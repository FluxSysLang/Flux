// fpreprocess.fx
// Flux source preprocessor -- translated from fpreprocess.py

#import <standard.fx>, <types.fx>, <string_utilities.fx>, <argparse.fx>;

using standard::io::console,
      standard::io::file,
      standard::strings,
      standard::strings::helpers,
      standard::strings::manip,
      argparse;

// ---------------------------------------------------------------------------
// Capacity limits
// ---------------------------------------------------------------------------
#def MAX_FILES       256;
#def MAX_LINES       65536;
#def MAX_CONSTANTS   512;
#def MAX_PSUBS       128;
#def MAX_LIB_DIRS    64;
#def MAX_DIR_STACK   64;
#def MAX_BRANCHES    32;
#def MAX_PSUB_PARAMS 16;

// ---------------------------------------------------------------------------
// Data structures
// ---------------------------------------------------------------------------

struct KVEntry
{
    byte* key, value;
};

struct PSubParam
{
    byte* name;
};

struct PSub
{
    byte*                      name;
    int                        param_count;
    PSubParam[MAX_PSUB_PARAMS] params;
    byte*                      body;
};

struct LineOrigin
{
    byte* filename;
    int   lineno;
};

// ---------------------------------------------------------------------------
// FXPreprocessor object
// ---------------------------------------------------------------------------
object FXPreprocessor
{
    byte* source_file;

    byte*[MAX_FILES]     processed_files;
    int                  processed_count;

    byte*[MAX_LINES]     output_lines;
    int                  output_count;

    KVEntry[MAX_CONSTANTS] constants;
    int                    constant_count;

    PSub[MAX_PSUBS]      psubs;
    int                  psub_count;

    byte*[MAX_LIB_DIRS]  lib_dirs;
    int                  lib_dir_count;

    LineOrigin[MAX_LINES] line_map;

    byte*[MAX_DIR_STACK] dir_stack;
    int                  dir_stack_top;

    byte* current_file;
    int   current_local_lineno;

    // -----------------------------------------------------------------------
    def __init(byte* src) -> this
    {
        this.source_file  = src;
        this.current_file = src;
        return this;
    };

    def __expr() -> FXPreprocessor* { return this; };
    def __exit() -> void { return; };

    // -----------------------------------------------------------------------
    // add_constant: register a compiler-injected constant before processing
    // -----------------------------------------------------------------------
    def add_constant(byte* key, byte* value) -> void
    {
        if (this.constant_count >= MAX_CONSTANTS) { return; };
        this.constants[this.constant_count].key   = key;
        this.constants[this.constant_count].value = value;
        this.constant_count = this.constant_count + 1;
    };

    // -----------------------------------------------------------------------
    // process: main entry point. Returns 0 on success.
    // -----------------------------------------------------------------------
    def process() -> int
    {
        if (this._process_file(this.source_file, 0) != 0)
        {
            return 1;
        };

        // Constant substitution passes until stable
        bool replaced = true;
        int  iteration;
        byte* new_line;

        while (replaced)
        {
            replaced  = false;
            iteration = iteration + 1;
            print(g"[PREPROCESSOR] constant substitution passes: ");
            println(iteration);

            for (int li; li < this.output_count; li = li + 1)
            {
                new_line = this._substitute_constants(this.output_lines[li]);
                if (strcmp(new_line, this.output_lines[li]) != 0)
                {
                    replaced = true;
                    this.output_lines[li] = new_line;
                };
            };
        };

        if (iteration == 1)
        {
            println(g"[PREPROCESSOR] Completed after 1 constant pass.");
        }
        else
        {
            print(g"[PREPROCESSOR] Completed after ");
            print(iteration);
            println(g" constant passes.");
        };

        // Write build/tmp.fx
        file fh(g"build/tmp.fx\0", g"wb\0");
        if (!fh.is_open())
        {
            println(g"[PREPROCESSOR] ERROR: Cannot open build/tmp.fx for writing");
            return 1;
        };

        for (int li; li < this.output_count; li = li + 1)
        {
            fh.write_line(this.output_lines[li]);
        };
        fh.close();

        println(g"[PREPROCESSOR] Generated: build/tmp.fx");
        print(g"[PREPROCESSOR] Processed ");
        print(this.processed_count);
        println(g" file(s)");

        return 0;
    };

    // -----------------------------------------------------------------------
    // Internal: dedup guard
    // -----------------------------------------------------------------------
    def _already_processed(byte* path) -> bool
    {
        for (int k; k < this.processed_count; k = k + 1)
        {
            if (strcmp(this.processed_files[k], path) == 0) { return true; };
        };
        return false;
    };

