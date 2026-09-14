// Effect system comprehensive test.
// Tests: transitive propagation, Pure enforcement, conflict detection,
//        attenuation, exclusions, user-defined effects, all builtin families.

#import <standard.fx>;

using standard::io::console;

// ---------------------------------------------------------------------------
// Effect declarations
// ---------------------------------------------------------------------------

// Standard composed effects
effect ShadowStack { *Hook & !@Unsafe & !Alloc };
effect SafeDetour  { *Hook.Detour & ^Alloc };
effect RealTime    { !Alloc & !IO & !Throw };
effect NetworkIO   { *IO.Socket & [Mem.Write | Mem.Read] };
effect HookContext { *Hook & !@Unsafe & !IO };

// Conflict test effects -- exactly-one and mutual implication
effect ReadOnly    { *Mem.Read <-> !Mem.Write };
effect ExclusiveIO { IO.Console ^| IO.File };

// ---------------------------------------------------------------------------
// Leaf stubs -- direct effect sources
// ---------------------------------------------------------------------------

// IO
def leaf_console(byte* msg) -> void # effect {*IO.Console};
def leaf_console(byte* msg) -> void {};

def leaf_file(byte* path) -> void # effect {*IO.File};
def leaf_file(byte* path) -> void {};

def leaf_socket(byte* xd) -> void # effect {*IO.Socket};
def leaf_socket(byte* xd) -> void {};

// Alloc
def leaf_heap() -> void* # effect {*Alloc.Heap};
def leaf_heap() -> void* {};

def leaf_virtual(uint size) -> void* # effect {*Alloc.Virtual};
def leaf_virtual(uint size) -> void* {};

// Unsafe
def leaf_ptr(void* p) -> byte # effect {*Unsafe.Ptr};
def leaf_ptr(void* p) -> byte { -> 0; };

def leaf_asm() -> long # effect {*Unsafe.ASM};
def leaf_asm() -> long { -> 0; };

def leaf_ffi(void* fn) -> void # effect {*Unsafe.FFI};
def leaf_ffi(void* fn) -> void {};

// Mem
def leaf_read_proc(void* addr) -> byte # effect {*Mem.Read.Process};
def leaf_read_proc(void* addr) -> byte { -> 0; };

def leaf_write_exec(void* addr, byte val) -> void # effect {*Mem.Write.Exec};
def leaf_write_exec(void* addr, byte val) -> void {};

def leaf_write_kernel(void* addr, byte val) -> void # effect {*Mem.Write.Kernel};
def leaf_write_kernel(void* addr, byte val) -> void {};

// Hook
def leaf_detour(void* target, void* hook) -> void # effect {*Hook.Detour};
def leaf_detour(void* target, void* hook) -> void {};

def leaf_iat(byte* mod, byte* fn, void* hook) -> void # effect {*Hook.IAT};
def leaf_iat(byte* mod, byte* fn, void* hook) -> void {};

// Sync
def leaf_lock() -> void # effect {*Sync.Lock};
def leaf_lock() -> void {};

def leaf_atomic(void* p, int val) -> void # effect {*Sync.Atomic};
def leaf_atomic(void* p, int val) -> void {};

// Crypto
def leaf_hash(byte* xd, uint len) -> void # effect {*Crypto.Hash};
def leaf_hash(byte* xd, uint len) -> void {};

def leaf_random(byte* buf, uint len) -> void # effect {*Crypto.Random};
def leaf_random(byte* buf, uint len) -> void {};

// Process
def leaf_spawn(byte* path) -> uint # effect {*Process.Spawn};
def leaf_spawn(byte* path) -> uint { -> 0; };

def leaf_inject(uint pid, byte* dll) -> void # effect {*Process.Inject};
def leaf_inject(uint pid, byte* dll) -> void {};

// Privilege
def leaf_elevate() -> void # effect {*Privilege.Elevate};
def leaf_elevate() -> void {};

def leaf_priv_check(uint p) -> bool # effect {*Privilege.Check};
def leaf_priv_check(uint p) -> bool { -> false; };

// Time
def leaf_sleep(uint ms) -> void # effect {*Time.Sleep};
def leaf_sleep(uint ms) -> void {};

// Anchors
def leaf_pure(int a, int b) -> int # effect {Pure};
def leaf_pure(int a, int b) -> int { -> a + b; };

def leaf_throw(int x) -> int # effect {*Throw};
def leaf_throw(int x) -> int { -> x; };

// ---------------------------------------------------------------------------
// Intermediate functions (transitive propagation test targets)
// No annotations -- effects propagate upward through them.
// ---------------------------------------------------------------------------

// mid_io calls leaf_console. No annotation.
// Any caller that excludes IO should catch this transitively.
def mid_io() -> void;
def mid_io() -> void
{
    leaf_console("mid\0");
};

// mid_alloc calls leaf_heap. No annotation.
def mid_alloc() -> void*;
def mid_alloc() -> void*
{
    -> leaf_heap();
};

