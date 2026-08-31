// standard::strings::format
// Format a value according to a Python-style format specifier using -> separator.
//
// Specifier grammar (same as Python's format_spec mini-language):
//   [[fill]align][sign][0][width][.precision][type]
//
//   fill   : any character
//   align  : < (left)  > (right)  ^ (center)
//   sign   : + (always)  - (negative only, default)  ' ' (space for positive)
//   0      : zero-pad (fill='0', align='>')
//   width  : integer minimum field width
//   .prec  : decimal digits after point (float), or max string width
//   type   : d  decimal integer
//            x  lowercase hex
//            X  uppercase hex
//            o  octal
//            b  binary
//            f  fixed-point float
//            e  scientific notation (lowercase)
//            E  scientific notation (uppercase)
//            s  string
//            (omitted) -- sensible default for the type
//
// Usage:
//   byte[64] buf;
//   int len = format(value, @buf[0], g"->.2f");
//
// In f-string context the compiler desugars f"{val->.2f}" into a format call.

#ifndef FLUX_STANDARD_FORMAT
#def FLUX_STANDARD_FORMAT 1;

namespace standard
{
    namespace strings
    {
        namespace _fmt_impl
        {
            // Parse a decimal integer from spec starting at *pos.
            // Advances *pos past consumed digits. Returns 0 if no digits present.
            def _parse_int(byte* spec, int* pos) -> int
            {
                int result;
                while (spec[*pos] >= 48 & spec[*pos] <= 57)
                {
                    result = result * 10 + (int)(spec[*pos] - 48);
                    *pos = *pos + 1;
                };
                return result;
            };

            // Write 'count' copies of fill character into buf at write_pos.
            // Returns updated write_pos.
            def _pad(byte* buf, int write_pos, byte fill, int count) -> int
            {
                for (int i = 0; i < count; i++)
                {
                    buf[write_pos] = fill;
                    write_pos++;
                };
                return write_pos;
            };

            // Apply fill/align/width around tmp[0..len) into buf.
            // Returns total bytes written (excluding null terminator written at end).
            def _align_into(byte* buf, byte* tmp, int len, byte fill, byte align, int width) -> int
            {
                int pad = width - len;
                if (pad < 0) { pad = 0; };
                int wp;

                if (align == 62)        // '>'  right
                {
                    wp = _pad(buf, wp, fill, pad);
                    for (int i = 0; i < len; i++) { buf[wp] = tmp[i]; wp++; };
                }
                elif (align == 94)      // '^'  center
                {
                    int lp = pad / 2;
                    wp = _pad(buf, wp, fill, lp);
                    for (int i = 0; i < len; i++) { buf[wp] = tmp[i]; wp++; };
                    wp = _pad(buf, wp, fill, pad - lp);
                }
                else                    // '<'  left (default)
                {
                    for (int i = 0; i < len; i++) { buf[wp] = tmp[i]; wp++; };
                    wp = _pad(buf, wp, fill, pad);
                };

                buf[wp] = 0;
                return wp;
            };

            // Write unsigned u64 value in given base into tmp (no null term).
            // uppercase: nonzero for A-F, zero for a-f.
            // Returns number of bytes written.
            def _uint_base(byte* tmp, u64 value, int base, int uppercase) -> int
            {
                if (value == (u64)0) { tmp[0] = 48; return 1; };

                byte[66] rev;
                int pos;
                u64 v = value;
                while (v != (u64)0)
                {
                    u64 d = v % (u64)base;
                    if (d < (u64)10)
                    {
                        rev[pos] = (byte)(d + (u64)48);
                    }
                    else
                    {
                        rev[pos] = (byte)(d - (u64)10 + (u64)(uppercase ? 65 : 97));
                    };
                    v = v / (u64)base;
                    pos++;
                };
                int out;
                for (int i = pos - 1; i >= 0; i--) { tmp[out] = rev[i]; out++; };
                return out;
            };

