#pragma once

#include <string>

// Embedded tag metadata for an audio file.
// Empty title/artist/album means the tag was absent — callers should fall back
// to the filename. durationSeconds is 0.0 if it could not be determined.
struct AudioMetadata {
    std::string title;
    std::string artist;
    std::string album;
    float durationSeconds = 0.0f;
};

// Reads embedded tags (ID3v2 for MP3, Vorbis comments for FLAC/OGG) and decodes
// the duration via miniaudio. Best-effort: any field that cannot be read is left
// empty / zero rather than failing the whole extraction.
class MetadataExtractor {
public:
    static AudioMetadata extract(const std::string& filePath);
};
