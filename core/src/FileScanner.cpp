#include "FileScanner.h"
#include "MetadataExtractor.h"
#include <algorithm>
#include <iostream>

namespace fs = std::filesystem;

std::string findAlbumArt(const fs::path& directory) {
    const std::vector<std::string> artFiles = { "cover.jpg", "cover.png", "folder.jpg", "folder.png", "album.jpg" };
    for (const auto& entry : fs::directory_iterator(directory)) {
        if (entry.is_regular_file()) {
            std::string name = entry.path().filename().string();
            std::transform(name.begin(), name.end(), name.begin(), [](unsigned char c) { return std::tolower(c); });
            if (std::find(artFiles.begin(), artFiles.end(), name) != artFiles.end()) {
                return entry.path().string();
            }
        }
    }
    return "";
}

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
                    info.albumArtPath = findAlbumArt(entry.path().parent_path());

                    AudioMetadata meta = MetadataExtractor::extract(info.path);
                    info.title = meta.title;
                    info.artist = meta.artist;
                    info.album = meta.album;
                    info.durationSeconds = meta.durationSeconds;

                    audioFiles.push_back(info);
                }
            }
        }
    } catch (const fs::filesystem_error& e) {
        std::cerr << "[FileScanner] Filesystem error: " << e.what() << std::endl;
    }

    return audioFiles;
}
