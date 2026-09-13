#import <standard.fx>;

using standard::io::console;

enum Colors
{
    RED, GREEN, BLUE
};

union UX
{
    int red;
    bool green;
    char blue;
} # Colors;

def main() -> int
{
    UX ux;

    ux.red = 10;

    switch (ux.#)
    {
        case (Colors.RED)
        {
            println("Red active!");
        }
        case (Colors.GREEN)
        {
            println("Green active!");
        }
        case (Colors.BLUE)
        {
            println("Blue active!");
        }
    };

    -> 0;
};