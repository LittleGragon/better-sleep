import Foundation
import AVFoundation

class AudioSegmentManager {
    static let shared = AudioSegmentManager()
    
    private let fileManager = FileManager.default
    
    // 获取按日期组织的声音片段目录
    func getSegmentsDirectory() -> URL? {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let segmentsURL = documentsPath.appendingPathComponent("AudioSegments", isDirectory: true)
        
        do {
            if !fileManager.fileExists(atPath: segmentsURL.path) {
                try fileManager.createDirectory(at: segmentsURL, withIntermediateDirectories: true)
                print("已创建声音片段目录: \(segmentsURL.path)")
            }
        } catch {
            print("创建声音片段目录失败: \(error.localizedDescription)")
            return nil
        }
        
        return segmentsURL
    }
    
    // 创建按日期分类的子目录
    private func getDateDirectory(for date: Date) -> URL? {
        guard let segmentsDir = getSegmentsDirectory() else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        let dateDirectory = segmentsDir.appendingPathComponent(dateString, isDirectory: true)
        
        do {
            if !fileManager.fileExists(atPath: dateDirectory.path) {
                try fileManager.createDirectory(at: dateDirectory, withIntermediateDirectories: true)
            }
        } catch {
            print("创建日期目录失败: \(error.localizedDescription)")
            return nil
        }
        
        return dateDirectory
    }
    
    // 保存音频片段到指定日期目录
    func saveSegment(_ segment: AudioSegment, from sourceURL: URL, completion: @escaping (Bool, URL?) -> Void) {
        guard let dateDir = getDateDirectory(for: segment.startTime) else {
            completion(false, nil)
            return
        }
        
        // 生成文件名
        let formatter = DateFormatter()
        formatter.dateFormat = "HH-mm-ss"
        let timeString = formatter.string(from: segment.startTime)
        
        let typeName = segment.type.rawValue
        let fileName = "\(typeName)_\(timeString).m4a"
        let destinationURL = dateDir.appendingPathComponent(fileName)
        
        // 在后台队列中执行文件操作
        DispatchQueue.global(qos: .background).async {
            do {
                // 如果目标文件已存在，先删除它
                if self.fileManager.fileExists(atPath: destinationURL.path) {
                    try self.fileManager.removeItem(at: destinationURL)
                }
                
                // 复制文件到目标位置
                try self.fileManager.copyItem(at: sourceURL, to: destinationURL)
                
                DispatchQueue.main.async {
                    print("音频片段已保存: \(destinationURL.path)")
                    completion(true, destinationURL)
                }
            } catch {
                DispatchQueue.main.async {
                    print("保存音频片段失败: \(error.localizedDescription)")
                    completion(false, nil)
                }
            }
        }
    }
    
