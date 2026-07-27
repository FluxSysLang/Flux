// Author: Karac V. Thweatt
// Updated: 2026-07-24

// math.fx - Comprehensive mathematical functions with overloads
#ifndef FLUX_STANDARD
#def FLUX_STANDARD 1;
#endif;

#ifndef FLUX_STANDARD_TYPES
#import <types.fx>;
#endif;

#ifndef FLUX_STANDARD_MATH
#def FLUX_STANDARD_MATH 1;

// Euler-Mascheroni constant used in Bessel Y and gamma functions
#def _EULER_MASCHERONI 0.5772156649015328606;

// Lanczos g=5, n=7 coefficients (Lanczos 1964 / Godfrey)
#def _LANCZOS_G   5.0;
#def _LANCZOS_C0  1.000000000190015;
#def _LANCZOS_C1  76.18009172947146;
#def _LANCZOS_C2 -86.50532032941677;
#def _LANCZOS_C3  24.01409824083091;
#def _LANCZOS_C4 -1.231739572450155;
#def _LANCZOS_C5  0.001208650973866179;
#def _LANCZOS_C6 -0.000005395239384953;

namespace standard
{
    namespace math
    {
        // ==================== Constants ====================
        const i8  PI8  = 3;
        const i16 PI16 = 3;
        const i32 PI32 = 3;
        const i64 PI64 = 3;

        const float  PIF        = 3.14159265358979f;
        const float  PI_2_F     = 1.5707963267948966f;
        const float  PI_4_F     = 0.7853981633974483f;
        const float  TAU_F      = 6.283185307179586f;
        const float  SQRT2_F    = 1.4142135623730951f;
        const float  SQRT1_2_F  = 0.7071067811865475f;
        const float  LN2_F      = 0.6931471805599453f;
        const float  LN10_F     = 2.302585092994046f;
        const float  LOG2E_F    = 1.4426950408889634f;
        const float  LOG10E_F   = 0.4342944819032518f;
        const float  INFINITY_F = (float)0x7F800000u;
        const float  NAN_F      = (float)0x7FC00000u;

        const double PID        = 3.14159265358979323846;
        const double PI_2_D     = 1.5707963267948966;
        const double PI_4_D     = 0.7853981633974483;
        const double TAU_D      = 6.283185307179586;
        const double SQRT2_D    = 1.4142135623730951;
        const double SQRT1_2_D  = 0.7071067811865475;
        const double LN2_D      = 0.6931471805599453;
        const double LN10_D     = 2.302585092994046;
        const double LOG2E_D    = 1.4426950408889634;
        const double LOG10E_D   = 0.4342944819032518;
        const double INFINITY_D = (double)0x7FF0000000000000u;
        const double NAN_D      = (double)0x7FF8000000000000u;

        struct Face    { int a, b, c; };
        struct Edge    { int a, b; };
        struct POINT   { int x, y; };
        struct Complex { double re, im; };

        // ==================== Absolute value ====================
        inline def abs<T: i8 | i16 | i32 | i64>(T x) -> T
        {
            if (x < 0) { return -x; };
            return x;
        };
        inline def abs(float x) -> float
        {
            if (x < 0.0f) { return -x; };
            return x;
        };
        inline def abs(double x) -> double
        {
            if (x < 0.0) { return -x; };
            return x;
        };

        // ==================== Min/Max ====================
        inline def min<T: i8 | i16 | i32 | i64 | float | double>(T a, T b) -> T
        {
            if (a < b) { return a; };
            return b;
        };
        inline def max<T: i8 | i16 | i32 | i64 | float | double>(T a, T b) -> T
        {
            if (a > b) { return a; };
            return b;
        };

        // ==================== Clamp ====================
        inline def clamp<T: i8 | i16 | i32 | i64 | float | double>(T v, T l, T h) -> T
        {
            if (v < l) { return l; };
            if (v > h) { return h; };
            return v;
        };

        // ==================== Square root ====================
        // Integer sqrt via Newton-Raphson with a bit-length-based initial guess.
        // prev_y is initialized to x+1 so the loop always executes at least once.
        inline def sqrt(i8 x) -> i8
        {
            if (x <= 0) { return 0; };
            i8 y = (i8)(1 << ((bit_length(x) + 1) / 2)),
               prev_y = x + 1;
            while (y != prev_y & y < prev_y)
            {
                prev_y = y;
                y = (y + x / y) / 2;
            };
            return y;
        };
        inline def sqrt(i16 x) -> i16
        {
            if (x <= 0) { return 0; };
            i16 y = (i16)(1 << ((bit_length(x) + 1) / 2)),
                prev_y = x + 1;
            while (y != prev_y & y < prev_y)
            {
                prev_y = y;
                y = (y + x / y) / 2;
            };
            return y;
        };
        inline def sqrt(i32 x) -> i32
        {
            if (x <= 0) { return 0; };
            i32 y = 1 << ((bit_length(x) + 1) / 2),
                prev_y = x + 1;
            while (y != prev_y & y < prev_y)
            {
                prev_y = y;
                y = (y + x / y) / 2;
            };
            return y;
        };
        inline def sqrt(i64 x) -> i64
        {
            if (x <= 0) { return 0; };
            i64 y = (i64)1 << ((bit_length(x) + 1) / 2),
                prev_y = x + 1;
            while (y != prev_y & y < prev_y)
            {
                prev_y = y;
                y = (y + x / y) / 2;
            };
            return y;
        };
        inline def sqrt(byte x) -> byte
        {
            if (x == 0) { return 0; };
            byte y = (byte)(1 << ((bit_length((i8)x) + 1) / 2)),
                 prev_y = x + 1;
            while (y != prev_y)
            {
                prev_y = y;
                y = (y + x / y) / 2;
            };
            return y;
        };
        inline def sqrt(u16 x) -> u16
        {
            if (x == 0) { return 0; };
            u16 y = (u16)(1 << ((bit_length((i16)x) + 1) / 2)),
                prev_y = x + 1;
            while (y != prev_y)
            {
                prev_y = y;
                y = (y + x / y) / 2;
            };
            return y;
        };
        inline def sqrt(u32 x) -> u32
        {
            if (x == 0) { return 0; };
            u32 y = (u32)(1 << ((bit_length((i32)x) + 1) / 2)),
                prev_y = x + 1;
            while (y != prev_y)
            {
                prev_y = y;
                y = (y + x / y) / 2;
            };
            return y;
        };
        inline def sqrt(u64 x) -> u64
        {
            if (x == 0) { return 0; };
            u64 y = (u64)1 << ((bit_length((i64)x) + 1) / 2),
                prev_y = x + 1;
            while (y != prev_y)
            {
                prev_y = y;
                y = (y + x / y) / 2;
            };
            return y;
        };
        vectorcall sqrt(float x) -> float
        {
            float result;
            volatile asm
            {
                sqrtss $1, $0
            } : "=x"(result) : "x"(x) : ;
            return result;
        };
        vectorcall sqrt(double x) -> double
        {
            double result;
            volatile asm
            {
                sqrtsd $1, $0
            } : "=x"(result) : "x"(x) : ;
            return result;
        };

        def fisr(float x) -> float
        {
            float  x2, y;
            u32    i;
            x2 = x * 0.5f;
            y  = x;
            i  = *((u32*)@y);                // evil floating point bit hack
            i  = (u32)0x5F3759DF - (i >> 1); // what the fuck?
            y  = *((float*)@i);
            y  = y * (1.5f - (x2 * y * y));
            //y  = y * (1.5f - (x2 * y * y));   // second iteration for better precision
            return y;
        };

