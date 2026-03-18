#pragma once

#include <string>
#include <vector>

struct LyricLine {
    float timestamp; // in seconds
    std::string text;
};

class LyricsParser {
public:
    static std::vector<LyricLine> parse(const std::string& lrcContent);
};
