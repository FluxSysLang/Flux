# Flux Effect System — In-Depth Reference

## What Effects Actually Are

Effects are labels. That is the whole truth of it. A function annotated
`# effect {Hook.Detour}` has been given the label `Hook.Detour`. The compiler
tracks that label and propagates it through the call graph. Nothing more happens
until something somewhere applies an operator that gives the label meaning in a
specific context.

This is the most important thing to understand about the system. The label is
the wire. The operators are the connectors. Connecting white to white through a
red cable is still white to white -- the color of the cable does not change what
is at either end. Labeling `fmalloc` with `Hook.Detour` does not make it unable
to allocate. It just means the call graph now carries that label upward. Whether
that means anything depends entirely on whether something else says it does.

The operators are what make effects meaningful. Without them, you have a rich
vocabulary for describing what code does, and nothing enforced. With them, you
have a compiler programming interface that can express real guarantees.

---

## The Labels

The built-in effect names are a taxonomy of behavioral facts about systems code.
They exist to give the operator expressions something precise to operate on.

### IO Family

```
IO              -- any external communication
IO.Console      -- stdin / stdout / stderr
IO.File         -- filesystem read or write
IO.Socket       -- network communication
IO.Pipe         -- IPC and named pipes
IO.Device       -- hardware device communication
IO.Serial       -- serial port
IO.USB          -- USB device IO
IO.GPU          -- GPU command submission
```

### Alloc Family

```
Alloc           -- any allocation
Alloc.Heap      -- standard heap allocation
Alloc.Pool      -- pool or arena allocator
Alloc.Stack     -- stack allocation
Alloc.Virtual   -- VirtualAlloc / mmap
Alloc.Shared    -- shared memory allocation
```

### Unsafe Family

```
Unsafe          -- any unsafe operation
Unsafe.Ptr      -- raw pointer dereference
Unsafe.Cast     -- unsafe type cast
Unsafe.ASM      -- inline assembly
Unsafe.FFI      -- calling foreign functions
Unsafe.Uninit   -- reading uninitialized memory
```

### Mem Family

```
Mem                 -- any memory operation
Mem.Read            -- any memory read
Mem.Read.Process    -- reading another process
Mem.Read.Kernel     -- kernel memory read
Mem.Read.Mapped     -- mapped file or shared memory read
Mem.Write           -- any memory write
Mem.Write.Process   -- writing another process
Mem.Write.Kernel    -- kernel memory write
Mem.Write.Exec      -- writing executable memory
Mem.Write.Mapped    -- mapped file or shared memory write
Mem.Exec            -- executing memory directly
Mem.Exec.JIT        -- JIT-compiled execution
Mem.Exec.Shellcode  -- raw shellcode execution
```

### Sync Family

```
Sync            -- any synchronization operation
Sync.Lock       -- mutex or critical section
Sync.Atomic     -- atomic operations
Sync.Signal     -- signals or events
Sync.Wait       -- blocking wait
```

### Crypto Family

```
Crypto          -- any cryptographic operation
Crypto.Hash     -- hashing
Crypto.Encrypt  -- encryption
Crypto.Decrypt  -- decryption
Crypto.Random   -- random number generation
Crypto.Key      -- key generation or management
```

### Process Family

```
Process             -- any process operation
Process.Spawn       -- creating processes
Process.Kill        -- terminating processes
Process.Inject      -- code injection
Process.Suspend     -- suspending or resuming threads
Process.Token       -- token or privilege manipulation
```

### Hook Family

```
Hook            -- any hooking operation
Hook.Detour     -- inline detour or trampoline
Hook.IAT        -- import address table hook
Hook.SSDT       -- SSDT hook (kernel)
Hook.Vtable     -- vtable hook
Hook.Exception  -- exception handler hook
```

### Privilege Family

```
Privilege           -- any privilege operation
Privilege.Elevate   -- privilege escalation
Privilege.Drop      -- privilege dropping
Privilege.Check     -- privilege checking
```

### Time Family

```
Time            -- any time-sensitive operation
Time.RealTime   -- hard real-time constraint
Time.Sleep      -- thread sleep or delay
Time.Timer      -- timer creation or management
```

### Anchor Labels

```
Pure    -- declared to have no side effects
Throw   -- can raise exceptions
```

These are still just labels. `Pure` on its own does not enforce anything. It is
the enforcement pass that checks `Pure`-labeled functions against `IO`, `Alloc`,
`Mem.Write`, and `Throw` that makes it meaningful.

---

## The Hierarchy

Effect names are organized into a parent-child hierarchy. This hierarchy is only
meaningful when an operator references it. Saying `!IO` excludes all `IO.*`
children not because of anything special about the name `IO`, but because the
`!` operator is defined to expand parent names to cover their children.

A label like `IO.Socket` is just a name. The fact that it is under `IO` in the
hierarchy only matters when an operator expression references `IO` -- then the
compiler knows to include `IO.Socket` in the expansion.

---

## The Operators

The operators are where the system becomes a compiler programming interface.
An operator applied to a label produces a rule the compiler enforces. Without
operators, labels are inert. With them, labels become policy.