        // ==================== Factorial (overflow check) ====================
        def factorial(i8 n) -> i8
        {
            if (n <= 1) { return 1; };
            i8 result = 1;
            for (i8 i = 2; i <= n; i++)
            {
                if (result > 127 / i) { return 0; };
                result *= i;
            };
            return result;
        };
        def factorial(i16 n) -> i16
        {
            if (n <= 1) { return 1; };
            i16 result = 1;
            for (i16 i = 2; i <= n; i++)
            {
                if (result > 32767 / i) { return 0; };
                result *= i;
            };
            return result;
        };
        def factorial(i32 n) -> i32
        {
            if (n <= 1) { return 1; };
            i32 result = 1;
            for (i32 i = 2; i <= n; i++)
            {
                if (result > 2147483647 / i) { return 0; };
                result *= i;
            };
            return result;
        };
        def factorial(i64 n) -> i64
        {
            if (n <= 1) { return 1; };
            i64 result = 1;
            for (i64 i = 2; i <= n; i++)
            {
                if (result > 9223372036854775807 / i) { return 0; };
                result *= i;
            };
            return result;
        };

        // ==================== GCD ====================
        def gcd<T: i8 | i16 | i32 | i64>(T a, T b) -> T
        {
            register T t;
            while (b != 0)
            {
                t = b;
                b = a % b;
                a = t;
            };
            return a;
        };

        // ==================== LCM (overflow safe) ====================
        inline def lcm<T: i8 | i16 | i32 | i64>(T a, T b) -> T
        {
            if (a == 0 | b == 0) { return 0; };
            return abs(a / gcd(a, b)) * b;
        };

        // ==================== Rounding ====================
        inline def floor(float x) -> float
        {
            i64 int_part = (i64)x;
            if (x >= 0.0f | x == (float)int_part) { return (float)int_part; };
            return (float)(int_part - 1);
        };
        inline def ceil(float x) -> float
        {
            i64 int_part = (i64)x;
            if (x <= 0.0f | x == (float)int_part) { return (float)int_part; };
            return (float)(int_part + 1);
        };
        inline def round(float x) -> float
        {
            if (x >= 0.0f) { return floor(x + 0.5f); };
            return ceil(x - 0.5f);
        };
        inline def floor(double x) -> double
        {
            i64 int_part = (i64)x;
            if (x >= 0.0 | x == (double)int_part) { return (double)int_part; };
            return (double)(int_part - 1);
        };
        inline def ceil(double x) -> double
        {
            i64 int_part = (i64)x;
            if (x <= 0.0 | x == (double)int_part) { return (double)int_part; };
            return (double)(int_part + 1);
        };
        inline def round(double x) -> double
        {
            if (x >= 0.0) { return floor(x + 0.5); };
            return ceil(x - 0.5);
        };
        // Integer rounding is a no-op; inline so callers pay nothing.
        inline def floor<T: i8 | i16 | i32 | i64>(T x) -> T { return x; };
        inline def ceil<T: i8 | i16 | i32 | i64>(T x) -> T  { return x; };
        inline def round<T: i8 | i16 | i32 | i64>(T x) -> T { return x; };

        // ==================== Trigonometry ====================
        //
        // sin/cos use Cody-Waite range reduction to [-pi/4, pi/4], then
        // evaluate minimax polynomials.  The pi/2 constant is split into
        // three double-precision parts (pio2_1, pio2_2, pio2_3) to avoid
        // cancellation for large arguments.
        //
        // Polynomial coefficients are from the standard fdlibm/SLEEF set,
        // accurate to within 1 ULP across the reduced range.

        // High-precision pi/2 split for Cody-Waite reduction:
        //   pio2_1  = first 33 bits of pi/2
        //   pio2_2  = second 33 bits
        //   pio2_3  = remainder
        #def _PIO2_1        1.57079632673412561417e+00;
        #def _PIO2_2        6.07710050650619224932e-11;
        #def _PIO2_3        6.12323399573676603587e-22;
        #def _TWO_OVER_PI   0.63661977236758134308;

        // Internal: evaluate sin kernel on r in [-pi/4, pi/4].
        // Uses degree-11 minimax polynomial (odd terms only).
        inline def _sin_kernel(double r) -> double
        {
            double r2;
            r2 = r * r;
            return r + r * r2 * (-1.66666666666666324348e-01
                 + r2 * ( 8.33333333332248946124e-03
                 + r2 * (-1.98412698298579493134e-04
                 + r2 * ( 2.75573137070700491217e-06
                 + r2 * (-2.50507602534165206869e-08
                 + r2 *   1.58969099521155010221e-10)))));
        };

        // Internal: evaluate cos kernel on r in [-pi/4, pi/4].
        // Uses degree-10 minimax polynomial (even terms only).
        inline def _cos_kernel(double r) -> double
        {
            double r2;
            r2 = r * r;
            return 1.0 - r2 * (5.0e-01
                 - r2 * ( 4.16666666666666019037e-02
                 - r2 * ( 1.38888888888741095749e-03
                 - r2 * ( 2.48015872894767294178e-05
                 - r2 * ( 2.75573143513906633035e-07
                 - r2 * ( 2.08757232129817851248e-09
                 - r2 *   1.13596475577881948265e-11))))));
        };

        // Internal: range-reduce x to [-pi/4, pi/4], return quadrant in *q.
        inline def _trig_reduce(double x, i32* q) -> double
        {
            double fn;
            i32    n;
            fn = x * _TWO_OVER_PI + 0.5;
            n  = (i32)fn;
            fn = (double)n;
            x  = x - fn * _PIO2_1;
            x  = x - fn * _PIO2_2;
            x  = x - fn * _PIO2_3;
            *q = n;
            return x;
        };

        // Internal: compute both sin and cos in one range-reduction pass.
        // Avoids calling _trig_reduce twice when both values are needed (e.g. tan).
        inline def _sincos_kernel(double x, double* s, double* c) -> void
        {
            bool neg;
            double r;
            i32    q;
            neg = x < 0.0;
            if (neg) { x = -x; };
            if (x <= 7.85398163397448278999e-01)
            {
                *s = neg ? -_sin_kernel(x) : _sin_kernel(x);
                *c = _cos_kernel(x);
                return;
            };
            r = _trig_reduce(x, @q);
            switch (q & 3)
            {
                case (0) { *s =  _sin_kernel(r); *c =  _cos_kernel(r); }
                case (1) { *s =  _cos_kernel(r); *c = -_sin_kernel(r); }
                case (2) { *s = -_sin_kernel(r); *c = -_cos_kernel(r); }
                default  { *s = -_cos_kernel(r); *c =  _sin_kernel(r); };
            };
            if (neg) { *s = -*s; };
        };

        def sin(double x) -> double
        {
            bool neg;
            double r;
            i32    q;
            neg = x < 0.0;
            if (neg) { x = -x; };
            if (x <= 7.85398163397448278999e-01)
            {
                r = _sin_kernel(x);
                if (neg) { r = -r; };
                return r;
            };
            r = _trig_reduce(x, @q);
            switch (q & 3)
            {
                case (0) { r =  _sin_kernel(r); }
                case (1) { r =  _cos_kernel(r); }
                case (2) { r = -_sin_kernel(r); }
                default  { r = -_cos_kernel(r); };
            };
            if (neg) { r = -r; };
            return r;
        };

        def cos(double x) -> double
        {
            double r;
            i32    q;
            if (x < 0.0) { x = -x; };
            if (x <= 7.85398163397448278999e-01)
            {
                return _cos_kernel(x);
            };
            r = _trig_reduce(x, @q);
            switch (q & 3)
            {
                case (0) { r =  _cos_kernel(r); }
                case (1) { r = -_sin_kernel(r); }
                case (2) { r = -_cos_kernel(r); }
                default  { r =  _sin_kernel(r); };
            };
            return r;
        };

        inline vectorcall sin(float x) -> float { return (float)sin((double)x); };
        inline vectorcall cos(float x) -> float { return (float)cos((double)x); };

