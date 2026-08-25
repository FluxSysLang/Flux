#import <standard.fx>;

using standard::io::console;

def main() -> int
{
	char x = 10;

	switch (typeof(x))
	{
		case (typeof(int))
		{
			println("x is an integer!");
		}
		case (typeof(float))
		{
			println("x is a float!");
		}
		default
		{
			println("x isn't a type I know!");
		};
	};

	return 0;
};