### Unary Operators

**`*X` -- propagates**

Causes label X to travel upward through the call graph. Every caller of this
function inherits X in its transitive label set. Every caller's caller inherits
it too. Indefinitely.

```flux
def write_socket(byte* data) -> void # effect {*IO.Socket};
```

`IO.Socket` now travels up. On its own this means nothing is forbidden. It just
means callers carry the label. Something else has to say what carrying it means.

**`!X` -- excludes**

X must not appear in the transitive label set of this function. If the compiler
finds X anywhere reachable from here, it is a violation. This is what turns
labels into enforcement.

```flux
def rt_handler() -> void # effect {!Alloc & !IO};
```

Now the labels `Alloc` and `IO` and all their children are forbidden in the
entire call graph below this function. A callee that has `*Alloc.Heap` traveling
upward will cause a violation at that call site.

Without `!`, the labels travel freely. `!` is the connector that says this
label cannot cross this point.

**`~X` -- requires**

X must already be present in the label set when this function is called. The
function requires a pre-existing label as a condition of being called.

**`?X` -- weak propagation**

X propagates upward but can be suppressed by `^X` somewhere in the chain.

**`@X` -- attenuatable**

Marks X as capable of being stopped by `# attenuate`. This is the default for
most labels. Explicit `@X` makes that property visible in a composed expression.

**`!@X` -- permanent**

X cannot be stopped by any `# attenuate` anywhere in the program. The compiler
will reject any attempt to attenuate it. The label travels through any boundary.

This is what makes `Unsafe.*` different from other labels. Without `!@`, any
label can be stopped at an attenuation boundary. With `!@`, it cannot. The
operator is the difference, not anything special about the label name.

**`^X` -- suppresses**

Suppresses X even if something else in the expression would imply it.

```flux
effect SafeDetour { *Hook.Detour & ^Alloc };
```

`Hook.Detour` normally implies `Alloc` through certain chains. `^Alloc`
suppresses that implication in this context. Without the `^` operator, the
suppression does not exist.

**`..X` -- one level**

X propagates exactly one level up, then stops.

**`...X` -- indefinite**

X propagates indefinitely. The default. Explicit `...X` makes intent clear when
composing with `..X`.

**`<*X` -- caller only**

X reaches the immediate caller and no further.

### Binary Operators

**`X & Y` -- both**

Both X and Y must hold.

**`X | Y` -- at least one**

At least one of X or Y must hold.

**`X > Y` -- priority**

At conflict boundaries, X wins over Y. Without this operator, conflicts between
labels are undefined. With it, the programmer defines the resolution rule inside
the effect definition rather than leaving it to the compiler.

**`X -> Y` -- conditional**

If X is present then Y must also be present.

**`X ^| Y` -- exclusive or**

Exactly one of X or Y may be present. If both appear in the transitive label
set, the compiler reports a conflict. Without this operator, having both labels
present is not a conflict -- it is just two labels coexisting.

**`X <-> Y` -- mutual implication**

Both must be present or neither.

**`X <-> !Y` -- mutual exclusion with implication**

If X present then Y must be absent. If Y present then X must be absent.

---

## How Operators Give Labels Meaning

The same label means different things depending on what operators are applied
to it.

`IO.Socket` with no operator: a label in the call graph. The compiler knows it
is there. Nothing is forbidden or required.

`*IO.Socket` in an annotation: the label propagates upward. Still not enforcing
anything on its own.

`!IO.Socket` in an annotation: the label is now forbidden. Any callee carrying
`IO.Socket` upward causes a violation.

`!@IO.Socket` in an effect definition: the label cannot be attenuated. Any
`# attenuate {IO.Socket}` is rejected.

Same label, four different behaviors, depending entirely on which operator is
applied. The label is the wire. The operator is the connector.

---

## User-Defined Effects

User-defined effects are named operator expressions. They let you give a name
to a behavioral profile -- a combination of labels and operators -- then use
that name as a label in other expressions.

```flux
effect RealTime { !Alloc & !IO & !Throw };
```

`RealTime` is now a label. On its own it does nothing. But the expression stored
under that name contains three `!` operators. When the enforcement pass expands
`RealTime`, those operators take effect.

```flux
effect MemoryScanner
{
    *Mem.Read.Process &
    !Mem.Write &
    !Hook &
    !Process.Inject
};
```

The name `MemoryScanner` is inert. The `!` operators inside it are not. Applying
`MemoryScanner` to a function makes those exclusions real. Applying
`MemoryScanner` to `fmalloc` does not prevent `fmalloc` from allocating --
`fmalloc` has no context that says `!Alloc`. The exclusions only matter where
the enforcement pass is checking them against a call graph.

---

## Propagation

The compiler builds a call graph, seeds each function with its own declared
labels, and propagates them upward through fixed-point iteration. Unannotated
intermediate functions are transparent -- labels pass through them.

```flux
// No annotation. Labels pass through.
def mid() -> void* { -> heap_alloc(); };

// Alloc.Heap travels through mid() and arrives here.
// !Alloc says it cannot. Violation.
def strict() -> void # effect {!Alloc};
def strict() -> void { mid(); };
```