        // tan uses the shared sincos kernel -- one range reduction for both values.
        vectorcall tan(float x) -> float
        {
            double s, c;
            _sincos_kernel((double)x, @s, @c);
            if (abs(c) < 1e-12) { return 0.0f; };
            return (float)(s / c);
        };
        vectorcall tan(double x) -> double
        {
            double s, c;
            _sincos_kernel(x, @s, @c);
            if (abs(c) < 1e-12) { return 0.0; };
            return s / c;
        };
        def atan(double x) -> double
        {
            // Reduce to [0, 1] via identity atan(x) = pi/2 - atan(1/x) for x > 1,
            // then evaluate a degree-13 minimax polynomial on [0, 1].
            bool neg, recip;
            neg   = x < 0.0;
            if (neg)   { x = -x; };
            recip = x > 1.0;
            if (recip) { x = 1.0 / x; };
            double x2 = x * x;
            double r = x * (1.0
                + x2 * (-3.33333333333329318027e-01
                + x2 * ( 1.99999999998764832476e-01
                + x2 * (-1.42857142725034663415e-01
                + x2 * ( 1.11111104054623529297e-01
                + x2 * (-9.09088713343650656196e-02
                + x2 * ( 7.69187620504482999495e-02
                + x2 * (-6.66107313738753120669e-02
                + x2 * ( 5.83357013379057348645e-02
                + x2 * (-4.76190184591045773639e-02
                + x2 * ( 3.64977340573025229249e-02
                + x2 * (-2.19986706991864906437e-02
                + x2 *   8.49330165602148348398e-03))))))))))));
            if (recip) { r = 1.57079632679489661923 - r; };
            if (neg)   { r = -r; };
            return r;
        };
        inline def atan(float x) -> float { return (float)atan((double)x); };
        inline def asin(float x) -> float
        {
            if (x >= 1.0f)  { return PIF * 0.5f; };
            if (x <= -1.0f) { return -PIF * 0.5f; };
            return atan(x / sqrt(1.0f - x*x));
        };
        inline def asin(double x) -> double
        {
            if (x >= 1.0)  { return PID * 0.5; };
            if (x <= -1.0) { return -PID * 0.5; };
            return atan(x / sqrt(1.0 - x*x));
        };
        inline def acos(float x) -> float   { return PIF * 0.5f - asin(x); };
        inline def acos(double x) -> double { return PID * 0.5  - asin(x); };
        def atan2(float y, float x) -> float
        {
            if (x > 0.0f)
            {
                return atan(y / x);
            };
            if (x < 0.0f)
            {
                float a = atan(y / x);
                return (y >= 0.0f) ? a + PIF : a - PIF;
            };
            if (y > 0.0f) { return PIF * 0.5f; };
            if (y < 0.0f) { return -PIF * 0.5f; };
            return 0.0f;
        };
        def atan2(double y, double x) -> double
        {
            if (x > 0.0)
            {
                return atan(y / x);
            };
            if (x < 0.0)
            {
                double a = atan(y / x);
                return (y >= 0.0) ? a + PID : a - PID;
            };
            if (y > 0.0) { return PID * 0.5; };
            if (y < 0.0) { return -PID * 0.5; };
            return 0.0;
        };

        // ==================== Hyperbolic functions ====================
        // Forward declarations for exp/log used below
        def exp(float) -> float,
            exp(double) -> double,
            log(float) -> float,
            log(double) -> double;

        // sinh/cosh: one exp() call each -- emx = 1/ex
        inline vectorcall sinh(float x) -> float
        {
            float ex = exp(x);
            return (ex - 1.0f / ex) * 0.5f;
        };
        inline vectorcall sinh(double x) -> double
        {
            double ex = exp(x);
            return (ex - 1.0 / ex) * 0.5;
        };
        inline vectorcall cosh(float x) -> float
        {
            float ex = exp(x);
            return (ex + 1.0f / ex) * 0.5f;
        };
        inline vectorcall cosh(double x) -> double
        {
            double ex = exp(x);
            return (ex + 1.0 / ex) * 0.5;
        };
        inline vectorcall tanh(float x) -> float
        {
            float ex = exp(2.0f * x);
            return (ex - 1.0f) / (ex + 1.0f);
        };
        inline vectorcall tanh(double x) -> double
        {
            double ex = exp(2.0 * x);
            return (ex - 1.0) / (ex + 1.0);
        };
        inline def asinh(float x) -> float   { return log(x + sqrt(x*x + 1.0f)); };
        inline def asinh(double x) -> double { return log(x + sqrt(x*x + 1.0)); };
        inline def acosh(float x) -> float
        {
            if (x < 1.0f) { return 0.0f; };
            return log(x + sqrt(x*x - 1.0f));
        };
        inline def acosh(double x) -> double
        {
            if (x < 1.0) { return 0.0; };
            return log(x + sqrt(x*x - 1.0));
        };
        inline def atanh(float x) -> float
        {
            if (abs(x) >= 1.0f) { return 0.0f; };
            return 0.5f * log((1.0f + x) / (1.0f - x));
        };
        inline def atanh(double x) -> double
        {
            if (abs(x) >= 1.0) { return 0.0; };
            return 0.5 * log((1.0 + x) / (1.0 - x));
        };

        // ==================== Exponential and Logarithmic ====================
        def exp(double x) -> double
        {
            // Clamp to avoid overflow/underflow
            if (x >  7.09782712893383996732e+02) { return 1.7976931348623157e+308; };
            if (x < -7.45133219101941108420e+02) { return 0.0; };

            // Range reduction: x = n*ln2 + r, |r| <= ln2/2
            double ln2_hi  = 6.93147180369123816490e-01;
            double ln2_lo  = 1.90821492927058770002e-10;
            double inv_ln2 = 1.44269504088896338700e+00;

            double fn = x * inv_ln2;
            i32    n;
            if (fn >= 0.0) { n = (i32)(fn + 0.5); } else { n = (i32)(fn - 0.5); };
            double r = x - (double)n * ln2_hi;
            r = r - (double)n * ln2_lo;

            // Degree-6 minimax for exp(r) on [-ln2/2, ln2/2]
            double r2 = r * r;
            double p = r * (1.0
                + r2 * (1.66666666666666019037e-01
                + r2 * (4.16666666666602470952e-03
                + r2 * (8.33333333310201598374e-05
                + r2 * (1.38888888885959271366e-06
                + r2 *  2.48015872894612088499e-08)))));
            double result = 1.0 + (r * p / (2.0 - p) + r);

            // Scale by 2^n via exponent field manipulation
            if (n == 0) { return result; };
            u64 bits;
            bits = *(u64*)@result;
            i64 exp_field;
            exp_field = (i64)((bits >> 52) & (u64)0x7FF) + (i64)n;
            if (exp_field <= 0)    { return 0.0; };
            if (exp_field >= 2047) { return 1.7976931348623157e+308; };
            bits = (bits & (u64)0x800FFFFFFFFFFFFF) | ((u64)exp_field << 52);
            return *(double*)@bits;
        };
        inline def exp(float x) -> float { return (float)exp((double)x); };

