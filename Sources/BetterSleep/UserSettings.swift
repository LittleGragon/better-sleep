import Foundation

// 用户设置管理类
class UserSettings {
    static let shared = UserSettings()
    
    // 设置键名
    private enum SettingsKeys {
        static let recordingStorageEnabled = "recordingStorageEnabled"
    }
    
    private let defaults = UserDefaults.standard
    
    private init() {
        // 设置默认值
        setupDefaultValues()
    }
    
    // 设置默认值
    private func setupDefaultValues() {
        let defaultValues: [String: Any] = [
            SettingsKeys.recordingStorageEnabled: true
        ]
        
        defaults.register(defaults: defaultValues)
    }
    
    // 录音存储是否启用
    var isRecordingStorageEnabled: Bool {
        get {
            return defaults.bool(forKey: SettingsKeys.recordingStorageEnabled)
        }
        set {
            defaults.set(newValue, forKey: SettingsKeys.recordingStorageEnabled)
        }
    }
}