import SwiftUI
import AVFoundation

struct RecordingDetailView: View {
    let recordingURL: URL
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var playbackProgress: Double = 0
    @State private var audioLevels: [Float] = []
    @State private var timer: Timer?
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 录音信息
            VStack(alignment: .leading, spacing: 8) {
                Text(formatRecordingName(url: recordingURL))
                    .font(.title2)
                    .bold()
                
                Text(formatRecordingDate(url: recordingURL))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            // 音频波形可视化（基于真实分贝数据）
            GeometryReader { geometry in
                AudioWaveformView(levels: $audioLevels, progress: $playbackProgress)
                    .frame(height: 200)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let progress = min(max(0, value.location.x / geometry.size.width), 1)
                                playbackProgress = progress
                                seekToProgress()
                            }
                    )
                    .onAppear {
                        // 加载音频文件并分析分贝数据
                        analyzeAudioFile()
                    }
            }
            .frame(height: 200)
            .padding(.horizontal)
            
            // 播放控制
            HStack(spacing: 30) {
                Button(action: rewind) {
                    Image(systemName: "gobackward.10")
                        .font(.title)
                }
                
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                }
                
                Button(action: forward) {
                    Image(systemName: "goforward.10")
                        .font(.title)
                }
            }
            .padding(.vertical)
            
            // 时间显示
            HStack {
                Text(formatTime(seconds: playbackProgress * (audioPlayer?.duration ?? 0)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatTime(seconds: audioPlayer?.duration ?? 0))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // 删除按钮
            Button(action: {
                showDeleteAlert = true
            }) {
                Label("删除录音", systemImage: "trash")
                    .foregroundColor(.red)
            }
            .padding()
        }
        .padding()
        .navigationTitle("录音详情")
        .alert("删除录音", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                // 删除逻辑将在父视图中处理
            }
        } message: {
            Text("确定要删除这个录音吗？此操作不可撤销。")
        }
        .onAppear {
            setupAudioPlayer()
        }
        .onDisappear {
            stopPlayback()
            timer?.invalidate()
        }
    }
    
    // 设置音频播放器
    private func setupAudioPlayer() {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: recordingURL)
            audioPlayer?.prepareToPlay()
            
            // 设置音频分析
            setupAudioAnalysis()
        } catch {
            print("初始化播放器失败: \(error.localizedDescription)")
        }
    }
    
    // 设置音频分析
    private func setupAudioAnalysis() {
        // 这里需要实现音频分析逻辑，获取音频电平数据
        if audioLevels.isEmpty {
            audioLevels = Array(repeating: 0.3, count: 100)
        }
        
        // 确保定时器在主线程上运行
        DispatchQueue.main.async {
            // 停止之前的定时器
            self.timer?.invalidate()
            
            // 创建新的定时器，更新播放进度
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                
                if isPlaying {
                    // 更新进度
                    if let player = audioPlayer {
                        playbackProgress = player.currentTime / player.duration
                    }
                    
                    // 更新音频电平
                    updateAudioLevels()
                }
            }
            
            // 确保定时器在主运行循环中运行
            RunLoop.main.add(self.timer!, forMode: .common)
        }
    }
    
    // 分析音频文件
    private func analyzeAudioFile() {
        guard let audioFile = try? AVAudioFile(forReading: recordingURL) else { return }
        
        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)
        let segmentSize = 1024
        
        // 读取音频数据
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        try? audioFile.read(into: buffer)
        
        // 计算分贝值
        var levels: [Float] = []
        if let channelData = buffer.floatChannelData?[0] {
            // 分段计算分贝
            for i in stride(from: 0, to: Int(frameCount), by: segmentSize) {
                let segmentEnd = min(i + segmentSize, Int(frameCount))
                var sum: Float = 0
                
                for j in i..<segmentEnd {
                    let sample = channelData[j]
                    sum += sample * sample
                }
                
                let rms = sqrt(sum / Float(segmentSize))
                let db = 20 * log10(rms)
                levels.append(normalizeDB(db))
            }
        }
        
        audioLevels = levels
    }
    
    // 标准化分贝值到0-1范围
    private func normalizeDB(_ db: Float) -> Float {
        let minDB: Float = -60
        let maxDB: Float = 0
        return min(max((db - minDB) / (maxDB - minDB), 0), 1)
    }
    
    // 更新音频电平
    private func updateAudioLevels() {
        // 实时更新当前播放位置的分贝值
        if isPlaying, let player = audioPlayer {
            let duration = Double(player.duration)
            let currentTime = Double(player.currentTime)
            let progress = currentTime / duration
            playbackProgress = progress
        }
    }
    
    // 切换播放/暂停
    private func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }
    
    // 开始播放
    private func startPlayback() {
        audioPlayer?.play()
        isPlaying = true
    }
    
    // 暂停播放
    private func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    // 停止播放
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        playbackProgress = 0
    }
    
    // 快退10秒
    private func rewind() {
        guard let player = audioPlayer else { return }
        player.currentTime = max(0, player.currentTime - 10)
    }
    
    // 快进10秒
    private func forward() {
        guard let player = audioPlayer else { return }
        player.currentTime = min(player.duration, player.currentTime + 10)
    }
    
    // 跳转到进度
    private func seekToProgress() {
        guard let player = audioPlayer else { return }
        player.currentTime = player.duration * playbackProgress
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
    
    // 格式化时间
    private func formatTime(seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
