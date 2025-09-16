import SwiftUI

struct AudioSegmentsView: View {
    @State private var availableDates: [Date] = []
    @State private var selectedDate: Date?
    @State private var segments: [AudioSegment] = []
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    VStack {
                        ProgressView("加载中...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    }
                } else {
                    if availableDates.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("暂无声音片段")
                                .font(.system(size: 17, weight: .semibold))
                            
                            Text("开始睡眠监测后，检测到的声音片段将按日期保存在这里")
                                .font(.system(size: 15))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding()
                    } else {
                        // 日期列表
                        List {
                            ForEach(availableDates, id: \.self) { date in
                                Section(header: 
                                    HStack {
                                        Text(formatDateHeader(date))
                                            .font(.system(size: 17, weight: .semibold))
                                        Spacer()
                                        Button(action: {
                                            deleteSegments(for: date)
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                    }
                                ) {
                                    if selectedDate == date {
                                        ForEach(segments, id: \.id) { segment in
                                            AudioSegmentRowView(segment: segment, audioPlayer: audioPlayer)
                                        }
                                    } else {
                                        Button(action: {
                                            loadSegments(for: date)
                                        }) {
                                            HStack {
                                                Text("查看 \(segments.count) 个片段")
                                                    .foregroundColor(.blue)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(.gray)
                                            }
                                            .padding(.vertical, 8)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("声音片段", displayMode: .large)
            .onAppear {
                loadAvailableDates()
            }
        }
    }
    
    // 加载可用日期
    private func loadAvailableDates() {
        isLoading = true
        // 使用RecordingManager中的方法
        DispatchQueue.global().async {
            let dates = RecordingManager().getAvailableDates()
            DispatchQueue.main.async {
                self.availableDates = dates
                self.isLoading = false
                
                // 默认加载最新的日期
                if let latestDate = dates.first {
                    self.loadSegments(for: latestDate)
                }
            }
        }
    }
    
    // 加载指定日期的声音片段
    private func loadSegments(for date: Date) {
        selectedDate = date
        isLoading = true
        // 使用RecordingManager中的方法
        DispatchQueue.global().async {
            let segments = RecordingManager().getSegments(for: date)
            DispatchQueue.main.async {
                self.segments = segments
                self.isLoading = false
            }
        }
    }
    
    // 删除指定日期的所有声音片段
    private func deleteSegments(for date: Date) {
        let alert = UIAlertController(title: "删除确认", message: "确定要删除 \(formatDateHeader(date)) 的所有声音片段吗？此操作不可撤销。", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { _ in
            // 使用RecordingManager中的方法
            DispatchQueue.global().async {
                let success = RecordingManager().deleteSegments(for: date)
                DispatchQueue.main.async {
                    if success {
                        // 从列表中移除日期
                        self.availableDates.removeAll { $0 == date }
                        
                        // 如果删除的是当前选中的日期，清空片段列表
                        if self.selectedDate == date {
                            self.segments = []
                            self.selectedDate = nil
                        }
                    } else {
                        print("删除失败")
                    }
                }
            }
        })
        
        // 显示警告框
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let root = window.rootViewController {
            var topController = root
            while let presented = topController.presentedViewController {
                topController = presented
            }
            topController.present(alert, animated: true)
        }
    }
    
    // 格式化日期标题
    private func formatDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// 音频片段行视图
struct AudioSegmentRowView: View {
    let segment: AudioSegment
    @ObservedObject var audioPlayer: AudioPlayer
    
    var body: some View {
        HStack {
            Image(systemName: segment.type == .snore ? "waveform.circle.fill" : "mic.circle.fill")
                .foregroundColor(segment.type == .snore ? .purple : .orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(segment.type == .snore ? "鼾声" : (segment.type == .sleepTalk ? "梦话" : "环境音"))
                    .font(.headline)
                Text("时间: \(formatTime(segment.startTime))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("时长: \(formatDuration(segment.duration))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: {
                playSegment()
            }) {
                Image(systemName: isPlaying() ? "pause.circle.fill" : "play.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title)
            }
        }
        .padding(.vertical, 8)
    }
    
    // 播放片段
    private func playSegment() {
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
    
    // 检查是否正在播放
    private func isPlaying() -> Bool {
        if let url = segment.url {
            return audioPlayer.isPlayingURL(url)
        }
        return false
    }
    
    // 格式化时间
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // 格式化时长
    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

struct AudioSegmentsView_Previews: PreviewProvider {
    static var previews: some View {
        AudioSegmentsView()
    }
}