        def log(double x) -> double
        {
            if (x <= 0.0) { return -1.7976931348623157e+308; };

            // Extract exponent and mantissa via bit manipulation
            u64 bits = *(u64*)@x;
            i32 e    = (i32)((bits >> 52) & (u64)0x7FF) - 1023;
            // Set exponent to 0 (biased 1023) to get mantissa in [1, 2)
            bits = (bits & (u64)0x800FFFFFFFFFFFFF) | (u64)0x3FF0000000000000;
            double m = *(double*)@bits;

            // Reduce to [sqrt(2)/2, sqrt(2)] -- if m < sqrt(2)/2, shift up
            if (m < 7.07106781186547524401e-01) { m = m * 2.0; e = e - 1; };

            // Minimax polynomial for log((1+f)/(1-f)) where f = (m-1)/(m+1)
            double f  = (m - 1.0) / (m + 1.0);
            double f2 = f * f;
            double w  = f2 * f2;
            double r1 = 6.66666666666735130309e-01
                      + w * (2.85714285135205626685e-01
                      + w * (1.81818180850050775676e-01
                      + w *  1.41253449399408350459e-01));
            double r2 = 3.99999999994889520090e-01
                      + w * (2.22222198432149984031e-01
                      + w *  1.53846227504559030779e-01);
            double r  = f2 * r2 + w * r1;
            double hfsq = 0.5 * f * f;
            double result = f * (1.0 - hfsq + r) * 2.0;

            // Add exponent contribution: result + n * ln2
            double ln2_hi = 6.93147180369123816490e-01;
            double ln2_lo = 1.90821492927058770002e-10;
            result = result + (double)e * ln2_lo;
            result = result + (double)e * ln2_hi;
            return result;
        };
        inline def log(float x) -> float     { return (float)log((double)x); };
        inline def log10(float x) -> float   { return log(x) * LOG10E_F; };
        inline def log10(double x) -> double { return log(x) * LOG10E_D; };
        inline def log2(float x) -> float    { return log(x) * LOG2E_F; };
        inline def log2(double x) -> double  { return log(x) * LOG2E_D; };

        // ==================== Power Functions ====================
        def pow<T: i8 | i16 | i32 | i64>(T base, T exp) -> T
        {
            if (exp == 0) { return 1; };
            if (exp < 0)  { return 0; };
            register T result = 1;
            while (exp)
            {
                if (exp & 1) { result = result * base; };
                base = base * base;
                exp  = exp >> 1;
            };
            return result;
        };
        inline def pow(float base, float exp) -> float
        {
            if (base == 0.0f & exp == 0.0f) { return 1.0f; };
            if (base <= 0.0f) { return 0.0f; };
            return exp(exp * log(base));
        };
        inline def pow(double base, double exp) -> double
        {
            if (base == 0.0 & exp == 0.0) { return 1.0; };
            if (base <= 0.0) { return 0.0; };
            return exp(exp * log(base));
        };
        inline def cbrt(float x) -> float
        {
            if (x == 0.0f) { return 0.0f; };
            return (x > 0.0f) ? exp(log(x) / 3.0f) : -exp(log(-x) / 3.0f);
        };
        inline def cbrt(double x) -> double
        {
            if (x == 0.0) { return 0.0; };
            return (x > 0.0) ? exp(log(x) / 3.0) : -exp(log(-x) / 3.0);
        };
        inline def hypot(float x, float y) -> float   { return sqrt(x*x + y*y); };
        inline def hypot(double x, double y) -> double { return sqrt(x*x + y*y); };

        // ==================== Special Functions ====================
        vectorcall erf(float x) -> float
        {
            float a1 = 0.254829592f, a2 = -0.284496736f, a3 = 1.421413741f;
            float a4 = -1.453152027f, a5 = 1.061405429f, p = 0.3275911f;
            float sign = (x >= 0.0f) ? 1.0f : -1.0f;
            x = abs(x);
            float t = 1.0f / (1.0f + p*x);
            float y = 1.0f - (((((a5*t + a4)*t) + a3)*t + a2)*t + a1)*t * exp(-x*x);
            return sign * y;
        };
        vectorcall erf(double x) -> double
        {
            double a1 = 0.254829592, a2 = -0.284496736, a3 = 1.421413741;
            double a4 = -1.453152027, a5 = 1.061405429, p = 0.3275911;
            double sign = (x >= 0.0) ? 1.0 : -1.0;
            x = abs(x);
            double t = 1.0 / (1.0 + p*x);
            double y = 1.0 - (((((a5*t + a4)*t) + a3)*t + a2)*t + a1)*t * exp(-x*x);
            return sign * y;
        };
        inline def erfc(float x) -> float   { return 1.0f - erf(x); };
        inline def erfc(double x) -> double { return 1.0 - erf(x); };

        // tgamma: Lanczos approximation, g=5, n=7 (Godfrey coefficients).
        // Accurate to ~15 significant digits for Re(x) > 0.
        def tgamma(double x) -> double
        {
            if (x <= 0.0) { return 0.0; };
            // Reflection for x < 0.5 (not needed here since we guard x <= 0)
            double t = x + _LANCZOS_G - 0.5;
            double s = _LANCZOS_C0
                     + _LANCZOS_C1 / (x + 0.0)
                     + _LANCZOS_C2 / (x + 1.0)
                     + _LANCZOS_C3 / (x + 2.0)
                     + _LANCZOS_C4 / (x + 3.0)
                     + _LANCZOS_C5 / (x + 4.0)
                     + _LANCZOS_C6 / (x + 5.0);
            return sqrt(2.0 * PID) * pow(t, x - 0.5) * exp(-t) * s;
        };
        inline def tgamma(float x) -> float { return (float)tgamma((double)x); };
        inline def lgamma(float x) -> float   { return log(abs(tgamma((double)x))); };
        inline def lgamma(double x) -> double { return log(abs(tgamma(x))); };

        // ==================== Floating-point classification ====================
        inline vectorcall isnan(float x) -> bool
        {
            u32 bits = (u32)x;
            u32 exp  = (bits >> 23) & 0xFF;
            u32 frac = bits & 0x7FFFFF;
            return (exp == 0xFF) & (frac != 0);
        };
        inline vectorcall isnan(double x) -> bool
        {
            u64 bits = (u64)x;
            u64 exp  = (bits >> 52) & 0x7FF;
            u64 frac = bits & 0xFFFFFFFFFFFFFu;
            return (exp == 0x7FF) & (frac != 0);
        };
        inline vectorcall isinf(float x) -> bool
        {
            u32 bits = (u32)x;
            u32 exp  = (bits >> 23) & 0xFF;
            u32 frac = bits & 0x7FFFFF;
            return (exp == 0xFF) & (frac == 0);
        };
        inline vectorcall isinf(double x) -> bool
        {
            u64 bits = (u64)x;
            u64 exp  = (bits >> 52) & 0x7FF;
            u64 frac = bits & 0xFFFFFFFFFFFFFu;
            return (exp == 0x7FF) & (frac == 0);
        };
        inline def isfinite(float x) -> bool  { return !isnan(x) & !isinf(x); };
        inline def isfinite(double x) -> bool { return !isnan(x) & !isinf(x); };
        inline vectorcall isnormal(float x) -> bool
        {
            u32 bits = (u32)x;
            u32 exp  = (bits >> 23) & 0xFF;
            return (exp != 0) & (exp != 0xFF);
        };
        inline vectorcall isnormal(double x) -> bool
        {
            u64 bits = (u64)x;
            u64 exp  = (bits >> 52) & 0x7FF;
            return (exp != 0) & (exp != 0x7FF);
        };
        inline def fpclassify(float x) -> i32
        {
            if (isnan(x))     { return 0; };
            if (isinf(x))     { return 1; };
            if (x == 0.0f)    { return 2; };
            if (isnormal(x))  { return 3; };
            return 4;
        };
        inline def fpclassify(double x) -> i32
        {
            if (isnan(x))     { return 0; };
            if (isinf(x))     { return 1; };
            if (x == 0.0)     { return 2; };
            if (isnormal(x))  { return 3; };
            return 4;
        };

