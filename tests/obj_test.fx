#import <standard.fx>;

using standard::io::console;

trait MyT1
{
    def pv() -> void;
};

trait MyT2
{
    def vp() -> void;
};

trait MyT3 = MyT1 & MyT2;

MyT3 object test
{
    def __init() -> this
    {
        return this;
    };

    def __expr() -> test*
    {
        return this;
    };

    def __exit() -> void { (void)this; };

    def pv() -> void { println("TEST"); };
    def vp() -> void {};
};

def main() -> int
{
    test t();

    t.__exit();

    t.pv();    // ERROR
    return 0;
};