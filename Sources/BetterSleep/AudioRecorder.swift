import AVFoundation

class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    var audioRecorder: AVAudioRecorder?
    private var recordingSession: AVAudioSession!
    private(set) var isRecording = false
    private(set) var currentRecordingURL: URL?

    override init() {
        super.init()
        setupAudioSession()
    }

    // 配置音频会话
    private func setupAudioSession() {
        recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers])
            try recordingSession.setActive(true, options: .notifyOthersOnDeactivation)
            // 设置后台音频会话
            NotificationCenter.default.addObserver(self, 
                                                  selector: #selector(handleInterruption), 
                                                  name: AVAudioSession.interruptionNotification, 
                                                  object: recordingSession)
            recordingSession.requestRecordPermission { [unowned self] allowed in
                DispatchQueue.main.async {
                    if allowed {
                        print("麦克风权限已授予")
                    } else {
                        print("麦克风权限被拒绝")
                    }
                }
            }
        } catch {
            print("音频会话配置失败: \(error.localizedDescription)")
        }
    }

    // 请求录音权限
    func requestRecordingPermissions(completion: @escaping (Bool) -> Void = { _ in }) {
        recordingSession.requestRecordPermission { allowed in
            DispatchQueue.main.async {
                completion(allowed)
            }
        }
    }

    // 开始录音
    func startRecording() -> Bool {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("sleep_recording_\(Date().timeIntervalSince1970).m4a")
        currentRecordingURL = audioFilename

        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true
            print("开始录音: \(audioFilename)")
            return true
        } catch {
            print("录音初始化失败: \(error.localizedDescription)")
            currentRecordingURL = nil
            return false
        }
    }

    // 停止录音
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        let url = currentRecordingURL
        currentRecordingURL = nil
        print("停止录音")
        return url
    }

    // 获取文档目录
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    // 录音完成回调
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("录音失败")
            currentRecordingURL = nil
        }
    }
    
    // 处理音频中断
    @objc private func handleInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .began {
            // 中断开始，保存当前状态
            print("音频会话被中断")
        } else if type == .ended {
            // 中断结束，恢复录音
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    print("恢复音频会话")
                    try? recordingSession.setActive(true, options: .notifyOthersOnDeactivation)
                    if isRecording && audioRecorder == nil {
                        _ = startRecording()
                    }
                }
            }
        }
    }
}