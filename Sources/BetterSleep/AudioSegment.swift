import Foundation

// 音频片段类型枚举
enum AudioSegmentType: String, CaseIterable {
    case unknown = "未知"
    case snore = "鼾声"
    case sleepTalk = "梦话"
    case ambient = "环境音"
}

// 音频片段模型
struct AudioSegment: Identifiable {
    let id = UUID()
    let url: URL?
    let startTime: Date
    let endTime: Date
    var type: AudioSegmentType
    var confidence: Double = 0.0
    var transcription: String? = nil // 梦话转录文本
    var decibelLevel: Float = 0.0 // 分贝水平

    // 计算片段时长
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }

    // 格式化开始时间字符串
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: startTime)
    }

    // 初始化方法
    init(url: URL?, startTime: Date, endTime: Date, type: AudioSegmentType = .unknown) {
        self.url = url
        self.startTime = startTime
        self.endTime = endTime
        self.type = type
    }
}