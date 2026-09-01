#import <standard.fx>;

using standard::io::console;

def main() -> int
{
	byte b;

	b[`7] = 1;

	print("Success!") if (b == 1);
	-> b[`0];
};