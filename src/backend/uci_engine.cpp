#include "uci_engine.h"
#include "notation.h"

#include <algorithm>

#include <chrono>
#include <cstring>
#include <sstream>

// POSIX
#include <fcntl.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------
namespace {

// Split a string on whitespace into tokens.
std::vector<std::string> tokenize(const std::string& s) {
    std::vector<std::string> tokens;
    std::istringstream ss(s);
    std::string tok;
    while (ss >> tok) tokens.push_back(tok);
    return tokens;
}

// Return the value that follows a named token in a token list, or "".
std::string token_after(const std::vector<std::string>& toks,
                        const std::string& key) {
    for (size_t i = 0; i + 1 < toks.size(); ++i)
        if (toks[i] == key) return toks[i + 1];
    return {};
}

// Collect all tokens that follow a named token until the next known keyword.
std::string tokens_after(const std::vector<std::string>& toks,
                         const std::string& key,
                         const std::vector<std::string>& stop_keys) {
    size_t start = toks.size();
    for (size_t i = 0; i < toks.size(); ++i)
        if (toks[i] == key) { start = i + 1; break; }
    if (start >= toks.size()) return {};
    std::string result;
    for (size_t i = start; i < toks.size(); ++i) {
        if (std::find(stop_keys.begin(), stop_keys.end(), toks[i]) !=
            stop_keys.end()) break;
        if (!result.empty()) result += ' ';
        result += toks[i];
    }
    return result;
}

} // anonymous namespace

// ---------------------------------------------------------------------------
// Ctor / Dtor
// ---------------------------------------------------------------------------
UCIEngine::UCIEngine() = default;

UCIEngine::~UCIEngine() {
    if (is_running()) quit();
}

// ---------------------------------------------------------------------------
// Process management
// ---------------------------------------------------------------------------
bool UCIEngine::start(const std::string& path,
                      const std::vector<std::string>& args) {
    if (is_running()) return false;

    // pipe[0] = read end, pipe[1] = write end
    int to_engine[2];   // parent writes → engine reads
    int from_engine[2]; // engine writes → parent reads

    if (pipe(to_engine) != 0 || pipe(from_engine) != 0) return false;

    pid_t child = fork();
    if (child < 0) return false;

    if (child == 0) {
        // ---------- child ----------
        dup2(to_engine[0],   STDIN_FILENO);
        dup2(from_engine[1], STDOUT_FILENO);
        // Close all pipe ends in child
        close(to_engine[0]);  close(to_engine[1]);
        close(from_engine[0]); close(from_engine[1]);

        // Build argv
        std::vector<const char*> argv;
        argv.push_back(path.c_str());
        for (const auto& a : args) argv.push_back(a.c_str());
        argv.push_back(nullptr);

        execvp(path.c_str(), const_cast<char* const*>(argv.data()));
        _exit(1); // exec failed
    }

    // ---------- parent ----------
    close(to_engine[0]);
    close(from_engine[1]);

    stdin_fd_  = to_engine[1];
    stdout_fd_ = from_engine[0];
    pid_       = child;
    running_   = true;

    // Start background reader thread
    reader_thread_ = std::thread(&UCIEngine::reader_loop, this);
    return true;
}

