#import <standard.fx>;

using standard::io::console;

struct A
{
    int x,y,z;
};

A a,b,c;

a.x = 10;

A[] g_arr = [a,b,c];

g_arr[0]
{
    .x = 20;
    .y = 30;
    .z = 40;
};

def main() -> int
{
    println(g_arr[0].x);
    println(g_arr[0].y);
    println(g_arr[0].z);
	return 0;
};