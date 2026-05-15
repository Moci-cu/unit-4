// gen-lockbg.cpp — Generate NieR-style sepia pixel wave lock screen background
// Compile: g++ -O3 -flto -march=native -std=c++17 -o gen-lockbg gen-lockbg.cpp
//          strip -s gen-lockbg
//
// Replaces: gen-lockbg.py (PIL/Pillow dependency removed)

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <random>
#include <string>
#include <vector>

int main(int argc, char* argv[]) {
    std::string out = (argc > 1) ? argv[1] : "/tmp/lockbg.png";

    // Sanitize output path
    if (out.empty()) {
        std::fprintf(stderr, "Error: output path is empty\n");
        return 1;
    }

    // Reject paths containing ".." to prevent directory traversal
    if (out.find("..") != std::string::npos) {
        std::fprintf(stderr, "Error: output path contains '..'\n");
        return 1;
    }

    // Canonicalize path
    std::error_code ec;
    std::filesystem::path out_path = std::filesystem::weakly_canonical(out, ec);
    if (ec) {
        std::fprintf(stderr, "Error: cannot canonicalize path: %s\n", ec.message().c_str());
        return 1;
    }
    out = out_path.string();

    // Check if parent directory exists and is writable
    std::filesystem::path parent = out_path.parent_path();
    if (!std::filesystem::exists(parent)) {
        std::fprintf(stderr, "Error: parent directory does not exist: %s\n", parent.c_str());
        return 1;
    }
    if (!std::filesystem::is_directory(parent)) {
        std::fprintf(stderr, "Error: parent path is not a directory: %s\n", parent.c_str());
        return 1;
    }

    // Check writability: if file exists, check it's writable; otherwise check parent is writable
    if (std::filesystem::exists(out_path)) {
        auto perms = std::filesystem::status(out_path).permissions();
        if ((perms & std::filesystem::perms::owner_write) == std::filesystem::perms::none) {
            std::fprintf(stderr, "Error: output file is not writable: %s\n", out.c_str());
            return 1;
        }
    } else {
        auto perms = std::filesystem::status(parent).permissions();
        if ((perms & std::filesystem::perms::owner_write) == std::filesystem::perms::none) {
            std::fprintf(stderr, "Error: parent directory is not writable: %s\n", parent.c_str());
            return 1;
        }
    }

    constexpr int W    = 1920;
    constexpr int H    = 1080;
    constexpr int CELL = 7;
    constexpr int GAP  = 1;
    constexpr int STEP = CELL + GAP;
    constexpr int COLS = W / STEP;
    constexpr int ROWS = H / STEP;

    // Background: (11, 9, 6)
    std::vector<unsigned char> pixels(static_cast<size_t>(W) * H * 3);
    for (size_t i = 0; i < pixels.size(); i += 3) {
        pixels[i]     = 11;
        pixels[i + 1] = 9;
        pixels[i + 2] = 6;
    }

    std::mt19937 rng(42);  // fixed seed, same as Python
    std::uniform_real_distribution<double> dist(0.0, 1.0);

    const double cx = COLS / 2.0;
    const double cy = ROWS / 2.0;
    const double max_dist = std::sqrt(cx * cx + cy * cy);

    for (int r = 0; r < ROWS; ++r) {
        for (int c = 0; c < COLS; ++c) {
            double lum = 0.78 + dist(rng) * 0.14;
            double d   = std::sqrt((c - cx) * (c - cx) + (r - cy) * (r - cy)) / max_dist;
            lum = lum * (1.0 - d * 0.08);

            unsigned char rr = std::min(255, static_cast<int>(lum * 230));
            unsigned char gg = std::min(255, static_cast<int>(lum * 215));
            unsigned char bb = std::min(255, static_cast<int>(lum * 180));

            int px = c * STEP;
            int py = r * STEP;

            // Fill CELL×CELL rectangle
            for (int dy = 0; dy < CELL; ++dy) {
                for (int dx = 0; dx < CELL; ++dx) {
                    int x = px + dx;
                    int y = py + dy;
                    if (x >= W || y >= H) continue;
                    int idx = (y * W + x) * 3;
                    pixels[idx]     = rr;
                    pixels[idx + 1] = gg;
                    pixels[idx + 2] = bb;
                }
            }
        }
    }

    if (!stbi_write_png(out.c_str(), W, H, 3, pixels.data(), W * 3)) {
        std::fprintf(stderr, "Failed to write %s\n", out.c_str());
        return 1;
    }

    std::printf("Generated %s\n", out.c_str());
    return 0;
}
