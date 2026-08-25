#import <standard.fx>;

using standard::io::console;

struct MyS
{
    noopstr[3] one,
               two,
               thr;
};

noopstr[3] test =
[
    "String 1",
    "string 2",
    "string 3!"
],
           test2 =
[
    "ABC",
    "123",
    "XYZ"
],
           test3 =
[
    "123456789",
    "abcdefghi",
    "zyxwvutsr"
];

def main() -> int
{
    println(test[0]);
    test
    {
        [0] = "Another!?";
    };
    println(test[0]);
    
    MyS s;

    s
    {
        .one = test;
        .two = test2;
        .thr = test3;
    };

    println(s.one[0]);

	return 0;
};