The violation is at the `mid()` call site. That is where the label enters
`strict()`'s transitive set and the `!` operator fires.

---

## Attenuation

`# attenuate {}` is a boundary operator that stops labels from propagating
further. It makes a containment guarantee: the listed labels do not escape
this function's interface to callers.

```flux
def log_event(byte* msg) -> void # attenuate {IO};
def log_event(byte* msg) -> void
{
    write_to_ring_buffer(msg);
};
```

`IO.Console` travels up through `write_to_ring_buffer` and reaches
`log_event`'s boundary. The `# attenuate {IO}` operator stops it. Callers do
not see `IO` in their transitive label set from this call.

Attenuation is precise or coarse:

- `# attenuate {IO}` stops `IO` and all `IO.*` children.
- `# attenuate {IO.Socket}` stops only `IO.Socket`. Other IO labels propagate.

A label marked `!@` cannot be attenuated. The `!@` operator already decided the
outcome. No boundary overrides it.

---

## Built-in Implications

Some labels have operator expressions pre-wired by the compiler based on what
those labels actually mean in reality.

| Label | Implied labels |
|-------|---------------|
| `Hook.Detour` | `Hook`, `Unsafe`, `Mem.Write.Exec` |
| `Hook.IAT` | `Hook`, `Mem.Write` |
| `Hook.SSDT` | `Hook`, `Privilege`, `Mem.Write.Kernel`, `Unsafe` |
| `Hook.Vtable` | `Hook`, `Mem.Write` |
| `Process.Inject` | `Process`, `Alloc.Virtual`, `Mem.Write.Exec`, `Hook`, `Unsafe` |
| `Crypto.Key` | `Crypto` |

An inline detour writes a JMP into executable memory. So `Hook.Detour` implies
`Mem.Write.Exec`. Code injection allocates virtual memory and writes executable
content. So `Process.Inject` implies `Alloc.Virtual` and `Mem.Write.Exec`. The
compiler encodes these relationships so you do not redeclare them everywhere.

---

## Primitive Label Sources

Some constructs introduce labels automatically from the code itself.

| Construct | Label |
|-----------|-------|
| Heap allocation | `Alloc.Heap` |
| Inline `asm` block | `Unsafe.ASM` |
| Raw pointer dereference | `Unsafe.Ptr` |
| `throw` | `Throw` |
| Unsafe cast | `Unsafe.Cast` |
| FFI call | `Unsafe.FFI` |

A function with an `asm` block carries `Unsafe.ASM` whether or not it is
annotated. These are seeded from the source itself.

---

## Annotation Syntax

**`# effect {}`** -- declares labels this function introduces. Goes on the
prototype. Definitions inherit it.

```flux
def hook_fn(void* target) -> void # effect {*Hook.Detour};
def hook_fn(void* target) -> void { ... };
```

**`# attenuate {}`** -- declares labels stopped at this function's boundary.

```flux
def buffered_write(byte* msg) -> void # attenuate {IO};
def buffered_write(byte* msg) -> void { ... };
```

Both may appear on the same function in any order, after contracts:

```flux
def foo() -> void : Contract # effect {*Alloc.Heap} # attenuate {IO};
def foo() -> void { ... };
```

Tags work in multi-prototype lists:

```flux
def read_mem(void* addr) -> byte # effect {*Mem.Read.Process},
    write_mem(void* addr, byte v) -> void # effect {*Mem.Write.Process};
```

---

## Conflict Detection

`^|` and `<->` operators inside an effect definition declare constraints on the
transitive label set of any function using that effect. Without those operators,
having multiple labels present is never a conflict -- labels coexist silently.

```flux
effect ExclusiveIO { IO.Console ^| IO.File };

// Conflict: both IO.Console and IO.File present.
def bad() -> void # effect {ExclusiveIO};
def bad() -> void { write_console("x\0"); read_file("y\0"); };
```

Without `^|` in `ExclusiveIO`, no conflict. The `^|` operator is what makes it
one.

---

## Pure Enforcement

`Pure` is checked by the enforcement pass against the four anchor violations:
`IO`, `Alloc`, `Mem.Write`, `Throw`. If any of those -- or any child of them --
appears in the transitive label set, violation. If the set is clean, the proof
passes silently.

This is not special behavior for the name `Pure`. It is the enforcement pass
applying a known definition to check the label set.

---

## Compiler Modes

| Flag | Behavior |
|------|----------|
| *(default)* | Transparent -- labels stored and propagated, nothing enforced |
| `--effects-warn` | Violations are warnings, compilation continues |
| `--effects` | Violations are errors, compilation aborted |

Default is transparent so existing code compiles unchanged. Enforcement is
opt-in.

---

## Zero Runtime Cost

Effects are erased before codegen. The binary is identical with or without
annotations. Labels and operators exist only during semantic analysis. They
produce verified knowledge about the program and then disappear.

The labels are inert. The operators make them meaningful. The compiler is the
engine that runs the rules.