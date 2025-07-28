import SwiftUI
import HealthKit

struct SleepPhaseView: View {
    @State private var sleepPhases: [SleepPhaseData] = []
    @State private var totalSleepTime: TimeInterval = 0
    @State private var deepSleepPercentage: Double = 0
    @State private var remSleepPercentage: Double = 0
    @State private var lightSleepPercentage: Double = 0
    
    private let healthStore = HKHealthStore()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                Text("睡眠阶段")
                    .font(.headline)
                    .padding(.top, 5)
                
                Divider()
                
                // 睡眠时长
                HStack {
                    Text("总睡眠时长:")
                        .font(.caption)
                    Spacer()
                    Text(formatDuration(totalSleepTime))
                        .font(.body)
                        .fontWeight(.medium)
                }
                .padding(.horizontal)
                
                // 睡眠阶段图表
                VStack(spacing: 5) {
                    // 深睡眠
                    SleepPhaseBar(
                        phase: "深睡眠",
                        percentage: deepSleepPercentage,
                        color: .blue
                    )
                    
                    // REM睡眠
                    SleepPhaseBar(
                        phase: "快速眼动",
                        percentage: remSleepPercentage,
                        color: .purple
                    )
                    
                    // 浅睡眠
                    SleepPhaseBar(
                        phase: "浅睡眠",
                        percentage: lightSleepPercentage,
                        color: .green
                    )
                }
                .padding()
                .background(Color.black.opacity(0.2))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // 睡眠阶段时间线
                if !sleepPhases.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("睡眠阶段时间线")
                            .font(.caption)
                            .padding(.horizontal)
                        
                        SleepPhaseTimeline(phases: sleepPhases)
                            .frame(height: 80)
                            .padding(.horizontal)
                    }
                }
                
                // 睡眠质量评估
                VStack(alignment: .leading, spacing: 5) {
                    Text("睡眠质量评估")
                        .font(.caption)
                    
                    Text(sleepQualityAssessment())
                        .font(.body)
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .background(Color.black.opacity(0.2))
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
        .onAppear {
            fetchSleepPhaseData()
        }
    }
    
    // 获取睡眠阶段数据
    private func fetchSleepPhaseData() {
        // 模拟数据 - 在实际应用中，这些数据应该从HealthKit或自定义睡眠分析中获取
        let now = Date()
        let calendar = Calendar.current
        
        // 假设睡眠开始于8小时前
        guard let sleepStart = calendar.date(byAdding: .hour, value: -8, to: now) else { return }
        
        // 创建模拟的睡眠阶段数据
        var phases: [SleepPhaseData] = []
        var currentTime = sleepStart
        
        // 添加初始浅睡眠阶段 (30分钟)
        if let endTime = calendar.date(byAdding: .minute, value: 30, to: currentTime) {
            phases.append(SleepPhaseData(
                startTime: currentTime,
                endTime: endTime,
                phase: .light
            ))
            currentTime = endTime
        }
        
        // 添加深睡眠阶段 (90分钟)
        if let endTime = calendar.date(byAdding: .minute, value: 90, to: currentTime) {
            phases.append(SleepPhaseData(
                startTime: currentTime,
                endTime: endTime,
                phase: .deep
            ))
            currentTime = endTime
        }
        
        // 添加REM睡眠阶段 (60分钟)
        if let endTime = calendar.date(byAdding: .minute, value: 60, to: currentTime) {
            phases.append(SleepPhaseData(
                startTime: currentTime,
                endTime: endTime,
                phase: .rem
            ))
            currentTime = endTime
        }
        
        // 添加浅睡眠阶段 (60分钟)
        if let endTime = calendar.date(byAdding: .minute, value: 60, to: currentTime) {
            phases.append(SleepPhaseData(
                startTime: currentTime,
                endTime: endTime,
                phase: .light
            ))
            currentTime = endTime
        }
        
        // 添加深睡眠阶段 (90分钟)
        if let endTime = calendar.date(byAdding: .minute, value: 90, to: currentTime) {
            phases.append(SleepPhaseData(
                startTime: currentTime,
                endTime: endTime,
                phase: .deep
            ))
            currentTime = endTime
        }
        
        // 添加REM睡眠阶段 (30分钟)
        if let endTime = calendar.date(byAdding: .minute, value: 30, to: currentTime) {
            phases.append(SleepPhaseData(
                startTime: currentTime,
                endTime: endTime,
                phase: .rem
            ))
            currentTime = endTime
        }
        
        // 添加浅睡眠阶段 (30分钟)
        if let endTime = calendar.date(byAdding: .minute, value: 30, to: currentTime) {
            phases.append(SleepPhaseData(
                startTime: currentTime,
                endTime: endTime,
                phase: .light
            ))
        }
        
        // 更新状态
        self.sleepPhases = phases
        
        // 计算总睡眠时间和各阶段百分比
        calculateSleepMetrics(phases: phases)
    }
    
    // 计算睡眠指标
    private func calculateSleepMetrics(phases: [SleepPhaseData]) {
        var totalSleep: TimeInterval = 0
        var deepSleep: TimeInterval = 0
        var remSleep: TimeInterval = 0
        var lightSleep: TimeInterval = 0
        
        for phase in phases {
            let duration = phase.endTime.timeIntervalSince(phase.startTime)
            totalSleep += duration
            
            switch phase.phase {
            case .deep:
                deepSleep += duration
            case .rem:
                remSleep += duration
            case .light:
                lightSleep += duration
            default:
                break
            }
        }
        
        self.totalSleepTime = totalSleep
        
        // 计算百分比
        if totalSleep > 0 {
            self.deepSleepPercentage = deepSleep / totalSleep
            self.remSleepPercentage = remSleep / totalSleep
            self.lightSleepPercentage = lightSleep / totalSleep
        }
    }
    
    // 睡眠质量评估
    private func sleepQualityAssessment() -> String {
        // 根据深睡眠和REM睡眠的比例评估睡眠质量
        let deepSleepMinutes = deepSleepPercentage * totalSleepTime / 60
        let remSleepMinutes = remSleepPercentage * totalSleepTime / 60
        
        if deepSleepPercentage >= 0.25 && remSleepPercentage >= 0.2 {
            return "睡眠质量优秀。深睡眠和REM睡眠比例均衡，有助于身体恢复和记忆巩固。"
        } else if deepSleepPercentage >= 0.2 {
            return "睡眠质量良好。深睡眠充足，但REM睡眠略少，可能影响认知功能。"
        } else if remSleepPercentage >= 0.2 {
            return "睡眠质量一般。REM睡眠充足，但深睡眠不足，可能影响身体恢复。"
        } else {
            return "睡眠质量较差。深睡眠和REM睡眠均不足，建议调整睡眠习惯。"
        }
    }
    
    // 格式化时长
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%d小时%02d分钟", hours, minutes)
    }
}

