import SwiftUI

struct AudioWaveformView: View {
    @Binding var levels: [Float]
    @Binding var progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景波形
                HStack(spacing: 2) {
                    ForEach(0..<levels.count, id: \.self) { index in
                        let height = CGFloat(levels[index]) * geometry.size.height
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 3, height: max(height, 1))
                    }
                }
                .frame(width: geometry.size.width)
                
                // 播放进度波形
                let progressIndex = Int(Double(levels.count) * progress)
                HStack(spacing: 2) {
                    ForEach(0..<progressIndex, id: \.self) { index in
                        let height = CGFloat(levels[index]) * geometry.size.height
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue.opacity(0.8))
                            .frame(width: 3, height: max(height, 1))
                    }
                }
                .frame(width: geometry.size.width * progress)
            }
        }
    }
}

struct DecibelMeterView: View {
    var currentDecibels: Float
    var color: Color = .blue
    
    var body: some View {
        VStack {
            Text("\(Int(currentDecibels)) dB")
                .font(.caption)
                .foregroundColor(.secondary)
            
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // 背景条
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    
                    // 当前分贝值条
                    RoundedRectangle(cornerRadius: 5)
                        .fill(decibelColor)
                        .frame(width: geometry.size.width, 
                               height: CGFloat(currentDecibels) * geometry.size.height / 100)
                }
            }
            .frame(height: 150)
            .animation(.easeInOut(duration: 0.2), value: currentDecibels)
        }
    }
    
    // 根据分贝值返回不同颜色
    private var decibelColor: Color {
        if currentDecibels < 30 {
            return .green
        } else if currentDecibels < 70 {
            return .yellow
        } else {
            return .red
        }
    }
}

struct AudioVisualizationView: View {
    @ObservedObject var recordingManager: RecordingManager
    
    var body: some View {
        VStack(spacing: 20) {
            // 分贝计
            DecibelMeterView(currentDecibels: recordingManager.currentDecibels)
                .frame(width: 60, height: 180)
                .padding(.horizontal)
            
            // 波形图
            AudioWaveformView(levels: .constant(recordingManager.audioLevels), progress: .constant(0.5))
                .frame(height: 80)
                .padding(.horizontal)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
}