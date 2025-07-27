import HealthKit
import SwiftUI

struct SleepRecord: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
}

class SleepDataManager: ObservableObject {
    @Published var sleepData: [SleepRecord] = []
    private let healthStore: HKHealthStore
    private let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
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
}