//
//  TiYoutubeplayerViewProxy.swift
//  TiYoutubeplayer
//
//  Created by Douglas Alves on 31/01/26.
//  Copyright (c) 2026 Upflix Inc. All rights reserved.
//


import UIKit
import TitaniumKit

@objc(TiYoutubeplayerViewProxy)
class TiYoutubeplayerViewProxy: TiViewProxy {

    /// Weak handle to the view created by `newView()`.
    ///
    /// Reading `self.view` here would be wrong: proxy methods run on the Kroll (JS)
    /// thread, and the `view` getter builds the view on the calling thread and
    /// re-creates it after `detachView`. Both produce UIKit/WebKit work off the main
    /// thread and orphaned players.
    private weak var playerViewRef: TiYoutubeplayerView?

    /// Commands issued before Titanium built the view.
    ///
    /// `createPlayerView(...)` followed immediately by `play()` runs entirely on the
    /// Kroll thread, while the native view is only built on the next layout pass.
    /// Dropping those calls leaves the player idle forever when `autoplay` is off, so
    /// they are held here and replayed from `newView()`.
    private var pendingCommands: [(TiYoutubeplayerView) -> Void] = []
    private let pendingLock = NSLock()

    /// Upper bound so a view that never gets built cannot grow this without limit.
    private static let maxPendingCommands = 32

    override func newView() -> TiUIView! {
        let view = TiYoutubeplayerView(frame: .zero)
        playerViewRef = view
        drainPendingCommands(into: view)
        return view
    }

    private func drainPendingCommands(into view: TiYoutubeplayerView) {
        pendingLock.lock()
        let commands = pendingCommands
        pendingCommands.removeAll()
        pendingLock.unlock()

        guard !commands.isEmpty else { return }

        TiThreadPerformOnMainThread({
            commands.forEach { $0(view) }
        }, false)
    }

    private func discardPendingCommands() {
        pendingLock.lock()
        pendingCommands.removeAll()
        pendingLock.unlock()
    }

    /// Runs `block` against the player view on the main thread, queueing it if the
    /// view does not exist yet.
    private func onPlayerView(_ block: @escaping (TiYoutubeplayerView) -> Void) {
        TiThreadPerformOnMainThread({ [weak self] in
            guard let self = self else { return }

            if let view = self.playerViewRef {
                block(view)
                return
            }

            self.pendingLock.lock()
            if self.pendingCommands.count < Self.maxPendingCommands {
                self.pendingCommands.append(block)
            }
            self.pendingLock.unlock()
        }, false)
    }

    override func viewWillDetach() {
        // Deterministic teardown while the proxy is still alive, so no async
        // callback can outlive it.
        discardPendingCommands()
        let view = playerViewRef
        TiThreadPerformOnMainThread({
            view?.cleanup()
        }, false)
        super.viewWillDetach()
    }

    @objc(play:)
    func play(args: [Any]?) {
        onPlayerView { $0.play() }
    }

    @objc(pause:)
    func pause(args: [Any]?) {
        onPlayerView { $0.pause() }
    }

    @objc(release:)
    func release(args: [Any]?) {
        // Anything still queued is for a player the caller is discarding.
        discardPendingCommands()
        onPlayerView { $0.cleanup() }
    }

    @objc(stop:)
    func stop(args: [Any]?) {
        onPlayerView { $0.stop() }
    }

    @objc(mute:)
    func mute(args: [Any]?) {
        onPlayerView { $0.mute() }
    }

    @objc(unmute:)
    func unmute(args: [Any]?) {
        onPlayerView { $0.unmute() }
    }

    @objc(isMuted:)
    func isMuted(args: [Any]?) -> NSNumber {
        return NSNumber(value: playerViewRef?.isMuted ?? true)
    }

    @objc(seek:)
    func seek(args: [Any]?) {
        guard let seconds = args?.first as? NSNumber else {
            return
        }
        onPlayerView { $0.seek(to: seconds.doubleValue) }
    }

