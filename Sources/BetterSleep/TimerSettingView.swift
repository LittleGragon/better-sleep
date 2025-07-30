import SwiftUI

@available(iOS 13.0, *)
struct TimerSettingView: View {
    @Binding var isTimerActive: Bool
    @Binding var timerDuration: TimeInterval
    @Binding var remainingTime: TimeInterval
    var onTimerStart: () -> Void
    var onTimerCancel: () -> Void
    
    let availableDurations: [TimeInterval] = [5*60, 10*60, 15*60, 20*60, 30*60, 45*60, 60*60, 90*60, 120*60]
    
    var body: some View {
        VStack(spacing: 24) {
            if isTimerActive {
                VStack(spacing: 24) {
                    Text("即将开始睡眠监测")
                        .font(.system(size: 22, weight: .semibold))
                    
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: CGFloat(remainingTime / timerDuration))
                            .stroke(Color(UIColor.systemBlue), lineWidth: 10)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1))
                        Text(timeString(from: remainingTime))
                            .font(.system(size: 40, weight: .bold))
                            
                    }
                    .frame(width: 200, height: 200)
                    
                    Button(action: { withAnimation { onTimerCancel() } }) {
                        Text("取消")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(UIColor.systemRed))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.1), radius: 10)
            } else {
                VStack(spacing: 20) {
                    Text("选择延迟启动时间")
                        .font(.system(size: 22, weight: .semibold))
                    
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            ForEach(Array(availableDurations[0..<3]), id: \.self) { duration in
                                Button(action: {
                                    timerDuration = duration
                                    onTimerStart()
                                }) {
                                    Text(timeString(from: duration))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(UIColor.systemBackground))
                                        .foregroundColor(Color(UIColor.systemBlue))
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(UIColor.systemBlue), lineWidth: 2))
                                }
                                
                            }
                        }
                        HStack(spacing: 16) {
                            ForEach(Array(availableDurations[3..<6]), id: \.self) { duration in
                                Button(action: {
                                    timerDuration = duration
                                    onTimerStart()
                                }) {
                                    Text(timeString(from: duration))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(UIColor.systemBackground))
                                        .foregroundColor(Color(UIColor.systemBlue))
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(UIColor.systemBlue), lineWidth: 2))
                                }
                                
                            }
                        }
                        HStack(spacing: 16) {
                            ForEach(Array(availableDurations[6..<9]), id: \.self) { duration in
                                Button(action: {
                                    timerDuration = duration
                                    onTimerStart()
                                }) {
                                    Text(timeString(from: duration))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(UIColor.systemBackground))
                                        .foregroundColor(Color(UIColor.systemBlue))
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(UIColor.systemBlue), lineWidth: 2))
                                }
                                
                            }
                        }
                    }
                    
                    VStack(spacing: 16) {
                        Text("自定义时间: \(timeString(from: timerDuration))")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                        
                        Slider(value: $timerDuration, in: 5*60...180*60)
                            .foregroundColor(Color(UIColor.systemBlue))
                    }
                    
                    Button(action: { onTimerStart() }) {
                        Text("开始倒计时")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(UIColor.systemBlue))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.1), radius: 10)
            }
        }
        .padding()
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}