    // -----------------------------------------------------------------------
    // Path resolution
    // mode: 0 = auto, 1 = local only, 2 = stdlib only
    // Returns allocated resolved path, or null on failure.
    // -----------------------------------------------------------------------
    def _resolve(byte* filepath, int mode) -> byte*
    {
        // Stdlib search paths
        byte* stdlib_root = g"src/stdlib\0";
        byte*[5] subdirs;
        subdirs[0] = g"src/stdlib\0";
        subdirs[1] = g"src/stdlib/runtime\0";
        subdirs[2] = g"src/stdlib/functions\0";
        subdirs[3] = g"src/stdlib/builtins\0";
        subdirs[4] = g"src/stdlib/utility\0";

        if (mode == 2)
        {
            // Stdlib only
            byte* candidate;
            byte* full;
            for (int k; k < 5; k = k + 1)
            {
                candidate = manip::concat(subdirs[k], g"/\0");
                full = manip::concat(candidate, filepath);
                ffree((u64)candidate);
                if (fopen(full, g"rb\0") != (void*)0)
                {
                    return full;
                };
                ffree((u64)full);
            };
            return (byte*)0;
        };

        if (mode == 1 | mode == 0)
        {
            // 1. Top of dir_stack
            if (this.dir_stack_top > 0)
            {
                byte* base = this.dir_stack[this.dir_stack_top - 1];
                byte* sep  = manip::concat(base, g"/\0");
                byte* full = manip::concat(sep, filepath);
                ffree((u64)sep);
                void* fh = fopen(full, g"rb\0");
                if ((u64)fh != 0)
                {
                    fclose(fh);
                    return full;
                };
                ffree((u64)full);
            };

            // 2. Root source file directory
            int last_sep = helpers::find_char_last(this.source_file, '/');
            if (last_sep >= 0)
            {
                byte* root_dir = manip::copy_n(this.source_file, last_sep + 1);
                byte* full = manip::concat(root_dir, filepath);
                ffree((u64)root_dir);
                void* fh = fopen(full, g"rb\0");
                if ((u64)fh != 0)
                {
                    fclose(fh);
                    return full;
                };
                ffree((u64)full);
            };

            // 3. Direct path (CWD-relative)
            void* fh = fopen(filepath, g"rb\0");
            if ((u64)fh != 0)
            {
                fclose(fh);
                return manip::copy_string(filepath);
            };

            // 4. Extra lib_dirs
            byte* sep;
            byte* full;
            for (int k; k < this.lib_dir_count; k = k + 1)
            {
                sep  = manip::concat(this.lib_dirs[k], g"/\0");
                full = manip::concat(sep, filepath);
                ffree((u64)sep);
                fh = fopen(full, g"rb\0");
                if ((u64)fh != 0)
                {
                    fclose(fh);
                    return full;
                };
                ffree((u64)full);
            };

            if (mode == 1) { return (byte*)0; };

            // mode 0: fall through to stdlib
            byte* sep2;
            byte* full2;
            for (int k; k < 5; k = k + 1)
            {
                sep2  = manip::concat(subdirs[k], g"/\0");
                full2 = manip::concat(sep2, filepath);
                ffree((u64)sep2);
                fh = fopen(full2, g"rb\0");
                if ((u64)fh != 0)
                {
                    fclose(fh);
                    return full2;
                };
                ffree((u64)full2);
            };
        };

        return (byte*)0;
    };

    // -----------------------------------------------------------------------
    // _process_package: resolve .fpm/packages/<name>/package.json and process
    // -----------------------------------------------------------------------
    def _process_package(byte* pkg_name) -> int
    {
        byte* pkg_base = manip::concat(g".fpm/packages/\0", pkg_name);
        byte* manifest = manip::concat(pkg_base, g"/package.json\0");

        void* fh = fopen(manifest, g"rb\0");
        if ((u64)fh == 0)
        {
            print(g"[PREPROCESSOR] ERROR: Package not found: ");
            println(pkg_name);
            ffree((u64)pkg_base);
            ffree((u64)manifest);
            return 1;
        };

        // Read package.json
        fseek(fh, 0, SEEK_END);
        int sz = ftell(fh);
        fseek(fh, 0, SEEK_SET);
        byte* buf = (byte*)fmalloc((u64)sz + 1);
        fread(buf, 1, sz, fh);
        fclose(fh);
        buf[sz] = 0;
        ffree((u64)manifest);

        // Extract "entrypoint": "..." from JSON (simple scan)
        byte* ep_key = strstr(buf, g"\"entrypoint\"\0");
        if ((u64)ep_key == 0)
        {
            print(g"[PREPROCESSOR] ERROR: No entrypoint in package: ");
            println(pkg_name);
            ffree((u64)buf);
            ffree((u64)pkg_base);
            return 1;
        };

        byte* colon = strchr(ep_key, ':');
        if ((u64)colon == 0)
        {
            ffree((u64)buf);
            ffree((u64)pkg_base);
            return 1;
        };

        colon = colon + 1;
        while (colon[0] == ' ' | colon[0] == '\t') { colon = colon + 1; };
        if (colon[0] != '"')
        {
            ffree((u64)buf);
            ffree((u64)pkg_base);
            return 1;
        };
        colon = colon + 1;  // skip opening quote

        int eplen;
        while (colon[eplen] != 0 & colon[eplen] != '"') { eplen = eplen + 1; };
        byte* ep_rel = manip::copy_n(colon, eplen);
        ffree((u64)buf);

        byte* sep       = manip::concat(pkg_base, g"/\0");
        byte* ep_full   = manip::concat(sep, ep_rel);
        ffree((u64)sep);
        ffree((u64)ep_rel);

        if (this._already_processed(ep_full))
        {
            ffree((u64)pkg_base);
            ffree((u64)ep_full);
            return 0;
        };

        print(g"[PREPROCESSOR] Package import: ");
        print(pkg_name);
        print(g" -> ");
        println(ep_full);

        if (this.dir_stack_top < MAX_DIR_STACK)
        {
            this.dir_stack[this.dir_stack_top] = pkg_base;
            this.dir_stack_top = this.dir_stack_top + 1;
        };

        int rc = this._process_file(ep_full, 1);

        this.dir_stack_top = this.dir_stack_top - 1;
        ffree((u64)ep_full);
        return rc;
    };

