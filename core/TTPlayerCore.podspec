#
# CocoaPods spec that compiles the C++ audio core into the iOS/macOS app so the
# Dart FFI can resolve its symbols via DynamicLibrary.process().
#
# Wire it up by adding this line to app/ios/Podfile (inside target 'Runner'):
#   pod 'TTPlayerCore', :path => '../../core'
# then run `cd app/ios && pod install`.
#
Pod::Spec.new do |s|
  s.name             = 'TTPlayerCore'
  s.version          = '1.0.0'
  s.summary          = 'OmniTune high-performance C++ audio core.'
  s.description      = 'miniaudio-based playback engine, equalizer, scanner and lyrics parser.'
  s.homepage         = 'https://github.com/omnitune/tt-next'
  s.license          = { :type => 'MIT' }
  s.author           = { 'OmniTune' => 'dev@omnitune.app' }
  s.source           = { :path => '.' }

  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.14'

  s.source_files        = 'src/**/*.cpp', 'include/**/*.h'
  s.public_header_files = 'include/AudioPlayer_c.h'
  s.requires_arc        = false

  s.frameworks = 'AudioToolbox', 'CoreAudio', 'AVFoundation'
  s.libraries  = 'c++'

  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY'           => 'libc++',
    'HEADER_SEARCH_PATHS'         => '"${PODS_TARGET_SRCROOT}/include"',
    # Keep the exported C symbols so Dart FFI's dlsym can find them in the
    # statically-linked binary (the linker would otherwise dead-strip them).
    'GCC_SYMBOLS_PRIVATE_EXTERN'  => 'NO',
    'DEAD_CODE_STRIPPING'         => 'NO',
  }
end