void UCIEngine::quit() {
    if (!is_running()) return;

    send("quit");
    running_ = false;

    // Give the engine up to 2 s to exit cleanly
    auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    int status = 0;
    while (std::chrono::steady_clock::now() < deadline) {
        pid_t r = waitpid(pid_, &status, WNOHANG);
        if (r != 0) break;
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
    // Force kill if still alive
    if (waitpid(pid_, &status, WNOHANG) == 0) {
        kill(pid_, SIGKILL);
        waitpid(pid_, &status, 0);
    }

    if (stdin_fd_  != -1) { close(stdin_fd_);  stdin_fd_  = -1; }
    if (stdout_fd_ != -1) { close(stdout_fd_); stdout_fd_ = -1; }
    pid_ = -1;

    lines_cv_.notify_all();
    if (reader_thread_.joinable()) reader_thread_.join();
}

bool UCIEngine::is_running() const {
    return running_.load();
}

// ---------------------------------------------------------------------------
// Background reader thread
// ---------------------------------------------------------------------------
void UCIEngine::reader_loop() {
    char buf[4096];
    std::string partial;

    while (running_) {
        ssize_t n = read(stdout_fd_, buf, sizeof(buf) - 1);
        if (n <= 0) break; // EOF or error → engine exited

        buf[n] = '\0';
        partial += buf;

        // Split on newlines and enqueue complete lines
        size_t pos;
        while ((pos = partial.find('\n')) != std::string::npos) {
            std::string line = partial.substr(0, pos);
            // Strip CR
            if (!line.empty() && line.back() == '\r') line.pop_back();
            partial.erase(0, pos + 1);

            {
                std::lock_guard<std::mutex> lk(lines_mutex_);
                lines_.push_back(std::move(line));
            }
            lines_cv_.notify_one();
        }
    }
    running_ = false;
    lines_cv_.notify_all();
}

// ---------------------------------------------------------------------------
// Raw I/O
// ---------------------------------------------------------------------------
void UCIEngine::send(const std::string& cmd) {
    if (stdin_fd_ == -1) return;
    std::string msg = cmd + '\n';
    const char* ptr = msg.c_str();
    size_t left = msg.size();
    while (left > 0) {
        ssize_t n = write(stdin_fd_, ptr, left);
        if (n <= 0) break;
        ptr  += n;
        left -= static_cast<size_t>(n);
    }
}

std::string UCIEngine::read_line(int timeout_ms) {
    std::unique_lock<std::mutex> lk(lines_mutex_);
    auto has_data = [this] { return !lines_.empty() || !running_; };

    if (timeout_ms < 0) {
        lines_cv_.wait(lk, has_data);
    } else {
        if (!lines_cv_.wait_for(lk,
                                std::chrono::milliseconds(timeout_ms),
                                has_data))
            return {}; // timeout
    }
    if (lines_.empty()) return {};
    std::string line = lines_.front();
    lines_.pop_front();
    return line;
}

// ---------------------------------------------------------------------------
// UCI protocol
// ---------------------------------------------------------------------------
bool UCIEngine::init(int timeout_ms) {
    send("uci");

    auto deadline = std::chrono::steady_clock::now() +
                    std::chrono::milliseconds(timeout_ms);

    while (std::chrono::steady_clock::now() < deadline) {
        int remaining = static_cast<int>(
            std::chrono::duration_cast<std::chrono::milliseconds>(
                deadline - std::chrono::steady_clock::now()).count());
        std::string line = read_line(remaining);
        if (line.empty()) {
            if (!running_) break;  // engine exited
            continue;              // skip blank lines
        }

        if (line.rfind("id name ", 0) == 0)
            engine_name_ = line.substr(8);
        else if (line.rfind("id author ", 0) == 0)
            engine_author_ = line.substr(10);
        else if (line.rfind("option ", 0) == 0)
            parse_option_line(line);
        else if (line == "uciok")
            return true;
    }
    return false;
}

bool UCIEngine::wait_ready(int timeout_ms) {
    send("isready");

    auto deadline = std::chrono::steady_clock::now() +
                    std::chrono::milliseconds(timeout_ms);

    while (std::chrono::steady_clock::now() < deadline) {
        int remaining = static_cast<int>(
            std::chrono::duration_cast<std::chrono::milliseconds>(
                deadline - std::chrono::steady_clock::now()).count());
        std::string line = read_line(remaining);
        if (line.empty()) {
            if (!running_) break;
            continue;
        }
        if (line == "readyok") return true;
    }
    return false;
}

void UCIEngine::new_game() {
    send("ucinewgame");
}

void UCIEngine::set_option(const std::string& name, const std::string& value) {
    send("setoption name " + name + " value " + value);
}

// ---------------------------------------------------------------------------
// Position
// ---------------------------------------------------------------------------
void UCIEngine::set_position_startpos(const std::vector<std::string>& moves) {
    std::string cmd = "position startpos";
    if (!moves.empty()) {
        cmd += " moves";
        for (const auto& m : moves) { cmd += ' '; cmd += m; }
    }
    send(cmd);
}

void UCIEngine::set_position_fen(const std::string& fen,
                                  const std::vector<std::string>& moves) {
    std::string cmd = "position fen " + fen;
    if (!moves.empty()) {
        cmd += " moves";
        for (const auto& m : moves) { cmd += ' '; cmd += m; }
    }
    send(cmd);
}

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------
void UCIEngine::go(const UCIGoOptions& opts) {
    std::string cmd = "go";

    if (opts.infinite) {
        cmd += " infinite";
    } else {
        if (opts.movetime  >= 0) cmd += " movetime "  + std::to_string(opts.movetime);
        if (opts.depth     >= 0) cmd += " depth "     + std::to_string(opts.depth);
        if (opts.wtime     >= 0) cmd += " wtime "     + std::to_string(opts.wtime);
        if (opts.btime     >= 0) cmd += " btime "     + std::to_string(opts.btime);
        if (opts.winc      >  0) cmd += " winc "      + std::to_string(opts.winc);
        if (opts.binc      >  0) cmd += " binc "      + std::to_string(opts.binc);
        if (opts.movestogo >= 0) cmd += " movestogo " + std::to_string(opts.movestogo);
    }
    send(cmd);
}

void UCIEngine::stop() {
    send("stop");
}

// ---------------------------------------------------------------------------
// Wait for bestmove
// ---------------------------------------------------------------------------
UCISearchResult UCIEngine::wait_for_bestmove(int timeout_ms) {
    UCISearchResult result;

    auto deadline = std::chrono::steady_clock::now() +
                    std::chrono::milliseconds(timeout_ms);

    while (std::chrono::steady_clock::now() < deadline) {
        int remaining = static_cast<int>(
            std::chrono::duration_cast<std::chrono::milliseconds>(
                deadline - std::chrono::steady_clock::now()).count());
        std::string line = read_line(remaining);
        if (line.empty()) break;

        auto toks = tokenize(line);
        if (toks.empty()) continue;

        if (toks[0] == "info") {
            result = parse_info_line(line, result);
        } else if (toks[0] == "bestmove") {
            if (toks.size() >= 2) result.bestmove = toks[1];
            if (toks.size() >= 4 && toks[2] == "ponder") result.ponder = toks[3];
            return result;
        }
    }
    return result; // timeout — bestmove is empty
}

// ---------------------------------------------------------------------------
// High-level helper
// ---------------------------------------------------------------------------
UCISearchResult UCIEngine::think(const Game& game, const UCIGoOptions& opts) {
    // Build moves list from game history
    std::vector<std::string> moves;
    for (const Move& m : game.get_move_history())
        moves.push_back(move_to_uci(m));

    set_position_startpos(moves);
    go(opts);

    int timeout = (opts.movetime > 0) ? opts.movetime * 3 : 30000;
    return wait_for_bestmove(timeout);
}

// ---------------------------------------------------------------------------
// Parsing helpers
// ---------------------------------------------------------------------------
void UCIEngine::parse_option_line(const std::string& line) {
    // option name <id> type <t> [default <x>] [min <x>] [max <x>] [var <x>]*
    auto toks = tokenize(line);
    if (toks.size() < 5) return;

    static const std::vector<std::string> kw =
        {"name","type","default","min","max","var"};

    UCIEngineOption opt;
    opt.name        = tokens_after(toks, "name",    kw);
    opt.type        = token_after (toks, "type");
    opt.default_val = token_after (toks, "default");
    opt.min_val     = token_after (toks, "min");
    opt.max_val     = token_after (toks, "max");

    // Collect all "var" values
    for (size_t i = 0; i + 1 < toks.size(); ++i)
        if (toks[i] == "var") opt.vars.push_back(toks[i + 1]);

    options_.push_back(std::move(opt));
}

UCISearchResult UCIEngine::parse_info_line(const std::string& line,
                                         const UCISearchResult& prev) const {
    UCISearchResult r = prev; // carry forward previous info
    auto toks = tokenize(line);
    if (toks.empty() || toks[0] != "info") return r;

    for (size_t i = 1; i < toks.size(); ++i) {
        if (toks[i] == "depth" && i + 1 < toks.size()) {
            r.depth = std::stoi(toks[++i]);
        } else if (toks[i] == "seldepth" && i + 1 < toks.size()) {
            r.seldepth = std::stoi(toks[++i]);
        } else if (toks[i] == "nodes" && i + 1 < toks.size()) {
            r.nodes = std::stol(toks[++i]);
        } else if (toks[i] == "score") {
            ++i;
            if (i < toks.size() && toks[i] == "cp" && i + 1 < toks.size()) {
                r.score_mate = false;
                r.score_cp   = std::stoi(toks[++i]);
            } else if (i < toks.size() && toks[i] == "mate" && i + 1 < toks.size()) {
                r.score_mate = true;
                r.mate_in    = std::stoi(toks[++i]);
            }
        } else if (toks[i] == "pv") {
            // Everything from "pv" to end of line is the PV
            std::string pv;
            for (size_t j = i + 1; j < toks.size(); ++j) {
                if (!pv.empty()) pv += ' ';
                pv += toks[j];
            }
            r.pv = std::move(pv);
            break; // pv is always last
        }
    }
    return r;
}