// 睡眠阶段数据结构
struct SleepPhaseData {
    let startTime: Date
    let endTime: Date
    let phase: SleepPhase
}

// 睡眠阶段条形图组件
struct SleepPhaseBar: View {
    let phase: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        HStack {
            Text(phase)
                .font(.caption)
                .frame(width: 60, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 20)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: CGFloat(percentage) * geometry.size.width, height: 20)
                }
            }
            .frame(height: 20)
            
            Text(String(format: "%.0f%%", percentage * 100))
                .font(.caption)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// 睡眠阶段时间线组件
struct SleepPhaseTimeline: View {
    let phases: [SleepPhaseData]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 30)
                
                // 各睡眠阶段
                ForEach(0..<phases.count, id: \.self) { index in
                    let phase = phases[index]
                    let (xPosition, width) = calculatePositionAndWidth(
                        for: phase,
                        in: geometry.size.width
                    )
                    
                    Rectangle()
                        .fill(colorForPhase(phase.phase))
                        .frame(width: width, height: 30)
                        .position(x: xPosition, y: 15)
                }
                
                // 时间标记
                VStack(alignment: .leading) {
                    HStack {
                        ForEach(0..<5) { i in
                            Text(timeLabel(at: i, count: 5))
                                .font(.system(size: 8))
                                .frame(width: geometry.size.width / 5)
                        }
                    }
                    .offset(y: -20)
                    
                    Spacer()
                }
            }
        }
    }
    
    // 计算睡眠阶段在时间线上的位置和宽度
    private func calculatePositionAndWidth(for phase: SleepPhaseData, in totalWidth: CGFloat) -> (CGFloat, CGFloat) {
        guard let firstPhase = phases.first, let lastPhase = phases.last else {
            return (0, 0)
        }
        
        let totalDuration = lastPhase.endTime.timeIntervalSince(firstPhase.startTime)
        let phaseDuration = phase.endTime.timeIntervalSince(phase.startTime)
        let phaseStart = phase.startTime.timeIntervalSince(firstPhase.startTime)
        
        let width = CGFloat(phaseDuration / totalDuration) * totalWidth
        let xPosition = CGFloat(phaseStart / totalDuration) * totalWidth + width / 2
        
        return (xPosition, width)
    }
    
    // 根据睡眠阶段返回颜色
    private func colorForPhase(_ phase: SleepPhase) -> Color {
        switch phase {
        case .deep:
            return .blue
        case .rem:
            return .purple
        case .light:
            return .green
        case .awake:
            return .orange
        case .unknown:
            return .gray
        }
    }
    
    // 生成时间标签
    private func timeLabel(at index: Int, count: Int) -> String {
        guard let firstPhase = phases.first, let lastPhase = phases.last else {
            return ""
        }
        
        let totalDuration = lastPhase.endTime.timeIntervalSince(firstPhase.startTime)
        let segmentDuration = totalDuration / Double(count - 1)
        let time = firstPhase.startTime.addingTimeInterval(segmentDuration * Double(index))
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }
}

struct SleepPhaseView_Previews: PreviewProvider {
    static var previews: some View {
        SleepPhaseView()
    }
}