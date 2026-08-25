// argparse.fx -- Command-line argument parser for Flux
// Usage: #import "argparse.fx";
//
// argc/argv convention (as documented):
//   argc == 0            -> no args, argv is invalid, do not read it
//   argc == 2            -> program + one flag  (e.g. program.exe --flag)
//   argc == 3            -> program + flag + value
//
// The real argument tokens start at argv[1] (argv[0] is the program name).
// This library hides that detail; callers always work with named args.

#ifndef FLUX_ARGPARSE
#def FLUX_ARGPARSE 1;

#ifndef FLUX_STANDARD_STRINGS
#import <utility\string_utilities.fx>;
#endif;

#ifndef FLUX_STANDARD_IO
#import <io.fx>;
#endif;

using standard::strings;
using standard::io::console;

namespace argparse
{
    // -----------------------------------------------------------------
    // Argument kinds
    // -----------------------------------------------------------------
    #def ARG_KIND_FLAG  0;   // --flag          (bool, no value token)
    #def ARG_KIND_VALUE 1;   // --key val        (string value follows)
    #def ARG_KIND_INT   2;   // --key 42         (integer value follows)

    // Maximum number of registered argument definitions and parsed results.
    #def ARGPARSE_MAX_ARGS 64;

    // Maximum length of a flag name (including the leading "--").
    #def ARGPARSE_NAME_MAX 64;

    // -----------------------------------------------------------------
    // Internal: one registered argument definition
    // -----------------------------------------------------------------
    struct ArgDef
    {
        byte[ARGPARSE_NAME_MAX] name;   // e.g. "--output\0"
        byte[ARGPARSE_NAME_MAX] shortname; // e.g. "-o\0", empty if none
        int  kind;                       // ARG_KIND_*
        bool required;
        byte[ARGPARSE_NAME_MAX] helptext;
        // Default value storage (used when arg is not present)
        byte[ARGPARSE_NAME_MAX] default_str;
        int  default_int;
        bool has_default;
    };

    // -----------------------------------------------------------------
    // Internal: one parsed result slot
    // -----------------------------------------------------------------
    struct ArgResult
    {
        byte[ARGPARSE_NAME_MAX] name;   // matches the ArgDef name
        bool present;                   // was this flag/key seen?
        bool bool_val;                  // for ARG_KIND_FLAG
        byte[256] str_val;              // for ARG_KIND_VALUE
        int  int_val;                   // for ARG_KIND_INT
    };

    // -----------------------------------------------------------------
    // Parser object
    // -----------------------------------------------------------------
    object Parser
    {
        ArgDef[ARGPARSE_MAX_ARGS]    defs;
        ArgResult[ARGPARSE_MAX_ARGS] results;
        int  def_count;
        bool parsed;
        bool allow_unknown;   // if false, unknown flags cause parse_error
        byte[256] prog_name;  // argv[0], filled in after parse()

        // ---- construction -------------------------------------------

        def __init() -> this
        {
            this.def_count    = 0;
            this.parsed       = false;
            this.allow_unknown = false;
            return this;
        };

        def __expr() -> Parser* { return this; };
        def __exit() -> void { (void)this; };

        // ---- registration helpers -----------------------------------

        // Copy src into a fixed char buffer of size ARGPARSE_NAME_MAX.
        // Private helper; not part of the trait surface.
        def copy_name(byte* dest, byte* src) -> void
        {
            int i;
            while (src[i] != 0 & i < (ARGPARSE_NAME_MAX - 1))
            {
                dest[i] = src[i];
                i++;
            };
            dest[i] = (byte)0;
        };

        // Find a def slot by long name; returns index or -1.
        def find_def(byte* name) -> int
        {
            for (int i; i < this.def_count; i++)
            {
                if (strcmp(@this.defs[i].name[0], name) == 0)
                {
                    return i;
                };
            };
            return -1;
        };

        // Find a def slot by long or short name; returns index or -1.
        def find_def_any(byte* token) -> int
        {
            for (int i; i < this.def_count; i++)
            {
                if (strcmp(@this.defs[i].name[0], token) == 0)
                {
                    return i;
                };
                if (this.defs[i].shortname[0] != 0
                    & strcmp(@this.defs[i].shortname[0], token) == 0)
                {
                    return i;
                };
            };
            return -1;
        };

        // ---- public registration API --------------------------------

