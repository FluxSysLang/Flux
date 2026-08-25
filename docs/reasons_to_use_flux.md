# A list of 20 reasons to use Flux

If you're wondering, "why Flux?", here's some reasons.

1. "I want systems-level performance without C's footguns."  
Flux compiles to LLVM IR, is stack-allocated by default, and exposes raw pointer arithmetic and inline ASM - with the performance profile of C - while adding a type system, ownership semantics, and memory safety tooling that C simply doesn't have.  
2. "I need to call into C libraries without losing my mind."
The FFI system is first-class: extern blocks, !! no-mangle, string-literal function names for mangled C++ symbols, and calling-convention keywords (cdecl, stdcall, vectorcall) directly on the function definition. No boilerplate binding layer required.  
3. "I want compile-time code generation without a preprocessor macro language from 1972."  
comptime blocks run full Flux at compile time via the FVM - I/O, FFI, networking, anything - and emitflux injects generated Flux source back into the compilation unit. Self-referential macros constant-fold automatically. It's a real programming environment at compile time, not token pasting.  
4. "Operator precedence always bites me with bitwise ops and comparisons."  
Flux fixes the classic C mistake: bitwise operators (\`&, \`|, \`^|) bind tighter than comparisons, so `a == b & c` means what you intuitively expect. No extra parentheses needed.  
5. "I want to add methods to types I don't own, including primitives."  
Type functions let you attach callable methods to any type - structs, primitives, aliases - using _ as the implicit receiver. "Hello".add_world() or 0.clamp(min, max) work without wrapping the type in a new object.
6. "C++ templates are unreadable and SFINAE is a nightmare."  
Flux templates are pure type substitution with no SFINAE. Type constraints are declared explicitly with <T: int | long> or named constraint blocks, and type geometry operators (`~=`, `!<`, `!>`) express compatibility rules without template metaprogramming gymnastics.  
7. "I want guaranteed tail-call optimization without trusting the optimizer."  
The <~ recurse arrow on a function definition emits LLVM musttail, guaranteeing zero stack growth on every recursive call. The escape keyword exits the strict-recursion context when you genuinely need to return.  
8. "Parsing binary protocols and file formats in C is tedious byte-juggling."  
from recasts a byte buffer directly into a typed struct - no copy, no field-by-field assignment, compile-time size check included. Bit slices (x[a``b]) let you extract arbitrary bit ranges, even across struct member boundaries. Endianness is introspectable with endianof.  
9. "I want to enforce preconditions and postconditions without littering asserts everywhere."  
contract blocks are compile-time function body modifiers: a pre-contract runs before the body, a post-contract runs before every return. They're reusable, parameterizable, and composable - separation of correctness concerns from logic.  
10. "Memory management is either too manual (C) or too hidden (GC languages)."  
Flux gives you a spectrum: stack by default, heap keyword for explicit heap allocation, fmalloc/ffree for manual control, defer for deterministic cleanup, and the ~ tie operator for move-semantics ownership. The optional borrow checker (--borrowcheck) adds alias and escape analysis without requiring annotations.  
11. "I want to control object interaction boundaries, not just access modifiers."  
interface goes beyond public/private: it specifies exactly which methods object A may call on object B (A : B), which return values may flow across the boundary (B(A)), and which methods may be called from inside another object's body (A -> B). All enforced at compile time.  
12. "I want to define custom integer and bit-width types without a library."  
The data{N} keyword lets you declare any-width primitive types from scratch - signed or unsigned, with explicit alignment and endianness baked in - and alias them with as. A 13-bit signed value with 16-bit alignment is one line: signed data{13:16} as strange13;. These decay to integers under the hood, participate in normal arithmetic, and can be chain-aliased. It's not a struct wrapping an int - it's a genuine primitive type that fits your memory layout rather than forcing your layout to fit the language.  
13. "Bit manipulation in C is 16 lines of shifts and masks that should be 2."  
Bit slices (x[a``b]) let you address arbitrary bit ranges directly as lvalues - readable and writable in place - and they work across struct member boundaries and can be composed (bit slice of a bit slice is valid). The byte-unpacking cast convention ((byte[4])someValue always places the most significant byte at index 0) means operations like big-endian serialization that require 8 lines of >> N & 0xFF in C collapse to a single cast-assign. This isn't sugar - it's a different mental model for working with binary data.  
14. "I need to dispatch across calling conventions in the same codebase."  
Calling convention is part of the function signature, not a pragma or attribute: cdecl, stdcall, vectorcall, thiscall, and fastcall (default) are keywords. Function pointer types carry their convention: vectorcall{}* pfoo(int)->int. Mixing conventions in one binary is safe and explicit.  
15. "Multiple inheritance always causes diamond problems."  
Flux's object inheritance rules structurally forbid the diamond: if two parents share a method with matching signature but different implementations, it's a compile error. The child doesn't inherit __init/__expr/__exit from any parent, so lifecycle responsibility always belongs to the child unambiguously.  
16. "I want to enforce API contracts at scale - deprecated paths should cause build failures, not warnings."  
deprecate myNS::someFunc; is a static assertion: if any code in the compilation unit still references that path, it's a compile error. Not a warning - a hard stop. Useful for enforcing migration away from old APIs.  
17. "I need custom infix operators that feel native, not method-call sugar."  
operator lets you define genuinely new infix symbols (e.g. a +++ b) or identifier operators (a NOPOR b) with fixed, consistent precedence between + and \*. Overloading built-in symbols is supported when at least one operand is a non-built-in type, with strict exact-match rules to prevent surprising coercions.
18. "Singleton-initialized state is always a mess of static variables and guard flags."  
singinit declares a variable that initializes exactly once per call site, across all calls - no manual guard, no std::call_once, no thread-safety ceremony needed at the declaration level.  
19. "I want to express relationships between type parameters in a generic, not just constraints on each one individually."  
Flux's type geometry system lets you declare relational constraints across multiple template parameters: T \~= U (must be compatible), T !\~= U (must be incompatible), T !<= U(narrowing between specifically these two is forbidden), and so on. These aren't checked at the declaration site - the compiler walks the instantiated function body looking for actual violations: implicit arithmetic narrowing, return-type mismatches, casts. Namedconstraint sets let you package complex multi-parameter relation expressions into reusable, composable, mergeable units (constraint C3 = C1 + C2`). It's a system for expressing correctness rules about how types interact with each other, not just what each type individually is allowed to be.  
20. "I want to catch ownership bugs optionally without committing to a borrow-checker-everywhere language."  
The Flux Borrow Checker (--borrowcheck / --borrowcheck-warn) is a separate pass, not on the hot path. It checks pointer aliasing violations, scope escapes, and optionally thread safety (--threads) and heap leaks (--leaks) - with zero annotation required in source. You opt in when you want the guarantee, and skip it when iteration speed matters more.