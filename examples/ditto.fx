#import <standard.fx>;

using standard::io::console;


def foo(int a, int b, int c) -> void
{
    println(f"{a} {b} {c}");
};

def main() -> int
{
    int i;
    int x = ++i,
        y = #",
        z = #";

    foo(x, y, z);
    foo(y, #", #");
    foo(z, #", #");

    return 0;
};