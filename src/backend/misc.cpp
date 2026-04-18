#include "misc.h"
#include "types.h"
#include <iostream>

PieceType get_type(Piece piece) {
    return static_cast<PieceType>((piece - 1) % 6 + 1);
}

Color get_color(Piece piece) {
    if (piece >= W_KING && piece <= W_PAWN) {
        return WHITE;
    } else if (piece >= B_KING && piece <= B_PAWN) {
        return BLACK;
    } 
    std::cout << "Error: Invalid piece value, returning default color WHITE" << static_cast<int>(piece) << std::endl;
    return WHITE;
}

// Convert file and rank to a single index (0-63)
int get_index(int file, int rank) {
    return rank * 8 + file;
}

bool is_capture(Move move) {
    return move.piece_captured != NO_PIECE;
}