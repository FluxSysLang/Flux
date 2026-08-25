// test_ptr.fx -- unit tests for SmartPtr<T> smart pointer

#import <standard.fx>, <collections.fx>;

using standard::io::console,
      standard::collections;

// ----------------------------------------------------------------
// Simple struct for non-trivial type tests
// ----------------------------------------------------------------
struct Vec2 { int x, y; };

// ----------------------------------------------------------------
// Test helpers
// ----------------------------------------------------------------
int g_passed, g_failed;

def pass(byte* name) -> void
{
    println("[PASS] ");
    println(name);
    println("");
    g_passed++;
    return;
};

def fail(byte* name, byte* reason) -> void
{
    println("[FAIL] ");
    println(name);
    println(" -- ");
    println(reason);
    println("");
    g_failed++;
    return;
};

// ----------------------------------------------------------------
// Test: default-construct allocates a non-null pointer
// ----------------------------------------------------------------
def test_init_valid() -> void
{
    SmartPtr<int> p;
    p.__init();
    if (p.valid())
    {
        pass("init_valid");
    }
    else
    {
        fail("init_valid", "valid() returned false after __init");
    };
    p.__exit();
    return;
};

// ----------------------------------------------------------------
// Test: get() returns a writable pointer; value round-trips
// ----------------------------------------------------------------
def test_get_readwrite() -> void
{
    SmartPtr<int> p;
    p.__init();
    *p.get() = 1234;
    if (*p.get() == 1234)
    {
        pass("get_readwrite");
    }
    else
    {
        fail("get_readwrite", "value did not round-trip through get()");
    };
    p.__exit();
    return;
};

// ----------------------------------------------------------------
// Test: works with a struct type
// ----------------------------------------------------------------
def test_struct_type() -> void
{
    SmartPtr<Vec2> p;
    p.__init();
    p.get().x = 10;
    p.get().y = 20;
    if (p.get().x == 10 and p.get().y == 20)
    {
        pass("struct_type");
    }
    else
    {
        fail("struct_type", "struct fields did not survive get()");
    };
    p.__exit();
    return;
};

// ----------------------------------------------------------------
// Test: reset() nulls the pointer and valid() returns false
// ----------------------------------------------------------------
def test_reset_nulls() -> void
{
    SmartPtr<int> p;
    p.__init();
    p.reset();
    if (!p.valid())
    {
        pass("reset_nulls");
    }
    else
    {
        fail("reset_nulls", "valid() still true after reset()");
    };
    p.__exit();
    return;
};

// ----------------------------------------------------------------
// Test: reset() is idempotent -- calling it twice does not crash
// ----------------------------------------------------------------
def test_reset_idempotent() -> void
{
    SmartPtr<int> p;
    p.__init();
    p.reset();
    p.reset();
    pass("reset_idempotent");
    p.__exit();
    return;
};

// ----------------------------------------------------------------
// Test: take() returns the raw pointer and leaves SmartPtr null
// ----------------------------------------------------------------
def test_take_relinquishes() -> void
{
    SmartPtr<int> p;
    p.__init();
    *p.get() = 99;
    int* raw = p.take();
    if (!p.valid() and *raw == 99)
    {
        pass("take_relinquishes");
    }
    else
    {
        fail("take_relinquishes", "take() did not transfer ownership correctly");
    };
    ffree(ulong(raw));
    p.__exit();
    return;
};

// ----------------------------------------------------------------
// Test: adopt an existing heap pointer via the T* overload
// ----------------------------------------------------------------
def test_adopt_existing() -> void
{
    int* raw = (int*)fmalloc(sizeof(int) / 8);
    *raw = 777;
    SmartPtr<int> p;
    p.__init(raw);
    if (p.valid() and *p.get() == 777)
    {
        pass("adopt_existing");
    }
    else
    {
        fail("adopt_existing", "adopted pointer not valid or value wrong");
    };
    p.__exit();
    return;
};

// ----------------------------------------------------------------
// Test: __exit() on a null (reset) pointer does not crash
// ----------------------------------------------------------------
def test_exit_after_reset() -> void
{
    SmartPtr<int> p;
    p.__init();
    p.reset();
    p.__exit();
    pass("exit_after_reset");
    return;
};

// ----------------------------------------------------------------
// Test: get() on null pointer returns null
// ----------------------------------------------------------------
def test_get_when_null() -> void
{
    SmartPtr<int> p;
    p.__init();
    p.reset();
    if (p.get() == (int*)STDLIB_GVP)
    {
        pass("get_when_null");
    }
    else
    {
        fail("get_when_null", "get() did not return null after reset");
    };
    p.__exit();
    return;
};

// ----------------------------------------------------------------
// main
// ----------------------------------------------------------------
def main() -> int
{
    println("=== SmartPtr<T> smart pointer tests ===");
    println("");

    test_init_valid();
    test_get_readwrite();
    test_struct_type();
    test_reset_nulls();
    test_reset_idempotent();
    test_take_relinquishes();
    test_adopt_existing();
    test_exit_after_reset();
    test_get_when_null();

    println("\nResults: ");
    println(f"{g_passed} passed, ");
    println(f"{g_failed} failed.");

    return g_failed;
};
