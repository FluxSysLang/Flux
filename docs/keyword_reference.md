# Flux Keyword Reference

Flux keywords are reserved, and cnanot be used as identifiers.  
This means you cannot do `int data;`, this is illegal.

The goal of this document is to be like an old school language help, which provides a unique example usage of each keyword.  

Not all keywords have examples just yet.

---

**`alignof`**
Returns the alignment requirement of a type in bits.
```
#import <standard.fx>;

using standard::io::console;

def main() -> int
{
    data{32:64} as u32_a64; // Unsigned 32-bit int, 64-bit aligned.

    u32_a64 trees = 200;

    while (trees-- > alignof(u32_a64))
    {
        println(f"Chopping a tree! {trees--} left!");
    };

    return 0;
};
```
Last 3 lines of output:
```
Chopping a tree! 69 left!
Chopping a tree! 67 left!
Chopping a tree! 65 left!
```

---

**`and`**
Logical AND operator. Equivalent to `&`.
```
#import <standard.fx>;

using standard::io::console;

struct Point2D
{
    int x, y;
};

def main() -> int
{
    Point2D a = {20, 50};
    Point2D b = {10, 100};

    float x = a.x / b.x,
          y = a.y / b.y;

    if (x > 0f and y > 0f)
    {
        println(x);
        println(y);
    }
    else
    {
        println("Integer division of floats will fail. Convert beforehand.");
    };

    x = float(a.x) / float(b.x);
    y = float(a.y) / float(b.y);

    if (x > 0f and y > 0f)
    {
        println(x);
        println(y);
    };

    return 0;
};
```

---

**`as`**
Creates a type alias.
```
unsigned data{32} as u32;
```

---

**`asm`**
Inline assembly block. Use `volatile` to instruct the compiler to not touch your assembly or attempt to optimize it. Flux uses AT&T style ASM and blocks are followed by `inputs : outputs : clobbers`, 
```
#ifdef __ARCH_ARM64__
            def mac_print(byte* msg, int x) -> void
            {
                volatile asm
                {
                    mov x0, #1
                    mov x1, $0
                    mov x2, $1
                    movz x16, #0x4
                    svc #0x80
                } : : "r"(msg), "r"(count) : "x0","x1","x2","x16","memory";
                return;
            };
#endif; // ARCH ARM
```

---

**`assert`**
Halts compilation or execution if condition is false.
```
assert(x > 0);
```

---

**`auto`**
Infers the type of a variable from its initializer.
```
auto x = 5;   // x is a char, if greater than char it promotes to uint, if greater than int max value, it is a ulong. Not recommended.
```
`auto` will attempt within reason, to infer the integer or floating type, and will be a built-in dependent on its value.
- It will always attempt to coerce to the smallest width type.
The example `auto x = 5;` makes `x` a `char`.

---

**`bool`**
Boolean type. Values are `true` or `false`. Default is `false` due to zero initialization.  
Any integer type, bitwise respective, can be coerced to a bool in context so long as it the value is 1 or 0.  
`float` and `double` types that precisely equal `1.0` and `0.0` will evaluate as `true` and `false` respectively.
```
bool flag = true;
```

---

**`break`**
Exits the nearest enclosing loop or switch.
```
while (true) { break; };
```

---

**`byte`**
Single byte type. Width configurable via `__BYTE_WIDTH__`, default 8 bits.
```
byte b = 0xFF;
```

---

**`case`**
Defines a branch in a switch statement. Does not require semicolon block termination.
```
switch (x) { case (1) { ... } default {}; };
```

---

**`catch`**
Handles a thrown exception.
```
try { ... } catch (int e) { ... };
```

---

**`cdecl`**
Declares a function using the cdecl calling convention. Used in place of `def`.
```
cdecl foo(int x) -> int { return x; };
```

---

**`char`**
Character type. Guaranteed 8 bits.
```
char c = 'H';
```

---

**`comptime`**  
Compile-time programming is done in `comptime` blocks.  
Everything inside is evaluated by the Flux Virtual Machine (FVM).  