        // ==================== nextafter, copysign, fdim, fma, fmod ====================
        inline vectorcall nextafter(float f, float to) -> float
        {
            if (isnan(f) | isnan(to)) { return NAN_F; };
            if (f == to) { return to; };
            u32 bits = (u32)f;
            if (f < to)
            {
                bits = (bits & 0x80000000) ? (bits - 1) : (bits + 1);
            }
            else
            {
                bits = (bits & 0x80000000) ? (bits + 1) : (bits - 1);
            };
            return (float)bits;
        };
        inline vectorcall nextafter(double f, double to) -> double
        {
            if (isnan(f) | isnan(to)) { return NAN_D; };
            if (f == to) { return to; };
            u64 bits = (u64)f;
            if (f < to)
            {
                bits = (bits & 0x8000000000000000u) ? (bits - 1) : (bits + 1);
            }
            else
            {
                bits = (bits & 0x8000000000000000u) ? (bits + 1) : (bits - 1);
            };
            return (double)bits;
        };
        inline vectorcall copysign(float x, float y) -> float
        {
            u32 bx = (u32)x, by = (u32)y;
            bx = (bx & 0x7FFFFFFF) | (by & 0x80000000);
            return (float)bx;
        };
        inline vectorcall copysign(double x, double y) -> double
        {
            u64 bx = (u64)x, by = (u64)y;
            bx = (bx & 0x7FFFFFFFFFFFFFFFu) | (by & 0x8000000000000000u);
            return (double)bx;
        };
        inline def fdim(float x, float y) -> float
        {
            return (x > y) ? (x - y) : 0.0f;
        };
        inline def fdim(double x, double y) -> double
        {
            return (x > y) ? (x - y) : 0.0d;
        };
        inline vectorcall fma(float x, float y, float z) -> float
        {
            return (float)((double)x * (double)y + (double)z);
        };
        inline vectorcall fma(double x, double y, double z) -> double
        {
            return x*y + z;
        };
        inline def fmod(float x, float y) -> float
        {
            if (y == 0.0f) { return 0.0f; };
            return x - (float)(i64)(x / y) * y;
        };
        inline def fmod(double x, double y) -> double
        {
            if (y == 0.0) { return 0.0; };
            return x - (double)(i64)(x / y) * y;
        };

        // ==================== Bit manipulation ====================

        // popcount: parallel bit-trick O(log N), no loop, no branch.
        // Each type is limited to its own bit width -- a byte can count at most 8,
        // i16 at most 16, etc.

        inline def popcount(byte x) -> byte
        {
            // 8-bit parallel -- max result 8
            byte v = x;
            v = v - ((v >> 1) & 0x55b);
            v = (v & 0x33b) + ((v >> 2) & 0x33b);
            return (v + (v >> 4)) & 0x0Fb;
        };
        inline def popcount(i8 x) -> i8
        {
            // Treat as 8-bit pattern; max result 8
            byte v = (byte)x;
            v = v - ((v >> 1) & 0x55b);
            v = (v & 0x33b) + ((v >> 2) & 0x33b);
            return (i8)((v + (v >> 4)) & 0x0Fb);
        };
        inline def popcount(i16 x) -> i16
        {
            // 16-bit parallel -- max result 16
            u16 v = (u16)x;
            v = v - ((v >> 1) & 0x5555);
            v = (v & 0x3333) + ((v >> 2) & 0x3333);
            v = (v + (v >> 4)) & 0x0F0F;
            return (i16)((v * 0x0101) >> 8);
        };
        inline def popcount(u16 x) -> u16
        {
            u16 v = x;
            v = v - ((v >> 1) & 0x5555);
            v = (v & 0x3333) + ((v >> 2) & 0x3333);
            v = (v + (v >> 4)) & 0x0F0F;
            return (v * 0x0101) >> 8;
        };
        inline def popcount(i32 x) -> i32
        {
            // 32-bit parallel -- max result 32
            u32 v = (u32)x;
            v = v - ((v >> 1) & 0x55555555u);
            v = (v & 0x33333333u) + ((v >> 2) & 0x33333333u);
            v = (v + (v >> 4)) & 0x0F0F0F0Fu;
            return (i32)((v * 0x01010101u) >> 24);
        };
        inline def popcount(u32 x) -> u32
        {
            u32 v = x;
            v = v - ((v >> 1) & 0x55555555u);
            v = (v & 0x33333333u) + ((v >> 2) & 0x33333333u);
            v = (v + (v >> 4)) & 0x0F0F0F0Fu;
            return (v * 0x01010101u) >> 24;
        };
        inline def popcount(i64 x) -> i64
        {
            // 64-bit parallel -- max result 64
            u64 v = (u64)x;
            v = v - ((v >> 1) & 0x5555555555555555u);
            v = (v & 0x3333333333333333u) + ((v >> 2) & 0x3333333333333333u);
            v = (v + (v >> 4)) & 0x0F0F0F0F0F0F0F0Fu;
            return (i64)((v * 0x0101010101010101u) >> 56);
        };
        inline def popcount(u64 x) -> u64
        {
            u64 v = x;
            v = v - ((v >> 1) & 0x5555555555555555u);
            v = (v & 0x3333333333333333u) + ((v >> 2) & 0x3333333333333333u);
            v = (v + (v >> 4)) & 0x0F0F0F0F0F0F0F0Fu;
            return (v * 0x0101010101010101u) >> 56;
        };

        def reverse_bits(byte x) -> byte
        {
            byte result = 0;
            for (byte i = 0; i < 8; i++)
            {
                result = (result << 1) | (x & 1);
                x = x >> 1;
            };
            return result;
        };
        def reverse_bits(i8 x) -> i8
        {
            i8 result = 0;
            for (i8 i = 0; i < 8; i++)
            {
                result = (result << 1) | (x & 1);
                x = x >> 1;
            };
            return result;
        };
        def reverse_bits(i16 x) -> i16
        {
            i16 result = 0;
            for (i16 i = 0; i < 16; i++)
            {
                result = (result << 1) | (x & 1);
                x = x >> 1;
            };
            return result;
        };
        def reverse_bits(i32 x) -> i32
        {
            i32 result = 0;
            for (i32 i = 0; i < 32; i++)
            {
                result = (result << 1) | (x & 1);
                x = x >> 1;
            };
            return result;
        };
        def reverse_bits(i64 x) -> i64
        {
            i64 result = 0;
            for (i64 i = 0; i < 64; i++)
            {
                result = (result << 1) | (x & 1);
                x = x >> 1;
            };
            return result;
        };

        inline def rotl(i8 x, i8 n) -> i8
        {
            n = n & 7;
            return (x << n) | ((x & 0xFF) >> (8 - n));
        };
        inline def rotl(i16 x, i16 n) -> i16
        {
            n = n & 15;
            return (x << n) | ((x & 0xFFFF) >> (16 - n));
        };
        inline def rotl(i32 x, i32 n) -> i32
        {
            n = n & 31;
            return (x << n) | ((x & 0xFFFFFFFFu) >> (32 - n));
        };
        inline def rotl(i64 x, i64 n) -> i64
        {
            n = n & 63;
            return (x << n) | ((x & 0xFFFFFFFFFFFFFFFFu) >> (64 - n));
        };
        inline def rotr(i8 x, i8 n) -> i8
        {
            n = n & 7;
            return (x >> n) | (x << (8 - n));
        };
        inline def rotr(i16 x, i16 n) -> i16
        {
            n = n & 15;
            return (x >> n) | (x << (16 - n));
        };
        inline def rotr(i32 x, i32 n) -> i32
        {
            n = n & 31;
            return (x >> n) | (x << (32 - n));
        };
        inline def rotr(i64 x, i64 n) -> i64
        {
            n = n & 63;
            return (x >> n) | (x << (64 - n));
        };

