
Pod::Spec.new do |s|

    s.name         = "Ti.YoutubePlayer"
    s.version      = "1.2.0"
    s.summary      = "The Ti.YoutubePlayer Titanium module."
  
    s.description  = <<-DESC
                     The Ti.YoutubePlayer Titanium module.
                     DESC
  
   s.homepage     = "https://github.com/deckameron/Ti.YoutubePlayer"
    s.license      = { :type => "MIT", :file => "LICENSE" }
    s.author       = 'Douglas Alves'
  
    s.platform     = :ios
    s.ios.deployment_target = '14.0'
  
    s.source       = { :git => "https://github.com/deckameron/Ti.YoutubePlayer.git" }
    
    s.ios.weak_frameworks = 'UIKit', 'Foundation'

    s.ios.dependency 'TitaniumKit'
  
    s.public_header_files = 'Classes/*.h'
    s.source_files = 'Classes/*.{h,m,swift}'
  end