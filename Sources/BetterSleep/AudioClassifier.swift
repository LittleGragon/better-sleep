import Foundation
import AVFoundation

import CoreML
import Speech
import SoundAnalysis

class AudioClassifier: NSObject {
    // 仅分析录音文件末尾的最近 N 秒
    private let tailSeconds: Double = 10.0

    // Core ML 声音分类模型（从 .mlmodelc 动态加载）
    private var mlModel: MLModel?
    private var speechRecognizer: SpeechRecognizer?

    override init() {
        super.init()
        setupModel()
        setupSpeechRecognizer()
    }

    // 加载模型（请确保已把 "Snoring 1.mlmodel" 加入到 App 目标，Xcode 会编译为 .mlmodelc）
    private func setupModel() {
        #if os(iOS)
        guard #available(iOS 13.0, *) else {
            print("SoundAnalysis 需要 iOS 13+")
            return
        }
        #endif
        let candidateNames = ["Snoring 1", "Snoring_1", "Snoring1"]
        for name in candidateNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
                do {
                    mlModel = try MLModel(contentsOf: url)
                    print("声音分类模型加载成功: \(name)")
                    return
                } catch {
                    print("加载模型失败(\(name)): \(error.localizedDescription)")
                }
            }
        }
        print("未在 Bundle 中找到 Snoring 模型(.mlmodelc)")
    }

    private func setupSpeechRecognizer() {
        speechRecognizer = SpeechRecognizer()
    }

    // 对音频片段进行分类：仅裁剪末尾 tailSeconds 秒后推理
    func classifyAudio(segment: AudioSegment, completion: @escaping (AudioSegment?) -> Void) {
        guard let audioURL = segment.url else {
            completion(nil)
            return
        }

        exportTailSegment(fileURL: audioURL, tailSeconds: tailSeconds) { [weak self] tailURL in
            guard let self = self else { return }
            let targetURL = tailURL ?? audioURL

            self.classifyWithSoundAnalysis(fileURL: targetURL) { label, confidence in
                let type = self.mapLabelToSegmentType(label: label, confidence: confidence)
                switch type {
                case .sleepTalk:
                    self.recognizeSpeech(in: audioURL, startTime: segment.startTime, endTime: segment.endTime) { _ in
                        var updated = segment
                        updated.type = .sleepTalk
                        completion(updated)
                    }
                case .snore:
                    var updated = segment
                    updated.type = .snore
                    completion(updated)
                case .ambient:
                    completion(nil)
                default:
                    completion(nil)
                }

                // 清理临时文件
                if let tailURL = tailURL {
                    try? FileManager.default.removeItem(at: tailURL)
                }
            }
        }
    }

    // 裁剪文件末尾 tailSeconds 秒到临时 .m4a（若失败则返回 nil）
    private func exportTailSegment(fileURL: URL, tailSeconds: Double, completion: @escaping (URL?) -> Void) {
        let asset = AVURLAsset(url: fileURL)
        let durationSec: Double = {
            if #available(iOS 16.0, *) {
                let sema = DispatchSemaphore(value: 0)
                var sec: Double = 0
                Task {
                    do {
                        let d = try await asset.load(.duration)
                        sec = CMTimeGetSeconds(d)
                    } catch {
                        print("加载资源时长失败: \(error.localizedDescription)")
                    }
                    sema.signal()
                }
                sema.wait()
                return sec
            } else {
                return CMTimeGetSeconds(asset.duration)
            }
        }()
        guard durationSec.isFinite, durationSec > 0 else {
            completion(nil)
            return
        }

        let startSec = max(0.0, durationSec - tailSeconds)
        let startTime = CMTime(seconds: startSec, preferredTimescale: 600)
        let durTime = CMTime(seconds: durationSec - startSec, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startTime, duration: durTime)

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            completion(nil)
            return
        }

        let outURL = FileManager.default.temporaryDirectory.appendingPathComponent("tail-\(UUID().uuidString).m4a")
        try? FileManager.default.removeItem(at: outURL)
        exporter.outputURL = outURL
        exporter.outputFileType = .m4a
        exporter.timeRange = timeRange
        if #available(iOS 18.0, *) {
            Task {
                do {
                    try await exporter.export(to: outURL, as: .m4a)
                    completion(outURL)
                } catch {
                    print("裁剪失败: \(error.localizedDescription)")
                    completion(nil)
                }
            }
        } else {
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed:
                    completion(outURL)
                default:
                    print("裁剪失败: \(exporter.error?.localizedDescription ?? "unknown")")
                    completion(nil)
                }
            }
        }
    }

    // 使用 SoundAnalysis 对文件做离线分类，返回最后一段的顶级标签与置信度
    private func classifyWithSoundAnalysis(fileURL: URL, completion: @escaping (String, Double) -> Void) {
        #if os(iOS)
        guard #available(iOS 13.0, *), let mlModel = self.mlModel else {
            completion("unknown", 0)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let analyzer = try SNAudioFileAnalyzer(url: fileURL)
                let request = try SNClassifySoundRequest(mlModel: mlModel)

                let observer = ClassificationObserver()
                try analyzer.add(request, withObserver: observer)

                analyzer.analyze()

                if let last = observer.lastResult,
                   let top = last.classifications.max(by: { $0.confidence < $1.confidence }) {
                    completion(top.identifier, Double(top.confidence))
                } else {
                    completion("unknown", 0)
                }
            } catch {
                print("声音分析失败: \(error.localizedDescription)")
                completion("unknown", 0)
            }
        }
        #else
        completion("unknown", 0)
        #endif
    }

    // 标签映射到片段类型（根据你的模型类别可调整）
    private func mapLabelToSegmentType(label: String, confidence: Double) -> AudioSegmentType {
        let l = label.lowercased()

        if l.contains("snore") || l.contains("snoring") || l.contains("鼾") {
            return confidence >= 0.6 ? .snore : .unknown
        }
        if l.contains("speech") || l.contains("talk") || l.contains("voice") || l.contains("说话") || l.contains("讲话") || l.contains("梦话") {
            return confidence >= 0.6 ? .sleepTalk : .unknown
        }
        if l.contains("ambient") || l.contains("noise") || l.contains("环境") {
            return confidence >= 0.7 ? .ambient : .unknown
        }
        return .unknown
    }

    // 语音识别(梦话内容)
    private func recognizeSpeech(in url: URL, startTime: Date, endTime: Date, completion: @escaping (String) -> Void) {
        guard let recognizer = speechRecognizer else {
            completion("")
            return
        }
        recognizer.recognizeSpeech(from: url, startTime: startTime, endTime: endTime) { result in
            completion(result)
        }
    }
}