        // Register a boolean flag (presence = true, absence = false).
        def add_flag(byte* name, byte* shortname, byte* help) -> bool
        {
            if (this.def_count >= ARGPARSE_MAX_ARGS) { return false; };
            int idx = this.def_count;
            this.copy_name(@this.defs[idx].name[0], name);
            this.copy_name(@this.defs[idx].shortname[0], shortname);
            this.copy_name(@this.defs[idx].helptext[0], help);
            this.defs[idx].kind       = ARG_KIND_FLAG;
            this.defs[idx].required   = false;
            this.defs[idx].has_default = false;
            this.def_count++;
            return true;
        };

        // Register a string-value argument.
        def add_value(byte* name, byte* shortname, byte* help, bool required) -> bool
        {
            if (this.def_count >= ARGPARSE_MAX_ARGS) { return false; };
            int idx = this.def_count;
            this.copy_name(@this.defs[idx].name[0], name);
            this.copy_name(@this.defs[idx].shortname[0], shortname);
            this.copy_name(@this.defs[idx].helptext[0], help);
            this.defs[idx].kind     = ARG_KIND_VALUE;
            this.defs[idx].required = required;
            this.defs[idx].has_default = false;
            this.def_count++;
            return true;
        };

        // Register a string-value argument with a default.
        def add_value_default(byte* name, byte* shortname, byte* help, byte* default_val) -> bool
        {
            if (!this.add_value(name, shortname, help, false)) { return false; };
            int idx = this.def_count - 1;
            this.copy_name(@this.defs[idx].default_str[0], default_val);
            this.defs[idx].has_default = true;
            return true;
        };

        // Register an integer-value argument.
        def add_int(byte* name, byte* shortname, byte* help, bool required) -> bool
        {
            if (this.def_count >= ARGPARSE_MAX_ARGS) { return false; };
            int idx = this.def_count;
            this.copy_name(@this.defs[idx].name[0], name);
            this.copy_name(@this.defs[idx].shortname[0], shortname);
            this.copy_name(@this.defs[idx].helptext[0], help);
            this.defs[idx].kind     = ARG_KIND_INT;
            this.defs[idx].required = required;
            this.defs[idx].has_default = false;
            this.def_count++;
            return true;
        };

        // Register an integer-value argument with a default.
        def add_int_default(byte* name, byte* shortname, byte* help, int default_val) -> bool
        {
            if (!this.add_int(name, shortname, help, false)) { return false; };
            int idx = this.def_count - 1;
            this.defs[idx].default_int = default_val;
            this.defs[idx].has_default = true;
            return true;
        };

        // ---- copy helpers for results --------------------------------

        def copy_result_str(byte* dest, byte* src) -> void
        {
            int i;
            while (src[i] != 0 & i < 255)
            {
                dest[i] = src[i];
                i++;
            };
            dest[i] = (byte)0;
        };

        // ---- parse --------------------------------------------------

        // Parse argc/argv as documented:
        //   argc == 0 -> no args (argv invalid)
        //   argc >= 2 -> argv[0] = program name, argv[1..argc-1] = tokens
        //
        // Returns true on success, false if a required arg is missing or
        // an unknown flag is encountered with allow_unknown == false.
        def parse(int argc, byte** argv) -> bool
        {
            // Initialize all result slots from defs
            for (int i; i < this.def_count; i++)
            {
                this.copy_name(@this.results[i].name[0], @this.defs[i].name[0]);
                this.results[i].present  = false;
                this.results[i].bool_val = false;
                this.results[i].int_val  = 0;
                this.results[i].str_val[0] = (byte)0;

                // Pre-populate defaults
                if (this.defs[i].has_default)
                {
                    if (this.defs[i].kind == ARG_KIND_VALUE)
                    {
                        this.copy_result_str(@this.results[i].str_val[0],
                                             @this.defs[i].default_str[0]);
                    }
                    elif (this.defs[i].kind == ARG_KIND_INT)
                    {
                        this.results[i].int_val = this.defs[i].default_int;
                    };
                };
            };

            // Nothing to do when no args were passed
            if (argc == 0)
            {
                this.parsed = true;
                return this.check_required();
            };

            // Store program name (argv[0])
            this.copy_result_str(@this.prog_name[0], argv[0]);

            // Walk tokens argv[1] .. argv[argc-1]
            int i = 1;
            while (i < argc)
            {
                byte* token = argv[i];

                // Skip empty tokens
                if (token[0] == 0)
                {
                    i++;
                    continue;
                };

                int def_idx = this.find_def_any(token);
                if (def_idx < 0)
                {
                    if (!this.allow_unknown)
                    {
                        println("argparse error: unknown argument: \0");
                        println(token);
                        return false;
                    };
                    i++;
                    continue;
                };

                int kind = this.defs[def_idx].kind;

                if (kind == ARG_KIND_FLAG)
                {
                    this.results[def_idx].present  = true;
                    this.results[def_idx].bool_val = true;
                    i++;
                }
                elif (kind == ARG_KIND_VALUE)
                {
                    i++;
                    if (i >= argc)
                    {
                        println("argparse error: missing value for: \0");
                        println(token);
                        return false;
                    };
                    this.results[def_idx].present = true;
                    this.copy_result_str(@this.results[def_idx].str_val[0], argv[i]);
                    i++;
                }
                elif (kind == ARG_KIND_INT)
                {
                    i++;
                    if (i >= argc)
                    {
                        println("argparse error: missing integer value for:\0");
                        println(token);
                        return false;
                    };
                    this
                    {
                        .results[def_idx]
                        {
                            .present = true;
                            .int_val = str2i32(argv[i]);
                        };
                    };
                    i++;
                }
                else
                {
                    i++;
                };
            };

            this.parsed = true;
            return this.check_required();
        };

