#include "MetadataExtractor.h"
#include "miniaudio.h"  // declarations only; implementation lives in AudioPlayer.cpp

#include <cstdint>
#include <cstring>
#include <fstream>
#include <vector>
#include <algorithm>

namespace {

// ---- small encoding helpers -------------------------------------------------

// Convert a UTF-16 (LE or BE) byte buffer to UTF-8.
std::string utf16ToUtf8(const unsigned char* data, size_t len, bool bigEndian) {
    std::string out;
    out.reserve(len);
    for (size_t i = 0; i + 1 < len; i += 2) {
        uint32_t cp = bigEndian ? (data[i] << 8 | data[i + 1])
                                : (data[i + 1] << 8 | data[i]);
        if (cp == 0) break;
        // Surrogate pairs are rare in tags; emit the BMP code point directly.
        if (cp < 0x80) {
            out.push_back(static_cast<char>(cp));
        } else if (cp < 0x800) {
            out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        } else {
            out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
            out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        }
    }
    return out;
}

// Latin-1 -> UTF-8.
std::string latin1ToUtf8(const unsigned char* data, size_t len) {
    std::string out;
    out.reserve(len);
    for (size_t i = 0; i < len; ++i) {
        unsigned char c = data[i];
        if (c == 0) break;
        if (c < 0x80) {
            out.push_back(static_cast<char>(c));
        } else {
            out.push_back(static_cast<char>(0xC0 | (c >> 6)));
            out.push_back(static_cast<char>(0x80 | (c & 0x3F)));
        }
    }
    return out;
}

// Decode an ID3v2 text frame payload given its leading encoding byte.
std::string decodeId3Text(const std::vector<unsigned char>& buf) {
    if (buf.empty()) return "";
    unsigned char encoding = buf[0];
    const unsigned char* p = buf.data() + 1;
    size_t n = buf.size() - 1;
    switch (encoding) {
        case 0: return latin1ToUtf8(p, n);                 // ISO-8859-1
        case 1: { // UTF-16 with BOM
            if (n >= 2 && p[0] == 0xFF && p[1] == 0xFE) return utf16ToUtf8(p + 2, n - 2, false);
            if (n >= 2 && p[0] == 0xFE && p[1] == 0xFF) return utf16ToUtf8(p + 2, n - 2, true);
            return utf16ToUtf8(p, n, false);
        }
        case 2: return utf16ToUtf8(p, n, true);            // UTF-16BE, no BOM
        case 3: default: return std::string(reinterpret_cast<const char*>(p), n); // UTF-8
    }
}

uint32_t synchsafe(const unsigned char* b) {
    return (uint32_t(b[0] & 0x7F) << 21) | (uint32_t(b[1] & 0x7F) << 14) |
           (uint32_t(b[2] & 0x7F) << 7) | uint32_t(b[3] & 0x7F);
}

uint32_t beU32(const unsigned char* b) {
    return (uint32_t(b[0]) << 24) | (uint32_t(b[1]) << 16) | (uint32_t(b[2]) << 8) | uint32_t(b[3]);
}

uint32_t leU32(const unsigned char* b) {
    return uint32_t(b[0]) | (uint32_t(b[1]) << 8) | (uint32_t(b[2]) << 16) | (uint32_t(b[3]) << 24);
}

// ---- ID3v2 (MP3) ------------------------------------------------------------

void parseId3v2(std::ifstream& f, AudioMetadata& meta) {
    unsigned char header[10];
    f.read(reinterpret_cast<char*>(header), 10);
    if (f.gcount() != 10 || std::memcmp(header, "ID3", 3) != 0) return;

    int major = header[3];
    uint32_t tagSize = synchsafe(header + 6);
    bool footer = (header[5] & 0x10) != 0;

    std::vector<unsigned char> body(tagSize);
    f.read(reinterpret_cast<char*>(body.data()), tagSize);
    if (static_cast<uint32_t>(f.gcount()) < tagSize) body.resize(static_cast<size_t>(f.gcount()));
    (void)footer;

    size_t pos = 0;
    const bool v22 = (major == 2);
    const size_t idLen = v22 ? 3 : 4;
    const size_t hdrLen = v22 ? 6 : 10;

    while (pos + hdrLen <= body.size()) {
        char id[5] = {0};
        std::memcpy(id, body.data() + pos, idLen);
        if (id[0] == 0) break; // padding

        uint32_t frameSize;
        if (v22) {
            frameSize = (uint32_t(body[pos + 3]) << 16) | (uint32_t(body[pos + 4]) << 8) | uint32_t(body[pos + 5]);
        } else if (major == 4) {
            frameSize = synchsafe(body.data() + pos + 4); // v2.4 = synchsafe
        } else {
            frameSize = beU32(body.data() + pos + 4);      // v2.3 = plain
        }
        size_t dataStart = pos + hdrLen;
        if (frameSize == 0 || dataStart + frameSize > body.size()) break;

        std::vector<unsigned char> payload(body.begin() + dataStart, body.begin() + dataStart + frameSize);
        std::string idStr(id);

        if (idStr == "TIT2" || idStr == "TT2") meta.title  = decodeId3Text(payload);
        else if (idStr == "TPE1" || idStr == "TP1") meta.artist = decodeId3Text(payload);
        else if (idStr == "TALB" || idStr == "TAL") meta.album  = decodeId3Text(payload);

        pos = dataStart + frameSize;
    }
}

// ---- Vorbis comments (FLAC) -------------------------------------------------

void applyVorbisComment(const std::string& comment, AudioMetadata& meta) {
    auto eq = comment.find('=');
    if (eq == std::string::npos) return;
    std::string key = comment.substr(0, eq);
    std::string val = comment.substr(eq + 1);
    std::transform(key.begin(), key.end(), key.begin(), [](unsigned char c) { return std::toupper(c); });
    if (key == "TITLE") meta.title = val;
    else if (key == "ARTIST") meta.artist = val;
    else if (key == "ALBUM") meta.album = val;
}

void parseFlac(std::ifstream& f, AudioMetadata& meta) {
    char marker[4];
    f.read(marker, 4);
    if (f.gcount() != 4 || std::memcmp(marker, "fLaC", 4) != 0) return;

    while (f) {
        unsigned char blockHeader[4];
        f.read(reinterpret_cast<char*>(blockHeader), 4);
        if (f.gcount() != 4) break;
        bool isLast = (blockHeader[0] & 0x80) != 0;
        int blockType = blockHeader[0] & 0x7F;
        uint32_t blockLen = (uint32_t(blockHeader[1]) << 16) | (uint32_t(blockHeader[2]) << 8) | uint32_t(blockHeader[3]);

        if (blockType == 4) { // VORBIS_COMMENT
            std::vector<unsigned char> block(blockLen);
            f.read(reinterpret_cast<char*>(block.data()), blockLen);
            if (static_cast<uint32_t>(f.gcount()) < blockLen) return;
            size_t p = 0;
            if (p + 4 > block.size()) return;
            uint32_t vendorLen = leU32(block.data() + p); p += 4 + vendorLen;
            if (p + 4 > block.size()) return;
            uint32_t count = leU32(block.data() + p); p += 4;
            for (uint32_t i = 0; i < count && p + 4 <= block.size(); ++i) {
                uint32_t len = leU32(block.data() + p); p += 4;
                if (p + len > block.size()) break;
                applyVorbisComment(std::string(reinterpret_cast<const char*>(block.data() + p), len), meta);
                p += len;
            }
            return; // got what we need
        } else {
            f.seekg(blockLen, std::ios::cur);
        }
        if (isLast) break;
    }
}

float extractDuration(const std::string& filePath) {
    ma_decoder decoder;
    if (ma_decoder_init_file(filePath.c_str(), NULL, &decoder) != MA_SUCCESS) return 0.0f;
    float seconds = 0.0f;
    ma_uint64 frames = 0;
    if (ma_decoder_get_length_in_pcm_frames(&decoder, &frames) == MA_SUCCESS && decoder.outputSampleRate > 0) {
        seconds = static_cast<float>(frames) / static_cast<float>(decoder.outputSampleRate);
    }
    ma_decoder_uninit(&decoder);
    return seconds;
}

std::string lowerExt(const std::string& path) {
    auto dot = path.find_last_of('.');
    if (dot == std::string::npos) return "";
    std::string ext = path.substr(dot);
    std::transform(ext.begin(), ext.end(), ext.begin(), [](unsigned char c) { return std::tolower(c); });
    return ext;
}

} // namespace

AudioMetadata MetadataExtractor::extract(const std::string& filePath) {
    AudioMetadata meta;
    std::string ext = lowerExt(filePath);

    std::ifstream f(filePath, std::ios::binary);
    if (f) {
        if (ext == ".mp3") {
            parseId3v2(f, meta);
        } else if (ext == ".flac") {
            parseFlac(f, meta);
        }
        // .ogg/.wav/.ape: tags not parsed here; duration still resolved below.
    }

    meta.durationSeconds = extractDuration(filePath);
    return meta;
}
