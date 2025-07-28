import WatchKit
import HealthKit
import CoreMotion
import UserNotifications

class ExtensionDelegate: NSObject, WKExtensionDelegate, UNUserNotificationCenterDelegate {
    // HealthKit 存储
    private let healthStore = HKHealthStore()
    // 睡眠数据管理器
    private var sleepSensorManager: SleepSensorManager?
    // 运动管理器
    private var motionManager: CMMotionManager?
    // 后台任务标识符
    private var backgroundTask: WKApplicationRefreshBackgroundTask?
    // 通知管理器
    private let notificationManager = SleepNotificationManager.shared
    
    func applicationDidFinishLaunching() {
        // 初始化睡眠传感器管理器
        sleepSensorManager = SleepSensorManager(healthStore: healthStore)
        
        // 请求必要的权限
        requestPermissions()
        
        // 设置后台刷新
        scheduleBackgroundRefresh()
        
        // 初始化运动管理器
        setupMotionManager()
        
        // 设置通知代理
        UNUserNotificationCenter.current().delegate = self
        
        // 设置默认的就寝和起床时间通知
        setupDefaultNotifications()
    }
    
    // 请求所有必要的权限
    private func requestPermissions() {
        // 请求健康数据权限
        requestHealthPermissions()
        
        // 请求通知权限
        notificationManager.requestNotificationPermissions { granted in
            if granted {
                print("通知权限请求成功")
            } else {
                print("通知权限请求失败")
            }
        }
    }
    
    // 请求健康数据权限
    private func requestHealthPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit 在此设备上不可用")
            return
        }
        
        // 定义我们需要的健康数据类型
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        // 请求权限
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            if let error = error {
                print("健康数据权限请求失败: \(error.localizedDescription)")
                return
            }
            
            if success {
                print("健康数据权限请求成功")
                // 开始监测睡眠
                self.sleepSensorManager?.startMonitoring()
            }
        }
    }
    
    // 设置运动管理器
    private func setupMotionManager() {
        motionManager = CMMotionManager()
        guard let motionManager = motionManager else { return }
        
        // 检查加速度计是否可用
        if motionManager.isAccelerometerAvailable {
            // 设置更新间隔
            motionManager.accelerometerUpdateInterval = 1.0 // 1秒
            
            // 开始加速度计更新
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
                guard let data = data, error == nil else {
                    if let error = error {
                        print("加速度计更新错误: \(error.localizedDescription)")
                    }
                    return
                }
                
                // 处理加速度数据
                self?.sleepSensorManager?.processAccelerometerData(data)
            }
        }
        
        // 检查陀螺仪是否可用
        if motionManager.isGyroAvailable {
            // 设置更新间隔
            motionManager.gyroUpdateInterval = 1.0 // 1秒
            
            // 开始陀螺仪更新
            motionManager.startGyroUpdates(to: .main) { [weak self] data, error in
                guard let data = data, error == nil else {
                    if let error = error {
                        print("陀螺仪更新错误: \(error.localizedDescription)")
                    }
                    return
                }
                
                // 处理陀螺仪数据
                self?.sleepSensorManager?.processGyroData(data)
            }
        }
    }
    
    // 设置默认的通知
    private func setupDefaultNotifications() {
        // 设置默认的就寝时间通知（晚上10点）
        let calendar = Calendar.current
        var bedtimeComponents = DateComponents()
        bedtimeComponents.hour = 22
        bedtimeComponents.minute = 0
        if let bedtime = calendar.date(from: bedtimeComponents) {
            notificationManager.scheduleBedtimeNotification(at: bedtime)
        }
        
        // 设置默认的起床时间通知（早上7点）
        var wakeupComponents = DateComponents()
        wakeupComponents.hour = 7
        wakeupComponents.minute = 0
        if let wakeup = calendar.date(from: wakeupComponents) {
            notificationManager.scheduleWakeupNotification(at: wakeup)
        }
    }
    
    // 设置后台刷新任务
    private func scheduleBackgroundRefresh() {
        let refreshInterval: TimeInterval = 15 * 60 // 15分钟
        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: Date(timeIntervalSinceNow: refreshInterval), userInfo: nil) { error in
            if let error = error {
                print("安排后台刷新失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 处理后台任务
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let refreshTask = task as? WKApplicationRefreshBackgroundTask {
                // 执行后台刷新任务
                sleepSensorManager?.updateSleepData()
                
                // 重新安排下一次后台刷新
                scheduleBackgroundRefresh()
                
                // 完成任务
                refreshTask.setTaskCompletedWithSnapshot(false)
            } else {
                // 处理其他类型的后台任务
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
    
    // 应用进入活动状态
    func applicationDidBecomeActive() {
        // 更新UI或数据
        sleepSensorManager?.updateSleepData()
    }
    
    // 应用将进入非活动状态
    func applicationWillResignActive() {
        // 保存任何需要的状态
    }
    
    // 处理通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 允许在前台显示通知
        completionHandler([.banner, .sound])
    }
    
    // 处理通知响应
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // 根据通知类型处理响应
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        
        switch categoryIdentifier {
        case SleepNotificationManager.NotificationType.bedtime.rawValue:
            // 处理就寝时间通知响应
            sleepSensorManager?.startMonitoring()
            
        case SleepNotificationManager.NotificationType.wakeup.rawValue:
            // 处理起床时间通知响应
            sleepSensorManager?.stopMonitoring()
            
        case SleepNotificationManager.NotificationType.sleepQuality.rawValue:
            // 处理睡眠质量通知响应
            // 可以打开睡眠指标视图
            break
            
        case SleepNotificationManager.NotificationType.sleepGoal.rawValue:
            // 处理睡眠目标通知响应
            break
            
        default:
            break
        }
        
        completionHandler()
    }
}