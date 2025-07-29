import Foundation
import AVFoundation
import SwiftUI

class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var totalTime: TimeInterval = 0
    // 存储多个音频播放器实例
    private var audioPlayers: [URL: AVAudioPlayer] = [:]
    // 存储每个音频的计时器
    private var updateTimers: [URL: Timer] = [:]
    // 存储每个音频的播放状态
    private var playingStates: [URL: Bool] = [:]
    // 存储每个音频的当前播放时间
    private var currentTimes: [URL: TimeInterval] = [:]
    // 存储每个音频的总时长
    private var totalTimes: [URL: TimeInterval] = [:]

    // 播放音频文件
    func playAudio(from url: URL) {
        do {
            // 配置音频会话
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)

            // 如果已有该URL的播放器实例，直接使用
            if let player = audioPlayers[url] {
                player.play()
                playingStates[url] = true
                startUpdateTimer(for: url)
                objectWillChange.send()
                return
            }

            // 创建新的播放器实例
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            newPlayer.play()

            // 存储新播放器及其状态
            audioPlayers[url] = newPlayer
            playingStates[url] = true
            totalTimes[url] = newPlayer.duration
            currentTimes[url] = 0
            startUpdateTimer(for: url)

            // 通知UI更新
            objectWillChange.send()
        } catch {
            print("音频播放失败: \(error.localizedDescription), URL: \(url.path)")
            let avError = error as NSError
    print("AVFoundation错误代码: \(avError.code), 域: \(avError.domain)")
          stopAudio(for: url)
        }
    }
    // 暂停指定URL的音频播放
    func pauseAudio(for url: URL) {
        audioPlayers[url]?.pause()
        playingStates[url] = false
        stopUpdateTimer(for: url)
        objectWillChange.send()
    }

    // 暂停所有音频播放
    func pauseAllAudio() {
        audioPlayers.forEach { $0.value.pause() }
        playingStates.forEach { playingStates[$0.key] = false }
        updateTimers.forEach { $0.value.invalidate() }
        objectWillChange.send()
    }

    // 停止指定URL的音频播放
    func stopAudio(for url: URL) {
        audioPlayers[url]?.stop()
        audioPlayers.removeValue(forKey: url)
        updateTimers[url]?.invalidate()
        updateTimers.removeValue(forKey: url)
        playingStates.removeValue(forKey: url)
        currentTimes.removeValue(forKey: url)
        totalTimes.removeValue(forKey: url)
        objectWillChange.send()
    }

    // 停止所有音频播放
    func stopAllAudio() {
        audioPlayers.forEach { $0.value.stop() }
        audioPlayers.removeAll()
        updateTimers.forEach { $0.value.invalidate() }
        updateTimers.removeAll()
        playingStates.removeAll()
        currentTimes.removeAll()
        totalTimes.removeAll()
        objectWillChange.send()
    }

    // 检查指定URL的音频是否正在播放
    func isPlayingURL(_ url: URL) -> Bool {
        return playingStates[url] ?? false
    }

    // 获取指定URL的当前播放时间
    func getCurrentTime(for url: URL) -> TimeInterval {
        return currentTimes[url] ?? 0
    }

    // 获取指定URL的总时长
    func getTotalTime(for url: URL) -> TimeInterval {
        return totalTimes[url] ?? 0
    }

    // 重置指定URL的播放器状态
    private func resetAudioState(for url: URL) {
        audioPlayers[url]?.stop()
        audioPlayers.removeValue(forKey: url)
        updateTimers[url]?.invalidate()
        updateTimers.removeValue(forKey: url)
        playingStates.removeValue(forKey: url)
        currentTimes.removeValue(forKey: url)
        totalTimes.removeValue(forKey: url)
    }

    // 开始指定URL的更新计时器
    private func startUpdateTimer(for url: URL) {
        // 先停止已有的计时器
        stopUpdateTimer(for: url)

        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            guard let self = self, let player = self.audioPlayers[url] else { return }
            self.currentTimes[url] = player.currentTime
        }
        updateTimers[url] = timer
    }

    // 停止指定URL的更新计时器
    private func stopUpdateTimer(for url: URL) {
        updateTimers[url]?.invalidate()
        updateTimers.removeValue(forKey: url)
    }

    // 音频播放完成回调
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // 找到对应的URL并清理
        if let url = audioPlayers.first(where: { $0.value === player })?.key {
            resetAudioState(for: url)
        }
    }

    // 处理音频中断（如电话打入）
    func handleAudioInterruption(interruptionType: AVAudioSession.InterruptionType) {
        if interruptionType == .ended {
            // 恢复所有之前正在播放的音频
            playingStates.forEach { url, isPlaying in
                if isPlaying {
                    playAudio(from: url)
                }
            }
        } else {
            // 暂停所有音频
            pauseAllAudio()
        }
    }
}