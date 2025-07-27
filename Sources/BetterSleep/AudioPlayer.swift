import Foundation
import AVFoundation
import SwiftUI

class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var totalTime: TimeInterval = 0
    private var audioPlayer: AVAudioPlayer?
    private var updateTimer: Timer?
    private var currentPlaybackURL: URL?

    // 播放音频文件
    func playAudio(from url: URL) {
        // 如果正在播放不同的音频，先停止
        if let currentURL = currentPlaybackURL, currentURL != url {
            stopPlayback()
        }

        do {
            // 配置音频会话
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            isPlaying = true
            currentPlaybackURL = url
            totalTime = audioPlayer?.duration ?? 0
            startUpdateTimer()
        } catch {
            print("音频播放失败: \(error.localizedDescription)")
            resetPlayerState()
        }
    }

    // 暂停播放
    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        stopUpdateTimer()
    }

    // 停止播放
    func stopPlayback() {
    audioPlayer?.stop()
    resetPlayerState()
}

func isPlayingURL(_ url: URL) -> Bool {
    return currentPlaybackURL == url
}

    // 重置播放器状态
    private func resetPlayerState() {
        isPlaying = false
        currentTime = 0
        totalTime = 0
        currentPlaybackURL = nil
        stopUpdateTimer()
        audioPlayer = nil
    }

    // 开始更新计时器（用于更新播放进度）
    private func startUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
        }
    }

    // 停止更新计时器
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    // 音频播放完成回调
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        resetPlayerState()
    }

    // 处理音频中断（如电话打入）
    func handleAudioInterruption(interruptionType: AVAudioSession.InterruptionType) {
        if interruptionType == .ended {
            // 如果是中断结束且之前正在播放，尝试恢复播放
            if let url = currentPlaybackURL, !isPlaying {
                playAudio(from: url)
            }
        } else {
            pausePlayback()
        }
    }
}