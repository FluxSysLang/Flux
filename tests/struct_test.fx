#import <standard.fx>;

using standard::io::console;

struct bits
{
    data{1} a,b,c,d,e,f,g,h;
};

def main() -> int
{
    bits myb;

    myb
    {
        .a = 0;
        .b = 1;
        .c = 0;
        .c = 0;
        .d = 0;
        .e = 0;
        .f = 0;
        .g = 0;
        .h = 1;
    };

    byte[2] y = [myb, 0];

    println(@y);

	return 0;
};