    // -----------------------------------------------------------------------
    // _process_file: read, strip comments, and process one file
    // mode: 0 = auto, 1 = local, 2 = stdlib
    // -----------------------------------------------------------------------
    def _process_file(byte* filepath, int mode) -> int
    {
        byte* resolved = this._resolve(filepath, mode);
        if ((u64)resolved == 0)
        {
            // Hint for local imports that should be stdlib
            if (mode == 1)
            {
                byte* stdlib_check = this._resolve(filepath, 2);
                if ((u64)stdlib_check != 0)
                {
                    print(g"[PREPROCESSOR] Could not find local import: ");
                    println(filepath);
                    print(g"#import \"");
                    print(filepath);
                    println(g"\";");
                    println(g"--------^");
                    print(g"#import <");
                    print(filepath);
                    println(g">; // try this");
                    ffree((u64)stdlib_check);
                    return 1;
                };
            };
            print(g"[PREPROCESSOR] ERROR: File not found: ");
            println(filepath);
            return 1;
        };

        if (this._already_processed(resolved))
        {
            ffree((u64)resolved);
            return 0;
        };

        if (this.processed_count < MAX_FILES)
        {
            this.processed_files[this.processed_count] = resolved;
            this.processed_count = this.processed_count + 1;
        };

        print(g"[PREPROCESSOR] Processing: ");
        println(filepath);

        // Read file
        void* fh = fopen(resolved, g"rb\0");
        fseek(fh, 0, SEEK_END);
        int sz = ftell(fh);
        fseek(fh, 0, SEEK_SET);

        byte* raw = (byte*)fmalloc((u64)sz + 2);
        int bytes_read = fread(raw, 1, sz, fh);
        fclose(fh);
        raw[bytes_read] = 0;

        // Strip UTF-8 BOM
        byte* content = raw;
        if ((byte)content[0] == (byte)0xEFb &
            (byte)content[1] == (byte)0xBBb &
            (byte)content[2] == (byte)0xBFb)
        {
            content = content + 3;
        };

        // Strip comments
        byte* stripped = this._strip_comments(content);
        ffree((u64)raw);

        // Enforce semicolons on directives
        if (this._check_directive_semicolons(stripped, resolved) != 0)
        {
            ffree((u64)stripped);
            return 1;
        };

        // Save/restore context
        byte* prev_file    = this.current_file;
        int   prev_lineno  = this.current_local_lineno;
        this.current_file  = resolved;

        // Push this file's directory
        int last_sep = helpers::find_char_last(resolved, '/');
        if (last_sep >= 0 & this.dir_stack_top < MAX_DIR_STACK)
        {
            this.dir_stack[this.dir_stack_top] = manip::copy_n(resolved, last_sep + 1);
            this.dir_stack_top = this.dir_stack_top + 1;
        };

        // Split into lines and process
        string s(stripped, strlen(stripped));
        byte** lines = s.split('\n');
        ffree((u64)stripped);

        int rc = 0;
        int i  = 0;
        int next;
        while ((u64)lines[i] != 0)
        {
            this.current_local_lineno = i + 1;
            next = this._process_line(lines, i);
            if (next < 0) { rc = 1; break; };
            i = next;
        };

        // Free split lines
        for (int k; (u64)lines[k] != 0; k = k + 1) { ffree((u64)lines[k]); };
        ffree((u64)lines);

        if (last_sep >= 0)
        {
            ffree((u64)this.dir_stack[this.dir_stack_top - 1]);
            this.dir_stack_top = this.dir_stack_top - 1;
        };

        this.current_file             = prev_file;
        this.current_local_lineno     = prev_lineno;

        return rc;
    };

    // -----------------------------------------------------------------------
    // _check_directive_semicolons: pre-scan stripped content for missing ;
    // -----------------------------------------------------------------------
    def _check_directive_semicolons(byte* content, byte* filepath) -> int
    {
        string s(content, strlen(content));
        byte** lines = s.split('\n');
        int rc = 0;

        string line;
        byte* t;
        bool is_directive;
        byte[32] num;
        for (int i; (u64)lines[i] != 0; i = i + 1)
        {
            line.set(lines[i]);
            line.trim();
            t = line.val();

            is_directive =
                helpers::starts_with(t, g"#import\0")  |
                helpers::starts_with(t, g"#package\0") |
                helpers::starts_with(t, g"#warn\0")    |
                helpers::starts_with(t, g"#stop\0")    |
                helpers::starts_with(t, g"#def\0")     |
                helpers::starts_with(t, g"#dir\0");

            if (is_directive & !helpers::ends_with(t, g";\0"))
            {
                i32str(i + 1, @num[0]);
                print(g"[PREPROCESSOR] ERROR: Directive missing semicolon in ");
                print(filepath);
                print(g" at line ");
                println(@num[0]);
                rc = 1;
                break;
            };
        };

        for (int k; (u64)lines[k] != 0; k = k + 1) { ffree((u64)lines[k]); };
        ffree((u64)lines);
        return rc;
    };

    // -----------------------------------------------------------------------
    // _emit_blank / _emit_line
    // -----------------------------------------------------------------------
    def _emit_blank() -> void
    {
        if (this.output_count >= MAX_LINES) { return; };
        this.output_lines[this.output_count]          = g"\0";
        this.line_map[this.output_count].filename     = this.current_file;
        this.line_map[this.output_count].lineno       = this.current_local_lineno;
        this.output_count = this.output_count + 1;
    };

    def _emit_line(byte* line) -> void
    {
        if (this.output_count >= MAX_LINES) { return; };
        this.output_lines[this.output_count]          = manip::copy_string(line);
        this.line_map[this.output_count].filename     = this.current_file;
        this.line_map[this.output_count].lineno       = this.current_local_lineno;
        this.output_count = this.output_count + 1;
    };