        // clz: binary-search O(log N) -- no loop
        inline def clz(byte x) -> byte
        {
            if (x == 0) { return 8; };
            byte n = 0;
            if ((x & 0xF0b) == 0) { n = n + 4; x = x << 4; };
            if ((x & 0xC0b) == 0) { n = n + 2; x = x << 2; };
            if ((x & 0x80b) == 0) { n = n + 1; };
            return n;
        };
        inline def clz(i8 x) -> i8
        {
            if (x == 0) { return 8; };
            i8 n = 0;
            if ((x & 0xF0) == 0) { n = n + 4; x = x << 4; };
            if ((x & 0xC0) == 0) { n = n + 2; x = x << 2; };
            if ((x & 0x80) == 0) { n = n + 1; };
            return n;
        };
        inline def clz(i16 x) -> i16
        {
            if (x == 0) { return 16; };
            i16 n = 0;
            if ((x & 0xFF00) == 0) { n = n + 8;  x = x << 8;  };
            if ((x & 0xF000) == 0) { n = n + 4;  x = x << 4;  };
            if ((x & 0xC000) == 0) { n = n + 2;  x = x << 2;  };
            if ((x & 0x8000) == 0) { n = n + 1; };
            return n;
        };
        inline def clz(i32 x) -> i32
        {
            if (x == 0) { return 32; };
            i32 n = 0;
            if ((x & 0xFFFF0000) == 0) { n = n + 16; x = x << 16; };
            if ((x & 0xFF000000) == 0) { n = n + 8;  x = x << 8;  };
            if ((x & 0xF0000000) == 0) { n = n + 4;  x = x << 4;  };
            if ((x & 0xC0000000) == 0) { n = n + 2;  x = x << 2;  };
            if ((x & 0x80000000) == 0) { n = n + 1; };
            return n;
        };
        inline def clz(i64 x) -> i64
        {
            if (x == 0) { return 64; };
            i64 n = 0;
            if ((x & 0xFFFFFFFF00000000u) == 0) { n = n + 32; x = x << 32; };
            if ((x & 0xFFFF000000000000u) == 0) { n = n + 16; x = x << 16; };
            if ((x & 0xFF00000000000000u) == 0) { n = n + 8;  x = x << 8;  };
            if ((x & 0xF000000000000000u) == 0) { n = n + 4;  x = x << 4;  };
            if ((x & 0xC000000000000000u) == 0) { n = n + 2;  x = x << 2;  };
            if ((x & 0x8000000000000000u) == 0) { n = n + 1; };
            return n;
        };

        // ctz: isolate lowest set bit then clz on the complement -- O(log N)
        inline def ctz(byte x) -> byte
        {
            if (x == 0) { return 8; };
            return (byte)(8 - 1 - clz(x & (byte)(-(i8)x)));
        };
        inline def ctz(i8 x) -> i8
        {
            if (x == 0) { return 8; };
            return (i8)(8 - 1 - clz((i8)(x & -x)));
        };
        inline def ctz(i16 x) -> i16
        {
            if (x == 0) { return 16; };
            return (i16)(16 - 1 - clz((i16)(x & -x)));
        };
        inline def ctz(i32 x) -> i32
        {
            if (x == 0) { return 32; };
            return 32 - 1 - clz(x & -x);
        };
        inline def ctz(i64 x) -> i64
        {
            if (x == 0) { return 64; };
            return 64 - 1 - clz(x & -x);
        };

        def bit_length<T: i8 | i16 | i32 | i64>(T x) -> T
        {
            if (x < 0) { x = -x; };
            T len = 0;
            while (x != 0)
            {
                len = len + 1;
                x = x >> 1;
            };
            return len;
        };

        inline def parity<T: i8 | i16 | i32 | i64 | byte | u16 | u32 | u64>(T x) -> T
        {
            return (T)(popcount(x) & 1);
        };

        inline def byte_swap(i16 x) -> i16
        {
            return ((x >> 8) & 0xFF) | ((x & 0xFF) << 8);
        };
        inline def byte_swap(i32 x) -> i32
        {
            return ((x >> 24) & 0xFF) | ((x >> 8) & 0xFF00) | ((x & 0xFF00) << 8) | ((x & 0xFF) << 24);
        };
        inline def byte_swap(i64 x) -> i64
        {
            i64 result = (x & 0x00000000000000FFu) << 56;
            result = result | ((x & 0x000000000000FF00u) << 40);
            result = result | ((x & 0x0000000000FF0000u) << 24);
            result = result | ((x & 0x00000000FF000000u) << 8);
            result = result | ((x & 0x000000FF00000000u) >> 8);
            result = result | ((x & 0x0000FF0000000000u) >> 24);
            result = result | ((x & 0x00FF000000000000u) >> 40);
            result = result | ((x & 0xFF00000000000000u) >> 56);
            return result;
        };
        inline def byte_swap(u16 x) -> u16 { return (u16)byte_swap((i16)x); };
        inline def byte_swap(u32 x) -> u32 { return (u32)byte_swap((i32)x); };
        inline def byte_swap(u64 x) -> u64 { return (u64)byte_swap((i64)x); };

        // ==================== Conversions and Utilities ====================
        inline def radians(float deg) -> float   { return deg * PIF / 180.0f; };
        inline def radians(double deg) -> double { return deg * PID / 180.0; };
        inline def degrees(float rad) -> float   { return rad * 180.0f / PIF; };
        inline def degrees(double rad) -> double { return rad * 180.0 / PID; };
        inline vectorcall saturate(float x) -> float
        {
            if (x < 0.0f) { return 0.0f; };
            if (x > 1.0f) { return 1.0f; };
            return x;
        };
        inline vectorcall saturate(double x) -> double
        {
            if (x < 0.0) { return 0.0; };
            if (x > 1.0) { return 1.0; };
            return x;
        };
        inline def smoothstep(float edge0, float edge1, float x) -> float
        {
            float t = saturate((x - edge0) / (edge1 - edge0));
            return t * t * (3.0f - 2.0f * t);
        };
        inline def smoothstep(double edge0, double edge1, double x) -> double
        {
            double t = saturate((x - edge0) / (edge1 - edge0));
            return t * t * (3.0 - 2.0 * t);
        };
        inline def step(float edge, float x) -> float
        {
            return (x >= edge) ? 1.0f : 0.0f;
        };
        inline def step(double edge, double x) -> double
        {
            return (x >= edge) ? 1.0 : 0.0;
        };

        // ==================== Sign and lerp ====================
        inline def sign<T: i8 | i16 | i32 | i64>(T x) -> T
        {
            if (x > 0) { return 1; };
            if (x < 0) { return -1; };
            return 0;
        };
        inline vectorcall sign(float x) -> float
        {
            if (x > 0.0f) { return 1.0f; };
            if (x < 0.0f) { return -1.0f; };
            return 0.0f;
        };
        inline vectorcall sign(double x) -> double
        {
            if (x > 0.0) { return 1.0; };
            if (x < 0.0) { return -1.0; };
            return 0.0;
        };
        inline def lerp<T: i8 | i16 | i32 | i64>(T a, T b, float t) -> T
        {
            return (T)((float)a + (float)(b - a) * t);
        };
        inline vectorcall lerp(float a, float b, float t) -> float
        {
            return a + (b - a) * t;
        };
        inline vectorcall lerp(double a, double b, double t) -> double
        {
            return a + (b - a) * t;
        };

