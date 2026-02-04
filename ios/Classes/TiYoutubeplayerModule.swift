//
//  TiYoutubeplayerModule.swift
//  Ti.YoutubePlayer
//
//  Created by Douglas Alves
//  Copyright (c) 2026 Upflix Inc. All rights reserved.
//

import UIKit
import TitaniumKit
import YouTubePlayerKit

/**
 
 Titanium Swift Module Requirements
 ---
 
 1. Use the @objc annotation to expose your class to Objective-C (used by the Titanium core)
 2. Use the @objc annotation to expose your method to Objective-C as well.
 3. Method arguments always have the "[Any]" type, specifying a various number of arguments.
 Unwrap them like you would do in Swift, e.g. "guard let arguments = arguments, let message = arguments.first"
 4. You can use any public Titanium API like before, e.g. TiUtils. Remember the type safety of Swift, like Int vs Int32
 and NSString vs. String.
 
 */

@objc(TiYoutubeplayerModule)
class TiYoutubeplayerModule: TiModule {
  
  func moduleGUID() -> String {
    return "a65f9da6-bc17-4eb6-8786-93a9bc633d9b"
  }
  
  override func moduleId() -> String! {
    return "ti.youtubeplayer"
  }

  override func startup() {
    super.startup()
    debugPrint("[DEBUG] \(self) loaded")
  }
    
    @objc(createPlayerView:)
    func createPlayerView(args: [Any]?) -> TiYoutubeplayerViewProxy {
        var properties: [AnyHashable: Any] = [:]
        
        if let firstArg = args?.first as? [AnyHashable: Any] {
            properties = firstArg
        }
        
        let proxy = TiYoutubeplayerViewProxy()
        proxy._init(withProperties: properties)
        
        return proxy
    }
    
    // MARK: - Constants
    
    @objc(AUTO)
    var PLAYBACK_QUALITY_AUTO: String {
        return YouTubePlayer.PlaybackQuality.auto.name
    }
    
    @objc(SMALL)
    var PLAYBACK_QUALITY_SMALL: String {
        return YouTubePlayer.PlaybackQuality.small.name
    }
    
    @objc(MEDIUM)
    var PLAYBACK_QUALITY_MEDIUM: String {
        return YouTubePlayer.PlaybackQuality.medium.name
    }
    
    @objc(HD720)
    var PLAYBACK_QUALITY_HD720: String {
        return YouTubePlayer.PlaybackQuality.hd720.name
    }
    
    @objc(HD1080)
    var PLAYBACK_QUALITY_HD1080: String {
        return YouTubePlayer.PlaybackQuality.hd1080.name
    }
    
    @objc(HIGH_RESOLUTION)
    var PLAYBACK_QUALITY_HIGH_RESOLUTION: String {
        return YouTubePlayer.PlaybackQuality.highResolution.name
    }
    
    @objc(SCALING_ASPECT_FILL)
    var SCALING_ASPECT_FILL: String {
        return "SCALING_ASPECT_FILL"
    }
    
    @objc(SCALING_ASPECT_FIT)
    var SCALING_ASPECT_FIT: String {
        return "SCALING_ASPECT_FIT"
    }    
}