#if os(iOS)
@available(iOS 13.0, *)
private final class ClassificationObserver: NSObject, SNResultsObserving {
    // 记录最后一帧结果
    private(set) var lastResult: SNClassificationResult?

    func request(_ request: SNRequest, didProduce result: SNResult) {
        if let r = result as? SNClassificationResult {
            lastResult = r
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("SoundAnalysis 请求失败: \(error.localizedDescription)")
    }

    func requestDidComplete(_ request: SNRequest) {
        // 完成
    }
}
#endif

// 语音识别器（保留原来实现）
class SpeechRecognizer: NSObject, AVAudioRecorderDelegate {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechURLRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    override init() {
        super.init()
        if #available(iOS 10.0, *) {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        }
    }

    func recognizeSpeech(from url: URL, startTime: Date, endTime: Date, completion: @escaping (String) -> Void) {
        guard #available(iOS 10.0, *), let recognizer = speechRecognizer, recognizer.isAvailable else {
            completion("语音识别不可用")
            return
        }

        recognitionTask?.cancel()
        self.recognitionTask = nil

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            var isFinal = false

            if let result = result {
                completion(result.bestTranscription.formattedString)
                isFinal = result.isFinal
            }

            if error != nil || isFinal {
                self.recognitionTask = nil
            }
        }
    }
}