        // ---------- Floating-point decomposition ----------
        inline def frexp(float x, int* exp) -> float
        {
            if (x == 0.0f) { *exp = 0; return 0.0f; };
            if (isinf(x) | isnan(x)) { *exp = 0; return x; };
            u32 bits = (u32)x;
            i32 e = ((bits >> 23) & 0xFF) - 127;
            u32 mant = (bits & 0x7FFFFF) | 0x800000;
            *exp = e + 1;
            return (float)(((bits & 0x80000000) | (mant >> 1)) & 0xFFFFFFFFu);
        };
        inline def frexp(double x, int* exp) -> double
        {
            if (x == 0.0) { *exp = 0; return 0.0; };
            if (isinf(x) | isnan(x)) { *exp = 0; return x; };
            u64 bits = (u64)x;
            i64 e = ((bits >> 52) & 0x7FF) - 1023;
            u64 mant = (bits & 0xFFFFFFFFFFFFFu) | 0x10000000000000u;
            *exp = (int)(e + 1);
            return (double)(((bits & 0x8000000000000000u) | (mant >> 1)) & 0xFFFFFFFFFFFFFFFFu);
        };
        inline def ldexp(float x, int exp) -> float
        {
            if (x == 0.0f | isinf(x) | isnan(x)) { return x; };
            return (float)((u32)x + ((u32)exp << 23));
        };
        inline def ldexp(double x, int exp) -> double
        {
            if (x == 0.0 | isinf(x) | isnan(x)) { return x; };
            return (double)((u64)x + ((u64)exp << 52));
        };
        inline def modf(float x, float* intpart) -> float
        {
            *intpart = (float)(i64)x;
            return x - *intpart;
        };
        inline def modf(double x, double* intpart) -> double
        {
            *intpart = (double)(i64)x;
            return x - *intpart;
        };
        inline def ilogb(float x) -> int
        {
            if (x == 0.0f) { return -2147483648; };
            if (isnan(x))  { return 2147483647; };
            if (isinf(x))  { return 2147483647; };
            u32 bits = (u32)x;
            return (int)((bits >> 23) & 0xFF) - 127;
        };
        inline def ilogb(double x) -> int
        {
            if (x == 0.0)  { return -2147483648; };
            if (isnan(x))  { return 2147483647; };
            if (isinf(x))  { return 2147483647; };
            u64 bits = (u64)x;
            return (int)((bits >> 52) & 0x7FF) - 1023;
        };
        inline def logb(float x) -> float   { return (float)ilogb(x); };
        inline def logb(double x) -> double { return (double)ilogb(x); };
        inline def scalbn(float x, int n) -> float    { return ldexp(x, n); };
        inline def scalbn(double x, int n) -> double  { return ldexp(x, n); };
        inline def scalbln(float x, long n) -> float  { return scalbn(x, (int)n); };
        inline def scalbln(double x, long n) -> double { return scalbn(x, (int)n); };

        // ---------- Additional rounding ----------
        inline def trunc(float x) -> float   { return (float)(i64)x; };
        inline def trunc(double x) -> double { return (double)(i64)x; };
        inline def nearbyint(float x) -> float   { return round(x); };
        inline def nearbyint(double x) -> double { return round(x); };

        def roundeven(float x) -> float
        {
            float r = round(x);
            if (abs(x - r) == 0.5f)
            {
                if ((i64)r & 1) { return r - ((x > 0.0f) ? 1.0f : -1.0f); };
            };
            return r;
        };
        def roundeven(double x) -> double
        {
            double r = round(x);
            if (abs(x - r) == 0.5)
            {
                if ((i64)r & 1) { return r - ((x > 0.0) ? 1.0 : -1.0); };
            };
            return r;
        };

        inline def lrint(float x) -> long   { return (long)round(x); };
        inline def lrint(double x) -> long  { return (long)round(x); };
        inline def llrint(float x) -> i64   { return (i64)round(x); };
        inline def llrint(double x) -> i64  { return (i64)round(x); };
        inline def lround(float x) -> long  { return (long)round(x); };
        inline def lround(double x) -> long { return (long)round(x); };
        inline def llround(float x) -> i64  { return (i64)round(x); };
        inline def llround(double x) -> i64 { return (i64)round(x); };

        // ---------- Accurate small argument ----------
        inline def expm1(float x) -> float   { return exp(x) - 1.0f; };
        inline def expm1(double x) -> double { return exp(x) - 1.0; };
        inline def log1p(float x) -> float   { return log(1.0f + x); };
        inline def log1p(double x) -> double { return log(1.0 + x); };

        // ---------- Exponential base-2 and base-10 ----------
        inline def exp2(float x) -> float    { return pow(2.0f, x); };
        inline def exp2(double x) -> double  { return pow(2.0d, x); };
        inline def exp10(float x) -> float   { return pow(10.0f, x); };
        inline def exp10(double x) -> double { return pow(10.0d, x); };

        // ---------- pi-scaled trig ----------
        def sinpi(float x) -> float
        {
            if (x == 0.0f) { return 0.0f; };
            float r = fmod(x, 2.0f);
            if (r > 1.0f) { r -= 2.0f; };
            return sin(r * PIF);
        };
        def sinpi(double x) -> double
        {
            if (x == 0.0) { return 0.0; };
            double r = fmod(x, 2.0);
            if (r > 1.0) { r -= 2.0; };
            return sin(r * PID);
        };
        def cospi(float x) -> float
        {
            if (x == 0.5f) { return 0.0f; };
            float r = fmod(x, 2.0f);
            if (r > 1.0f) { r -= 2.0f; };
            return cos(r * PIF);
        };
        def cospi(double x) -> double
        {
            if (x == 0.5) { return 0.0; };
            double r = fmod(x, 2.0);
            if (r > 1.0) { r -= 2.0; };
            return cos(r * PID);
        };
        def tanpi(float x) -> float
        {
            double s, c;
            _sincos_kernel((double)(fmod(x, 2.0f) > 1.0f ? fmod(x, 2.0f) - 2.0f : fmod(x, 2.0f)) * (double)PIF, @s, @c);
            if (abs(c) < 1e-12) { return 0.0f; };
            return (float)(s / c);
        };
        def tanpi(double x) -> double
        {
            double s, c;
            double r = fmod(x, 2.0);
            if (r > 1.0) { r -= 2.0; };
            _sincos_kernel(r * PID, @s, @c);
            if (abs(c) < 1e-12) { return 0.0; };
            return s / c;
        };

        // ---------- Inverse error functions ----------
        def erfinv(float x) -> float
        {
            if (x < -1.0f | x > 1.0f) { return NAN_F; };
            float a = 0.147f, y = erf(x);
            return y / sqrt(1.0f - exp(-y*y) * (a + 0.5f * log(1.0f - y*y)));
        };
        def erfinv(double x) -> double
        {
            if (x < -1.0 | x > 1.0) { return NAN_D; };
            double a = 0.147, y = erf(x);
            return y / sqrt(1.0 - exp(-y*y) * (a + 0.5 * log(1.0 - y*y)));
        };
        inline def erfcinv(float x) -> float   { return erfinv(1.0f - x); };
        inline def erfcinv(double x) -> double { return erfinv(1.0 - x); };

        // ---------- IEEE remainder and quotient ----------
        inline def remainder(float x, float y) -> float
        {
            if (y == 0.0f) { return 0.0f; };
            return x - round(x / y) * y;
        };
        inline def remainder(double x, double y) -> double
        {
            if (y == 0.0) { return 0.0; };
            return x - round(x / y) * y;
        };
        def remquo(float x, float y, int* quo) -> float
        {
            if (y == 0.0f) { *quo = 0; return 0.0f; };
            float q = round(x / y);
            *quo = (int)q;
            return x - q * y;
        };
        def remquo(double x, double y, int* quo) -> double
        {
            if (y == 0.0) { *quo = 0; return 0.0; };
            double q = round(x / y);
            *quo = (int)q;
            return x - q * y;
        };

        // ---------- Beta functions ----------
        inline def beta(float a, float b) -> float   { return tgamma(a) * tgamma(b) / tgamma(a + b); };
        inline def beta(double a, double b) -> double { return tgamma(a) * tgamma(b) / tgamma(a + b); };
        inline def lbeta(float a, float b) -> float   { return lgamma(a) + lgamma(b) - lgamma(a + b); };
        inline def lbeta(double a, double b) -> double { return lgamma(a) + lgamma(b) - lgamma(a + b); };

        // ---------- Gamma with sign ----------
        // Sign is determined analytically: tgamma(x) < 0 when x is in (-2n-1, -2n) for integer n.
        // For positive x it is always positive. We compute tgamma once.
        def lgamma_r(double x, int* signp) -> double
        {
            double g = tgamma(x);
            *signp = (g >= 0.0) ? 1 : -1;
            return log(abs(g));
        };
        inline def lgamma_r(float x, int* signp) -> float
        {
            return (float)lgamma_r((double)x, signp);
        };

