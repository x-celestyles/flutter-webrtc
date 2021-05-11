#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_webrtc'
  s.version          = '0.2.2'
  s.summary          = 'Flutter WebRTC plugin for iOS.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'https://github.com/cloudwebrtc/flutter-webrtc'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'CloudWebRTC' => 'duanweiwei1982@gmail.com' }
  s.source           = { :path => '.' }
  #s.source           = { :path => 'https://github.com/huoda1237/YeasVideoImages.git'}
  
  #s.ios.vendored_frameworks = 'Frameworks/MLImageSegmentationLibrary.framework'
  #s.vendored_frameworks = 'MLImageSegmentationLibrary.framework'
  s.source_files = 'Classes/**/*'
  s.resources = 'Classes/Resources/*.png'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'Libyuv', '1703'
  s.dependency 'GoogleWebRTC', '1.1.31999'
  s.dependency 'GPUImage'
  #s.dependency 'YeasVideoImages'
  s.dependency 'MLImageSegmentationLibrary'
  s.ios.deployment_target = '12.0'
  s.static_framework = true

end