        // ---- internal: check all required args were supplied --------

        def check_required() -> bool
        {
            for (int i; i < this.def_count; i++)
            {
                if (this.defs[i].required & !this.results[i].present)
                {
                    println("argparse error: required argument missing: \0");
                    println(@this.defs[i].name[0]);
                    return false;
                };
            };
            return true;
        };

        // ---- result accessors --------------------------------------

        // Find a result slot index; returns -1 if not found.
        def find_result(byte* name) -> int
        {
            for (int i; i < this.def_count; i++)
            {
                if (strcmp(@this.results[i].name[0], name) == 0)
                {
                    return i;
                };
            };
            return -1;
        };

        // Returns true if the flag/arg was present on the command line.
        def is_present(byte* name) -> bool
        {
            int idx = this.find_result(name);
            if (idx < 0) { return false; };
            return this.results[idx].present;
        };

        // Get boolean value of a flag (true = flag was passed).
        def get_flag(byte* name) -> bool
        {
            int idx = this.find_result(name);
            if (idx < 0) { return false; };
            return this.results[idx].bool_val;
        };

        // Get string value of an ARG_KIND_VALUE argument.
        // Returns a pointer into the internal result buffer.
        // Valid until the Parser goes out of scope.
        def get_value(byte* name) -> byte*
        {
            int idx = this.find_result(name);
            if (idx < 0) { return (byte*)0; };
            return @this.results[idx].str_val[0];
        };

        // Get integer value of an ARG_KIND_INT argument.
        def get_int(byte* name) -> int
        {
            int idx = this.find_result(name);
            if (idx < 0) { return 0; };
            return this.results[idx].int_val;
        };

        // ---- help generation ---------------------------------------

        def print_help() -> void
        {
            println("Usage:\0");
            print("  \0");
            println(@this.prog_name[0]);
            println("\0");
            println("Options:\0");
            for (int i; i < this.def_count; i++)
            {
                print("  \0");
                print(@this.defs[i].name[0]);

                if (this.defs[i].shortname[0] != 0)
                {
                    print(", \0");
                    print(@this.defs[i].shortname[0]);
                };

                if (this.defs[i].kind == ARG_KIND_VALUE)
                {
                    print(" <string>\0");
                }
                elif (this.defs[i].kind == ARG_KIND_INT)
                {
                    print(" <int>\0");
                };

                if (this.defs[i].required)
                {
                    print(" [required]\0");
                };

                print("  \0");
                println(@this.defs[i].helptext[0]);

                if (this.defs[i].has_default)
                {
                    print("    default: \0");
                    if (this.defs[i].kind == ARG_KIND_VALUE)
                    {
                        println(@this.defs[i].default_str[0]);
                    }
                    elif (this.defs[i].kind == ARG_KIND_INT)
                    {
                        byte[32] numbuf;
                        i32str(this.defs[i].default_int, @numbuf[0]);
                        println(@numbuf[0]);
                    };
                };
            };
        };
    };

}; // namespace argparse

#endif; // FLUX_ARGPARSE
