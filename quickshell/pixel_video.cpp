// pixel_video.cpp — Generate NieR pixel wave reveal/hide MP4 videos
// Compile: g++ -O3 -flto -march=native -std=c++17 -Wall -Wextra -o pixel_video pixel_video.cpp
//          strip -s pixel_video
//
// Replaces: pixel_wave.py + pixel-wave-close-video.py (Pillow/NumPy deps removed)
//
// Safety: RAII throughout, no malloc/free, no shell/exec, no network, no user-controlled format strings.
// Footprint: ~50KB binary, ~6MB RAM during render (1920×1080), no external libs beyond std C++.

#include <algorithm>
#include <cerrno>
#include <climits>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <random>
#include <string>
#include <vector>
#include <unistd.h>
#include <sys/wait.h>
#include <fcntl.h>

// ── Constants (matching Python) ──
constexpr int    CELL       = 7;
constexpr int    STEP       = 8;
constexpr float  FRONT_W    = 1.2f;
constexpr float  LIFT_MAX   = 7.0f;
constexpr float  SPRING_K   = 0.28f;
constexpr float  SPRING_D   = 0.62f;
constexpr float  WAVE_SPEED = 7.2f;

constexpr unsigned char BG_R = 11, BG_G = 9, BG_B = 6;
constexpr unsigned char SEPIA_R = 230, SEPIA_G = 215, SEPIA_B = 180;

// ── Grid state (RAII — no manual allocations) ──
struct Grid {
    int cols, rows, off_x, off_y, total;
    std::vector<float> target_color;
    std::vector<float> jitter;
    std::vector<float> progress;
    std::vector<float> lift;
    std::vector<float> lift_vel;

    Grid(int w, int h) {
        cols  = w / STEP;
        rows  = h / STEP;
        off_x = (w - cols * STEP) / 2;
        off_y = (h - rows * STEP) / 2;
        total = cols * rows;

        target_color.resize(total);
        jitter.resize(total);
        progress.resize(total, 0.0f);
        lift.resize(total, 0.0f);
        lift_vel.resize(total, 0.0f);

        std::mt19937 rng(42);
        std::uniform_real_distribution<float> lum_dist(0.78f, 0.92f);
        std::uniform_real_distribution<float> jit_dist(-2.0f, 2.0f);

        for (int i = 0; i < total; ++i) {
            target_color[i] = lum_dist(rng);
            jitter[i]       = jit_dist(rng);
        }
    }
};

struct Wave {
    float cx, cy, r, max_r;
    int   dir;  // +1 = reveal, -1 = hide
    bool  done = false;
};

// ── Simulation ──
static float max_dist(float cx, float cy, int cols, int rows) {
    if (rows <= 1 || cols <= 1) return 1.0f;
    float m = 0.0f;
    for (int ri = 0; ri < 2; ++ri) {
        for (int ci = 0; ci < 2; ++ci) {
            int r = ri ? rows - 1 : 0;
            int c = ci ? cols - 1 : 0;
            float dx = cx - c, dy = cy - r;
            float d  = std::sqrt(dx * dx + dy * dy);
            if (d > m) m = d;
        }
    }
    return m;
}

inline float smoothstep(float t) {
    return t * t * (3.0f - 2.0f * t);
}

static void step_simulation(Grid& g, std::vector<Wave>& waves, float speed_scale) {
    const int n = g.total;

    // Spring lift damping
    for (int i = 0; i < n; ++i) {
        g.lift_vel[i] *= SPRING_D;
        g.lift_vel[i] -= SPRING_K * g.lift[i] * SPRING_D;
        g.lift[i]     += g.lift_vel[i];
        if (std::abs(g.lift[i]) < 0.001f && std::abs(g.lift_vel[i]) < 0.001f) {
            g.lift[i]     = 0.0f;
            g.lift_vel[i] = 0.0f;
        }
    }

    // Wave propagation
    for (auto& w : waves) {
        if (w.done) continue;
        w.r += WAVE_SPEED * speed_scale;
        if (w.r >= w.max_r + FRONT_W * 4.0f) { w.done = true; continue; }

        for (int i = 0; i < n; ++i) {
            int c = i % g.cols;
            int r = i / g.cols;
            float dx = static_cast<float>(c) - w.cx;
            float dy = static_cast<float>(r) - w.cy;
            float d  = std::sqrt(dx * dx + dy * dy);
            float df = w.r - (d + g.jitter[i]);

            if (df < -FRONT_W) continue;

            float t = std::clamp((df + FRONT_W) / (FRONT_W * 2.0f), 0.0f, 1.0f);
            float ease = smoothstep(t);

            if (w.dir == 1) {
                if (ease > g.progress[i]) g.progress[i] = ease;
            } else {
                float inv = 1.0f - ease;
                if (inv < g.progress[i]) g.progress[i] = inv;
            }

            // Lift at wave front
            bool in_front = (df >= -FRONT_W && df < FRONT_W);
            bool can_lift = g.lift[i] < 0.1f;
            bool range_ok = (w.dir == 1) ? (g.progress[i] < 0.6f) : (g.progress[i] > 0.35f);
            if (in_front && can_lift && range_ok) {
                g.lift_vel[i] = LIFT_MAX * 0.55f;
            }
        }
    }

    // Remove done waves
    waves.erase(std::remove_if(waves.begin(), waves.end(),
        [](const Wave& w) { return w.done; }), waves.end());
}

