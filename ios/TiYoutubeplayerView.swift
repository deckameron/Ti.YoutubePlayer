//
//  TiYoutubeplayerView.swift
//  TiYoutubeplayer
//
//  Created by Douglas Alves on 31/01/26.
//  Copyright (c) 2026 Upflix Inc. All rights reserved.
//

import UIKit
import TitaniumKit
import YouTubePlayerKit
import Combine
import SwiftUI
import WebKit

/// Verbose logging. Keep this off in release builds.
private let kYouTubeVerboseLogging = false

@inline(__always)
private func ytLog(_ message: @autoclosure () -> String) {
    if kYouTubeVerboseLogging {
        NSLog("[YOUTUBE] %@", message())
    }
}

/// Holds a task reference so the task body can remove itself once finished.
private final class TaskBox {
    var task: Task<Void, Never>?
}

/// Thread-safe task manager.
///
/// Deliberately *not* `@MainActor`: it is touched from `deinit`, which can run on
/// any thread, and an actor hop there would let finished tasks pile up.
private final class TaskManager {
    private let lock = NSLock()
    private var tasks: Set<Task<Void, Never>> = []

    func add(_ task: Task<Void, Never>) {
        lock.lock()
        tasks.insert(task)
        lock.unlock()
    }

    func remove(_ task: Task<Void, Never>) {
        lock.lock()
        tasks.remove(task)
        lock.unlock()
    }

    func cancelAll() {
        lock.lock()
        let pending = tasks
        tasks.removeAll()
        lock.unlock()
        pending.forEach { $0.cancel() }
    }
}

class TiYoutubeplayerView: TiUIView {

    private var youtubePlayer: YouTubePlayer?
    private var playerHostingController: UIHostingController<AnyView>?
    private var cancellables = Set<AnyCancellable>()

    /// Read from the Kroll thread by `isMuted()` on the proxy while the player writes
    /// it on the main thread, so it needs its own lock.
    private let mutedLock = NSLock()
    private var _isMuted: Bool = true
    var isMuted: Bool {
        get {
            mutedLock.lock()
            defer { mutedLock.unlock() }
            return _isMuted
        }
        set {
            mutedLock.lock()
            _isMuted = newValue
            mutedLock.unlock()
        }
    }

    private var preferredQuality: String = "hd1080"
    private var scalingMode: Int = 0 // 0 = FIT, 1 = FILL

    private var videoAspectRatio: CGFloat = 16.0 / 9.0
    private var videoWidth: Int = 0
    private var videoHeight: Int = 0
    private var currentVideoId: String = ""

    /// Zeroing weak reference to the proxy.
    ///
    /// `TiUIView.proxy` is declared `assign` (non-zeroing), so it dangles after the
    /// proxy is deallocated and `proxy != nil` cannot detect that. Every event we
    /// fire from an async context goes through this reference instead.
    private weak var proxyRef: TiViewProxy?

    private let taskManager = TaskManager()
    private var metadataTask: Task<Void, Never>?
    private var isReleased = false
    private var didSetupOtherObservers = false

    /// The properties the current player was built from.
    ///
    /// Titanium recycles views in ListView/TableView and re-applies the next row's
    /// properties, so this is what a reconfiguration is compared against.
    private struct PlayerConfig: Equatable {
        var videoId: String
        var autoplay: Bool
        var loop: Bool
        var controls: Bool
        var showCaptions: Bool
        var showFullscreenButton: Bool
        var keyboardControlsDisabled: Bool
        var startSeconds: Double
        var muted: Bool
        var scalingMode: Int
        var preferredQuality: String

        /// These are baked into the iFrame when the player is created, so changing
        /// any of them means the player has to be rebuilt. Everything else can be
        /// applied to the running player.
        func requiresRebuild(comparedTo other: PlayerConfig) -> Bool {
            return autoplay != other.autoplay
                || loop != other.loop
                || controls != other.controls
                || showCaptions != other.showCaptions
                || showFullscreenButton != other.showFullscreenButton
                || keyboardControlsDisabled != other.keyboardControlsDisabled
                || startSeconds != other.startSeconds
        }
    }

    private var currentConfig: PlayerConfig?

    /// Parent this hosting controller was added to, for #5 containment.
    private weak var hostingParentVC: UIViewController?