// mid_chain calls mid_io which calls leaf_console -- two hops deep.
def mid_chain() -> void;
def mid_chain() -> void
{
    mid_io();
};

// mid_deep_alloc calls mid_alloc which calls leaf_heap -- two hops.
def mid_deep_alloc() -> void;
def mid_deep_alloc() -> void
{
    void* p = mid_alloc();
    (void)p;
};

// mid_multi introduces both IO and Alloc through separate chains.
def mid_multi() -> void;
def mid_multi() -> void
{
    mid_io();
    mid_deep_alloc();
};

// mid_unsafe calls leaf_asm transitively.
def mid_unsafe() -> void;
def mid_unsafe() -> void
{
    leaf_asm();
};

// ---------------------------------------------------------------------------
// Attenuation stubs
// ---------------------------------------------------------------------------

// Fully attenuates IO -- callers see no IO effect.
def attenuated_io(byte* msg) -> void # attenuate {IO};
def attenuated_io(byte* msg) -> void
{
    leaf_console(msg);
};

// Fully attenuates Alloc.
def attenuated_alloc(uint size) -> void* # attenuate {Alloc};
def attenuated_alloc(uint size) -> void* {};

// Attenuates IO but not Alloc -- both escape without attenuation.
def partial_attenuate(byte* msg) -> void # effect {*Alloc.Heap} # attenuate {IO};
def partial_attenuate(byte* msg) -> void
{
    leaf_console(msg);
    void* p = leaf_heap();
    (void)p;
};

// Attenuates only IO.Socket -- IO.File still escapes.
def socket_attenuate(byte* msg) -> void # effect {*IO.File} # attenuate {IO.Socket};
def socket_attenuate(byte* msg) -> void
{
    leaf_socket(msg);
    leaf_file(msg);
};

// Attenuates a transitively introduced effect -- mid_io's IO is contained.
def attenuated_transitive(byte* msg) -> void # attenuate {IO};
def attenuated_transitive(byte* msg) -> void
{
    mid_io();
};

// ---------------------------------------------------------------------------
// TRANSITIVE PROPAGATION TESTS
// ---------------------------------------------------------------------------

// SHOULD FAIL (1 violation): excludes IO, calls mid_io which introduces
// IO.Console transitively through leaf_console.
def trans_direct_fail() -> void # effect {!IO};
def trans_direct_fail() -> void
{
    mid_io();
};

// SHOULD FAIL (1 violation): excludes IO, calls mid_chain which is two hops
// from leaf_console.
def trans_two_hop_fail() -> void # effect {!IO};
def trans_two_hop_fail() -> void
{
    mid_chain();
};

// SHOULD FAIL (2 violations): excludes both IO and Alloc, calls mid_multi
// which introduces both transitively.
def trans_multi_fail() -> void # effect {!IO & !Alloc};
def trans_multi_fail() -> void
{
    mid_multi();
};

// SHOULD PASS: calls attenuated_transitive which contains mid_io's IO.
def trans_attenuated_pass() -> void # effect {!IO};
def trans_attenuated_pass() -> void
{
    attenuated_transitive("ok\0");
};

// SHOULD PASS: calls attenuated_io which attenuates all IO.
def trans_fully_attenuated_pass() -> void # effect {!IO};
def trans_fully_attenuated_pass() -> void
{
    attenuated_io("ok\0");
};

// SHOULD FAIL (1 violation): partial_attenuate attenuates IO but introduces
// Alloc.Heap -- caller excludes Alloc.
def trans_partial_attenuate_fail() -> void # effect {!Alloc};
def trans_partial_attenuate_fail() -> void
{
    partial_attenuate("bad\0");
};

// SHOULD FAIL (1 violation): socket_attenuate attenuates IO.Socket but
// IO.File escapes -- caller excludes IO.
def trans_socket_fail() -> void # effect {!IO};
def trans_socket_fail() -> void
{
    socket_attenuate("bad\0");
};

// ---------------------------------------------------------------------------
// PURE ENFORCEMENT TESTS
// ---------------------------------------------------------------------------

// SHOULD PASS: only calls leaf_pure which is Pure.
def pure_pass() -> int # effect {Pure};
def pure_pass() -> int
{
    -> leaf_pure(1, 2);
};

// SHOULD PASS: chains two Pure calls.
def pure_chain_pass() -> int # effect {Pure};
def pure_chain_pass() -> int
{
    int a = leaf_pure(1, 2);
    int b = leaf_pure(a, 3);
    -> b;
};

// SHOULD FAIL: declares Pure but calls leaf_console -- IO violation.
def pure_io_fail() -> void # effect {Pure};
def pure_io_fail() -> void
{
    leaf_console("bad\0");
};

// SHOULD FAIL: declares Pure but calls mid_alloc -- Alloc violation
// introduced transitively through mid_alloc -> leaf_heap.
def pure_transitive_alloc_fail() -> int # effect {Pure};
def pure_transitive_alloc_fail() -> int
{
    void* p = mid_alloc();
    (void)p;
    -> 0;
};