// ── Render ──
static void render_frame(Grid& g, int w, int h, std::vector<unsigned char>& pixels) {
    // Fill background
    for (size_t i = 0; i < pixels.size(); i += 3) {
        pixels[i]     = BG_R;
        pixels[i + 1] = BG_G;
        pixels[i + 2] = BG_B;
    }

    // Two passes: pass 0 = base, pass 1 = lifted (on top)
    for (int pass = 0; pass < 2; ++pass) {
        for (int r = 0; r < g.rows; ++r) {
            for (int c = 0; c < g.cols; ++c) {
                int i = r * g.cols + c;
                float p  = g.progress[i];
                float lv = g.lift[i];
                if (lv < 0.0f) lv = 0.0f;

                if (pass == 0 && lv > 0.3f)  continue;
                if (pass == 1 && lv <= 0.3f) continue;
                if (p < 0.004f && lv < 0.01f) continue;

                float vi = std::min(1.0f, p * g.target_color[i]);
                auto rr = static_cast<unsigned char>(std::min(255.0f, vi * SEPIA_R));
                auto gg = static_cast<unsigned char>(std::min(255.0f, vi * SEPIA_G));
                auto bb = static_cast<unsigned char>(std::min(255.0f, vi * SEPIA_B));

                int size = static_cast<int>(CELL + lv + 0.5f);
                int half = static_cast<int>(lv / 2.0f);
                int px   = g.off_x + c * STEP - half;
                int py   = g.off_y + r * STEP - half;

                int x1 = std::max(0, px);
                int y1 = std::max(0, py);
                int x2 = std::min(w, px + size);
                int y2 = std::min(h, py + size);

                for (int yy = y1; yy < y2; ++yy) {
                    for (int xx = x1; xx < x2; ++xx) {
                        int idx = (yy * w + xx) * 3;
                        pixels[idx]     = rr;
                        pixels[idx + 1] = gg;
                        pixels[idx + 2] = bb;
                    }
                }
            }
        }
    }
}