    // -----------------------------------------------------------------------
    // _process_line: dispatch one line. Returns next index or -1 on error.
    // lines is a null-terminated byte** from split('\n').
    // -----------------------------------------------------------------------
    def _process_line(byte** lines, int i) -> int
    {
        byte* line = lines[i];
        string s(line);
        s.trim();
        byte* t = s.val();

        // Empty line
        if (t[0] == 0)
        {
            this._emit_blank();
            return i + 1;
        };

        // #dir
        if (helpers::starts_with(t, g"#dir\0"))
        {
            this._handle_dir(line);
            this._emit_blank();
            return i + 1;
        };

        // #psub  (collect continuation lines ending with #)
        if (helpers::starts_with(t, g"#psub\0"))
        {
            byte* rest = manip::copy_string(t + 5);

            string rs(rest);
            rs.trim();
            ffree((u64)rest);
            rest = rs.val();

            string next_s;
            byte* joined;
            byte* joined2;
            while (helpers::ends_with(rest, g"#\0"))
            {
                // drop trailing #
                rest[strlen(rest) - 1] = 0;
                this._emit_blank();
                i = i + 1;
                if ((u64)lines[i] == 0) { break; };
                this.current_local_lineno = i + 1;
                next_s.set(lines[i]);
                next_s.trim();
                joined = manip::concat(rest, g" \0");
                joined2 = manip::concat(joined, next_s.val());
                ffree((u64)joined);
                rest = joined2;
            };

            if (this._handle_psub(rest, i + 1) != 0) { return -1; };
            this._emit_blank();
            return i + 1;
        };

        // #def
        if (helpers::starts_with(t, g"#def\0"))
        {
            this._handle_def(t);
            this._emit_blank();
            return i + 1;
        };

        // #ifnpsub (before #ifpsub to avoid prefix clash)
        if (helpers::starts_with(t, g"#ifnpsub\0"))
        {
            byte* name = this._parse_cond_name(t + 8);
            int next = this._process_conditional(lines, i, name, true, true);
            ffree((u64)name);
            return next;
        };

        // #ifpsub
        if (helpers::starts_with(t, g"#ifpsub\0"))
        {
            byte* name = this._parse_cond_name(t + 7);
            int next = this._process_conditional(lines, i, name, false, true);
            ffree((u64)name);
            return next;
        };

        // #ifdef
        if (helpers::starts_with(t, g"#ifdef\0"))
        {
            byte* name = this._parse_cond_name(t + 6);
            int next = this._process_conditional(lines, i, name, false, false);
            ffree((u64)name);
            return next;
        };

        // #ifndef
        if (helpers::starts_with(t, g"#ifndef\0"))
        {
            byte* name = this._parse_cond_name(t + 7);
            int next = this._process_conditional(lines, i, name, true, false);
            ffree((u64)name);
            return next;
        };

        // #package
        if (helpers::starts_with(t, g"#package\0"))
        {
            byte* rest = manip::copy_string(t + 8);
            helpers::trim_end(rest);
            // strip trailing ;
            int rlen = strlen(rest);
            if (rlen > 0 & rest[rlen - 1] == ';') { rest[rlen - 1] = 0; };
            string rs(rest);
            rs.trim();
            // comma-separated package names
            byte** pkgs = rs.split(',');
            string pname;
            for (int k; (u64)pkgs[k] != 0; k = k + 1)
            {
                pname.set(pkgs[k]);
                pname.trim();
                if (pname.len() > 0)
                {
                    if (this._process_package(pname.val()) != 0)
                    {
                        ffree((u64)rest);
                        for (int m; (u64)pkgs[m] != 0; m = m + 1) { ffree((u64)pkgs[m]); };
                        ffree((u64)pkgs);
                        return -1;
                    };
                };
            };
            for (int k; (u64)pkgs[k] != 0; k = k + 1) { ffree((u64)pkgs[k]); };
            ffree((u64)pkgs);
            ffree((u64)rest);
            this._emit_blank();
            return i + 1;
        };

        // #import
        if (helpers::starts_with(t, g"#import\0"))
        {
            if (this._handle_import(line, i + 1) != 0) { return -1; };
            this._emit_blank();
            return i + 1;
        };

        // #warn
        if (helpers::starts_with(t, g"#warn\0"))
        {
            byte* msg = this._extract_quoted(line);
            if ((u64)msg != 0)
            {
                print(g"[PREPROCESSOR] ");
                println(msg);
                ffree((u64)msg);
            };
            this._emit_blank();
            return i + 1;
        };

        // #stop
        if (helpers::starts_with(t, g"#stop\0"))
        {
            byte* msg = this._extract_quoted(line);
            if ((u64)msg != 0)
            {
                print(g"[PREPROCESSOR] ");
                println(msg);
                ffree((u64)msg);
            };
            println(g"Compilation failed, preprocessor stopped by constant.");
            return -1;
        };

        // #endif
        if (helpers::starts_with(t, g"#endif;\0"))
        {
            this._emit_blank();
            return i + 1;
        };

        // stray #else (handled inside _process_conditional)
        if (strcmp(t, g"#else\0") == 0 | strcmp(t, g"#else;\0") == 0)
        {
            this._emit_blank();
            return i + 1;
        };

        // Regular line
        byte* sub = this._substitute_constants(line);
        this._emit_line(sub);
        ffree((u64)sub);
        return i + 1;
    };

    // -----------------------------------------------------------------------
    // _handle_dir
    // -----------------------------------------------------------------------
    def _handle_dir(byte* line) -> void
    {
        byte* path = this._extract_quoted(line);
        if ((u64)path == 0) { return; };

        // Normalize backslashes to forward slashes
        for (int k; path[k] != 0; k = k + 1)
        {
            if (path[k] == '\\') { path[k] = '/'; };
        };

        for (int k; k < this.lib_dir_count; k = k + 1)
        {
            if (strcmp(this.lib_dirs[k], path) == 0) { ffree((u64)path); return; };
        };

        if (this.lib_dir_count < MAX_LIB_DIRS)
        {
            this.lib_dirs[this.lib_dir_count] = path;
            this.lib_dir_count = this.lib_dir_count + 1;
            print(g"[PREPROCESSOR] Added library directory: ");
            println(path);
        };
    };

    // -----------------------------------------------------------------------
    // _handle_def
    // -----------------------------------------------------------------------
    def _handle_def(byte* t) -> void
    {
        // t starts with "#def", already trimmed
        byte* rest = t + 4;
        while (rest[0] == ' ' | rest[0] == '\t') { rest = rest + 1; };

        // name: first word
        int ni;
        while (rest[ni] != 0 & rest[ni] != ' ' & rest[ni] != '\t') { ni = ni + 1; };
        byte* name = manip::copy_n(rest, ni);
        rest = rest + ni;
        while (rest[0] == ' ' | rest[0] == '\t') { rest = rest + 1; };

        // value: remainder up to ;
        int vi;
        while (rest[vi] != 0 & rest[vi] != ';') { vi = vi + 1; };
        byte* value = manip::copy_n(rest, vi);
        string vs(value);
        vs.trim();
        ffree((u64)value);
        value = manip::copy_string(vs.val());

        if (name[0] == 0) { ffree((u64)name); ffree((u64)value); return; };

        if (this.constant_count < MAX_CONSTANTS)
        {
            this.constants[this.constant_count].key   = name;
            this.constants[this.constant_count].value = value;
            this.constant_count = this.constant_count + 1;
            print(g"[PREPROCESSOR] Defined constant: ");
            print(name);
            print(g" = ");
            println(value);
        };
    };

