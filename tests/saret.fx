// Sized-Array Return test.

#import <standard.fx>;

using standard::io::console;


def foo() -> byte[3]
{
    return "AB";
};


def main() -> int
{
	println(@foo());

	return 0;
};