You can write any Flux code inside a `comptime` block. There are no restrictions on I/O. You may even perform networking if you really wished.  
FFI is also possible, as well as inline ASM execution supported by [Keystone Engine](https://github.com/keystone-engine/keystone) (x86-64 only for now). 

The FVM has its own pseudo assembly language. All Flux inside turns into FVM assembly, which it then executes.  You can dump your `comptime` assembly to a file using `compiler.fvm.dump("path/to/yourdump.fvm);`  
It is plaintext, not bytecode, so you can read and inspect it.  
It can then independently be ran with `fvm.py yourdump.fvm`
```
#import <standard.fx>;

using standard::io::console;

enum AnyTag { INT, FLOAT, LONG, BOOL };

union Any
{
    int   ival;
    float fval;
    long  lval;
    bool  bval;
} # AnyTag;

comptime
{
    byte*[] types  = ["int", "float", "long", "bool"],
            tags   = ["INT", "FLOAT", "LONG", "BOOL"],
            fields = ["ival", "fval", "lval", "bval"];
    int     count  = 4;
    byte* T,
          TAG,
          FIELD;

    for (int idx = 0; idx < count; idx++)
    {
        T     = types[idx];
        TAG   = tags[idx];
        FIELD = fields[idx];

        emitflux
        {
            def ~$f"wrap_{T}"(~$f"{T}" x) -> Any
            {
                Any a;
                a.# = AnyTag.~$f"{TAG}";
                a.~$f"{FIELD}" = x;
                return a;
            };

            def ~$f"unwrap_{T}"(Any a) -> ~$f"{T}"
            {
                return a.~$f"{FIELD}";
            };

            def ~$f"is_{T}"(Any a) -> bool
            {
                return a.# == AnyTag.~$f"{TAG}";
            };
        };
    };
};

def main() -> int
{
    Any a = wrap_int(42);
    Any b = wrap_float(3.14f);
    Any c = wrap_long(9999999l);

    if (is_int(a))   { println(f"int:   {unwrap_int(a)}"); };
    if (is_float(b)) { println(f"float: {unwrap_float(b)}"); };
    if (is_long(c))  { println(f"long:  {unwrap_long(c)}"); };

    return 0;
};

```

You can also use FVM assembly directly inside `comptime` blocks with `fluxvm {}`.

`comptime` blocks can also be named, and jumped to with `goto` like a `label`, allowing for loop behavior:
```
comptime ABC
{
    compiler.io.console.println("ABC");
    goto XYZ;
};

comptime XYZ
{
    compiler.io.console.println("XYZ");
    goto ABC;
};
```

---

**`const`**
Marks a variable as immutable after initialization.
```
const int x = 10;
```

---

**`continue`**
Skips to the next iteration of the nearest enclosing loop.
```
for (int i; i < 10; i++) { if (i == 5) { continue; }; };
```

---

**`data`**
Declares a raw bit-width type. Can be signed or unsigned.
```
unsigned data{32} as u32;
signed data{64} as i64;
```

---

**`def`**
Declares or defines a function. `fastcall` calling convention by default. Configurable.
```
def add(int x, int y) -> int { return x + y; };
```

---

**`default`**
Fallback branch in a switch statement. Requires semicolon block termination.
```
switch (x) { case (1) { ... } default { ... }; };
```

---

**`deprecate`**
Marks a namespace, object member, or function signature as deprecated. Emits an error on use.  
Applied to the declaration, not the definition.
```
deprecate oldFunc() -> void;
deprecate oldLib;    // Namespace will be identified
deprecate oldMember; // Type will be identified by definition
```

---

**`do`**
Enter a `do` loop.
```
do { x++; };
```
Adding `while`
```
do { x++; } while (x < 10);
```

---

**`double`**
64-bit floating point type.
```
double pi = 3.1415926585;
```

---

**`elif`**
Else-if branch in a conditional chain.
```
if (x == 1) { ... } elif (x == 2) { ... } else { ... };
```

---

**`else`**
Fallback branch of an `if` statement.
```
if (x > 0) { ... } else { ... };
```

---

**`emitflux`**  
Emit Flux source code at the scope of the `comptime` block this `emitflux` is found in.  
```
#import <standard.fx>;

using standard::io::console;

enum State { Idle, Running, Paused, Stopped };

comptime
{
    int[] trans_from = [0, 1, 2, 1];
    int[] trans_to   = [1, 2, 1, 3];
    int   tcount     = 4;

    emitflux
    {
        def state_name(int s) -> byte*
        {
            if (s == 0) { return "Idle"; };
            if (s == 1) { return "Running"; };
            if (s == 2) { return "Paused"; };
            if (s == 3) { return "Stopped"; };
            return "Unknown";
        };
    };

    for (int tidx = 0; tidx < tcount; tidx++)
    {
        emitflux
        {
            comptime
            {
                emitflux
                {
                    def ~$i"can_trans_{}_{}":{trans_from[tidx];trans_to[tidx];}() -> bool { return true; };
                };
            };
        };
    };

    emitflux
    {
        def transition(int fx, int to) -> int
        {
            if (fx == 0 & to == 1 & can_trans_0_1()) { return to; };
            if (fx == 1 & to == 2 & can_trans_1_2()) { return to; };
            if (fx == 2 & to == 1 & can_trans_2_1()) { return to; };
            if (fx == 1 & to == 3 & can_trans_1_3()) { return to; };
            println(f"Invalid: {fx}:{state_name(fx)} -> {to}:{state_name(to)}");
            return fx;
        };
    };
};

def main() -> int
{
    int state = 0;

    println(f"Initial: {state_name(state)}");

    state = transition(state, 1);
    println(f"Start:   {state_name(state)}");

    state = transition(state, 2);
    println(f"Pause:   {state_name(state)}");

    state = transition(state, 3);
    println(f"Invalid: {state_name(state)}");

    state = transition(state, 1);
    println(f"Resume:  {state_name(state)}");

    state = transition(state, 3);
    println(f"Stop:    {state_name(state)}");

    return 0;
};

```

---

**`enum`**
Declares an enumeration of named integer constants.
```
enum Color { RED, GREEN, BLUE };

Color c;
```

---

**`export`:
Define a function as external for linkage. Used when creating libraries or to allow a function to be   
seen from outside the program's compilation unit.  
Only definitions are used with `export`.
```
export
{
    def !!foo() -> int
    {
        int a = 1, b = 10;
        int[10] x = [y for (int y in a..b)];
        return x[5];
    };
};
```

---

**`extern`**:
External FFI - reference a function from a library.
Only prototypes and variable declarations are used with `extern`.
```
extern
{
    def !!foo() -> int;
    int some_external_int;
};
```

---

`extern` and `export` are mutually exclusive, you cannot do:
`extern export { ... };` or `export extern def ...;`

---

**`escape`**
Exits a strictly-recursive function and returns a value up the call chain. Every `return` in a strictly-recursive function re-enters itself; `escape` is the only true exit.  
A strictly-recursive function is defined with a recurse arrow `<~` in its signature instead of a return arrow `->`.
```
def factorial <~ int (int n, int acc)
{
    if (n <= 1) { escape acc; };
    return factorial(n - 1, acc * n);
};
```

---

**`false`**
Boolean literal false. Equivalent to `0`.
```
bool flag;
```

---

**`fastcall`**
Declares a function using the fastcall calling convention. Used in place of `def`.
```
fastcall foo(int x) -> int { return x; };
```

---

**`float`**
32-bit floating point type.
```
float x = 3.14159;
```

---

**`fluxvm`**  
Inline Flux VM assembly can be done at `comptime` and can be exported for standalone execution (so long as any code isn't platform specific).
```
comptime
{
    int x = 5;

    fluxvm
    {
        LOCAL_GET x
        PUSH 10
        ADD
        LOCAL_SET x
    };

    compiler.io.console.print(f"FluxVM modified int x = {x}\n");
};
```
Result:
```
FluxVM modified int x = 15
```

---

**`for`**
Declares a for loop. Supports both C-style and for-in iteration.
```
for (int i; i < 10; i++) { ... };
for (int x in arr) { ... };
```

---

**`global`**
Declares a variable at global scope regardless of where it appears.
```
global int counter;
```

---

**`goto`**
Unconditional jump to a `label`.
```
goto myLabel;
```

---

**`heap`**
Allocates a variable on the heap explicitly.
```
heap int x = 10;
```
This calls `fmalloc(sizeof(T))` where `T` is the type. `x` is a pointer of type `T`.  
It is **not** the same as `int* x = @10;`, as this is a stack-allocated pointer & value.

---

**`if`**
Conditional branch. Single-statements must be wrapped in a block.
```
if (x > 0) { ... };
```

---

**`in`**
Used in for-in loops to specify the iterable.
```
for (int x in arr) { ... };
```

---

**`int`**
32-bit signed integer type.
```
int x = 42;
```

---

**`is`**
Equivalent to `==`.
```
if (x is 5) { ... };
```

---

**`jump`**
Jump to a target address. Any integer value will be treated as an address.

A jump to an address with no executable memory will cause a crash.
```
jump 0;

jump @func;
```

---

**`label`**
Declares a jump target for `goto`.
```
label myLabel:
```
Use like:
```
def foo() -> int
{
label j1:
    // code
    goto j3;
label j2:
    // code
    goto final;
label j3:
    // code
    goto j2;
label final:
    // return
};
```

---

**`local`**
Explicitly marks a variable as local scope. Cannot escape its scope via return or by being passed to a function.
```
local int x = 10;
```
Example:
```
def foo(int x) -> int { return x; };

def baz() -> int { local int z = 50; return z; }; // Compile error, z cannot leave function.

def bar() -> void
{
    local int x = 10;
    int y = foo(x); // Compile error, x cannot leave scope.
}
```

---

**`long`**
64-bit signed integer type.
```
long x = 1000000000000;
```

---

**`macro`**
Macros are named and parameterized expressions that replace themselves with their body in place.  
```
#import <standard.fx>;

using standard::io::console;

macro factorial(n)
{
    n * factorial(--n) if (n > 1) else 1
};

def main() -> int
{
    int x = factorial(5);
    println(x);

    return 0;
};
```

---

**`namespace`**
Declares a named scope for organizing code.
```
namespace math { def square(int x) -> int { return x * x; }; };
```

---

**`noinit`**
Suppresses zero-initialization of a variable.
```
int x = noinit;
```

---

**`noreturn`**
Marks a point in code as unreachable. Emits LLVM `unreachable`.
```
noreturn;
```

---

**`not`**
Logical NOT operator. Equivalent to `!`.
```
if (not flag) { ... };
```
Can also perform `not using`:
```
not using standard::math::calculus;
```

---

**`object`**
Declares an object type with methods and state.
```
object Point
{
    int x, y;

    def __init(int x, int y) -> this
    {
        this.x = x;
        this.y = y;
        return this;
    };
    
    def __expr() -> Point* // or whatever you want Point to represent
    {
        return this;
    };

    def __exit() -> void { (void)this; };
};
```

Objects must declare `__init`, `__expr`, and `__exit`.

### `__expr` built in method
`__init` and `__exit` are obvious ones, they're the constructor and destructor.  
The job of `__expr` is different. When you want to use an object instance in an expression context, this function lets you define what is returned. Typically a good default is the type itself as a pointer, like `Point*`.  
You could also do:
```
def __expr() -> byte*
{
    return f"{this.x},{this.y}";
};
```

---

**`operator`**:
Define a custom infix operator. Can use symbols or an identifier as the operator.  
To overload a built-in operator, one of the operands **must not** be a built-in type, ie `int`, `float`, `byte`, etc.
```
#import <standard.fx>;

using standard::io::console;

// Custom operator +++
operator (int L, int R) [+++] -> int
{
    return ++L + ++R;
};

// Overload a built in operator
operator (int L, i16* R) [+] -> int
{
    i32 t = [R[0], R[1]];
    return L + t;
};


def main() -> int
{
    int    x = 12;
    i16[2] y = [0,55];
    int    z = x + y;
    
    print(z); print(); // 67

    print(5 +++ 3);    // 10
    return 0;
};
```

---

**`or`**
Logical OR operator. Equivalent to `|`.
```
if (x == 0 or y == 0) { ... };
```

---

**`private`**
Restricts member access to within the object. Members must be wrapped in a block.
```
object Foo
{
    private
    {
        int secret;
    };
};
```

---

**`public`**
Explicitly marks a member as externally accessible. Members must be wrapped in a block. Object members are public by default.
```
object Foo
{
    public
    {
        int value;
    };
};
```

---

**`register`**
Hints that a variable should be stored in a CPU register. Not enforced, but strongly hinted.
```
register int i;
```

---

**`return`**
Returns a value from a function. In strictly-recursive functions, re-enters the function.
```
return x + y;
```

---

**`signed`**
Declares a signed data type. Types are unsigned by default.
```
signed data{32} as i32;
```

---

**`singinit`**
Declares a singleton. Function-scoped variable that is initialized only once across all calls. If the compiler warns you of an in-loop allocation and you do not want to hoist it out of the loop, you should make it a singleton so it does not continually allocate stack slots.
```
singinit int count;
```

---

**`sizeof`**
Returns the size of a type or value in bits, never bytes. Divide by `sizeof(byte)` to get accurate byte widths.
```
sizeof(int)   // 32
```

---

**`stack`**
Explicitly marks a variable as stack allocated. This is default behavior and implicit in any non-heap allocation.
```
stack int x = 10;
```
Identical to:
```
int x = 10;
```

---

**`stdcall`**
Declares a function using the stdcall calling convention. Used in place of `def`.
```
stdcall foo(int x) -> int { return x; };
```

---

**`struct`**
Declares a packed data structure. Padding dependent on the alignment of the types within.
```
struct Point { int x, y; }; // 64 bits wide. This can pack into a long or any 64 bit wide type.
```

---

**`switch`**
Multi-branch conditional on a value.
```
switch (x) { case (1) { ... } default {}; };
```

---

**`this`**
Refers to the current object instance's pointer inside an object method.
```
def __init(int x) -> this { this.x = x; return this; };
```

---

**`thiscall`**
Declares a function using the thiscall calling convention. Used in place of `def`.
```
thiscall foo(int x) -> int { return x; };
```

---

**`throw`**
Throws an exception value.
```
throw(42);
```

---

**`trait`**
Declares a contract that an object must implement.
```
trait Drawable { def draw() -> void; };
```

---

**`true`**
Boolean literal true. Equivalent to `1`.
```
bool flag = true;
```

---

**`try`**
Begins a block that can throw exceptions.
```
try { ... } catch (int e) { ... };
```

---

**`uint`**
32-bit unsigned integer type.
```
uint x = 4294967295;
```

---

**`ulong`**
64-bit unsigned integer type.
```
ulong x = 18446744073709551615;
```

---

**`union`**
Declares a type where all members share the same memory.
```
union Data { int i; float f; };
```

---

**`unsigned`**
Declares an unsigned data type.
```
unsigned data{32} as u32;
```

---

**`using`**
Brings a namespace into the current scope.
```
using standard::io::console;
```

---

**`vectorcall`**
Declares a function using the vectorcall calling convention. Used in place of `def`.
```
vectorcall foo(int x) -> int { return x; };
```

---

**`void`**
Represents the absence of a value. Also used as a null pointer literal.
```
def foo() -> void { return; };
void* p = (void*)void; // (void*)0;
```

---

**`volatile`**
Prevents the compiler from optimizing accesses to a variable or assembly block. Use this when you have assembly you do not want modified at all through optimization. You may have desired side effects get removed by optimization, and `volatile` prevents that.
```
volatile int x = 0;
volatile asm { ... };
```

---

**`while`**
Declares a while loop.
```
while (x > 0) { x--; };
```

---

**`xor`**
Bitwise XOR operator. Note: `^` is exponentiation.
```
int result = a xor b;
```