    // -----------------------------------------------------------------------
    // _handle_psub
    // -----------------------------------------------------------------------
    def _handle_psub(byte* rest, int lineno) -> int
    {
        while (rest[0] == ' ' | rest[0] == '\t') { rest = rest + 1; };

        int popen = helpers::find_char(rest, '(', 0);
        if (popen == -1)
        {
            println(g"[PREPROCESSOR] ERROR: #psub missing parameter list");
            return 1;
        };

        if (this.psub_count >= MAX_PSUBS) { return 0; };

        PSub* pe = @this.psubs[this.psub_count];

        byte* raw_name = manip::copy_n(rest, popen);
        string ns(raw_name);
        ns.trim();
        ffree((u64)raw_name);
        pe.name = manip::copy_string(ns.val());

        int pclose = helpers::find_char(rest + popen, ')', 0);
        if (pclose == -1)
        {
            println(g"[PREPROCESSOR] ERROR: #psub unclosed parameter list");
            return 1;
        };
        pclose = pclose + popen;

        byte* raw_params = manip::copy_n(rest + popen + 1, pclose - popen - 1);
        string ps_str(raw_params);
        ffree((u64)raw_params);
        byte** param_tokens = ps_str.split(',');

        pe.param_count = 0;
        string pt;
        for (int k; (u64)param_tokens[k] != 0; k = k + 1)
        {
            pt.set(param_tokens[k]);
            pt.trim();
            if (pt.len() > 0 & pe.param_count < MAX_PSUB_PARAMS)
            {
                pe.params[pe.param_count].name = manip::copy_string(pt.val());
                pe.param_count = pe.param_count + 1;
            };
            ffree((u64)param_tokens[k]);
        };
        ffree((u64)param_tokens);

        byte* body_ptr = rest + pclose + 1;
        while (body_ptr[0] == ' ' | body_ptr[0] == '\t') { body_ptr = body_ptr + 1; };
        string bs(body_ptr);
        bs.trim();
        pe.body = manip::copy_string(bs.val());

        this.psub_count = this.psub_count + 1;

        print(g"[PREPROCESSOR] Defined PSUB: ");
        print(pe.name);
        print(g"(");
        for (int k; k < pe.param_count; k = k + 1)
        {
            if (k > 0) { print(g", "); };
            print(pe.params[k].name);
        };
        print(g") = ");
        println(pe.body);

        return 0;
    };

    // -----------------------------------------------------------------------
    // _handle_import: dispatch #import <...> and #import "..."
    // -----------------------------------------------------------------------
    def _handle_import(byte* line, int lineno) -> int
    {
        // Find "#import" then scan rest of line for <> or "" tokens
        byte* p = strstr(line, g"#import\0");
        p = p + 7;

        // Strip trailing semicolon and whitespace
        byte* rest = manip::copy_string(p);
        int rlen = strlen(rest);
        if (rlen > 0 & rest[rlen - 1] == ';') { rest[rlen - 1] = 0; };
        string rs(rest);
        rs.trim();
        ffree((u64)rest);
        rest = rs.val();

        int j    = 0;
        int rlen2 = strlen(rest);
        byte c;
        int end;
        byte* std_path;
        string sp;
        byte* local_path;
        string lp;

        while (j < rlen2)
        {
            c = rest[j];

            if (c == '<')
            {
                j = j + 1;
                end = helpers::find_char(rest, '>', j);
                if (end == -1)
                {
                    println(g"[PREPROCESSOR] ERROR: Unterminated <> in #import");
                    return 1;
                };
                std_path = manip::copy_n(rest + j, end - j);
                sp.set(std_path);
                sp.trim();
                ffree((u64)std_path);
                print(g"[PREPROCESSOR] Stdlib import: ");
                println(sp.val());
                if (this._process_file(sp.val(), 2) != 0) { return 1; };
                j = end + 1;
            }
            elif (c == '"')
            {
                j = j + 1;
                end = helpers::find_char(rest, '"', j);
                if (end == -1)
                {
                    println(g"[PREPROCESSOR] ERROR: Unterminated \"\" in #import");
                    return 1;
                };
                local_path = manip::copy_n(rest + j, end - j);
                lp.set(local_path);
                lp.trim();
                ffree((u64)local_path);
                print(g"[PREPROCESSOR] Local import: ");
                println(lp.val());
                if (this._process_file(lp.val(), 1) != 0) { return 1; };
                j = end + 1;
            }
            else
            {
                j = j + 1;
            };
        };

        return 0;
    };

