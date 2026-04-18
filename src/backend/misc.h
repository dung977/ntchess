#ifndef MISC_H
#define MISC_H

#include "types.h"

PieceType get_type(Piece piece);
Color get_color(Piece piece);
int get_index(int file, int rank);
bool is_capture(Move move);

#endif