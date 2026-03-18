#pragma once

#include <string>
#include <vector>
#include <filesystem>

struct AudioFileInfo {
    std::string path;
    std::string fileName;
    std::string extension;
    // Basic metadata can be added later
};

class FileScanner {
public:
    static std::vector<AudioFileInfo> scanDirectory(const std::string& path);
};
