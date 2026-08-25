// Author: Karac V. Thweatt

// regex.fx - NFA-based regular expression engine for Flux.
//
// Uses Thompson NFA simulation: O(n*m) time, O(m) space where n = input length,
// m = pattern length. No backtracking. No heap allocation.
//
// Supported syntax:
//   .         Any character except newline
//   *         Zero or more of the preceding atom
//   +         One or more of the preceding atom
//   ?         Zero or one of the preceding atom
//   |         Alternation
//   ( )       Grouping (used for alternation scope; no captures)
//   [ ]       Character class  e.g. [a-z0-9_]
//   [^ ]      Negated character class  e.g. [^aeiou]
//   ^         Anchor: start of string
//   $         Anchor: end of string
//   \d        Digit [0-9]
//   \D        Non-digit
//   \w        Word character [a-zA-Z0-9_]
//   \W        Non-word character
//   \s        Whitespace [ \t\n\r]
//   \S        Non-whitespace
//   \n \t \r  Literal newline / tab / carriage return
//   \\        Literal backslash
//   Any other character matches literally.
//
// Provides:
//   regex_compile(byte* pattern, RegexProgram* prog) -> bool
//       Compiles a pattern into prog. Returns false if the pattern is invalid
//       or exceeds REGEX_MAX_INSTR instructions.
//
//   regex_match(RegexProgram* prog, byte* text) -> bool
//       Returns true if the entire text matches the pattern (anchored both ends).
//
//   regex_search(RegexProgram* prog, byte* text, int* match_start, int* match_len) -> bool
//       Finds the leftmost-longest match anywhere in text.
//       On success, *match_start and *match_len are set.
//
//   regex_find(RegexProgram* prog, byte* text, int start,
//              int* match_start, int* match_len) -> bool
//       Like regex_search but begins scanning at byte offset `start`.
//       Use to iterate all non-overlapping matches.
//
//   regex_replace(RegexProgram* prog, byte* src, byte* repl,
//                 byte* dst, int dst_cap) -> int
//       Replaces all non-overlapping matches in src with repl, writing into dst.
//       Returns number of bytes written, or -1 if dst_cap exceeded.
//
// Limits (all compile-time constants, adjustable via #def before import):
//   REGEX_MAX_INSTR   512   Maximum NFA instructions per program
//   REGEX_MAX_STATES  512   Maximum simultaneous active NFA states
//   REGEX_MAX_CLASS   32    Maximum bytes in a character class bitmap (256 bits)
//
// Dependencies: standard::types, standard::memory, standard::strings

#ifndef FLUX_STANDARD_TYPES
#import <types.fx>;
#endif;

#ifndef FLUX_STANDARD_MEMORY
#import <memory.fx>;
#endif;

#ifndef FLUX_STANDARD_STRINGS
#import <string_utilities.fx>;
#endif;

#ifndef FLUX_STANDARD_REGEX
#def FLUX_STANDARD_REGEX 1;

#ifndef REGEX_MAX_INSTR
#def REGEX_MAX_INSTR 512;
#endif;

#ifndef REGEX_MAX_STATES
#def REGEX_MAX_STATES 512;
#endif;

#ifndef REGEX_MAX_CLASS
#def REGEX_MAX_CLASS 32;
#endif;

using standard::memory,
      standard::strings;

namespace standard
{
	namespace regex
	{
		///  -------------------------------------------------------------------
		  Instruction opcodes
		  -------------------------------------------------------------------
		///

		// OP_CHAR    match one literal byte (arg = the byte)
		// OP_ANY     match any byte except \n
		// OP_CLASS   match a byte in the bitmap stored in class_data
		// OP_NCLASS  match a byte NOT in the bitmap
		// OP_SPLIT   fork execution: next two states are out0 and out1
		// OP_JUMP    unconditional jump to out0
		// OP_MATCH   accept
		// OP_BOL     assert position == start of string
		// OP_EOL     assert next byte == 0 (end of string)