// SHOULD FAIL: declares Pure but calls leaf_throw -- Throw violation.
def pure_throw_fail() -> int # effect {Pure};
def pure_throw_fail() -> int
{
    -> leaf_throw(1);
};

// SHOULD FAIL: declares Pure but calls mid_chain -- IO violation two hops deep.
def pure_deep_fail() -> void # effect {Pure};
def pure_deep_fail() -> void
{
    mid_chain();
};

// ---------------------------------------------------------------------------
// CONFLICT DETECTION TESTS
// ---------------------------------------------------------------------------

// ExclusiveIO declares IO.Console ^ IO.File (exactly one allowed).

// SHOULD FAIL: introduces both IO.Console and IO.File -- violates ^ constraint.
def conflict_xor_fail() -> void # effect {ExclusiveIO};
def conflict_xor_fail() -> void
{
    leaf_console("a\0");
    leaf_file("b\0");
};

// SHOULD PASS: introduces only IO.Console.
def conflict_xor_pass() -> void # effect {ExclusiveIO};
def conflict_xor_pass() -> void
{
    leaf_console("a\0");
};

// ReadOnly declares Mem.Read <-> !Mem.Write (mutual: read implies no write).

// SHOULD FAIL: introduces Mem.Read.Process and Mem.Write.Exec --
// violates <-> constraint.
def conflict_mutual_fail() -> void # effect {ReadOnly};
def conflict_mutual_fail() -> void
{
    leaf_read_proc((@)void);
    leaf_write_exec((@)void, 0);
};

// SHOULD PASS: introduces only Mem.Read.
def conflict_mutual_pass() -> void # effect {ReadOnly};
def conflict_mutual_pass() -> void
{
    leaf_read_proc((@)void);
};

// ---------------------------------------------------------------------------
// DIRECT EXCLUSION TESTS (baseline)
// ---------------------------------------------------------------------------

// SHOULD FAIL: !Alloc, calls leaf_heap directly.
def excl_alloc_fail() -> void # effect {!Alloc};
def excl_alloc_fail() -> void
{
    leaf_heap();
};

// SHOULD FAIL: !IO, calls leaf_console directly.
def excl_io_fail() -> void # effect {!IO};
def excl_io_fail() -> void
{
    leaf_console("bad\0");
};

// SHOULD PASS: !IO, calls attenuated_io.
def excl_io_attenuated_pass() -> void # effect {!IO};
def excl_io_attenuated_pass() -> void
{
    attenuated_io("ok\0");
};

// SHOULD PASS: !Alloc, calls attenuated_alloc.
def excl_alloc_attenuated_pass() -> void # effect {!Alloc};
def excl_alloc_attenuated_pass() -> void
{
    attenuated_alloc(64);
};

// SHOULD FAIL: !IO, calls socket_attenuate -- IO.File escapes.
def excl_partial_fail() -> void # effect {!IO};
def excl_partial_fail() -> void
{
    socket_attenuate("bad\0");
};

// ---------------------------------------------------------------------------
// USER-DEFINED EFFECT TESTS
// ---------------------------------------------------------------------------

// SHOULD PASS: ShadowStack excludes Alloc, hook_wrap only calls leaf_detour.
def shadow_stack_pass() -> void # effect {ShadowStack};
def shadow_stack_pass() -> void
{
    leaf_detour((@)void, (@)void);
};

// SHOULD FAIL: ShadowStack excludes Alloc, but we call leaf_heap.
def shadow_stack_alloc_fail() -> void # effect {ShadowStack};
def shadow_stack_alloc_fail() -> void
{
    leaf_detour((@)void, (@)void);
    leaf_heap();
};

// SHOULD PASS: RealTime excludes Alloc, IO, Throw -- only calls leaf_pure.
def rt_pass() -> void # effect {RealTime};
def rt_pass() -> void
{
    leaf_pure(1, 2);
};

// SHOULD FAIL: RealTime excludes IO -- calls mid_io transitively.
def rt_io_fail() -> void # effect {RealTime};
def rt_io_fail() -> void
{
    mid_io();
};

// SHOULD FAIL: RealTime excludes Alloc -- calls leaf_heap.
def rt_alloc_fail() -> void # effect {RealTime};
def rt_alloc_fail() -> void
{
    leaf_heap();
};

// ---------------------------------------------------------------------------
// MAIN -- unrestricted, exercises all families
// ---------------------------------------------------------------------------

def main() -> int
{
    leaf_console("Effect comprehensive test\0");

    void* p = leaf_heap();
    (void)p;

    leaf_lock();
    leaf_hash("x\0", 1);
    leaf_random("buf\0", 4);
    leaf_elevate();
    leaf_priv_check(0);
    leaf_sleep(1);
    leaf_detour((@)void, (@)void);
    leaf_inject(0, "dll\0");
    leaf_spawn("path\0");
    leaf_asm();
    leaf_ffi((@)void);

    int r = leaf_pure(2, 3);
    (void)r;

    -> 0;
};