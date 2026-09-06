#import <standard.fx>;

using standard::io::console;


comptime
{
    data{16::0} le_x = 5; // 0b00000101 00000000 in LE
    data{16}    be_x = 5; // 0b00000000 00000101 in BE

    byte x = 5;

    data{3} y = x[5``7];

    data{3} le_y = le_x[5``7],
            be_y = be_x[13``15];

    data{1} z = x[5``7][`0];

    data{1} le_z = le_x[5``7][`0],
            be_z = be_x[13``15][`0];

    if (z)
    {
        compiler.io.console.println("Success 1!");
    };

    if (y == 0b101)
    {
        compiler.io.console.println("Success 2!");
    };

    if (le_z)
    {
        compiler.io.console.println("Success 3!");
    };

    if (be_z)
    {
        compiler.io.console.println("Success 4!");
    };

    if (le_y == 0b101)
    {
        compiler.io.console.println("Success 5!");
    };

    if (be_y == 0b101)
    {
        compiler.io.console.println("Success 6!");
    };
};


def main() -> int
{
    data{16::0} le_x = 5; // 0b00000101 00000000 in LE
    data{16}    be_x = 5; // 0b00000000 00000101 in BE

    byte x = 5;

    data{3} y = x[5``7];

    data{3} le_y = le_x[5``7];
    data{3} be_y = be_x[13``15];

    data{1} z = x[5``7][`0];

    data{1} le_z = le_x[5``7][`0];
    data{1} be_z = be_x[13``15][`0];

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

    if (be_z)
    {
        println("Success 4!");
    };

    if (le_y == 0b101)
    {
        println("Success 5!");
    };

    if (be_y == 0b101)
    {
        println("Success 6!");
    };

    -> 0;
};