#import <standard.fx>;

using standard::io::console;


comptime
{
    data{16::0} le_x = 5; // 0b00000101 000000000 in LE

    byte x = 0b00000101;

    data{3} y = x[5``7];

    data{3} le_y = le_x[5``7];

    data{1} z = x[5``7][`0];

    data{1} le_z = le_x[5``7][`0];

    if (z)
    {
        compiler.io.console.println("[CT] Success 1!");
    };

    if (y == 0b101)
    {
        compiler.io.console.println("[CT] Success 2!");
    };

    if (le_z)
    {
        compiler.io.console.println("[CT] Success 3!");
    };

    if (le_y == 0b101)
    {
        compiler.io.console.println("[CT] Success 4!");
    };
};


def main() -> int
{
    data{16::0} le_x = 5; // 0b00000101 000000000 in LE

    byte x = 0b00000101;

    data{3} y = x[5``7];

    data{3} le_y = le_x[5``7];

    data{1} z = x[5``7][`0];

    data{1} le_z = le_x[5``7][`0];

    if (z)
    {
        println("Success 1!");
    };

    if (y == 0b101)
    {
        println("Success 2!");
    };

    if (le_z)
    {
        println("Success 3!");
    };

    if (le_y == 0b101)
    {
        println("Success 4!");
    };

    -> 0;
};