		#def OP_CHAR   0;
		#def OP_ANY    1;
		#def OP_CLASS  2;
		#def OP_NCLASS 3;
		#def OP_SPLIT  4;
		#def OP_JUMP   5;
		#def OP_MATCH  6;
		#def OP_BOL    7;
		#def OP_EOL    8;

		// Instruction layout.
		// out0, out1: indices into the instruction array; -1 = no target.
		// arg:        for OP_CHAR the literal byte; unused otherwise.
		// class_id:   for OP_CLASS/OP_NCLASS, index into prog.classes[].

		struct RegexInstr
		{
			int op, out0, out1, arg, class_id;
		};

		// A compiled character class: 256-bit bitmap, one bit per ASCII value.
		// bytes[i >> 3] bit (i & 7) is set if character i is in the class.

		struct RegexClass
		{
			byte[REGEX_MAX_CLASS] bytes;
		};

		// A compiled regex program.

		#def REGEX_MAX_CLASSES 32;

		struct RegexProgram
		{
			RegexInstr[REGEX_MAX_INSTR] instr;
			RegexClass[REGEX_MAX_CLASSES] classes;
			int n_instr, n_classes;
			bool anchored_start, anchored_end;
		};


		///  -------------------------------------------------------------------
		  Compiler internals
		  -------------------------------------------------------------------
		///

		// Compiler state lives entirely on the stack.

		struct RegexCompiler
		{
			byte*        pat;
			int          pos, n_pat;
			RegexProgram* prog;
			bool         ok;
		};

		// Emit one instruction; return its index, or -1 on overflow.
		def _emit(RegexProgram* prog, int op, int out0, int out1, int arg, int class_id) -> int
		{
			int idx;
			if (prog.n_instr >= REGEX_MAX_INSTR) { return -1; };
			idx = prog.n_instr;
			prog.instr[idx].op       = op;
			prog.instr[idx].out0     = out0;
			prog.instr[idx].out1     = out1;
			prog.instr[idx].arg      = arg;
			prog.instr[idx].class_id = class_id;
			prog.n_instr++;
			return idx;
		};