            // Write a fixed-point representation of a non-negative double into tmp.
            // Returns bytes written (no null term).
            def _dbl_fixed(byte* tmp, double value, int precision) -> int
            {
                int wp;
                i64 int_part = (i64)value;
                double frac = value - double(int_part);

                // Integer part
                if (int_part == (i64)0)
                {
                    tmp[wp] = 48; wp++;
                }
                else
                {
                    byte[32] irev;
                    int ipos;
                    i64 iv = int_part;
                    while (iv > (i64)0)
                    {
                        irev[ipos] = (byte)((iv % (i64)10) + (i64)48);
                        iv = iv / (i64)10;
                        ipos++;
                    };
                    for (int k = ipos - 1; k >= 0; k--) { tmp[wp] = irev[k]; wp++; };
                };

                if (precision > 0)
                {
                    tmp[wp] = 46; wp++;  // '.'

                    i64 mul = (i64)1;
                    for (int j = 0; j < precision; j++) { mul = mul * (i64)10; };
                    i64 frac_part = (i64)(frac * double(mul) + (double)0.5);

                    if (frac_part >= mul) { int_part++; frac_part = (i64)0; };

                    byte[32] frev;
                    int fd;
                    i64 tf = frac_part;
                    while (tf > (i64)0) { frev[fd] = (byte)((tf % (i64)10) + (i64)48); tf = tf / (i64)10; fd++; };

                    for (int n = 0; n < precision - fd; n++) { tmp[wp] = 48; wp++; };
                    for (int p = fd - 1; p >= 0; p--) { tmp[wp] = frev[p]; wp++; };
                };

                return wp;
            };

            // Parse format spec into component fields.
            def _parse_spec(
                byte* spec,
                byte* out_fill,   byte* out_align,
                byte* out_sign,   int*  out_zero,
                int*  out_width,  int*  out_prec_given,
                int*  out_prec,   byte* out_type
            ) -> void
            {
                *out_fill  = 32;   // ' '
                *out_align = 0;
                *out_sign  = 45;   // '-'
                *out_zero  = 0;
                *out_width = 0;
                *out_prec_given = 0;
                *out_prec  = 6;
                *out_type  = 0;

                int pos;

                // [[fill]align]: if spec[1] is an align char, spec[0] is fill
                if (spec[0] != 0 & spec[1] != 0)
                {
                    byte s1 = spec[1];
                    if (s1 == 60 | s1 == 62 | s1 == 94)
                    {
                        *out_fill  = spec[0];
                        *out_align = s1;
                        pos = 2;
                    };
                };

                // align without explicit fill
                if (*out_align == 0 & spec[pos] != 0)
                {
                    byte s0 = spec[pos];
                    if (s0 == 60 | s0 == 62 | s0 == 94) { *out_align = s0; pos++; };
                };

                // sign
                if (spec[pos] == 43 | spec[pos] == 45 | spec[pos] == 32)
                {
                    *out_sign = spec[pos]; pos++;
                };

                // zero-pad flag
                if (spec[pos] == 48)
                {
                    *out_zero  = 1;
                    *out_fill  = 48;
                    if (*out_align == 0) { *out_align = 62; };
                    pos++;
                };

                *out_width = _parse_int(spec, @pos);

                if (spec[pos] == 46) { pos++; *out_prec_given = 1; *out_prec = _parse_int(spec, @pos); };

                if (spec[pos] != 0) { *out_type = spec[pos]; };
            };
        };

