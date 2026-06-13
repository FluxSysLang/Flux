comptime
{
	compiler.fvm.loadlib("kernel32","dll");
	compiler.import.stdlib("standard.fx");

	using standard::io::console;

	def main() -> int
	{
		compiler.io.console.print("COMPTIME!\n");
		print("Hello at comptime using regular print!\n");
		return 0;
	};

	compiler.fvm.dump("C:\\Users\\kvthw\\Flux\\test2.fvm");
	FRTStartup();
};

def !!FRTStartup() -> int { return 0; };