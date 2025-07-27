import SwiftUI

struct TimerSettingView: View {
    @Binding var isTimerActive: Bool
    @Binding var timerDuration: TimeInterval
    @Binding var remainingTime: TimeInterval
    var onTimerStart: () -> Void
    var onTimerCancel: () -> Void
    
    let availableDurations: [TimeInterval] = [5*60, 10*60, 15*60, 20*60, 30*60, 45*60, 60*60]
    
    var body: some View {
        VStack(spacing: 20) {
            if isTimerActive {
                // 显示倒计时
                VStack {
                    Text("睡眠监测将在以下时间后启动")
                        .font(.headline)
                    
                    Text(timeString(from: remainingTime))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.blue)
                        .padding()
                    
                    Button(action: onTimerCancel) {
                        Text("取消")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            } else {
                // 选择定时器时长
                VStack {
                    Text("选择延迟启动时间")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(availableDurations, id: \.self) { duration in
                                Button(action: {
                                    timerDuration = duration
                                    onTimerStart()
                                }) {
                                    Text(timeString(from: duration))
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 10)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
    
    // 将时间间隔转换为格式化字符串
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}