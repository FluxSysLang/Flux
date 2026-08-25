#import <standard.fx>;

using standard::io::console;

constraint X(A)
{
    A !@ A
};

struct A<T>
{
    T x;
};

def foo<T, :{X}>(T a) -> A<T>
{
    return {(T)a};
};

trait F
{
    def baz() -> void;
};

F object FOO<T>
{
    T x;
    def __init(T a) -> this { this.x = a; return this; };
    def __expr() -> FOO<T>* { return this; };
    def __exit() -> void { (void)this; };

    def baz() -> void {};
};

def main() -> int
{
    A<int> a = foo(10);

    println(a.x);

    return 0;
};