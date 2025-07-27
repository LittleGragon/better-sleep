import SwiftUI
import HealthKit
import AVFoundation
import BackgroundTasks

@main
struct SleepApp: App {
    private let healthStore = HKHealthStore()
    private let audioRecorder = AudioRecorder()
    private let sleepDataManager: SleepDataManager
    private let audioClassifier = AudioClassifier()
    private let recordingManager: RecordingManager

    init() {
        // 初始化健康数据管理器
        sleepDataManager = SleepDataManager(healthStore: healthStore)
        // 初始化录音管理器
        recordingManager = RecordingManager(audioRecorder: audioRecorder, audioClassifier: audioClassifier)
        // 请求必要的权限
        requestPermissions()
        // 配置后台任务
        configureBackgroundTasks()
    }
    
    // 配置后台任务
    private func configureBackgroundTasks() {
        // 设置应用程序以支持后台音频
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("设置音频会话失败: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                sleepDataManager: sleepDataManager,
                recordingManager: recordingManager
            )
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                // 应用进入后台时的处理
                if recordingManager.isMonitoring {
                    print("应用进入后台，继续监测中...")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // 应用回到前台时的处理
                if recordingManager.isMonitoring {
                    print("应用回到前台，继续监测中...")
                }
            }
        }
    }

    // 请求健康数据和麦克风权限
    private func requestPermissions() {
        sleepDataManager.requestHealthPermissions()
        audioRecorder.requestRecordingPermissions()
    }
}