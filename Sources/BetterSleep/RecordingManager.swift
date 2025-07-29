import Foundation
import AVFoundation
import UIKit
import BackgroundTasks
import UserNotifications

class RecordingManager: NSObject, ObservableObject {
    private let audioRecorder: AudioRecorder
    private let audioClassifier: AudioClassifier
    private let cloudManager = CloudManager.shared
    private var analysisTimer: Timer?
    private var recordedSegments: [AudioSegment] = []
    private var currentRecordingURL: URL?
    private var recordingStartTime: Date?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var delayTimer: Timer?
    
    @Published var isMonitoring = false
    @Published var recentSegments: [AudioSegment] = []
    @Published var currentDecibels: Float = 0.0
    @Published var audioLevels: [Float] = Array(repeating: 0, count: 30) // 存储最近的音频电平
    @Published var isTimerActive: Bool = false
    @Published var timerDuration: TimeInterval = 0
    @Published var remainingTime: TimeInterval = 0
    @Published var recordings: [URL] = [] // 存储录音文件
    @Published var isStorageAvailable: Bool = false // 存储是否可用
    @Published var isSavingToStorage: Bool = false // 是否正在保存
    @Published var storageType: String = "本地存储" // 当前存储类型

    init(audioRecorder: AudioRecorder, audioClassifier: AudioClassifier) {
        self.audioRecorder = audioRecorder
        self.audioClassifier = audioClassifier
        super.init()
        
        // 检查存储是否可用
        let permissions = cloudManager.checkStoragePermissions()
        isStorageAvailable = permissions.isAvailable
        storageType = permissions.storageType
        
        // 暂时注释掉 iCloud 状态监听
        // cloudManager.startMonitoringCloudChanges()
        
        // 加载录音文件
        if UserSettings.shared.isRecordingStorageEnabled {
            loadRecordings()
        }
        
        // 监听设置变更通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: NSNotification.Name("SettingsChanged"),
            object: nil
        )
        
