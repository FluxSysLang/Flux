#import <standard.fx>;

using standard::io::console;

"".repeat(int x) -> ""
{
    ulong slen = strlen(_),
          total = x * slen;

    heap byte s = fmalloc(total + 1);

    for (int c; c < x; c++)
    {
        fmemcpy(s + c * slen, _, slen);
    };

    s[total] = 0;
    return s;
};

def main() -> int
{
    print("Hello!".repeat(3));
    return 0;
};