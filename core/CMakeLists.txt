cmake_minimum_required(VERSION 3.10)
project(TTPlayerCore)

set(CMAKE_CXX_STANDARD 17)

include_directories(include)

add_library(TTPlayerCore SHARED
    src/AudioPlayer.cpp
    src/AudioPlayer_c.cpp
    src/FileScanner.cpp
    src/LyricsParser.cpp
    src/Equalizer.cpp
    src/MetadataExtractor.cpp
)

# On Windows, export all symbols so the extern "C" ABI is visible in the DLL
# export table. Without this MSVC produces no import .lib and the Dart FFI
# (and test_core) cannot resolve the C functions at runtime.
set_target_properties(TTPlayerCore PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)

add_executable(test_core test/test_core.cpp)
target_link_libraries(test_core TTPlayerCore)

# Platform specific configurations
if(ANDROID)
    # miniaudio uses AAudio (dlopen'd) / OpenSL ES on Android; link OpenSLES + log.
    target_link_libraries(TTPlayerCore PUBLIC OpenSLES log)
elseif(WIN32)
    target_link_libraries(TTPlayerCore PUBLIC winmm)
elseif(APPLE)
    # Covers both macOS and iOS (CoreAudio + AudioToolbox).
    find_library(CORE_AUDIO CoreAudio)
    find_library(AUDIO_TOOLBOX AudioToolbox)
    target_link_libraries(TTPlayerCore PUBLIC ${CORE_AUDIO} ${AUDIO_TOOLBOX})
    if(IOS)
        find_library(AVFOUNDATION AVFoundation)
        target_link_libraries(TTPlayerCore PUBLIC ${AVFOUNDATION})
    endif()
elseif(UNIX AND NOT APPLE)
    target_link_libraries(TTPlayerCore PUBLIC asound dl pthread m)
endif()

# test_core is a desktop-only convenience target; skip it on mobile NDK builds.
if(ANDROID OR IOS)
    set_target_properties(test_core PROPERTIES EXCLUDE_FROM_ALL TRUE)
endif()
