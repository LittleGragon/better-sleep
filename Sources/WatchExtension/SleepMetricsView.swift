import SwiftUI
import HealthKit

struct SleepMetricsView: View {
    @State private var sleepDuration: TimeInterval = 0
    @State private var averageHeartRate: Double = 0
    @State private var restingHeartRate: Double = 0
    @State private var respiratoryRate: Double = 0
    @State private var heartRateVariability: Double = 0
    @State private var sleepQuality: String = "未知"
    
    private let healthStore = HKHealthStore()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("睡眠指标")
                    .font(.headline)
                    .padding(.top, 5)
                
                Divider()
                
                // 睡眠时长
                MetricView(
                    title: "睡眠时长",
                    value: formatDuration(sleepDuration),
                    icon: "bed.double.fill"
                )
                
                // 睡眠质量
                MetricView(
                    title: "睡眠质量",
                    value: sleepQuality,
                    icon: "star.fill"
                )
                
                // 平均心率
                MetricView(
                    title: "平均心率",
                    value: "\(Int(averageHeartRate)) BPM",
                    icon: "heart.fill"
                )
                
                // 静息心率
                MetricView(
                    title: "静息心率",
                    value: "\(Int(restingHeartRate)) BPM",
                    icon: "heart.circle.fill"
                )
                
                // 心率变异性
                MetricView(
                    title: "心率变异性",
                    value: String(format: "%.1f ms", heartRateVariability),
                    icon: "waveform.path.ecg"
                )
                
                // 呼吸频率
                MetricView(
                    title: "呼吸频率",
                    value: String(format: "%.1f 次/分", respiratoryRate),
                    icon: "lungs.fill"
                )
            }
            .padding(.horizontal)
        }
        .onAppear {
            fetchSleepMetrics()
        }
    }
    
    // 获取睡眠指标
    private func fetchSleepMetrics() {
        // 获取最近的睡眠数据
        fetchRecentSleepData { duration, quality in
            self.sleepDuration = duration
            self.sleepQuality = quality
            
            // 获取睡眠期间的心率数据
            self.fetchHeartRateData(during: duration)
            
            // 获取静息心率
            self.fetchRestingHeartRate()
            
            // 获取心率变异性
            self.fetchHeartRateVariability()
            
            // 获取呼吸频率
            self.fetchRespiratoryRate()
        }
    }
    
    // 获取最近的睡眠数据
    private func fetchRecentSleepData(completion: @escaping (TimeInterval, String) -> Void) {
        guard HKHealthStore.isHealthDataAvailable(),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(0, "未知")
            return
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else {
            completion(0, "未知")
            return
        }
        
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
                completion(0, "未知")
                return
            }
            
            guard let samples = samples as? [HKCategorySample] else {
                completion(0, "未知")
                return
            }
            
            // 计算最近一次睡眠的时长
            if let lastSleep = samples.first {
                let duration = lastSleep.endDate.timeIntervalSince(lastSleep.startDate)
                
                // 简单的睡眠质量评估
                var quality = "未知"
                if duration >= 7 * 3600 { // 7小时或更长
                    quality = "优"
                } else if duration >= 6 * 3600 { // 6-7小时
                    quality = "良"
                } else if duration >= 5 * 3600 { // 5-6小时
                    quality = "中"
                } else { // 少于5小时
                    quality = "差"
                }
                
                completion(duration, quality)
            } else {
                completion(0, "未知")
            }
        }
        
        healthStore.execute(query)
    }
    
    // 获取睡眠期间的心率数据
    private func fetchHeartRateData(during sleepDuration: TimeInterval) {
        guard HKHealthStore.isHealthDataAvailable(),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .hour, value: -Int(sleepDuration / 3600), to: endDate) else {
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKStatisticsQuery(
            quantityType: heartRateType,
            quantitySamplePredicate: predicate,
            options: [.discreteAverage]
        ) { _, statistics, error in
            if let error = error {
                print("获取心率数据失败: \(error.localizedDescription)")
                return
            }
            
            guard let statistics = statistics,
                  let averageHeartRate = statistics.averageQuantity() else {
                return
            }
            
            let heartRate = averageHeartRate.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            
            DispatchQueue.main.async {
                self.averageHeartRate = heartRate
            }
        }
        
        healthStore.execute(query)
    }
    
    // 获取静息心率
    private func fetchRestingHeartRate() {
        guard HKHealthStore.isHealthDataAvailable(),
              let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            return
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -1, to: endDate) else {
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKStatisticsQuery(
            quantityType: restingHeartRateType,
            quantitySamplePredicate: predicate,
            options: [.discreteAverage]
        ) { _, statistics, error in
            if let error = error {
                print("获取静息心率数据失败: \(error.localizedDescription)")
                return
            }
            
            guard let statistics = statistics,
                  let averageRestingHeartRate = statistics.averageQuantity() else {
                return
            }
            
            let heartRate = averageRestingHeartRate.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            
            DispatchQueue.main.async {
                self.restingHeartRate = heartRate
            }
        }
        
        healthStore.execute(query)
    }
    
    // 获取心率变异性
    private func fetchHeartRateVariability() {
        guard HKHealthStore.isHealthDataAvailable(),
              let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -1, to: endDate) else {
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKStatisticsQuery(
            quantityType: hrvType,
            quantitySamplePredicate: predicate,
            options: [.discreteAverage]
        ) { _, statistics, error in
            if let error = error {
                print("获取心率变异性数据失败: \(error.localizedDescription)")
                return
            }
            
            guard let statistics = statistics,
                  let averageHRV = statistics.averageQuantity() else {
                return
            }
            
            let hrv = averageHRV.doubleValue(for: HKUnit.secondUnit(with: .milli))
            
            DispatchQueue.main.async {
                self.heartRateVariability = hrv
            }
        }
        
        healthStore.execute(query)
    }
    
    // 获取呼吸频率
    private func fetchRespiratoryRate() {
        guard HKHealthStore.isHealthDataAvailable(),
              let respiratoryRateType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) else {
            return
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -1, to: endDate) else {
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKStatisticsQuery(
            quantityType: respiratoryRateType,
            quantitySamplePredicate: predicate,
            options: [.discreteAverage]
        ) { _, statistics, error in
            if let error = error {
                print("获取呼吸频率数据失败: \(error.localizedDescription)")
                return
            }
            
            guard let statistics = statistics,
                  let averageRespiratoryRate = statistics.averageQuantity() else {
                return
            }
            
            let rate = averageRespiratoryRate.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            
            DispatchQueue.main.async {
                self.respiratoryRate = rate
            }
        }
        
        healthStore.execute(query)
    }
    
    // 格式化时长
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%d小时%02d分钟", hours, minutes)
    }
}

// 指标视图组件
struct MetricView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 20))
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }
}

struct SleepMetricsView_Previews: PreviewProvider {
    static var previews: some View {
        SleepMetricsView()
    }
}