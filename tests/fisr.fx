#import <standard.fx>, <math.fx>;

using standard::io::console,
	  standard::math;

def main() -> int
{
    float x = fisr(5f);
    float y = fisr(5.0);

    println(x);
    println(y);

	return 0;
};