        // 暂时注释掉 iCloud 通知监听
        // NotificationCenter.default.addObserver(
        //     self,
        //     selector: #selector(ubiquityIdentityDidChange),
        //     name: NSNotification.Name.NSUbiquityIdentityDidChange,
        //     object: nil
        // )
    }
    
    // 暂时注释掉 iCloud 状态变化处理
    /*
    // 存储状态变化
    @objc private func ubiquityIdentityDidChange(_ notification: Notification) {
        let permissions = cloudManager.checkStoragePermissions()
        isStorageAvailable = permissions.isAvailable
        storageType = permissions.storageType
        
        if permissions.isAvailable {
            loadRecordings()
        } else {
            recordings = []
        }
    }
    */
    
    // 加载录音文件
    func loadRecordings() {
        // 检查用户是否启用了录音存储
        guard UserSettings.shared.isRecordingStorageEnabled else {
            DispatchQueue.main.async {
                self.recordings = []
                print("录音存储功能已被用户禁用，不加载录音")
            }
            return
        }
        
        let permissions = cloudManager.checkStoragePermissions()
        guard permissions.isAvailable else {
            DispatchQueue.main.async {
                self.isStorageAvailable = false
                self.recordings = []
                print("存储权限检查失败: \(permissions.errorMessage ?? "未知错误")")
            }
            return
        }
        
        cloudManager.getAllRecordings { [weak self] urls, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let urls = urls {
                    self.recordings = urls
                    self.isStorageAvailable = true
                } else {
                    self.recordings = []
                    print("获取录音失败: \(error?.localizedDescription ?? "未知错误")")
                }
            }
        }
    }

    // 开始睡眠监测（录音+分析）
    func startMonitoring() -> Bool {
        guard !isMonitoring else { return false }

        recordedSegments.removeAll()
        recordingStartTime = Date()
        let success = audioRecorder.startRecording()

        if success {
            isMonitoring = true
            currentRecordingURL = audioRecorder.currentRecordingURL
            
            // 重置音频电平数组
            DispatchQueue.main.async {
                self.audioLevels = Array(repeating: 0, count: 30)
                self.currentDecibels = 0.0
            }
            
            startAnalysisTimer()
            startBackgroundTask()
            startAudioLevelMonitoring()
        }

        return success
    }
    
    // 开始后台任务
    private func startBackgroundTask() {
        // 结束之前的后台任务（如果有）
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        // 开始新的后台任务
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // 后台任务即将过期时的清理工作
            self?.stopMonitoring()
            if let bgTask = self?.backgroundTask, bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                self?.backgroundTask = .invalid
            }
        }
    }
    
    // 监控音频电平
    private func startAudioLevelMonitoring() {
        // 创建一个更频繁的定时器来更新音频电平
        let levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isMonitoring else { return }
            
            if let recorder = self.audioRecorder.audioRecorder {
                recorder.updateMeters()
                let power = recorder.averagePower(forChannel: 0)
                // 将分贝值转换为0-100的范围
                let normalizedPower = self.normalizeDbValue(power)
                
                DispatchQueue.main.async {
                    self.currentDecibels = normalizedPower
                    // 更新音频电平数组
                    self.audioLevels.removeFirst()
                    self.audioLevels.append(normalizedPower)
                }
            }
        }
        
        // 确保定时器在后台也能运行
        RunLoop.current.add(levelTimer, forMode: .common)
    }
    
    // 将分贝值标准化到0-100范围
    private func normalizeDbValue(_ power: Float) -> Float {
        // 音频电平通常在-160到0之间，我们将其映射到0-100
        let minDb: Float = -60.0 // 最小可听分贝
        let maxDb: Float = 0.0   // 最大分贝
        
        // 检查是否为无效值
        if power.isNaN || power.isInfinite {
            return 0.0
        }
        
        // 限制在范围内
        let clampedPower = max(minDb, min(power, maxDb))
        
        // 映射到0-100
        return (clampedPower - minDb) / (maxDb - minDb) * 100.0
    }

    // 停止睡眠监测
    func stopMonitoring() {
        guard isMonitoring else { return }

        stopAnalysisTimer()
        let recordingURL = audioRecorder.stopRecording()
        isMonitoring = false
        recordingStartTime = nil

        // 结束后台任务
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }

        // 保存完整录音并处理分段
        if let url = recordingURL {
            processFullRecording(url: url)
        }
    }

    // 启动分析定时器（每10秒分析一次音频片段）
    private func startAnalysisTimer() {
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) {
            [weak self] _ in
            self?.analyzeRecentAudio()
        }
        
        // 确保定时器在后台也能运行
        RunLoop.current.add(analysisTimer!, forMode: .common)
    }

    // 停止分析定时器
    private func stopAnalysisTimer() {
        analysisTimer?.invalidate()
        analysisTimer = nil
    }

    // 分析最近的音频片段
    private func analyzeRecentAudio() {
        guard let startTime = recordingStartTime else { return }

        let segment = AudioSegment(
            url: audioRecorder.currentRecordingURL,
            startTime: Date().addingTimeInterval(-10),
            endTime: Date(),
            type: .unknown
        )

        // 分析音频类型（鼾声/梦话/其他）
        audioClassifier.classifyAudio(segment: segment) {
            [weak self] classifiedSegment in
            guard let self = self else { return }
            
            // 即使没有分类结果，也打印日志
            if classifiedSegment == nil {
                print("音频分类失败，未返回结果")
                return
            }
            
            guard let classifiedSegment = classifiedSegment else { return }
            
            // 打印分类结果
            print("音频分类结果: \(classifiedSegment.type.rawValue)")
            
            // 只有当声音类型不是未知时才添加到片段列表
            if classifiedSegment.type != .unknown {
                self.recordedSegments.append(classifiedSegment)
                DispatchQueue.main.async {
                    self.recentSegments.append(classifiedSegment)
                    print("添加了新的声音片段: \(classifiedSegment.type.rawValue)")
                }
            } else {
                print("声音类型为未知，不添加到片段列表")
            }
        }
    }

    // 处理完整录音文件
    private func processFullRecording(url: URL) {
        // 1. 保存完整录音到应用文档目录
        // 2. 对检测到的音频片段进行精确裁剪
        // 3. 更新健康数据
        
        print("完整录音已保存: \(url)")
        print("检测到的事件: \(recordedSegments.count)个")
        
        // 保存到存储
        saveRecordingToStorage(url: url)
    }
    
    // 保存录音到存储
    private func saveRecordingToStorage(url: URL) {
        // 检查用户是否启用了录音存储
        guard UserSettings.shared.isRecordingStorageEnabled else {
            print("录音存储功能已被用户禁用，不保存录音")
            return
        }
        
        let permissions = cloudManager.checkStoragePermissions()
        guard permissions.isAvailable else {
            print("存储不可用，无法保存录音: \(permissions.errorMessage ?? "未知错误")")
            return
        }
        
        DispatchQueue.main.async {
            self.isSavingToStorage = true
        }
        
        cloudManager.saveRecordingToStorage(localURL: url) { [weak self] storageURL, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isSavingToStorage = false
                
                if let storageURL = storageURL {
                    print("录音已成功保存到\(permissions.storageType): \(storageURL.path)")
                    // 延迟3秒后刷新录音列表，确保同步完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.loadRecordings()
                    }
                    // 发送保存成功通知
                    NotificationCenter.default.post(name: .recordingSavedSuccessfully, object: nil)
                } else {
                    let errorMessage: String
                    if let error = error {
                        if error.localizedDescription.contains("无法访问") {
                            errorMessage = "存储访问被拒绝，请检查存储设置"
                        } else {
                            errorMessage = error.localizedDescription
                        }
                    } else {
                        errorMessage = "未知错误"
                    }
                    print("保存录音失败: \(errorMessage)")
                    // 发送保存失败通知
                    NotificationCenter.default.post(name: .recordingSaveFailed, object: errorMessage)
                }
            }
        }
    }
    
    // 删除录音
    func deleteRecording(url: URL, completion: @escaping (Bool) -> Void) {
        cloudManager.deleteRecording(url: url) { [weak self] success, error in
            guard let self = self else { return }
            
            if success {
                // 从列表中移除
                DispatchQueue.main.async {
                    self.recordings.removeAll { $0.path == url.path }
                }
                completion(true)
            } else {
                print("删除录音失败: \(error?.localizedDescription ?? "未知错误")")
                completion(false)
            }
        }
    }
    
    // 启动定时器
    func startDelayedMonitoring(duration: TimeInterval) {
        // 取消之前的定时器
        cancelDelayedMonitoring()
        
        // 设置新的定时器
        timerDuration = duration
        remainingTime = duration
        isTimerActive = true
        
        // 创建定时器，每秒更新一次
        delayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            
            if self.remainingTime > 0 {
                self.remainingTime -= 1
                
                // 如果剩余时间是整10秒，请求额外的后台执行时间
                if Int(self.remainingTime) % 10 == 0 {
                    self.extendBackgroundRunningTime()
                }
            } else {
                // 时间到，启动监测
                self.cancelDelayedMonitoring()
                _ = self.startMonitoring()
            }
        }
        
        // 确保定时器在后台也能运行
        RunLoop.current.add(delayTimer!, forMode: .common)
        
        // 请求系统提供额外的后台执行时间
        extendBackgroundRunningTime()
        
        // 注册本地通知，以防应用被系统终止
        scheduleTimerCompletionNotification(duration: duration)
    }
    
    // 取消定时器
    func cancelDelayedMonitoring() {
        delayTimer?.invalidate()
        delayTimer = nil
        isTimerActive = false
        remainingTime = 0
    }
    
    // 处理设置变更
    @objc private func handleSettingsChanged() {
        if UserSettings.shared.isRecordingStorageEnabled {
            // 如果启用了录音存储，重新加载录音
            loadRecordings()
        } else {
            // 如果禁用了录音存储，清空录音列表
            DispatchQueue.main.async {
                self.recordings = []
            }
        }
    }
    
    // 请求额外的后台执行时间
    private func extendBackgroundRunningTime() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
        }
        
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // 后台任务即将过期时的清理工作
            if let bgTask = self?.backgroundTask, bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                self?.backgroundTask = .invalid
            }
        }
    }
    
    // 安排定时器完成通知
    private func scheduleTimerCompletionNotification(duration: TimeInterval) {
        // 取消之前的通知
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // 请求通知权限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted else {
                print("通知权限被拒绝")
                return
            }
            
            // 创建通知内容
            let content = UNMutableNotificationContent()
            content.title = "睡眠监测已开始"
            content.body = "定时器已完成，睡眠监测已自动开始"
            content.sound = UNNotificationSound.default
            
            // 创建触发器（在定时器结束时触发）
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration + 1, repeats: false)
            
            // 创建通知请求
            let request = UNNotificationRequest(identifier: "timerCompletion", content: content, trigger: trigger)
            
            // 添加通知请求
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("添加通知失败: \(error.localizedDescription)")
                }
            }
        }
    }
}