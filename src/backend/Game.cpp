#include "Game.h"
#include "notation.h"
#include <climits>

Game::Game() {
    board.setup_pieces();
    position_history.push_back(make_position());
}

Position Game::make_position() const {
    Position key;
    for (int sq = 0; sq < 64; ++sq)
        key.pieces[sq] = board.get_piece(sq);
    key.side_to_move   = turn;
    const StateInfo& si = board.get_state_info();
    key.white_castle_ks = si.white_can_castle_kingside;
    key.white_castle_qs = si.white_can_castle_queenside;
    key.black_castle_ks = si.black_can_castle_kingside;
    key.black_castle_qs = si.black_can_castle_queenside;
    key.ep_file         = si.en_passant_file;
    return key;
}

const Board& Game::get_board() const { return board; }

Color Game::get_turn() const { return turn; }

bool Game::make_move(const Move& move) {
    if (status != ONGOING) {
        return false;
    }

    // If a clock is ticking, deduct elapsed time before validating
    if (clocks_set_ && clock_running_) {
        stop_clock();
        Clock& active = (clock_owner_ == WHITE) ? white_clock_ : black_clock_;
        if (active.is_flagged()) {
            status = TIMEOUT;
            return false;
        }
    }

    std::vector<Move> legal_moves = generate_legal_moves(board, move.square_from);
    for (const Move& legal_move : legal_moves) {
        if (legal_move.square_from == move.square_from && legal_move.square_to == move.square_to) {
            if (move.promotion_piece_type != NO_PIECE_TYPE && legal_move.promotion_piece_type != move.promotion_piece_type) {
                continue;
            }
            move_history_san.push_back(move_to_san(board, legal_move));
            board.make_move(legal_move);
            move_history.push_back(legal_move);
            turn = (turn == WHITE) ? BLACK : WHITE;
            position_history.push_back(make_position());
            check_game_status();

            // Start opponent's clock
            if (clocks_set_ && status == ONGOING) {
                start_clock();
            }
            return true;
        }
    }
    return false;
}

GameStatus Game::get_game_status() const { return status; }

const std::vector<Move>& Game::get_move_history() const { return move_history; }

const std::vector<std::string>& Game::get_move_history_san() const { return move_history_san; }

void Game::check_game_status() {
    // Threefold repetition: current position has appeared 3+ times
    {
        const Position& current = position_history.back();
        int count = 0;
        for (const Position& k : position_history)
            if (k == current) ++count;
        if (count >= 3) {
            status = DRAW_BY_REPETITION;
            return;
        }
    }

    std::vector<Move> legal_moves = generate_legal_moves(board, turn);
    if (is_in_check(board, turn)) {
        if (legal_moves.empty()) {
            status = CHECKMATE;
        }
    } else {
        if (legal_moves.empty()) {
            status = STALEMATE;
            return;
        }
        if (board.get_state_info().halfmove_clock >= 100) {
            status = DRAW_BY_FIFTY_MOVE_RULE;
            return;
        }
    }
}

// ---------------------------------------------------------------------------
// Clock management
// ---------------------------------------------------------------------------

void Game::set_clocks(long long white_ms, long long black_ms,
                      long long white_inc_ms, long long black_inc_ms) {
    white_clock_ = Clock(white_ms, white_inc_ms);
    black_clock_ = Clock(black_ms, black_inc_ms);
    clocks_set_   = true;
    clock_running_ = false;
}

void Game::start_clock() {
    clock_owner_   = turn;
    clock_start_   = std::chrono::steady_clock::now();
    clock_running_ = true;
}

long long Game::stop_clock() {
    if (!clock_running_) return 0;
    clock_running_ = false;

    auto now     = std::chrono::steady_clock::now();
    long long ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                       now - clock_start_).count();

    Clock& c = (clock_owner_ == WHITE) ? white_clock_ : black_clock_;
    c.remaining_ms -= ms;
    c.remaining_ms += c.increment_ms; // add increment after move completes
    return ms;
}

bool Game::clock_running() const { return clock_running_; }

long long Game::remaining_ms(Color color) const {
    if (!clocks_set_) return LLONG_MAX;
    const Clock& c = (color == WHITE) ? white_clock_ : black_clock_;
    // If this side's clock is currently ticking, account for live elapsed time
    if (clock_running_ && clock_owner_ == color) {
        auto now     = std::chrono::steady_clock::now();
        long long ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                           now - clock_start_).count();
        return c.remaining_ms - ms;
    }
    return c.remaining_ms;
}
