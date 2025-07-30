import SwiftUI
import HealthKit
import AVFoundation
import CloudKit
import UIKit

struct ContentView: View {
    @ObservedObject var sleepDataManager: SleepDataManager
    @ObservedObject var recordingManager: RecordingManager
    @ObservedObject private var audioPlayer: AudioPlayer
    @State private var showingPermissionAlert = false
    @State private var permissionMessage = ""
    @State private var recentSleepData: [HKCategorySample]?
    @State private var showingTimerSettings = false
    @State private var showingSettings = false
    @State private var showCloudRecordings = false

init(sleepDataManager: SleepDataManager, recordingManager: RecordingManager) {
    self.sleepDataManager = sleepDataManager
    self.recordingManager = recordingManager
    self._audioPlayer = ObservedObject(wrappedValue: AudioPlayer())
    }

    // 监测控制按钮


    // 监测控制按钮
    private var monitoringControlButton: some View {
        Button(action: toggleMonitoring) {
            Text(recordingManager.isMonitoring ? "停止监测" : "开始睡眠监测")
                .frame(maxWidth: .infinity)
                .padding()
                .background(recordingManager.isMonitoring ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .font(.headline)
        }
    }

    var body: some View {
          NavigationView {
              VStack(spacing: 20) {
                // 录音控制按钮和定时器按钮
                HStack {
                    monitoringControlButton
                    
                    Button(action: {
                        showingTimerSettings.toggle()
                    }) {
                        Image(systemName: "timer")
                            .font(.system(size: 22))
                            .padding(10)
                            .background(Color(UIColor.systemBlue).opacity(0.2))
                            .clipShape(Circle())
                    }
                    .disabled(recordingManager.isMonitoring || recordingManager.isTimerActive)
                }
                
                
                // 定时器状态
                if recordingManager.isTimerActive {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundColor(.orange)
                        Text("将在 \(formatDuration(recordingManager.remainingTime)) 后开始监测")
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        Button(action: {
                            recordingManager.cancelDelayedMonitoring()
                        }) {
                            Text("取消")
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                
                
                // 声音波形显示（仅在监测时显示）
                if recordingManager.isMonitoring {
                    AudioVisualizationView(recordingManager: recordingManager)
                        .frame(height: 200)
                        .padding(.vertical)
                }
            

                // 最近检测到的音频片段
                if !recordingManager.recentSegments.isEmpty {
                    recentSegmentsList
                } else if !recordingManager.isMonitoring && !recordingManager.isTimerActive {
                    emptyStateView
                }
            

                Spacer()
                
                // 底部设置按钮
                Button(action: {
                    showingSettings = true
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("设置")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(10)
                }
                .padding(.bottom)
        .navigationBarTitle("睡眠声音监测")
            .navigationBarItems(trailing: Button(action: { showCloudRecordings.toggle() }) { HStack { Image(systemName: "icloud"); Text("录音记录") } })
            .alert(isPresented: $showingPermissionAlert) { Alert(title: Text("权限不足"), message: Text(permissionMessage), dismissButton: .default(Text("前往设置"), action: openSettings)) }
            .sheet(isPresented: $showCloudRecordings) { CloudRecordingsView(recordingManager: recordingManager) }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(isPresented: $showingTimerSettings) {
                VStack {
                    Text("设置延迟启动时间")
                        .font(.system(size: 17, weight: .semibold))
                        .padding()
                    TimerSettingView(
                        isTimerActive: $recordingManager.isTimerActive,
                        timerDuration: $recordingManager.timerDuration,
                        remainingTime: $recordingManager.remainingTime,
                        onTimerStart: { recordingManager.startDelayedMonitoring(duration: recordingManager.timerDuration); showingTimerSettings = false },
                        onTimerCancel: { recordingManager.cancelDelayedMonitoring(); showingTimerSettings = false }
                    )
                    .padding()
                    Button("关闭") { showingTimerSettings = false }
                    .padding()
                }
            }
            .onAppear {
                checkPermissions()
                fetchSleepData()
            }
        }
    }
}




    // 最近片段列表
    private var recentSegmentsList: some View {
        VStack(alignment: .leading) {
            Text("检测到的声音片段")
                .font(.system(size: 15))
                .foregroundColor(Color(UIColor.secondaryLabel))
            List(recordingManager.recentSegments.sorted(by: { $0.startTime > $1.startTime })) { segment in
                HStack {
                    Image(systemName: segment.type == .snore ? "waveform.circle.fill" : "mic.circle.fill")
                        .foregroundColor(segment.type == .snore ? .purple : .orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(segment.type == .snore ? "鼾声" : "梦话")
                            .font(.headline)
                        Text("时间: \(formatDate(segment.startTime))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("时长: \(formatDuration(segment.duration))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { playSegment(segment) }) {
                        Image(systemName: audioPlayer.isPlaying && audioPlayer.isPlayingURL(segment.url!) ? "pause.circle.fill" : "play.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    // 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "moon.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("尚未检测到声音片段")
                .foregroundColor(.secondary)
            Text("点击开始按钮开始睡眠监测")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 40)
    }

    // 切换监测状态
    private func toggleMonitoring() {
        if recordingManager.isMonitoring {
            recordingManager.stopMonitoring()
        } else {
            let success = recordingManager.startMonitoring()
            if !success {
                permissionMessage = "无法开始录音，请检查麦克风权限"
                showingPermissionAlert = true
            }
        }
    }

    // 检查权限
    private func checkPermissions() {
        sleepDataManager.requestHealthPermissions { success in
            if !success {
                DispatchQueue.main.async {
                    self.permissionMessage = "需要健康数据权限以分析睡眠状况"
                    self.showingPermissionAlert = true
                }
            }
        }
    }

    // 获取睡眠数据
    private func fetchSleepData() {
        sleepDataManager.fetchRecentSleepData { samples in
            DispatchQueue.main.async {
                self.recentSleepData = samples
            }
        }
    }

    // 播放片段
    private func playSegment(_ segment: AudioSegment) {
        if let url = segment.url {
            if audioPlayer.isPlayingURL(url) {
                // 如果当前正在播放这个片段，则暂停
                audioPlayer.pauseAudio(for: url)
            } else {
                // 如果当前没有播放这个片段，则播放它
                audioPlayer.playAudio(from: url)
            }
        }
    }

    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    // 格式化时长
    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    // 打开设置
    private func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// 预览
struct ContentView_Previews: PreviewProvider {
    static let healthStore = HKHealthStore()
    static let sleepDataManager = SleepDataManager(healthStore: healthStore)
    static let audioRecorder = AudioRecorder()
    static let audioClassifier = AudioClassifier()
    static let recordingManager = RecordingManager(audioRecorder: audioRecorder, audioClassifier: audioClassifier)

    static var previews: some View {
        ContentView(
            sleepDataManager: sleepDataManager,
            recordingManager: recordingManager
        )
    }
}