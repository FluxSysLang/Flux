#import <standard.fx>;

using standard::io::console;

dict{"":""} myDict
{
    "Hello": "World!",
    "hey": "you"
};

dict{"":""} myDict2
{
    "ABC": "DEF",
    "GHI": "JKL"
};

dict{"":""} myDict3 = myDict + myDict2;

def foo<T,U>(dict{T:U} d) -> dict{T:U}
{
    -> d;
};

struct Account
{
    bool logged_in;
};

constraint myC(A, B, C, D)
{
    D !~= B & [A !@ A] !~= C !`< D !-= A
};

Account a;

//a.logged_in = true;

byte* status = d{ (a.logged_in) : "Logged In",
                  (!a.logged_in): "Guest"
                }[true];

def main() -> int
{
    println(foo(myDict2)["ABC"]);
    println(myDict["hey"]);
    println(myDict2["GHI"]);
    println(myDict3["ABC"]);
    println(status);
    -> 0;
};