    // -----------------------------------------------------------------------
    // _process_conditional: handle #ifdef/#ifndef/#ifpsub/#ifnpsub blocks
    // Returns next line index past #endif, or -1 on error.
    // -----------------------------------------------------------------------
    def _process_conditional(byte** lines, int start_i,
                              byte* cond_name, bool is_ifndef, bool check_macros) -> int
    {
        int entry_lineno = this.current_local_lineno;
        this._emit_blank();

        // Parallel branch storage: each branch has a bool condition and a
        // range [start, start+len) into a flat collected array.
        bool[MAX_BRANCHES] branch_cond;
        int[MAX_BRANCHES]  branch_start;
        int[MAX_BRANCHES]  branch_len;
        int                branch_count;

        byte*[MAX_LINES] collected;
        int[MAX_LINES]   collected_origins;
        int              collected_count = 0;

        bool cur_cond        = this._eval_cond(cond_name, is_ifndef, check_macros);
        int  cur_start       = 0;
        int  depth           = 1;
        bool has_else        = false;

        int i = start_i + 1;
        byte* line;
        string s;
        byte* t;
        int orig_lineno;
        bool branch_taken;
        int bstart;
        int bend;
        int bj;
        byte*[2] sub;
        int next_inner;
        byte* elif_rest;
        int erlen;
        string ers;
        byte* elif_name;
        bool  elif_invert;
        while ((u64)lines[i] != 0)
        {
            line = lines[i];
            s.set(line);
            s.trim();
            t = s.val();
            orig_lineno = entry_lineno + (i - start_i);

            // Track nesting
            if (helpers::starts_with(t, g"#ifdef\0")   |
                helpers::starts_with(t, g"#ifndef\0")  |
                helpers::starts_with(t, g"#ifnpsub\0") |
                helpers::starts_with(t, g"#ifpsub\0"))
            {
                depth = depth + 1;
            };

            if (helpers::starts_with(t, g"#endif;\0"))
            {
                depth = depth - 1;
                if (depth == 0)
                {
                    // Flush last branch
                    if (branch_count < MAX_BRANCHES)
                    {
                        branch_cond[branch_count]  = cur_cond;
                        branch_start[branch_count] = cur_start;
                        branch_len[branch_count]   = collected_count - cur_start;
                        branch_count = branch_count + 1;
                    };

                    this._emit_blank();  // blank for #endif

                    // Find first true branch and process it
                    branch_taken = false;
                    for (int bi; bi < branch_count; bi = bi + 1)
                    {
                        bstart = branch_start[bi];
                        bend   = bstart + branch_len[bi];

                        if (!branch_taken & branch_cond[bi])
                        {
                            branch_taken = true;
                            bj = 0;
                            while (bj < branch_len[bi])
                            {
                                this.current_local_lineno = collected_origins[bstart + bj];
                                // Build a temporary null-terminated sub-array for _process_line
                                sub[0] = collected[bstart + bj];
                                sub[1] = (byte*)0;
                                next_inner = this._process_line(@sub[0], 0);
                                if (next_inner < 0) { return -1; };
                                bj = bj + 1;
                            };
                        }
                        else
                        {
                            // Excluded: emit blanks
                            for (int bk = bstart; bk < bend; bk = bk + 1)
                            {
                                this.current_local_lineno = collected_origins[bk];
                                this._emit_blank();
                            };
                        };
                    };

                    return i + 1;
                }
                else
                {
                    // Inner #endif -- collect as content
                    if (collected_count < MAX_LINES)
                    {
                        collected[collected_count]         = line;
                        collected_origins[collected_count] = orig_lineno;
                        collected_count = collected_count + 1;
                    };
                    i = i + 1;
                    continue;
                };
            };

            if (depth == 1)
            {
                if (helpers::starts_with(t, g"#elif\0"))
                {
                    if (has_else)
                    {
                        println(g"[PREPROCESSOR] ERROR: #elif after #else");
                        return -1;
                    };
                    // Flush current branch
                    if (branch_count < MAX_BRANCHES)
                    {
                        branch_cond[branch_count]  = cur_cond;
                        branch_start[branch_count] = cur_start;
                        branch_len[branch_count]   = collected_count - cur_start;
                        branch_count = branch_count + 1;
                    };
                    cur_start = collected_count;

                    elif_rest = manip::copy_string(t + 5);
                    helpers::trim_end(elif_rest);
                    erlen = strlen(elif_rest);
                    if (erlen > 0 & elif_rest[erlen - 1] == ';') { elif_rest[erlen - 1] = 0; };
                    ers.set(elif_rest);
                    ers.trim();
                    ffree((u64)elif_rest);

                    this._parse_ifdef_condition(ers.val(), @elif_name, @elif_invert);
                    cur_cond = this._eval_cond(elif_name, elif_invert, check_macros);
                    ffree((u64)elif_name);

                    this._emit_blank();
                    i = i + 1;
                    continue;
                };

                if (strcmp(t, g"#else\0") == 0 | strcmp(t, g"#else;\0") == 0)
                {
                    if (has_else)
                    {
                        println(g"[PREPROCESSOR] ERROR: Multiple #else in one block");
                        return -1;
                    };
                    has_else = true;
                    if (branch_count < MAX_BRANCHES)
                    {
                        branch_cond[branch_count]  = cur_cond;
                        branch_start[branch_count] = cur_start;
                        branch_len[branch_count]   = collected_count - cur_start;
                        branch_count = branch_count + 1;
                    };
                    cur_start = collected_count;
                    cur_cond  = true;
                    this._emit_blank();
                    i = i + 1;
                    continue;
                };
            };

            // Ordinary content line
            if (collected_count < MAX_LINES)
            {
                collected[collected_count]         = line;
                collected_origins[collected_count] = orig_lineno;
                collected_count = collected_count + 1;
            };
            i = i + 1;
        };

        println(g"[PREPROCESSOR] ERROR: Unclosed conditional block");
        return -1;
    };

    // -----------------------------------------------------------------------
    // _eval_cond: test cond_name defined/undefined
    // -----------------------------------------------------------------------
    def _eval_cond(byte* cond_name, bool is_ifndef, bool check_macros) -> bool
    {
        bool defined = false;
        if (check_macros)
        {
            for (int k; k < this.psub_count; k = k + 1)
            {
                if (strcmp(this.psubs[k].name, cond_name) == 0)
                {
                    defined = true;
                    break;
                };
            };
        }
        else
        {
            for (int k; k < this.constant_count; k = k + 1)
            {
                if (strcmp(this.constants[k].key, cond_name) == 0)
                {
                    defined = strcmp(this.constants[k].value, g"0\0") != 0;
                    break;
                };
            };
        };
        return is_ifndef ? !defined : defined;
    };

    // -----------------------------------------------------------------------
    // _parse_ifdef_condition: parse SYMBOL / defined(SYMBOL) / !defined(SYMBOL)
    // Writes allocated name into *out_name, sets *out_invert.
    // -----------------------------------------------------------------------
    def _parse_ifdef_condition(byte* expr, byte** out_name, bool* out_invert) -> void
    {
        string es(expr);
        es.trim();
        byte* e = es.val();
        *out_invert = false;

        if (e[0] == '!')
        {
            *out_invert = true;
            e = e + 1;
            while (e[0] == ' ' | e[0] == '\t') { e = e + 1; };
        };

        if (helpers::starts_with(e, g"defined\0"))
        {
            e = e + 7;
            while (e[0] == ' ' | e[0] == '\t') { e = e + 1; };
            if (e[0] == '(') { e = e + 1; };
            int ci;
            while (e[ci] != 0 & e[ci] != ')') { ci = ci + 1; };
            byte* n = manip::copy_n(e, ci);
            string ns(n);
            ns.trim();
            ffree((u64)n);
            *out_name = manip::copy_string(ns.val());
            return;
        };

        // Plain identifier
        *out_name = manip::copy_string(e);
    };

    // -----------------------------------------------------------------------
    // _parse_cond_name: extract bare name from "#ifdef FOO" or "#ifpsub FOO(...)"
    // -----------------------------------------------------------------------
    def _parse_cond_name(byte* rest) -> byte*
    {
        string s(rest);
        s.trim();
        byte* t = s.val();
        int ci;
        while (t[ci] != 0 & t[ci] != '(' & t[ci] != ' ' & t[ci] != '\t')
        {
            ci = ci + 1;
        };
        byte* n = manip::copy_n(t, ci);
        string ns(n);
        ns.trim();
        ffree((u64)n);
        return manip::copy_string(ns.val());
    };

