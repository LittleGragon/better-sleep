import Foundation

enum AudioSegmentType: String, CaseIterable {
    case unknown = "未知"
    case snore = "鼾声"
    case sleepTalk = "梦话"
    case ambient = "环境音"
}

struct AudioSegment: Identifiable {
    let id = UUID()
    let url: URL?
    let startTime: Date
    let endTime: Date
    var type: AudioSegmentType
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}