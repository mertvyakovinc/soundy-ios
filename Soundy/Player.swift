import AVFoundation
import MediaPlayer
import UIKit

/// Playback: AVPlayer + background audio + lock-screen / Control Center controls.
@MainActor
final class Player: ObservableObject {
    static let shared = Player()

    @Published private(set) var queue: [Track] = []
    @Published private(set) var index: Int = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var isWave = false
    @Published var errorText: String?

    var current: Track? { queue.indices.contains(index) ? queue[index] : nil }

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var itemObservers: [NSKeyValueObservation] = []
    private var endObserver: NSObjectProtocol?
    private var artworkTask: Task<Void, Never>?
    private var extending = false

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.automaticallyWaitsToMinimizeStalling = true

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] t in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.position = t.seconds.isFinite ? t.seconds : 0
                if let d = self.player.currentItem?.duration.seconds, d.isFinite, d > 0 { self.duration = d }
                self.isPlaying = self.player.timeControlStatus == .playing
                self.isBuffering = self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }
        setupRemoteCommands()
    }

    // MARK: - Queue

    func play(_ list: [Track], at i: Int, wave: Bool = false) {
        guard list.indices.contains(i) else { return }
        queue = list
        index = i
        isWave = wave
        load()
    }

    func togglePlay() {
        guard current != nil else { return }
        if player.timeControlStatus == .playing { player.pause() } else { player.play() }
        isPlaying.toggle()
        updateNowPlaying()
    }

    func next() {
        guard !queue.isEmpty else { return }
        if index + 1 < queue.count { index += 1; load() }
        else if isWave { Task { await extendWave(thenAdvance: true) } }
    }

    func previous() {
        if position > 4 { seek(to: 0); return }
        guard index > 0 else { seek(to: 0); return }
        index -= 1
        load()
    }

    func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: max(0, seconds), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        position = seconds
        updateNowPlaying()
    }

    func skip(to i: Int) {
        guard queue.indices.contains(i) else { return }
        index = i
        load()
    }

    // MARK: - Loading

    private func load() {
        guard let t = current else { return }
        errorText = nil
        position = 0
        duration = Double(t.duration)
        itemObservers.removeAll()
        if let o = endObserver { NotificationCenter.default.removeObserver(o) }

        guard let url = t.streamURL else { errorText = "Не удалось открыть трек"; return }
        let item = AVPlayerItem(url: url)
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.next() }
        }
        itemObservers.append(item.observe(\.status) { [weak self] it, _ in
            guard it.status == .failed else { return }
            Task { @MainActor in
                self?.errorText = "Трек не играет, пропускаю"
                self?.next()
            }
        })
        player.replaceCurrentItem(with: item)
        player.play()
        isPlaying = true
        Library.shared.addToHistory(t)
        updateNowPlaying()
        loadArtwork(for: t)

        // Keep the wave flowing: fetch more before the queue runs out.
        if isWave && index >= queue.count - 3 { Task { await extendWave(thenAdvance: false) } }
    }

    private func extendWave(thenAdvance: Bool) async {
        guard !extending else { return }
        extending = true
        defer { extending = false }
        let known = Set(queue.map(\.matchKey))
        let more = await Wave.build().filter { !known.contains($0.matchKey) }
        guard !more.isEmpty else { return }
        queue.append(contentsOf: more)
        if thenAdvance { index += 1; load() }
    }

    // MARK: - Lock screen / Control Center

    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in MainActor.assumeIsolated { self?.player.play(); self?.isPlaying = true; self?.updateNowPlaying() }; return .success }
        c.pauseCommand.addTarget { [weak self] _ in MainActor.assumeIsolated { self?.player.pause(); self?.isPlaying = false; self?.updateNowPlaying() }; return .success }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in MainActor.assumeIsolated { self?.togglePlay() }; return .success }
        c.nextTrackCommand.addTarget { [weak self] _ in MainActor.assumeIsolated { self?.next() }; return .success }
        c.previousTrackCommand.addTarget { [weak self] _ in MainActor.assumeIsolated { self?.previous() }; return .success }
        c.changePlaybackPositionCommand.addTarget { [weak self] e in
            guard let e = e as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            MainActor.assumeIsolated { self?.seek(to: e.positionTime) }
            return .success
        }
    }

    private var artwork: MPMediaItemArtwork?

    private func updateNowPlaying() {
        guard let t = current else { MPNowPlayingInfoCenter.default().nowPlayingInfo = nil; return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: t.title,
            MPMediaItemPropertyArtist: t.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        if let a = artwork { info[MPMediaItemPropertyArtwork] = a }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(for t: Track) {
        artwork = nil
        artworkTask?.cancel()
        guard let url = t.coverURL else { return }
        artworkTask = Task {
            guard let result = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: result.0), !Task.isCancelled else { return }
            await MainActor.run {
                guard self.current?.id == t.id else { return }
                self.artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                self.updateNowPlaying()
            }
        }
    }
}
