#import <standard.fx>, <format.fx>;

using standard::io::console,
      standard::strings,
      standard::strings::_fmt_impl;

def main() -> int
{
    byte[64] buf;
    int len;

    // --- float / double ---
    double pi = 3.14159265358979;
    len = format(pi, @buf[0], g".2f");
    print("pi .2f        : "); print(@buf[0]); print();

    len = format(pi, @buf[0], g".5f");
    print("pi .5f        : "); print(@buf[0]); print();

    len = format(pi, @buf[0], g"10.3f");
    print("pi 10.3f      : "); print(@buf[0]); print();

    len = format(pi, @buf[0], g"<10.3f");
    print("pi <10.3f     : "); print(@buf[0]); print();

    len = format(pi, @buf[0], g"^10.3f");
    print("pi ^10.3f     : "); print(@buf[0]); print();

    len = format(pi, @buf[0], g"+.4f");
    print("pi +.4f       : "); print(@buf[0]); print();

    len = format(pi, @buf[0], g".3e");
    print("pi .3e        : "); print(@buf[0]); print();

    len = format(pi, @buf[0], g".3E");
    print("pi .3E        : "); print(@buf[0]); print();

    // --- signed integer ---
    int count = 42;
    len = format(count, @buf[0], g"d");
    print("42 d          : "); print(@buf[0]); print();

    len = format(count, @buf[0], g"8d");
    print("42 8d         : "); print(@buf[0]); print();

    len = format(count, @buf[0], g"08d");
    print("42 08d        : "); print(@buf[0]); print();

    len = format(count, @buf[0], g"+d");
    print("42 +d         : "); print(@buf[0]); print();

    len = format(count, @buf[0], g"x");
    print("42 x          : "); print(@buf[0]); print();

    len = format(count, @buf[0], g"X");
    print("42 X          : "); print(@buf[0]); print();

    len = format(count, @buf[0], g"o");
    print("42 o          : "); print(@buf[0]); print();

    len = format(count, @buf[0], g"b");
    print("42 b          : "); print(@buf[0]); print();

    // negative
    int neg = -7;
    len = format(neg, @buf[0], g"d");
    print("-7 d          : "); print(@buf[0]); print();

    len = format(neg, @buf[0], g"08d");
    print("-7 08d        : "); print(@buf[0]); print();

    // int printed as float
    len = format(count, @buf[0], g".2f");
    print("42 .2f        : "); print(@buf[0]); print();

    // --- unsigned integer ---
    uint addr = 4294967295u;
    len = format(addr, @buf[0], g"X");
    print("0xFFFFFFFF X  : "); print(@buf[0]); print();

    len = format(addr, @buf[0], g"b");
    print("0xFFFFFFFF b  : "); print(@buf[0]); print();

    // --- string ---
    len = format(g"hello", @buf[0], g"s");
    print("hello s       : "); print(@buf[0]); print();

    len = format(g"hello", @buf[0], g"10s");
    print("hello 10s     : "); print(@buf[0]); print();

    len = format(g"hello", @buf[0], g">10s");
    print("hello >10s    : "); print(@buf[0]); print();

    len = format(g"hello", @buf[0], g"^10s");
    print("hello ^10s    : "); print(@buf[0]); print();

    len = format(g"hello", @buf[0], g".3s");
    print("hello .3s     : "); print(@buf[0]); print();

    len = format(g"hello", @buf[0], g"*>10s");
    print("hello *>10s   : "); print(@buf[0]); print();

    // --- bool ---
    len = format(true, @buf[0], g"");
    print("true          : "); print(@buf[0]); print();

    len = format(false, @buf[0], g"");
    print("false         : "); print(@buf[0]); print();

    // --- zero / edge cases ---
    double zero = 0.0;
    len = format(zero, @buf[0], g".2f");
    print("0.0 .2f       : "); print(@buf[0]); print();

    int izero;
    len = format(izero, @buf[0], g"08d");
    print("0 08d         : "); print(@buf[0]); print();

    len = format(izero, @buf[0], g"b");
    print("0 b           : "); print(@buf[0]); print();

    return 0;
};