    /// What the caller last asked for, applied as soon as the player reports `.ready`.
    ///
    /// The natural way to use this module is to create the view and immediately call
    /// `play()`. At that point the iFrame API has not loaded yet, so the command would
    /// evaluate JavaScript against a player that does not exist and be swallowed by
    /// `try?` — leaving a permanently black view when `autoplay` is off.
    private enum PlaybackIntent { case play, pause }
    private var desiredPlayback: PlaybackIntent?
    private var isPlayerReady = false

    /// Bounds can be zero while the view is off-screen; retry a bounded number of
    /// times instead of rescheduling forever.
    private var scalingRetryCount = 0
    private static let maxScalingRetries = 30

    override func initializeState() {
        super.initializeState()

        proxyRef = proxy as? TiViewProxy

        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.backgroundColor = .black
        self.clipsToBounds = true
    }

    /// Titanium hands a recycled view to a different proxy in ListView/TableView.
    /// Keep the weak reference pointing at the proxy that actually owns us.
    override func transferProxy(_ newProxy: TiViewProxy!, deep: Bool) {
        super.transferProxy(newProxy, deep: deep)
        proxyRef = newProxy
    }

    override func frameSizeChanged(_ frame: CGRect, bounds: CGRect) {
        super.frameSizeChanged(frame, bounds: bounds)

        playerHostingController?.view.frame = bounds

        if videoWidth > 0 && videoHeight > 0 {
            scalingRetryCount = 0
            applyCalculatedScaling()
        }
    }

    // MARK: - Event dispatch

    /// Fires an event through the zeroing weak proxy reference.
    private func fire(_ name: String, _ payload: [String: Any]) {
        guard !isReleased, let proxy = proxyRef else { return }
        proxy.fireEvent(name, with: payload)
    }

    // MARK: - Task helpers

    /// Runs `operation` on the main actor with the view and player passed in, so the
    /// closure never has to capture `self` strongly.
    ///
    /// - Parameter onUnavailable: Called instead of `operation` when the player is
    ///   already gone — either at enqueue time or by the time the task runs. Callers
    ///   with a JS callback must supply this, otherwise the callback is silently
    ///   dropped and the caller waits forever.
    @discardableResult
    private func createTask(
        onUnavailable: (() -> Void)? = nil,
        _ operation: @escaping @MainActor (TiYoutubeplayerView, YouTubePlayer) async -> Void
    ) -> Task<Void, Never>? {
        guard !isReleased, youtubePlayer != nil else {
            if let onUnavailable = onUnavailable {
                // Always deliver on the main thread, like the task path does.
                if Thread.isMainThread {
                    onUnavailable()
                } else {
                    DispatchQueue.main.async(execute: onUnavailable)
                }
            }
            return nil
        }

        let box = TaskBox()
        let task = Task { @MainActor [weak self, taskManager] in
            defer {
                if let task = box.task {
                    taskManager.remove(task)
                }
            }

            // A cancelled Task still runs its body, so this branch is the one that
            // fires when the view was torn down between enqueue and execution.
            guard let self = self, !self.isReleased, let player = self.youtubePlayer else {
                onUnavailable?()
                return
            }

            await operation(self, player)
        }

        // Registered synchronously so `remove` in the defer can never run first.
        box.task = task
        taskManager.add(task)

        return task
    }

    override func configurationSet() {
        super.configurationSet()

        // A released view must not be brought back to life by a reconfiguration.
        guard !isReleased else { return }

        proxyRef = proxy as? TiViewProxy

        guard let config = readConfig() else { return }

        if let previous = currentConfig {
            // Recycled row. Rebuild only if an iFrame-level parameter changed;
            // otherwise adjust the running player in place.
            if config.requiresRebuild(comparedTo: previous) {
                teardownPlayer()
                buildPlayer(with: config)
            } else {
                applyLiveConfig(config, previous: previous)
            }
        } else {
            buildPlayer(with: config)
        }

        currentConfig = config
    }