        // Single generic format function -- dispatches on typeof(value) at compile time.
        def format<T>(T value, byte* buf, byte* spec) -> int
        {
            byte fill, align, sign_ch, fmt_type;
            int zero, width, prec_given, prec;

            standard::strings::_fmt_impl::_parse_spec(spec, @fill, @align, @sign_ch, @zero, @width, @prec_given, @prec, @fmt_type);

            byte[72] tmp;
            int tpos;

            if (typeof(value) is typeof(bool))
            {
                byte* word = g"true" if (value) else g"false";
                int i;
                while (word[i] != 0) { tmp[tpos] = word[i]; tpos++; i++; };
                if (align == 0) { align = 60; };
            }
            elif (typeof(value) is typeof(byte*) | typeof(value) is typeof(char*))
            {
                // String: apply precision as max length
                byte* s = (byte*)value;
                int len;
                while (s[len] != 0) { len++; };
                if (prec_given & prec < len) { len = prec; };
                for (int i = 0; i < len; i++) { tmp[tpos] = s[i]; tpos++; };
                if (align == 0) { align = 60; };
            }
            elif (typeof(value) is typeof(double) | typeof(value) is typeof(float))
            {
                double v = (double)value;
                if (!prec_given) { prec = 6; };
                if (align == 0) { align = 62; };

                bool is_neg = v < (double)0.0;
                if (is_neg) { tmp[0] = 45; tpos = 1; v = -v; }
                elif (sign_ch == 43) { tmp[0] = 43; tpos = 1; }
                elif (sign_ch == 32) { tmp[0] = 32; tpos = 1; };

                bool sci = (fmt_type == 101 | fmt_type == 69); // 'e' 'E'
                if (sci)
                {
                    int exp;
                    double sv = v;
                    if (sv != (double)0.0)
                    {
                        while (sv >= (double)10.0) { sv = sv / (double)10.0; exp++; };
                        while (sv < (double)1.0)   { sv = sv * (double)10.0; exp--; };
                    };
                    byte[40] sig;
                    int slen = standard::strings::_fmt_impl::_dbl_fixed(@sig[0], sv, prec);
                    for (int i = 0; i < slen; i++) { tmp[tpos] = sig[i]; tpos++; };
                    tmp[tpos] = fmt_type; tpos++;
                    if (exp < 0) { tmp[tpos] = 45; tpos++; exp = -exp; }
                    else         { tmp[tpos] = 43; tpos++; };
                    byte[8] erev;
                    int epos;
                    if (exp == 0) { erev[0] = 48; erev[1] = 48; epos = 2; }
                    else
                    {
                        int ev = exp;
                        while (ev > 0) { erev[epos] = (byte)((ev % 10) + 48); ev = ev / 10; epos++; };
                        if (epos < 2) { erev[epos] = 48; epos++; };
                    };
                    for (int i = epos - 1; i >= 0; i--) { tmp[tpos] = erev[i]; tpos++; };
                }
                else
                {
                    byte[40] fixed;
                    int flen = standard::strings::_fmt_impl::_dbl_fixed(@fixed[0], v, prec);
                    for (int i = 0; i < flen; i++) { tmp[tpos] = fixed[i]; tpos++; };
                };
            }
            else
            {
                // Integer family -- signed or unsigned, any width
                if (align == 0) { align = 62; };

                // Float format specifiers on an integer: cast and recurse
                if (fmt_type == 102 | fmt_type == 101 | fmt_type == 69)
                {
                    return format((double)value, buf, spec);
                };

                int base = 10, uppercase;
                if      (fmt_type == 120) { base = 16; }
                elif    (fmt_type == 88)  { base = 16; uppercase = 1; }
                elif    (fmt_type == 111) { base = 8; }
                elif    (fmt_type == 98)  { base = 2; };

                bool is_signed = (typeof(value) is typeof(int)  | typeof(value) is typeof(long)  |
                                  typeof(value) is typeof(i32)  | typeof(value) is typeof(i16)   |
                                  typeof(value) is typeof(i8)   | typeof(value) is typeof(i64)   |
                                  typeof(value) is typeof(char));

                u64 uval;
                bool is_neg;
                if (is_signed)
                {
                    i64 sv = (i64)value;
                    is_neg = sv < (i64)0;
                    uval = (u64)sv if (!is_neg) else (u64)(-sv);
                }
                else
                {
                    uval = (u64)value;
                };

                if (is_neg)             { tmp[0] = 45; tpos = 1; }
                elif (sign_ch == 43)    { tmp[0] = 43; tpos = 1; }
                elif (sign_ch == 32)    { tmp[0] = 32; tpos = 1; };

                byte[66] digits;
                int dlen = standard::strings::_fmt_impl::_uint_base(@digits[0], uval, base, uppercase);
                for (int i = 0; i < dlen; i++) { tmp[tpos] = digits[i]; tpos++; };
            };

            return standard::strings::_fmt_impl::_align_into(buf, @tmp[0], tpos, fill, align, width);
        };
    };
};

#endif; // FLUX_STANDARD_FORMAT
