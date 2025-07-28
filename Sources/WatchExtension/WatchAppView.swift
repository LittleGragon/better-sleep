import SwiftUI
import HealthKit

struct WatchAppView: View {
    @State private var isMonitoring = false
    @State private var heartRate: Double = 0
    @State private var sleepQuality: String = "未知"
    @State private var lastSleepDuration: TimeInterval = 0
    @State private var selectedTab = 0
    
    // 健康存储
    private let healthStore = HKHealthStore()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 主页面
            ScrollView {
                VStack(spacing: 15) {
                    Text("睡眠监测")
                        .font(.headline)
                    
                    Divider()
                    
                    // 心率显示
                    VStack {
                        Text("当前心率")
                            .font(.caption)
                        Text("\(Int(heartRate))")
                            .font(.system(size: 36, weight: .bold))
                        Text("BPM")
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(10)
                    
                    // 睡眠质量
                    VStack {
                        Text("睡眠质量")
                            .font(.caption)
                        Text(sleepQuality)
                            .font(.headline)
                    }
                    .padding()
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(10)
                    
                    // 上次睡眠时长
                    if lastSleepDuration > 0 {
                        VStack {
                            Text("上次睡眠")
                                .font(.caption)
                            Text(formatDuration(lastSleepDuration))
                                .font(.headline)
                        }
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(10)
                    }
                    
                    // 开始/停止按钮
                    Button(action: {
                        isMonitoring.toggle()
                        // 发送通知到ExtensionDelegate
                        NotificationCenter.default.post(
                            name: isMonitoring ? .startSleepMonitoring : .stopSleepMonitoring,
                            object: nil
                        )
                    }) {
                        Text(isMonitoring ? "停止监测" : "开始监测")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BorderedButtonStyle(tint: isMonitoring ? .red : .green))
                    .padding(.top)
                }
                .padding()
            }
            .tag(0)
            
            // 睡眠阶段页面
            SleepPhaseView()
                .tag(1)
            
            // 睡眠指标页面
            SleepMetricsView()
                .tag(2)
            
            // 设置页面
            ScrollView {
                VStack(spacing: 15) {
                    Text("设置")
                        .font(.headline)
                    
                    Divider()
                    
                    // 自动睡眠检测设置
                    Toggle("自动睡眠检测", isOn: .constant(true))
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(10)
                    
                    // 睡眠提醒设置
                    Toggle("睡眠提醒", isOn: .constant(true))
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(10)
                    
                    // 数据同步设置
                    Toggle("与iPhone同步", isOn: .constant(true))
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(10)
                    
                    // 关于按钮
                    Button(action: {
                        // 显示关于信息
                    }) {
                        Text("关于")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .padding(.top)
                }
                .padding()
            }
            .tag(3)
        }
        .tabViewStyle(PageTabViewStyle())
        .onAppear {
            // 请求健康数据权限
            requestHealthPermissions()
            
            // 获取最近的睡眠数据
            fetchRecentSleepData()
            
            // 开始心率监测
            startHeartRateMonitoring()
        }
    }
        .tabViewStyle(PageTabViewStyle())
        .onAppear {
            // 请求健康数据权限
            requestHealthPermissions()
            
            // 获取最近的睡眠数据
            fetchRecentSleepData()
            
            // 开始心率监测
            startHeartRateMonitoring()
        }
    }
        .onAppear {
            // 请求健康数据权限
            requestHealthPermissions()
            
            // 获取最近的睡眠数据
            fetchRecentSleepData()
            
            // 开始心率监测
            startHeartRateMonitoring()
        }
    }
    
    // 请求健康数据权限
    private func requestHealthPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if let error = error {
                print("健康数据权限请求失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 获取最近的睡眠数据
    private func fetchRecentSleepData() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: 10,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            if let error = error {
                print("获取睡眠数据失败: \(error.localizedDescription)")
                return
            }
            
            guard let samples = samples as? [HKCategorySample] else { return }
            
            // 分析睡眠质量
            DispatchQueue.main.async {
                if let lastSleep = samples.first {
                    let duration = lastSleep.endDate.timeIntervalSince(lastSleep.startDate)
                    self.lastSleepDuration = duration
                    
                    // 简单的睡眠质量评估
                    if duration >= 7 * 3600 { // 7小时或更长
                        self.sleepQuality = "优"
                    } else if duration >= 6 * 3600 { // 6-7小时
                        self.sleepQuality = "良"
                    } else if duration >= 5 * 3600 { // 5-6小时
                        self.sleepQuality = "中"
                    } else { // 少于5小时
                        self.sleepQuality = "差"
                    }
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    // 开始心率监测
    private func startHeartRateMonitoring() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])
        let updateHandler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = { query, samples, deletedObjects, queryAnchor, error in
            
            guard let samples = samples as? [HKQuantitySample], error == nil else { return }
            
            DispatchQueue.main.async {
                if let lastSample = samples.last {
                    // 获取心率值（单位：次/分钟）
                    self.heartRate = lastSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                }
            }
        }
        
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: devicePredicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit,
            resultsHandler: updateHandler
        )
        
        query.updateHandler = updateHandler
        
        healthStore.execute(query)
    }
    
    // 格式化时长
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%d小时%02d分钟", hours, minutes)
    }
}

// 通知名称扩展
extension Notification.Name {
    static let startSleepMonitoring = Notification.Name("startSleepMonitoring")
    static let stopSleepMonitoring = Notification.Name("stopSleepMonitoring")
}

struct WatchAppView_Previews: PreviewProvider {
    static var previews: some View {
        WatchAppView()
    }
}