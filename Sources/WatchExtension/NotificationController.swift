import WatchKit
import SwiftUI
import UserNotifications

class NotificationController: WKUserNotificationHostingController<NotificationView> {
    var title: String?
    var message: String?
    var sleepDuration: TimeInterval?
    
    override var body: NotificationView {
        return NotificationView(
            title: title ?? "睡眠提醒",
            message: message ?? "查看您的睡眠数据",
            sleepDuration: sleepDuration ?? 0
        )
    }
    
    override func willActivate() {
        // 当控制器即将激活时调用
        super.willActivate()
    }
    
    override func didDeactivate() {
        // 当控制器停用时调用
        super.didDeactivate()
    }
    
    override func didReceive(_ notification: UNNotification) {
        // 从通知中提取数据
        let content = notification.request.content
        
        // 设置标题和消息
        self.title = content.title
        self.message = content.body
        
        // 提取睡眠时长（如果有）
        if let durationString = content.userInfo["sleepDuration"] as? String,
           let duration = Double(durationString) {
            self.sleepDuration = duration
        }
        
        // 更新视图
        super.didReceive(notification)
    }
}

struct NotificationView: View {
    var title: String
    var message: String
    var sleepDuration: TimeInterval
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 30))
                .foregroundColor(.blue)
                .padding(.bottom, 5)
            
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            if sleepDuration > 0 {
                Divider()
                    .padding(.vertical, 5)
                
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.green)
                    
                    Text(formatDuration(sleepDuration))
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                }
                .padding(.top, 5)
            }
        }
        .padding()
    }
    
    // 格式化时长
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%d小时%02d分钟", hours, minutes)
    }
}