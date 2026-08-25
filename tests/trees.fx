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