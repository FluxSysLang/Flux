// argparse_example.fx

#import <standard.fx>, <argparse.fx>;

using argparse;

def main(int argc, byte** argv) -> int
{
    Parser ap();

    ap.add_flag("--verbose\0",  "-v\0", "Enable verbose output\0");
    ap.add_flag("--help\0",     "-h\0", "Show this help message\0");
    ap.add_value("--input\0",   "-i\0", "Input file path\0",  true);
    ap.add_value_default("--output\0", "-o\0", "Output file path\0", "stdout\0");
    ap.add_int_default("--count\0",    "-c\0", "Number of iterations\0", 1);

    if (!ap.parse(argc, argv))
    {
        ap.print_help();
        return 1;
    };

    if (ap.get_flag("--help\0"))
    {
        ap.print_help();
        return 0;
    };

    bool  verbose = ap.get_flag("--verbose\0");
    byte* input   = ap.get_value("--input\0");
    byte* output  = ap.get_value("--output\0");
    int   count   = ap.get_int("--count\0");

    if (verbose)
    {
        print("Input:  \0"); println(input);
        print("Output: \0"); println(output);
        print("Count:  \0");
        byte[32] cbuf;
        i32str(count, @cbuf[0]);
        println(@cbuf[0]);
    };

    return 0;
};
