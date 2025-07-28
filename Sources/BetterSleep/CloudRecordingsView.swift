import SwiftUI
import AVFoundation

extension Notification.Name {
    static let recordingSavedSuccessfully = Notification.Name("recordingSavedSuccessfully")
    static let recordingSaveFailed = Notification.Name("recordingSaveFailed")
}

struct CloudRecordingsView: View {
    @ObservedObject var recordingManager: RecordingManager

    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedRecording: URL?
    @State private var showSaveSuccess = false
    @State private var showSaveError = false
    @State private var showSettings = false
    
    var body: some View {
        VStack {
            if !UserSettings.shared.isRecordingStorageEnabled {
                VStack(spacing: 20) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("录音存储功能已关闭")
                        .font(.headline)
                    
                    Text("您可以在设置中开启录音存储功能")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        showSettings = true
                    }) {
                        Text("前往设置")
                            .foregroundColor(.blue)
                    }
                    .padding()
                }
                .padding()
            } else if recordingManager.isStorageAvailable {
                if recordingManager.isSavingToStorage {
                    ProgressView("正在保存录音到\(recordingManager.storageType)...")
                        .padding()
                } else if recordingManager.recordings.isEmpty {
                    Text("没有找到录音")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(recordingManager.recordings, id: \.self) { url in
                            NavigationLink(destination: RecordingDetailView(recordingURL: url)) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(formatRecordingName(url: url))
                                            .font(.headline)
                                        
                                        Text(formatRecordingDate(url: url))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Image(systemName: "chevron.right")
                                    //     .foregroundColor(.blue)
                                    //     .font(.system(size: 14, weight: .bold))
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                Button(action: {
                    recordingManager.loadRecordings()
                }) {
                    Label("刷新录音列表", systemImage: "arrow.clockwise")
                }
                .padding()
            } else {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Text("存储不可用")
                        .font(.title)
                        .foregroundColor(.secondary)
                    
                    Text("无法访问存储，请检查应用权限设置")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding()
                }
                .padding()
            }
        }
        .navigationTitle("录音记录")
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("删除录音"),
                message: Text("确定要删除这个录音吗？此操作不可撤销。"),
                primaryButton: .destructive(Text("删除")) {
                    if let url = selectedRecording {
                        deleteRecording(url: url)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        
        .onAppear {
            // 监听保存成功通知
            NotificationCenter.default.addObserver(forName: .recordingSavedSuccessfully, object: nil, queue: .main) { _ in
                showSaveSuccess = true
            }
            
            // 监听保存失败通知
            NotificationCenter.default.addObserver(forName: .recordingSaveFailed, object: nil, queue: .main) { notification in
                if let errorMessage = notification.object as? String {
                    alertMessage = "保存录音失败: \(errorMessage)"
                } else {
                    alertMessage = "保存录音失败"
                }
                showAlert = true
            }
        }
        .onAppear {
            // 监听保存成功通知
            NotificationCenter.default.addObserver(forName: .recordingSavedSuccessfully, object: nil, queue: .main) { _ in
                showSaveSuccess = true
            }
            
            // 监听保存失败通知
            NotificationCenter.default.addObserver(forName: .recordingSaveFailed, object: nil, queue: .main) { notification in
                if let errorMessage = notification.object as? String {
                    alertMessage = "保存录音失败: \(errorMessage)"
                } else {
                    alertMessage = "保存录音失败"
                }
                showAlert = true
            }
        }
        .alert("录音保存成功", isPresented: $showSaveSuccess) {
            Button("确定") {}
        } message: {
            Text("录音已成功保存到\(recordingManager.storageType)")
        }
    }
    
    // 格式化录音名称
    private func formatRecordingName(url: URL) -> String {
        let fileName = url.lastPathComponent
        return fileName.replacingOccurrences(of: "sleep_recording_", with: "录音: ")
            .replacingOccurrences(of: ".m4a", with: "")
    }
    
    // 格式化录音日期
    private func formatRecordingDate(url: URL) -> String {
        let fileName = url.lastPathComponent
        if let dateString = fileName.components(separatedBy: "sleep_recording_").last?.replacingOccurrences(of: ".m4a", with: "") {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            
            if let date = formatter.date(from: dateString) {
                formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
                return formatter.string(from: date)
            }
        }
        return "未知日期"
    }
    
    // 删除录音
    private func deleteRecording(url: URL) {
        recordingManager.deleteRecording(url: url) { success in
            if !success {
                alertMessage = "删除录音失败"
                showAlert = true
            }
        }
    }
}

