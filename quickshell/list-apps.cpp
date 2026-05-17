// clist-apps.cpp — high-performance .desktop parser
// Compile: g++ -O3 -flto -march=native -std=c++17 -o list-apps list-apps.cpp
//          strip -s list-apps

#include <algorithm>
#include <cstring>
#include <cctype>
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

struct Entry {
    std::string name, exec, categories, keywords, desktop_id;
    bool no_display = false, hidden = false;
};

static void set_value(Entry& e, const std::string& key, const std::string& val) {
    std::string base = key;
    auto br = key.find('[');
    if (br != std::string::npos) base = key.substr(0, br);

    if (base == "Name" && (e.name.empty() || br == std::string::npos))
        e.name = val;
    else if (base == "Exec" && e.exec.empty())
        e.exec = val;
    else if (base == "Categories" && e.categories.empty())
        e.categories = val;
    else if (base == "Keywords" && e.keywords.empty())
        e.keywords = semicolon_to_space(val);
    else if (base == "NoDisplay")
        e.no_display = (val == "true");
    else if (base == "Hidden")
        e.hidden = (val == "true");
}

static Entry parse(const fs::path& path) {
    Entry e;
    e.desktop_id = path.stem().string();

    std::ifstream f(path);
    std::string line;
    bool in_section = false;
    std::string current_key;
    std::string pending_value;

    while (std::getline(f, line)) {
        line = trim(line);
        if (line.empty() || line[0] == '#') continue;

        if (line[0] == '[') {
            if (!current_key.empty() && !pending_value.empty())
                set_value(e, current_key, pending_value);
            in_section = (line == "[Desktop Entry]");
            current_key.clear();
            pending_value.clear();
            continue;
        }
        if (!in_section) continue;

        auto eq = line.find('=');
        if (eq == std::string::npos && !current_key.empty()) {
            if (!pending_value.empty()) pending_value += ' ';
            pending_value += line;
            continue;
        }

        if (!current_key.empty() && !pending_value.empty())
            set_value(e, current_key, pending_value);

        if (eq == std::string::npos) continue;

        current_key = trim(line.substr(0, eq));
        pending_value = trim(line.substr(eq + 1));
    }
    if (!current_key.empty() && !pending_value.empty())
        set_value(e, current_key, pending_value);

    return e;
}

static std::string strip_pct(const std::string& s) {
    std::string r;
    r.reserve(s.size());
    for (size_t i = 0; i < s.size(); ++i) {
        if (s[i] == '%' && i + 1 < s.size() && std::isalpha(static_cast<unsigned char>(s[i + 1]))) {
            ++i; continue;
        }
        r.push_back(s[i]);
    }
    return r;
}

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
    if (xdg) paths.push_back(fs::path(xdg) / "applications");
    else paths.push_back(fs::path(h) / ".local/share/applications");
    paths.push_back(fs::path(h) / ".local/share/flatpak/exports/share/applications");
    return paths;
}

int main() {
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
            if (entry.no_display || entry.hidden || entry.name.empty()) continue;

            std::string fp = entry.name + "|" + entry.desktop_id + "|"
                           + entry.categories + "|" + entry.exec + "|" + entry.keywords;
            if (seen.count(fp)) continue;
            seen.insert(fp);

            std::cout << escape_delim(entry.name) << "|"
                      << escape_delim(entry.desktop_id) << "|"
                      << escape_delim(entry.categories) << "|"
                      << escape_delim(strip_pct(entry.exec)) << "|"
                      << escape_delim(entry.keywords) << "\n";
        }
    }
    return 0;
}
