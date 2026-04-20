#pragma once

#include <string>
#include "types.h"
#include "Board.h"
#include "Game.h"

char piece_to_char(Piece piece);
std::string piece_to_unicode(Piece piece);
std::string move_to_uci(Move move);
std::string move_to_san(Board& board, Move move);
std::string game_to_fen(const Game& game);
// Produces a PGN string with standard seven-tag roster plus optional FEN tag.
// whitePlayer / blackPlayer default to "?" if empty.
std::string game_to_pgn(const Game& game,
                         const std::string& whitePlayer = "?",
                         const std::string& blackPlayer = "?",
                         const std::string& eventName   = "?",
                         const std::string& siteName    = "?");

// Convert a UCI move string (e.g. "e2e4", "e7e8q") to a Move struct.
// The board is used to look up which piece is on the source square and to
// validate legality.  Returns a Move with square_from == square_to == -1
// on failure.
Move uci_to_move(const std::string& uci, Board& board, Color turn);

// Convert a SAN move string (e.g. "e4", "Nf3", "O-O") to a Move struct.
// Returns a Move with square_from == square_to == -1 on failure.
Move san_to_move(const std::string& san, Board& board, Color turn);

// Parse a PGN text string and reconstruct a Game with all moves played.
// Handles optional [FEN ...] tag for non-standard starting positions.
// Returns true on success, false if the PGN is unparseable or contains
// illegal moves (out_game is left in the successfully-replayed prefix).
bool parse_pgn(const std::string& pgn_text, Game& out_game);