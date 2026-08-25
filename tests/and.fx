#import <standard.fx>;

using standard::io::console;

struct Point2D
{
    int x, y;
};

def main() -> int
{
    Point2D a = {20, 50};
    Point2D b = {10, 100};

    float x = a.x / b.x,
          y = a.y / b.y;

    if (x > 0f and y > 0f)
    {
        println(x);
        println(y);
    }
    else
    {
        println("Integer division of floats will fail. Convert beforehand.");
    };

    x = float(a.x) / float(b.x);
    y = float(a.y) / float(b.y);

    if (x > 0f and y > 0f)
    {
        println(x);
        println(y);
    };

    return 0;
};