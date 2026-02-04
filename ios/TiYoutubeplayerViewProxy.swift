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
    
    private var playerView: TiYoutubeplayerView {
        return view as! TiYoutubeplayerView
    }
    
    override func newView() -> TiUIView! {
        return TiYoutubeplayerView(frame: .zero)
    }
    
    @objc(play:)
    func play(args: [Any]?) {
        playerView.play()
    }
    
    @objc(pause:)
    func pause(args: [Any]?) {
        playerView.pause()
    }
    
    @objc(stop:)
    func stop(args: [Any]?) {
        playerView.stop()
    }
    
    @objc(mute:)
    func mute(args: [Any]?) {
        playerView.mute()
    }
    
    @objc(unmute:)
    func unmute(args: [Any]?) {
        playerView.unmute()
    }
    
    @objc(isMuted:)
    func isMuted(args: [Any]?) -> Bool {
        return playerView.isMuted
    }
    
    @objc(seek:)
    func seek(args: [Any]?) {
        guard let seconds = args?.first as? NSNumber else {
            return
        }
        playerView.seek(to: seconds.doubleValue)
    }
    
    @objc(getDuration:)
    func getDuration(args: [Any]?) {
        guard let callback = args?.first as? KrollCallback else {
            return
        }
        
        playerView.getDuration { duration in
            if let duration = duration {
                callback.call([["duration": duration]], thisObject: self)
            } else {
                callback.call([["duration": NSNull()]], thisObject: self)
            }
        }
    }
    
    @objc(getCurrentTime:)
    func getCurrentTime(args: [Any]?) {
        guard let callback = args?.first as? KrollCallback else {
            return
        }
        
        playerView.getCurrentTime { currentTime in
            if let currentTime = currentTime {
                callback.call([["currentTime": currentTime]], thisObject: self)
            } else {
                callback.call([["currentTime": NSNull()]], thisObject: self)
            }
        }
    }
    
    @objc(setPlaybackRate:)
    func setPlaybackRate(args: [Any]?) {
        guard let rate = args?.first as? NSNumber else {
            return
        }
        playerView.setPlaybackRate(rate: rate.doubleValue)
    }
    
    @objc(setPlaybackQuality:)
    func setPlaybackQuality(args: [Any]?) {
        guard let quality = args?.first as? String else {
            return
        }
        playerView.setPlaybackQuality(quality: quality)
    }

    @objc(getAvailableQualityLevels:)
    func getAvailableQualityLevels(args: [Any]?) {
        guard let callback = args?.first as? KrollCallback else {
            return
        }
        
        playerView.getAvailableQualityLevels { levels in
            callback.call([["levels": levels]], thisObject: self)
        }
    }
    
    @objc(reload:)
    func reload(args: [Any]?) {
        playerView.reload()
    }
    
    @objc(cueVideo:)
    func cueVideo(args: [Any]?) {
        guard let dict = args?.first as? [String: Any],
              let videoId = dict["videoId"] as? String else {
            return
        }
        let startSeconds = dict["startSeconds"] as? Double ?? 0.0
        playerView.cueVideo(videoId: videoId, startSeconds: startSeconds)
    }
    
    @objc(loadVideo:)
    func loadVideo(args: [Any]?) {
        guard let dict = args?.first as? [String: Any],
              let videoId = dict["videoId"] as? String else {
            return
        }
        let startSeconds = dict["startSeconds"] as? Double ?? 0.0
        playerView.loadVideo(videoId: videoId, startSeconds: startSeconds)
    }
    
    @objc(changeVideo:)
    func changeVideo(args: [Any]?) {
        guard let videoId = args?.first as? String else {
            return
        }
        playerView.changeVideo(videoId: videoId)
    }
}
