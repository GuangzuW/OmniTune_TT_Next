#include "LyricsParser.h"
#include <regex>
#include <algorithm>
#include <iostream>

std::vector<LyricLine> LyricsParser::parse(const std::string& lrcContent) {
    std::vector<LyricLine> lyrics;
    std::regex lyricRegex(R"(\[(\d{2}):(\d{2})\.(\d{2,3})\](.*))");
    std::smatch match;

    std::string line;
    std::string content = lrcContent;
    size_t pos = 0;
    while ((pos = content.find('\n')) != std::string::npos || !content.empty()) {
        if (pos != std::string::npos) {
            line = content.substr(0, pos);
            content.erase(0, pos + 1);
        } else {
            line = content;
            content.clear();
        }

        if (std::regex_search(line, match, lyricRegex)) {
            float minutes = std::stof(match[1].str());
            float seconds = std::stof(match[2].str());
            float milliseconds = std::stof(match[3].str());
            
            // Adjust for 2-digit vs 3-digit ms
            if (match[3].length() == 2) {
                milliseconds *= 10;
            }

            float timestamp = minutes * 60.0f + seconds + milliseconds / 1000.0f;
            std::string text = match[4].str();

            lyrics.push_back({timestamp, text});
        }
    }

    std::sort(lyrics.begin(), lyrics.end(), [](const LyricLine& a, const LyricLine& b) {
        return a.timestamp < b.timestamp;
    });

    return lyrics;
}