// ── Video pipeline ──
static int generate_video(int w, int h, int fps, float duration,
                          const char* output, const char* quality,
                          bool hide_mode) {
    // Guard: prevent tainted allocation size
    if (w < 1 || w > 7680 || h < 1 || h > 4320) {
        std::fprintf(stderr, "Invalid dimensions: %dx%d\n", w, h);
        return 1;
    }

    // Ensure output dir exists
    std::filesystem::path out_path(output);
    auto parent = out_path.parent_path();
    if (!parent.empty()) {
        std::error_code ec;
        std::filesystem::create_directories(parent, ec);
    }

    float speed_scale = 60.0f / fps;
    Grid g(w, h);
    std::vector<Wave> waves;

    Wave wv;
    wv.cx    = g.cols * 0.5f;
    wv.cy    = g.rows * 0.5f;
    wv.r     = 0.0f;
    wv.max_r = max_dist(wv.cx, wv.cy, g.cols, g.rows);
    wv.dir   = hide_mode ? -1 : 1;

    // For hide mode: start with all pixels visible
    if (hide_mode) {
        for (int i = 0; i < g.total; ++i) g.progress[i] = 1.0f;
    }

    waves.push_back(wv);
    int total_frames = static_cast<int>(duration * fps);

    // Build ffmpeg command
    std::string crf, preset;
    if (std::strcmp(quality, "high") == 0)   { crf = "18"; preset = "medium"; }
    else if (std::strcmp(quality, "low") == 0) { crf = "28"; preset = "fast"; }
    else                                       { crf = "23"; preset = "fast"; }

    char size_str[32];
    std::snprintf(size_str, sizeof(size_str), "%dx%d", w, h);

    char fps_str[16];
    std::snprintf(fps_str, sizeof(fps_str), "%d", fps);

    // Build ffmpeg arguments (no shell interpolation)
    std::vector<const char*> ffmpeg_args = {
        "ffmpeg", "-y", "-f", "rawvideo", "-vcodec", "rawvideo",
        "-s", size_str, "-pix_fmt", "rgb24", "-r", fps_str,
        "-i", "-", "-an", "-vcodec", "libx264", "-pix_fmt", "yuv420p",
        "-crf", crf.c_str(), "-preset", preset.c_str(),
        "-tune", "fastdecode", "-movflags", "+faststart",
        output,  // output path passed as separate argument, not shell-interpolated
        nullptr
    };

    // Create pipe for stdin
    int pipefd[2];
    if (pipe(pipefd) == -1) {
        std::fprintf(stderr, "Failed to create pipe\n");
        return 1;
    }

    pid_t pid = fork();
    if (pid == -1) {
        std::fprintf(stderr, "Failed to fork\n");
        close(pipefd[0]);
        close(pipefd[1]);
        return 1;
    }

    if (pid == 0) {
        // Child process
        close(pipefd[1]); // Close write end
        dup2(pipefd[0], STDIN_FILENO);
        close(pipefd[0]);

        // Redirect stderr to /dev/null
        int devnull = open("/dev/null", O_WRONLY);
        if (devnull != -1) {
            dup2(devnull, STDERR_FILENO);
            close(devnull);
        }

        execvp("ffmpeg", const_cast<char* const*>(ffmpeg_args.data()));
        std::fprintf(stderr, "Failed to exec ffmpeg\n");
        _exit(1);
    }

    // Parent process
    close(pipefd[0]); // Close read end
    FILE* ffmpeg = fdopen(pipefd[1], "w");
    if (!ffmpeg) {
        std::fprintf(stderr, "Failed to fdopen pipe\n");
        close(pipefd[1]);
        return 1;
    }

    // Render + pipe frames
    std::vector<unsigned char> pixels(static_cast<size_t>(w) * h * 3);
    int last_pct = -1;

    for (int frame = 0; frame < total_frames; ++frame) {
        step_simulation(g, waves, speed_scale);
        render_frame(g, w, h, pixels);
        std::fwrite(pixels.data(), 1, pixels.size(), ffmpeg);
        if (std::ferror(ffmpeg)) {
            std::fprintf(stderr, "Write error piping to ffmpeg\n");
            break;
        }

        int pct = 100 * (frame + 1) / total_frames;
        if (pct != last_pct) {
            std::printf("\r  [");
            for (int i = 0; i < 50; ++i) std::putchar(i < pct / 2 ? '#' : ' ');
            std::printf("] %3d%%  (%d/%d)", pct, frame + 1, total_frames);
            std::fflush(stdout);
            last_pct = pct;
        }
    }
    std::putchar('\n');

    fclose(ffmpeg);

    // Wait for child process (EINTR-safe)
    int status;
    int r;
    while ((r = waitpid(pid, &status, 0)) < 0 && errno == EINTR) {}
    if (r < 0) {
        std::fprintf(stderr, "waitpid failed\n");
        return 1;
    }
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
        std::fprintf(stderr, "ffmpeg failed (status %d)\n", status);
        return 1;
    }

    std::printf("Generated %s\n", output);
    return 0;
}

// ── CLI ──
static void usage(const char* prog) {
    std::printf(
        "Usage: %s <reveal|hide> <width> <height> <fps> <duration> <output.mp4> [quality]\n"
        "  quality: low | medium | high (default: medium)\n"
        "Example: %s reveal 1920 1080 60 1.0 wave_reveal.mp4 medium\n",
        prog, prog);
}

int main(int argc, char* argv[]) {
    if (argc < 7) { usage(argv[0]); return 1; }

    const char* mode = argv[1];
    char* end = nullptr;

    errno = 0;
    long lw = std::strtol(argv[2], &end, 10);
    if (end == argv[2] || *end || errno == ERANGE || lw <= 0 || lw > INT_MAX) {
        std::fprintf(stderr, "invalid width\n"); return 1;
    }

    errno = 0;
    long lh = std::strtol(argv[3], &end, 10);
    if (end == argv[3] || *end || errno == ERANGE || lh <= 0 || lh > INT_MAX) {
        std::fprintf(stderr, "invalid height\n"); return 1;
    }

    errno = 0;
    long lf = std::strtol(argv[4], &end, 10);
    if (end == argv[4] || *end || errno == ERANGE || lf <= 0 || lf > INT_MAX) {
        std::fprintf(stderr, "invalid fps\n"); return 1;
    }

    errno = 0;
    float duration = std::strtof(argv[5], &end);
    if (end == argv[5] || *end || errno == ERANGE || duration <= 0.0f) {
        std::fprintf(stderr, "invalid duration\n"); return 1;
    }

    int w   = static_cast<int>(lw);
    int h   = static_cast<int>(lh);
    int fps = static_cast<int>(lf);
    const char* output   = argv[6];
    const char* quality  = (argc > 7) ? argv[7] : "medium";

    // Sanitize output path (prevent command injection via shell metacharacters)
    for (const char* p = output; *p; ++p) {
        if (*p == ';' || *p == '|' || *p == '&' || *p == '$' ||
            *p == '`' || *p == '(' || *p == ')') {
            std::fprintf(stderr, "Invalid char in output path: '%c'\n", *p);
            return 1;
        }
    }

    bool hide = false;
    if (std::strcmp(mode, "hide") == 0) hide = true;
    else if (std::strcmp(mode, "reveal") != 0) { usage(argv[0]); return 1; }

    return generate_video(w, h, fps, duration, output, quality, hide);
}
