# Flux Standard Library Documentation

Version: 2.3
Date: June 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Library Structure](#library-structure)
3. [Core Modules](#core-modules)
   - [standard.fx](#standardfx)
   - [types.fx](#typesfx)
   - [sys.fx](#sysfx)
   - [io.fx](#iofx)
   - [math.fx](#mathfx)
4. [Runtime System](#runtime-system)
   - [runtime.fx](#runtimefx)
   - [memory.fx](#memoryfx)
   - [allocators.fx](#allocatorsfx)
   - [ffifio.fx](#ffifiofx)
5. [String Utilities](#string-utilities)
   - [string_utilities.fx](#string_utilitiesfx)
   - [string_object_raw.fx](#string_object_rawfx)
6. [Collections Library](#collections-library)
   - [collections.fx](#collectionsfx)
7. [Vectors Library](#vectors-library)
   - [vectors.fx](#vectorsfx)
8. [Extended Libraries](#extended-libraries)
   - [atomics.fx](#atomicsfx)
   - [threading.fx](#threadingfx)
   - [timing.fx](#timingfx)
   - [random.fx](#randomfx)
   - [cryptography.fx](#cryptographyfx)
   - [crc32.fx](#crc32fx)
   - [bigint.fx](#bigintfx)
   - [decimal.fx](#decimalfx)
   - [net_windows.fx / socket_object_raw.fx](#net_windowsfx--socket_object_rawfx)
   - [uuid.fx](#uuidfx)
   - [sharedmemory.fx](#sharedmemoryfx)
   - [format.fx](#formatfx)
   - [console.fx](#consolefx)
   - [graphing.fx](#graphingfx)
   - [oglgraphing.fx](#oglgraphingfx)
   - [opengl.fx](#openglfx)
   - [windows.fx](#windowsfx)
   - [wasapi.fx](#wasapifx)
   - [detour.fx](#detourfx)
   - [operators.fx](#operatorsfx)
   - [dotenv.fx](#dotenvfx)
   - [json.fx](#jsonfx)
   - [matrices.fx](#matricesfx)
   - [fourier.fx](#fourierfx)
   - [physics.fx](#physicsfx)
   - [tensors.fx](#tensorsfx)
   - [autograd.fx](#autogradfx)
   - [raytracing.fx](#raytracingfx)
   - [raycasting.fx](#raycastingfx)
   - [datautils.fx](#datautilsfx)
   - [datetime.fx](#datetimefx)
   - [xml.fx](#xmlfx)
   - [csv.fx](#csvfx)
   - [encodings.fx](#encodingsfx)
9. [Security](#security)
   - [shadowstack.fx](#shadowstackfx)
10. [Import Guidelines](#import-guidelines)
11. [Platform Support](#platform-support)

---

## Overview

The Flux Standard Library provides a comprehensive set of tools and utilities for systems programming, designed to work across Windows, Linux, and macOS platforms.

### Design Philosophy

- **Cross-platform compatibility**: Supports Windows, Linux, and macOS through conditional compilation
- **Low-level control**: Direct access to system calls and memory management
- **Type safety**: Comprehensive type system with platform-specific definitions
- **Minimal dependencies**: Core functionality with optional FFI support
- **Performance-oriented**: Assembly-level optimizations where needed

---

## Library Structure

```
stdlib/
  `----/ standard.fx              # Main entry point
  `----/runtime/runtime.fx        # Runtime initialization and entry point
  `----/ types.fx                 # Type definitions and utilities
  `----/ sys.fx                   # OS detection
  `----/ io.fx                    # Input/output operations
  `----/ math.fx                  # Mathematical functions
  `----/runtime/memory.fx         # Memory management
  `----/runtime/allocators.fx     # stdheap/stdstack/stdpool/stdarena/stdring allocators
  `----/runtime/ffifio.fx         # FFI-based file I/O (C runtime)
  `----/ string_utilities.fx      # String manipulation functions
  `----/ string_object_raw.fx     # String object implementation
  `----/ file_object_raw.fx       # File object implementation
  `----/ socket_object_raw.fx     # Socket object + Winsock FFI (standard::sockets)
  `----/ collections.fx           # Dynamic data structures (Array, HashMap, HashMapInt,
  `----/                          #   LinkedList, Stack, Queue, Deque, RingBuffer,
  `----/                          #   HashSet, HashSetInt, BinarySearchTree, MinHeap)
  `----/ vectors.fx               # 3D/4D vector mathematics
  `----/runtime/atomics.fx        # Atomic operations
  `----/runtime/threading.fx      # Threads, mutexes, condition variables
  `----/runtime/timing.fx         # High-resolution timers
  `----/ random.fx                # Random number generation
  `----/ cryptography.fx          # SHA-256, MD5, AES
  `----/ crc32.fx                 # CRC32 (IEEE 802.3, reflected poly)
  `----/ bigint.fx                # Arbitrary-precision integers
  `----/ decimal.fx               # Arbitrary-precision decimals
  `----/ net_windows.fx           # Winsock2 glue; full networking in socket_object_raw.fx
  `----/ uuid.fx                  # UUID generation (v1, v4, v7)
  `----/runtime/sharedmemory.fx   # Named shared memory regions
  `----/ format.fx                # ANSI color and text formatting
  `----/ console.fx               # TUI cursor and color control
  `----/ graphing.fx              # 2D/3D ASCII graphing
  `----/ oglgraphing.fx           # OpenGL-backed 2D/3D graphing
  `----/ opengl.fx                # OpenGL context and rendering helpers
  `----/ windows.fx               # Win32 window and GDI wrapper
  `----/ wasapi.fx                # WASAPI loopback audio capture
  `----/ detour.fx                # x86-64 inline hook / detour
  `----/ operators.fx             # Extended operator utilities
  `----/ dotenv.fx                # .env file loader (cross-platform)
  `----/ json.fx                  # JSON parse, build, and serialize library
  `----/ matrices.fx              # Mat3/Mat4/Mat5 matrix math
  `----/ fourier.fx               # DFT and FFT (Cooley-Tukey)
  `----/ physics.fx               # Rigid body + soft body physics engine
  `----/ tensors.fx               # N-dimensional tensor library
  `----/ autograd.fx              # Tape-based reverse-mode automatic differentiation
  `----/ raytracing.fx            # Physically-based path tracer
  `----/ raycasting.fx            # 2.5D tile raycaster (Wolfenstein-style)
  `----/ datautils.fx             # Low-level byte writer utilities
  `----/ datetime.fx              # Calendar date/time, duration, ISO 8601 parsing/formatting
  `----/ xml.fx                   # XML parse, build, and serialize (arena-backed)
  `----/ csv.fx                   # CSV parse, write, and cleanup (RFC 4180)
  `----/ encoding.fx              # Hex, Base32, Base58, Base64, Base64URL, URL percent-encoding
  `----/runtime/shadowstack.fx    # Opt-in shadow stack protection (Windows x86-64)
```

---

## Core Modules

### standard.fx

**Purpose**: Main entry point for the Flux Standard Library

**Usage**:
```flux
#import <standard.fx>;
```

**Description**:  
The `standard.fx` file serves as the primary import point for applications using the Flux Standard Library. It defines preprocessor guards and unconditionally imports `runtime.fx`, which pulls in the full runtime chain.

**Features**:
- Defines `FLUX_STANDARD` preprocessor constant
- Imports `runtime.fx` (which in turn imports `types.fx`, `memory.fx`, `allocators.fx`, `sys.fx`, `io.fx`, `ffifio.fx`, and the raw builtins)
- Provides the stable import surface for all Flux programs

---

### types.fx

**Purpose**: Comprehensive type system definitions and utilities

**Namespace**: `standard::types`

**Guard macro**: `FLUX_STANDARD_TYPES`

#### Type Definitions

##### Primitive Types

| Type Alias | Definition | Description |
|------------|------------|-------------|
| `nybble` | `unsigned data{4}` | 4-bit unsigned integer |
| `noopstr` | `byte[]` | Null-terminated byte string |
| `u16` | `unsigned data{16}` | 16-bit unsigned integer |
| `u32` | `unsigned data{32}` | 32-bit unsigned integer |
| `u64` | `unsigned data{64}` | 64-bit unsigned integer |
| `i8` | `signed data{8}` | 8-bit signed integer |
| `i16` | `signed data{16}` | 16-bit signed integer |
| `i32` | `signed data{32}` | 32-bit signed integer |
| `i64` | `signed data{64}` | 64-bit signed integer |

##### Pointer Types

| Type | Definition | Description |
|------|------------|-------------|
| `byte_ptr` | `byte*` | Pointer to byte |
| `i32_ptr` | `i32*` | Pointer to 32-bit signed integer |
| `i64_ptr` | `i64*` | Pointer to 64-bit signed integer |
| `void_ptr` | `void*` | Generic pointer |
| `noopstr_ptr` | `noopstr*` | Pointer to string |

##### Platform-Specific Types

**x86_64 and ARM64**:
```flux
intptr    // i64* - Pointer-sized signed integer
uintptr   // u64* - Pointer-sized unsigned integer
ssize_t   // i64  - Signed size type
size_t    // u64  - Unsigned size type
```

**x86 (32-bit)**:
```flux
intptr    // i32* - Pointer-sized signed integer
uintptr   // u32* - Pointer-sized unsigned integer
ssize_t   // i32  - Signed size type
size_t    // u32  - Unsigned size type
```

**Windows-Specific**:
```flux
wchar     // i16  - Wide character (UTF-16)
```

##### Network/Endian Types

**Big-Endian (Network Byte Order)**:
```flux
be16  // unsigned data{16::1}
be32  // unsigned data{32::1}
be64  // unsigned data{64::1}
```

**Little-Endian (Host Byte Order)**:
```flux
le16  // unsigned data{16::0}
le32  // unsigned data{32::0}
le64  // unsigned data{64::0}
```

#### Utility Functions

##### Byte Swapping

```flux
def bswap16(u16 value) -> u16
def bswap32(u32 value) -> u32
def bswap64(u64 value) -> u64
```

Swap byte order for endianness conversion.

**Example**:
```flux
u16 net_value = bswap16(0x1234);  // 0x3412
```

##### Network/Host Conversion

**Deprecated** - these wrappers remain present but are superseded by `net_windows.fx` helpers.

```flux
def ntoh16(be16 net_value) -> le16
def ntoh32(be32 net_value) -> le32
def hton16(le16 host_value) -> be16
def hton32(le32 host_value) -> be32
```

##### Bit Manipulation

```flux
def bit_test(u32 value, u32 bit) -> bool    // Test if bit is set
```

**Example**:
```flux
u32 flags = 0b00001000;
bool is_set = bit_test(flags, 3);  // true
```

##### Alignment Utilities

```flux
def align_up(u64 value, u64 alignment) -> u64
def align_down(u64 value, u64 alignment) -> u64
def is_aligned(u64 value, u64 alignment) -> bool
```

**Example**:
```flux
u64 aligned = align_up(137, 16);  // 144
bool check = is_aligned(144, 16);  // true
```

---

### sys.fx

**Purpose**: OS detection and platform constants

**Namespace**: `standard::system`

**Guard macro**: `FLUX_STANDARD_SYSTEM`

**Description**:  
Sets the `CURRENT_OS` preprocessor constant at compile time and provides Win32 FFI declarations needed by the runtime. Automatically imported by `runtime.fx`.

#### Platform Constants

```flux
CURRENT_OS  // Set at compile time
  1 = Windows
  2 = Linux
  3 = macOS
```

**Example**:
```flux
switch (CURRENT_OS)
{
    case (1) { print("Running on Windows\0"); }
    case (2) { print("Running on Linux\0"); }
    case (3) { print("Running on macOS\0"); }
};
```

---

### io.fx

**Purpose**: Cross-platform input/output operations

**Namespace**: `standard::io`

**Guard macro**: `FLUX_STANDARD_IO`

**Sub-namespaces**:
- `standard::io::console` - Console I/O operations
- `standard::io::file` - File I/O operations

#### Console I/O

##### Input Functions

```flux
def input(byte[] buffer, int max_len) -> int
```

Read user input from console. Platform-agnostic wrapper that calls the appropriate platform-specific implementation.

**Parameters**:
- `buffer`: Byte array to store input
- `max_len`: Maximum number of bytes to read

**Returns**: Number of bytes read (excluding null terminator)

**Platform Implementations**:
- Windows: `win_input()` - Uses Windows API (ReadFile)
- Linux: `nix_input()` - Uses Linux syscalls
- macOS: `mac_input()` - Uses macOS syscalls

##### Output Functions

```flux
def print(noopstr s, int len) -> void
def print(noopstr s) -> void
def print(byte s) -> void
```

Print to console output.

**Overloads**:
- `print(noopstr s, int len)`: Print string with explicit length
- `print(noopstr s)`: Print null-terminated string
- `print(byte s)`: Print single character

**Example**:
```flux
print("Hello, World!\0\0");
print('A');  // Print single character
```

**Platform Implementations**:
- Windows: `win_print()` - Uses Windows API (WriteFile)
- Linux: `nix_print()` - Uses Linux syscalls (write)
- macOS: `mac_print()` - Uses macOS syscalls

#### File I/O (Native Implementation)

The file I/O system provides both native syscall-based and FFI-based implementations.

##### Windows File I/O

**Constants**:
```flux
GENERIC_READ          = 0x80000000
GENERIC_WRITE         = 0x40000000
GENERIC_READ_WRITE    = 0xC0000000
FILE_SHARE_READ       = 0x00000001
FILE_SHARE_WRITE      = 0x00000002
CREATE_NEW            = 1
CREATE_ALWAYS         = 2
OPEN_EXISTING         = 3
OPEN_ALWAYS           = 4
FILE_ATTRIBUTE_NORMAL = 0x00000080
INVALID_HANDLE_VALUE  = -1
```

**Core Functions**:

```flux
def win_open(byte* path, i32 access, i32 share, i32 create, i32 flags) -> i64
def win_read(i64 handle, byte* buffer, u32 bytes_to_read, u32* bytes_read) -> i32
def win_write(i64 handle, byte* buffer, u32 bytes_to_write, u32* bytes_written) -> i32
def win_close(i64 handle) -> i32
```

**Helper Functions**:

```flux
def open_read(byte* path) -> i64
def open_write(byte* path) -> i64
def open_append(byte* path) -> i64
def open_read_write(byte* path) -> i64
```

##### Linux File I/O

**System Call Numbers**:
```flux
SYS_OPEN  = 2
SYS_READ  = 0
SYS_WRITE = 1
SYS_CLOSE = 3
SYS_EXIT  = 60
```

**Open Flags**:
```flux
O_RDONLY = 0x0000
O_WRONLY = 0x0001
O_RDWR   = 0x0002
O_CREAT  = 0x0040
O_TRUNC  = 0x0200
O_APPEND = 0x0400
```

**Permission Modes**:
```flux
S_IRUSR = 0x0400  // User read
S_IWUSR = 0x0200  // User write
S_IXUSR = 0x0100  // User execute
S_IRGRP = 0x0040  // Group read
S_IWGRP = 0x0020  // Group write
S_IXGRP = 0x0010  // Group execute
S_IROTH = 0x0004  // Others read
S_IWOTH = 0x0002  // Others write
S_IXOTH = 0x0001  // Others execute
DEFAULT_PERM = S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH
```

**Core Functions**:

```flux
open(byte* path, i32 flags, i32 mode) -> i64
read(i64 fd, byte* buffer, u64 count) -> i64
write(i64 fd, byte* buffer, u64 count) -> i64
close(i64 fd) -> i32
```

**Helper Functions**:

```flux
open_read(byte* path) -> i64
open_write(byte* path) -> i64
open_append(byte* path) -> i64
open_read_write(byte* path) -> i64
read32(i64 fd, byte* buffer, u32 count) -> i32
write32(i64 fd, byte* buffer, u32 count) -> i32
```

**Example Usage**:
```flux
#import <standard.fx>;

def main() -> int
{
    i64 fd = open_write("output.txt\0");
    if (fd == INVALID_FD)
    {
        print("Failed to open file\0");
        return 1;
    };
    
    byte[] data = "Hello, File!\0";
    i64 written = write(fd, @data[0], 13);
    
    close(fd);
    return 0;
};
```

---

### math.fx

**Purpose**: Comprehensive mathematical functions with type overloading

**Namespace**: `standard::math`

**Guard macro**: `FLUX_STANDARD_MATH`

#### Mathematical Constants

```flux
// Integer approximations
PI8, PI16, PI32, PI64 = 3
E8, E16, E32, E64 = 2

// Floating-point constants
PIF = 3.14159265358979323846
EF  = 2.71828182845904523536
```

#### Core Mathematical Functions

All functions are overloaded for types: `i8`, `i16`, `i32`, `i64`, `float`

##### Absolute Value

```flux
def abs(T x) -> T  // T {i8, i16, i32, i64, float}
```

##### Minimum and Maximum

```flux
def min(T a, T b) -> T
def max(T a, T b) -> T
```

##### Clamp

```flux
def clamp(T value, T low, T high) -> T
```

Constrains `value` to be within [`low`, `high`].

##### Square Root

```flux
def sqrt(T x) -> T
```

Uses Newton's method. Integer versions use integer arithmetic; float version uses iterative refinement.

##### Factorial

```flux
def factorial(T n) -> T  // T {i8, i16, i32, i64}
```

##### GCD / LCM

```flux
def gcd(T a, T b) -> T
def lcm(T a, T b) -> T
```

##### Power

```flux
def pow(T base, T exp) -> T  // T {i8, i16, i32, i64, float}
```

Integer versions use repeated multiplication. Float version supports fractional exponents via exp/log.

#### Trigonometric Functions

```flux
def sin(float x) -> float
def cos(float x) -> float
def tan(float x) -> float
```

Input in radians. Implemented via Taylor series.

#### Logarithmic Functions

```flux
def log(float x) -> float    // Natural logarithm
def log10(float x) -> float  // Base-10 logarithm
```

#### Additional Utilities

```flux
def lerp(T a, T b, float t) -> T         // Linear interpolation
def sign(T x) -> T                        // -1, 0, or 1
def popcount(T x) -> T                    // Count set bits
def reverse_bits(T x) -> T               // Reverse bit order
```

---

## Runtime System

### runtime.fx

**Purpose**: Runtime initialization and program entry point management

**Description**:  
Manages the full startup chain for Flux programs. Imports `types.fx`, `memory.fx`, `sys.fx`, `io.fx`, `ffifio.fx`, and the raw builtins. Defines `STDLIB_GVP`, `NULL`, `U64MAXVAL`, and the `FRTStartup` entry point.

#### Global Constants

```flux
const void* STDLIB_GVP  // Standard global void pointer (null sentinel)
#def NULL STDLIB_GVP    // Alias for STDLIB_GVP
const data{64} U64MAXVAL = 0xFFFFFFFFFFFFFFFFu
```

`STDLIB_GVP` / `NULL` are provided so null checks do not momentarily allocate an integer zero on the stack.

#### Entry Points

**User-Defined Main Functions**:
```flux
def main() -> int
def main(int* argc, byte** argv) -> int
```

**Runtime Entry Point** (do not redefine):
```flux
def FRTStartup() -> int
```

`FRTStartup()` is the actual entry point called by the OS. It handles:
1. Platform detection
2. Standard heap allocator initialization (`stdheap::table_init()`)
3. Command-line argument extraction (Windows)
4. Calling the user's `main()` function
5. Process cleanup

**Linux Entry**:
```flux
def _start() -> void  // Calls FRTStartup()
```

#### Exit Functions

```flux
def exit(int code) -> void   // Platform-native process exit
def abort() -> void          // Abnormal process termination
def atexit(void* fn) -> int  // Register exit callback (stub on Linux/macOS)
```

**Example**:
```flux
#import <standard.fx>;

def main(int* argc, byte** argv) -> int
{
    print("Arguments:\0");
    for (int i = 0; i < *argc; i++)
    {
        print(argv[i]);
        print("\n\0");
    };
    return 0;
};
```

---

### memory.fx

**Purpose**: Memory management - native implementations and C runtime FFI

**Namespace**: `standard::memory`

**Guard macro**: `FLUX_STANDARD_MEMORY`

**Description**:  
Provides both platform-native implementations of `malloc`/`free`/`calloc`/`realloc` (using `mmap`/`munmap` on Linux and macOS, C FFI on Windows) and a `standard::memory` namespace with higher-level utilities. Also exposes Win32 virtual memory functions.

#### Low-Level Allocation (C-compatible ABI)

```flux
def malloc(size_t size) -> void*
def free(void* ptr) -> void
def calloc(size_t count, size_t size) -> void*
def realloc(void* ptr, size_t new_size) -> void*
```

On Windows these are C runtime FFI declarations. On Linux and macOS they are native implementations backed by `mmap`/`munmap` with an 8-byte size header.

#### Memory Operations

```flux
def memset(void* ptr, int value, size_t n) -> void*
def memcpy(void* dst, void* src, size_t n) -> void*
def memmove(void* dst, void* src, size_t n) -> void*
def memcmp(void* a, void* b, size_t n) -> int
```

All four are native Flux implementations with no C runtime dependency.

#### Win32 Virtual Memory

Available on Windows only:

```flux
extern def VirtualAlloc(ulong, size_t, u32, u32) -> ulong
extern def VirtualFree(ulong, size_t, u32) -> bool
extern def VirtualProtect(ulong, size_t, u32, u32*) -> bool
extern def FlushInstructionCache(ulong, ulong, size_t) -> bool
```

#### standard::memory Utilities

```flux
def mem_zero(void* ptr, size_t size) -> void
def mem_fill(void* ptr, byte value, size_t size) -> void
def mem_copy(void* dest, void* src, size_t size) -> void
def mem_move(void* dest, void* src, size_t size) -> void
def mem_compare(void* a, void* b, size_t size) -> int
def mem_equals(void* a, void* b, size_t size) -> bool
```

#### Aligned Allocation

```flux
def align_forward(size_t addr, size_t alignment) -> size_t
def is_aligned(size_t addr, size_t alignment) -> bool
def malloc_aligned(size_t size, size_t alignment) -> void*
def free_aligned(void* ptr) -> void
```

#### Reference Counting

```flux
struct RefCountHeader { size_t ref_count, size; };

def ref_alloc(size_t size) -> void*
def ref_retain(void* ptr) -> void*
def ref_release(void* ptr) -> void
def ref_count(void* ptr) -> size_t
```

#### Byte Manipulation

```flux
def swap_bytes(byte* a, byte* b) -> void
def reverse_bytes(byte* buffer, size_t size) -> void
def copy_bytes(byte* dest, byte* src, size_t count) -> void
def zero_bytes(byte* buffer, size_t count) -> void
```

**Example**:
```flux
void* buffer = malloc(100);
if (buffer == NULL)
{
    print("Allocation failed\0");
    return 1;
};
// ... use buffer ...
free(buffer);
```

---

### allocators.fx

**Purpose**: Flux custom allocators — heap, stack, pool, arena, and ring

**Namespace**: `standard::memory::allocators`

**Guard macro**: `FLUX_STANDARD_ALLOCATORS`

**Description**:  
Provides five allocators under the `standard::memory::allocators` namespace. The primary heap allocator (`stdheap`) is automatically initialized by `FRTStartup()`. All others must be constructed manually.

#### stdheap — Standard Heap Allocator

**Namespace**: `standard::memory::allocators::stdheap`

**Design**:
- Segregated free lists by size class for O(1) small alloc/free
- Bump pointer fast path carves from a slab frontier
- Large allocations (>4096 bytes) get a dedicated OS slab, released on `ffree`
- Block metadata lives in a separate table slab (open-addressed hash map keyed by user pointer)
- No inline headers; user data blocks are completely clean
- No zeroing (Flux zero-initializes at the language level)
- Slabs acquired from OS: 4MB → 8MB → 16MB → 32MB → 64MB cap
- Zero OS memory consumed until the first `fmalloc` call

**Public API**:

```flux
def fmalloc(size_t size) -> u64     // Allocate; returns integer address
def ffree(u64 ptr) -> void          // Free by integer address
def ffree(byte* ptr) -> void        // Free by pointer (overload)
def frealloc(u64 ptr, size_t new_size) -> u64  // Reallocate
```

**Note**: `fmalloc` returns a `u64` (raw address). Cast to the desired pointer type:

```flux
byte* buf = (byte*)fmalloc(256);
// ... use buf ...
ffree((u64)buf);
```

**Internal API** (do not call directly):

```flux
def stdheap::table_init() -> bool   // Called by FRTStartup()
```

---

#### stdstack — Stack Allocator

**Namespace**: `standard::memory::allocators::stdstack`

**Description**: Bump-pointer allocator backed by a single `stdheap` allocation. All allocations happen in order; only a bulk reset is supported (no individual frees).

```flux
object StackAllocator
{
    def __init(size_t size) -> this,
        allocate(size_t size) -> void_ptr,
        reset() -> void,
        get_used() -> size_t,
        get_available() -> size_t,
        get_capacity() -> size_t;
};
```

---

#### stdpool — Pool Allocator

**Namespace**: `standard::memory::allocators::stdpool`

**Description**: Fixed-size block pool. All blocks are the same size. O(1) alloc and free via an in-place free list. Returns `null` when exhausted.

```flux
object PoolAllocator
{
    def __init(size_t block_size, size_t block_count) -> this,
        allocate() -> void_ptr,
        deallocate(void_ptr ptr) -> void,
        get_block_size() -> size_t,
        get_block_count() -> size_t,
        get_free_count() -> size_t;
};
```

---

#### stdarena — Arena Allocator

**Namespace**: `standard::memory::allocators::stdarena`

**Description**: Bump-pointer allocator over a linked chain of OS-backed chunks. Individual frees are unsupported by design — free everything at once with `arena_reset` or `arena_destroy`. Supports scope-level rewind via `arena_mark`/`arena_rewind`. All allocations are 8-byte aligned. Zero OS memory consumed until first `alloc` call.

**Chunk growth**: 1 MB initial → doubles each chunk → 64 MB cap.

```flux
struct Arena     { /* head chunk, next_chunk_size, chunk_size_cap */ };
struct ArenaMark { /* chunk pointer + offset snapshot */ };

def arena_init(Arena* a) -> void
def arena_init_sized(Arena* a, size_t first_chunk) -> void
def alloc(Arena* a, size_t sz) -> void*          // 8-byte aligned, returns null on OOM
def alloc_zero(Arena* a, size_t sz) -> void*     // Zeroes before returning
def alloc_copy(Arena* a, void* src, size_t sz) -> void*
def alloc_str(Arena* a, byte* src) -> byte*      // Copy null-terminated string into arena
def arena_mark(Arena* a) -> ArenaMark            // Snapshot current position
def arena_rewind(Arena* a, ArenaMark* m) -> void // Restore to mark (bulk frees newer chunks)
def arena_reset(Arena* a) -> void                // Reset all offsets; keep chunks allocated
def arena_destroy(Arena* a) -> void              // Free all chunks back to stdheap
def arena_used(Arena* a) -> size_t               // Bytes in use across all chunks
def arena_committed(Arena* a) -> size_t          // Total bytes committed from OS
```

**Example**:

```flux
#import "allocators.fx";
using standard::memory::allocators::stdarena;

Arena a;
arena_init(@a);
byte* buf = (byte*)alloc(@a, 1024);
// ... use buf (no individual free needed) ...
arena_destroy(@a);
```

---

#### stdring — Ring Allocator

**Namespace**: `standard::memory::allocators::stdring`

**Description**: Fixed-capacity circular buffer allocator. Returns a `RingAllocResult*` on success or `null` when the buffer has wrapped around to occupied space.

```flux
struct RingAllocResult { /* user data follows header */ };

// Constructed via object syntax; capacity set at init.
def allocate(size_t size) -> RingAllocResult*
```

---

### ffifio.fx

**Purpose**: File I/O through C standard library FFI

**Namespace**: `standard::io::file`

**Description**:  
Provides high-level file I/O operations using C's `stdio.h` through FFI. An alternative to the native syscall-based file I/O in `io.fx`.

#### C stdio FFI Declarations

```flux
extern def !!
    fopen(byte* filename, byte* mode) -> void*,
    fclose(void* stream) -> int,
    fread(void* ptr, int size, int count, void* stream) -> int,
    fwrite(void* ptr, int size, int count, void* stream) -> int,
    fseek(void* stream, int offset, int whence) -> int,
    ftell(void* stream) -> int,
    rewind(void* stream) -> void,
    feof(void* stream) -> int,
    ferror(void* stream) -> int;
```

#### File Modes

| Mode | Description |
|------|-------------|
| `"r"` | Read |
| `"w"` | Write (truncate) |
| `"a"` | Append |
| `"r+"` | Read/write |
| `"w+"` | Read/write (truncate) |
| `"rb"` | Read binary |
| `"wb"` | Write binary |
| `"ab"` | Append binary |

#### Seek Constants

```flux
SEEK_SET = 0  // Beginning of file
SEEK_CUR = 1  // Current position
SEEK_END = 2  // End of file
```

#### High-Level Helper Functions

```flux
def read_file(byte* filename, byte[] buffer, int buffer_size) -> int
def write_file(byte* filename, byte[] data, int data_size) -> int
def append_file(byte* filename, byte[] data, int data_size) -> int
def get_file_size(byte* filename) -> int
def file_exists(byte* filename) -> bool
```

**Example**:
```flux
#import <standard.fx>;

def main() -> int
{
    byte[] data = "Hello, World!\0";
    int written = write_file("test.txt\0", data, 13);
    if (written < 0)
    {
        print("Failed to write file\0");
        return 1;
    };
    
    byte[1024] buffer;
    int read_bytes = read_file("test.txt\0", buffer, 1024);
    if (read_bytes > 0)
    {
        print(buffer);
    };
    return 0;
};
```

---

## String Utilities

### string_utilities.fx

**Purpose**: Comprehensive string manipulation functions

**Description**:  
Native Flux implementations of string operations without C runtime dependencies.

#### Core String Functions

```flux
def strlen(byte* ps) -> int
def strcpy(noopstr dest, noopstr src) -> noopstr
```

#### Integer to String Conversion

```flux
def i32str(i32 value, byte* buffer) -> i32
def i64str(i64 value, byte* buffer) -> i64
def u32str(u32 value, byte* buffer) -> u32
def u64str(u64 value, byte* buffer) -> u64
```

**Example**:
```flux
byte[32] buffer;
i32 len = i32str(-12345, @buffer[0]);
print(buffer);  // Prints "-12345"
```

#### String to Integer Conversion

```flux
def str2i32(byte* str) -> int
def str2u32(byte* str) -> uint
def str2i64(byte* str) -> i64
def str2u64(byte* str) -> u64
```

#### Float Conversion

```flux
def fstr(float value, byte* buffer, int precision) -> int
def str2f(byte* str) -> float
```

#### Character Classification

```flux
def is_digit(byte c) -> bool
def is_alpha(byte c) -> bool
def is_alnum(byte c) -> bool
def is_whitespace(byte c) -> bool
def is_upper(byte c) -> bool
def is_lower(byte c) -> bool
def is_hex_digit(byte c) -> bool
def is_identifier_start(byte c) -> bool
def is_identifier_char(byte c) -> bool
```

#### Character Conversion

```flux
def to_upper(byte c) -> byte
def to_lower(byte c) -> byte
def hex_to_int(byte c) -> int
```

#### String Comparison

```flux
def str_equals(byte* s1, byte* s2) -> bool
def str_equals_n(byte* s1, byte* s2, int n) -> bool
def starts_with(byte* str, byte* prefix) -> bool
def ends_with(byte* str, byte* suffix) -> bool
```

#### String Search

```flux
def find_char(byte* str, byte ch, int start_pos) -> int
def find_char_last(byte* str, byte ch) -> int
def find_substring(byte* haystack, byte* needle, int start_pos) -> int
def count_char(byte* str, byte ch) -> int
```

#### String Manipulation

```flux
def skip_whitespace(byte* str, int pos) -> int
def trim_start(byte* str) -> int
def trim_end(byte* str) -> int
```

**Memory-Allocating Functions** (caller must free):

```flux
def copy_string(byte* src) -> byte*
def copy_n(byte* src, int n) -> byte*
def substring(byte* str, int start, int length) -> byte*
def concat(byte* s1, byte* s2) -> byte*
```

#### Parsing Functions

```flux
def parse_int(byte* str, int start_pos, int* end_pos) -> int
def parse_hex(byte* str, int start_pos, int* end_pos) -> int
```

#### Line and Word Operations

```flux
def count_lines(byte* str) -> int
def get_line(byte* str, int line_num) -> byte*
def count_words(byte* str) -> int
```

#### String Replacement

```flux
def replace_first(byte* str, byte* find, byte* replace) -> byte*
```

#### Tokenization Helpers

```flux
def skip_until(byte* str, int pos, char ch) -> int
def skip_while_digit(byte* str, int pos) -> int
def skip_while_alnum(byte* str, int pos) -> int
def skip_while_identifier(byte* str, int pos) -> int
def match_at(byte* str, int pos, byte* pattern) -> bool
```

---

### string_object_raw.fx

**Purpose**: Object-oriented string wrapper

**Description**:  
Provides an object-oriented interface for string manipulation. Imported by `runtime.fx`; marked for deprecation from direct runtime use.

#### String Object

```flux
object string
{
    noopstr value;
    
    def val() -> byte*,
        len() -> int,
        set(byte*) -> bool,
        clear() -> void,
        isempty() -> bool,
        
        // Comparison
        equals(byte*) -> bool,
        compare(byte*) -> int,
        icompare(byte*) -> int,
        
        // Search
        contains(byte*) -> bool,
        startswith(byte*) -> bool,
        endswith(byte*) -> bool,
        indexof(byte*) -> int,
        lastindexof(byte*) -> int,
        indexof_char(char) -> int,
        lastindexof_char(char) -> int,
        count_occurrences(byte*) -> int,
        //count_spaces() -> int, // count_occurances(" \0")
        
        // Character access
        charat(int) -> char,
        setat(int, char) -> bool,
        
        // Substring & manipulation
        substring(int, int) -> byte*,
        left(int) -> byte*,
        right(int) -> byte*,
        
        // Concatenation
        concat(byte*) -> byte*,
        append(byte*) -> bool,
        prepend(byte*) -> bool,
        
        // Modification
        replace(byte*, byte*) -> byte*,
        replace_all(byte*, byte*) -> byte*,
        replace_char(char, char) -> bool,
        insert(int, byte*) -> bool,
        remove(int, int) -> bool,
        
        // Case conversion
        toupper() -> bool,
        tolower() -> bool,
        totitle() -> bool,
        
        // Trimming
        trim() -> bool,
        trimstart() -> bool,
        trimend() -> bool,
        trim_char(char) -> bool,
        
        // Splitting & joining
        split(char) -> byte**,
        split_lines() -> byte**,
        split_words() -> byte**,
        
        // Validation
        isalpha() -> bool,
        isdigit() -> bool,
        isalnum() -> bool,
        //isupper() -> bool,
        //islower() -> bool,
        
        // Conversion
        toint() -> int,
        toi32() -> i32,
        toi64() -> i64,
        tou32() -> u32,
        tou64() -> u64,
        fromint(int) -> bool,
        
        // Line operations
        count_lines() -> int,
        get_line(int) -> byte*,
        count_words() -> int,
        
        // Other
        reverse() -> bool,
        copy() -> byte*,
        hash() -> int,
        printval() -> void,
        println() -> void;
};
```

**Example**:
```flux
string myStr("Hello, World!\0");
print(myStr.val());
int length = myStr.len();
```

---

## Collections Library

### collections.fx

**Purpose**: Comprehensive data structure implementations for Flux

**Namespace**: `standard::collections`

**Dependencies**: `types.fx`, `memory.fx`

**Description**:  
Provides essential data structures for efficient data management. All collections are generic (using `void*` payloads) and manage their own allocation. Caller is responsible for freeing payloads.

#### Dynamic Array (Array)

**Definition**:
```flux
object Array
{
    void** items;
    size_t size;
    size_t capacity;
};
```

**Constructors**:
```flux
Array()                        // Default capacity: 16
Array(size_t initial_capacity) // Custom capacity
```

| Method | Returns | Description |
|--------|---------|-------------|
| `get_size()` | `size_t` | Current number of elements |
| `get_capacity()` | `size_t` | Current allocated capacity |
| `is_empty()` | `bool` | Check if empty |
| `push(void* item)` | `bool` | Add to end (auto-resize) |
| `pop()` | `void*` | Remove and return last item |
| `get(size_t index)` | `void*` | Get item at index |
| `set(size_t index, void* item)` | `bool` | Set item at index |
| `clear()` | `void` | Remove all items (keeps capacity) |
| `remove_at(size_t index)` | `bool` | Remove at index (shift left) |
| `insert_at(size_t index, void* item)` | `bool` | Insert at index (shift right) |

**Example**:
```flux
Array myArray(32);
myArray.push((void*)42);
size_t count = myArray.get_size();  // 1
void* value = myArray.get(0);       // (void*)42
```

---

#### Doubly Linked List (LinkedList)

**Definition**:
```flux
struct LinkedListNode
{
    void* payload;
    LinkedListNode* next;
    LinkedListNode* prev;
};

object LinkedList
{
    LinkedListNode* head;
    LinkedListNode* tail;
    size_t size;
};
```

| Method | Returns | Description |
|--------|---------|-------------|
| `get_size()` | `size_t` | Number of nodes |
| `is_empty()` | `bool` | Check if empty |
| `push_front(void*)` | `bool` | Add to front |
| `push_back(void*)` | `bool` | Add to back |
| `pop_front()` | `void*` | Remove and return first |
| `pop_back()` | `void*` | Remove and return last |
| `peek_front()` | `void*` | Get first without removing |
| `peek_back()` | `void*` | Get last without removing |
| `get(size_t index)` | `void*` | Get at index (O(n)) |
| `remove_at(size_t index)` | `bool` | Remove at index |
| `clear()` | `void` | Remove all nodes |

---

#### Stack

LIFO wrapper over `LinkedList`.

| Method | Returns | Description |
|--------|---------|-------------|
| `get_size()` | `size_t` | Number of items |
| `is_empty()` | `bool` | Check if empty |
| `push(void*)` | `bool` | Push onto stack |
| `pop()` | `void*` | Pop and return top |
| `peek()` | `void*` | Get top without removing |
| `clear()` | `void` | Remove all items |

---

#### Queue

FIFO wrapper over `LinkedList`.

| Method | Returns | Description |
|--------|---------|-------------|
| `get_size()` | `size_t` | Number of items |
| `is_empty()` | `bool` | Check if empty |
| `enqueue(void*)` | `bool` | Add to back |
| `dequeue()` | `void*` | Remove and return front |
| `peek()` | `void*` | Get front without removing |
| `clear()` | `void` | Remove all items |

---

#### Hash Map (HashMap)

**Definition**:
```flux
struct HashMapEntry { i64 key; void* value; HashMapEntry* next; };

object HashMap
{
    HashMapEntry** buckets;
    size_t bucket_count;
    size_t size;
};
```

**Constructors**:
```flux
HashMap()               // Default: 16 buckets
HashMap(size_t buckets) // Custom bucket count
```

| Method | Returns | Description |
|--------|---------|-------------|
| `get_size()` | `size_t` | Number of pairs |
| `is_empty()` | `bool` | Check if empty |
| `put(i64 key, void* value)` | `bool` | Insert or update |
| `get(i64 key)` | `void*` | Get value (NULL if absent) |
| `contains(i64 key)` | `bool` | Check key exists |
| `remove(i64 key)` | `bool` | Remove pair |
| `clear()` | `void` | Remove all entries |

Uses chaining for collision resolution. Fixed bucket count (no auto-rehashing).

---

#### Binary Search Tree (BinarySearchTree)

**Definition**:
```flux
struct BinaryTreeNode
{
    void* payload;
    i64 key;
    BinaryTreeNode* left;
    BinaryTreeNode* right;
    BinaryTreeNode* parent;
};

object BinarySearchTree { BinaryTreeNode* root; size_t size; };
```

| Method | Returns | Description |
|--------|---------|-------------|
| `get_size()` | `size_t` | Number of nodes |
| `is_empty()` | `bool` | Check if empty |
| `insert(i64 key, void* item)` | `bool` | Insert (updates if exists) |
| `find(i64 key)` | `void*` | Find payload by key |
| `contains(i64 key)` | `bool` | Check key exists |
| `remove(i64 key)` | `bool` | Remove node |
| `clear()` | `void` | Remove all nodes |

Maintains sorted order. Not self-balancing.

---

#### Integer Hash Map (HashMapInt)

String-keyed variant of `HashMap`. Key type is `byte*` (null-terminated string) instead of `i64`.

| Method | Returns | Description |
|--------|---------|-------------|
| `get_size()` | `size_t` | Number of pairs |
| `is_empty()` | `bool` | Check if empty |
| `put(byte* key, void* value)` | `bool` | Insert or update |
| `get(byte* key)` | `void*` | Get value (NULL if absent) |
| `contains(byte* key)` | `bool` | Check key exists |
| `remove(byte* key)` | `bool` | Remove pair |
| `clear()` | `void` | Remove all entries |

---

#### Deque

Double-ended queue backed by `LinkedList`. Supports O(1) push/pop at both ends.

| Method | Returns | Description |
|--------|---------|-------------|
| `get_size()` | `size_t` | Number of items |
| `is_empty()` | `bool` | Check if empty |
| `push_front(void*)` | `bool` | Add to front |
| `push_back(void*)` | `bool` | Add to back |
| `pop_front()` | `void*` | Remove and return front |
| `pop_back()` | `void*` | Remove and return back |
| `peek_front()` | `void*` | Get front without removing |
| `peek_back()` | `void*` | Get back without removing |
| `clear()` | `void` | Remove all items |

---

#### RingBuffer

Fixed-capacity circular buffer. Overwrites oldest entries when full.

| Method | Returns | Description |
|--------|---------|-------------|
| `get_size()` | `size_t` | Number of items currently stored |
| `get_capacity()` | `size_t` | Maximum capacity |
| `is_empty()` | `bool` | Check if empty |
| `is_full()` | `bool` | Check if at capacity |
| `push(void*)` | `bool` | Add item (returns false if full) |
| `pop()` | `void*` | Remove and return oldest item |
| `peek()` | `void*` | Get oldest item without removing |
| `clear()` | `void` | Remove all items |

---

#### Hash Set (HashSet)

Set of unique `void*` values keyed by `i64`. No duplicate keys.

| Method | Returns | Description |
|--------|---------|-------------|
| `get_size()` | `size_t` | Number of entries |
| `is_empty()` | `bool` | Check if empty |
| `add(i64 key, void* value)` | `bool` | Add entry |
| `contains(i64 key)` | `bool` | Check membership |
| `get(i64 key)` | `void*` | Retrieve value |
| `remove(i64 key)` | `bool` | Remove entry |
| `clear()` | `void` | Remove all entries |

---

#### Integer Hash Set (HashSetInt)

String-keyed variant of `HashSet`. Key type is `byte*` (null-terminated string).

| Method | Returns | Description |
|--------|---------|-------------|
| `get_size()` | `size_t` | Number of entries |
| `is_empty()` | `bool` | Check if empty |
| `add(byte* key, void* value)` | `bool` | Add entry |
| `contains(byte* key)` | `bool` | Check membership |
| `get(byte* key)` | `void*` | Retrieve value |
| `remove(byte* key)` | `bool` | Remove entry |
| `clear()` | `void` | Remove all entries |

---

#### Min Heap (MinHeap)

Binary min-heap keyed by `i64`. Always returns the lowest-keyed item from `peek`/`pop`.

| Method | Returns | Description |
|--------|---------|-------------|
| `get_size()` | `size_t` | Number of items |
| `is_empty()` | `bool` | Check if empty |
| `push(i64 key, void* item)` | `bool` | Insert item with priority key |
| `pop()` | `void*` | Remove and return lowest-key item |
| `peek()` | `void*` | Get lowest-key item without removing |
| `peek_key()` | `i64` | Get lowest key without removing |
| `clear()` | `void` | Remove all items |

---



### vectors.fx

**Purpose**: 3D and 4D vector mathematics

**Namespace**: `standard::vectors`

**Dependencies**: `types.fx`, `math.fx`

#### Vector Structures

```flux
struct Vec3 { float x, y, z; };
struct Vec4 { float x, y, z, w; };
```

#### Vec3 Constructors

```flux
def vec3(float x, float y, float z) -> Vec3
def vec3_zero() -> Vec3    // (0, 0, 0)
def vec3_one() -> Vec3     // (1, 1, 1)
def vec3_up() -> Vec3      // (0, 1, 0)
def vec3_down() -> Vec3    // (0, -1, 0)
def vec3_left() -> Vec3    // (-1, 0, 0)
def vec3_right() -> Vec3   // (1, 0, 0)
def vec3_forward() -> Vec3 // (0, 0, 1)
def vec3_back() -> Vec3    // (0, 0, -1)
```

#### Vec4 Constructors

```flux
def vec4(float x, float y, float z, float w) -> Vec4
def vec4_zero() -> Vec4
def vec4_one() -> Vec4
def vec4_from_vec3(Vec3 v, float w) -> Vec4
```

#### Arithmetic Operations

```flux
def vec3_add(Vec3 a, Vec3 b) -> Vec3
def vec3_sub(Vec3 a, Vec3 b) -> Vec3
def vec3_mul(Vec3 v, float scalar) -> Vec3
def vec3_div(Vec3 v, float scalar) -> Vec3
def vec3_negate(Vec3 v) -> Vec3
def vec3_scale(Vec3 a, Vec3 b) -> Vec3  // Component-wise multiply

def vec4_add(Vec4 a, Vec4 b) -> Vec4
def vec4_sub(Vec4 a, Vec4 b) -> Vec4
def vec4_mul(Vec4 v, float scalar) -> Vec4
def vec4_div(Vec4 v, float scalar) -> Vec4
def vec4_negate(Vec4 v) -> Vec4
def vec4_scale(Vec4 a, Vec4 b) -> Vec4
```

#### Dot and Cross Products

```flux
def vec3_dot(Vec3 a, Vec3 b) -> float
def vec4_dot(Vec4 a, Vec4 b) -> float
def vec3_cross(Vec3 a, Vec3 b) -> Vec3  // Right-hand rule
```

#### Length and Normalization

```flux
def vec3_length_squared(Vec3 v) -> float
def vec3_length(Vec3 v) -> float
def vec3_normalize(Vec3 v) -> Vec3
def vec3_distance(Vec3 a, Vec3 b) -> float
def vec3_distance_squared(Vec3 a, Vec3 b) -> float

def vec4_length_squared(Vec4 v) -> float
def vec4_length(Vec4 v) -> float
def vec4_normalize(Vec4 v) -> Vec4
def vec4_distance(Vec4 a, Vec4 b) -> float
def vec4_distance_squared(Vec4 a, Vec4 b) -> float
```

#### Interpolation

```flux
def vec3_lerp(Vec3 a, Vec3 b, float t) -> Vec3
def vec4_lerp(Vec4 a, Vec4 b, float t) -> Vec4
def vec3_slerp(Vec3 a, Vec3 b, float t) -> Vec3
def vec4_slerp(Vec4 a, Vec4 b, float t) -> Vec4
```

#### Projection and Reflection

```flux
def vec3_project(Vec3 v, Vec3 onto) -> Vec3
def vec3_reject(Vec3 v, Vec3 from) -> Vec3
def vec3_reflect(Vec3 v, Vec3 normal) -> Vec3

def vec4_project(Vec4 v, Vec4 onto) -> Vec4
def vec4_reject(Vec4 v, Vec4 from) -> Vec4
def vec4_reflect(Vec4 v, Vec4 normal) -> Vec4
```

#### Angle, Min/Max/Clamp, Rotation, Advanced

```flux
def vec3_angle(Vec3 a, Vec3 b) -> float  // Radians, range [0, π]
def vec4_angle(Vec4 a, Vec4 b) -> float

def vec3_min(Vec3 a, Vec3 b) -> Vec3
def vec3_max(Vec3 a, Vec3 b) -> Vec3
def vec3_clamp(Vec3 v, Vec3 min_v, Vec3 max_v) -> Vec3

def vec3_rotate_x(Vec3 v, float angle) -> Vec3  // Angles in radians
def vec3_rotate_y(Vec3 v, float angle) -> Vec3
def vec3_rotate_z(Vec3 v, float angle) -> Vec3

def vec3_barycentric(Vec3 a, Vec3 b, Vec3 c, float u, float v) -> Vec3
def vec3_triple_product(Vec3 a, Vec3 b, Vec3 c) -> float  // a · (b × c)
def vec3_abs(Vec3 v) -> Vec3
def vec4_abs(Vec4 v) -> Vec4
```

---

## Extended Libraries

### atomics.fx

**Purpose**: Lock-free atomic primitives for multi-threaded access

**Namespace**: `standard::atomic`

**Guard macro**: `FLUX_STANDARD_ATOMICS`

**Description**:  
Provides hardware atomics via inline assembly for x86-64 and ARM64. Used internally by `threading.fx`.

#### Memory Barriers

```flux
def fence() -> void           // Full memory barrier
def compiler_barrier() -> void // Compiler-only barrier
def load_fence() -> void       // Acquire barrier
def store_fence() -> void      // Release barrier
```

#### Atomic Load / Store

```flux
def load32(i32* ptr) -> i32
def load64(i64* ptr) -> i64
def store32(i32* ptr, i32 value) -> void
def store64(i64* ptr, i64 value) -> void
```

#### Atomic Exchange

```flux
def exchange32(i32* ptr, i32 value) -> i32
def exchange64(i64* ptr, i64 value) -> i64
```

#### Compare-and-Swap

```flux
def cas32(i32* ptr, i32 expected, i32 desired) -> bool
def cas64(i64* ptr, i64 expected, i64 desired) -> bool
```

#### Atomic Arithmetic

```flux
def fetch_add32(i32* ptr, i32 delta) -> i32
def fetch_add64(i64* ptr, i64 delta) -> i64
def fetch_sub32(i32* ptr, i32 delta) -> i32
def fetch_sub64(i64* ptr, i64 delta) -> i64
def fetch_and32(i32* ptr, i32 mask) -> i32
def fetch_and64(i64* ptr, i64 mask) -> i64
def fetch_or32(i32* ptr, i32 mask) -> i32
def fetch_or64(i64* ptr, i64 mask) -> i64
def fetch_xor32(i32* ptr, i32 mask) -> i32
def fetch_xor64(i64* ptr, i64 mask) -> i64
def inc32(i32* ptr) -> i32
def inc64(i64* ptr) -> i64
def dec32(i32* ptr) -> i32
def dec64(i64* ptr) -> i64
```

#### Spin Lock

```flux
def spin_lock(i32* lock) -> void
def spin_unlock(i32* lock) -> void
def spin_trylock(i32* lock) -> bool
```

#### One-Time Initialization

```flux
def once_begin(i32* flag) -> bool  // Returns true if this caller wins the race
def once_end(i32* flag) -> void    // Signal initialization complete
```

#### Reference Counting / Flags

```flux
def ref_inc(i32* counter) -> void
def ref_dec_and_test(i32* counter) -> bool  // Returns true when count hits 0
def ref_get(i32* counter) -> i32

def flag_set(i32* flag) -> void
def flag_clear(i32* flag) -> void
def flag_test(i32* flag) -> bool
def flag_test_and_set(i32* flag) -> bool
```

---

### threading.fx

**Purpose**: Thread creation and synchronization primitives

**Namespace**: `standard::threading`

**Guard macro**: `FLUX_STANDARD_THREADING`

**Dependencies**: `types.fx`, `atomics.fx`

**Supported platforms**: Windows, Linux, macOS (x86-64 and ARM64)

#### Structures

```flux
struct Thread    { /* platform handle + id */ };
struct Mutex     { /* platform CS or pthread_mutex */ };
struct RWLock    { /* platform SRW or pthread_rwlock */ };
struct CondVar   { /* platform CV or pthread_cond */ };
struct Semaphore { /* platform handle + count */ };
struct Barrier   { /* atomic counter + CondVar */ };
struct TLSKey    { /* platform TLS slot */ };
```

#### Thread

```flux
def thread_create(void* fn, void* arg, Thread* out) -> int  // 0 on success
def thread_join(Thread* t) -> int
def thread_id() -> u64
def thread_yield() -> void
def thread_sleep_ms(u32 ms) -> void
```

#### Mutex

```flux
def mutex_init(Mutex* m) -> int
def mutex_destroy(Mutex* m) -> void
def mutex_lock(Mutex* m) -> void
def mutex_unlock(Mutex* m) -> void
def mutex_trylock(Mutex* m) -> bool
```

#### Reader/Writer Lock

```flux
def rwlock_init(RWLock* rw) -> int
def rwlock_destroy(RWLock* rw) -> void
def rwlock_read_lock(RWLock* rw) -> void
def rwlock_read_unlock(RWLock* rw) -> void
def rwlock_write_lock(RWLock* rw) -> void
def rwlock_write_unlock(RWLock* rw) -> void
def rwlock_try_read_lock(RWLock* rw) -> bool
def rwlock_try_write_lock(RWLock* rw) -> bool
```

#### Barrier

```flux
def barrier_init(Barrier* b, i32 n) -> void  // n = thread count
def barrier_wait(Barrier* b) -> bool          // Returns true for the last thread
```

#### Thread-Local Storage

```flux
def tls_key_create(TLSKey* k) -> int
def tls_key_destroy(TLSKey* k) -> void
def tls_set(TLSKey* k, void* value) -> int
def tls_get(TLSKey* k) -> void*
```

**Example**:
```flux
#import "threading.fx";
using standard::threading;

Thread t;
thread_create(my_worker_fn, (void*)@arg, @t);
thread_join(@t);
```

---

### timing.fx

**Purpose**: High-resolution timestamps, timers, and benchmarking utilities

**Namespace**: `standard::time`

**Description**:  
Provides nanosecond-resolution timing across all supported platforms.

#### Core Functions

```flux
def time_now() -> i64      // Current time in nanoseconds (platform-appropriate)
def sleep_ms(u32 ms) -> void
def sleep_us(u32 us) -> void
```

#### Unit Conversion

```flux
def ns_to_us(i64 ns) -> i64
def ns_to_ms(i64 ns) -> i64
def ns_to_sec(i64 ns) -> i64
def us_to_ns(i64 us) -> i64
def ms_to_ns(i64 ms) -> i64
def sec_to_ns(i64 s) -> i64
```

#### Timer Object

```flux
struct Timer { /* start/stop timestamps */ };

def timer_start(Timer* t) -> void
def timer_stop(Timer* t) -> i64   // Returns elapsed nanoseconds
```

**Example**:
```flux
#import "timing.fx";
using standard::time;

Timer t;
timer_start(@t);
// ... work ...
i64 elapsed_ns = timer_stop(@t);
```

---

### random.fx

**Purpose**: Random number generation

**Namespace**: `standard::random`

**Description**:  
Provides multiple RNG algorithms. Uses `rdtsc` or OS entropy for seeding. The recommended default is `PCG32` for general use.

#### RNG Structures

```flux
struct XorShift64  { /* 64-bit state */ };
struct XorShift128 { /* 128-bit state */ };
struct PCG32       { /* state + sequence */ };
struct LCG         { /* state */ };
```

#### Seeding

```flux
def xorshift64_seed(XorShift64* rng, u64 seed) -> void
def xorshift64_init(XorShift64* rng) -> void   // Auto-seed from entropy
def xorshift128_seed(XorShift128* rng, u64 seed1, u64 seed2) -> void
def xorshift128_init(XorShift128* rng) -> void
def pcg32_seed(PCG32* rng, u64 seed, u64 seq) -> void
def pcg32_init(PCG32* rng) -> void
def lcg_seed(LCG* rng, u64 seed) -> void
def lcg_init(LCG* rng) -> void
```

#### Generation

```flux
def xorshift64_next(XorShift64* rng) -> u64
def xorshift128_next(XorShift128* rng) -> u64
def pcg32_next(PCG32* rng) -> u32
def lcg_next(LCG* rng) -> u32
```

#### Utilities

```flux
def random_range_u64(XorShift128* rng, u64 max) -> u64
def random_range_u32(PCG32* rng, u32 max) -> u32
def random_range_int(PCG32* rng, int min, int max) -> int
def random_float(PCG32* rng) -> float           // [0.0, 1.0)
def random_range_float(PCG32* rng, float min, float max) -> float
def random_bool(PCG32* rng) -> bool
def random_bytes(PCG32* rng, byte* buffer, u64 length) -> void
def shuffle_u32_array(PCG32* rng, u32* array, u32 length) -> void
def roll_dice(PCG32* rng, int sides) -> int
def roll_dice_sum(PCG32* rng, int count, int sides) -> int
def flip_coin(PCG32* rng) -> bool
def random_string(PCG32* rng, byte* buffer, u32 length, byte* charset) -> void
def random_alphanum(PCG32* rng, byte* buffer, u32 length) -> void
def random_hex(PCG32* rng, byte* buffer, u32 length) -> void
```

#### Global Convenience Interface

```flux
def init_random() -> void  // Initialize global PCG32 state
def random() -> u32        // Draw from global state
```

---

### cryptography.fx

**Purpose**: Hashing and encryption primitives

**Namespaces**:
- `standard::crypto::hashing::SHA256`
- `standard::crypto::hashing::MD5`
- `standard::crypto::encryption::AES`

#### SHA-256

```flux
struct SHA256_CTX { /* 256-bit digest state */ };

def sha256_init(SHA256_CTX* ctx) -> void
def sha256_update(SHA256_CTX* ctx, byte* data, u64 len) -> void
def sha256_final(SHA256_CTX* ctx, byte* hash) -> void  // hash: 32-byte output buffer
```

#### MD5

```flux
struct MD5_CTX { /* 128-bit digest state */ };

def md5_init(MD5_CTX* ctx) -> void
def md5_update(MD5_CTX* ctx, byte* data, u64 len) -> void
def md5_final(MD5_CTX* ctx, byte* digest) -> void  // digest: 16-byte output buffer
```

#### AES

```flux
struct AES_CTX { /* round keys */ };

def aes_key_expansion(AES_CTX* ctx, byte* key) -> void          // 16-byte key
def aes_encrypt_block(AES_CTX* ctx, byte* plaintext, byte* ciphertext) -> void  // 16-byte blocks
def aes_decrypt_block(AES_CTX* ctx, byte* ciphertext, byte* plaintext) -> void
```

**Example** (SHA-256):
```flux
#import "cryptography.fx";
using standard::crypto::hashing::SHA256;

byte[32] hash;
SHA256_CTX ctx;
sha256_init(@ctx);
sha256_update(@ctx, data, data_len);
sha256_final(@ctx, @hash[0]);
```

---

### bigint.fx

**Purpose**: Arbitrary-precision integer arithmetic

**Namespace**: `math::bigint`

**Dependencies**: `math.fx`

#### BigInt Structure

```flux
struct BigInt { /* limb array, length, sign */ };
```

#### Construction

```flux
def bigint_zero(BigInt* num) -> void
def bigint_one(BigInt* num) -> void
def bigint_from_uint(BigInt* num, uint value) -> void
def bigint_from_u64(BigInt* num, u64 value) -> void
```

#### Predicates

```flux
def bigint_is_zero(BigInt* num) -> bool
def bigint_is_one(BigInt* num) -> bool
```

#### Arithmetic

```flux
def bigint_add(BigInt* result, BigInt* a, BigInt* b) -> void
def bigint_sub(BigInt* result, BigInt* a, BigInt* b) -> void
def bigint_mul(BigInt* result, BigInt* a, BigInt* b) -> void  // Karatsuba for large inputs
def bigint_divmod(BigInt* quotient, BigInt* remainder, BigInt* a, BigInt* b) -> void
def bigint_div(BigInt* result, BigInt* a, BigInt* b) -> void
def bigint_mod(BigInt* result, BigInt* a, BigInt* b) -> void
def bigint_pow_uint(BigInt* result, BigInt* base, uint exp) -> void
```

#### Bit Shifts

```flux
def bigint_shl(BigInt* result, BigInt* a, uint n) -> void
def bigint_shr(BigInt* result, BigInt* a, uint n) -> void
```

#### Comparison and Utilities

```flux
def bigint_cmp(BigInt* a, BigInt* b) -> int  // -1, 0, 1
def bigint_cmp_abs(BigInt* a, BigInt* b) -> int
def bigint_copy(BigInt* dest, BigInt* src) -> void
def bigint_normalize(BigInt* num) -> void
def bigint_print(BigInt* num) -> void
def bigint_print_hex(BigInt* num) -> void
def bigint_print_decimal(BigInt* num) -> void
```

---

### decimal.fx

**Purpose**: Arbitrary-precision decimal arithmetic

**Namespace**: `math::decimal`

**Dependencies**: `bigint.fx`

#### Decimal Structure

```flux
struct Decimal { BigInt coefficient; i32 exponent; bool negative; };
```

#### Precision Control

```flux
def decimal_set_precision(i32 prec) -> void
def decimal_get_precision() -> i32
```

#### Construction

```flux
def decimal_zero(Decimal* d) -> void
def decimal_one(Decimal* d) -> void
def decimal_from_i64(Decimal* d, i64 value) -> void
def decimal_from_u64(Decimal* d, u64 value) -> void
def decimal_from_string(Decimal* d, byte* s) -> void
def decimal_copy(Decimal* dest, Decimal* src) -> void
```

#### Arithmetic

```flux
def decimal_add(Decimal* result, Decimal* a, Decimal* b) -> void
def decimal_sub(Decimal* result, Decimal* a, Decimal* b) -> void
def decimal_mul(Decimal* result, Decimal* a, Decimal* b) -> void
def decimal_div(Decimal* result, Decimal* a, Decimal* b) -> void
def decimal_mod(Decimal* result, Decimal* a, Decimal* b) -> void
def decimal_pow_int(Decimal* result, Decimal* base, i32 exp) -> void
def decimal_neg(Decimal* result, Decimal* a) -> void
def decimal_abs(Decimal* result, Decimal* a) -> void
def decimal_sqrt(Decimal* result, Decimal* a) -> void
```

**Important**: Never pass the same pointer as both input and output (alias corruption). Always route through an intermediate variable:

```flux
Decimal tmp;
decimal_div(@tmp, @zoom, @two);  // Correct
decimal_copy(@zoom, @tmp);
// NOT: decimal_div(@zoom, @zoom, @two)  // Wrong - alias corruption
```

#### Rounding and Truncation

```flux
def decimal_round(Decimal* result, Decimal* a, i32 places) -> void
def decimal_truncate(Decimal* result, Decimal* a, i32 places) -> void
def decimal_floor(Decimal* result, Decimal* a) -> void
def decimal_ceil(Decimal* result, Decimal* a) -> void
```

#### Comparison and Predicates

```flux
def decimal_cmp(Decimal* a, Decimal* b) -> i32  // -1, 0, 1
def decimal_cmp_abs(Decimal* a, Decimal* b) -> i32
def decimal_is_zero(Decimal* d) -> bool
def decimal_is_negative(Decimal* d) -> bool
def decimal_is_positive(Decimal* d) -> bool
```

#### Output

```flux
def decimal_to_double(Decimal* d) -> double
def decimal_print(Decimal* d) -> void
def decimal_print_sci(Decimal* d) -> void  // Scientific notation
```

---

### net_windows.fx / socket_object_raw.fx

**Purpose**: TCP/UDP networking (Windows Sockets API — Winsock2)

**Namespace**: `standard::sockets`

**Platform**: Windows only

**Description**:  
`net_windows.fx` is the thin glue file that sets up the guard macro and imports `socket_object_raw.fx`. All actual networking functionality lives in `socket_object_raw.fx` under the `standard::sockets` namespace. Importing either file makes the full API available. A `using standard::sockets;` directive is emitted automatically at the bottom of `socket_object_raw.fx`.

#### Structures

```flux
struct sockaddr_in
{
    u16 sin_family, sin_port;
    u32 sin_addr;
    byte[8] sin_zero;
};

struct sockaddr  { u16 sa_family; byte[14] sa_data; };

struct WSAData
{
    u16 wVersion, wHighVersion;
    byte[257] szDescription;
    byte[129] szSystemStatus;
    u16 iMaxSockets, iMaxUdpDg;
    u64* lpVendorInfo;
};

struct timeval { i32 tv_sec, tv_usec; };

enum socket_type  { TCP, UDP };
enum socket_error { OK, NOT_OPEN, BIND_FAILED, CONNECT_FAILED,
                    LISTEN_FAILED, SEND_FAILED, RECV_FAILED, INVALID_TYPE };
```

#### Constants

```flux
// Address families
AF_INET = 2, AF_INET6 = 23

// Socket types
SOCK_STREAM = 1, SOCK_DGRAM = 2, SOCK_RAW = 3

// Protocols
IPPROTO_TCP = 6, IPPROTO_UDP = 17

// Socket option level
SOL_SOCKET = 0xFFFF

// Common socket options
SO_REUSEADDR = 0x0004, SO_KEEPALIVE = 0x0008, SO_BROADCAST = 0x0020
SO_RCVBUF = 0x1002, SO_SNDBUF = 0x1001
SO_RCVTIMEO = 0x1006, SO_SNDTIMEO = 0x1005

// Special addresses
INADDR_ANY = 0x00000000
INADDR_LOOPBACK = 0x7F000001
INADDR_BROADCAST = 0xFFFFFFFF

// WSA errors
WSAEWOULDBLOCK = 10035, WSAECONNRESET = 10054, WSAETIMEDOUT = 10060

// ioctlsocket
FIONBIO = 0x8004667E, FIONREAD = 0x4004667F
WINSOCK_VERSION = 0x0202
```

#### Initialization

```flux
def init() -> int           // WSAStartup (call before any socket ops)
def cleanup() -> int        // WSACleanup
def get_last_error() -> int // WSAGetLastError
```

#### Socket Creation

```flux
def tcp_socket() -> int
def udp_socket() -> int
```

#### Address Helpers

```flux
def init_sockaddr(sockaddr_in* addr, u32 ip_addr, u16 port) -> void
def init_sockaddr_str(sockaddr_in* addr, byte* ip_str, u16 port) -> void
def get_ip_string(sockaddr_in* addr) -> byte*
def get_port(sockaddr_in* addr) -> u16
def port_ntoh(u16 net_port) -> u16
def port_hton(u16 host_port) -> u16
```

#### Socket Options

```flux
def set_nonblocking(int sockfd) -> int
def set_blocking(int sockfd) -> int
def set_reuseaddr(int sockfd, bool enable) -> int
def set_recv_timeout(int sockfd, int milliseconds) -> int
def set_send_timeout(int sockfd, int milliseconds) -> int
def is_valid_socket(int sockfd) -> bool
```

#### TCP Helpers

```flux
def tcp_server_create(u16 port, int backlog) -> int
def tcp_server_accept(int server_sockfd, sockaddr_in* client_addr) -> int
def tcp_client_connect(byte* ip_addr, u16 port) -> int
def tcp_send(int sockfd, byte[] data, int length) -> int
def tcp_recv(int sockfd, byte[] buffer, int buffer_size) -> int
def tcp_send_all(int sockfd, byte[] data, int length) -> int
def tcp_recv_all(int sockfd, byte[] buffer, int length) -> int
def tcp_close(int sockfd) -> int
```

#### UDP Helpers

```flux
def udp_socket_bind(u16 port) -> int
def udp_send(int sockfd, byte[] data, int length, byte* dest_ip, u16 dest_port) -> int
def udp_recv(int sockfd, byte[] buffer, int buffer_size, sockaddr_in* src_addr) -> int
def udp_close(int sockfd) -> int
```

#### socket Object (OOP Interface)

The `socket` object wraps a file descriptor and provides a method-based interface:

```flux
object socket
{
    int fd, type, error_state;
    bool is_server, connected;
    sockaddr_in local_addr, remote_addr;

    def __init(int sock_type) -> this,   // sock_type: socket_type.TCP or socket_type.UDP

        // Status
        is_open() -> bool,
        close() -> bool,
        get_error() -> int,

        // TCP server
        bind(u16 port) -> bool,
        listen(int backlog) -> bool,
        accept() -> socket,

        // TCP client
        connect(byte* ip_addr, u16 port) -> bool,

        // Send / receive (TCP or UDP)
        send(byte* data, int length) -> int,
        recv(byte* buffer, int buffer_size) -> int,
        send_all(byte* data, int length) -> int,
        recv_all(byte* buffer, int length) -> int,

        // UDP specific
        sendto(byte* data, int length, byte* dest_ip, u16 dest_port) -> int,
        recvfrom(byte* buffer, int buffer_size, sockaddr_in* src_addr) -> int,

        // Options
        set_nonblocking(bool enable) -> bool,
        set_reuseaddr(bool enable) -> bool,
        set_recv_timeout(int ms) -> bool,
        set_send_timeout(int ms) -> bool,

        // Info
        get_local_port() -> u16,
        get_remote_ip() -> byte*,
        get_remote_port() -> u16,
        is_tcp() -> bool,
        is_udp() -> bool;
};
```

**Example**:

```flux
#import "net_windows.fx";

def main() -> int
{
    init();
    socket server(socket_type.TCP);
    server.fd = tcp_socket();
    server.bind(8080);
    server.listen(5);
    socket client = server.accept();
    byte[1024] buf;
    int n = client.recv(@buf[0], 1024);
    cleanup();
    return 0;
};
```

---

### uuid.fx

**Purpose**: UUID generation (versions 1, 4, and 7)

**Namespace**: `standard::uuid`

**Dependencies**: `random.fx`

#### UUID Structure

```flux
struct UUID { /* 16 bytes */ };
```

#### Generation

```flux
def uuid_v4(UUID* uuid, PCG32* rng) -> void       // Random UUID
def uuid_v4_quick(UUID* uuid) -> void              // Auto-seeded
def uuid_v7(UUID* uuid, PCG32* rng) -> void       // Time-ordered UUID
def uuid_v7_quick(UUID* uuid) -> void
def uuid_v1(UUID* uuid, PCG32* rng) -> void       // Time-based UUID
def uuid_v1_quick(UUID* uuid) -> void
def uuid_nil(UUID* uuid) -> void                   // All-zero UUID
def uuid_generate_batch_v4(UUID* uuids, int count, PCG32* rng) -> void
```

#### String Conversion

```flux
def uuid_to_string(UUID* uuid, byte* buffer) -> void        // Lowercase, 37-byte buffer
def uuid_to_string_upper(UUID* uuid, byte* buffer) -> void  // Uppercase
def uuid_to_hex(UUID* uuid, byte* buffer) -> void           // 32 hex chars, no dashes
```

#### Utilities

```flux
def uuid_equals(UUID* a, UUID* b) -> bool
def uuid_is_nil(UUID* uuid) -> bool
def uuid_version(UUID* uuid) -> int
def uuid_copy(UUID* dest, UUID* src) -> void
```

---

### sharedmemory.fx

**Purpose**: Named shared memory regions visible across processes

**Namespace**: `standard::sharedmemory`

#### SharedMem Structure

```flux
struct SharedMem { /* handle, mapping pointer, size, name */ };
```

#### Lifecycle

```flux
def shm_create(SharedMem* out, byte* name, size_t size) -> int      // Create new region
def shm_open_existing(SharedMem* out, byte* name, size_t size) -> int // Open existing
def shm_map(SharedMem* shm, u32 access) -> void*  // Map into address space
def shm_flush(SharedMem* shm) -> int
def shm_unmap(SharedMem* shm) -> int
def shm_close(SharedMem* shm) -> int
def shm_destroy(SharedMem* shm, byte* name) -> int  // Unmap + close + delete
```

---

### format.fx

**Purpose**: ANSI color codes, text formatting, borders, and separators

**Namespace**: `standard::format`

**Guard macro**: `FLUX_STANDARD_FORMAT`

#### Color Constants (`standard::format::colors`)

Pre-built ANSI escape strings as global `byte[]` constants:

```flux
RESET, BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, WHITE
BRIGHT_BLACK, BRIGHT_RED, BRIGHT_GREEN, BRIGHT_YELLOW
BRIGHT_BLUE, BRIGHT_MAGENTA, BRIGHT_CYAN, BRIGHT_WHITE
BG_BLACK, BG_RED, BG_GREEN, BG_YELLOW, BG_BLUE, BG_MAGENTA, BG_CYAN, BG_WHITE
BG_BRIGHT_BLACK ... BG_BRIGHT_WHITE
```

#### Printing Utilities

```flux
def print_charn(char c, int count) -> void          // Print char N times
def print_repeat(byte* str, int count) -> void
def print_separator(char c, int width) -> void
def hline(int width) -> void                        // Unicode box-drawing line
def hline_heavy(int width) -> void
def hline_light(int width) -> void
```

#### Colored Output

```flux
def print_colored(byte* text, byte* color) -> void
def println_colored(byte* text, byte* color) -> void
def print_red(byte* text) -> void
def print_green(byte* text) -> void
def print_blue(byte* text) -> void
def print_yellow(byte* text) -> void
def print_cyan(byte* text) -> void
def print_magenta(byte* text) -> void
```

#### Text Styling

```flux
def print_styled(byte* text, byte* style) -> void
def print_bold(byte* text) -> void
def print_italic(byte* text) -> void
def print_underline(byte* text) -> void
```

#### Borders and Boxes

```flux
def print_box_top(int width, bool double_line) -> void
def print_box_bottom(int width, bool double_line) -> void
```

---

### console.fx

**Purpose**: TUI cursor positioning, color control, and region management (Windows)

**Namespace**: `standard::io::console`

**Guard macro**: `FLUX_STANDARD_CONSOLE`

**Platform**: Windows only

**Usage**:
```flux
#import "console.fx";
using standard::io::console;

Console con;
con.cursor_set(0, 23);
con.set_attr(CON_FG_GREEN | CON_BG_BLACK);
con.write("Progress: [####      ] 40%\0");
con.reset_attr();
```

#### Coordinate Helpers

```flux
def make_coord(i16 x, i16 y) -> i32  // Pack (x, y) into COORD DWORD
def coord_x(i32 coord) -> i16
def coord_y(i32 coord) -> i16
```

#### Console Object

```flux
object Console
{
    def __init() -> this,
    
        refresh_size() -> void,
        get_width() -> i16,
        get_height() -> i16,
    
        cursor_set(i16 x, i16 y) -> void,
        cursor_get() -> i32,           // Packed COORD
        cursor_save() -> void,
        cursor_restore() -> void,
        cursor_visible(bool visible) -> void,
    
        set_attr(i16 attr) -> void,
        save_attr() -> void,
        restore_attr() -> void,
        reset_attr() -> void,
    
        write(byte* msg) -> void,
        write_at(i16 x, i16 y, byte* msg) -> void,
        write_at_colored(i16 x, i16 y, i16 attr, byte* msg) -> void,
    
        clear_line(i16 y) -> void,
        clear_line_attr(i16 y, i16 attr) -> void,
        clear_region(i16 x, i16 y, i16 w, i16 h) -> void,
        clear_screen() -> void,
        scroll_up(i16 top_row, i16 bottom_row, i16 lines) -> void,
    
        progress_bar(i16 row, byte* label, i32 done, i32 total) -> void,
        spinner(i16 x, i16 y, i32 tick) -> void;
};
```

---

### graphing.fx

**Purpose**: 2D line graphs, bar charts, scatter plots, and a full 3D graphing system

**Namespace**: `standard::graphing` / `standard::graphing::graph3d`

#### 2D Graphing

```flux
struct Graph { /* dimensions, axes, data series */ };
```

Provides terminal-based 2D rendering of line graphs, bar charts, and scatter plots with configurable axes and grid.

#### 3D Graphing

```flux
struct Graph3D { /* 3D axes, parametric data generators */ };
```

Full 3D graphing system with parametric surface and curve generators.

---

### opengl.fx

**Purpose**: OpenGL context setup and rendering helpers via Win32 WGL

**Namespace**: `standard::system::windows` (OpenGL section)

**Platform**: Windows only

#### Context Setup

```flux
def setup_opengl(HDC device_context) -> HGLRC
def swap_buffers(HDC device_context) -> void
def gl_load_extensions() -> void
```

#### Shader Utilities

```flux
def compile_shader(int shader_type, byte* src) -> int
def link_program(int vert, int frag) -> int
```

#### Matrix Math (for shaders)

```flux
struct Matrix4 { /* 4x4 float matrix */ };
struct GLVec3  { float x, y, z; };

def mat4_identity(Matrix4* out) -> void
def mat4_mul(Matrix4* a, Matrix4* b, Matrix4* out) -> void
def mat4_perspective(float fovy_rad, float aspect, float near_z, float far_z, Matrix4* out) -> void
def mat4_ortho(float left, float right, float bottom, float top, float near_z, float far_z, Matrix4* out) -> void
def mat4_translate(float tx, float ty, float tz, Matrix4* out) -> void
def mat4_scale(float sx, float sy, float sz, Matrix4* out) -> void
def mat4_rotate(float ax, float ay, float az, float angle_rad, Matrix4* out) -> void
def vec3_dot(GLVec3* a, GLVec3* b) -> float
```

---

### windows.fx

**Purpose**: Win32 window creation and GDI drawing

**Namespace**: `standard::system::windows`

**Platform**: Windows only

#### Structures

```flux
struct MSG          { /* Windows message */ };
struct WNDCLASSEXA  { /* Window class descriptor */ };
struct RECT         { left, top, right, bottom; };
struct PAINTSTRUCT  { /* Paint context */ };
```

#### Helpers

```flux
def DefaultWindowProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) -> LRESULT
def RGB(byte r, byte g, byte b) -> DWORD
```

#### Window Object

```flux
object Window
{
    def __init(byte* title, int w, int h, int x, int y) -> this,
        __exit() -> void,
    
        show() -> void,
        hide() -> void,
        set_title(byte* title) -> void,
        process_messages() -> bool;  // Returns false on WM_QUIT
};
```

#### Canvas Object

```flux
object Canvas
{
    def __init(HWND hwnd, HDC hdc) -> this,
        __exit() -> void,
    
        clear(DWORD color) -> void,
        set_pen(DWORD color, int width) -> void,
        line(int x1, int y1, int x2, int y2) -> void,
        circle(int cx, int cy, int r) -> void;
};
```

---

### detour.fx

**Purpose**: x86-64 inline hook / detour (Windows)

**Platform**: Windows only (x86-64)

#### Detour Object

```flux
object Detour
{
    def __init() -> this,
        __exit() -> void,
    
        install(ulong target, ulong hook) -> bool,
        uninstall() -> bool,
        call_original(ulong arg) -> ulong;
};
```

**Description**: Patches a 14-byte absolute jump at `target` to redirect execution to `hook`. Saves the original bytes so the original function can be called via `call_original`. Uses `VirtualProtect` to temporarily make the target page writable and `FlushInstructionCache` after patching.

---

---

### operators.fx

**Purpose**: Extended operator utilities

**Namespace**: `standard::operators`

**Description**: Supplementary operator implementations and overloads not covered by the core language or other modules.

---

### crc32.fx

**Purpose**: CRC32 checksum computation (IEEE 802.3, reflected polynomial 0xEDB88320)

**Namespace**: `crc32`

**Guard macro**: `FLUX_STANDARD_STRINGS` (imports `string_utilities.fx`)

#### Functions

```flux
def crc32::compute(byte* buf, uint length) -> uint
def crc32::of_string(byte* str) -> uint
```

`compute` builds the lookup table internally and processes `length` bytes from `buf`. `of_string` is a convenience wrapper that calls `strlen` first.

**Example**:
```flux
#import "crc32.fx";

uint checksum = crc32::compute(@data[0], data_len);
uint hash     = crc32::of_string("hello\0");
```

---

### dotenv.fx

**Purpose**: `.env` file parser and environment variable loader

**Author**: reinitd

**Namespace**: `dotenv`

**Platform**: Windows and Linux/macOS (conditional compilation)

**Guard macro**: `FLUX_DOTENV`

**Description**:  
Loads `key=value` pairs from a `.env` file into the process environment via `_putenv_s` (Windows) or `setenv` (POSIX). Supports `${VAR}` substitution within values. Lines beginning with `#` or `;` are treated as comments.

#### Error Codes (`dotenv::err`)

```flux
dotenv::err::OK                  =  0   // Success
dotenv::err::ERR_FILE_NOT_FOUND  = -1   // fopen returned 0
dotenv::err::ERR_ALLOC_FAILED    = -2   // fmalloc or frealloc returned 0
dotenv::err::ERR_SETENV_FAILED   = -3   // _putenv_s or setenv failed
dotenv::err::ERR_INVALID_FORMAT  = -4   // Malformed line in .env file
dotenv::err::ERR_NULL_POINTER    = -5   // Null pointer passed for path or buffer
dotenv::err::ERR_READ_FAILED     = -6   // File exists but could not be read
```

#### Functions

```flux
def dotenv::loadenv(byte* path, bool overwrite, bool verbose) -> int
def dotenv::setenv(byte* name, byte* value, bool overwrite) -> int
```

`loadenv` opens the file at `path`, parses every non-comment line as `KEY=value`, optionally replaces existing variables (`overwrite`), and optionally logs parsing details (`verbose`). Returns a `dotenv::err` code.

**Example**:
```flux
#import <standard.fx>;
#import "dotenv.fx";

extern { def !!getenv(byte* name) -> byte*; };

int result = dotenv::loadenv(".env\0", true, false);
if (result != dotenv::err::OK) { return 1; };

byte* host = getenv("DB_HOST\0");
if ((u64)host != 0) { print(host); };
```

---

### json.fx

**Purpose**: JSON parse, build, and serialize library

**Namespace**: `json`

**Guard macro**: `FLUX_JSON`

**Dependencies**: `standard.fx`, `allocators.fx` (uses `stdarena` for zero-copy parsing)

**Description**:  
Provides four main types: `JSONArray`, `JSONObject`, `JSONNode`, and `JSONParser`. An arena-backed serializer (`serialize_arena`) supports zero-allocation output. Zero-copy string support: parsed string values are views into the source text buffer; call `as_string_view()` for these, and `as_string()` only for strings set via `set_string()`.

#### Type Codes

```flux
json::JSON_NULL   = 0
json::JSON_BOOL   = 1
json::JSON_INT    = 2
json::JSON_FLOAT  = 3
json::JSON_STRING = 4
json::JSON_ARRAY  = 5
json::JSON_OBJECT = 6
```

#### JSONNode

```flux
object JSONNode
{
    def __init() -> this,
        __exit() -> void,

        // Type queries
        is_null() -> bool,   is_bool() -> bool,
        is_int() -> bool,    is_float() -> bool,
        is_string() -> bool, is_array() -> bool,
        is_object() -> bool,

        // Setters
        set_null() -> void,
        set_bool(bool v) -> void,
        set_int(i64 v) -> void,
        set_float(double v) -> void,
        set_string(byte* src) -> bool,
        set_string_arena(byte* src, Arena* a) -> bool,
        set_array() -> void,
        set_object() -> void,
        set_array_arena(Arena* a) -> void,
        set_object_arena(Arena* a) -> void,

        // Value getters
        as_bool() -> bool,
        as_int() -> i64,
        as_float() -> double,
        as_string() -> byte*,       // For set_string'd values only
        as_string_view() -> byte*,  // Zero-copy; valid only while source buffer lives

        // Array operations
        array_push_new() -> void*,                   // Appends a new JSONNode; returns it
        array_push_new_arena(Arena* a) -> void*,
        array_len() -> size_t,
        array_get(size_t i) -> void*,                // Cast result to JSONNode*

        // Object operations
        object_set_new(byte* key) -> void*,          // Inserts new node for key; returns it
        object_set_new_arena(byte* key, Arena* a) -> void*,
        object_get(byte* key) -> void*,              // Cast result to JSONNode*
        object_has(byte* key) -> bool,
        object_len() -> size_t,
        object_key_at(size_t i) -> byte*,
        object_val_at(size_t i) -> void*;            // Cast to JSONNode*
};
```

#### JSONParser

```flux
object JSONParser
{
    def __init(byte* text, int text_len, Arena* a) -> this,
        ok() -> bool,
        parse(JSONNode* node) -> bool;  // Returns true on success
};
```

#### Serialization

```flux
// Stack-allocated buffer serializer (caller supplies buffer)
def json::serialize(JSONNode* node, byte* buf, int pos, int cap) -> int  // Returns end position

// Arena-backed serializer (allocates dynamically)
def json::serialize_arena(JSONNode* node, Arena* a, int init_cap) -> byte*  // Returns heap string
```

#### node_free

```flux
def json::node_free(void* p) -> void  // Free a heap-allocated JSONNode (avoids __exit self-ref)
```

**Example**:
```flux
#import "json.fx";
using json;

Arena a;
arena_init(@a);
JSONNode root;
root.set_object_arena(@a);
JSONNode* name = (JSONNode*)root.object_set_new_arena("name\0", @a);
name.set_string_arena("Flux\0", @a);
byte* out = serialize_arena(@root, @a, 128);
print(out);
arena_destroy(@a);
```

---

### matrices.fx

**Purpose**: 3×3, 4×4, and 5×5 matrix mathematics

**Namespace**: `standard::matrices`

**Guard macro**: `FLUX_STANDARD_MATRICES`

**Dependencies**: `types.fx`, `vectors.fx`

#### Structures

```flux
struct Mat3 { float m00..m22; };   // Row-major 3×3
struct Mat4 { float m00..m33; };   // Row-major 4×4
struct Mat5 { float m00..m44; };   // Row-major 5×5
```

#### Mat3 API

**Construction**:
```flux
def mat3_zero() -> Mat3
def mat3_identity() -> Mat3
def mat3_from_rows(Vec3 r0, Vec3 r1, Vec3 r2) -> Mat3
def mat3_from_columns(Vec3 c0, Vec3 c1, Vec3 c2) -> Mat3
def mat3_diagonal(Vec3 d) -> Mat3
```

**Arithmetic**:
```flux
def mat3_add(Mat3 a, Mat3 b) -> Mat3
def mat3_sub(Mat3 a, Mat3 b) -> Mat3
def mat3_mul(Mat3 a, Mat3 b) -> Mat3
def mat3_mul_scalar(Mat3 m, float s) -> Mat3
def mat3_mul_vec3(Mat3 m, Vec3 v) -> Vec3
```

**Properties**:
```flux
def mat3_trace(Mat3 m) -> float
def mat3_determinant(Mat3 m) -> float
def mat3_transpose(Mat3 m) -> Mat3
def mat3_cofactor(Mat3 m) -> Mat3
def mat3_adjugate(Mat3 m) -> Mat3
def mat3_inverse(Mat3 m) -> Mat3
def mat3_is_invertible(Mat3 m) -> bool
def mat3_frobenius_norm(Mat3 m) -> float
```

**Transforms**:
```flux
def mat3_scale_uniform(float s) -> Mat3
def mat3_scale(Vec3 s) -> Mat3
def mat3_rotation_x(float angle) -> Mat3
def mat3_rotation_y(float angle) -> Mat3
def mat3_rotation_z(float angle) -> Mat3
def mat3_rotation_axis_angle(Vec3 axis, float angle) -> Mat3
```

#### Mat4 API

Mirrors the Mat3 API with Vec4 variants, plus:

```flux
def mat4_submatrix(Mat4 m, i32 i, i32 j) -> Mat3
def mat4_rotation_plane(i32 axis1, i32 axis2, float angle) -> Mat4
def mat4_perspective(float fovy_rad, float aspect, float near_z, float far_z, Mat4* out) -> void
def mat4_lookat(Vec3* eye, Vec3* target, Vec3* up, Mat4* out) -> void
```

#### Mat5 API

Mirrors Mat3/Mat4 for 5×5 matrices. Construction, arithmetic, trace, determinant, transpose, and cofactor are available. Full inverse not provided; use Mat4 for graphics transforms.

---

### fourier.fx

**Purpose**: Discrete and Fast Fourier Transforms

**Namespace**: `standard::math::fourier`

**Guard macro**: `FLUX_FOURIER`

**Dependencies**: `types.fx`, `math.fx`, `memory.fx`

**Note**: Requires a `Complex` struct (re/im double fields) to be defined before use — typically provided by `math.fx` or the calling module.

#### Complex Number Helpers

```flux
def complex_add(Complex* result, Complex* a, Complex* b) -> void
def complex_sub(Complex* result, Complex* a, Complex* b) -> void
def complex_mul(Complex* result, Complex* a, Complex* b) -> void
def complex_mag(Complex* c) -> double
def complex_phase(Complex* c) -> double
def complex_from_polar(Complex* result, double mag, double phase) -> void
```

#### Transform Functions

```flux
// Naive O(N²) DFT
def dft(Complex* out, Complex* xin, i32 n) -> void
def idft(Complex* out, Complex* xin, i32 n) -> void   // Inverse DFT (unnormalized)

// O(N log N) Cooley-Tukey FFT (N must be a power of two)
def fft(Complex* buf, i32 n) -> void    // In-place, forward
def ifft(Complex* buf, i32 n) -> void   // In-place, inverse (unnormalized)
```

#### Utilities

```flux
def is_power_of_two(i32 n) -> bool
def next_power_of_two(i32 n) -> i32
def fft_alloc(i32 n) -> Complex*         // fmalloc n Complex structs
def fft_load_real(Complex* buf, double* samples, i32 n) -> void
def fft_magnitude(double* mag, Complex* buf, i32 n) -> void
```

**Example**:
```flux
#import "fourier.fx";
using standard::math::fourier;

i32 n = 512;
Complex* buf = fft_alloc(n);
fft_load_real(buf, @samples[0], n);
fft(buf, n);
double[256] mag;
fft_magnitude(@mag[0], buf, n);
ffree((u64)buf);
```

---

### physics.fx

**Purpose**: Rigid body and soft body physics engine

**Namespace**: `standard::physics`

**Guard macro**: `FLUX_PHYSICS`

**Dependencies**: `types.fx`, `math.fx`, `vectors.fx`, `matrices.fx`

#### Rigid Body

##### Structures

```flux
struct SphereCollider { Vec3 center; float radius; };
struct AABBCollider   { Vec3 half_extents; };
struct PlaneCollider  { Vec3 normal; float dist; };
struct Collider       { /* union of sphere/aabb/plane */ };

struct RigidBody      { Vec3 pos, vel, force, ang_vel, torque;
                        Quat orientation; Mat3 inertia_inv_local;
                        float mass, inv_mass, restitution, friction;
                        i32 collider_type; Collider collider;
                        bool sleeping; i32 sleep_frames; };

struct Contact        { Vec3 point, normal; float penetration;
                        RigidBody* a; RigidBody* b; };

struct PhysWorld      { RigidBody* bodies; Contact* contacts;
                        i32 body_count, body_cap, contact_cap;
                        Vec3 gravity; };

struct Quat           { float x, y, z, w; };
```

##### Quaternion Math

```flux
def quat_identity() -> Quat
def quat_mul(Quat a, Quat b) -> Quat
def quat_integrate(Quat* q, Vec3 omega, float dt) -> void
def quat_rotate(Quat q, Vec3 v) -> Vec3
def quat_to_mat3(Quat q) -> Mat3
```

##### Body Construction

```flux
def body_init_sphere(RigidBody* b, Vec3 pos, float radius, float mass) -> void
def body_init_aabb(RigidBody* b, Vec3 pos, Vec3 half_extents, float mass) -> void
def body_init_plane(RigidBody* b, Vec3 normal, float dist) -> void
```

##### World API

```flux
def world_init(PhysWorld* w, i32 body_cap, i32 contact_cap) -> void
def world_destroy(PhysWorld* w) -> void
def world_set_gravity(PhysWorld* w, Vec3 g) -> void
def world_add_sphere(PhysWorld* w, Vec3 pos, float radius, float mass) -> i32
def world_add_aabb(PhysWorld* w, Vec3 pos, Vec3 half_extents, float mass) -> i32
def world_add_plane(PhysWorld* w, Vec3 normal, float dist) -> i32
def world_get_body(PhysWorld* w, i32 idx) -> RigidBody*
def world_apply_force(PhysWorld* w, i32 idx, Vec3 force) -> void
def world_apply_torque(PhysWorld* w, i32 idx, Vec3 torque) -> void
def world_apply_impulse_at(PhysWorld* w, i32 idx, Vec3 impulse, Vec3 point) -> void
def world_set_material(PhysWorld* w, i32 idx, float restitution, float friction) -> void
def world_step(PhysWorld* w, float dt, i32 iteration_count) -> void
```

#### Soft Body

##### Structures

```flux
struct SoftParticle { Vec3 pos, vel, force; float mass, inv_mass, damping; bool pinned; };
struct SoftSpring   { i32 a, b, kind; float rest_len, stiffness, damping; };
struct SoftBody     { SoftParticle* particles; SoftSpring* springs; i32 pcap, scap, pcount, scount; };
struct SoftWorld    { SoftBody* bodies; i32 body_cap, body_count;
                      Vec3 gravity; bool has_ground;
                      Vec3 ground_normal; float ground_dist; };
```

Spring kinds: `SOFT_SPRING_STRUCTURAL = 0`, `SOFT_SPRING_SHEAR = 1`, `SOFT_SPRING_BEND = 2`

##### SoftBody API

```flux
def softbody_alloc(SoftBody* sb, i32 pcap, i32 scap) -> void
def softbody_free(SoftBody* sb) -> void
def sb_add_particle(SoftBody* sb, Vec3 pos, float mass, float damping) -> i32
def sb_add_spring(SoftBody* sb, i32 a, i32 b, float stiffness, float damping, i32 kind) -> i32
def sb_apply_springs(SoftBody* sb) -> void
def sb_integrate(SoftBody* sb, Vec3 gravity, float dt) -> void
def sb_resolve_ground(SoftBody* sb, Vec3 normal, float dist, float restitution, float friction) -> void
def sb_resolve_sphere(SoftBody* sb, Vec3 sphere_pos, float radius, float restitution) -> void
```

##### SoftWorld API

```flux
def softworld_init(SoftWorld* sw, i32 body_cap) -> void
def softworld_destroy(SoftWorld* sw) -> void
def softworld_set_gravity(SoftWorld* sw, Vec3 g) -> void
def softworld_set_ground(SoftWorld* sw, Vec3 normal, float dist) -> void
def softworld_get_body(SoftWorld* sw, i32 id) -> SoftBody*
def softworld_pin(SoftWorld* sw, i32 body_id, i32 particle_idx) -> void
def softworld_unpin(SoftWorld* sw, i32 body_id, i32 particle_idx, float mass) -> void
def softworld_apply_force(SoftWorld* sw, i32 body_id, i32 particle_idx, Vec3 force) -> void
def softworld_apply_impulse(SoftWorld* sw, i32 body_id, i32 particle_idx, Vec3 impulse) -> void
def softworld_collide_rigid(SoftWorld* sw, PhysWorld* pw) -> void
def softworld_step(SoftWorld* sw, float dt) -> void

// Constructors for common soft body shapes
def softworld_add_rope(SoftWorld* sw, ...) -> i32
def softworld_add_cloth(SoftWorld* sw, Vec3 origin, i32 rows, i32 cols, float spacing,
                        float particle_mass, float damping, float stiffness, float bend_factor) -> i32
def softworld_add_blob(SoftWorld* sw, ...) -> i32
```

**Example**:
```flux
#import "physics.fx";
using standard::physics;

PhysWorld pw;
world_init(@pw, 64, 512);
world_set_gravity(@pw, vec3(0.0, -9.81, 0.0));
i32 ball = world_add_sphere(@pw, vec3(0.0, 5.0, 0.0), 0.5, 1.0);
i32 floor = world_add_plane(@pw, vec3(0.0, 1.0, 0.0), 0.0);
world_step(@pw, 0.016, 6);
world_destroy(@pw);
```

---

### tensors.fx

**Purpose**: Generic N-dimensional tensor library

**Namespace**: `standard::tensors`

**Guard macro**: `FLUX_STANDARD_TENSORS`

**Dependencies**: `types.fx`, `memory.fx`, `math.fx`

**Maximum rank**: 8 (configurable via `TENSOR_MAX_RANK`)

#### Structures

```flux
struct TensorShape { size_t dims[TENSOR_MAX_RANK]; size_t strides[TENSOR_MAX_RANK]; size_t rank; };

object Tensor<T>     { /* owns heap-allocated element buffer */ };
object TensorView<T> { /* non-owning window into a Tensor */ };
```

#### Construction

```flux
def tensor_make<T>(size_t* shape, size_t rank) -> Tensor<T>*          // Zero-filled
def tensor_from_data<T>(T* data, size_t* shape, size_t rank) -> Tensor<T>*
def tensor_scalar<T>(T value) -> Tensor<T>*                            // Rank-0
def tensor_vector<T>(T* data, size_t n) -> Tensor<T>*                 // Rank-1
def tensor_matrix<T>(T* data, size_t rows, size_t cols) -> Tensor<T>* // Rank-2, row-major
```

#### Element Access

```flux
def tensor_get<T>(Tensor<T>* t, size_t* idx) -> T
def tensor_set<T>(Tensor<T>* t, size_t* idx, T v) -> void
def tensor_at<T>(Tensor<T>* t, size_t flat) -> T
def tensor_put<T>(Tensor<T>* t, size_t flat, T v) -> void
```

#### Arithmetic (element-wise, broadcast-safe)

```flux
def tensor_add<T>(Tensor<T>* a, Tensor<T>* b) -> Tensor<T>*
def tensor_sub<T>(Tensor<T>* a, Tensor<T>* b) -> Tensor<T>*
def tensor_mul<T>(Tensor<T>* a, Tensor<T>* b) -> Tensor<T>*
def tensor_div<T>(Tensor<T>* a, Tensor<T>* b) -> Tensor<T>*
def tensor_add_scalar<T>(Tensor<T>* a, T s) -> Tensor<T>*
def tensor_mul_scalar<T>(Tensor<T>* a, T s) -> Tensor<T>*
def tensor_neg<T>(Tensor<T>* a) -> Tensor<T>*
```

#### Reductions

```flux
def tensor_sum<T>(Tensor<T>* t) -> T
def tensor_product<T>(Tensor<T>* t) -> T
def tensor_min<T>(Tensor<T>* t) -> T
def tensor_max<T>(Tensor<T>* t) -> T
def tensor_mean_f(Tensor<float>* t) -> float
def tensor_mean_d(Tensor<double>* t) -> double
```

#### Shape Manipulation

```flux
def tensor_reshape<T>(Tensor<T>* t, size_t* new_shape, size_t new_rank) -> Tensor<T>*
def tensor_transpose<T>(Tensor<T>* t) -> Tensor<T>*
def tensor_permute<T>(Tensor<T>* t, size_t* axes) -> Tensor<T>*
def tensor_slice<T>(Tensor<T>* t, size_t axis, size_t start, size_t end) -> Tensor<T>*
def tensor_squeeze<T>(Tensor<T>* t) -> Tensor<T>*
def tensor_expand_dims<T>(Tensor<T>* t, size_t axis) -> Tensor<T>*
```

#### Linear Algebra

```flux
def tensor_matmul_f(Tensor<float>* a, Tensor<float>* b) -> Tensor<float>*
def tensor_matmul_d(Tensor<double>* a, Tensor<double>* b) -> Tensor<double>*
def tensor_dot_f(Tensor<float>* a, Tensor<float>* b) -> float
def tensor_dot_d(Tensor<double>* a, Tensor<double>* b) -> double
def tensor_outer_f(Tensor<float>* a, Tensor<float>* b) -> Tensor<float>*
def tensor_outer_d(Tensor<double>* a, Tensor<double>* b) -> Tensor<double>*
```

#### Utilities

```flux
def tensor_copy<T>(Tensor<T>* t) -> Tensor<T>*
def tensor_fill<T>(Tensor<T>* t, T value) -> void
def tensor_equal<T>(Tensor<T>* a, Tensor<T>* b) -> bool
def tensor_numel(Tensor<void>* t) -> size_t
def tensor_rank(Tensor<void>* t) -> size_t
def tensor_shape_dim(Tensor<void>* t, size_t axis) -> size_t
def tensor_print_shape(Tensor<void>* t) -> void
```

---

### autograd.fx

**Purpose**: Tape-based reverse-mode automatic differentiation

**Namespace**: `standard` (operates on `Tensor<float>`)

**Guard macro**: `FLUX_STANDARD_AUTOGRAD`

**Dependencies**: `types.fx`, `memory.fx`, `math.fx`

**Description**:  
Records every differentiable operation onto a `Tape` during the forward pass. Calling `backward(@tape, @loss)` walks the tape in reverse and accumulates gradients into each `GradTensor.grad` buffer. One `fmalloc` at `Tape` initialization; no per-op heap allocation.

#### Key Constants

```flux
AG_MAX_INPUTS  = 2    // Max inputs per op node
AG_NO_PRODUCER = -1   // Sentinel for leaf tensors

// Op kinds (stored in GradNode)
AG_OP_NONE=0, AG_OP_ADD=1, AG_OP_SUB=2, AG_OP_MUL=3, AG_OP_MATMUL=4
AG_OP_RELU=5, AG_OP_SIGMOID=6, AG_OP_TANH_ACT=7, AG_OP_SUM=8
AG_OP_SCALE=9, AG_OP_NEG=10
```

#### Structures

```flux
struct GradTensor
{
    float* vals;   // Forward values (owned)
    float* grad;   // Gradient buffer (owned)
    size_t numel;
    i32    tape_slot;   // Index in Tape; -1 if leaf
};

struct GradNode
{
    i32    op_kind;
    i32    input_slots[AG_MAX_INPUTS];
    i32    n_inputs;
    float  scalar;      // For AG_OP_SCALE
};

object Tape
{
    def __init(size_t capacity) -> this,  // capacity = max ops
        __exit() -> void;
};
```

#### Forward Operations

Each function records an op on the tape and returns a new `GradTensor`:

```flux
def gt_init(GradTensor* gt, Tape* tape, float* data, size_t rows, size_t cols) -> void
def grad_add(Tape* tape, GradTensor* a, GradTensor* b) -> GradTensor
def grad_sub(Tape* tape, GradTensor* a, GradTensor* b) -> GradTensor
def grad_mul(Tape* tape, GradTensor* a, GradTensor* b) -> GradTensor
def grad_matmul(Tape* tape, GradTensor* a, GradTensor* b) -> GradTensor
def grad_relu(Tape* tape, GradTensor* x) -> GradTensor
def grad_sigmoid(Tape* tape, GradTensor* x) -> GradTensor
def grad_tanh_act(Tape* tape, GradTensor* x) -> GradTensor
def grad_sum(Tape* tape, GradTensor* x) -> GradTensor    // Reduce to scalar
def grad_scale(Tape* tape, GradTensor* x, float s) -> GradTensor
def grad_neg(Tape* tape, GradTensor* x) -> GradTensor
```

#### Backward Pass

```flux
def backward(Tape* tape, GradTensor* loss) -> void
```

Walks the tape in reverse, calling each op's backward function to accumulate gradients. After `backward`, `a.grad` and `b.grad` contain `dL/dA` and `dL/dB` respectively.

**Example**:
```flux
#import "autograd.fx";

Tape tape((size_t)512);
GradTensor a, b, c;
gt_init(@a, @tape, w_data, rows, cols);
gt_init(@b, @tape, x_data, rows, cols);
c = grad_matmul(@tape, @a, @b);
c = grad_relu(@tape, @c);
backward(@tape, @c);
// a.grad and b.grad now hold dL/dA, dL/dB
```

---

### raytracing.fx

**Purpose**: Physically-based path tracer

**Namespace**: `raytracer`

**Guard macro**: `FLUX_RAYTRACING`

**Dependencies**: `types.fx`, `math.fx`, `vectors.fx`, `memory.fx`, `allocators.fx`, `random.fx`

#### Material Types

```flux
RT_MAT_LAMBERTIAN = 0   // Diffuse
RT_MAT_METAL      = 1   // Specular with fuzz
RT_MAT_DIELECTRIC = 2   // Glass/refraction
RT_MAT_EMISSIVE   = 3   // Light source
```

#### Primitive Types

```flux
RT_PRIM_SPHERE   = 0
RT_PRIM_TRIANGLE = 1
RT_PRIM_PLANE    = 2
```

#### Key Structures

```flux
struct RTMaterial { i32 kind; Vec3 albedo; float fuzz, ior, emission_strength; };
struct RTRay      { Vec3 origin, direction; };
struct RTHit      { Vec3 point, normal; float t; bool front_face; RTMaterial mat; };
struct RTSphere   { Vec3 center; float radius; RTMaterial mat; };
struct RTTriangle { Vec3 a, b, c; Vec3 normal; RTMaterial mat; };
struct RTPlane    { Vec3 normal; float d; RTMaterial mat; };
struct RTScene    { /* primitives, BVH nodes, materials */ };
struct RTCamera   { /* origin, lower_left, horizontal, vertical, lens */ };
```

#### Material Constructors

```flux
def mat_lambertian(Vec3 albedo) -> RTMaterial
def mat_metal(Vec3 albedo, float fuzz) -> RTMaterial
def mat_dielectric(float ior) -> RTMaterial
def mat_emissive(Vec3 colour, float strength) -> RTMaterial
```

#### Scene Building

```flux
def rt_scene_init(RTScene* s, i32 initial_cap) -> void
def rt_scene_free(RTScene* s) -> void
def rt_scene_add_sphere(RTScene* s, Vec3 center, float radius, RTMaterial mat) -> i32
def rt_scene_add_triangle(RTScene* s, Vec3 a, Vec3 b, Vec3 c, RTMaterial mat) -> i32
def rt_scene_add_plane(RTScene* s, Vec3 normal, float d, RTMaterial mat) -> i32
def bvh_build(RTScene* s) -> void    // Build BVH after adding all geometry
```

#### Camera

```flux
def rt_camera_init(RTCamera* cam, Vec3 lookfrom, Vec3 lookat, Vec3 up,
                   float vfov, float aspect, float aperture, float focus_dist) -> void
def rt_camera_get_ray(RTCamera* cam, float s, float t, PCG32* rng) -> RTRay
```

#### Rendering

```flux
// Render full image into caller-supplied u32 (0xAARRGGBB) pixel buffer
def rt_render(RTScene* s, RTCamera* cam, u32* buf,
              i32 width, i32 height, i32 samples_per_pixel, i32 max_depth) -> void

// Single tile (for threading integration)
def rt_render_tile(RTScene* s, RTCamera* cam, u32* buf,
                   i32 width, i32 height, i32 samples_per_pixel, i32 max_depth,
                   i32 tile_x, i32 tile_y, i32 tile_w, i32 tile_h) -> void

// Write PPM image file
def rt_write_ppm(u32* buf, i32 width, i32 height, byte* path) -> bool
```

**Example**:
```flux
#import "raytracing.fx";
using raytracer;

RTScene scene;
rt_scene_init(@scene, 64);
rt_scene_add_sphere(@scene, vec3(0.0, 0.0, -1.0), 0.5, mat_lambertian(vec3(0.8, 0.3, 0.3)));
rt_scene_add_sphere(@scene, vec3(0.0, -100.5, -1.0), 100.0, mat_lambertian(vec3(0.8, 0.8, 0.0)));
bvh_build(@scene);
RTCamera cam;
rt_camera_init(@cam, vec3(0.0,0.0,0.0), vec3(0.0,0.0,-1.0), vec3(0.0,1.0,0.0), 90.0, 1.333, 0.0, 1.0);
u32* buf = (u32*)fmalloc((size_t)(800 * 600 * (sizeof(u32) / 8)));
rt_render(@scene, @cam, buf, 800, 600, 64, 8);
rt_write_ppm(buf, 800, 600, "out.ppm\0");
rt_scene_free(@scene);
ffree((u64)buf);
```

---

### raycasting.fx

**Purpose**: 2.5D tile-based raycaster (Wolfenstein / DOOM style)

**Namespace**: `raycaster`

**Guard macro**: `FLUX_RAYCASTING`

**Dependencies**: `types.fx`, `math.fx`, `vectors.fx`, `memory.fx`, `allocators.fx`

**Coordinate system**: +X = East, +Y = North. Angle 0 = facing East, increases counter-clockwise.

#### Tile Flags

```flux
RC_TILE_EMPTY = 0, RC_TILE_SOLID = 1, RC_TILE_DOOR = 2, RC_TILE_TRANS = 4
```

#### Wall Face IDs

```flux
RC_FACE_NONE=0, RC_FACE_X_POS=1, RC_FACE_X_NEG=2, RC_FACE_Y_POS=3, RC_FACE_Y_NEG=4
```

#### Render Pass Flags

```flux
RC_PASS_SKY=1, RC_PASS_WALLS=2, RC_PASS_FLOOR=4, RC_PASS_SPRITES=8, RC_PASS_ALL=15
```

#### Key Structures

```flux
struct RCTile          { i32 type, tex_id; u32 tint; float alpha; };
struct RCMap           { RCTile* cells; i32 width, height; RCTexturePalette* palette; };
struct RCTexture       { u32* pixels; i32 width, height; };
struct RCTexturePalette{ RCTexture* entries; i32 count, cap; };
struct RCPlayer        { float x, y, angle, move_speed, turn_speed; };
struct RCCamera        { float fov_rad, view_dist; i32 screen_w, screen_h;
                         float dir_x, dir_y, plane_x, plane_y; };
struct RCWallHit       { float dist; i32 face; float u; i32 tex_id; u32 tint; };
struct RCSprite        { float x, y; float dist; i32 tex_id; u32 tint; };
struct RCSky           { u32 top_color, horizon_color; };
struct RCScene         { RCMap* map; RCPlayer* player; RCCamera* cam;
                         RCSky* sky; RCSprite* sprites; i32 sprite_count; };
```

#### Map Management

```flux
def rc_map_init(RCMap* m, i32 width, i32 height) -> void
def rc_map_free(RCMap* m) -> void
def rc_map_get(RCMap* m, i32 x, i32 y) -> RCTile
def rc_map_set(RCMap* m, i32 x, i32 y, RCTile tile) -> void
def rc_map_set_solid(RCMap* m, i32 x, i32 y, i32 tex, u32 tint) -> void
```

#### Player and Camera

```flux
def rc_player_init(RCPlayer* p, float x, float y, float angle) -> void
def rc_camera_init(RCCamera* cam, float fov_deg, i32 sw, i32 sh, float view_dist) -> void
def rc_camera_sync(RCCamera* cam, RCPlayer* p) -> void
def rc_player_move(RCPlayer* p, RCMap* m, float forward, float strafe) -> void
def rc_player_turn(RCPlayer* p, float delta_rad) -> void
```

#### Texture Palette

```flux
def rc_palette_init(RCTexturePalette* pal, i32 initial_cap) -> void
def rc_palette_free(RCTexturePalette* pal) -> void
def rc_palette_add(RCTexturePalette* pal, u32* pixels, i32 w, i32 h) -> i32
def rc_tex_sample(RCTexture* tex, float u, float v) -> u32
```

#### Rendering

```flux
// Low-level passes (return depth buffer / fill buffer)
def rc_cast_walls(RCMap* m, RCCamera* cam, float* depth_buf, RCWallHit* hit_buf) -> void
def rc_cast_floor(RCMap* m, RCCamera* cam, float* depth_buf, u32* buf) -> void
def rc_draw_sky(RCSky* sky, RCCamera* cam, u32* buf) -> void
def rc_draw_walls(RCCamera* cam, RCWallHit* hit_buf, float* depth_buf, u32* buf) -> void
def rc_sprite_distances(RCSprite* sprites, i32 count, RCPlayer* p) -> void
def rc_sprite_sort(RCSprite* sprites, i32 count) -> void
def rc_draw_sprites(RCCamera* cam, RCSprite* sprites, i32 count,
                    float* depth_buf, u32* buf) -> void

// High-level composite render (combines all passes per RC_PASS_* flags)
def rc_render(RCScene* scene, u32* buf) -> void

// Scene convenience init
def rc_scene_init(RCScene* scene, RCMap* map, RCPlayer* player, RCCamera* cam,
                  RCSky* sky) -> void
def rc_scene_set_sprites(RCScene* scene, RCSprite* sprites, i32 count) -> void
```

#### Color Utilities

```flux
def color_pack(float r, float g, float b) -> u32      // Pack [0,1] to 0xAARRGGBB
def color_unpack(u32 argb, float* r, float* g, float* b) -> void
def color_scale(u32 argb, float factor) -> u32
def color_lerp(u32 a, u32 b, float t) -> u32
def color_tint(u32 base, u32 tint) -> u32
def fog_factor(float dist, float view_dist) -> float  // Linear fog [0,1]
```

**Example**:
```flux
#import "raycasting.fx";
using raycaster;

RCMap   map;    rc_map_init(@map, 24, 24);
RCPlayer player; rc_player_init(@player, 2.5, 2.5, 0.0);
RCCamera cam;   rc_camera_init(@cam, 66.0, 320, 240, 16.0);
rc_camera_sync(@cam, @player);
u32* buf = (u32*)fmalloc((size_t)(320 * 240 * (sizeof(u32) / 8)));
RCScene scene;
rc_scene_init(@scene, @map, @player, @cam, NULL);
rc_render(@scene, buf);
rc_map_free(@map);
ffree((u64)buf);
```

---

### wasapi.fx

**Purpose**: WASAPI loopback audio capture (Windows)

**Platform**: Windows only

**Guard macro**: `FLUX_WASAPI`

**Dependencies**: `types.fx`, `windows.fx`

**Description**:  
Captures system audio output as PCM float32 samples by calling COM vtable methods directly. No C++ headers required — vtable slot offsets are fixed by the Windows ABI. Supports both `WAVE_FORMAT_IEEE_FLOAT` and `WAVE_FORMAT_PCM` mix formats.

#### Constants

```flux
AUDCLNT_SHAREMODE_SHARED    = 0u
AUDCLNT_SHAREMODE_EXCLUSIVE = 1u
AUDCLNT_STREAMFLAGS_LOOPBACK     = 0x00020000u
AUDCLNT_STREAMFLAGS_EVENTCALLBACK = 0x00040000u
WAVE_FORMAT_PCM        = 1
WAVE_FORMAT_IEEE_FLOAT = 3
WAVE_FORMAT_EXTENSIBLE = 0xFFFE
eRender = 0u, eCapture = 1u, eConsole = 0u
```

#### Structures

```flux
struct GUID                 { u32 data1; u16 data2, data3; byte[8] data4; };
struct WAVEFORMATEX         { u16 wFormatTag, nChannels; u32 nSamplesPerSec, nAvgBytesPerSec;
                              u16 nBlockAlign, wBitsPerSample, cbSize; };
struct WAVEFORMATEXTENSIBLE { /* WAVEFORMATEX + SubFormat GUID */ };
struct WasapiCapture        { /* COM interface pointers, format, state */ };
```

#### Public API

```flux
def wasapi_init_guids() -> void     // Must be called before wasapi_open
def wasapi_open(WasapiCapture* ctx) -> bool
def wasapi_close(WasapiCapture* ctx) -> void
def wasapi_read_samples(WasapiCapture* ctx, float* out_buf, u32 max_frames) -> u32
```

`wasapi_open` initializes COM, creates the `MMDeviceEnumerator`, activates the default render endpoint for loopback, and starts the stream. `wasapi_read_samples` drains available packet buffers and converts PCM to float32 if necessary. Returns the number of frames written to `out_buf`.

**Example**:
```flux
#import "wasapi.fx";

WasapiCapture cap;
wasapi_init_guids();
if (!wasapi_open(@cap)) { return 1; };
float[4096] samples;
u32 n = wasapi_read_samples(@cap, @samples[0], 4096);
wasapi_close(@cap);
```

---

### oglgraphing.fx

**Purpose**: OpenGL-backed 2D and 3D graphing

**Namespace**: `standard::oglgraphing`

**Dependencies**: `opengl.fx`, `math.fx`

**Description**:  
Mirrors the API of `graphing.fx` exactly, replacing `Canvas*` with implicit global GL state and DWORD colors with float RGB. Coordinates are mapped to NDC via an `OGLGraph` viewport descriptor.

#### Structures

```flux
struct OGLGraph
{
    i32   vp_x, vp_y, vp_w, vp_h;   // Viewport in pixels
    float x_min, x_max, y_min, y_max;
};

struct OGLGraph3D { /* 3D axes + parametric data generators */ };
```

#### 2D API

```flux
def ogl_begin_frame(OGLGraph* g) -> void
def ogl_end_frame() -> void
def draw_axes(OGLGraph* g, float r, float gv, float b, float line_width) -> void
def draw_grid(OGLGraph* g, i32 nx, i32 ny, float r, float gv, float b) -> void
def plot_line(OGLGraph* g, float* xs, float* ys, i32 n,
              float r, float gv, float b, float line_width) -> void
def plot_scatter(OGLGraph* g, float* xs, float* ys, i32 n,
                 float r, float gv, float b, i32 point_size) -> void
def plot_bar(OGLGraph* g, float* xs, float* ys, i32 n,
             float r, float gv, float b) -> void
```

**Example**:
```flux
#import <standard.fx>;
#import "opengl.fx";
#import "oglgraphing.fx";
using standard::oglgraphing;

// Inside render loop:
OGLGraph g;
g.vp_x = 0;  g.vp_y = 0;  g.vp_w = 800;  g.vp_h = 600;
g.x_min = 0.0;  g.x_max = 6.0;  g.y_min = 0.0;  g.y_max = 6.0;
ogl_begin_frame(@g);
draw_axes(@g, 0.8, 0.8, 0.8, 1.0);
draw_grid(@g, 5, 5, 0.2, 0.2, 0.2);
plot_line(@g, @xs[0], @ys[0], 5, 0.0, 0.8, 1.0, 1.5);
ogl_end_frame();
```

---

### datautils.fx

**Purpose**: Low-level byte writer utilities (used internally by `detour.fx`)

**Description**:  
Free functions for writing x86-64 JMP stubs and comparing/copying raw byte buffers. Not namespaced; intended for direct use by patching and instrumentation code.

#### Functions

```flux
def write_jmp_indirect(ulong dst) -> void
    // Write a 6-byte RIP-relative indirect JMP (FF 25 00 00 00 00) at dst.
    // Caller must write the 8-byte absolute target at dst+6.

def write_addr64(ulong dst, ulong addr) -> void
    // Write an 8-byte little-endian absolute address at dst.

def copy_bytes(ulong dst, ulong src, int n) -> void
    // Copy n bytes from src to dst.

def bytes_eq(byte* a, byte* b, int len) -> int
    // Returns 1 if the first len bytes are equal, 0 otherwise.

def fill_buf(byte* buf, int len, byte val) -> void
    // Fill buf with the repeating byte value val.
```

---

### datetime.fx

**Purpose**: Calendar date and time library

**Namespace**: `standard::datetime`

**Guard macro**: `FLUX_DATETIME`

**Dependencies**: `types.fx`, `timing.fx`

**Description**:  
Provides calendar arithmetic, wall-clock access, epoch conversion, formatting, and ISO 8601 parsing. All allocation is on the caller's stack; no heap use. Cross-platform: uses `GetSystemTimeAsFileTime`/`GetLocalTime` on Windows and `clock_gettime` on Linux/macOS.

#### Structures

```flux
struct DateTime
{
    i32 year;
    i32 month;    // 1-12
    i32 day;      // 1-31
    i32 hour;     // 0-23
    i32 minute;   // 0-59
    i32 second;   // 0-59
    i32 ms;       // 0-999
};

struct Date    { i32 year, month, day; };
struct TimeOfDay { i32 hour, minute, second, ms; };
struct Duration  { i64 total_ms; };   // signed millisecond interval
```

#### Wall-Clock Access

```flux
def dt_now_utc()   -> DateTime   // Current UTC time
def dt_now_local() -> DateTime   // Current local time (platform TZ)
```

#### Epoch Conversion (Unix epoch = 1970-01-01 00:00:00 UTC)

```flux
def dt_from_unix_ms(i64 ms)         -> DateTime
def dt_to_unix_ms(DateTime* dt)     -> i64
def dt_from_unix_sec(i64 s)         -> DateTime
def dt_to_unix_sec(DateTime* dt)    -> i64
```

#### Arithmetic

```flux
def dt_add_ms(DateTime* dt, i64 ms)           -> DateTime
def dt_add_days(DateTime* dt, i64 days)        -> DateTime
def dt_diff_ms(DateTime* a, DateTime* b)       -> i64   // a - b
def dt_diff_days(DateTime* a, DateTime* b)     -> i64
```

#### Predicates

```flux
def dt_is_leap(int year)                       -> bool
def dt_day_of_week(DateTime* dt)               -> int   // 0=Sun .. 6=Sat
def dt_day_of_year(DateTime* dt)               -> int   // 1..366
def dt_days_in_month(int year, int month)      -> int
```

#### Comparison

```flux
def dt_cmp(DateTime* a, DateTime* b)  -> int    // <0 a<b, 0 equal, >0 a>b
def dt_eq(DateTime* a, DateTime* b)   -> bool
def dt_lt(DateTime* a, DateTime* b)   -> bool
```

#### Formatting

All format functions write into a caller-supplied buffer and return the number of characters written (excluding the null terminator), or `0` if `cap` is insufficient.

```flux
def dt_format_iso(DateTime* dt, byte* buf, int cap)     -> int
    // "YYYY-MM-DDTHH:MM:SS.mmmZ"  — requires cap >= 25

def dt_format_date(DateTime* dt, byte* buf, int cap)    -> int
    // "YYYY-MM-DD"                 — requires cap >= 11

def dt_format_time(DateTime* dt, byte* buf, int cap)    -> int
    // "HH:MM:SS.mmm"               — requires cap >= 13

def dt_format_rfc1123(DateTime* dt, byte* buf, int cap) -> int
    // "Mon, 02 Jan 2006 15:04:05 GMT" — requires cap >= 30
```

#### Parsing

```flux
def dt_parse_iso(byte* s, DateTime* out) -> bool
```

Accepts:
- `"YYYY-MM-DD"`
- `"YYYY-MM-DDTHH:MM:SS"`
- `"YYYY-MM-DDTHH:MM:SSZ"`
- `"YYYY-MM-DDTHH:MM:SS.mmm"`
- `"YYYY-MM-DDTHH:MM:SS.mmmZ"`

Returns `false` if the string is malformed or out-of-range.

#### Duration Helpers

```flux
def dur_from_ms(i64 ms)       -> Duration
def dur_seconds(Duration* d)  -> i64    // total seconds (truncated)
def dur_minutes(Duration* d)  -> i64    // total minutes (truncated)
def dur_hours(Duration* d)    -> i64    // total hours (truncated)
def dur_days(Duration* d)     -> i64    // total days (truncated)

// Remainder parts (always non-negative):
def dur_ms_part(Duration* d)  -> i64    // 0-999
def dur_sec_part(Duration* d) -> i64    // 0-59
def dur_min_part(Duration* d) -> i64    // 0-59
def dur_hr_part(Duration* d)  -> i64    // 0-23
```

**Example**:
```flux
#import <standard.fx>;
#import "datetime.fx";
using standard::datetime;

def main() -> int
{
    DateTime now;
    byte[25] buf;
    now = dt_now_utc();
    dt_format_iso(@now, @buf[0], 25);
    println(@buf[0]);
    return 0;
};
```

---

### xml.fx

**Purpose**: XML parse, build, and serialize library

**Namespace**: `xml`

**Guard macro**: `FLUX_XML`

**Dependencies**: `standard.fx`, `allocators.fx`

**Description**:  
A recursive descent XML parser and serializer backed entirely by an `Arena` allocator. The caller owns one `Arena` and passes it into every API call; a single `arena_destroy()` releases the entire document tree. UTF-8 source is assumed; no BOM handling. Namespace prefixes are kept verbatim (no resolution).

#### Node Type Constants

```flux
const int XML_ELEMENT = 0;   // Element node (has tag, attrs, children)
const int XML_TEXT    = 1;   // Text content node
const int XML_COMMENT = 2;   // <!-- ... --> comment
const int XML_PI      = 3;   // <?target data?> processing instruction
const int XML_CDATA   = 4;   // <![CDATA[...]]> section
```

Maximum nesting depth: `XML_MAX_DEPTH` (default 256).

#### Structures

```flux
struct XmlAttr
{
    byte* name, value;
};

struct XmlAttrList
{
    XmlAttr* buf;
    size_t   len, cap;
};

struct XmlChildren
{
    void*  buf;
    size_t len, cap;
};

struct XmlNode
{
    int         type;      // XML_ELEMENT | XML_TEXT | XML_COMMENT | XML_PI | XML_CDATA
    byte*       tag;       // Element tag name or PI target; null for text/comment/CDATA
    byte*       text;      // Text content, comment body, PI data, or CDATA content
    XmlAttrList attrs;
    XmlChildren children;
    XmlNode*    parent;
};
```

#### Parsing

```flux
def xml_parse(byte* src, int len, Arena* a) -> XmlNode*
    // Parse src (len bytes of UTF-8 XML) using arena a.
    // Returns the root element, or null on parse error / OOM.
```

Entity references decoded: `&amp;` `&lt;` `&gt;` `&apos;` `&quot;` `&#NNN;` `&#xHH;`.  
DTD declarations (`<!DOCTYPE ...`) are skipped.

#### Node Accessors

```flux
def xml_child_count(XmlNode* n)               -> size_t
def xml_child(XmlNode* n, size_t i)           -> XmlNode*
def xml_attr_count(XmlNode* n)                -> size_t
def xml_attr(XmlNode* n, byte* name)          -> byte*    // null if not found
def xml_first_child_tag(XmlNode* n, byte* tag) -> XmlNode* // null if not found
```

#### Building

```flux
def xml_new_element(Arena* a, byte* tag)                        -> XmlNode*
def xml_new_text(Arena* a, byte* text)                          -> XmlNode*
def xml_new_comment(Arena* a, byte* text)                       -> XmlNode*
def xml_new_pi(Arena* a, byte* target, byte* data)              -> XmlNode*
def xml_new_cdata(Arena* a, byte* text)                         -> XmlNode*
def xml_set_attr(XmlNode* n, Arena* a, byte* name, byte* value) -> bool
def xml_append_child(XmlNode* parent, Arena* a, XmlNode* child) -> bool
```

#### Serialization

```flux
def xml_serialize(XmlNode* node, Arena* a, int init_cap) -> byte*
    // Serialize with "<?xml version="1.0" encoding="UTF-8"?>" declaration.
    // init_cap is the initial buffer guess in bytes (512 is a safe default).
    // Returns a null-terminated arena-owned string, or null on OOM.

def xml_serialize_fragment(XmlNode* node, Arena* a, int init_cap) -> byte*
    // Serialize without the XML declaration (useful for fragments).
```

Output uses 2-space indentation. Attribute values and text content are XML-escaped (`<`, `>`, `&`, `"`, `'`). Elements with no children emit a self-closing tag (`/>`).

**Example**:
```flux
#import <standard.fx>;
#import <xml.fx>;

using standard::io::console,
      xml;

def main() -> int
{
    Arena    a;
    XmlNode* root, child;
    byte*    out;

    stdarena::init(@a, 65536);
    defer stdarena::destroy(@a);

    root  = xml_new_element(@a, "root\0");
    child = xml_new_element(@a, "item\0");

    xml_set_attr(child, @a, "id\0", "1\0");
    xml_append_child(child, @a, xml_new_text(@a, "Hello\0"));
    xml_append_child(root,  @a, child);

    out = xml_serialize(root, @a, 512);

    println(out);
    return 0;
};
```

---

### csv.fx

**Purpose**: CSV parse and write library

**Namespace**: `csv`

**Guard macro**: `FLUX_CSV`

**Dependencies**: `standard.fx`, `ffifio.fx`, `allocators.fx`

**Description**:  
RFC 4180 compliant CSV parser and serializer. Supports configurable delimiters, quoted fields (double-quote escape `""`), and CRLF/LF/CR line endings. All field strings are individually heap-allocated (`fmalloc`); call `csv_free` when done.

#### Structures

```flux
struct CsvRow
{
    byte** fields;   // Array of null-terminated field strings (heap-owned)
    int    count;    // Number of fields in this row
    int    capacity;
};

struct CsvTable
{
    CsvRow** rows;   // Array of row pointers (heap-owned)
    int      count;  // Number of rows
    int      capacity;
};
```

#### Parsing

```flux
def csv_parse_buf(byte* buf, int len, byte delim, CsvTable* out) -> bool
    // Parse a CSV buffer already in memory.
    // delim is typically ','.  Returns false on allocation failure.

def csv_parse_file(byte* path, byte delim, CsvTable* out) -> bool
    // Read a file from disk, then call csv_parse_buf.
    // Returns false if the file cannot be opened or an allocation fails.
```

#### Field Access

```flux
def csv_field(CsvTable* t, int row, int col) -> byte*
    // Return the field at (row, col), both zero-based.
    // Returns a null pointer if either index is out of range.
```

#### Writing

```flux
def csv_write_file(byte* path, CsvTable* t, byte delim) -> bool
    // Serialize the table back to a file.
    // Fields are automatically quoted when they contain the delimiter,
    // a double-quote, CR, or LF.  Returns false if the file cannot be opened.
```

#### Cleanup

```flux
def csv_free(CsvTable* t) -> void
    // Release every field string, every CsvRow, and the row-pointer array.
    // Does not free the CsvTable struct itself (it may be stack-allocated).
```

**Example**:
```flux
#import <standard.fx>;
#import <csv.fx>;

using standard::io::console,
      csv;

def main() -> int
{
    CsvTable t;
    byte*    name;
    byte*    score;

    if (!csv_parse_file("scores.csv\0", ',', @t)) { return 1; };

    // Skip header row; iterate data rows.
    int r = 1;
    while (r < t.count)
    {
        name  = csv_field(@t, r, 0);
        score = csv_field(@t, r, 1);
        if ((u64)name != 0 & (u64)score != 0)
        {
            print(name);
            print(": \0");
            println(score);
        };
        r++;
    };

    csv_free(@t);
    return 0;
};
```

---

### encodings.fx

**Purpose**: Binary-to-text encoding and URL percent-encoding

**Namespace**: `standard::encoding`

**Guard macro**: `FLUX_STANDARD_ENCODING`

**Dependencies**: `types.fx`

**Description**:  
Stack-only (no heap allocation) encode/decode routines for Hex, Base32, Base58, Base64, Base64 URL-safe, and URL percent-encoding. All functions return the number of bytes written to `dst`, or `-1` if `dst_cap` is insufficient or the input is malformed. Use the `*_len` helpers to compute safe upper bounds before calling encode/decode.

#### Hex

```flux
def hex_encode_len(int src_len) -> int
    // Returns 2 * src_len.

def hex_encode(byte* src, int src_len, byte* dst, int dst_cap) -> int
    // Lowercase hex output (0-9, a-f).

def hex_encode_upper(byte* src, int src_len, byte* dst, int dst_cap) -> int
    // Uppercase hex output (0-9, A-F).

def hex_decode(byte* src, int src_len, byte* dst, int dst_cap) -> int
    // src_len must be even. Returns -1 on invalid hex character.
```

#### Base32 (RFC 4648, alphabet A-Z 2-7)

```flux
def base32_encode_len(int src_len, bool pad) -> int
def base32_decode_len(int src_len) -> int

def base32_encode(byte* src, int src_len, byte* dst, int dst_cap, bool pad) -> int
    // pad=true appends '=' padding to a multiple of 8.

def base32_decode(byte* src, int src_len, byte* dst, int dst_cap) -> int
    // Case-insensitive; padding characters are skipped.
```

#### Base58 (Bitcoin alphabet)

Alphabet: `123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz`

```flux
def base58_encode_len(int src_len) -> int

def base58_encode(byte* src, int src_len, byte* dst, int dst_cap) -> int
def base58_decode(byte* src, int src_len, byte* dst, int dst_cap) -> int
```

#### Base64 (RFC 4648 standard)

```flux
def base64_encode_len(int src_len, bool pad) -> int
def base64_decode_len(int src_len) -> int

def base64_encode(byte* src, int src_len, byte* dst, int dst_cap, bool pad) -> int
    // Standard alphabet (A-Z a-z 0-9 + /). pad=true appends '='.

def base64_decode(byte* src, int src_len, byte* dst, int dst_cap) -> int
    // Padding characters and standard alphabet accepted.
```

#### Base64 URL-safe (RFC 4648 §5)

Uses `-` instead of `+` and `_` instead of `/`.

```flux
def base64url_encode(byte* src, int src_len, byte* dst, int dst_cap, bool pad) -> int
def base64url_decode(byte* src, int src_len, byte* dst, int dst_cap) -> int
```

#### URL Percent-Encoding (RFC 3986)

Unreserved characters (`A-Z a-z 0-9 - _ . ~`) pass through unchanged. All other bytes are encoded as `%XX` (uppercase hex). `+` is **not** used for spaces; space encodes as `%20`.

```flux
def url_encode_len(byte* src, int src_len) -> int
    // Returns src_len * 3 (worst-case upper bound).

def url_encode(byte* src, int src_len, byte* dst, int dst_cap) -> int
def url_decode(byte* src, int src_len, byte* dst, int dst_cap) -> int
    // '+' is decoded as '+', not space.
    // Returns -1 on malformed %XX sequences.
```

**Example**:
```flux
#import <standard.fx>, <encodings.fx>;

using standard::encoding;

def main() -> int
{
    byte[6]  src    = ['H','e','l','l','o','!'];
    byte[16] enc;
    byte[6]  dec;
    int      enc_len, dec_len;

    enc_len = base64_encode(@src[0], 6, @enc[0], 16, true);
    // enc_len == 8, enc == "SGVsbG8h"

    dec_len = base64_decode(@enc[0], enc_len, @dec[0], 6);
    // dec_len == 6, dec == "Hello!"

    return 0;
};
```

---



### Basic Import

To use the standard library:

```flux
#import <standard.fx>;
```

This automatically imports via `runtime.fx`:
- Type definitions (`types.fx`)
- OS detection (`sys.fx`)
- Memory management (`memory.fx`, `allocators.fx`)
- I/O operations (`io.fx`)
- File I/O via FFI (`ffifio.fx`)
- String utilities (`string_utilities.fx`)
- Raw builtins (`string_object_raw.fx`, `file_object_raw.fx`)

### Selective Imports

Extended libraries must be imported explicitly:

```flux
// Types only
#import <types.fx>;

// Math
#import <math.fx>;

// Collections
#import <collections.fx>;

// Vectors
#import <vectors.fx>;

// Threading (pulls in atomics.fx automatically)
#import <threading.fx>;

// Timing
#import <timing.fx>;

// Networking (Windows)
#import <net_windows.fx>;   // or: #import "socket_object_raw.fx";

// Cryptography
#import <cryptography.fx>;

// CRC32
#import <crc32.fx>;

// Arbitrary precision
#import <decimal.fx>;  // also pulls in bigint.fx

// TUI console control
#import <console.fx>;

// ANSI text formatting
#import <format.fx>;

// OpenGL (Windows)
#import <opengl.fx>;

// OpenGL graphing
#import <oglgraphing.fx>;

// Win32 GUI
#import <windows.fx>;

// WASAPI audio capture (Windows)
#import <wasapi.fx>;

// Inline hooking (Windows x86-64)
#import <detour.fx>;

// .env file loader
#import <dotenv.fx>;

// JSON
#import <json.fx>;

// Matrix math (Mat3/Mat4/Mat5)
#import <matrices.fx>;

// Fourier (DFT/FFT)
#import <fourier.fx>;

// Physics engine
#import <physics.fx>;

// Tensors
#import <tensors.fx>;

// Automatic differentiation
#import <autograd.fx>;

// Path tracer
#import <raytracing.fx>;

// 2.5D raycaster
#import <raycasting.fx>;

// DateTime / calendar
#import <datetime.fx>;

// XML (arena-backed)
#import <xml.fx>;

// CSV (RFC 4180)
#import <csv.fx>;

// Binary-to-text encodings
#import <encodings.fx>;
```

### Namespace Usage

After importing, use namespaces explicitly or with `using`:

```flux
#import <standard.fx>;

// Explicit namespace
int result = standard::math::abs(-42);

// Using directive
using standard::math;
int result = abs(-42);

// Collections
#import <collections.fx>;
using standard::collections;
Array myArray;

// Vectors
#import <vectors.fx>;
using standard::vectors;
Vec3 position = vec3(1.0, 2.0, 3.0);
```

### Conditional Compilation

```flux
// Disable runtime
#def FLUX_RUNTIME 0;
#import <standard.fx>;

// Guard against double imports
#ifndef FLUX_STANDARD_MEMORY
#import <memory.fx>;
#endif;
```

---

## Security

### shadowstack.fx

**Purpose**: Opt-in per-function shadow stack protection against stack smashing attacks

**Namespace**: `standard::runtime::shadow_stack`

**Guard macro**: `FLUX_SHADOW_STACK_IMPL`

**Platform**: Windows x86-64 only (current)

#### Activation

Define `FLUX_SHADOW_STACK` before importing `standard.fx`. The runtime will automatically initialize the shadow stack page on startup and tear it down on exit.

```flux
#def FLUX_SHADOW_STACK 1;
#import <standard.fx>;
```

#### Design

The shadow stack maintains a separately allocated, non-executable memory page holding `FSSFrame` records. Each record stores a saved return address (XOR'd with a per-process canary) and a canary value. Protection is opt-in per function via contracts — the compiler never injects code automatically.

The canary is seeded at startup from two hardware entropy sources (RDTSC and `QueryPerformanceCounter`) XOR'd with a constant, ensuring a unique value every run.

#### FSSFrame

```flux
struct FSSFrame
{
    u64 canary,     // Random canary XOR'd with the saved return address
        saved_ra,   // Return address captured at frame entry (XOR'd with canary)
        saved_rsp;  // Canary copy used for secondary verification
};
```

#### Globals

| Global | Type | Description |
|--------|------|-------------|
| `FSS_BASE` | `FSSFrame*` | Pointer to the shadow page |
| `FSS_TOP` | `u64` | Current push index (grows upward) |
| `FSS_CAP` | `u64` | Maximum frames the page can hold (170) |
| `FSS_CANARY` | `u64` | Process-lifetime random canary seed |

#### Core API

```flux
def fss_init() -> bool
```
Allocates the shadow page via `VirtualAlloc` and seeds `FSS_CANARY`. Called automatically by `FRTStartup`. Returns `false` if allocation fails.

```flux
def fss_push(u64 ra, u64 rsp) -> u64
```
Pushes a frame. `ra` is stored XOR'd with `FSS_CANARY`. Returns the slot index.

```flux
def fss_verify(u64 slot, u64 ra, u64 rsp) -> bool
```
Verifies a previously pushed frame. Checks the canary field, decodes and compares the return address, and validates `rsp`. Returns `false` if any check fails.

```flux
def fss_pop() -> void
```
Pops and zeroes the top frame so it cannot be replayed.

```flux
def fss_abort() -> void
```
Prints a fatal diagnostic and terminates immediately via `ExitProcess(1)`. Declared `noreturn`.

```flux
def fss_teardown() -> void
```
Frees the shadow page. Called automatically by `FRTStartup` on exit.

#### Contracts

The primary programmer interface. Apply to any function handling untrusted input or performing buffer manipulation.

```flux
def vulnerable(byte* buf, int len) -> void : FSS_Protect_Frame
{
    // ...
} : FSS_Cleanup_Frame;
```

**`FSS_Protect_Frame`** (pre-contract, injected at function entry):
- Declares `__fss_canary_local` on the protected function's own stack frame
- Captures the return address from `8(%rbp)`
- Pushes both into the shadow stack via `fss_push`
- Sets `__fss_frame_active = true`

**`FSS_Cleanup_Frame`** (post-contract, injected before every `return`):
- Re-captures the return address from `8(%rbp)`
- Calls `fss_verify` to check the return address matches the saved shadow frame
- Checks `__fss_canary_local == FSS_CANARY` to detect physical stack overflows
- On success: calls `fss_pop()`
- On failure: calls `fss_abort()` — process terminates immediately, no further execution

Because `FSS_Protect_Frame` is a pre-contract, `__fss_canary_local` is declared before any user-defined locals in the function. On x86-64 where the stack grows downward and buffers overflow upward, the canary naturally sits above user buffers — a linear overflow will hit it before reaching the return address.

#### Detection Vectors

| Attack | Detected By |
|--------|-------------|
| Linear buffer overflow reaching the canary | `__fss_canary_local == FSS_CANARY` check |
| Return address overwrite | `fss_verify` return address comparison |
| Direct `FSS_CANARY` global tampering | `fss_verify` canary field check |

#### Example

```flux
#def FLUX_SHADOW_STACK 1;
#import <standard.fx>;
using standard::io::console;

def parse_input(byte* buf, int len) -> bool : FSS_Protect_Frame
{
    // Buffer operations on untrusted input...
    return true;
} : FSS_Cleanup_Frame;

def main() -> int
{
    byte[64] buf;
    parse_input(@buf[0], 64);
    return 0;
};
```

#### Notes

- `FLUX_SHADOW_STACK` must be defined before `#import <standard.fx>`
- The shadow page holds up to 170 frames; deeply recursive protected functions will hit this limit
- Windows x86-64 only; requires a frame pointer (`%rbp`) to be present
- `FSS_CANARY` is a process-lifetime global — direct writes to it from any code path are also detected
- Future: per-call canary randomization via `fss_rdtsc() ^| FSS_CANARY` for stronger per-invocation protection

---

## Platform Support

### Supported Platforms

| Platform | Architecture | Status |
|----------|--------------|--------|
| Windows | x86_64 (64-bit) | Supported, primary target |
| Linux | x86_64 (64-bit) | Supported |
| macOS | x86_64 (64-bit) | Partial - needs improvement |
| - | ARM (64-bit) | Minimal - needs major improvement |

### Platform Detection

Preprocessor definitions set automatically at compile time:

```flux
#ifdef __WINDOWS__
    // Windows-specific code
#endif;

#ifdef __LINUX__
    // Linux-specific code
#endif;

#ifdef __MACOS__
    // macOS-specific code
#endif;

#ifdef __ARCH_X86_64__
    // 64-bit x86 code
#endif;

#ifdef __ARCH_ARM64__
    // ARM64 code
#endif;

#ifdef __WIN64__
    // Windows 64-bit
#endif;
```

### Platform-Specific Notes

#### Windows

- Uses Windows API for console I/O (`GetStdHandle`, `WriteFile`, `ReadFile`)
- File I/O through both Windows API and C FFI
- Supports wide character handling (`wchar`)
- Command-line arguments parsed from `GetCommandLineW()`
- Exclusive home of: `net_windows.fx`, `console.fx`, `opengl.fx`, `windows.fx`, `detour.fx`, `sharedmemory.fx`
- Entry point: `FRTStartup()`

#### Linux

- Direct syscall interface for all I/O operations
- No C runtime dependency for core operations
- Native `malloc`/`free` via `mmap`/`munmap`
- Entry point: `_start()` → `FRTStartup()`

#### macOS

- Similar to Linux with BSD syscalls
- Native `malloc`/`free` via macOS `mmap` syscall numbers
- Console I/O implementation pending full testing
- Entry point: `start()`

---

## Best Practices

### Memory Management

1. **Prefer `fmalloc`/`ffree` for Flux programs** — the standard heap allocator is more efficient than `malloc`/`free` in most cases:
   ```flux
   byte* buf = (byte*)fmalloc(256);
   // ... use buf ...
   ffree((u64)buf);
   ```

2. **Check allocation results**:
   ```flux
   void* buffer = malloc(1024);
   if (buffer == NULL)
   {
       return -1;
   };
   ```

3. **All locals are zero-initialized** — no need to manually zero freshly declared stack variables.

4. **All allocations are stack-allocated by default** — do not declare variables inside loops unless you intend a stack overflow. Hoist loop-invariant declarations to the function top.

### String Handling

1. **Always null-terminate strings** — the compiler does not do this automatically:
   ```flux
   print("Hello, World!\0");
   ```

2. **Use appropriate buffer sizes**:
   ```flux
   byte[32] buffer;
   i32str(value, @buffer[0]);
   ```

3. **Free dynamically allocated strings**:
   ```flux
   byte* result = concat(s1, s2);
   print(result);
   free(result);
   ```

### File I/O

1. **Always check file handles**:
   ```flux
   i64 fd = open_read("file.txt\0");
   if (fd == INVALID_FD)
   {
       return -1;
   };
   ```

2. **Close files when done**:
   ```flux
   close(fd);
   ```

### Error Handling

1. **Check return values**:
   ```flux
   int result = write_file("data.txt\0", buffer, size);
   if (result < 0)
   {
       print("Write failed\0");
       return 1;
   };
   ```

2. **Use try-catch for critical sections**:
   ```flux
   try
   {
       // Risky operation
   }
   catch()
   {
       return false;
   };
   ```

---

## Version History

**Version 2.3** (June 2026)
- `datetime.fx` added: calendar date/time, duration arithmetic, wall-clock access, ISO 8601 / RFC 1123 formatting and parsing (`standard::datetime`)
- `xml.fx` added: arena-backed recursive descent XML parser, builder, and serializer with entity decoding and pretty-print output (`xml` namespace)
- `csv.fx` added: RFC 4180 CSV parser and writer with configurable delimiter, quoted-field support, and `csv_free` cleanup (`csv` namespace)
- `encodings.fx` added: stack-only Hex, Base32, Base58, Base64, Base64URL, and URL percent-encoding routines (`standard::encoding`)

**Version 2.2** (June 2026)
- `shadowstack.fx` added: opt-in per-function shadow stack protection for Windows x86-64

**Version 2.1** (May 2026)
- Documentation updated to better reflect library contents
- `net_windows.fx` clarified: full networking now lives in `socket_object_raw.fx` under `standard::sockets`; `net_windows.fx` is a thin glue file
- `allocators.fx` expanded: now documents `stdstack`, `stdpool`, `stdarena`, and `stdring` in addition to `stdheap`
- `collections.fx` expanded: `HashMapInt`, `Deque`, `RingBuffer`, `HashSet`, `HashSetInt`, and `MinHeap` added
- New library sections added: `crc32.fx`, `dotenv.fx`, `json.fx`, `matrices.fx`, `fourier.fx`, `physics.fx`, `tensors.fx`, `autograd.fx`, `raytracing.fx`, `raycasting.fx`, `wasapi.fx`, `oglgraphing.fx`, `datautils.fx`

**Version 2.0** (March 2026)
- `red` prefix removed from all library filenames
- `redstandard.fx` retired; `standard.fx` now directly imports `runtime.fx`
- `red_string_utilities.fx` renamed to `string_utilities.fx`
- `memory.fx` expanded: native Linux/macOS `malloc`/`free` via `mmap`; `standard::memory` namespace with utilities, aligned allocation, reference counting, and byte manipulation helpers
- `allocators.fx` promoted to primary heap allocator (`fmalloc`/`ffree`/`frealloc`); initialized by `FRTStartup()`
- `sys.fx` formalized with `standard::system` namespace and `CURRENT_OS` detection
- `ntoh`/`hton` helpers in `types.fx` marked deprecated
- New libraries added: `atomics.fx`, `threading.fx`, `timing.fx`, `random.fx`, `cryptography.fx`, `bigint.fx`, `decimal.fx`, `net_windows.fx`, `uuid.fx`, `sharedmemory.fx`, `format.fx`, `console.fx`, `graphing.fx`, `opengl.fx`, `windows.fx`, `detour.fx`, `operators.fx`

**Version 1.0** (February 2026)
- Initial reduced specification implementation
- Cross-platform support (Windows, Linux, macOS)
- Core I/O, math, and string utilities
- FFI integration with C runtime
- Collections library (Array, LinkedList, Stack, Queue, HashMap, BinarySearchTree)
- Vectors library (3D/4D vector mathematics)

---

## Contributing

The Flux Standard Library is part of the Flux language project. For contributions, bug reports, or questions, please visit the [Flux Discord server](https://discord.gg/RAHjbYuNUc).

---

## License

This documentation describes the Flux Standard Library as part of the Flux programming language project.

---

*This documentation reflects the Flux standard library as of v2.3, June 2026. For the most up-to-date information, refer to the official Flux language repository and Discord community.*