		// Set a bit in a class bitmap.
		def _class_set(RegexClass* cls, int ch) -> void
		{
			if (ch < 0 | ch > 255) { return; };
			cls.bytes[ch >> 3] = cls.bytes[ch >> 3] | (byte)(1 << (ch `& 7));
		};

		// Test a bit in a class bitmap.
		def _class_test(RegexClass* cls, int ch) -> bool
		{
			if (ch < 0 | ch > 255) { return false; };
			return (cls.bytes[ch >> 3] `& (byte)(1 << (ch `& 7))) != 0;
		};

		// Allocate a new class slot; return its index or -1.
		def _new_class(RegexProgram* prog) -> int
		{
			int idx;
			if (prog.n_classes >= REGEX_MAX_CLASSES) { return -1; };
			idx = prog.n_classes;
			prog.n_classes++;
			return idx;
		};

		// Forward declarations (compiler is mutually recursive).
		def _compile_alternation(RegexCompiler* c, int* start_out, int* end_out) -> bool;
		def _compile_concat(RegexCompiler* c, int* start_out, int* end_out) -> bool;
		def _compile_atom(RegexCompiler* c, int* start_out, int* end_out) -> bool;
		def _add_state(RegexProgram* prog, int* states, int* n_states,
		               int* visited, int s, int text_pos, bool at_start) -> void;

		// Patch all instructions in the chain rooted at `idx` that have
		// out0 == -1 to point to `target`. Used to link dangling exits.
		def _patch(RegexProgram* prog, int idx, int target) -> void
		{
			int cur, next;
			cur = idx;
			while (cur != -1)
			{
				if (prog.instr[cur].out0 == -1)
				{
					next                  = prog.instr[cur].out1;
					prog.instr[cur].out0 = target;
					prog.instr[cur].out1 = -1;
					cur                   = next;
				}
				else
				{
					cur = -1;
				};
			};
		};


		///  -------------------------------------------------------------------
		  Character class parser  [ ... ]
		  -------------------------------------------------------------------
		///

		def _parse_class(RegexCompiler* c, int class_idx) -> bool
		{
			RegexClass* cls = @c.prog.classes[class_idx];
			int         ch, lo, hi;
			byte        b, bnext;
			bool        negate;

			// Check for negation.
			if (c.pos < c.n_pat & c.pat[c.pos] == (byte)94)  // '^'
			{
				negate = true;
				c.pos++;
			};

			while (c.pos < c.n_pat)
			{
				b = c.pat[c.pos];
				if (b == (byte)93) { c.pos++; break; };  // ']'

				// Escape sequences inside [ ].
				if (b == (byte)92 & c.pos + 1 < c.n_pat)  // '\'
				{
					c.pos++;
					b = c.pat[c.pos];
					c.pos++;
					if (b == (byte)100)       // \d
					{
						lo = 48; hi = 57;
						while (lo <= hi) { _class_set(cls, lo); lo++; };
					}
					else if (b == (byte)119)  // \w
					{
						lo = 48; hi = 57;  while (lo <= hi) { _class_set(cls, lo); lo++; };
						lo = 65; hi = 90;  while (lo <= hi) { _class_set(cls, lo); lo++; };
						lo = 97; hi = 122; while (lo <= hi) { _class_set(cls, lo); lo++; };
						_class_set(cls, 95);  // '_'
					}
					else if (b == (byte)115)  // \s
					{
						_class_set(cls, 32);   // space
						_class_set(cls, 9);    // \t
						_class_set(cls, 10);   // \n
						_class_set(cls, 13);   // \r
					}
					else if (b == (byte)110) { _class_set(cls, 10); }   // \n
					else if (b == (byte)116) { _class_set(cls, 9);  }   // \t
					else if (b == (byte)114) { _class_set(cls, 13); }   // \r
					else                     { _class_set(cls, (int)b); };
					continue;
				};

				// Possible range: a-z
				if (c.pos + 2 < c.n_pat & c.pat[c.pos + 1] == (byte)45)  // '-'
				{
					bnext = c.pat[c.pos + 2];
					if (bnext != (byte)93)  // not ']'
					{
						lo = (int)b;
						hi = (int)bnext;
						if (lo > hi) { return false; };
						while (lo <= hi) { _class_set(cls, lo); lo++; };
						c.pos += 3;
						continue;
					};
				};

				// Single character.
				_class_set(cls, (int)b);
				c.pos++;
			};

			// If negated, flip all 256 bits but keep \n out (regex convention).
			if (negate)
			{
				int i;
				while (i < REGEX_MAX_CLASS)
				{
					cls.bytes[i] = cls.bytes[i] `^| (byte)0xFF;
					i++;
				};
				// Remove \n from negated class so [^x] doesn't match newlines.
				int newline_byte = 10 >> 3;
				cls.bytes[newline_byte] = cls.bytes[newline_byte] `& (byte)`!(1 << (10 `& 7));
			};

			return true;
		};


		///  -------------------------------------------------------------------
		  Atom compiler
		  -------------------------------------------------------------------
		///

		// Compile a single atom. Returns the index of the first instruction
		// emitted (start_out) and the last instruction whose out0 is still
		// open / dangling (end_out). The caller chains end_out to what follows.

		def _compile_atom(RegexCompiler* c, int* start_out, int* end_out) -> bool
		{
			int  idx, cid, lo, hi;
			byte b, b2;

			if (c.pos >= c.n_pat) { return false; };

			b = c.pat[c.pos];

			// '(' — grouped alternation
			if (b == (byte)40)
			{
				c.pos++;
				if (!_compile_alternation(c, start_out, end_out)) { return false; };
				if (c.pos >= c.n_pat | c.pat[c.pos] != (byte)41) { return false; };
				c.pos++;
				return true;
			};

			// '.' — any except newline
			if (b == (byte)46)
			{
				c.pos++;
				idx = _emit(c.prog, OP_ANY, -1, -1, 0, 0);
				if (idx < 0) { return false; };
				*start_out = idx;
				*end_out   = idx;
				return true;
			};

			// '^' — start anchor
			if (b == (byte)94)
			{
				c.pos++;
				idx = _emit(c.prog, OP_BOL, -1, -1, 0, 0);
				if (idx < 0) { return false; };
				*start_out = idx;
				*end_out   = idx;
				return true;
			};

			// '$' — end anchor
			if (b == (byte)36)
			{
				c.pos++;
				idx = _emit(c.prog, OP_EOL, -1, -1, 0, 0);
				if (idx < 0) { return false; };
				*start_out = idx;
				*end_out   = idx;
				return true;
			};

			// '[' — character class
			if (b == (byte)91)
			{
				c.pos++;
				bool negated = (c.pos < c.n_pat & c.pat[c.pos] == (byte)94);
				cid = _new_class(c.prog);
				if (cid < 0) { return false; };
				if (!_parse_class(c, cid)) { return false; };
				int op = negated ? OP_NCLASS : OP_CLASS;
				// _parse_class already handled negation in the bitmap; always emit OP_CLASS.
				idx = _emit(c.prog, OP_CLASS, -1, -1, 0, cid);
				if (idx < 0) { return false; };
				*start_out = idx;
				*end_out   = idx;
				return true;
			};

			// '\' — escape
			if (b == (byte)92 & c.pos + 1 < c.n_pat)
			{
				c.pos++;
				b2 = c.pat[c.pos];
				c.pos++;

				if (b2 == (byte)110) { b2 = (byte)10;  };  // \n
				if (b2 == (byte)116) { b2 = (byte)9;   };  // \t
				if (b2 == (byte)114) { b2 = (byte)13;  };  // \r

				// \d \D \w \W \s \S — emit CLASS/NCLASS
				if (b2 == (byte)100 | b2 == (byte)68 |   // d D
				    b2 == (byte)119 | b2 == (byte)87 |   // w W
				    b2 == (byte)115 | b2 == (byte)83)    // s S
				{
					cid = _new_class(c.prog);
					if (cid < 0) { return false; };
					RegexClass* cls = @c.prog.classes[cid];
					if (b2 == (byte)100 | b2 == (byte)68)
					{
						lo = 48; hi = 57; while (lo <= hi) { _class_set(cls, lo); lo++; };
					}
					else if (b2 == (byte)119 | b2 == (byte)87)
					{
						lo = 48; hi = 57;  while (lo <= hi) { _class_set(cls, lo); lo++; };
						lo = 65; hi = 90;  while (lo <= hi) { _class_set(cls, lo); lo++; };
						lo = 97; hi = 122; while (lo <= hi) { _class_set(cls, lo); lo++; };
						_class_set(cls, 95);
					}
					else
					{
						_class_set(cls, 32); _class_set(cls, 9);
						_class_set(cls, 10); _class_set(cls, 13);
					};
					// Uppercase = negated.
					bool neg = (b2 == (byte)68 | b2 == (byte)87 | b2 == (byte)83);
					if (neg)
					{
						int fi;
						while (fi < REGEX_MAX_CLASS)
						{
							cls.bytes[fi] = cls.bytes[fi] `^| (byte)0xFF;
							fi++;
						};
						int nl_byte = 10 >> 3;
						cls.bytes[nl_byte] = cls.bytes[nl_byte] `& (byte)`!(1 << (10 `& 7));
					};
					int op2 = OP_CLASS;
					idx = _emit(c.prog, op2, -1, -1, 0, cid);
					if (idx < 0) { return false; };
					*start_out = idx;
					*end_out   = idx;
					return true;
				};

				// Literal escaped character.
				idx = _emit(c.prog, OP_CHAR, -1, -1, (int)b2, 0);
				if (idx < 0) { return false; };
				*start_out = idx;
				*end_out   = idx;
				return true;
			};

			// Stop characters that are not atoms.
			if (b == (byte)41 | b == (byte)124) { return false; };  // ) |

			// Plain literal character.
			c.pos++;
			idx = _emit(c.prog, OP_CHAR, -1, -1, (int)b, 0);
			if (idx < 0) { return false; };
			*start_out = idx;
			*end_out   = idx;
			return true;
		};


		///  -------------------------------------------------------------------
		  Quantifier compiler  (wraps an atom with * + ?)
		  -------------------------------------------------------------------
		///

		def _compile_quantified(RegexCompiler* c, int* start_out, int* end_out) -> bool
		{
			int atom_start, atom_end, split_idx, jump_idx;
			byte q;

			if (!_compile_atom(c, @atom_start, @atom_end)) { return false; };

			if (c.pos >= c.n_pat)
			{
				*start_out = atom_start;
				*end_out   = atom_end;
				return true;
			};

			q = c.pat[c.pos];

			// '*'  →  SPLIT(out0=-1[exit], out1=atom_start); atom_end → SPLIT
			if (q == (byte)42)
			{
				c.pos++;
				split_idx = _emit(c.prog, OP_SPLIT, -1, atom_start, 0, 0);
				if (split_idx < 0) { return false; };
				_patch(c.prog, atom_end, split_idx);
				*start_out = split_idx;
				*end_out   = split_idx;
				return true;
			};

			// '+'  →  atom; SPLIT(out0=-1[exit], out1=atom_start)
			if (q == (byte)43)
			{
				c.pos++;
				split_idx = _emit(c.prog, OP_SPLIT, -1, atom_start, 0, 0);
				if (split_idx < 0) { return false; };
				_patch(c.prog, atom_end, split_idx);
				*start_out = atom_start;
				*end_out   = split_idx;
				return true;
			};

			// '?'  →  SPLIT(out0=-1[exit], out1=atom_start); chain atom_end→split
			if (q == (byte)63)
			{
				c.pos++;
				split_idx = _emit(c.prog, OP_SPLIT, -1, atom_start, 0, 0);
				if (split_idx < 0) { return false; };
				c.prog.instr[atom_end].out1 = split_idx;
				*start_out = split_idx;
				*end_out   = atom_end;
				return true;
			};

			// No quantifier.
			*start_out = atom_start;
			*end_out   = atom_end;
			return true;
		};


		///  -------------------------------------------------------------------
		  Concatenation compiler
		  -------------------------------------------------------------------
		///

		def _compile_concat(RegexCompiler* c, int* start_out, int* end_out) -> bool
		{
			int  first_start, first_end, next_start, next_end;
			byte peek;
			bool got_first;

			got_first = false;

			while (c.pos < c.n_pat)
			{
				peek = c.pat[c.pos];
				// Stop at alternation or close-paren.
				if (peek == (byte)124 | peek == (byte)41) { break; };

				if (!got_first)
				{
					if (!_compile_quantified(c, @first_start, @first_end)) { return false; };
					got_first = true;
				}
				else
				{
					if (!_compile_quantified(c, @next_start, @next_end)) { return false; };
					// Link first_end → next_start.
					_patch(c.prog, first_end, next_start);
					first_end = next_end;
				};
			};

			if (!got_first) { return false; };
			*start_out = first_start;
			*end_out   = first_end;
			return true;
		};


		///  -------------------------------------------------------------------
		  Alternation compiler
		  -------------------------------------------------------------------
		///

		def _compile_alternation(RegexCompiler* c, int* start_out, int* end_out) -> bool
		{
			int  lhs_start, lhs_end, rhs_start, rhs_end, split_idx, jump_idx;

			if (!_compile_concat(c, @lhs_start, @lhs_end)) { return false; };

			if (c.pos < c.n_pat & c.pat[c.pos] == (byte)124)  // '|'
			{
				c.pos++;
				if (!_compile_alternation(c, @rhs_start, @rhs_end)) { return false; };

				// Emit SPLIT(lhs_start, rhs_start) before both branches.
				// Since both are already emitted, emit a JUMP relay:
				//   split → SPLIT(jump_to_lhs, rhs_start)
				//   jump_to_lhs → JUMP(lhs_start)
				// Then start = split_idx.
				jump_idx  = _emit(c.prog, OP_JUMP, lhs_start, -1, 0, 0);
				if (jump_idx < 0) { return false; };
				split_idx = _emit(c.prog, OP_SPLIT, jump_idx, rhs_start, 0, 0);
				if (split_idx < 0) { return false; };

				*start_out = split_idx;
				// Both lhs_end and rhs_end are open; chain them.
				// Use the patch-list trick: link via out1 when out0 == -1.
				c.prog.instr[lhs_end].out1 = rhs_end;
				*end_out = lhs_end;
				return true;
			};

			*start_out = lhs_start;
			*end_out   = lhs_end;
			return true;
		};


		///  -------------------------------------------------------------------
		  Public compile entry point
		  -------------------------------------------------------------------
		///

		def regex_compile(byte* pattern, RegexProgram* prog) -> bool
		{
			RegexCompiler c;
			int start, end, match_idx;

			mem_zero(prog, (size_t)(sizeof(RegexProgram) / 8));

			c.pat    = pattern;
			c.pos    = 0;
			c.n_pat  = strlen(pattern);
			c.prog   = prog;
			c.ok     = true;

			// Strip leading '^' anchor.
			if (c.n_pat > 0 & pattern[0] == (byte)94)
			{
				prog.anchored_start = true;
				c.pos++;
			};

			// Strip trailing '$' anchor (only if last char and not escaped).
			if (c.n_pat > 1 & pattern[c.n_pat - 1] == (byte)36)
			{
				bool escaped = (c.n_pat > 2 & pattern[c.n_pat - 2] == (byte)92);
				if (!escaped)
				{
					prog.anchored_end = true;
					c.n_pat--;
				};
			};

			if (c.pos >= c.n_pat)
			{
				// Empty pattern: matches everything.
				match_idx = _emit(prog, OP_MATCH, -1, -1, 0, 0);
				return match_idx >= 0;
			};

			if (!_compile_alternation(@c, @start, @end)) { return false; };

			// Append MATCH and patch the open exit.
			match_idx = _emit(prog, OP_MATCH, -1, -1, 0, 0);
			if (match_idx < 0) { return false; };
			_patch(prog, end, match_idx);

			// The program starts at the last emitted instruction index.
			// Reorder: the entry point is `start`, not instruction 0.
			// We store the entry by swapping instruction 0 with `start` if needed.
			// Simpler: store entry_point in the program struct.
			// Since we don't have that field, prepend a JUMP(start).
			if (start != 0)
			{
				int jmp_idx = _emit(prog, OP_JUMP, start, -1, 0, 0);
				if (jmp_idx < 0) { return false; };
				// Move jmp_idx to slot 0 by swapping with whatever is there.
				RegexInstr tmp = prog.instr[0];
				prog.instr[0]       = prog.instr[jmp_idx];
				prog.instr[jmp_idx] = tmp;
				// Fix all references to 0 → jmp_idx, and to jmp_idx → 0.
				int fi;
				while (fi < prog.n_instr)
				{
					if (prog.instr[fi].out0 == 0)         { prog.instr[fi].out0 = jmp_idx; }
					else if (prog.instr[fi].out0 == jmp_idx) { prog.instr[fi].out0 = 0; };
					if (prog.instr[fi].out1 == 0)         { prog.instr[fi].out1 = jmp_idx; }
					else if (prog.instr[fi].out1 == jmp_idx) { prog.instr[fi].out1 = 0; };
					fi++;
				};
			};

			return true;
		};


		///  -------------------------------------------------------------------
		  NFA simulation
		  -------------------------------------------------------------------
		///

		// Add state `s` to the active set, following epsilon (SPLIT/JUMP) edges.
		def _add_state(RegexProgram* prog, int* states, int* n_states,
		               int* visited, int s, int text_pos, bool at_start) -> void
		{
			int op;
			if (s < 0 | s >= prog.n_instr) { return; };
			if (visited[s] != 0) { return; };
			visited[s] = 1;

			op = prog.instr[s].op;

			if (op == OP_JUMP)
			{
				_add_state(prog, states, n_states, visited, prog.instr[s].out0,
				           text_pos, at_start);
				return;
			};

			if (op == OP_SPLIT)
			{
				_add_state(prog, states, n_states, visited, prog.instr[s].out0,
				           text_pos, at_start);
				_add_state(prog, states, n_states, visited, prog.instr[s].out1,
				           text_pos, at_start);
				return;
			};

			if (op == OP_BOL)
			{
				if (at_start)
				{
					_add_state(prog, states, n_states, visited, prog.instr[s].out0,
					           text_pos, at_start);
				};
				return;
			};

			if (op == OP_EOL)
			{
				// EOL is handled during step; just add it as-is so step can check.
				if (*n_states < REGEX_MAX_STATES)
				{
					int eol_n = *n_states;
					states[eol_n] = s;
					*n_states = eol_n + 1;
				};
				return;
			};

			if (*n_states < REGEX_MAX_STATES)
			{
				int add_n = *n_states;
				states[add_n] = s;
				*n_states = add_n + 1;
			};
		};

		// Simulate one step: consume byte `ch` from current states,
		// produce next states. Returns true if MATCH was reached.
		def _step(RegexProgram* prog,
		          int* cur, int n_cur,
		          int* nxt, int* n_nxt,
		          int* visited,
		          int ch, int text_pos, int text_len,
		          bool at_start) -> bool
		{
			int i, s, op, out0;
			bool matched;
			i       = 0;
			*n_nxt  = 0;
			matched = false;

			mem_zero(visited, (size_t)(REGEX_MAX_STATES * (sizeof(int) / 8)));

			while (i < n_cur)
			{
				s  = cur[i];
				op = prog.instr[s].op;

				if (op == OP_MATCH)
				{
					matched = true;
					i++;
					continue;
				};

				if (op == OP_EOL)
				{
					if (ch == 0 | text_pos >= text_len)
					{
						_add_state(prog, nxt, n_nxt, visited, prog.instr[s].out0,
						           text_pos, false);
					};
					i++;
					continue;
				};

				if (op == OP_CHAR)
				{
					if (ch == prog.instr[s].arg)
					{
						out0 = prog.instr[s].out0;
						_add_state(prog, nxt, n_nxt, visited, out0, text_pos, false);
					};
					i++;
					continue;
				};

				if (op == OP_ANY)
				{
					if (ch != 10 & ch != 0)  // not \n, not NUL
					{
						out0 = prog.instr[s].out0;
						_add_state(prog, nxt, n_nxt, visited, out0, text_pos, false);
					};
					i++;
					continue;
				};

				if (op == OP_CLASS)
				{
					if (_class_test(@prog.classes[prog.instr[s].class_id], ch))
					{
						out0 = prog.instr[s].out0;
						_add_state(prog, nxt, n_nxt, visited, out0, text_pos, false);
					};
					i++;
					continue;
				};

				if (op == OP_NCLASS)
				{
					if (!_class_test(@prog.classes[prog.instr[s].class_id], ch))
					{
						out0 = prog.instr[s].out0;
						_add_state(prog, nxt, n_nxt, visited, out0, text_pos, false);
					};
					i++;
					continue;
				};

				i++;
			};

			return matched;
		};

		// Core search engine. Scans text[scan_from..] for the leftmost-longest match.
		// Returns true and sets *ms, *ml on success.
		def _search_from(RegexProgram* prog, byte* text, int text_len,
		                 int scan_from, int* ms, int* ml) -> bool
		{
			int[REGEX_MAX_STATES] cur_states, nxt_states;
			int[REGEX_MAX_STATES] visited;
			int  n_cur, n_nxt, si, pos, ch;
			bool found, at_start;
			int  match_start, match_end;
			int  ci, ci2, sci;

			found       = false;
			match_start = -1;
			match_end   = -1;
			si          = scan_from;

			while (si <= text_len)
			{
				// Start a new attempt from position si.
				n_cur    = 0;
				at_start = (si == 0);
				mem_zero(@visited[0], (size_t)(REGEX_MAX_STATES * (sizeof(int) / 8)));
				_add_state(prog, @cur_states[0], @n_cur, @visited[0], 0, si, at_start);

				// If anchored to start, only try from position 0.
				if (prog.anchored_start & si > 0) { break; };

				pos = si;
				while (n_cur > 0)
				{
					// Check for match in current state set.
					ci = 0;
					while (ci < n_cur)
					{
						if (prog.instr[cur_states[ci]].op == OP_MATCH)
						{
							if (!found | pos > match_end)
							{
								found       = true;
								match_start = si;
								match_end   = pos;
							};
						};
						ci++;
					};

					if (pos >= text_len) { break; };

					ch = (int)text[pos];
					mem_zero(@visited[0], (size_t)(REGEX_MAX_STATES * (sizeof(int) / 8)));
					_step(prog, @cur_states[0], n_cur, @nxt_states[0], @n_nxt,
					      @visited[0], ch, pos, text_len, pos == 0);

					// Copy nxt into cur.
					n_cur = n_nxt;
					n_nxt = 0;
					sci   = 0;
					while (sci < n_cur)
					{
						cur_states[sci] = nxt_states[sci];
						sci++;
					};

					pos++;
				};

				// Check match at end of scan.
				ci2 = 0;
				while (ci2 < n_cur)
				{
					if (prog.instr[cur_states[ci2]].op == OP_MATCH)
					{
						if (!found | pos > match_end)
						{
							found       = true;
							match_start = si;
							match_end   = pos;
						};
					};
					ci2++;
				};

				if (found & prog.anchored_start) { break; };
				si++;
			};

			if (found)
			{
				if (prog.anchored_end & match_end != text_len) { return false; };
				*ms = match_start;
				*ml = match_end - match_start;
				return true;
			};
			return false;
		};


		///  -------------------------------------------------------------------
		  Public API
		  -------------------------------------------------------------------
		///

		// Returns true if the entire text matches the pattern (fully anchored).
		def regex_match(RegexProgram* prog, byte* text) -> bool
		{
			int ms, ml, tlen;
			tlen = strlen(text);
			if (!_search_from(prog, text, tlen, 0, @ms, @ml)) { return false; };
			return ms == 0 & ml == tlen;
		};

		// Finds the leftmost-longest match anywhere in text.
		def regex_search(RegexProgram* prog, byte* text,
		                 int* match_start, int* match_len) -> bool
		{
			int tlen = strlen(text);
			return _search_from(prog, text, tlen, 0, match_start, match_len);
		};

		// Like regex_search but begins scanning at byte offset `start`.
		def regex_find(RegexProgram* prog, byte* text, int start,
		               int* match_start, int* match_len) -> bool
		{
			int tlen = strlen(text);
			if (start > tlen) { return false; };
			return _search_from(prog, text, tlen, start, match_start, match_len);
		};

		// Replaces all non-overlapping matches in src with repl, writing to dst.
		// Returns bytes written, or -1 if dst_cap exceeded.
		def regex_replace(RegexProgram* prog, byte* src, byte* repl,
		                  byte* dst, int dst_cap) -> int
		{
			int  tlen, rlen, out, pos, ms, ml, ci;
			bool found;
			tlen = strlen(src);
			rlen = strlen(repl);
			out  = 0;
			pos  = 0;
			while (pos <= tlen)
			{
				found = _search_from(prog, src, tlen, pos, @ms, @ml);
				if (!found | ml == 0) { break; };
				// Copy literal prefix src[pos..ms).
				ci = pos;
				while (ci < ms)
				{
					if (out >= dst_cap) { return -1; };
					dst[out] = src[ci];
					out++;
					ci++;
				};
				// Copy replacement.
				ci = 0;
				while (ci < rlen)
				{
					if (out >= dst_cap) { return -1; };
					dst[out] = repl[ci];
					out++;
					ci++;
				};
				pos = ms + ml;
				if (ml == 0) { pos++; };
			};
			// Copy remaining tail.
			ci = pos;
			while (ci < tlen)
			{
				if (out >= dst_cap) { return -1; };
				dst[out] = src[ci];
				out++;
				ci++;
			};
			if (out >= dst_cap) { return -1; };
			dst[out] = (byte)0;
			return out;
		};

	};
};

#endif;
