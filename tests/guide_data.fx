// guide_data.fx -- Language Guide content for fide
// To add an entry: add a FluxExample struct literal to g_examples[].
// Entries MUST remain alphabetical by name.

struct FluxExample
{
    noopstr name, desc, code;
};

FluxExample[] g_examples = [

    // ---- A ----

    { "alignof",
      "Returns the alignment requirement of a type in bits.",
      "#import <standard.fx>;\n\nusing standard::io::console;\n\ndef main() -> int\n{\n    data{32:64} as u32_a64;\n    u32_a64 trees = 200;\n\n    while (trees-- > alignof(u32_a64))\n    {\n        println(f\"Chopping a tree! {trees--} left!\");\n    };\n\n    return 0;\n};\n"
    },

    { "and",
      "Logical AND operator. Equivalent to &.",
      "if (x > 0 and y > 0)\n{\n    println(\"Both positive.\");\n};\n" },

    { "as",
      "Creates a type alias.",
      "unsigned data{32} as u32;\nsigned   data{64} as i64;\n" },

    { "asm",
      "Inline assembly block. Use volatile to prevent optimization.",
      "volatile asm\n{\n    mov x0, #1\n    mov x1, $0\n    mov x2, $1\n    svc #0x80\n} : : \"r\"(msg), \"r\"(count) : \"x0\",\"x1\",\"x2\",\"memory\";\n" },

    { "assert",
      "Halts compilation or execution if the condition is false.",
      "assert(x > 0);\n" },

    { "auto",
      "Infers the type of a variable from its initializer. Coerces to the smallest fitting type.",
      "auto x = 5;      // x is char\nauto y = 300;    // y is uint (exceeds char max)\nauto z = 3.14f;  // z is float\n" },

    // ---- B ----

    { "bool",
      "Boolean type. Values are true or false. Default is false (zero-initialized).",
      "bool flag = true;\nbool done;   // false by default\n" },

    { "break",
      "Exits the nearest enclosing loop or switch statement.",
      "while (true)\n{\n    if (done) { break; };\n};\n" },

    { "byte",
      "Single byte type. Width configurable via __BYTE_WIDTH__, default 8 bits.",
      "byte b = 0xFF;\nbyte* msg = \"Hello\""
    },

    // ---- C ----

    { "case",
      "Defines a branch in a switch statement. No fallthrough. No semicolon after the block.",
      "switch (x)\n{\n    case (1) { println(\"one\"); }\n    case (2) { println(\"two\"); }\n    default  { println(\"other\"); };\n};\n" },

    { "catch",
      "Handles a thrown exception from a try block.",
      "try\n{\n    throw(42);\n}\ncatch (int e)\n{\n    println(f\"Caught: {e}\");\n};\n" },

    { "cdecl",
      "Declares a function using the cdecl calling convention. Used in place of def.",
      "cdecl foo(int x) -> int { return x; };\n" },

    { "char",
      "Character type. Guaranteed 8 bits.",
      "char c = 'H';\n" },

    { "comptime",
      "Compile-time block evaluated by the Flux Virtual Machine. Supports full Flux including I/O, FFI, and emitflux.",
      "comptime\n{\n    byte*[] names = [\"Alice\", \"Bob\"];\n    int count = 2;\n\n    for (int i = 0; i < count; i++)\n    {\n        emitflux\n        {\n            def ~$f\"greet_{names[i]}\"() -> void\n            {\n                println(~$f\"{names[i]}\");\n            };\n        };\n    };\n};\n" },

    { "const",
      "Marks a variable as immutable after initialization.",
      "const int MAX = 100;\nconst byte* GREETING = \"Hello\""
    },

    { "continue",
      "Skips to the next iteration of the nearest enclosing loop.",
      "for (int i = 0; i < 10; i++)\n{\n    if (i == 5) { continue; };\n    println(i);\n};\n" },

    // ---- D ----

    { "data",
      "Declares a raw bit-width type. Syntax: data{width} or data{width:alignment}.",
      "unsigned data{32}    as u32;\nsigned   data{64}    as i64;\nunsigned data{32:64} as u32_aligned64;\n" },

    { "def",
      "Declares or defines a function. Uses fastcall calling convention by default.",
      "def add(int x, int y) -> int\n{\n    return x + y;\n};\n" },

    { "default",
      "Fallback branch in a switch statement. Requires semicolon block termination.",
      "switch (x)\n{\n    case (1) { println(\"one\"); }\n    default  { println(\"other\"); };\n};\n" },

    { "deprecate",
      "Marks a namespace, object member, or function signature as deprecated. Emits an error on use.",
      "deprecate oldFunc() -> void;\ndeprecate oldLib;\ndeprecate oldMember;\n" },

    { "do",
      "Enters a do loop. Optionally followed by while for a do-while loop.",
      "int x = 0;\ndo { x++; } while (x < 10);\n" },

    { "double",
      "64-bit floating point type.",
      "double pi = 3.14159265358979;\n" },

    // ---- E ----

    { "elif",
      "Else-if branch in a conditional chain.",
      "if (x == 1)      { println(\"one\");   }\nelif (x == 2)    { println(\"two\");   }\nelse             { println(\"other\"); };\n" },

    { "else",
      "Fallback branch of an if statement.",
      "if (x > 0) { println(\"positive\"); }\nelse       { println(\"non-positive\"); };\n" },

    { "emitflux",
      "Emits Flux source code at the scope of the enclosing comptime block. Used for compile-time code generation.",
      "comptime\n{\n    byte*[] ops = [\"+\", \"-\", \"*\"];\n    int count = 3;\n\n    for (int i = 0; i < count; i++)\n    {\n        emitflux\n        {\n            def ~$f\"apply_{ops[i]}\"(int a, int b) -> int\n            {\n                return a ~$ops[i] b;\n            };\n        };\n    };\n};\n" },

    { "enum",
      "Declares an enumeration of named integer constants.",
      "enum Color { RED, GREEN, BLUE };\n\nColor c = Color.RED;\n" },

    { "escape",
      "Exits a strictly-recursive function and returns a value. Every return in a strict-recurse re-enters; escape is the only true exit.",
      "def factorial <~ int (int n, int acc)\n{\n    if (n <= 1) { escape acc; };\n    return factorial(n - 1, acc * n);\n};\n" },

    { "export",
      "Defines a function as externally visible for linkage. Used when creating libraries.",
      "export\n{\n    def !!add(int a, int b) -> int\n    {\n        return a + b;\n    };\n};\n" },

    { "extern",
      "References a function or variable from an external library via FFI.",
      "extern\n{\n    def !!printf(byte* fmt, ...) -> int;\n    int some_external_int;\n};\n" },

    // ---- F ----

    { "false",
      "Boolean literal false. Equivalent to 0.",
      "bool flag = false;\nbool done;  // also false -- zero-initialized by default\n" },

    { "fastcall",
      "Declares a function using the fastcall calling convention. Used in place of def.",
      "fastcall foo(int x) -> int { return x; };\n" },

    { "float",
      "32-bit floating point type.",
      "float pi = 3.14159f;\n" },

    { "fluxvm",
      "Inline Flux VM assembly inside a comptime block.",
      "comptime\n{\n    int x = 5;\n\n    fluxvm\n    {\n        LOCAL_GET x\n        PUSH 10\n        ADD\n        LOCAL_SET x\n    };\n\n    compiler.io.console.print(f\"x = {x}\\n\");\n};\n" },

    { "for",
      "Declares a for loop. Supports C-style and for-in iteration over arrays and ranges.",
      "for (int i = 0; i < 10; i++) { println(i); };\n\nint[5] arr = [1,2,3,4,5];\nfor (int x in arr) { println(x); };\n\nfor (int x in 0..10) { println(x); };\n" },

    // ---- G ----

    { "global",
      "Declares a variable at global scope regardless of where the declaration appears.",
      "def foo() -> void\n{\n    global int counter;\n    counter++;\n    return;\n};\n" },

    { "goto",
      "Unconditional jump to a label.",
      "def foo() -> int\n{\nlabel start:\n    if (x < 10) { x++; goto start; };\n    return x;\n};\n" },

    // ---- H ----

    { "heap",
      "Allocates a variable on the heap. The variable becomes a pointer of the declared type.",
      "heap int x = 10;\nprintln(*x);\n" },

    // ---- I ----

    { "if",
      "Conditional branch. Body must be wrapped in a block.",
      "if (x > 0)\n{\n    println(\"positive\");\n}\nelif (x == 0)\n{\n    println(\"zero\");\n}\nelse\n{\n    println(\"negative\");\n};\n" },

    { "in",
      "Used in for-in loops to specify the iterable, or as a membership test operator.",
      "int[5] arr = [1,2,3,4,5];\nfor (int x in arr) { println(x); };\n\nif (3 in arr) { println(\"found\"); };\n" },

    { "int",
      "32-bit signed integer type.",
      "int x = 42;\nint y = -100;\n" },

    { "is",
      "Equality operator. Equivalent to ==.",
      "if (x is 5) { println(\"x is five\"); };\n" },

    // ---- J ----

    { "jump",
      "Jumps to a target address. Any integer value is treated as an address.",
      "jump @myFunc;\njump 0x1000;\n" },

    // ---- L ----

    { "label",
      "Declares a named jump target for goto.",
      "def foo() -> int\n{\nlabel start:\n    x++;\n    if (x < 10) { goto start; };\n    return x;\n};\n" },

    { "local",
      "Marks a variable as scope-local. It cannot be returned or passed to another function.",
      "def bar() -> void\n{\n    local int x = 10;\n    return;\n};\n" },

    { "long",
      "64-bit signed integer type.",
      "long x = 1000000000000l;\n" },

    // ---- M ----

    { "macro",
      "Named parameterized expression that replaces itself with its body at the call site.",
      "#import <standard.fx>;\n\nusing standard::io::console;\n\nmacro factorial(n)\n{\n    n * factorial(--n) if (n > 1) else 1\n};\n\ndef main() -> int\n{\n    int x = factorial(5);\n    println(x);  // 120\n    return 0;\n};\n" },

    // ---- N ----

    { "namespace",
      "Declares a named scope for organizing code.",
      "namespace math\n{\n    def square(int x) -> int { return x * x; };\n    def cube(int x)   -> int { return x * x * x; };\n};\n\nusing math;\nprintln(square(4));\n" },

    { "noinit",
      "Suppresses zero-initialization of a variable. The variable's value is undefined until assigned.",
      "int x = noinit;\nx = 42;\n" },

    { "noreturn",
      "Marks a point in code as unreachable. Emits LLVM unreachable.",
      "def panic(byte* msg) -> void\n{\n    println(msg);\n    noreturn;\n};\n" },

    { "not",
      "Logical NOT operator. Equivalent to !. Can also perform 'not using' to remove a namespace.",
      "if (not flag) { println(\"flag is false\"); };\n\nnot using standard::math::calculus;\n" },

    // ---- O ----

    { "object",
      "Declares an object type with methods and state. Must implement __init, __expr, and __exit.",
      "object Point\n{\n    int x, y;\n\n    def __init(int x, int y) -> this\n    {\n        this.x = x;\n        this.y = y;\n        return this;\n    };\n\n    def __expr() -> Point* { return this; };\n    def __exit() -> void   { (void)this; };\n};\n" },

    { "operator",
      "Defines a custom infix operator using symbols or an identifier.",
      "operator (int L, int R) [+++] -> int\n{\n    return ++L + ++R;\n};\n\ndef main() -> int\n{\n    println(5 +++ 3);  // 10\n    return 0;\n};\n" },

    { "or",
      "Logical OR operator. Equivalent to |.",
      "if (x == 0 or y == 0) { println(\"at least one is zero\"); };\n" },

    // ---- P ----

    { "private",
      "Restricts member access to within the object.",
      "object Foo\n{\n    private\n    {\n        int secret;\n    };\n};\n" },

    { "public",
      "Explicitly marks members as externally accessible. Object members are public by default.",
      "object Foo\n{\n    public\n    {\n        int value;\n    };\n};\n" },

    // ---- R ----

    { "register",
      "Hints that a variable should be stored in a CPU register.",
      "register int i;\nfor (i = 0; i < 1000; i++) { };\n" },

    { "return",
      "Returns a value from a function. In strictly-recursive functions, re-enters the function.",
      "def add(int x, int y) -> int\n{\n    return x + y;\n};\n" },

    // ---- S ----

    { "signed",
      "Declares a signed data type. Types are unsigned by default in Flux.",
      "signed data{32} as i32;\nsigned data{64} as i64;\n" },

    { "singinit",
      "Declares a singleton variable initialized only once across all calls to the enclosing function.",
      "def counter() -> int\n{\n    singinit int count;\n    count++;\n    return count;\n};\n" },

    { "sizeof",
      "Returns the size of a type or value in bits.",
      "int bits  = sizeof(int);\nint bytes = sizeof(int) / sizeof(byte);\n" },

    { "stack",
      "Explicitly marks a variable as stack allocated. This is the default for all non-heap allocations.",
      "stack int x = 10;  // identical to: int x = 10;\n" },

    { "stdcall",
      "Declares a function using the stdcall calling convention. Used in place of def.",
      "stdcall foo(int x) -> int { return x; };\n" },

    { "struct",
      "Declares a packed data structure.",
      "struct Point { int x, y; };\n\nPoint p {x = 10, y = 20};\nprintln(p.x);\nprintln(p.y);\n" },

    { "switch",
      "Multi-branch conditional on a value. No fallthrough between cases.",
      "switch (x)\n{\n    case (1) { println(\"one\");   }\n    case (2) { println(\"two\");   }\n    default  { println(\"other\"); };\n};\n" },

    // ---- T ----

    { "this",
      "Refers to the current object instance's pointer inside an object method.",
      "object Counter\n{\n    int value;\n\n    def __init(int start) -> this\n    {\n        this.value = start;\n        return this;\n    };\n\n    def increment() -> void { this.value++; return; };\n    def __expr()    -> Counter* { return this; };\n    def __exit()    -> void { (void)this; };\n};\n" },

    { "thiscall",
      "Declares a function using the thiscall calling convention. Used in place of def.",
      "thiscall foo(int x) -> int { return x; };\n" },

    { "throw",
      "Throws an exception value to be caught by an enclosing catch block.",
      "try\n{\n    throw(42);\n}\ncatch (int e)\n{\n    println(f\"Caught: {e}\");\n};\n" },

    { "trait",
      "Declares a contract (interface) that an object type must implement.",
      "trait Drawable\n{\n    def draw() -> void;\n    def resize(float s) -> void;\n};\n" },

    { "true",
      "Boolean literal true. Equivalent to 1.",
      "bool flag = true;\nwhile (true) { break; };\n" },

    { "try",
      "Begins a block that can throw exceptions, to be handled by a following catch block.",
      "try\n{\n    int result = riskyOp();\n    println(result);\n}\ncatch (int e)\n{\n    println(f\"Error: {e}\");\n};\n" },

    // ---- U ----

    { "uint",
      "32-bit unsigned integer type.",
      "uint x = 4294967295u;\n" },

    { "ulong",
      "64-bit unsigned integer type.",
      "ulong x = 18446744073709551615ul;\n" },

    { "union",
      "Declares a type where all members share the same memory region.",
      "union Data { int i; float f; };\n\nData d;\nd.i = 42;\nprintln(d.f);\n" },

    { "unsigned",
      "Declares an unsigned data type. All data{} types are unsigned by default.",
      "unsigned data{32} as u32;\nunsigned data{8}  as u8;\n" },

    { "using",
      "Brings a namespace into the current scope.",
      "#import <standard.fx>;\n\nusing standard::io::console;\n\nprintln(\"Hello!\");\n" },

    // ---- V ----

    { "vectorcall",
      "Declares a function using the vectorcall calling convention. Used in place of def.",
      "vectorcall foo(int x) -> int { return x; };\n" },

    { "void",
      "Represents the absence of a value. (void*)void is a null pointer.",
      "def foo() -> void { return; };\n\nvoid* p = (void*)void;\n" },

    { "volatile",
      "Prevents the compiler from optimizing accesses to a variable or asm block.",
      "volatile int mmio = 0;\n\nvolatile asm\n{\n    nop\n};\n" },

    // ---- W ----

    { "while",
      "Declares a while loop. Condition is checked before each iteration.",
      "int x = 10;\nwhile (x > 0)\n{\n    println(x);\n    x--;\n};\n" },

    // ---- X ----

    { "xor",
      "Bitwise XOR operator. Note: ^ is exponentiation in Flux, not XOR.",
      "int a = 0b1010;\nint b = 0b1100;\nint r = a xor b;  // 0b0110 = 6\nprintln(r);\n" }
];
