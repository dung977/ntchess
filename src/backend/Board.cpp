#include "Board.h"
#include "misc.h"
#include "types.h"
#include <cstdlib>

Board::Board() {
    for (int i = 0; i < 64; i++) {
        board[i] = NO_PIECE;
    }
    state_history.push_back(StateInfo());
}

void Board::setup_pieces() {
    board[0] = W_ROOK;
    board[1] = W_KNIGHT;
    board[2] = W_BISHOP;
    board[3] = W_QUEEN;
    board[4] = W_KING;
    board[5] = W_BISHOP;
    board[6] = W_KNIGHT;
    board[7] = W_ROOK;
    for (int i = 8; i < 16; i++) {
        board[i] = W_PAWN;
    }
    board[56] = B_ROOK;
    board[57] = B_KNIGHT;
    board[58] = B_BISHOP;
    board[59] = B_QUEEN;
    board[60] = B_KING;
    board[61] = B_BISHOP;
    board[62] = B_KNIGHT;
    board[63] = B_ROOK;
    for (int i = 48; i < 56; i++) {
        board[i] = B_PAWN;
    }
}

Piece Board::get_piece(int file, int rank) const {
    return board[get_index(file, rank)];
}

Piece Board::get_piece(int square) const {
    return board[square];
}

void Board::set_piece(int file, int rank, Piece piece) {
    board[get_index(file, rank)] = piece;
}

void Board::update_state_info(const Move& move) {
    int from_file = move.square_from % 8;
    int from_rank = move.square_from / 8;
    int to_file = move.square_to % 8;
    int to_rank = move.square_to / 8;
    Piece piece = move.piece_moved;
    Piece captured_piece = move.piece_captured;
    StateInfo& si = state_history.back();
    // Update castling rights when king or rook moves or is captured
    if (get_type(piece) == KING) {
        if (get_color(piece) == WHITE) {
            si.white_can_castle_kingside = false;
            si.white_can_castle_queenside = false;
        } else {
            si.black_can_castle_kingside = false;
            si.black_can_castle_queenside = false;
        }
    } else if (get_type(piece) == ROOK) {
        if (get_color(piece) == WHITE) {
            if (from_file == 0 && from_rank == 0) {
                si.white_can_castle_queenside = false;
            } else if (from_file == 7 && from_rank == 0) {
                si.white_can_castle_kingside = false;
            }
        } else {
            if (from_file == 0 && from_rank == 7) {
                si.black_can_castle_queenside = false;
            } else if (from_file == 7 && from_rank == 7) {
                si.black_can_castle_kingside = false;
            }
        }
    }
    if (captured_piece != NO_PIECE && get_type(captured_piece) == ROOK) {
        if (get_color(captured_piece) == WHITE) {
            if (to_file == 0 && to_rank == 0) {
                si.white_can_castle_queenside = false;
            } else if (to_file == 7 && to_rank == 0) {
                si.white_can_castle_kingside = false;
            }
        } else {
            if (to_file == 0 && to_rank == 7) {
                si.black_can_castle_queenside = false;
            } else if (to_file == 7 && to_rank == 7) {
                si.black_can_castle_kingside = false;
            }
        }
    }
    // Update en passant target square
    if (get_type(piece) == PAWN && abs(to_rank - from_rank) == 2) {
        si.en_passant_file = from_file;
    } else {
        si.en_passant_file = -1;
    }

    // Update halfmove clock
    if (get_type(piece) == PAWN || captured_piece != NO_PIECE) {
        si.halfmove_clock = 0;
    } else {
        si.halfmove_clock++;
    }
}

void Board::make_move(const Move& move) {
    int from_rank = move.square_from / 8;
    int to_file = move.square_to % 8;
    int to_rank = move.square_to / 8;
    Piece piece = board[move.square_from];

    if (move.move_type == CASTLING) {
        // Handle castling
        if (to_file == 6) { // Kingside
            board[get_index(5, from_rank)] = board[get_index(7, from_rank)];
            board[get_index(7, from_rank)] = NO_PIECE;
        } else if (to_file == 2) { // Queenside
            board[get_index(3, from_rank)] = board[get_index(0, from_rank)];
            board[get_index(0, from_rank)] = NO_PIECE;
        }
    }

    if (move.move_type == EN_PASSANT) {
        // Handle en passant capture
        int ep_rank = (get_color(piece) == WHITE) ? to_rank - 1 : to_rank + 1;
        board[get_index(to_file, ep_rank)] = NO_PIECE; // Remove the captured pawn
    }

    if (move.move_type == PROMOTION) {
        // Handle promotion
        switch (move.promotion_piece_type) {
            case QUEEN:
                piece = (get_color(piece) == WHITE) ? W_QUEEN : B_QUEEN;
                break;
            case ROOK:
                piece = (get_color(piece) == WHITE) ? W_ROOK : B_ROOK;
                break;
            case BISHOP:
                piece = (get_color(piece) == WHITE) ? W_BISHOP : B_BISHOP;
                break;
            case KNIGHT:
                piece = (get_color(piece) == WHITE) ? W_KNIGHT : B_KNIGHT;
                break;
            default:
                break;
        }
    }
    
    board[move.square_to] = piece;
    board[move.square_from] = NO_PIECE;

    state_history.push_back(state_history.back()); // snapshot current state
    update_state_info(move);
}

void Board::unmake_move(const Move& move) {
    // Restore StateInfo from history
    state_history.pop_back();

    int to_file = move.square_to % 8;
    int to_rank = move.square_to / 8;
    int from_rank = move.square_from / 8;

    if (move.move_type == CASTLING) {
        if (to_file == 6) { // Kingside
            board[get_index(7, from_rank)] = board[get_index(5, from_rank)];
            board[get_index(5, from_rank)] = NO_PIECE;
            board[move.square_from] = move.piece_moved;
            board[move.square_to] = NO_PIECE;
        } else if (to_file == 2) { // Queenside
            board[get_index(0, from_rank)] = board[get_index(3, from_rank)];
            board[get_index(3, from_rank)] = NO_PIECE;
            board[move.square_from] = move.piece_moved;
            board[move.square_to] = NO_PIECE;
        }
    } else if (move.move_type == EN_PASSANT) {
        // Restore the captured pawn next to the destination square
        Piece captured_pawn = (get_color(move.piece_moved) == WHITE) ? B_PAWN : W_PAWN;
        int ep_rank = (get_color(move.piece_moved) == WHITE) ? to_rank - 1 : to_rank + 1;
        board[move.square_from] = move.piece_moved;
        board[move.square_to] = NO_PIECE; // landing square had no piece before the move
        board[get_index(to_file, ep_rank)] = captured_pawn;
    } else if (move.move_type == PROMOTION) {
        // Restore the pawn that was promoted
        Piece pawn = (get_color(move.piece_moved) == WHITE) ? W_PAWN : B_PAWN;
        board[move.square_from] = pawn;
        board[move.square_to] = move.piece_captured;
    } else {
        board[move.square_from] = move.piece_moved;
        board[move.square_to] = move.piece_captured;
    }
}

void Board::clear_board() {
    for (int i = 0; i < 64; i++) {
        board[i] = NO_PIECE;
    }
    state_history.clear();
    state_history.push_back(StateInfo()); // Reset state info
}
