#include "FileScanner.h"
#include <algorithm>
#include <iostream>

namespace fs = std::filesystem;

std::vector<AudioFileInfo> FileScanner::scanDirectory(const std::string& directoryPath) {
    std::vector<AudioFileInfo> audioFiles;

    if (!fs::exists(directoryPath) || !fs::is_directory(directoryPath)) {
        std::cerr << "[FileScanner] Error: Path does not exist or is not a directory: " << directoryPath << std::endl;
        return audioFiles;
    }

    const std::vector<std::string> extensions = { ".mp3", ".flac", ".ape", ".wav", ".ogg" };

    try {
        for (const auto& entry : fs::recursive_directory_iterator(directoryPath, fs::directory_options::skip_permission_denied)) {
            if (entry.is_regular_file()) {
                std::string ext = entry.path().extension().string();
                std::transform(ext.begin(), ext.end(), ext.begin(), [](unsigned char c) { return std::tolower(c); });

                if (std::find(extensions.begin(), extensions.end(), ext) != extensions.end()) {
                    AudioFileInfo info;
                    info.path = entry.path().string();
                    info.fileName = entry.path().filename().string();
                    info.extension = ext;
                    audioFiles.push_back(info);
                }
            }
        }
    } catch (const fs::filesystem_error& e) {
        std::cerr << "[FileScanner] Filesystem error: " << e.what() << std::endl;
    }

    return audioFiles;
}
