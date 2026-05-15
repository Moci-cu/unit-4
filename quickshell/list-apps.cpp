// clist-apps.cpp — high-performance .desktop parser
// Compile: g++ -O3 -flto -march=native -std=c++17 -o list-apps list-apps.cpp
//          strip -s list-apps
//          upx --best list-apps (optional)

#include <algorithm>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <unordered_set>
#include <vector>
#include <unistd.h>

namespace fs = std::filesystem;

static std::string trim(const std::string& s) {
    auto b = s.find_first_not_of(" \t\r\n");
    if (b == std::string::npos) return "";
    auto e = s.find_last_not_of(" \t\r\n");
    return s.substr(b, e - b + 1);
}

static std::string semicolon_to_space(const std::string& s) {
    std::string r;
    r.reserve(s.size());
    for (char c : s) r.push_back(c == ';' ? ' ' : c);
    return r;
}

// Escape pipe and backslash for consumer split("|")/unescape
static std::string escape_delim(const std::string& s) {
    std::string r;
    r.reserve(s.size() + 4);
    for (char c : s) {
        if (c == '\\') r += "\\\\";
        else if (c == '|') r += "\\|";
        else r += c;
    }
    return r;
}

static std::string strip_pct(const std::string& s) {
    std::string r;
    r.reserve(s.size());
    for (size_t i = 0; i < s.size(); ++i) {
        if (s[i] == '%' && i + 1 < s.size() && std::isalpha(static_cast<unsigned char>(s[i + 1]))) {
            ++i;
            continue;
        }
        r.push_back(s[i]);
    }
    return r;
}

static std::string escape_delim(const std::string& s) {
    std::string r;
    r.reserve(s.size() * 2);
    for (char c : s) {
        if (c == '\\') {
            r.push_back('\\');
            r.push_back('\\');
        } else if (c == '|') {
            r.push_back('\\');
            r.push_back('|');
        } else {
            r.push_back(c);
        }
    }
    return r;
}

struct Entry {
    std::string name;
    std::string exec;
    std::string categories;
    std::string keywords;
    std::string desktop_id;
    bool no_display = false;
    bool hidden = false;
};

static Entry parse(const fs::path& path) {
    Entry e;
    e.desktop_id = path.stem().string();

    std::ifstream f(path);
    std::string line;
    bool in_section = false;
    std::string pending_value;

    while (std::getline(f, line)) {
        line = trim(line);
        if (line.empty() || line[0] == '#') continue;

        if (line[0] == '[') {
            in_section = (line == "[Desktop Entry]");
            continue;
        }
        if (!in_section) continue;

        // Continuation: line starts with whitespace or is appended to previous value
        bool is_continuation = !pending_value.empty() && (line[0] == ' ' || line[0] == '\t');
        if (is_continuation) {
            pending_value += line;
            continue;
        }

        auto eq = line.find('=');
        if (eq == std::string::npos) continue;

        std::string key = trim(line.substr(0, eq));
        std::string val = trim(line.substr(eq + 1));

        // Extract base key (strip [lang] suffix)
        std::string base = key;
        auto br = key.find('[');
        if (br != std::string::npos) base = key.substr(0, br);

        // Only set if not already set (prefer bare key, then first locale)
        if (base == "Name" && (e.name.empty() || br == std::string::npos)) {
            e.name = val;
        } else if (base == "Exec" && e.exec.empty()) {
            // Exec values often contain continuation across multiple lines
            // Read rest of multiline value
            std::string full_val = val;
            std::string next;
            auto pos = f.tellg();
            while (std::getline(f, next)) {
                if (next.empty()) break;
                if (next[0] != ' ' && next[0] != '\t') {
                    // Unget - need to reprocess this line
                    // Since we can't unget easily with getline, store position and reset
                    f.clear();
                    f.seekg(pos);
                    break;
                }
                full_val += next;
                pos = f.tellg();
            }
            e.exec = full_val;
        } else if (base == "Categories" && e.categories.empty()) {
            e.categories = val;
        } else if (base == "Keywords" && e.keywords.empty()) {
            e.keywords = semicolon_to_space(val);
        } else if (base == "NoDisplay") {
            e.no_display = (val == "true");
        } else if (base == "Hidden") {
            e.hidden = (val == "true");
        }
    }
    return e;
}

static std::vector<fs::path> discover_paths() {
    std::vector<fs::path> paths = {
        "/usr/share/applications",
        "/var/lib/flatpak/exports/share/applications",
        "/var/lib/snapd/desktop/applications"
    };
    const char* home = getenv("HOME");
    if (!home) return paths;
    std::string h(home);
    const char* xdg = getenv("XDG_DATA_HOME");
    if (xdg) {
        paths.push_back(fs::path(xdg) / "applications");
    } else {
        paths.push_back(fs::path(h) / ".local/share/applications");
    }
    paths.push_back(fs::path(h) / ".local/share/flatpak/exports/share/applications");
    return paths;
}

int main() {
    // Disable C I/O sync for speed
    std::ios::sync_with_stdio(false);
    std::cin.tie(nullptr);

    std::unordered_set<std::string> seen;

    for (const auto& dir : discover_paths()) {
        if (!fs::exists(dir) || !fs::is_directory(dir)) continue;
        std::error_code ec;
        for (const auto& de : fs::directory_iterator(dir, ec)) {
            if (!de.is_regular_file()) continue;
            if (de.path().extension() != ".desktop") continue;

            auto entry = parse(de.path());
            if (entry.no_display || entry.hidden) continue;
            if (entry.name.empty()) continue;

            // Deduplicate by Name|DesktopId|Categories|Exec|Keywords
            std::string fingerprint = entry.name + "|" + entry.desktop_id + "|"
                                     + entry.categories + "|" + entry.exec + "|"
                                     + entry.keywords;
            if (seen.count(fingerprint)) continue;
            seen.insert(fingerprint);

            std::cout << escape_delim(entry.name) << "|"
                      << escape_delim(entry.desktop_id) << "|"
                      << escape_delim(entry.categories) << "|"
                      << escape_delim(strip_pct(entry.exec)) << "|"
                      << escape_delim(entry.keywords) << "\n";
        }
    }
    return 0;
}
