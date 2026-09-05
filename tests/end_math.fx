#import <standard.fx>;

using standard::io::console;

def main() -> int
{
	data{16::0} as le_16;
	data{16}    as be_16;

	be_16 x = (le_16)5 + (be_16)5;

	if (x == 10)
	{
		println("Success!");
	};

	-> 0;
};