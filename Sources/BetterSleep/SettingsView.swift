import SwiftUI

struct SettingsView: View {
    @State private var isRecordingStorageEnabled: Bool = UserSettings.shared.isRecordingStorageEnabled
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("录音设置")) {
                    Toggle("保存录音文件", isOn: $isRecordingStorageEnabled)
                        .onChange(of: isRecordingStorageEnabled) { newValue in
                            UserSettings.shared.isRecordingStorageEnabled = newValue
                            
                            // 通知其他视图设置已更改
                            NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
                        }
                }
                
                Section(header: Text("关于"), footer: Text("录音文件将保存在本地存储中，您可以随时在设置中关闭此功能。")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarItems(trailing: Button("完成") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}