    // -----------------------------------------------------------------------
    // _strip_comments: strip // line comments and /// block comments.
    // Preserves newlines inside block comments for accurate line numbers.
    // Returns allocated string.
    // -----------------------------------------------------------------------
    def _strip_comments(byte* src) -> byte*
    {
        int n   = strlen(src);
        byte* dst = (byte*)fmalloc((u64)n + 1);
        int i = 0, di = 0;
        bool in_string = false;
        byte string_char = 0;

        byte c;
        while (i < n)
        {
            c = src[i];

            if (in_string)
            {
                dst[di] = c; di = di + 1;
                if (c == '\\' & i + 1 < n)
                {
                    i = i + 1;
                    dst[di] = src[i]; di = di + 1;
                }
                elif (c == string_char)
                {
                    in_string = false;
                };
                i = i + 1;
                continue;
            };

            if (c == '"' | c == '\'')
            {
                in_string   = true;
                string_char = c;
                dst[di] = c; di = di + 1;
                i = i + 1;
                continue;
            };

            // Block comment: ///
            if (i + 2 < n & c == '/' & src[i+1] == '/' & src[i+2] == '/')
            {
                i = i + 3;
                while (i < n)
                {
                    if (i + 2 < n & src[i] == '/' & src[i+1] == '/' & src[i+2] == '/')
                    {
                        i = i + 3;
                        break;
                    };
                    if (src[i] == '\n') { dst[di] = '\n'; di = di + 1; };
                    i = i + 1;
                };
                continue;
            };

            // Line comment: //
            if (i + 1 < n & c == '/' & src[i+1] == '/')
            {
                while (i < n & src[i] != '\n') { i = i + 1; };
                continue;
            };

            dst[di] = c; di = di + 1;
            i = i + 1;
        };

        dst[di] = 0;
        return dst;
    };

    // -----------------------------------------------------------------------
    // _expand_macros: expand #psub parameterized macros in a line.
    // Returns allocated result string.
    // -----------------------------------------------------------------------
    def _expand_macros(byte* line, int depth) -> byte*
    {
        if (depth > 64 | this.psub_count == 0)
        {
            return manip::copy_string(line);
        };

        int n       = strlen(line),
            di, i,
            j_em,
            psub_idx,
            k_em,
            pdepth,
            arg_count,
            elen;

        byte* dst    = (byte*)fmalloc((u64)(n * 4 + 256)),
              name_em,
              raw_args,
              replaced_em,
              expanded_em;

        bool changed, in_str_em;
        byte c_em,
             str_ch_em,
             ck_em;
        PSub* pe_em;
        byte** args_em;
        string expanded_s,
               arg_s;
        while (i < n)
        {
            c_em = line[i];

            if (c_em == '_' | helpers::is_alpha(c_em))
            {
                j_em = i;
                while (j_em < n & (line[j_em] == '_' | helpers::is_alnum(line[j_em])))
                {
                    j_em = j_em + 1;
                };

                name_em = manip::copy_n(line + i, j_em - i);

                psub_idx = -1;
                for (int pk; pk < this.psub_count; pk = pk + 1)
                {
                    if (strcmp(this.psubs[pk].name, name_em) == 0)
                    {
                        psub_idx = pk;
                        break;
                    };
                };

                if (psub_idx >= 0 & j_em < n & line[j_em] == '(')
                {
                    pe_em = @this.psubs[psub_idx];

                    // Find matching closing paren
                    k_em      = j_em + 1;
                    pdepth = 1;
                    in_str_em = false;
                    str_ch_em = 0;
                    while (k_em < n & pdepth > 0)
                    {
                        ck_em = line[k_em];
                        if (in_str_em)
                        {
                            if (ck_em == '\\') { k_em = k_em + 1; }
                            elif (ck_em == str_ch_em) { in_str_em = false; };
                        }
                        else
                        {
                            if (ck_em == '"' | ck_em == '\'') { in_str_em = true; str_ch_em = ck_em; }
                            elif (ck_em == '(') { pdepth = pdepth + 1; }
                            elif (ck_em == ')') { pdepth = pdepth - 1; };
                        };
                        k_em = k_em + 1;
                    };

                    // Split args on top-level commas
                    raw_args = manip::copy_n(line + j_em + 1, k_em - 1 - (j_em + 1));
                    args_em = this._split_macro_args(raw_args);
                    ffree((u64)raw_args);

                    arg_count = 0;
                    while ((u64)args_em[arg_count] != 0) { arg_count = arg_count + 1; };

                    if (arg_count != pe_em.param_count)
                    {
                        println(g"[PREPROCESSOR] ERROR: Macro argument count mismatch");
                        for (int m; (u64)args_em[m] != 0; m = m + 1) { ffree((u64)args_em[m]); };
                        ffree((u64)args_em);
                        ffree((u64)name_em);
                        // emit as-is
                        for (int m = i; m < k_em; m = m + 1) { dst[di] = line[m]; di = di + 1; };
                        i = k_em;
                        continue;
                    };

                    // Substitute params into body (whole-word replacement)
                    expanded_s.set(pe_em.body);
                    for (int ai; ai < arg_count; ai = ai + 1)
                    {
                        arg_s.set(args_em[ai]);
                        arg_s.trim();
                        replaced_em = expanded_s.replace_all(pe_em.params[ai].name, arg_s.val());
                        expanded_s.set(replaced_em);
                        ffree((u64)replaced_em);
                    };

                    expanded_em = expanded_s.val();
                    elen = strlen(expanded_em);
                    for (int m; m < elen; m = m + 1) { dst[di] = expanded_em[m]; di = di + 1; };
                    changed = true;

                    for (int m; (u64)args_em[m] != 0; m = m + 1) { ffree((u64)args_em[m]); };
                    ffree((u64)args_em);
                    ffree((u64)name_em);
                    i = k_em;
                }
                else
                {
                    for (int m = i; m < j_em; m = m + 1) { dst[di] = line[m]; di = di + 1; };
                    ffree((u64)name_em);
                    i = j_em;
                };
            }
            else
            {
                dst[di] = c_em; di = di + 1;
                i = i + 1;
            };
        };

        dst[di] = 0;

        if (changed)
        {
            byte* result = this._expand_macros(dst, depth + 1);
            ffree((u64)dst);
            return result;
        };

        return dst;
    };

