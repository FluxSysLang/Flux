#import <standard.fx>;

using standard::io::console;

struct X
{
	int j,k;
};

ulong enum MyE1
{
	A, B, C, D
};

X enum MyE2
{
	A, B, C, D
};

def main() -> int
{
	MyE2 E2;

	E2.A.j = 5;
	println(E2.A.j);
	-> 0;
};