    private func readConfig() -> PlayerConfig? {
        guard let videoId = proxy?.value(forKey: "videoId") as? String, !videoId.isEmpty else {
            NSLog("[YOUTUBE] ERROR: videoId is required")
            return nil
        }

        let controls = proxy.value(forKey: "showControls") as? Bool ?? false
        let showFullscreenButton = proxy.value(forKey: "showFullscreenButton") as? Bool ?? false

        if showFullscreenButton && !controls {
            NSLog("[YOUTUBE] WARNING: showFullscreenButton has no effect with showControls:false — "
                  + "YouTube renders the fullscreen button inside its control bar.")
        }

        return PlayerConfig(
            videoId: videoId,
            autoplay: proxy.value(forKey: "autoplay") as? Bool ?? true,
            loop: proxy.value(forKey: "loop") as? Bool ?? true,
            controls: controls,
            showCaptions: proxy.value(forKey: "showCaptions") as? Bool ?? false,
            showFullscreenButton: showFullscreenButton,
            keyboardControlsDisabled: proxy.value(forKey: "keyboardControlsDisabled") as? Bool ?? true,
            startSeconds: proxy.value(forKey: "startSeconds") as? Double ?? 0.0,
            muted: proxy.value(forKey: "muted") as? Bool ?? true,
            scalingMode: (proxy.value(forKey: "scalingMode") as? NSNumber)?.intValue ?? 0,
            preferredQuality: proxy.value(forKey: "preferredQuality") as? String ?? "hd1080"
        )
    }

    private func buildPlayer(with config: PlayerConfig) {
        currentVideoId = config.videoId
        scalingMode = config.scalingMode
        preferredQuality = config.preferredQuality
        isMuted = config.muted

        var parameters = YouTubePlayer.Parameters()
        parameters.autoPlay = config.autoplay
        parameters.loopEnabled = config.loop
        parameters.showControls = config.controls
        parameters.keyboardControlsDisabled = config.keyboardControlsDisabled
        parameters.showCaptions = config.showCaptions
        parameters.showFullscreenButton = config.showFullscreenButton

        // Native start time, instead of a timed seek after the player is up.
        if config.startSeconds > 0 {
            parameters.startTime = Measurement(value: config.startSeconds, unit: UnitDuration.seconds)
        }

        let player = YouTubePlayer(
            source: .video(id: config.videoId),
            parameters: parameters
        )
        youtubePlayer = player

        setupStateObserver()

        let playerView = YouTubePlayerView(player) { _ in }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

        let hostingController = UIHostingController(rootView: AnyView(playerView))
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = self.bounds

        self.addSubview(hostingController.view)
        self.playerHostingController = hostingController
        attachHostingControllerIfNeeded()

        ytLog("SwiftUI player created for \(config.videoId)")

        fetchVideoMetadata(videoId: config.videoId)
    }

    /// Applies the properties that do not require rebuilding the iFrame.
    private func applyLiveConfig(_ config: PlayerConfig, previous: PlayerConfig) {
        if config.preferredQuality != previous.preferredQuality {
            preferredQuality = config.preferredQuality
        }

        if config.scalingMode != previous.scalingMode {
            setScalingMode(mode: config.scalingMode)
        }

        if config.muted != previous.muted {
            if config.muted { mute() } else { unmute() }
        }

        if config.videoId != previous.videoId {
            loadVideo(videoId: config.videoId, startSeconds: config.startSeconds)
        }
    }

    /// Drops the current player without marking the view released, so the same view
    /// can host a new one.
    private func teardownPlayer() {
        cancellables.removeAll()
        taskManager.cancelAll()
        metadataTask?.cancel()
        metadataTask = nil

        didSetupOtherObservers = false
        isPlayerReady = false
        desiredPlayback = nil
        videoWidth = 0
        videoHeight = 0
        scalingRetryCount = 0

        if let hostingController = playerHostingController {
            detachHostingController(hostingController)
        }
        playerHostingController = nil
        youtubePlayer = nil
    }

    // MARK: - View controller containment

    /// SwiftUI expects its hosting controller to live in the view-controller
    /// hierarchy; without it, lifecycle, trait and safe-area updates do not reach the
    /// player. The parent only exists once we are in a window, so this runs again from
    /// `didMoveToWindow()`.
    private func attachHostingControllerIfNeeded() {
        guard !isReleased, let hostingController = playerHostingController else { return }

        let target = closestViewController()
        guard hostingController.parent !== target else { return }

        // Recycled rows can end up under a different view controller, so move the
        // hosting controller rather than assuming its first parent is still right.
        // The view itself stays in our subview tree throughout.
        if hostingController.parent != nil {
            hostingController.willMove(toParent: nil)
            hostingController.removeFromParent()
        }

        if let target = target {
            target.addChild(hostingController)
            hostingController.didMove(toParent: target)
        }
        hostingParentVC = target
    }

