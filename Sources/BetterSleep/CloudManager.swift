import Foundation

class CloudManager {
    static let shared = CloudManager()
    
    private let fileManager = FileManager.default
    // 暂时注释掉 iCloud 相关代码
    // private let ubiquityContainer = "iCloud.com.littlegragon.BetterSleep"
    // private var useLocalStorage = false
    
    private init() {
        setupLocalDirectory()
        // 暂时注释掉 iCloud 监听
        // startMonitoringCloudChanges()
    }
    
    // 设置本地目录
    private func setupLocalDirectory() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let recordingsURL = documentsPath.appendingPathComponent("Recordings", isDirectory: true)
        
        do {
            if !fileManager.fileExists(atPath: recordingsURL.path) {
                try fileManager.createDirectory(at: recordingsURL, withIntermediateDirectories: true)
                print("已创建本地录音目录: \(recordingsURL.path)")
            }
        } catch {
            print("创建本地目录失败: \(error.localizedDescription)")
        }
    }
    
    // 获取录音目录
    func getRecordingsDirectory() -> URL? {
        return getLocalRecordingsDirectory()
    }
    
    // 获取本地录音目录
    private func getLocalRecordingsDirectory() -> URL? {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("Recordings", isDirectory: true)
    }
    
    // 将录音文件保存到存储
    func saveRecordingToStorage(localURL: URL, completion: @escaping (URL?, Error?) -> Void) {
        // 暂时只使用本地存储
        saveToLocal(localURL: localURL, completion: completion)
    }
    
    // 保存到本地
    private func saveToLocal(localURL: URL, completion: @escaping (URL?, Error?) -> Void) {
        guard let localDirectory = getLocalRecordingsDirectory() else {
            completion(nil, NSError(domain: "CloudManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法访问本地存储目录"]))
            return
        }
        
        // 创建一个带有日期的文件名
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "sleep_recording_\(dateString).m4a"
        
        let destinationURL = localDirectory.appendingPathComponent(fileName)
        
        // 在后台队列中执行文件操作
        DispatchQueue.global(qos: .background).async {
            do {
                // 如果目标文件已存在，先删除它
                if self.fileManager.fileExists(atPath: destinationURL.path) {
                    try self.fileManager.removeItem(at: destinationURL)
                }
                
                // 复制文件到本地
                try self.fileManager.copyItem(at: localURL, to: destinationURL)
                
                DispatchQueue.main.async {
                    print("录音已保存到本地: \(destinationURL.path)")
                    completion(destinationURL, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    print("保存录音到本地失败: \(error.localizedDescription)")
                    completion(nil, error)
                }
            }
        }
    }
    
    // 获取所有录音文件
    func getAllRecordings(completion: @escaping ([URL]?, Error?) -> Void) {
        // 暂时只从本地获取
        getLocalRecordings(completion: completion)
    }
    
    // 获取本地录音
    private func getLocalRecordings(completion: @escaping ([URL]?, Error?) -> Void) {
        guard let localDirectory = getLocalRecordingsDirectory() else {
            completion(nil, NSError(domain: "CloudManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法访问本地存储目录"]))
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            do {
                // 获取目录中的所有文件
                let fileURLs = try self.fileManager.contentsOfDirectory(at: localDirectory, includingPropertiesForKeys: nil)
                
                // 过滤出音频文件
                let audioFiles = fileURLs.filter { $0.pathExtension.lowercased() == "m4a" }
                
                // 按日期排序
                let sortedRecordings = audioFiles.sorted { url1, url2 in
                    let date1 = self.getDateFromURL(url1) ?? Date.distantPast
                    let date2 = self.getDateFromURL(url2) ?? Date.distantPast
                    return date1 > date2
                }
                
                DispatchQueue.main.async {
                    completion(sortedRecordings, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    print("获取本地录音失败: \(error.localizedDescription)")
                    completion(nil, error)
                }
            }
        }
    }
    
    // 从URL中提取日期
    private func getDateFromURL(_ url: URL) -> Date? {
        let fileName = url.lastPathComponent
        if let dateString = fileName.components(separatedBy: "sleep_recording_").last?.replacingOccurrences(of: ".m4a", with: "") {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            return formatter.date(from: dateString)
        }
        return nil
    }
    
    // 删除录音文件
    func deleteRecording(url: URL, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                try self.fileManager.removeItem(at: url)
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    print("删除录音失败: \(error.localizedDescription)")
                    completion(false, error)
                }
            }
        }
    }
    
    // 检查存储权限状态
    func checkStoragePermissions() -> (isAvailable: Bool, errorMessage: String?, storageType: String) {
        // 检查本地存储是否可用
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let localDirectory = documentsPath.appendingPathComponent("Recordings", isDirectory: true)
        
        if fileManager.fileExists(atPath: localDirectory.path) {
            return (true, nil, "本地存储")
        }
        
        return (true, nil, "本地存储") // 本地存储总是可用的
    }
    
    // 获取当前存储类型
    func getStorageType() -> String {
        return "本地存储"
    }
    
    // 暂时注释掉 iCloud 相关方法
    /*
    // 检查iCloud是否可用
    func isCloudAvailable() -> Bool {
        return fileManager.ubiquityIdentityToken != nil
    }
    
    // 监听iCloud状态变化
    func startMonitoringCloudChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ubiquityIdentityDidChange),
            name: NSNotification.Name.NSUbiquityIdentityDidChange,
            object: nil
        )
    }
    
    @objc private func ubiquityIdentityDidChange(_ notification: Notification) {
        let isAvailable = isCloudAvailable()
        print("iCloud状态变化: \(isAvailable ? "可用" : "不可用")")
        
        // 重新设置存储方式
        setupStorage()
    }
    */
}