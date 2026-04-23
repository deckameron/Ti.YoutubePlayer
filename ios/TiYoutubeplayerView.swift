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

// Thread-safe task manager
@MainActor
private final class TaskManager {
    private var tasks: Set<Task<Void, Never>> = []
    
    func add(_ task: Task<Void, Never>) {
        tasks.insert(task)
    }
    
    func remove(_ task: Task<Void, Never>) {
        tasks.remove(task)
    }
    
    func cancelAll() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }
}

class TiYoutubeplayerView: TiUIView {
    
    private var youtubePlayer: YouTubePlayer!
    private var playerHostingController: UIHostingController<AnyView>?
    private var cancellables = Set<AnyCancellable>()
    var isMuted: Bool = true
    private var preferredQuality: String = "hd1080"
    private var scalingMode: Int = 0 // 0 = FIT, 1 = FILL
    
    private var videoAspectRatio: CGFloat = 16.0 / 9.0
    private var videoWidth: Int = 0
    private var videoHeight: Int = 0
    private var currentVideoId: String = ""
    
    // Thread-safe task management
    private let taskManager = TaskManager()
    private var metadataTask: Task<Void, Error>?
    private var isReleased = false
    
    override func initializeState() {
        super.initializeState()
        
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.backgroundColor = .black
        self.clipsToBounds = true
    }
    
    override func frameSizeChanged(_ frame: CGRect, bounds: CGRect) {
        super.frameSizeChanged(frame, bounds: bounds)
            
        playerHostingController?.view.frame = bounds
        
        if videoWidth > 0 && videoHeight > 0 {
            applyCalculatedScaling()
        }
    }
    
    @discardableResult
    private func createTask(_ operation: @escaping @MainActor () async -> Void) -> Task<Void, Never>? {
        guard !isReleased, youtubePlayer != nil else { return nil }
        
        var task: Task<Void, Never>?
        
        task = Task { @MainActor [weak self, taskManager] in
            defer {
                if let task = task {
                    taskManager.remove(task)
                }
            }
            
            guard let self = self, !self.isReleased, self.youtubePlayer != nil else {
                return
            }
            
            await operation()
        }
        
        if let task = task {
            Task { @MainActor [taskManager] in
                taskManager.add(task)
            }
        }
        
        return task
    }
    
    override func configurationSet() {
        super.configurationSet()
        
        guard let videoId = proxy.value(forKey: "videoId") as? String else {
            NSLog("[YOUTUBE] ERROR: videoId is required")
            return
        }
        
        currentVideoId = videoId
        
        let autoplay = proxy.value(forKey: "autoplay") as? Bool ?? true
        let loop = proxy.value(forKey: "loop") as? Bool ?? true
        let controls = proxy.value(forKey: "showControls") as? Bool ?? false
        let muted = proxy.value(forKey: "muted") as? Bool ?? true
        let showCaptions = proxy.value(forKey: "showCaptions") as? Bool ?? false
        let showFullscreenButton = proxy.value(forKey: "showFullscreenButton") as? Bool ?? false
        let keyboardControlsDisabled = proxy.value(forKey: "keyboardControlsDisabled") as? Bool ?? true
        let startSeconds = proxy.value(forKey: "startSeconds") as? Double ?? 0.0
        
        if let mode = proxy.value(forKey: "scalingMode") as? Int {
            scalingMode = mode
        }
        
        if let quality = proxy.value(forKey: "preferredQuality") as? String {
            self.preferredQuality = quality
        }
        
        self.isMuted = muted
        
        var parameters = YouTubePlayer.Parameters()
        parameters.autoPlay = autoplay
        parameters.loopEnabled = loop
        parameters.showControls = controls
        parameters.keyboardControlsDisabled = keyboardControlsDisabled
        parameters.showCaptions = showCaptions
        parameters.showFullscreenButton = showFullscreenButton
        
        youtubePlayer = YouTubePlayer(
            source: .video(id: videoId),
            parameters: parameters
        )
        
        setupStateObserver()
        
        // TESTE - Sempre usa SwiftUI agora (sem detecção de TableView)
        NSLog("[YOUTUBE] Using SwiftUI player (testing without TableView detection)")
        
        let playerView = YouTubePlayerView(self.youtubePlayer) { state in }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        
        let hostingController = UIHostingController(rootView: AnyView(playerView))
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = self.bounds
        
        self.addSubview(hostingController.view)
        self.playerHostingController = hostingController
        
        NSLog("[YOUTUBE] SwiftUI player created")
        
        // INSPECIONA DEPOIS
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            
            NSLog("[YOUTUBE] ===== SWIFTUI INSPECTION =====")
            NSLog("[YOUTUBE] hostingController.view.frame: %@", NSCoder.string(for: hostingController.view.frame))
            NSLog("[YOUTUBE] hostingController.view.superview: %@", hostingController.view.superview != nil ? "YES" : "NO")
            NSLog("[YOUTUBE] self.subviews.count: %d", self.subviews.count)
            NSLog("[YOUTUBE] ===== END INSPECTION =====")
        }
        
