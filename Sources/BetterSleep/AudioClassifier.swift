import Foundation
import AVFoundation


import CoreML
import Speech
import Accelerate

// Temporary placeholder models until actual .mlmodel is added
struct SoundClassifierModelInput {
    var audio: MLMultiArray
}

class SoundClassifierModel {
    static func load() throws -> SoundClassifierModel {
        return SoundClassifierModel()
    }
    func prediction(input: SoundClassifierModelInput) -> SoundClassifierModelOutput {
        // 模拟分类结果 - 随机返回不同的声音类型
        let random = Double.random(in: 0...1)
        var classLabel = "unknown"
        var probs: [String: Double] = [:]
        
        if random < 0.4 {
            classLabel = "snore"
            probs = ["snore": 0.8, "speech": 0.1, "ambient": 0.1]
        } else if random < 0.7 {
            classLabel = "speech"
            probs = ["snore": 0.1, "speech": 0.7, "ambient": 0.2]
        } else if random < 0.9 {
            classLabel = "ambient"
            probs = ["snore": 0.05, "speech": 0.05, "ambient": 0.9]
        } else {
            classLabel = "unknown"
            probs = ["snore": 0.3, "speech": 0.3, "ambient": 0.4]
        }
        
        return SoundClassifierModelOutput(classLabel: classLabel, classLabelProbs: probs)
    }
}

struct SoundClassifierModelOutput {
    let classLabel: String
    let classLabelProbs: [String: Double]
}

class AudioClassifier: NSObject {
    // 音频特征提取参数
    private let sampleRate: Double = 44100
    private let bufferSize: Int = 1024
    private let hopSize: Int = 512
    private let numMelBands: Int = 40
    private let numMFCCs: Int = 13
    private let frameDuration: TimeInterval = 0.5 // 每帧分析时长(秒)

    // Core ML模型
    private var soundClassifierModel: SoundClassifierModel?
    private var speechRecognizer: SpeechRecognizer?

    override init() {
        super.init()
        setupModels()
        setupSpeechRecognizer()
    }

    // 初始化模型
    private func setupModels() {
        // 加载声音分类模型
        do {
            soundClassifierModel = try SoundClassifierModel.load()
            print("声音分类模型加载成功")
        } catch {
            print("声音分类模型加载失败: \(error.localizedDescription)")
            // 实际项目中应提供默认模型或下载机制
        }
    }

    // 初始化语音识别器
    private func setupSpeechRecognizer() {
        speechRecognizer = SpeechRecognizer()
    }

    // 分类音频片段
    func classifyAudio(segment: AudioSegment, completion: @escaping (AudioSegment?) -> Void) {
        guard let audioURL = segment.url else {
            completion(nil)
            return
        }

        // 1. 提取音频特征
        extractAudioFeatures(from: audioURL, startTime: segment.startTime, endTime: segment.endTime) { [weak self] features in
            guard let self = self, let features = features else {
                completion(nil)
                return
            }

            // 2. 使用Core ML模型分类
            self.predictSoundType(with: features) { soundType in
                switch soundType {
                case .sleepTalk:
                    // 3. 如果是梦话，进行语音识别
                    self.recognizeSpeech(in: audioURL, startTime: segment.startTime, endTime: segment.endTime) { transcription in
                        var updatedSegment = segment
                        updatedSegment.type = .sleepTalk
                        // 可以在这里添加梦话文本信息
                        completion(updatedSegment)
                    }
                case .snore:
                    var updatedSegment = segment
                    updatedSegment.type = .snore
                    completion(updatedSegment)
                default:
                    completion(nil)
                }
            }
        }
    }

    // 提取音频特征
    private func extractAudioFeatures(from url: URL, startTime: Date, endTime: Date, completion: @escaping (MLMultiArray?) -> Void) {
        // 实际实现中需要:
        // 1. 从完整录音中提取指定时间段的音频
        // 2. 转换为PCM格式
        // 3. 计算MFCC特征
        // 4. 格式化为Core ML输入格式

        // 简化实现 - 实际项目需完善特征提取逻辑
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            // 创建模拟特征数据(实际项目需替换为真实特征提取)
            do {
                let shape = [1, self.numMFCCs, 10] as [NSNumber]
                let features = try MLMultiArray(shape: shape, dataType: .double)
                
                // 填充一些随机值，模拟真实特征
                for i in 0..<features.count {
                    features[i] = NSNumber(value: Double.random(in: -1...1))
                }
                
                completion(features)
            } catch {
                print("特征提取失败: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    // 预测声音类型
    private func predictSoundType(with features: MLMultiArray, completion: @escaping (AudioSegmentType) -> Void) {
        guard let model = soundClassifierModel else {
            completion(.unknown)
            return
        }

        let shape = [features.count, 1].map { NSNumber(value: $0) }
        guard let audioArray = try? MLMultiArray(shape: shape, dataType: .float32) else {
            print("Failed to create MLMultiArray")
            completion(.unknown)
            return
        }
        for i in 0..<features.count {
            audioArray[[i, 0] as [NSNumber]] = features[i]
        }
        let input = SoundClassifierModelInput(audio: audioArray)

        do {
            let output = model.prediction(input: input)
            let topPrediction = output.classLabelProbs.max(by: { $0.value < $1.value })
            let snoreProbability = topPrediction?.key == "snore" ? topPrediction?.value ?? 0 : 0
        let speechProbability = topPrediction?.key == "speech" ? topPrediction?.value ?? 0 : 0
            let ambientProbability = topPrediction?.key == "ambient" ? topPrediction?.value ?? 0 : 0

            // 根据概率判断声音类型
            if snoreProbability > 0.7 {
                completion(.snore)
            } else if speechProbability > 0.6 {
                completion(.sleepTalk)
            } else if ambientProbability > 0.8 {
                completion(.ambient)
            } else {
                completion(.unknown)
            }
        } catch {
            print("声音分类失败: \(error.localizedDescription)")
            completion(.unknown)
        }
    }

    // 语音识别(梦话内容)
    private func recognizeSpeech(in url: URL, startTime: Date, endTime: Date, completion: @escaping (String) -> Void) {
        guard let recognizer = speechRecognizer else {
            completion("")
            return
        }

        // 提取指定时间段的音频并进行语音识别
        recognizer.recognizeSpeech(from: url, startTime: startTime, endTime: endTime) { result in
            completion(result)
        }
    }
}

// 语音识别器
class SpeechRecognizer: NSObject, AVAudioRecorderDelegate {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechURLRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    override init() {
        super.init()
        // 设置语音识别器
        if #available(iOS 10.0, *) {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        }
    }

    // 识别音频中的语音
    func recognizeSpeech(from url: URL, startTime: Date, endTime: Date, completion: @escaping (String) -> Void) {
        guard #available(iOS 10.0, *), let recognizer = speechRecognizer, recognizer.isAvailable else {
            completion("语音识别不可用")
            return
        }

        recognitionTask?.cancel()
        self.recognitionTask = nil

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        // 设置识别时间段(实际实现中需要先裁剪音频)
        let duration = endTime.timeIntervalSince(startTime)
        // Removed timeout as SFSpeechURLRecognitionRequest doesn't support this property

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