    private func detachHostingController(_ hostingController: UIHostingController<AnyView>) {
        if hostingController.parent != nil {
            hostingController.willMove(toParent: nil)
            hostingController.view.removeFromSuperview()
            hostingController.removeFromParent()
        } else {
            hostingController.view.removeFromSuperview()
        }
        hostingParentVC = nil
    }

    private func closestViewController() -> UIViewController? {
        var responder: UIResponder? = self.next
        while let current = responder {
            if let viewController = current as? UIViewController {
                return viewController
            }
            responder = current.next
        }
        return nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Only meaningful once we are in a window; there is no parent to find before that.
        if window != nil {
            attachHostingControllerIfNeeded()
        }
    }

    /// Tears the player down. Must be called on the main thread.
    func cleanup() {
        guard !isReleased else { return }
        isReleased = true

        ytLog("cleanup")

        cancellables.removeAll()
        taskManager.cancelAll()

        metadataTask?.cancel()
        metadataTask = nil

        desiredPlayback = nil
        isPlayerReady = false

        if let hostingController = playerHostingController {
            detachHostingController(hostingController)
        }
        playerHostingController = nil
        youtubePlayer = nil
        currentConfig = nil
        proxyRef = nil
    }

    private func fetchVideoMetadata(videoId: String) {
        metadataTask?.cancel()

        metadataTask = Task { [weak self] in
            let urlString = "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=\(videoId)&format=json"
            guard let url = URL(string: urlString) else { return }

            let data: Data
            do {
                (data, _) = try await URLSession.shared.data(from: url)
            } catch {
                if !Task.isCancelled {
                    ytLog("Failed to fetch metadata: \(error)")
                }
                return
            }

            guard !Task.isCancelled else { return }
            guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }

            let title = json["title"] as? String ?? ""
            let author = json["author_name"] as? String ?? ""
            let width = json["width"] as? Int ?? 0
            let height = json["height"] as? Int ?? 0

            await MainActor.run { [weak self] in
                guard let self = self, !self.isReleased else { return }

                if width > 0 && height > 0 {
                    self.videoWidth = width
                    self.videoHeight = height
                    self.videoAspectRatio = CGFloat(width) / CGFloat(height)

                    self.scalingRetryCount = 0
                    self.applyCalculatedScaling()
                }

                self.fire("metadataReceived", [
                    "videoId": videoId,
                    "title": title,
                    "author": author
                ])
            }
        }
    }

    private func applyCalculatedScaling() {
        guard !isReleased else { return }

        guard let hostingController = playerHostingController else { return }
        guard videoAspectRatio > 0 else { return }

        let containerWidth = self.bounds.width
        let containerHeight = self.bounds.height

        guard containerWidth > 0 && containerHeight > 0 else {
            guard scalingRetryCount < Self.maxScalingRetries else { return }
            scalingRetryCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.applyCalculatedScaling()
            }
            return
        }

        scalingRetryCount = 0

        let containerAspect = containerWidth / containerHeight

        let playerWidth: CGFloat
        let playerHeight: CGFloat

        if scalingMode == 1 {
            // ASPECT_FILL
            if containerAspect > videoAspectRatio {
                playerWidth = containerWidth
                playerHeight = containerWidth / videoAspectRatio
            } else {
                playerHeight = containerHeight
                playerWidth = containerHeight * videoAspectRatio
            }
        } else {
            // ASPECT_FIT
            if containerAspect > videoAspectRatio {
                playerHeight = containerHeight
                playerWidth = containerHeight * videoAspectRatio
            } else {
                playerWidth = containerWidth
                playerHeight = containerWidth / videoAspectRatio
            }
        }

        hostingController.view.frame = CGRect(
            x: (containerWidth - playerWidth) / 2,
            y: (containerHeight - playerHeight) / 2,
            width: playerWidth,
            height: playerHeight
        )
    }

    func setScalingMode(mode: Int) {
        guard !isReleased else { return }
        scalingMode = mode
        scalingRetryCount = 0
        applyCalculatedScaling()
    }

    private func forceHighQuality() {
        guard !isReleased else { return }
        setPlaybackQuality(quality: preferredQuality)
    }

    // MARK: - Observers

    private func setupStateObserver() {
        guard let youtubePlayer = self.youtubePlayer else { return }

        youtubePlayer.statePublisher
            .sink { [weak self] state in
                guard let self = self, !self.isReleased else { return }

                switch state {
                case .idle:
                    self.fire("playerStateChange", ["playerState": "idle"])

                case .ready:
                    self.isPlayerReady = true
                    self.fire("playerStateChange", ["playerState": "ready"])
                    self.setupOtherObservers()

                    // Applied here rather than on a timer: on a slow connection the
                    // old 1s delay fired before the player existed and the video
                    // started with sound.
                    if self.isMuted {
                        self.mute()
                    } else {
                        self.unmute()
                    }

                    // Replay whatever was requested before the player was usable.
                    switch self.desiredPlayback {
                    case .play: self.play()
                    case .pause: self.pause()
                    case nil: break
                    }

                    self.forceHighQuality()

                case .error(let error):
                    let (code, type, message) = Self.describe(error)
                    ytLog("Error: code=\(code), type=\(type)")

                    self.fire("error", [
                        "message": message,
                        "code": code,
                        "type": type
                    ])

                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    /// Maps a `YouTubePlayer.Error` to the YouTube IFrame API error codes.
    ///
    /// `YouTubePlayer.Error` is a plain Swift enum, so bridging it to `NSError` yields
    /// the case's ordinal position, not the YouTube error code. It has to be matched
    /// on the case itself.
    private static func describe(_ error: Error) -> (code: Int, type: String, message: String) {
        switch error as? YouTubePlayer.Error {
        case .invalidSource:
            return (2, "invalid_parameter", "Invalid video ID")
        case .html5NotSupported:
            return (5, "html5_error", "HTML5 player error")
        case .notFound:
            return (100, "not_found", "Video not found, private, or age-restricted")
        case .embeddedVideoPlayingNotAllowed:
            return (101, "embedding_disabled", "Video owner does not allow embedding")
        case .missingAPIClientIdentification:
            return (153, "missing_referer", "Missing HTTP Referer header or API Client identification")
        case .iFrameApiFailedToLoad:
            return (-1, "iframe_api_failed", "The YouTube iFrame API failed to load")
        case .webContentProcessDidTerminate:
            return (-2, "web_process_terminated", "The web content process was terminated")
        case .setupFailed(let underlying):
            return (-3, "setup_failed", underlying.localizedDescription)
        case .didFailProvisionalNavigation(let underlying),
             .didFailNavigation(let underlying):
            return (-4, "navigation_failed", underlying.localizedDescription)
        default:
            return (-99, "unknown", String(describing: error))
        }
    }

    private func setupOtherObservers() {
        guard let youtubePlayer = self.youtubePlayer else { return }

        // `.ready` can be emitted more than once (the player recovers from errors),
        // so make sure we do not stack duplicate subscriptions.
        guard !didSetupOtherObservers else { return }
        didSetupOtherObservers = true

        youtubePlayer.playbackStatePublisher
            .sink { [weak self] playbackState in
                guard let self = self, !self.isReleased else { return }

                var stateString = "unknown"
                var stateCode = -1

                switch playbackState {
                case .unstarted: stateString = "unstarted"; stateCode = -1
                case .ended: stateString = "ended"; stateCode = 0
                case .playing:
                    stateString = "playing"
                    stateCode = 1

                    if self.videoWidth > 0 && self.videoHeight > 0 {
                        self.scalingRetryCount = 0
                        self.applyCalculatedScaling()
                    }
                    self.forceHighQuality()

                case .paused: stateString = "paused"; stateCode = 2
                case .buffering: stateString = "buffering"; stateCode = 3
                case .cued: stateString = "cued"; stateCode = 5
                default: break
                }

                self.fire("playbackStateChange", [
                    "state": stateString,
                    "code": stateCode,
                    "isFullyReady": true
                ])
            }
            .store(in: &cancellables)

        youtubePlayer.playbackQualityPublisher
            .sink { [weak self] quality in
                guard let self = self, !self.isReleased else { return }

                var qualityString = "unknown"
                switch quality {
                case .auto: qualityString = "auto"
                case .small: qualityString = "small"
                case .medium: qualityString = "medium"
                case .large: qualityString = "large"
                case .hd720: qualityString = "hd720"
                case .hd1080: qualityString = "hd1080"
                case .highResolution: qualityString = "highres"
                default: break
                }

                self.fire("playbackQualityChange", ["quality": qualityString])
            }
            .store(in: &cancellables)

        youtubePlayer.playbackRatePublisher
            .sink { [weak self] rate in
                guard let self = self, !self.isReleased else { return }
                self.fire("playbackRateChange", ["rate": rate.value])
            }
            .store(in: &cancellables)

        youtubePlayer.fullscreenStatePublisher
            .sink { [weak self] state in
                guard let self = self, !self.isReleased else { return }
                self.fire("fullscreenChange", ["fullscreen": state.isFullscreen])
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    func play() {
        guard !isReleased else { return }
        desiredPlayback = .play
        // Not ready yet: the `.ready` handler replays this.
        guard isPlayerReady else { return }

        createTask { _, player in
            try? await player.play()
        }
    }

    func pause() {
        guard !isReleased else { return }
        desiredPlayback = .pause
        guard isPlayerReady else { return }

        createTask { _, player in
            try? await player.pause()
        }
    }

    /// Stops playback and rewinds to the start; a later `play()` resumes from there.
    ///
    /// Deliberately not `YouTubePlayer.stop()`, which maps to the iFrame API's
    /// `stopVideo()` and unloads the video — after that a `play()` did nothing, while
    /// the same call on Android resumed. YouTube's own documentation reserves
    /// `stopVideo()` for rare cases and recommends pausing instead.
    func stop() {
        guard !isReleased else { return }
        // Also suppresses autoplay if this lands before the player is ready.
        desiredPlayback = .pause
        guard isPlayerReady else { return }

        createTask { _, player in
            try? await player.pause()
            try? await player.seek(
                to: Measurement(value: 0, unit: UnitDuration.seconds),
                allowSeekAhead: true
            )
        }
    }

    func mute() {
        guard !isReleased else { return }
        // Recorded up front so `.ready` can apply it even if this call is too early.
        isMuted = true
        guard isPlayerReady else { return }

        createTask { view, player in
            try? await player.mute()
            guard !view.isReleased else { return }
            view.fire("muteChanged", ["muted": true])
        }
    }

    func unmute() {
        guard !isReleased else { return }
        isMuted = false
        guard isPlayerReady else { return }

        createTask { view, player in
            try? await player.unmute()
            guard !view.isReleased else { return }
            view.fire("muteChanged", ["muted": false])
        }
    }

    func seek(to seconds: Double) {
        let time = Measurement(value: seconds, unit: UnitDuration.seconds)
        createTask { _, player in
            try? await player.seek(to: time, allowSeekAhead: true)
        }
    }

    func getDuration(completion: @escaping (Double?) -> Void) {
        createTask(onUnavailable: { completion(nil) }) { _, player in
            guard let duration = try? await player.getDuration() else {
                completion(nil)
                return
            }
            completion(duration.converted(to: .seconds).value)
        }
    }

    func getCurrentTime(completion: @escaping (Double?) -> Void) {
        createTask(onUnavailable: { completion(nil) }) { _, player in
            guard let currentTime = try? await player.getCurrentTime() else {
                completion(nil)
                return
            }
            completion(currentTime.converted(to: .seconds).value)
        }
    }

    /// Locates the player's `WKWebView` inside the SwiftUI hosting view.
    @MainActor
    private static func findWebView(in view: UIView) -> WKWebView? {
        if let webView = view as? WKWebView { return webView }
        for subview in view.subviews {
            if let found = findWebView(in: subview) { return found }
        }
        return nil
    }

    /// Note: YouTube has ignored `setPlaybackQuality` since 2019. This is kept as a
    /// best-effort hint only.
    func setPlaybackQuality(quality: String) {
        preferredQuality = quality

        createTask { view, _ in
            guard let hostingView = view.playerHostingController?.view,
                  let webView = Self.findWebView(in: hostingView) else { return }

            // The player is exposed as `youtubePlayer` by YouTubePlayerKit's HTML
            // template (HTMLBuilder.youTubePlayerJavaScriptVariableName).
            let js = """
            (function() {
                try {
                    if (window.youtubePlayer && window.youtubePlayer.setPlaybackQuality) {
                        window.youtubePlayer.setPlaybackQuality('\(quality)');
                        return 'success';
                    }
                    return 'player not ready';
                } catch(e) {
                    return 'error: ' + e.message;
                }
            })();
            """

            _ = try? await webView.evaluateJavaScript(js)
        }
    }

    func getAvailableQualityLevels(completion: @escaping ([String]) -> Void) {
        createTask(onUnavailable: { completion([]) }) { view, _ in
            guard let hostingView = view.playerHostingController?.view,
                  let webView = Self.findWebView(in: hostingView) else {
                completion([])
                return
            }

            let js = """
            (function() {
                try {
                    if (window.youtubePlayer && window.youtubePlayer.getAvailableQualityLevels) {
                        return window.youtubePlayer.getAvailableQualityLevels();
                    }
                    return [];
                } catch(e) {
                    return [];
                }
            })();
            """

            let result = try? await webView.evaluateJavaScript(js)
            completion((result as? [String]) ?? [])
        }
    }

    func setPlaybackRate(rate: Double) {
        createTask { _, player in
            let playbackRate: YouTubePlayer.PlaybackRate
            switch rate {
            case 0.25: playbackRate = .quarterSpeed
            case 0.5: playbackRate = .halfSpeed
            case 0.75: playbackRate = .threeQuarterSpeed
            case 1.0: playbackRate = .normal
            case 1.25: playbackRate = .oneQuarterFaster
            case 1.5: playbackRate = .oneHalfFaster
            case 1.75: playbackRate = .threeQuarterFaster
            case 2.0: playbackRate = .double
            default: playbackRate = .normal
            }

            try? await player.set(playbackRate: playbackRate)
        }
    }

    func reload() {
        guard !isReleased else { return }
        // The web view reloads, so `.ready` will fire again.
        isPlayerReady = false

        createTask { _, player in
            try? await player.reload()
        }
    }

    func cueVideo(videoId: String, startSeconds: Double = 0) {
        guard !isReleased, youtubePlayer != nil else { return }

        currentVideoId = videoId
        fetchVideoMetadata(videoId: videoId)

        let startTime = Measurement(value: startSeconds, unit: UnitDuration.seconds)
        createTask { _, player in
            try? await player.cue(source: .video(id: videoId), startTime: startTime)
        }
    }

    func loadVideo(videoId: String, startSeconds: Double = 0) {
        guard !isReleased, youtubePlayer != nil else { return }

        currentVideoId = videoId
        fetchVideoMetadata(videoId: videoId)

        let startTime = Measurement(value: startSeconds, unit: UnitDuration.seconds)
        createTask { _, player in
            try? await player.load(source: .video(id: videoId), startTime: startTime)
        }
    }

    func changeVideo(videoId: String) {
        loadVideo(videoId: videoId)
    }

    deinit {
        isReleased = true

        taskManager.cancelAll()
        metadataTask?.cancel()
        metadataTask = nil

        // `deinit` can run off the main thread (Titanium's destroy queue, or the
        // Kroll thread during GC). UIHostingController/WKWebView and the
        // @MainActor YouTubePlayer must not be touched or released there.
        //
        // The cancellables go along for the ride: AnyCancellable cancels on its own
        // deinit, and those subscription chains reach into the player's web view.
        let hostingController = playerHostingController
        let player = youtubePlayer
        let subscriptions = cancellables

        cancellables.removeAll()
        playerHostingController = nil
        youtubePlayer = nil

        let detach: () -> Void = {
            guard let hostingController = hostingController else { return }
            if hostingController.parent != nil {
                hostingController.willMove(toParent: nil)
                hostingController.view.removeFromSuperview()
                hostingController.removeFromParent()
            } else {
                hostingController.view.removeFromSuperview()
            }
        }

        if Thread.isMainThread {
            detach()
            // hostingController, player and subscriptions release here, on main.
        } else {
            DispatchQueue.main.async {
                detach()
                _ = player
                _ = subscriptions
            }
        }
    }
}
