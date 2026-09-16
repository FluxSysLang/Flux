#def FLUX_SHADOW_STACK 1;
#import <standard.fx>;

using standard::io::console;

def main() -> int : FSS_Protect_Frame
{
    println("Hello World!");
    return 0;
} : FSS_Cleanup_Frame # effect {!IO.Console.Output};