        fetchVideoMetadata(videoId: videoId)
        
        if muted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.mute()
            }
        }
        
        if startSeconds > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.seek(to: startSeconds)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.forceHighQuality()
        }
    }
    
    func cleanup() {
        guard !isReleased else {
            NSLog("[YOUTUBE] Cleanup called but already released")
            return
        }
        isReleased = true
        
        NSLog("[YOUTUBE] ===== CLEANUP CALLED =====")
        NSLog("[YOUTUBE] Stack trace: %@", Thread.callStackSymbols.joined(separator: "\n"))
        NSLog("[YOUTUBE] Releasing YouTubePlayer view")
        
        // Cancela observers
        cancellables.removeAll()
        
        // Cancela tasks
        Task { @MainActor [taskManager] in
            taskManager.cancelAll()
        }
        
        metadataTask?.cancel()
        metadataTask = nil
        
        // Limpa referências
        youtubePlayer = nil
        playerHostingController?.view.removeFromSuperview()
        playerHostingController = nil
    }
    
    private func fetchVideoMetadata(videoId: String) {
        metadataTask?.cancel()
        
        metadataTask = Task {
            do {
                guard !Task.isCancelled else { return }
                
                let urlString = "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=\(videoId)&format=json"
                guard let url = URL(string: urlString) else { return }
                
                let (data, _) = try await URLSession.shared.data(from: url)
                
                guard !Task.isCancelled else { return }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let title = json["title"] as? String ?? ""
                    let author = json["author_name"] as? String ?? ""
                    let width = json["width"] as? Int ?? 0
                    let height = json["height"] as? Int ?? 0
                    
                    await MainActor.run {
                        guard !self.isReleased else { return }
                        
                        if width > 0 && height > 0 {
                            self.videoWidth = width
                            self.videoHeight = height
                            self.videoAspectRatio = CGFloat(width) / CGFloat(height)
                            
                            self.applyCalculatedScaling()
                        }
                        
                        self.proxy.fireEvent("metadataReceived", with: [
                            "videoId": videoId,
                            "title": title,
                            "author": author
                        ])
                    }
                }
            } catch {
                if !Task.isCancelled {
                    NSLog("[YOUTUBE] Failed to fetch metadata: \(error)")
                }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.applyCalculatedScaling()
            }
            return
        }
        
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
        applyCalculatedScaling()
    }
    
    private func forceHighQuality() {
        guard !isReleased else { return }
        setPlaybackQuality(quality: preferredQuality)
    }
    
    private func setupStateObserver() {
        guard let youtubePlayer = self.youtubePlayer else { return }
        
        youtubePlayer.statePublisher
            .sink { [weak self] state in
                guard let self = self, !self.isReleased, self.proxy != nil else { return }
                
                switch state {
                case .idle:
                    self.proxy.fireEvent("playerStateChange", with: ["playerState": "idle"])
                case .ready:
                    self.proxy.fireEvent("playerStateChange", with: ["playerState": "ready"])
                    self.setupOtherObservers()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self = self, !self.isReleased else { return }
                        self.forceHighQuality()
                    }
                case .error(let error):
                    self.proxy.fireEvent("error", with: [
                        "message": error.localizedDescription,
                        "code": (error as NSError).code
                    ])
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupOtherObservers() {
        guard let youtubePlayer = self.youtubePlayer else { return }
        
        youtubePlayer.playbackStatePublisher
            .sink { [weak self] playbackState in
                guard let self = self, !self.isReleased, self.proxy != nil else { return }
                
                var stateString = "unknown"
                var stateCode = -1
                
                switch playbackState {
                case .unstarted: stateString = "unstarted"; stateCode = -1
                case .ended: stateString = "ended"; stateCode = 0
                case .playing:
                    stateString = "playing"
                    stateCode = 1
                    
                    if self.videoWidth > 0 && self.videoHeight > 0 {
                        self.applyCalculatedScaling()
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        guard let self = self, !self.isReleased else { return }
                        self.forceHighQuality()
                    }
                case .paused: stateString = "paused"; stateCode = 2
                case .buffering: stateString = "buffering"; stateCode = 3
                case .cued: stateString = "cued"; stateCode = 5
                default: break
                }
                
                self.proxy.fireEvent("playbackStateChange", with: [
                    "state": stateString,
                    "code": stateCode
                ])
            }
            .store(in: &cancellables)
        
        youtubePlayer.playbackQualityPublisher
            .sink { [weak self] quality in
                guard let self = self, !self.isReleased, self.proxy != nil else { return }
                
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
                
                self.proxy.fireEvent("playbackQualityChange", with: ["quality": qualityString])
            }
            .store(in: &cancellables)
        
        youtubePlayer.playbackRatePublisher
            .sink { [weak self] rate in
                guard let self = self, !self.isReleased, self.proxy != nil else { return }
                self.proxy.fireEvent("playbackRateChange", with: ["rate": rate.value])
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func play() {
        guard !isReleased else { return }
        
        guard youtubePlayer != nil else { return }
        createTask { @MainActor in
            try? await self.youtubePlayer.play()
        }
    }
    
    func pause() {
        guard !isReleased else { return }
                
        guard youtubePlayer != nil else { return }
        createTask { @MainActor in
            try? await self.youtubePlayer.pause()
        }
    }
    
    func stop() {
        guard !isReleased else { return }
        
        guard youtubePlayer != nil else { return }
        createTask { @MainActor in
            try? await self.youtubePlayer.stop()
        }
    }
    
    func mute() {
        guard !isReleased else { return }
        
        guard youtubePlayer != nil else { return }
        createTask { @MainActor in
            try? await self.youtubePlayer.mute()
            guard !self.isReleased, self.proxy != nil else { return }
            self.isMuted = true
            self.proxy.fireEvent("muteChanged", with: ["muted": true])
        }
    }
    
    func unmute() {
        guard !isReleased else { return }
                
        guard youtubePlayer != nil else { return }
        createTask { @MainActor in
            try? await self.youtubePlayer.unmute()
            guard !self.isReleased, self.proxy != nil else { return }
            self.isMuted = false
            self.proxy.fireEvent("muteChanged", with: ["muted": false])
        }
    }
    
    func seek(to seconds: Double) {
        guard !isReleased else { return }
        
        guard youtubePlayer != nil else { return }
        let time = Measurement(value: seconds, unit: UnitDuration.seconds)
        createTask { @MainActor in
            try? await self.youtubePlayer.seek(to: time, allowSeekAhead: true)
        }
    }
    
    func getDuration(completion: @escaping (Double?) -> Void) {
        guard !isReleased, youtubePlayer != nil else {
            completion(nil)
            return
        }
        
        createTask { @MainActor in
            guard let duration = try? await self.youtubePlayer.getDuration() else {
                completion(nil)
                return
            }
            completion(duration.converted(to: .seconds).value)
        }
    }
    
    func getCurrentTime(completion: @escaping (Double?) -> Void) {
        guard !isReleased, youtubePlayer != nil else {
            completion(nil)
            return
        }
        
        createTask { @MainActor in
            guard let currentTime = try? await self.youtubePlayer.getCurrentTime() else {
                completion(nil)
                return
            }
            completion(currentTime.converted(to: .seconds).value)
        }
    }
    
    func setPlaybackQuality(quality: String) {
        guard !isReleased else { return }
                
        guard youtubePlayer != nil else { return }
        
        createTask { @MainActor in
            guard let hostingView = self.playerHostingController?.view else { return }
            
            @MainActor
            func findWKWebView(in view: UIView) -> WKWebView? {
                if let webView = view as? WKWebView { return webView }
                for subview in view.subviews {
                    if let found = findWKWebView(in: subview) { return found }
                }
                return nil
            }
            
            guard let webView = findWKWebView(in: hostingView) else { return }
            
            let js = """
            (function() {
                try {
                    if (window.player && window.player.setPlaybackQuality) {
                        window.player.setPlaybackQuality('\(quality)');
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
        guard !isReleased, youtubePlayer != nil else {
            completion([])
            return
        }
        
        createTask { @MainActor in
            guard let hostingView = self.playerHostingController?.view else {
                completion([])
                return
            }
            
            @MainActor
            func findWKWebView(in view: UIView) -> WKWebView? {
                if let webView = view as? WKWebView { return webView }
                for subview in view.subviews {
                    if let found = findWKWebView(in: subview) { return found }
                }
                return nil
            }
            
            guard let webView = findWKWebView(in: hostingView) else {
                completion([])
                return
            }
            
            let js = """
            (function() {
                try {
                    if (window.player && window.player.getAvailableQualityLevels) {
                        return window.player.getAvailableQualityLevels();
                    }
                    return [];
                } catch(e) {
                    return [];
                }
            })();
            """
            
            do {
                let result = try await webView.evaluateJavaScript(js)
                if let levels = result as? [String] {
                    completion(levels)
                } else {
                    completion([])
                }
            } catch {
                completion([])
            }
        }
    }
    
    func setPlaybackRate(rate: Double) {
        guard !isReleased, youtubePlayer != nil else { return }
        
        createTask { @MainActor in
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
            
            try? await self.youtubePlayer.set(playbackRate: playbackRate)
        }
    }
    
    func reload() {
        guard !isReleased, youtubePlayer != nil else { return }
        
        createTask { @MainActor in
            try? await self.youtubePlayer.reload()
        }
    }
    
    func cueVideo(videoId: String, startSeconds: Double = 0) {
        guard !isReleased, youtubePlayer != nil else { return }
        
        currentVideoId = videoId
        fetchVideoMetadata(videoId: videoId)
        
        let startTime = Measurement(value: startSeconds, unit: UnitDuration.seconds)
        createTask { @MainActor in
            let source = YouTubePlayer.Source.video(id: videoId)
            try? await self.youtubePlayer.cue(source: source, startTime: startTime)
        }
    }
    
    func loadVideo(videoId: String, startSeconds: Double = 0) {
        guard !isReleased, youtubePlayer != nil else { return }
        
        currentVideoId = videoId
        fetchVideoMetadata(videoId: videoId)
        
        let startTime = Measurement(value: startSeconds, unit: UnitDuration.seconds)
        createTask { @MainActor in
            let source = YouTubePlayer.Source.video(id: videoId)
            try? await self.youtubePlayer.load(source: source, startTime: startTime)
        }
    }
    
    func changeVideo(videoId: String) {
        guard !isReleased, youtubePlayer != nil else { return }
        loadVideo(videoId: videoId)
    }
    
    deinit {
        NSLog("[YOUTUBE] ===== DEINIT CALLED =====")
        cleanup()
    }
}