        // ---------- Bessel functions (first kind) ----------
        def besselj0(float x) -> float
        {
            if (abs(x) < 8.0f)
            {
                float x2 = x * x;
                return 1.0f - x2/4.0f + x2*x2/64.0f - x2*x2*x2/2304.0f + x2*x2*x2*x2/147456.0f;
            };
            return sqrt(2.0f/(PIF*abs(x))) * cos(x - PIF/4.0f);
        };
        def besselj0(double x) -> double
        {
            if (abs(x) < 8.0)
            {
                double x2 = x * x;
                return 1.0 - x2/4.0 + x2*x2/64.0 - x2*x2*x2/2304.0 + x2*x2*x2*x2/147456.0;
            };
            return sqrt(2.0/(PID*abs(x))) * cos(x - PID/4.0);
        };
        def besselj1(float x) -> float
        {
            if (abs(x) < 8.0f)
            {
                float x2 = x * x;
                return x/2.0f - x*x2/16.0f + x*x2*x2/384.0f - x*x2*x2*x2/18432.0f;
            };
            float s = (x > 0.0f) ? 1.0f : -1.0f;
            return s * sqrt(2.0f/(PIF*abs(x))) * sin(x - PIF/4.0f);
        };
        def besselj1(double x) -> double
        {
            if (abs(x) < 8.0)
            {
                double x2 = x * x;
                return x/2.0 - x*x2/16.0 + x*x2*x2/384.0 - x*x2*x2*x2/18432.0;
            };
            double s = (x > 0.0) ? 1.0 : -1.0;
            return s * sqrt(2.0/(PID*abs(x))) * sin(x - PID/4.0);
        };
        def besseljn(int n, float x) -> float
        {
            if (n == 0) { return besselj0(x); };
            if (n == 1) { return besselj1(x); };
            float j0 = besselj0(x), j1 = besselj1(x), jn;
            for (int i = 1; i < n; i++)
            {
                jn = 2.0f * (float)i / x * j1 - j0;
                j0 = j1;
                j1 = jn;
            };
            return jn;
        };
        def besseljn(int n, double x) -> double
        {
            if (n == 0) { return besselj0(x); };
            if (n == 1) { return besselj1(x); };
            double j0 = besselj0(x), j1 = besselj1(x), jn;
            for (int i = 1; i < n; i++)
            {
                jn = 2.0 * (double)i / x * j1 - j0;
                j0 = j1;
                j1 = jn;
            };
            return jn;
        };

        // ---------- Bessel functions (second kind) ----------
        // Y0(x) = (2/pi) * [ln(x/2) + gamma] * J0(x) - (correction series)
        // The correction series is omitted here (same approximation order as J0 above).
        // besselj0 is called once and reused.
        def bessely0(float x) -> float
        {
            if (x <= 0.0f) { return NAN_F; };
            if (x < 8.0f)
            {
                float j0 = besselj0(x);
                return (2.0f/PIF) * (log(x/2.0f) + (float)_EULER_MASCHERONI) * j0;
            };
            return sqrt(2.0f/(PIF*x)) * sin(x - PIF/4.0f);
        };
        def bessely0(double x) -> double
        {
            if (x <= 0.0) { return NAN_D; };
            if (x < 8.0)
            {
                double j0 = besselj0(x);
                return (2.0/PID) * (log(x/2.0) + _EULER_MASCHERONI) * j0;
            };
            return sqrt(2.0/(PID*x)) * sin(x - PID/4.0);
        };
        def bessely1(float x) -> float
        {
            if (x <= 0.0f) { return NAN_F; };
            if (x < 8.0f)
            {
                float j1 = besselj1(x);
                return (2.0f/PIF) * (log(x/2.0f) + (float)_EULER_MASCHERONI) * j1;
            };
            return sqrt(2.0f/(PIF*x)) * cos(x - PIF/4.0f);
        };
        def bessely1(double x) -> double
        {
            if (x <= 0.0) { return NAN_D; };
            if (x < 8.0)
            {
                double j1 = besselj1(x);
                return (2.0/PID) * (log(x/2.0) + _EULER_MASCHERONI) * j1;
            };
            return sqrt(2.0/(PID*x)) * cos(x - PID/4.0);
        };
        def besselyn(int n, float x) -> float
        {
            if (n == 0) { return bessely0(x); };
            if (n == 1) { return bessely1(x); };
            float y0 = bessely0(x), y1 = bessely1(x), yn;
            for (int i = 1; i < n; i++)
            {
                yn = 2.0f * (float)i / x * y1 - y0;
                y0 = y1;
                y1 = yn;
            };
            return yn;
        };
        def besselyn(int n, double x) -> double
        {
            if (n == 0) { return bessely0(x); };
            if (n == 1) { return bessely1(x); };
            double y0 = bessely0(x), y1 = bessely1(x), yn;
            for (int i = 1; i < n; i++)
            {
                yn = 2.0 * (double)i / x * y1 - y0;
                y0 = y1;
                y1 = yn;
            };
            return yn;
        };

        // ---------- Integer overflow helpers ----------
        inline def add_overflow(i64 a, i64 b, i64* result) -> bool
        {
            *result = a + b;
            return ((a > 0) & (b > 0) & (*result < 0)) | ((a < 0) & (b < 0) & (*result > 0));
        };
        inline def mul_overflow(i64 a, i64 b, i64* result) -> bool
        {
            *result = a * b;
            if (a == 0 | b == 0) { return false; };
            return (*result / a != b);
        };
        inline def is_power_of_two(i64 x) -> bool
        {
            return (x > 0) & ((x & (x - 1)) == 0);
        };
        def next_power_of_two(i64 x) -> i64
        {
            if (x <= 0) { return 1; };
            i64 v = x - 1;
            v = v | (v >> 1);
            v = v | (v >> 2);
            v = v | (v >> 4);
            v = v | (v >> 8);
            v = v | (v >> 16);
            v = v | (v >> 32);
            return v + 1;
        };

        // ---------- Complex arithmetic ----------
        inline def complex_add(Complex a, Complex b) -> Complex
        {
            Complex c;
            c.re = a.re + b.re;
            c.im = a.im + b.im;
            return c;
        };
        inline def complex_sub(Complex a, Complex b) -> Complex
        {
            Complex c;
            c.re = a.re - b.re;
            c.im = a.im - b.im;
            return c;
        };
        inline def complex_mul(Complex a, Complex b) -> Complex
        {
            Complex c;
            c.re = a.re * b.re - a.im * b.im;
            c.im = a.re * b.im + a.im * b.re;
            return c;
        };
        inline def complex_div(Complex a, Complex b) -> Complex
        {
            double denom = b.re * b.re + b.im * b.im;
            Complex c;
            c.re = (a.re * b.re + a.im * b.im) / denom;
            c.im = (a.im * b.re - a.re * b.im) / denom;
            return c;
        };
        inline def complex_abs(Complex z) -> double   { return sqrt(z.re * z.re + z.im * z.im); };
        inline def complex_phase(Complex z) -> double { return atan2(z.im, z.re); };
        inline def complex_conj(Complex z) -> Complex
        {
            Complex c;
            c.re = z.re;
            c.im = -z.im;
            return c;
        };
        def complex_exp(Complex z) -> Complex
        {
            double r = exp(z.re);
            Complex c;
            c.re = r * cos(z.im);
            c.im = r * sin(z.im);
            return c;
        };
        inline def complex_log(Complex z) -> Complex
        {
            Complex c;
            c.re = log(complex_abs(z));
            c.im = complex_phase(z);
            return c;
        };
        def complex_pow(Complex z, double p) -> Complex
        {
            Complex logz = complex_log(z);
            logz.re = logz.re * p;
            logz.im = logz.im * p;
            return complex_exp(logz);
        };
    };
};

#endif;
