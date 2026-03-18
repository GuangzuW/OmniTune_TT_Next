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
)

add_executable(test_core test/test_core.cpp)
target_link_libraries(test_core TTPlayerCore)

# Platform specific configurations
if(WIN32)
    target_link_libraries(TTPlayerCore PUBLIC winmm)
elseif(APPLE)
    find_library(CORE_AUDIO CoreAudio)
    find_library(AUDIO_TOOLBOX AudioToolbox)
    target_link_libraries(TTPlayerCore PUBLIC ${CORE_AUDIO} ${AUDIO_TOOLBOX})
elseif(UNIX AND NOT APPLE)
    target_link_libraries(TTPlayerCore PUBLIC asound dl pthread m)
endif()
