import Foundation
import HealthKit
import CoreMotion
import WatchKit
import WatchConnectivity

// 睡眠阶段枚举
enum SleepPhase: String {
    case awake = "清醒"
    case light = "浅睡眠"
    case deep = "深睡眠"
    case rem = "快速眼动"
    case unknown = "未知"
}

class SleepSensorManager: NSObject, WCSessionDelegate {
    // HealthKit 存储
    private let healthStore: HKHealthStore
    // 会话连接
    private var session: WCSession?
    // 睡眠状态
    private(set) var isMonitoring = false
    // 睡眠数据
    private var sleepData: [SleepSensorData] = []
    // 运动数据缓冲区
    private var motionBuffer: [MotionData] = []
    // 心率数据缓冲区
    private var heartRateBuffer: [HeartRateData] = []
    // 睡眠检测算法参数
    private let motionThreshold: Double = 0.1
    private let sleepDetectionWindow: TimeInterval = 300 // 5分钟
    
    // 初始化
    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
        super.init()
        
        // 设置 WatchConnectivity
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    // 开始监测睡眠
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        // 开始心率监测
        startHeartRateMonitoring()
        
        // 通知 iOS 应用
        sendMessageToiOS(message: ["command": "startSleepMonitoring"])
        
        print("开始睡眠监测")
    }
    
    // 停止监测睡眠
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        
        // 停止心率监测
        stopHeartRateMonitoring()
        
        // 保存收集的数据
        saveSleepData()
        
        // 通知 iOS 应用
        sendMessageToiOS(message: ["command": "stopSleepMonitoring"])
        
        print("停止睡眠监测")
    }
    
    // 更新睡眠数据
    func updateSleepData() {
        // 分析当前数据
        analyzeSleepData()
        
        // 如果检测到用户已经醒来，停止监测
        if isUserAwake() && isMonitoring {
            stopMonitoring()
        }
    }
    
    // 处理加速度计数据
    func processAccelerometerData(_ data: CMAccelerometerData) {
        guard isMonitoring else { return }
        
        // 计算加速度向量的大小
        let magnitude = sqrt(pow(data.acceleration.x, 2) + 
                            pow(data.acceleration.y, 2) + 
                            pow(data.acceleration.z, 2))
        
        // 存储运动数据
        let motionData = MotionData(
            timestamp: Date(),
            magnitude: magnitude,
            type: .accelerometer,
            x: data.acceleration.x,
            y: data.acceleration.y,
            z: data.acceleration.z
        )
        motionBuffer.append(motionData)
        
        // 限制缓冲区大小
        if motionBuffer.count > 1000 {
            motionBuffer.removeFirst(motionBuffer.count - 1000)
        }
        
        // 检测睡眠状态
        detectSleepState()
    }
    
    // 处理陀螺仪数据
    func processGyroData(_ data: CMGyroData) {
        guard isMonitoring else { return }
        
        // 计算角速度向量的大小
        let magnitude = sqrt(pow(data.rotationRate.x, 2) + 
                            pow(data.rotationRate.y, 2) + 
                            pow(data.rotationRate.z, 2))
        
        // 存储运动数据
        let motionData = MotionData(
            timestamp: Date(),
            magnitude: magnitude,
            type: .gyroscope,
            x: data.rotationRate.x,
            y: data.rotationRate.y,
            z: data.rotationRate.z
        )
        motionBuffer.append(motionData)
        
        // 限制缓冲区大小
        if motionBuffer.count > 1000 {
            motionBuffer.removeFirst(motionBuffer.count - 1000)
        }
        
        // 检测睡眠状态
        detectSleepState()
    }
    
    // 开始心率监测
    private func startHeartRateMonitoring() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        // 创建心率查询
        let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])
        let updateHandler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = { query, samples, deletedObjects, queryAnchor, error in
            
            guard let samples = samples as? [HKQuantitySample], error == nil else {
                if let error = error {
                    print("心率监测错误: \(error.localizedDescription)")
                }
                return
            }
            
            for sample in samples {
                // 获取心率值（单位：次/分钟）
                let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                
                // 存储心率数据
                let heartRateData = HeartRateData(timestamp: sample.startDate, bpm: heartRate)
                self.heartRateBuffer.append(heartRateData)
                
                // 限制缓冲区大小
                if self.heartRateBuffer.count > 100 {
                    self.heartRateBuffer.removeFirst(self.heartRateBuffer.count - 100)
                }
            }
            
            // 检测睡眠状态
            self.detectSleepState()
        }
        
        // 创建查询
        let query = HKAnchoredObjectQuery(type: heartRateType, predicate: devicePredicate, anchor: nil, limit: HKObjectQueryNoLimit, resultsHandler: updateHandler)
        
        // 设置查询以接收更新
        query.updateHandler = updateHandler
        
        // 执行查询
        healthStore.execute(query)
    }
    
    // 停止心率监测
    private func stopHeartRateMonitoring() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        // 停止所有心率查询
        healthStore.stop(HKQuery.predicateForObjects(from: [HKDevice.local()]))
    }
    
    // 检测睡眠状态
    private func detectSleepState() {
        // 确保有足够的数据进行分析
        guard !motionBuffer.isEmpty, !heartRateBuffer.isEmpty else { return }
        
        // 获取最近一段时间的运动数据
        let recentMotionData = getRecentMotionData(window: sleepDetectionWindow)
        
        // 计算平均运动幅度
        let averageMotion = recentMotionData.map { $0.magnitude }.reduce(0, +) / Double(recentMotionData.count)
        
        // 获取最近的心率数据
        let recentHeartRate = heartRateBuffer.last?.bpm ?? 0
        
        // 睡眠状态检测逻辑
        let isSleeping = averageMotion < motionThreshold && recentHeartRate < 65
        
        // 检测睡眠阶段
        let sleepPhase = detectSleepPhase(
            motionLevel: averageMotion,
            heartRate: recentHeartRate,
            recentMotionData: recentMotionData
        )
        
        // 创建睡眠传感器数据
        let sensorData = SleepSensorData(
            timestamp: Date(),
            isSleeping: isSleeping,
            motionLevel: averageMotion,
            heartRate: recentHeartRate,
            sleepPhase: sleepPhase
        )
        
        // 添加到睡眠数据数组
        sleepData.append(sensorData)
        
        // 限制数据数组大小
        if sleepData.count > 1000 {
            sleepData.removeFirst(sleepData.count - 1000)
        }
        
        // 如果检测到睡眠阶段变化，发送通知
        if sleepData.count >= 2 {
            let previousPhase = sleepData[sleepData.count - 2].sleepPhase
            if previousPhase != sleepPhase {
                // 发送睡眠阶段变化消息到iOS应用
                sendSleepPhaseChangeToiOS(phase: sleepPhase)
            }
        }
    }
    
    // 检测睡眠阶段
    private func detectSleepPhase(motionLevel: Double, heartRate: Double, recentMotionData: [MotionData]) -> SleepPhase {
        // 如果运动水平高，则认为是清醒状态
        if motionLevel > motionThreshold * 2 {
            return .awake
        }
        
        // 计算运动变异性（用于区分深睡眠和REM睡眠）
        let motionVariance = calculateMotionVariance(recentMotionData)
        
        // 根据心率和运动变异性判断睡眠阶段
        if heartRate < 55 && motionLevel < motionThreshold / 2 {
            // 心率低，运动水平非常低 -> 深睡眠
            return .deep
        } else if heartRate >= 55 && heartRate < 70 && motionVariance > 0.05 {
            // 心率中等，运动变异性高 -> REM睡眠
            return .rem
        } else if motionLevel < motionThreshold {
            // 运动水平低 -> 浅睡眠
            return .light
        } else {
            // 默认为清醒
            return .awake
        }
    }
    
    // 计算运动变异性
    private func calculateMotionVariance(_ motionData: [MotionData]) -> Double {
        guard motionData.count > 1 else { return 0 }
        
        // 计算运动幅度的平均值
        let mean = motionData.map { $0.magnitude }.reduce(0, +) / Double(motionData.count)
        
        // 计算方差
        let variance = motionData.map { pow($0.magnitude - mean, 2) }.reduce(0, +) / Double(motionData.count)
        
        return variance
    }
    
    // 发送睡眠阶段变化消息到iOS应用
    private func sendSleepPhaseChangeToiOS(phase: SleepPhase) {
        let message: [String: Any] = [
            "command": "sleepPhaseChanged",
            "phase": phase.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessageToiOS(message: message)
    }
    
    // 获取最近一段时间的运动数据
    private func getRecentMotionData(window: TimeInterval) -> [MotionData] {
        let cutoffDate = Date().addingTimeInterval(-window)
        return motionBuffer.filter { $0.timestamp > cutoffDate }
    }
    
    // 检查用户是否已经醒来
    private func isUserAwake() -> Bool {
        // 确保有足够的数据进行分析
        guard sleepData.count >= 10 else { return false }
        
        // 获取最近的10个数据点
        let recentData = Array(sleepData.suffix(10))
        
        // 如果大多数数据点表明用户醒着，则认为用户已经醒来
        let awakeCount = recentData.filter { !$0.isSleeping }.count
        return awakeCount >= 7 // 70%的数据点表明用户醒着
    }
    
    // 保存睡眠数据到HealthKit
    private func saveSleepData() {
        guard !sleepData.isEmpty, let sleepCategoryType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        // 分析睡眠数据，找出睡眠开始和结束时间
        var sleepPeriods: [(start: Date, end: Date)] = []
        var currentSleepStart: Date? = nil
        
        for (index, data) in sleepData.enumerated() {
            if data.isSleeping && currentSleepStart == nil {
                // 睡眠开始
                currentSleepStart = data.timestamp
            } else if !data.isSleeping && currentSleepStart != nil {
                // 睡眠结束
                sleepPeriods.append((start: currentSleepStart!, end: sleepData[index-1].timestamp))
                currentSleepStart = nil
            }
        }
        
        // 如果最后一个状态是睡眠中，添加到当前时间
        if let start = currentSleepStart {
            sleepPeriods.append((start: start, end: Date()))
        }
        
        // 合并短暂的清醒期（小于15分钟的清醒被视为睡眠的一部分）
        let mergedPeriods = mergeSleepPeriods(sleepPeriods, maxGap: 15 * 60)
        
        // 保存到HealthKit
        for period in mergedPeriods {
            // 创建睡眠分析样本
            let sleepSample = HKCategorySample(
                type: sleepCategoryType,
                value: HKCategoryValueSleepAnalysis.asleep.rawValue,
                start: period.start,
                end: period.end
            )
            
            // 保存到健康数据库
            healthStore.save(sleepSample) { success, error in
                if let error = error {
                    print("保存睡眠数据失败: \(error.localizedDescription)")
                } else if success {
                    print("成功保存睡眠数据: \(period.start) 到 \(period.end)")
                    
                    // 发送睡眠数据到iOS应用
                    self.sendSleepDataToiOS(start: period.start, end: period.end)
                }
            }
        }
    }
    
    // 合并睡眠周期，如果间隔小于指定时间
    private func mergeSleepPeriods(_ periods: [(start: Date, end: Date)], maxGap: TimeInterval) -> [(start: Date, end: Date)] {
        guard !periods.isEmpty else { return [] }
        
        var result: [(start: Date, end: Date)] = []
        var currentStart = periods[0].start
        var currentEnd = periods[0].end
        
        for i in 1..<periods.count {
            let nextStart = periods[i].start
            let nextEnd = periods[i].end
            
            // 如果下一个周期的开始时间与当前周期的结束时间间隔小于maxGap，则合并
            if nextStart.timeIntervalSince(currentEnd) <= maxGap {
                currentEnd = nextEnd
            } else {
                // 否则，添加当前周期并开始新的周期
                result.append((start: currentStart, end: currentEnd))
                currentStart = nextStart
                currentEnd = nextEnd
            }
        }
        
        // 添加最后一个周期
        result.append((start: currentStart, end: currentEnd))
        
        return result
    }
    
    // 发送消息到iOS应用
    private func sendMessageToiOS(message: [String: Any]) {
        guard let session = session, session.isReachable else { return }
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("发送消息到iOS应用失败: \(error.localizedDescription)")
        }
    }
    
    // 发送睡眠数据到iOS应用
    private func sendSleepDataToiOS(start: Date, end: Date) {
        let formatter = ISO8601DateFormatter()
        let message: [String: Any] = [
            "command": "sleepDataUpdated",
            "startTime": formatter.string(from: start),
            "endTime": formatter.string(from: end),
            "duration": end.timeIntervalSince(start)
        ]
        
        sendMessageToiOS(message: message)
    }
    
    // WCSessionDelegate 方法
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession 激活失败: \(error.localizedDescription)")
        } else {
            print("WCSession 激活成功，状态: \(activationState.rawValue)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // 处理从iOS应用接收的消息
        if let command = message["command"] as? String {
            switch command {
            case "startSleepMonitoring":
                startMonitoring()
            case "stopSleepMonitoring":
                stopMonitoring()
            default:
                break
            }
        }
    }
}

// 运动数据类型
enum MotionDataType {
    case accelerometer
    case gyroscope
}

// 运动数据结构
struct MotionData {
    let timestamp: Date
    let magnitude: Double
    let type: MotionDataType
    let x: Double
    let y: Double
    let z: Double
}

// 心率数据结构
struct HeartRateData {
    let timestamp: Date
    let bpm: Double
}

// 睡眠传感器数据结构
struct SleepSensorData {
    let timestamp: Date
    let isSleeping: Bool
    let motionLevel: Double
    let heartRate: Double
    var sleepPhase: SleepPhase = .unknown
}