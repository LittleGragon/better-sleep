import SwiftUI
import AVFoundation

struct ActivityIndicator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.startAnimating()
        return indicator
    }
    
    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {}
}

extension Notification.Name {
    static let recordingSavedSuccessfully = Notification.Name("recordingSavedSuccessfully")
    static let recordingSaveFailed = Notification.Name("recordingSaveFailed")
}

struct CloudRecordingsView: View {
    @ObservedObject var recordingManager: RecordingManager
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playingURL: URL?
    @State private var isPlaying = false
    @State private var playbackDelegate: PlaybackDelegate?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedRecording: URL?
    @State private var showSaveSuccess = false
    @State private var showSaveError = false
    @State private var showSettings = false
    
    var body: some View {
        VStack {
            if !UserSettings.shared.isRecordingStorageEnabled {
                VStack(spacing: 20) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("录音存储功能已关闭")
                        .font(.system(size: 17, weight: .semibold))
                    
                    Text("您可以在设置中开启录音存储功能")
                        .font(.system(size: 15))
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        showSettings = true
                    }) {
                        Text("前往设置")
                            .foregroundColor(.blue)
                    }
                    .padding()
                }
                .padding()
            } else if recordingManager.isStorageAvailable {
                if recordingManager.isSavingToStorage {
                    VStack {
    Text("正在保存录音到\(recordingManager.storageType)...")
    ActivityIndicator()
}
                        .padding()
                } else if recordingManager.recordings.isEmpty {
                    Text("没有找到录音")
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .padding()
                } else {
                    List {
                        ForEach(recordingManager.recordings, id: \.absoluteString) { url in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(formatRecordingName(url: url))
                                        .font(.system(size: 17, weight: .semibold))
                                    
                                    Text(formatRecordingDate(url: url))
                                        .font(.system(size: 15))
                                        .foregroundColor(Color(UIColor.secondaryLabel))
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    if playingURL == url && isPlaying {
                                        stopPlayback()
                                    } else {
                                        playRecording(url: url)
                                    }
                                }) {
                                    Image(systemName: (playingURL == url && isPlaying) ? "stop.circle" : "play.circle")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                                .padding(.trailing, 8) // 增加右侧间距
                                
                                Button(action: {
                                    deleteRecording(url: url)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                Button(action: {
                    recordingManager.loadRecordings()
                }) {
                    HStack {
    Image(systemName: "arrow.clockwise")
    Text("刷新录音列表")
}
                }
                .padding()
            } else {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Text("存储不可用")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Text("无法访问存储，请检查应用权限设置")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding()
                }
                .padding()
            }
        }
        .navigationBarTitle("录音记录")
        .alert(isPresented: $showAlert) {
    Alert(title: Text("删除录音"),
          message: Text("确定要删除这个录音吗？此操作不可撤销。"),
          primaryButton: .destructive(Text("删除"), action: {
              if let url = selectedRecording {
                  deleteRecording(url: url)
              }
          }),
          secondaryButton: .cancel())
}
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onDisappear {
            stopPlayback()
        }
        .onAppear {
            // 监听保存成功通知
            NotificationCenter.default.addObserver(forName: .recordingSavedSuccessfully, object: nil, queue: .main) { _ in
                showSaveSuccess = true
            }
            
            // 监听保存失败通知
            NotificationCenter.default.addObserver(forName: .recordingSaveFailed, object: nil, queue: .main) { notification in
                if let errorMessage = notification.object as? String {
                    alertMessage = "保存录音失败: \(errorMessage)"
                } else {
                    alertMessage = "保存录音失败"
                }
                showAlert = true
            }
        }
        .alert(isPresented: $showSaveSuccess) {
    Alert(
        title: Text("录音保存成功\n录音已成功保存到\(recordingManager.storageType)"),
        dismissButton: .default(Text("确定"))
    )
}
    }
    
    // 格式化录音名称
    private func formatRecordingName(url: URL) -> String {
        let fileName = url.lastPathComponent
        return fileName.replacingOccurrences(of: "sleep_recording_", with: "录音: ")
            .replacingOccurrences(of: ".m4a", with: "")
    }
    
    // 格式化录音日期
    private func formatRecordingDate(url: URL) -> String {
        let fileName = url.lastPathComponent
        if let dateString = fileName.components(separatedBy: "sleep_recording_").last?.replacingOccurrences(of: ".m4a", with: "") {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            
            if let date = formatter.date(from: dateString) {
                formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
                return formatter.string(from: date)
            }
        }
        return "未知日期"
    }
    
    // 播放录音
    private func playRecording(url: URL) {
        do {
            // 停止当前播放
            stopPlayback()
            
            // 设置音频会话
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 创建播放器
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            playbackDelegate = PlaybackDelegate(onComplete: {
                self.isPlaying = false
                self.playingURL = nil
            })
            audioPlayer?.delegate = playbackDelegate
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            playingURL = url
            isPlaying = true
        } catch {
            alertMessage = "播放录音失败: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    // 停止播放
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }
    
    // 删除录音
    private func deleteRecording(url: URL) {
        // 如果正在播放，先停止
        if playingURL == url {
            stopPlayback()
        }
        
        recordingManager.deleteRecording(url: url) { success in
            if !success {
                alertMessage = "删除录音失败"
                showAlert = true
            }
        }
    }
}

// 播放完成代理
class PlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    var onComplete: () -> Void
    
    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onComplete()
    }
}