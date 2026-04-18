#ifndef MOVEGEN_H
#define MOVEGEN_H

#include <vector>
#include "Board.h"
#include "types.h"

std::vector<Move> generate_moves(const Board& board, int square);
bool is_in_check(const Board& board, Color color);
std::vector<Move> generate_legal_moves(Board& board, int square);
std::vector<Move> generate_legal_moves(Board& board, Color color);
bool is_legal_move(Board& board, Move move);

#endif
