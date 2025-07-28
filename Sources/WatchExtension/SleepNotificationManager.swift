import Foundation
import UserNotifications
import WatchKit
import HealthKit

class SleepNotificationManager {
    // 单例
    static let shared = SleepNotificationManager()
    
    // 通知中心
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // 通知类型
    enum NotificationType: String {
        case bedtime = "bedtime"
        case wakeup = "wakeup"
        case sleepQuality = "sleepQuality"
        case sleepGoal = "sleepGoal"
    }
    
    // 私有初始化方法
    private init() {}
    
    // 请求通知权限
    func requestNotificationPermissions(completion: @escaping (Bool) -> Void = { _ in }) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("通知权限请求失败: \(error.localizedDescription)")
            }
            completion(granted)
        }
    }
    
    // 安排就寝时间通知
    func scheduleBedtimeNotification(at date: Date) {
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = "就寝时间"
        content.body = "现在是您设定的就寝时间，准备睡觉吧"
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = NotificationType.bedtime.rawValue
        
        // 创建触发器
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        // 创建请求
        let request = UNNotificationRequest(
            identifier: NotificationType.bedtime.rawValue,
            content: content,
            trigger: trigger
        )
        
        // 添加通知请求
        notificationCenter.add(request) { error in
            if let error = error {
                print("安排就寝时间通知失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 安排起床时间通知
    func scheduleWakeupNotification(at date: Date) {
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = "起床时间"
        content.body = "现在是您设定的起床时间，祝您有美好的一天"
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = NotificationType.wakeup.rawValue
        
        // 创建触发器
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        // 创建请求
        let request = UNNotificationRequest(
            identifier: NotificationType.wakeup.rawValue,
            content: content,
            trigger: trigger
        )
        
        // 添加通知请求
        notificationCenter.add(request) { error in
            if let error = error {
                print("安排起床时间通知失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 发送睡眠质量通知
    func sendSleepQualityNotification(duration: TimeInterval, quality: String) {
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = "睡眠报告"
        content.body = "您昨晚的睡眠质量为\(quality)，点击查看详情"
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = NotificationType.sleepQuality.rawValue
        
        // 添加睡眠时长到用户信息
        content.userInfo = ["sleepDuration": String(duration)]
        
        // 创建触发器（立即触发）
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // 创建请求
        let request = UNNotificationRequest(
            identifier: "\(NotificationType.sleepQuality.rawValue)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        // 添加通知请求
        notificationCenter.add(request) { error in
            if let error = error {
                print("发送睡眠质量通知失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 发送睡眠目标通知
    func sendSleepGoalNotification(achieved: Bool, duration: TimeInterval, goalDuration: TimeInterval) {
        // 创建通知内容
        let content = UNMutableNotificationContent()
        
        if achieved {
            content.title = "恭喜！"
            content.body = "您达到了睡眠目标，继续保持！"
        } else {
            let shortfall = goalDuration - duration
            let shortfallMinutes = Int(shortfall / 60)
            content.title = "睡眠目标未达成"
            content.body = "您的睡眠时间比目标少了约\(shortfallMinutes)分钟，尝试今晚早点睡觉"
        }
        
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = NotificationType.sleepGoal.rawValue
        
        // 添加睡眠时长到用户信息
        content.userInfo = [
            "sleepDuration": String(duration),
            "goalDuration": String(goalDuration),
            "achieved": achieved
        ]
        
        // 创建触发器（立即触发）
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // 创建请求
        let request = UNNotificationRequest(
            identifier: "\(NotificationType.sleepGoal.rawValue)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        // 添加通知请求
        notificationCenter.add(request) { error in
            if let error = error {
                print("发送睡眠目标通知失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 取消所有通知
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    // 取消特定类型的通知
    func cancelNotification(type: NotificationType) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [type.rawValue])
    }
}