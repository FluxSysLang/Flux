#import <standard.fx>;

using standard::io::console;

struct MyStru
{
	int x;
};

MyStru[].len() -> int
{
    // sizeof(_) is returning the size of a pointer which is 64.
    // Should be 128
    println(f"sizeof(_): {sizeof(_)}");
	return sizeof(_) / sizeof(MyStru); // 64 / 32
};

def main() -> int
{
    //println(sizeof(MyStru));  // 32
    MyStru[] a =
    [
        {1},
        {2},
        {3},
        {4}
    ];
    //println(sizeof(a)); // 128

    println(a.len());   // 2

	return 0;
};