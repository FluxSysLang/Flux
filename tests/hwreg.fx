#import <standard.fx>;

using standard::io::console;

struct MV
{
	char control, direction, parity, stopbits;
};

union HWReg
{
    MV mv;
	uint reg;
};

def main() -> int
{
    HWReg hwreg;

    hwreg.reg = 0x41424344u;

    println(f"{hwreg.mv.control}");
	return 0;
};