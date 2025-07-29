import SwiftUI

struct AudioWaveformView: View {
    var audioLevels: [Float]
    var color: Color = .blue
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<audioLevels.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: (geometry.size.width / CGFloat(audioLevels.count)) - 2, 
                               height: CGFloat(audioLevels[index]) * geometry.size.height / 100)
                }
            }
            .frame(height: geometry.size.height)
            .animation(.easeInOut(duration: 0.2), value: audioLevels)
        }
    }
}

struct DecibelMeterView: View {
    var currentDecibels: Float
    var color: Color = .blue
    
    var body: some View {
        VStack {
            Text("\(Int(currentDecibels))%")
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
            AudioWaveformView(audioLevels: recordingManager.audioLevels, color: .blue)
                .frame(height: 80)
                .padding(.horizontal)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
}