#pragma once

#include <string>
#include <vector>
#include <filesystem>

struct AudioFileInfo {
    std::string path;
    std::string fileName;
    std::string extension;
    std::string albumArtPath;
};

class FileScanner {
public:
    static std::vector<AudioFileInfo> scanDirectory(const std::string& path);
};
