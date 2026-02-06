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

class TiYoutubeplayerView: TiUIView {
    
    private var youtubePlayer: YouTubePlayer!
    private var playerHostingController: UIHostingController<AnyView>?
    private var cancellables = Set<AnyCancellable>()
    var isMuted: Bool = true
    private var preferredQuality: String = "hd1080"
    
    override func initializeState() {
        super.initializeState()
        
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.backgroundColor = .black
        self.clipsToBounds = true
    }
    
    override func frameSizeChanged(_ frame: CGRect, bounds: CGRect) {
        super.frameSizeChanged(frame, bounds: bounds)
        
        playerHostingController?.view.frame = bounds
    }
    
    override func configurationSet() {
        super.configurationSet()
        
        guard let videoId = proxy.value(forKey: "videoId") as? String else {
            debugPrint("[ERROR] videoId is required")
            return
        }
        
        let autoplay = proxy.value(forKey: "autoplay") as? Bool ?? true
        let loop = proxy.value(forKey: "loop") as? Bool ?? true
        let controls = proxy.value(forKey: "controls") as? Bool ?? false
        let muted = proxy.value(forKey: "muted") as? Bool ?? true
        // let aspectFill = proxy.value(forKey: "aspectFill") as? Bool ?? true
        let scalingMode = proxy.value(forKey: "scalingMode") as? String ?? "SCALING_ASPECT_FIT"
        let showCaptions = proxy.value(forKey: "showCaptions") as? Bool ?? false
        let showFullscreenButton = proxy.value(forKey: "showFullscreenButton") as? Bool ?? false
        let keyboardControlsDisabled = proxy.value(forKey: "keyboardControlsDisabled") as? Bool ?? true
        let startSeconds = proxy.value(forKey: "startSeconds") as? Double ?? 0.0
        
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
        
        let configuredView: AnyView
        
        if scalingMode == "SCALING_ASPECT_FILL" {
            // FULL FILL - força o vídeo a preencher toda área
            configuredView = AnyView(
                GeometryReader { geometry in
                    let videoAspect: CGFloat = 16.0 / 9.0
                    let containerAspect = geometry.size.width / geometry.size.height
                    
                    // Calcula o scale necessário
                    let scale: CGFloat
                    if containerAspect > videoAspect {
                        // Container mais largo que o vídeo - escala pela largura
                        scale = 1.0
                    } else {
                        // Container mais alto que o vídeo - escala pela altura
                        scale = (geometry.size.height / geometry.size.width) * videoAspect
                    }
                    
                    return YouTubePlayerView(self.youtubePlayer) { state in }
                        .frame(width: geometry.size.width * scale, height: geometry.size.width * scale / videoAspect)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .clipped()
                }
                    .clipped()
            )
        } else {
            // FIT - mantém aspect ratio
            configuredView = AnyView(
                YouTubePlayerView(youtubePlayer) { state in }
                    .aspectRatio(16/9, contentMode: .fit)
            )
        }
        
        let hostingController = UIHostingController(rootView: configuredView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = self.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.addSubview(hostingController.view)
        self.playerHostingController = hostingController
        
        setupObservers()
        
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
    
    private func forceHighQuality() {
        setPlaybackQuality(quality: preferredQuality)
        
        // Também tenta via JavaScript direto
        guard let hostingView = playerHostingController?.view else { return }
        
        func findWKWebView(in view: UIView) -> WKWebView? {
            if let webView = view as? WKWebView {
                return webView
            }
            for subview in view.subviews {
                if let found = findWKWebView(in: subview) {
                    return found
                }
            }
            return nil
        }
        
        guard let webView = findWKWebView(in: hostingView) else { return }
        
        // JavaScript agressivo para forçar qualidade
        let js = """
        (function() {
            try {
                // Tenta múltiplas vezes com delay
                function setQuality() {
                    if (window.player && window.player.setPlaybackQuality) {
                        window.player.setPlaybackQuality('\(preferredQuality)');
                        
                        // Também tenta setPlaybackQualityRange se disponível
                        if (window.player.setPlaybackQualityRange) {
                            window.player.setPlaybackQualityRange('\(preferredQuality)', '\(preferredQuality)');
                        }
                        
                        console.log('Quality set to \(preferredQuality)');
                    } else {
                        setTimeout(setQuality, 500);
                    }
                }
                setQuality();
                
                // Reforça a cada 2 segundos nos primeiros 10 segundos
                var attempts = 0;
                var interval = setInterval(function() {
                    attempts++;
                    if (attempts >= 5) {
                        clearInterval(interval);
                        return;
                    }
                    
                    if (window.player && window.player.setPlaybackQuality) {
                        window.player.setPlaybackQuality('\(preferredQuality)');
                    }
                }, 2000);
                
                return 'quality enforcement started';
            } catch(e) {
                return 'error: ' + e.message;
            }
        })();
        """
        
        webView.evaluateJavaScript(js) { result, error in
            if let error = error {
                debugPrint("[ERROR] Failed to force quality: \(error)")
            } else if let result = result as? String {
                debugPrint("[DEBUG] Force quality result: \(result)")
            }
        }
    }
    
    private func setupObservers() {
        // Observer: Estado do player (ready, error, idle)
        youtubePlayer.statePublisher
            .sink { [weak self] state in
                guard let self = self else { return }
                
                switch state {
                case .idle:
                    self.proxy.fireEvent("playerStateChange", with: ["playerState": "idle"])
                case .ready:
                    self.proxy.fireEvent("playerStateChange", with: ["playerState": "ready"])
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
        
        // Observer: Estado de playback (playing, paused, ended, etc)
        youtubePlayer.playbackStatePublisher
            .sink { [weak self] playbackState in
                guard let self = self else { return }
                
                var stateString = "unknown"
                var stateCode = -1
                
                switch playbackState {
                case .unstarted:
                    stateString = "unstarted"
                    stateCode = -1
                case .ended:
                    stateString = "ended"
                    stateCode = 0
                case .playing:
                    stateString = "playing"
                    stateCode = 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.forceHighQuality()
                    }
                case .paused:
                    stateString = "paused"
                    stateCode = 2
                case .buffering:
                    stateString = "buffering"
                    stateCode = 3
                case .cued:
                    stateString = "cued"
                    stateCode = 5
                default:
                    break
                }
                
                self.proxy.fireEvent("playbackStateChange", with: [
                    "state": stateString,
                    "code": stateCode
                ])
            }
            .store(in: &cancellables)
        
        // Observer: Qualidade de playback
        youtubePlayer.playbackQualityPublisher
            .sink { [weak self] quality in
                guard let self = self else { return }
                
                var qualityString = "unknown"
                
                switch quality {
                case .auto:
                    qualityString = "auto"
                case .small:
                    qualityString = "small"
                case .medium:
                    qualityString = "medium"
                case .large:
                    qualityString = "large"
                case .hd720:
                    qualityString = "hd720"
                case .hd1080:
                    qualityString = "hd1080"
                case .highResolution:
                    qualityString = "highres"
                default:
                    break
                }
                
                self.proxy.fireEvent("playbackQualityChange", with: ["quality": qualityString])
            }
            .store(in: &cancellables)
        
        // Observer: Taxa de reprodução (playback rate)
        youtubePlayer.playbackRatePublisher
            .sink { [weak self] rate in
                guard let self = self else { return }
                
                self.proxy.fireEvent("playbackRateChange", with: ["rate": rate.value])
            }
            .store(in: &cancellables)
        
        // Observer: Metadados (título, autor, videoId)
        youtubePlayer.playbackMetadataPublisher
            .sink { [weak self] metadata in
                guard let self = self else { return }
                
                var metadataDict: [String: Any] = [:]
                
                if let title = metadata.title {
                    metadataDict["title"] = title
                }
                if let author = metadata.author {
                    metadataDict["author"] = author
                }
                if let videoId = metadata.videoId {
                    metadataDict["videoId"] = videoId
                }
                
                if !metadataDict.isEmpty {
                    self.proxy.fireEvent("metadataReceived", with: metadataDict)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func play() {
        Task { @MainActor in
            try? await youtubePlayer.play()
        }
    }
    
    func pause() {
        Task { @MainActor in
            try? await youtubePlayer.pause()
        }
    }
    
    func stop() {
        Task { @MainActor in
            try? await youtubePlayer.stop()
        }
    }
    
    func mute() {
        Task { @MainActor in
            try? await youtubePlayer.mute()
            self.isMuted = true
            self.proxy.fireEvent("muteChanged", with: ["muted": true])
        }
    }
    
    func unmute() {
        Task { @MainActor in
            try? await youtubePlayer.unmute()
            self.isMuted = false
            self.proxy.fireEvent("muteChanged", with: ["muted": false])
        }
    }
    
    func seek(to seconds: Double) {
        let time = Measurement(value: seconds, unit: UnitDuration.seconds)

        Task { @MainActor in
            try? await youtubePlayer.seek(
                to: time,
                allowSeekAhead: true
            )
        }
    }
    
    func getDuration(completion: @escaping (Double?) -> Void) {
        Task { @MainActor in
            guard let duration = try? await youtubePlayer.getDuration() else {
                completion(nil)
                return
            }

            completion(duration.converted(to: .seconds).value)
        }
    }
    
    func getCurrentTime(completion: @escaping (Double?) -> Void) {
        Task { @MainActor in
            guard let currentTime = try? await youtubePlayer.getCurrentTime() else {
                completion(nil)
                return
            }
            completion(currentTime.converted(to: .seconds).value)
        }
    }
    
    func setPlaybackQuality(quality: String) {
        Task { @MainActor in
            // YouTubePlayerKit não expõe setPlaybackQuality diretamente
            // Mas podemos tentar forçar via JavaScript evaluation
            guard let hostingView = playerHostingController?.view else { return }
            
            // Procura o WKWebView
            @MainActor
            func findWKWebView(in view: UIView) -> WKWebView? {
                if let webView = view as? WKWebView {
                    return webView
                }
                for subview in view.subviews {
                    if let found = findWKWebView(in: subview) {
                        return found
                    }
                }
                return nil
            }
            
            guard let webView = findWKWebView(in: hostingView) else {
                debugPrint("[ERROR] WKWebView not found for quality change")
                return
            }
            
            // Tenta setar a qualidade via JavaScript
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
            
            do {
                let result = try await webView.evaluateJavaScript(js)
                if let resultString = result as? String {
                    debugPrint("[DEBUG] Set quality result: \(resultString)")
                }
            } catch {
                debugPrint("[ERROR] Failed to set quality: \(error)")
            }
        }
    }

    func getAvailableQualityLevels(completion: @escaping ([String]) -> Void) {
        Task { @MainActor in
            guard let hostingView = playerHostingController?.view else {
                completion([])
                return
            }
            
            @MainActor
            func findWKWebView(in view: UIView) -> WKWebView? {
                if let webView = view as? WKWebView {
                    return webView
                }
                for subview in view.subviews {
                    if let found = findWKWebView(in: subview) {
                        return found
                    }
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
        Task { @MainActor in
            let playbackRate: YouTubePlayer.PlaybackRate
            switch rate {
            case 0.25:
                playbackRate = .quarterSpeed
            case 0.5:
                playbackRate = .halfSpeed
            case 0.75:
                playbackRate = .threeQuarterSpeed
            case 1.0:
                playbackRate = .normal
            case 1.25:
                playbackRate = .oneQuarterFaster
            case 1.5:
                playbackRate = .oneHalfFaster
            case 1.75:
                playbackRate = .threeQuarterFaster
            case 2.0:
                playbackRate = .double
            default:
                playbackRate = .normal
            }
            
            try? await youtubePlayer.set(playbackRate: playbackRate)
        }
    }
    
    func reload() {
        Task { @MainActor in
            try? await youtubePlayer.reload()
        }
    }
    
    func cueVideo(videoId: String, startSeconds: Double = 0) {
        let startTime = Measurement(value: startSeconds, unit: UnitDuration.seconds)
        Task { @MainActor in
            let source = YouTubePlayer.Source.video(id: videoId)
            try? await youtubePlayer.cue(source: source, startTime: startTime)
        }
    }
    
    func loadVideo(videoId: String, startSeconds: Double = 0) {
        let startTime = Measurement(value: startSeconds, unit: UnitDuration.seconds)
        Task { @MainActor in
            let source = YouTubePlayer.Source.video(id: videoId)
            try? await youtubePlayer.load(source: source, startTime: startTime)
        }
    }
    
    func changeVideo(videoId: String) {
        loadVideo(videoId: videoId)
    }
}