    // 获取指定日期的声音片段
    func getSegments(for date: Date, completion: @escaping ([AudioSegment]?) -> Void) {
        guard let dateDir = getDateDirectory(for: date) else {
            completion(nil)
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            do {
                let fileURLs = try self.fileManager.contentsOfDirectory(at: dateDir, includingPropertiesForKeys: nil)
                
                // 过滤出音频文件
                let audioFiles = fileURLs.filter { $0.pathExtension.lowercased() == "m4a" }
                
                // 创建AudioSegment对象
                var segments: [AudioSegment] = []
                
                for fileURL in audioFiles {
                    // 从文件名解析信息
                    let fileName = fileURL.deletingPathExtension().lastPathComponent
                    let components = fileName.components(separatedBy: "_")
                    
                    if components.count >= 2 {
                        let typeName = components[0]
                        let timeString = components[1]
                        
                        // 解析类型
                        var type: AudioSegmentType = .unknown
                        switch typeName {
                        case "鼾声":
                            type = .snore
                        case "梦话":
                            type = .sleepTalk
                        case "环境音":
                            type = .ambient
                        default:
                            break
                        }
                        
                        // 解析时间
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH-mm-ss"
                        
                        if let time = formatter.date(from: timeString) {
                            let calendar = Calendar.current
                            var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
                            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
                            
                            dateComponents.hour = timeComponents.hour
                            dateComponents.minute = timeComponents.minute
                            dateComponents.second = timeComponents.second
                            
                            if let startTime = calendar.date(from: dateComponents) {
                                let endTime = startTime.addingTimeInterval(10) // 假设片段时长为10秒
                                
                                let segment = AudioSegment(
                                    url: fileURL,
                                    startTime: startTime,
                                    endTime: endTime,
                                    type: type
                                )
                                segments.append(segment)
                            }
                        }
                    }
                }
                
                // 按时间排序
                segments.sort { $0.startTime < $1.startTime }
                
                DispatchQueue.main.async {
                    completion(segments)
                }
            } catch {
                DispatchQueue.main.async {
                    print("获取声音片段失败: \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }
    }
    
    // 同步获取指定日期的声音片段
    func getSegmentsSync(for date: Date) -> [AudioSegment] {
        guard let dateDir = getDateDirectory(for: date) else {
            return []
        }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: dateDir, includingPropertiesForKeys: nil)
            
            // 过滤出音频文件
            let audioFiles = fileURLs.filter { $0.pathExtension.lowercased() == "m4a" }
            
            // 创建AudioSegment对象
            var segments: [AudioSegment] = []
            
            for fileURL in audioFiles {
                // 从文件名解析信息
                let fileName = fileURL.deletingPathExtension().lastPathComponent
                let components = fileName.components(separatedBy: "_")
                
                if components.count >= 2 {
                    let typeName = components[0]
                    let timeString = components[1]
                    
                    // 解析类型
                    var type: AudioSegmentType = .unknown
                    switch typeName {
                    case "鼾声":
                        type = .snore
                    case "梦话":
                        type = .sleepTalk
                    case "环境音":
                        type = .ambient
                    default:
                        break
                    }
                    
                    // 解析时间
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH-mm-ss"
                    
                    if let time = formatter.date(from: timeString) {
                        let calendar = Calendar.current
                        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
                        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
                        
                        dateComponents.hour = timeComponents.hour
                        dateComponents.minute = timeComponents.minute
                        dateComponents.second = timeComponents.second
                        
                        if let startTime = calendar.date(from: dateComponents) {
                            let endTime = startTime.addingTimeInterval(10) // 假设片段时长为10秒
                            
                            let segment = AudioSegment(
                                url: fileURL,
                                startTime: startTime,
                                endTime: endTime,
                                type: type
                            )
                            segments.append(segment)
                        }
                    }
                }
            }
            
            // 按时间排序
            segments.sort { $0.startTime < $1.startTime }
            
            return segments
        } catch {
            print("获取声音片段失败: \(error.localizedDescription)")
            return []
        }
    }
    
    // 获取所有有声音片段的日期
    func getAvailableDates(completion: @escaping ([Date]?) -> Void) {
        guard let segmentsDir = getSegmentsDirectory() else {
            completion(nil)
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            do {
                let fileURLs = try self.fileManager.contentsOfDirectory(at: segmentsDir, includingPropertiesForKeys: nil)
                
                // 过滤出目录
                let directories = fileURLs.filter { url in
                    var isDirectory: ObjCBool = false
                    return self.fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
                }
                
                // 解析日期
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                
                var dates: [Date] = []
                for directory in directories {
                    let dateString = directory.lastPathComponent
                    if let date = formatter.date(from: dateString) {
                        dates.append(date)
                    }
                }
                
                // 按日期排序（最新的在前）
                dates.sort { $0 > $1 }
                
                DispatchQueue.main.async {
                    completion(dates)
                }
            } catch {
                DispatchQueue.main.async {
                    print("获取日期列表失败: \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }
    }
    
    // 同步获取所有有声音片段的日期
    func getAvailableDatesSync() -> [Date] {
        guard let segmentsDir = getSegmentsDirectory() else {
            return []
        }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: segmentsDir, includingPropertiesForKeys: nil)
            
            // 过滤出目录
            let directories = fileURLs.filter { url in
                var isDirectory: ObjCBool = false
                return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
            }
            
            // 解析日期
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            var dates: [Date] = []
            for directory in directories {
                let dateString = directory.lastPathComponent
                if let date = formatter.date(from: dateString) {
                    dates.append(date)
                }
            }
            
            // 按日期排序（最新的在前）
            dates.sort { $0 > $1 }
            
            return dates
        } catch {
            print("获取日期列表失败: \(error.localizedDescription)")
            return []
        }
    }
    
    // 删除指定日期的所有声音片段
    func deleteSegments(for date: Date, completion: @escaping (Bool) -> Void) {
        guard let dateDir = getDateDirectory(for: date) else {
            completion(false)
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            do {
                try self.fileManager.removeItem(at: dateDir)
                DispatchQueue.main.async {
                    completion(true)
                }
            } catch {
                DispatchQueue.main.async {
                    print("删除声音片段失败: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    // 同步删除指定日期的所有声音片段
    func deleteSegmentsSync(for date: Date) -> Bool {
        guard let dateDir = getDateDirectory(for: date) else {
            return false
        }
        
        do {
            try fileManager.removeItem(at: dateDir)
            return true
        } catch {
            print("删除声音片段失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // 删除指定的声音片段
    func deleteSegment(_ segment: AudioSegment, completion: @escaping (Bool) -> Void) {
        guard let url = segment.url else {
            completion(false)
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            do {
                try self.fileManager.removeItem(at: url)
                DispatchQueue.main.async {
                    completion(true)
                }
            } catch {
                DispatchQueue.main.async {
                    print("删除声音片段失败: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
}