    // -----------------------------------------------------------------------
    // _split_macro_args: split raw arg string on top-level commas.
    // Returns null-terminated byte** (caller frees each element and the array).
    // -----------------------------------------------------------------------
    def _split_macro_args(byte* raw) -> byte**
    {
        // Count top-level commas to size the result
        int n     = strlen(raw);
        int depth = 0;
        bool in_str = false;
        byte str_ch = 0;
        int comma_count = 0;

        byte c_sa;
        for (int k; k < n; k = k + 1)
        {
            c_sa = raw[k];
            if (in_str)
            {
                if (c_sa == str_ch) { in_str = false; };
            }
            elif (c_sa == '"' | c_sa == '\'') { in_str = true; str_ch = c_sa; }
            elif (c_sa == '(') { depth = depth + 1; }
            elif (c_sa == ')') { depth = depth - 1; }
            elif (c_sa == ',' & depth == 0) { comma_count = comma_count + 1; };
        };

        int capacity = comma_count + 2;
        byte** result = (byte**)fmalloc((u64)capacity * 8);

        int   part_idx = 0;
        int   start    = 0;
        depth = 0; in_str = false; str_ch = 0;

        byte c_sa2;
        for (int k; k <= n; k = k + 1)
        {
            c_sa2 = raw[k];
            if (in_str)
            {
                if (c_sa2 == str_ch) { in_str = false; };
            }
            elif (c_sa2 == '"' | c_sa2 == '\'') { in_str = true; str_ch = c_sa2; }
            elif (c_sa2 == '(') { depth = depth + 1; }
            elif (c_sa2 == ')') { depth = depth - 1; }
            elif ((c_sa2 == ',' & depth == 0) | c_sa2 == 0)
            {
                result[part_idx] = manip::copy_n(raw + start, k - start);
                part_idx = part_idx + 1;
                start    = k + 1;
            };
        };

        result[part_idx] = (byte*)0;
        return result;
    };

    // -----------------------------------------------------------------------
    // _substitute_constants: expand macros then substitute scalar constants.
    // Returns allocated result string.
    // -----------------------------------------------------------------------
    def _substitute_constants(byte* line) -> byte*
    {
        // Expand parameterized macros first
        byte* expanded = this._expand_macros(line, 0);

        int n = strlen(expanded);
        if (n == 0 | (n == 1 & expanded[0] == ';'))
        {
            return expanded;
        };

        byte* dst = (byte*)fmalloc((u64)n * 4 + 256),
              tok_sc,
              cv_sc,
              clean_sc,
              token_start = (byte*)0;
        int di, token_pos,
            clen_sc,
            cvl_sc;
        bool in_quotes,
             is_delim_sc,
             subbed_sc;

        byte c_sc;

        string cvs_sc;
        // Walk char by char; flush identifier tokens at delimiters
        for (int k; k <= n; k = k + 1)
        {
            c_sc = expanded[k];  // 0 at k==n

            if (c_sc == '"') { in_quotes = !in_quotes; };

            is_delim_sc = !in_quotes & (c_sc == 0 | c_sc == ' ' | c_sc == '\t' |
                c_sc == '.' | c_sc == ',' | c_sc == ';' | c_sc == ':' |
                c_sc == '(' | c_sc == ')' | c_sc == '[' | c_sc == ']' |
                c_sc == '{' | c_sc == '}' | c_sc == '+' | c_sc == '-' |
                c_sc == '*' | c_sc == '/' | c_sc == '%' | c_sc == '=' |
                c_sc == '!' | c_sc == '<' | c_sc == '>' | c_sc == '|' |
                c_sc == '&' | c_sc == '^' | c_sc == '~');

            if (is_delim_sc)
            {
                if (token_pos > 0)
                {
                    // We have a token: token is expanded[k-token_pos .. k-1]
                    tok_sc = manip::copy_n(expanded + k - token_pos, token_pos);
                    subbed_sc = false;
                    for (int ck; ck < this.constant_count; ck = ck + 1)
                    {
                        if (strcmp(this.constants[ck].key, tok_sc) == 0)
                        {
                            // Copy value, strip trailing ;
                            cv_sc = manip::copy_string(this.constants[ck].value);
                            cvl_sc = strlen(cv_sc);
                            while (cvl_sc > 0 & cv_sc[cvl_sc - 1] == ';')
                            {
                                cv_sc[cvl_sc - 1] = 0;
                                cvl_sc = cvl_sc - 1;
                            };
                            cvs_sc.set(cv_sc);
                            cvs_sc.trim();
                            clean_sc = cvs_sc.val();
                            clen_sc = strlen(clean_sc);
                            for (int m; m < clen_sc; m = m + 1) { dst[di] = clean_sc[m]; di = di + 1; };
                            ffree((u64)cv_sc);
                            subbed_sc = true;
                            break;
                        };
                    };
                    if (!subbed_sc)
                    {
                        for (int m; m < token_pos; m = m + 1)
                        {
                            dst[di] = expanded[k - token_pos + m]; di = di + 1;
                        };
                    };
                    ffree((u64)tok_sc);
                    token_pos = 0;
                };
                if (c_sc != 0) { dst[di] = c_sc; di = di + 1; };
            }
            else
            {
                token_pos = token_pos + 1;
            };
        };

        dst[di] = 0;
        ffree((u64)expanded);
        return dst;
    };

    // -----------------------------------------------------------------------
    // _extract_quoted: return the content of the first "..." in a line.
    // Returns allocated string or null.
    // -----------------------------------------------------------------------
    def _extract_quoted(byte* line) -> byte*
    {
        int start = helpers::find_char(line, '"', 0);
        if (start == -1) { return (byte*)0; };
        start = start + 1;
        int end = helpers::find_char(line, '"', start);
        if (end == -1) { return (byte*)0; };
        return manip::copy_n(line + start, end - start);
    };
};

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
def main(int argc, byte** argv) -> int
{
    argparse::Parser parser();

    parser.add_value("--src\0",    "-s\0",    "Source .fx file to preprocess\0", true);
    parser.add_value("--srcdir\0", "\0",       "Override FLUXC_SRCDIR\0",         false);

    if (!parser.parse(argc, argv))
    {
        parser.print_help();
        return 1;
    };

    byte* src_file = parser.get_value("--src\0");
    //FXPreprocessor pp(src_file);

///
    if (parser.is_present("--srcdir\0"))
    {
        pp.lib_dirs[pp.lib_dir_count] = parser.get_value("--srcdir\0");
        pp.lib_dir_count = pp.lib_dir_count + 1;
    };
///
    return 0;
};