    /// Unwraps an argument that may arrive either as a bare value (KVC, when the
    /// key is passed in the creation dictionary) or wrapped in the argument array
    /// (when JS calls the method directly).
    private static func firstArgument(_ value: Any?) -> Any? {
        if let array = value as? [Any] {
            return array.first
        }
        return value
    }

    @objc(setScalingMode:)
    func setScalingMode(value: Any?) {
        guard let mode = (Self.firstArgument(value) as? NSNumber)?.intValue else {
            return
        }

        // A `setX:` selector makes KVC bypass TiProxy's `setValue:forUndefinedKey:`,
        // so the value never reaches dynprops on its own. Write it back explicitly:
        // configurationSet() reads `scalingMode` from the proxy when the view is
        // finally built, which happens after this setter runs.
        replaceValue(NSNumber(value: mode), forKey: "scalingMode", notification: false)

        onPlayerView { $0.setScalingMode(mode: mode) }
    }

    @objc(getDuration:)
    func getDuration(args: [Any]?) {
        guard let callback = args?.first as? KrollCallback else {
            return
        }

        onPlayerView { [weak self] view in
            view.getDuration { duration in
                guard let self = self else { return }
                callback.call([["duration": duration.map { $0 as Any } ?? NSNull()]], thisObject: self)
            }
        }
    }

    @objc(getCurrentTime:)
    func getCurrentTime(args: [Any]?) {
        guard let callback = args?.first as? KrollCallback else {
            return
        }

        onPlayerView { [weak self] view in
            view.getCurrentTime { currentTime in
                guard let self = self else { return }
                callback.call([["currentTime": currentTime.map { $0 as Any } ?? NSNull()]], thisObject: self)
            }
        }
    }

    @objc(setPlaybackRate:)
    func setPlaybackRate(value: Any?) {
        guard let rate = (Self.firstArgument(value) as? NSNumber)?.doubleValue else {
            return
        }

        replaceValue(NSNumber(value: rate), forKey: "playbackRate", notification: false)
        onPlayerView { $0.setPlaybackRate(rate: rate) }
    }

    @objc(setPlaybackQuality:)
    func setPlaybackQuality(value: Any?) {
        guard let quality = Self.firstArgument(value) as? String else {
            return
        }

        replaceValue(quality, forKey: "playbackQuality", notification: false)
        onPlayerView { $0.setPlaybackQuality(quality: quality) }
    }

    @objc(getAvailableQualityLevels:)
    func getAvailableQualityLevels(args: [Any]?) {
        guard let callback = args?.first as? KrollCallback else {
            return
        }

        onPlayerView { [weak self] view in
            view.getAvailableQualityLevels { levels in
                guard let self = self else { return }
                callback.call([["levels": levels]], thisObject: self)
            }
        }
    }

    @objc(reload:)
    func reload(args: [Any]?) {
        onPlayerView { $0.reload() }
    }

    @objc(cueVideo:)
    func cueVideo(args: [Any]?) {
        guard let dict = args?.first as? [String: Any],
              let videoId = dict["videoId"] as? String else {
            return
        }
        let startSeconds = dict["startSeconds"] as? Double ?? 0.0
        onPlayerView { $0.cueVideo(videoId: videoId, startSeconds: startSeconds) }
    }

    @objc(loadVideo:)
    func loadVideo(args: [Any]?) {
        guard let dict = args?.first as? [String: Any],
              let videoId = dict["videoId"] as? String else {
            return
        }
        let startSeconds = dict["startSeconds"] as? Double ?? 0.0
        onPlayerView { $0.loadVideo(videoId: videoId, startSeconds: startSeconds) }
    }

    @objc(changeVideo:)
    func changeVideo(args: [Any]?) {
        guard let videoId = args?.first as? String else {
            return
        }
        onPlayerView { $0.changeVideo(videoId: videoId) }
    }
}
