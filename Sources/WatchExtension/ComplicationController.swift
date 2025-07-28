import ClockKit
import HealthKit

class ComplicationController: NSObject, CLKComplicationDataSource {
    // 健康存储
    private let healthStore = HKHealthStore()
    
    // 提供当前时间点的表盘复杂功能数据
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        // 获取最近的睡眠数据
        fetchRecentSleepData { sleepDuration in
            // 创建表盘复杂功能的模板
            let template = self.createTemplate(for: complication, sleepDuration: sleepDuration)
            
            // 如果成功创建模板，则创建时间线条目
            if let template = template {
                let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
                handler(entry)
            } else {
                handler(nil)
            }
        }
    }
    
    // 支持的表盘复杂功能系列
    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([])
    }
    
    // 获取表盘复杂功能的隐私行为
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }
    
    // 获取表盘复杂功能的占位符模板
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        let template = createTemplate(for: complication, sleepDuration: 7 * 3600) // 7小时作为示例
        handler(template)
    }
    
    // 创建表盘复杂功能模板
    private func createTemplate(for complication: CLKComplication, sleepDuration: TimeInterval) -> CLKComplicationTemplate? {
        // 格式化睡眠时长
        let hours = Int(sleepDuration) / 3600
        let minutes = (Int(sleepDuration) % 3600) / 60
        let sleepText = String(format: "%dh %dm", hours, minutes)
        
        // 根据复杂功能系列创建不同的模板
        switch complication.family {
        case .modularSmall:
            let template = CLKComplicationTemplateModularSmallStackText()
            template.line1TextProvider = CLKSimpleTextProvider(text: "睡眠")
            template.line2TextProvider = CLKSimpleTextProvider(text: sleepText)
            return template
            
        case .modularLarge:
            let template = CLKComplicationTemplateModularLargeStandardBody()
            template.headerTextProvider = CLKSimpleTextProvider(text: "睡眠时长")
            template.body1TextProvider = CLKSimpleTextProvider(text: sleepText)
            return template
            
        case .utilitarianSmall:
            let template = CLKComplicationTemplateUtilitarianSmallFlat()
            template.textProvider = CLKSimpleTextProvider(text: "睡眠: " + sleepText)
            return template
            
        case .utilitarianLarge:
            let template = CLKComplicationTemplateUtilitarianLargeFlat()
            template.textProvider = CLKSimpleTextProvider(text: "睡眠时长: " + sleepText)
            return template
            
        case .circularSmall:
            let template = CLKComplicationTemplateCircularSmallStackText()
            template.line1TextProvider = CLKSimpleTextProvider(text: "睡眠")
            template.line2TextProvider = CLKSimpleTextProvider(text: sleepText)
            return template
            
        case .extraLarge:
            let template = CLKComplicationTemplateExtraLargeStackText()
            template.line1TextProvider = CLKSimpleTextProvider(text: "睡眠")
            template.line2TextProvider = CLKSimpleTextProvider(text: sleepText)
            return template
            
        case .graphicCorner:
            let template = CLKComplicationTemplateGraphicCornerStackText()
            template.innerTextProvider = CLKSimpleTextProvider(text: "睡眠")
            template.outerTextProvider = CLKSimpleTextProvider(text: sleepText)
            return template
            
        case .graphicBezel:
            let circularTemplate = CLKComplicationTemplateGraphicCircularView()
            circularTemplate.complicationName = "睡眠"
            
            let gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: .blue, fillFraction: min(Float(sleepDuration) / (8 * 3600), 1.0))
            circularTemplate.gaugeProvider = gaugeProvider
            
            let template = CLKComplicationTemplateGraphicBezelCircularText()
            template.circularTemplate = circularTemplate
            template.textProvider = CLKSimpleTextProvider(text: "睡眠时长: " + sleepText)
            return template
            
        case .graphicCircular:
            let template = CLKComplicationTemplateGraphicCircularView()
            template.complicationName = "睡眠"
            
            let gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: .blue, fillFraction: min(Float(sleepDuration) / (8 * 3600), 1.0))
            template.gaugeProvider = gaugeProvider
            return template
            
        case .graphicRectangular:
            let template = CLKComplicationTemplateGraphicRectangularStandardBody()
            template.headerTextProvider = CLKSimpleTextProvider(text: "睡眠时长")
            template.body1TextProvider = CLKSimpleTextProvider(text: sleepText)
            
            // 计算睡眠质量
            var qualityText = "未知"
            if sleepDuration >= 7 * 3600 {
                qualityText = "优"
            } else if sleepDuration >= 6 * 3600 {
                qualityText = "良"
            } else if sleepDuration >= 5 * 3600 {
                qualityText = "中"
            } else if sleepDuration > 0 {
                qualityText = "差"
            }
            
            template.body2TextProvider = CLKSimpleTextProvider(text: "质量: " + qualityText)
            return template
            
        @unknown default:
            return nil
        }
    }
    
    // 获取最近的睡眠数据
    private func fetchRecentSleepData(completion: @escaping (TimeInterval) -> Void) {
        guard HKHealthStore.isHealthDataAvailable(),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(0)
            return
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else {
            completion(0)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: 10,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            if let error = error {
                print("获取睡眠数据失败: \(error.localizedDescription)")
                completion(0)
                return
            }
            
            guard let samples = samples as? [HKCategorySample] else {
                completion(0)
                return
            }
            
            // 计算最近一次睡眠的时长
            if let lastSleep = samples.first {
                let duration = lastSleep.endDate.timeIntervalSince(lastSleep.startDate)
                completion(duration)
            } else {
                completion(0)
            }
        }
        
        healthStore.execute(query)
    }
}