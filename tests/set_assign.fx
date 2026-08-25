#import <standard.fx>;

using standard::io::console;

noopstr[3] test =
[
    "String 1",
    "string 2",
    "string 3!"
];

test
{
    [0] = "New string!";
    [1] = "Another one!";
    [2] = "Changed again?";
};

struct obs
{
    noopstr x = "DEFAULT";
};

obs[3] nobs;

nobs[0]
{
    .x = "NOT DEFAULT";
};
nobs[1]
{
    .x = "NOT DEFAULT 2";
};

def main() -> int
{
    int i;
    println(test[i++]);
    #";
    #";

    i = 0;

    println(nobs[i++].x);
    #";
    return 0;
};