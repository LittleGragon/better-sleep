import HealthKit
import SwiftUI
import WatchConnectivity

struct SleepRecord: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    var source: String = "iPhone" // 数据来源：iPhone 或 Apple Watch
}

class SleepDataManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var sleepData: [SleepRecord] = []
    @Published var watchConnectionStatus: Bool = false
    
    private let healthStore: HKHealthStore
    private let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
    private var session: WCSession?

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

    // 请求健康数据权限
    func requestHealthPermissions(completion: @escaping (Bool) -> Void = { _ in }) {
        guard let sleepType = sleepType else {
            completion(false)
            return
        }

        healthStore.requestAuthorization(toShare: [sleepType], read: [sleepType]) { success, error in
            if let error = error {
                print("健康数据权限请求失败: \(error.localizedDescription)")
            }
            completion(success)
        }
    }

    // 获取最近7天的睡眠数据
    func fetchRecentSleepData(completion: @escaping ([HKCategorySample]?) -> Void) {
        guard let sleepType = sleepType else {
            completion(nil)
            return
        }

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else {
            completion(nil)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            if let error = error {
                print("获取睡眠数据失败: \(error.localizedDescription)")
                completion(nil)
                return
            }
            completion(samples as? [HKCategorySample])
        }

        healthStore.execute(query)
    }
    
    // MARK: - WatchConnectivity Methods
    
    // 会话激活完成
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.watchConnectionStatus = activationState == .activated
        }
        
        if let error = error {
            print("WCSession 激活失败: \(error.localizedDescription)")
        }
    }
    
    // 接收来自 Apple Watch 的消息
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let command = message["command"] as? String else { return }
        
        switch command {
        case "sleepDataUpdated":
            // 处理来自 Apple Watch 的睡眠数据
            handleWatchSleepData(message)
        case "sleepPhaseChanged":
            // 处理来自 Apple Watch 的睡眠阶段变化
            handleWatchSleepPhaseChange(message)
        case "startSleepMonitoring":
            // Apple Watch 开始监测睡眠
            print("Apple Watch 开始监测睡眠")
        case "stopSleepMonitoring":
            // Apple Watch 停止监测睡眠
            print("Apple Watch 停止监测睡眠")
        default:
            break
        }
    }
    
    // 处理来自 Apple Watch 的睡眠数据
    private func handleWatchSleepData(_ message: [String: Any]) {
        guard let startTimeString = message["startTime"] as? String,
              let endTimeString = message["endTime"] as? String,
              let duration = message["duration"] as? TimeInterval else {
            return
        }
        
        let formatter = ISO8601DateFormatter()
        
        guard let startTime = formatter.date(from: startTimeString),
              let endTime = formatter.date(from: endTimeString) else {
            return
        }
        
        // 创建睡眠记录
        let sleepRecord = SleepRecord(
            id: UUID(),
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            source: "Apple Watch"
        )
        
        // 更新UI
        DispatchQueue.main.async {
            self.sleepData.append(sleepRecord)
            // 按日期排序
            self.sleepData.sort { $0.startTime > $1.startTime }
        }
    }
    
    // 处理来自 Apple Watch 的睡眠阶段变化
    private func handleWatchSleepPhaseChange(_ message: [String: Any]) {
        guard let phase = message["phase"] as? String,
              let timestamp = message["timestamp"] as? TimeInterval else {
            return
        }
        
        let date = Date(timeIntervalSince1970: timestamp)
        
        // 记录睡眠阶段变化
        print("睡眠阶段变化: \(phase) 时间: \(date)")
        
        // 这里可以添加更多处理逻辑，例如发送本地通知、更新UI等
        // 如果应用在前台，可以直接更新UI
        // 如果应用在后台，可以发送本地通知
        
        // 示例：如果是REM睡眠阶段，可以记录下来用于后续分析
        if phase == "快速眼动" {
            // 记录REM睡眠开始时间
            UserDefaults.standard.set(timestamp, forKey: "lastREMSleepStart")
        }
    }
    
    // 发送消息到 Apple Watch
    func sendMessageToWatch(message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil, errorHandler: ((Error) -> Void)? = nil) {
        guard let session = session, session.isReachable else {
            errorHandler?(NSError(domain: "com.littlegragon.BetterSleep", code: 0, userInfo: [NSLocalizedDescriptionKey: "Apple Watch 不可达"]))
            return
        }
        
        session.sendMessage(message, replyHandler: replyHandler, errorHandler: errorHandler)
    }
    
    // 开始 Apple Watch 睡眠监测
    func startWatchSleepMonitoring() {
        sendMessageToWatch(
            message: ["command": "startSleepMonitoring"],
            errorHandler: { error in
                print("发送开始监测命令失败: \(error.localizedDescription)")
            }
        )
    }
    
    // 停止 Apple Watch 睡眠监测
    func stopWatchSleepMonitoring() {
        sendMessageToWatch(
            message: ["command": "stopSleepMonitoring"],
            errorHandler: { error in
                print("发送停止监测命令失败: \(error.localizedDescription)")
            }
        )
    }
    
    // MARK: - Required WCSessionDelegate methods for iOS
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.watchConnectionStatus = false
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // 重新激活会话
        WCSession.default.activate()
    }
}