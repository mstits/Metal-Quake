# 1 "test.c"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 465 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "test.c" 2
# 1 "WinQuake/quakedef.h" 1
# 41 "WinQuake/quakedef.h"
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/math.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/math.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/cdefs.h" 1 3 4
# 782 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/cdefs.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_symbol_aliasing.h" 1 3 4
# 783 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/cdefs.h" 2 3 4
# 848 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/cdefs.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_posix_availability.h" 1 3 4
# 849 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/cdefs.h" 2 3 4
# 966 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/cdefs.h" 3 4
# 1 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/ptrcheck.h" 1 3 4
# 967 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/cdefs.h" 2 3 4
# 32 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/math.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 196 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/AvailabilityVersions.h" 1 3 4
# 197 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/AvailabilityInternal.h" 1 3 4
# 33 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/AvailabilityInternal.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/AvailabilityVersions.h" 1 3 4
# 34 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/AvailabilityInternal.h" 2 3 4
# 198 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/AvailabilityInternalLegacy.h" 1 3 4
# 34 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/AvailabilityInternalLegacy.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/AvailabilityInternal.h" 1 3 4
# 35 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/AvailabilityInternalLegacy.h" 2 3 4
# 199 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 2 3 4
# 33 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/math.h" 2 3 4
# 50 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/math.h" 3 4
    typedef float float_t;
    typedef double double_t;
# 117 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/math.h" 3 4
extern int __math_errhandling(void);
# 137 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/math.h" 3 4
extern int __fpclassifyf(float);
extern int __fpclassifyd(double);
extern int __fpclassifyl(long double);
# 180 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/math.h" 3 4
inline __attribute__ ((__always_inline__)) int __inline_isfinitef(float);
inline __attribute__ ((__always_inline__)) int __inline_isfinited(double);
inline __attribute__ ((__always_inline__)) int __inline_isfinitel(long double);
inline __attribute__ ((__always_inline__)) int __inline_isinff(float);
inline __attribute__ ((__always_inline__)) int __inline_isinfd(double);
inline __attribute__ ((__always_inline__)) int __inline_isinfl(long double);
inline __attribute__ ((__always_inline__)) int __inline_isnanf(float);
inline __attribute__ ((__always_inline__)) int __inline_isnand(double);
inline __attribute__ ((__always_inline__)) int __inline_isnanl(long double);
inline __attribute__ ((__always_inline__)) int __inline_isnormalf(float);
inline __attribute__ ((__always_inline__)) int __inline_isnormald(double);
inline __attribute__ ((__always_inline__)) int __inline_isnormall(long double);
inline __attribute__ ((__always_inline__)) int __inline_signbitf(float);
inline __attribute__ ((__always_inline__)) int __inline_signbitd(double);
inline __attribute__ ((__always_inline__)) int __inline_signbitl(long double);

inline __attribute__ ((__always_inline__)) int __inline_isfinitef(float __x) {
    return __x == __x && __builtin_fabsf(__x) != __builtin_inff();
}
inline __attribute__ ((__always_inline__)) int __inline_isfinited(double __x) {
    return __x == __x && __builtin_fabs(__x) != __builtin_inf();
}
inline __attribute__ ((__always_inline__)) int __inline_isfinitel(long double __x) {
    return __x == __x && __builtin_fabsl(__x) != __builtin_infl();
}
inline __attribute__ ((__always_inline__)) int __inline_isinff(float __x) {
    return __builtin_fabsf(__x) == __builtin_inff();
}
inline __attribute__ ((__always_inline__)) int __inline_isinfd(double __x) {
    return __builtin_fabs(__x) == __builtin_inf();
}
inline __attribute__ ((__always_inline__)) int __inline_isinfl(long double __x) {
    return __builtin_fabsl(__x) == __builtin_infl();
}
inline __attribute__ ((__always_inline__)) int __inline_isnanf(float __x) {
    return __x != __x;
}
inline __attribute__ ((__always_inline__)) int __inline_isnand(double __x) {
    return __x != __x;
}
inline __attribute__ ((__always_inline__)) int __inline_isnanl(long double __x) {
    return __x != __x;
}
inline __attribute__ ((__always_inline__)) int __inline_signbitf(float __x) {
    union { float __f; unsigned int __u; } __u;
    __u.__f = __x;
    return (int)(__u.__u >> 31);
}
inline __attribute__ ((__always_inline__)) int __inline_signbitd(double __x) {
    union { double __f; unsigned long long __u; } __u;
    __u.__f = __x;
    return (int)(__u.__u >> 63);
}
# 243 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/math.h" 3 4
inline __attribute__ ((__always_inline__)) int __inline_signbitl(long double __x) {
    union { long double __f; unsigned long long __u;} __u;
    __u.__f = __x;
    return (int)(__u.__u >> 63);
}

inline __attribute__ ((__always_inline__)) int __inline_isnormalf(float __x) {
    return __inline_isfinitef(__x) && __builtin_fabsf(__x) >= 1.17549435e-38F;
}
inline __attribute__ ((__always_inline__)) int __inline_isnormald(double __x) {
    return __inline_isfinited(__x) && __builtin_fabs(__x) >= 2.2250738585072014e-308;
}
inline __attribute__ ((__always_inline__)) int __inline_isnormall(long double __x) {
    return __inline_isfinitel(__x) && __builtin_fabsl(__x) >= 2.2250738585072014e-308L;
}
# 314 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/math.h" 3 4
extern float acosf(float);
extern double acos(double);
extern long double acosl(long double);

extern float asinf(float);
extern double asin(double);
extern long double asinl(long double);

extern float atanf(float);
extern double atan(double);
extern long double atanl(long double);

extern float atan2f(float, float);
extern double atan2(double, double);
extern long double atan2l(long double, long double);

extern float cosf(float);
extern double cos(double);
extern long double cosl(long double);

extern float sinf(float);
extern double sin(double);
extern long double sinl(long double);

extern float tanf(float);
extern double tan(double);
extern long double tanl(long double);

extern float acoshf(float);
extern double acosh(double);
extern long double acoshl(long double);

extern float asinhf(float);
extern double asinh(double);
extern long double asinhl(long double);

extern float atanhf(float);
extern double atanh(double);
extern long double atanhl(long double);

extern float coshf(float);
extern double cosh(double);
extern long double coshl(long double);

extern float sinhf(float);
extern double sinh(double);
extern long double sinhl(long double);

extern float tanhf(float);
extern double tanh(double);
extern long double tanhl(long double);

extern float expf(float);
extern double exp(double);
extern long double expl(long double);

extern float exp2f(float);
extern double exp2(double);
extern long double exp2l(long double);

extern float expm1f(float);
extern double expm1(double);
extern long double expm1l(long double);

extern float logf(float);
extern double log(double);
extern long double logl(long double);

extern float log10f(float);
extern double log10(double);
extern long double log10l(long double);

extern float log2f(float);
extern double log2(double);
extern long double log2l(long double);

extern float log1pf(float);
extern double log1p(double);
extern long double log1pl(long double);

extern float logbf(float);
extern double logb(double);
extern long double logbl(long double);

extern float modff(float, float *);
extern double modf(double, double *);
extern long double modfl(long double, long double *);

extern float ldexpf(float, int);
extern double ldexp(double, int);
extern long double ldexpl(long double, int);

extern float frexpf(float, int *);
extern double frexp(double, int *);
extern long double frexpl(long double, int *);

extern int ilogbf(float);
extern int ilogb(double);
extern int ilogbl(long double);

extern float scalbnf(float, int);
extern double scalbn(double, int);
extern long double scalbnl(long double, int);

extern float scalblnf(float, long int);
extern double scalbln(double, long int);
extern long double scalblnl(long double, long int);

extern float fabsf(float);
extern double fabs(double);
extern long double fabsl(long double);

extern float cbrtf(float);
extern double cbrt(double);
extern long double cbrtl(long double);

extern float hypotf(float, float);
extern double hypot(double, double);
extern long double hypotl(long double, long double);

extern float powf(float, float);
extern double pow(double, double);
extern long double powl(long double, long double);

extern float sqrtf(float);
extern double sqrt(double);
extern long double sqrtl(long double);

extern float erff(float);
extern double erf(double);
extern long double erfl(long double);

extern float erfcf(float);
extern double erfc(double);
extern long double erfcl(long double);




extern float lgammaf(float);
extern double lgamma(double);
extern long double lgammal(long double);

extern float tgammaf(float);
extern double tgamma(double);
extern long double tgammal(long double);

extern float ceilf(float);
extern double ceil(double);
extern long double ceill(long double);

extern float floorf(float);
extern double floor(double);
extern long double floorl(long double);

extern float nearbyintf(float);
extern double nearbyint(double);
extern long double nearbyintl(long double);

extern float rintf(float);
extern double rint(double);
extern long double rintl(long double);

extern long int lrintf(float);
extern long int lrint(double);
extern long int lrintl(long double);

extern float roundf(float);
extern double round(double);
extern long double roundl(long double);

extern long int lroundf(float);
extern long int lround(double);
extern long int lroundl(long double);




extern long long int llrintf(float);
extern long long int llrint(double);
extern long long int llrintl(long double);

extern long long int llroundf(float);
extern long long int llround(double);
extern long long int llroundl(long double);


extern float truncf(float);
extern double trunc(double);
extern long double truncl(long double);

extern float fmodf(float, float);
extern double fmod(double, double);
extern long double fmodl(long double, long double);

extern float remainderf(float, float);
extern double remainder(double, double);
extern long double remainderl(long double, long double);

extern float remquof(float, float, int *);
extern double remquo(double, double, int *);
extern long double remquol(long double, long double, int *);

extern float copysignf(float, float);
extern double copysign(double, double);
extern long double copysignl(long double, long double);

extern float nanf(const char *);
extern double nan(const char *);
extern long double nanl(const char *);

extern float nextafterf(float, float);
extern double nextafter(double, double);
extern long double nextafterl(long double, long double);

extern double nexttoward(double, long double);
extern float nexttowardf(float, long double);
extern long double nexttowardl(long double, long double);

extern float fdimf(float, float);
extern double fdim(double, double);
extern long double fdiml(long double, long double);

extern float fmaxf(float, float);
extern double fmax(double, double);
extern long double fmaxl(long double, long double);

extern float fminf(float, float);
extern double fmin(double, double);
extern long double fminl(long double, long double);

extern float fmaf(float, float, float);
extern double fma(double, double, double);
extern long double fmal(long double, long double, long double);
# 594 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/math.h" 3 4
extern float __exp10f(float) __attribute__((availability(macos,introduced=10.9))) __attribute__((availability(ios,introduced=7.0)));
extern double __exp10(double) __attribute__((availability(macos,introduced=10.9))) __attribute__((availability(ios,introduced=7.0)));





inline __attribute__ ((__always_inline__)) void __sincosf(float __x, float *__sinp, float *__cosp);
inline __attribute__ ((__always_inline__)) void __sincos(double __x, double *__sinp, double *__cosp);
# 611 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/math.h" 3 4
extern float __cospif(float) __attribute__((availability(macos,introduced=10.9))) __attribute__((availability(ios,introduced=7.0)));
extern double __cospi(double) __attribute__((availability(macos,introduced=10.9))) __attribute__((availability(ios,introduced=7.0)));
extern float __sinpif(float) __attribute__((availability(macos,introduced=10.9))) __attribute__((availability(ios,introduced=7.0)));
extern double __sinpi(double) __attribute__((availability(macos,introduced=10.9))) __attribute__((availability(ios,introduced=7.0)));
extern float __tanpif(float) __attribute__((availability(macos,introduced=10.9))) __attribute__((availability(ios,introduced=7.0)));
extern double __tanpi(double) __attribute__((availability(macos,introduced=10.9))) __attribute__((availability(ios,introduced=7.0)));


extern _Float16 __fabsf16(_Float16) __attribute__((availability(macos,introduced=15.0))) __attribute__((availability(ios,introduced=18.0))) __attribute__((availability(watchos,introduced=11.0))) __attribute__((availability(tvos,introduced=18.0)));
extern _Float16 __hypotf16(_Float16, _Float16) __attribute__((availability(macos,introduced=15.0))) __attribute__((availability(ios,introduced=18.0))) __attribute__((availability(watchos,introduced=11.0))) __attribute__((availability(tvos,introduced=18.0)));
extern _Float16 __sqrtf16(_Float16) __attribute__((availability(macos,introduced=15.0))) __attribute__((availability(ios,introduced=18.0))) __attribute__((availability(watchos,introduced=11.0))) __attribute__((availability(tvos,introduced=18.0)));
extern _Float16 __ceilf16(_Float16) __attribute__((availability(macos,introduced=15.0))) __attribute__((availability(ios,introduced=18.0))) __attribute__((availability(watchos,introduced=11.0))) __attribute__((availability(tvos,introduced=18.0)));
extern _Float16 __floorf16(_Float16) __attribute__((availability(macos,introduced=15.0))) __attribute__((availability(ios,introduced=18.0))) __attribute__((availability(watchos,introduced=11.0))) __attribute__((availability(tvos,introduced=18.0)));
extern _Float16 __rintf16(_Float16) __attribute__((availability(macos,introduced=15.0))) __attribute__((availability(ios,introduced=18.0))) __attribute__((availability(watchos,introduced=11.0))) __attribute__((availability(tvos,introduced=18.0)));
extern _Float16 __roundf16(_Float16) __attribute__((availability(macos,introduced=15.0))) __attribute__((availability(ios,introduced=18.0))) __attribute__((availability(watchos,introduced=11.0))) __attribute__((availability(tvos,introduced=18.0)));
extern _Float16 __truncf16(_Float16) __attribute__((availability(macos,introduced=15.0))) __attribute__((availability(ios,introduced=18.0))) __attribute__((availability(watchos,introduced=11.0))) __attribute__((availability(tvos,introduced=18.0)));
extern _Float16 __copysignf16(_Float16, _Float16) __attribute__((availability(macos,introduced=15.0))) __attribute__((availability(ios,introduced=18.0))) __attribute__((availability(watchos,introduced=11.0))) __attribute__((availability(tvos,introduced=18.0)));
extern _Float16 __nextafterf16(_Float16, _Float16) __attribute__((availability(macos,introduced=15.0))) __attribute__((availability(ios,introduced=18.0))) __attribute__((availability(watchos,introduced=11.0))) __attribute__((availability(tvos,introduced=18.0)));
extern _Float16 __fmaxf16(_Float16, _Float16) __attribute__((availability(macos,introduced=15.0))) __attribute__((availability(ios,introduced=18.0))) __attribute__((availability(watchos,introduced=11.0))) __attribute__((availability(tvos,introduced=18.0)));
extern _Float16 __fminf16(_Float16, _Float16) __attribute__((availability(macos,introduced=15.0))) __attribute__((availability(ios,introduced=18.0))) __attribute__((availability(watchos,introduced=11.0))) __attribute__((availability(tvos,introduced=18.0)));
extern _Float16 __fmaf16(_Float16, _Float16, _Float16) __attribute__((availability(macos,introduced=15.0))) __attribute__((availability(ios,introduced=18.0))) __attribute__((availability(watchos,introduced=11.0))) __attribute__((availability(tvos,introduced=18.0)));
# 657 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/math.h" 3 4
inline __attribute__ ((__always_inline__)) void __sincospif(float __x, float *__sinp, float *__cosp);
inline __attribute__ ((__always_inline__)) void __sincospi(double __x, double *__sinp, double *__cosp);






struct __float2 { float __sinval; float __cosval; };
struct __double2 { double __sinval; double __cosval; };

extern struct __float2 __sincosf_stret(float);
extern struct __double2 __sincos_stret(double);
extern struct __float2 __sincospif_stret(float);
extern struct __double2 __sincospi_stret(double);

inline __attribute__ ((__always_inline__)) void __sincosf(float __x, float *__sinp, float *__cosp) {
    const struct __float2 __stret = __sincosf_stret(__x);
    *__sinp = __stret.__sinval; *__cosp = __stret.__cosval;
}

inline __attribute__ ((__always_inline__)) void __sincos(double __x, double *__sinp, double *__cosp) {
    const struct __double2 __stret = __sincos_stret(__x);
    *__sinp = __stret.__sinval; *__cosp = __stret.__cosval;
}

inline __attribute__ ((__always_inline__)) void __sincospif(float __x, float *__sinp, float *__cosp) {
    const struct __float2 __stret = __sincospif_stret(__x);
    *__sinp = __stret.__sinval; *__cosp = __stret.__cosval;
}

inline __attribute__ ((__always_inline__)) void __sincospi(double __x, double *__sinp, double *__cosp) {
    const struct __double2 __stret = __sincospi_stret(__x);
    *__sinp = __stret.__sinval; *__cosp = __stret.__cosval;
}







extern double j0(double) __attribute__((availability(macos,introduced=10.0))) __attribute__((availability(ios,introduced=3.2)));
extern double j1(double) __attribute__((availability(macos,introduced=10.0))) __attribute__((availability(ios,introduced=3.2)));
extern double jn(int, double) __attribute__((availability(macos,introduced=10.0))) __attribute__((availability(ios,introduced=3.2)));
extern double y0(double) __attribute__((availability(macos,introduced=10.0))) __attribute__((availability(ios,introduced=3.2)));
extern double y1(double) __attribute__((availability(macos,introduced=10.0))) __attribute__((availability(ios,introduced=3.2)));
extern double yn(int, double) __attribute__((availability(macos,introduced=10.0))) __attribute__((availability(ios,introduced=3.2)));
extern double scalb(double, double);
extern int signgam;
# 784 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/math.h" 3 4
struct exception {
    int type;
    char *name;
    double arg1;
    double arg2;
    double retval;
};
# 42 "WinQuake/quakedef.h" 2
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/setjmp.h" 1 3 4
# 27 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/setjmp.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 28 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/setjmp.h" 2 3 4
# 79 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/setjmp.h" 3 4
typedef int jmp_buf[((14 + 8 + 2) * 2)];
typedef int sigjmp_buf[((14 + 8 + 2) * 2) + 1];






extern int setjmp(jmp_buf);
extern void longjmp(jmp_buf, int) __attribute__((__noreturn__));


int _setjmp(jmp_buf);
void _longjmp(jmp_buf, int) __attribute__((__noreturn__));
int sigsetjmp(sigjmp_buf, int);
void siglongjmp(sigjmp_buf, int) __attribute__((__noreturn__));



void longjmperror(void);
# 43 "WinQuake/quakedef.h" 2
# 1 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/stdarg.h" 1 3
# 47 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/stdarg.h" 3
# 1 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/__stdarg_header_macro.h" 1 3
# 48 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/stdarg.h" 2 3



# 1 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/__stdarg___gnuc_va_list.h" 1 3
# 12 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/__stdarg___gnuc_va_list.h" 3
typedef __builtin_va_list __gnuc_va_list;
# 52 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/stdarg.h" 2 3




# 1 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/__stdarg_va_list.h" 1 3
# 12 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/__stdarg_va_list.h" 3
typedef __builtin_va_list va_list;
# 57 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/stdarg.h" 2 3




# 1 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/__stdarg_va_arg.h" 1 3
# 62 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/stdarg.h" 2 3




# 1 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/__stdarg___va_copy.h" 1 3
# 67 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/stdarg.h" 2 3




# 1 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/__stdarg_va_copy.h" 1 3
# 72 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/stdarg.h" 2 3
# 44 "WinQuake/quakedef.h" 2
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/stdio.h" 1 3 4
# 61 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/stdio.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 1 3 4
# 69 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_bounds.h" 1 3 4
# 70 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 2 3 4

# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 72 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 2 3 4

# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_types.h" 1 3 4
# 27 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_types.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types.h" 1 3 4
# 33 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/machine/_types.h" 1 3 4
# 34 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/machine/_types.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/_types.h" 1 3 4
# 28 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/_types.h" 3 4
typedef signed char __int8_t;



typedef unsigned char __uint8_t;
typedef short __int16_t;
typedef unsigned short __uint16_t;
typedef int __int32_t;
typedef unsigned int __uint32_t;
typedef long long __int64_t;
typedef unsigned long long __uint64_t;

typedef long __darwin_intptr_t;
typedef unsigned int __darwin_natural_t;
# 61 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/_types.h" 3 4
typedef int __darwin_ct_rune_t;





typedef union {
 char __mbstate8[128];
 long long _mbstateL;
} __mbstate_t;

typedef __mbstate_t __darwin_mbstate_t;




typedef long int __darwin_ptrdiff_t;
# 87 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/_types.h" 3 4
typedef long unsigned int __darwin_size_t;







typedef __builtin_va_list __darwin_va_list;







typedef int __darwin_wchar_t;




typedef __darwin_wchar_t __darwin_rune_t;


typedef int __darwin_wint_t;




typedef unsigned long __darwin_clock_t;
typedef __uint32_t __darwin_socklen_t;
typedef long __darwin_ssize_t;
typedef long __darwin_time_t;
# 35 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/machine/_types.h" 2 3 4
# 34 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types.h" 2 3 4
# 67 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types.h" 3 4
typedef __int64_t __darwin_blkcnt_t;
typedef __int32_t __darwin_blksize_t;
typedef __int32_t __darwin_dev_t;
typedef unsigned int __darwin_fsblkcnt_t;
typedef unsigned int __darwin_fsfilcnt_t;
typedef __uint32_t __darwin_gid_t;
typedef __uint32_t __darwin_id_t;
typedef __uint64_t __darwin_ino64_t;

typedef __darwin_ino64_t __darwin_ino_t;



typedef __darwin_natural_t __darwin_mach_port_name_t;
typedef __darwin_mach_port_name_t __darwin_mach_port_t;
typedef __uint16_t __darwin_mode_t;
typedef __int64_t __darwin_off_t;
typedef __int32_t __darwin_pid_t;
typedef __uint32_t __darwin_sigset_t;
typedef __int32_t __darwin_suseconds_t;
typedef __uint32_t __darwin_uid_t;
typedef __uint32_t __darwin_useconds_t;
typedef unsigned char __darwin_uuid_t[16];
typedef char __darwin_uuid_string_t[37];



# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_pthread/_pthread_types.h" 1 3 4
# 57 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_pthread/_pthread_types.h" 3 4
struct __darwin_pthread_handler_rec {
 void (*__routine)(void *);
 void *__arg;
 struct __darwin_pthread_handler_rec *__next;
};

struct _opaque_pthread_attr_t {
 long __sig;
 char __opaque[56];
};

struct _opaque_pthread_cond_t {
 long __sig;
 char __opaque[40];
};

struct _opaque_pthread_condattr_t {
 long __sig;
 char __opaque[8];
};

struct _opaque_pthread_mutex_t {
 long __sig;
 char __opaque[56];
};

struct _opaque_pthread_mutexattr_t {
 long __sig;
 char __opaque[8];
};

struct _opaque_pthread_once_t {
 long __sig;
 char __opaque[8];
};

struct _opaque_pthread_rwlock_t {
 long __sig;
 char __opaque[192];
};

struct _opaque_pthread_rwlockattr_t {
 long __sig;
 char __opaque[16];
};

struct _opaque_pthread_t {
 long __sig;
 struct __darwin_pthread_handler_rec *__cleanup_stack;
 char __opaque[8176];
};

typedef struct _opaque_pthread_attr_t __darwin_pthread_attr_t;
typedef struct _opaque_pthread_cond_t __darwin_pthread_cond_t;
typedef struct _opaque_pthread_condattr_t __darwin_pthread_condattr_t;
typedef unsigned long __darwin_pthread_key_t;
typedef struct _opaque_pthread_mutex_t __darwin_pthread_mutex_t;
typedef struct _opaque_pthread_mutexattr_t __darwin_pthread_mutexattr_t;
typedef struct _opaque_pthread_once_t __darwin_pthread_once_t;
typedef struct _opaque_pthread_rwlock_t __darwin_pthread_rwlock_t;
typedef struct _opaque_pthread_rwlockattr_t __darwin_pthread_rwlockattr_t;
typedef struct _opaque_pthread_t *__darwin_pthread_t;
# 95 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types.h" 2 3 4
# 28 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_types.h" 2 3 4
# 43 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_types.h" 3 4
typedef int __darwin_nl_item;
typedef int __darwin_wctrans_t;

typedef __uint32_t __darwin_wctype_t;
# 74 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 2 3 4



# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_va_list.h" 1 3 4
# 43 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_va_list.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/machine/types.h" 1 3 4
# 37 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/machine/types.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/types.h" 1 3 4
# 55 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/types.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_int8_t.h" 1 3 4
# 30 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_int8_t.h" 3 4
typedef signed char int8_t;
# 56 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/types.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_int16_t.h" 1 3 4
# 30 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_int16_t.h" 3 4
typedef short int16_t;
# 57 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/types.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_int32_t.h" 1 3 4
# 30 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_int32_t.h" 3 4
typedef int int32_t;
# 58 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/types.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_int64_t.h" 1 3 4
# 30 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_int64_t.h" 3 4
typedef long long int64_t;
# 59 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/types.h" 2 3 4

# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_u_int8_t.h" 1 3 4
# 30 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_u_int8_t.h" 3 4
typedef unsigned char u_int8_t;
# 61 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/types.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_u_int16_t.h" 1 3 4
# 30 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_u_int16_t.h" 3 4
typedef unsigned short u_int16_t;
# 62 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/types.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_u_int32_t.h" 1 3 4
# 30 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_u_int32_t.h" 3 4
typedef unsigned int u_int32_t;
# 63 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/types.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_u_int64_t.h" 1 3 4
# 30 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_u_int64_t.h" 3 4
typedef unsigned long long u_int64_t;
# 64 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/types.h" 2 3 4


typedef int64_t register_t;




# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_intptr_t.h" 1 3 4
# 32 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_intptr_t.h" 3 4
typedef __darwin_intptr_t intptr_t;
# 72 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/types.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_uintptr_t.h" 1 3 4
# 34 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_uintptr_t.h" 3 4
typedef unsigned long uintptr_t;
# 73 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/types.h" 2 3 4




typedef u_int64_t user_addr_t;
typedef u_int64_t user_size_t;
typedef int64_t user_ssize_t;
typedef int64_t user_long_t;
typedef u_int64_t user_ulong_t;
typedef int64_t user_time_t;
typedef int64_t user_off_t;
# 105 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/types.h" 3 4
typedef u_int64_t syscall_arg_t;
# 38 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/machine/types.h" 2 3 4
# 44 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_va_list.h" 2 3 4
typedef __darwin_va_list va_list;
# 78 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_size_t.h" 1 3 4
# 50 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_size_t.h" 3 4
typedef __darwin_size_t size_t;
# 79 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_null.h" 1 3 4
# 80 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 2 3 4

# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/stdio.h" 1 3 4
# 43 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/stdio.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 44 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/stdio.h" 2 3 4



int renameat(int, const char *, int, const char *) __attribute__((availability(macosx,introduced=10.10)));



int renamex_np(const char *, const char *, unsigned int) __attribute__((availability(macosx,introduced=10.12))) __attribute__((availability(ios,introduced=10.0))) __attribute__((availability(tvos,introduced=10.0))) __attribute__((availability(watchos,introduced=3.0)));
int renameatx_np(int, const char *, int, const char *, unsigned int) __attribute__((availability(macosx,introduced=10.12))) __attribute__((availability(ios,introduced=10.0))) __attribute__((availability(tvos,introduced=10.0))) __attribute__((availability(watchos,introduced=3.0)));
# 82 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_printf.h" 1 3 4
# 34 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_printf.h" 3 4
int printf(const char * restrict, ...) __attribute__((__format__ (__printf__, 1, 2)));
# 83 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 2 3 4



typedef __darwin_off_t fpos_t;
# 97 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 3 4
struct __sbuf {
 unsigned char * _base;
 int _size;
};


struct __sFILEX;
# 131 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 3 4
typedef struct __sFILE {
 unsigned char * _p;
 int _r;
 int _w;
 short _flags;
 short _file;
 struct __sbuf _bf;
 int _lbfsize;


 void *_cookie;
 int (* _Nullable _close)(void *);
 int (* _Nullable _read) (void *, char *, int __n);
 fpos_t (* _Nullable _seek) (void *, fpos_t, int);
 int (* _Nullable _write)(void *, const char *, int __n);


 struct __sbuf _ub;
 struct __sFILEX *_extra;
 int _ur;


 unsigned char _ubuf[3];
 unsigned char _nbuf[1];


 struct __sbuf _lb;


 int _blksize;
 fpos_t _offset;
} FILE;

# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_seek_set.h" 1 3 4
# 165 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 2 3 4


extern FILE *__stdinp __attribute__((__swift_attr__("nonisolated(unsafe)")));
extern FILE *__stdoutp __attribute__((__swift_attr__("nonisolated(unsafe)")));
extern FILE *__stderrp __attribute__((__swift_attr__("nonisolated(unsafe)")));
# 232 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 3 4
void clearerr(FILE *);
int fclose(FILE *);
int feof(FILE *);
int ferror(FILE *);
int fflush(FILE *);
int fgetc(FILE *);
int fgetpos(FILE * restrict, fpos_t *);
char * fgets(char * restrict , int __size, FILE *);



FILE *fopen(const char * restrict __filename, const char * restrict __mode) __asm("_" "fopen" );

int fprintf(FILE * restrict, const char * restrict, ...) __attribute__((__format__ (__printf__, 2, 3)));
int fputc(int, FILE *);
int fputs(const char * restrict, FILE * restrict) __asm("_" "fputs" );
size_t fread(void * restrict __ptr, size_t __size, size_t __nitems, FILE * restrict __stream);
FILE *freopen(const char * restrict, const char * restrict,
     FILE * restrict) __asm("_" "freopen" );
int fscanf(FILE * restrict, const char * restrict, ...) __attribute__((__format__ (__scanf__, 2, 3)));
int fseek(FILE *, long, int);
int fsetpos(FILE *, const fpos_t *);
long ftell(FILE *);
size_t fwrite(const void * restrict __ptr, size_t __size, size_t __nitems, FILE * restrict __stream) __asm("_" "fwrite" );
int getc(FILE *);
int getchar(void);


__attribute__((__deprecated__("This function is provided for compatibility reasons only.  Due to security concerns inherent in the design of gets(3), it is highly recommended that you use fgets(3) instead.")))

char * gets(char *) ;

void perror(const char *) __attribute__((__cold__));
int putc(int, FILE *);
int putchar(int);
int puts(const char *);
int remove(const char *);
int rename (const char *__old, const char *__new);
void rewind(FILE *);
int scanf(const char * restrict, ...) __attribute__((__format__ (__scanf__, 1, 2)));
void setbuf(FILE * restrict, char * restrict );
int setvbuf(FILE * restrict, char * restrict , int, size_t __size);

__attribute__((__availability__(swift, unavailable, message="Use snprintf instead.")))


__attribute__((__deprecated__("This function is provided for compatibility reasons only.  Due to security concerns inherent in the design of sprintf(3), it is highly recommended that you use snprintf(3) instead.")))

int sprintf(char * restrict , const char * restrict, ...) __attribute__((__format__ (__printf__, 2, 3))) ;

int sscanf(const char * restrict, const char * restrict, ...) __attribute__((__format__ (__scanf__, 2, 3)));
FILE *tmpfile(void);

__attribute__((__availability__(swift, unavailable, message="Use mkstemp(3) instead.")))

__attribute__((__deprecated__("This function is provided for compatibility reasons only.  Due to security concerns inherent in the design of tmpnam(3), it is highly recommended that you use mkstemp(3) instead.")))

char * tmpnam(char *);

int ungetc(int, FILE *);
int vfprintf(FILE * restrict, const char * restrict, va_list) __attribute__((__format__ (__printf__, 2, 0)));
int vprintf(const char * restrict, va_list) __attribute__((__format__ (__printf__, 1, 0)));

__attribute__((__availability__(swift, unavailable, message="Use vsnprintf instead.")))


__attribute__((__deprecated__("This function is provided for compatibility reasons only.  Due to security concerns inherent in the design of sprintf(3), it is highly recommended that you use vsnprintf(3) instead.")))

int vsprintf(char * restrict , const char * restrict, va_list) __attribute__((__format__ (__printf__, 2, 0))) ;
# 311 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_ctermid.h" 1 3 4
# 36 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_ctermid.h" 3 4
char * ctermid(char *);
# 312 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 2 3 4






FILE *fdopen(int, const char *) __asm("_" "fdopen" );

int fileno(FILE *);
# 331 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 3 4
int pclose(FILE *) __attribute__((__availability__(swift, unavailable, message="Use posix_spawn APIs or NSTask instead. (On iOS, process spawning is unavailable.)")));



FILE *popen(const char *, const char *) __asm("_" "popen" ) __attribute__((__availability__(swift, unavailable, message="Use posix_spawn APIs or NSTask instead. (On iOS, process spawning is unavailable.)")));
# 350 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 3 4
int __srget(FILE *);
int __svfscanf(FILE *, const char *, va_list) __attribute__((__format__ (__scanf__, 2, 0)));
int __swbuf(int, FILE *);
# 361 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 3 4
inline __attribute__ ((__always_inline__)) int __sputc(int _c, FILE *_p) {
 if (--_p->_w >= 0 || (_p->_w >= _p->_lbfsize && (char)_c != '\n'))
  return (*_p->_p++ = _c);
 else
  return (__swbuf(_c, _p));
}
# 387 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 3 4
void flockfile(FILE *);
int ftrylockfile(FILE *);
void funlockfile(FILE *);
int getc_unlocked(FILE *);
int getchar_unlocked(void);
int putc_unlocked(int, FILE *);
int putchar_unlocked(int);



int getw(FILE *);
int putw(int, FILE *);


__attribute__((__availability__(swift, unavailable, message="Use mkstemp(3) instead.")))

__attribute__((__deprecated__("This function is provided for compatibility reasons only.  Due to security concerns inherent in the design of tempnam(3), it is highly recommended that you use mkstemp(3) instead.")))

char * tempnam(const char *__dir, const char *__prefix) __asm("_" "tempnam" );
# 425 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_off_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_off_t.h" 3 4
typedef __darwin_off_t off_t;
# 426 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 2 3 4


int fseeko(FILE * __stream, off_t __offset, int __whence);
off_t ftello(FILE * __stream);





int snprintf(char * restrict __str, size_t __size, const char * restrict __format, ...) __attribute__((__format__ (__printf__, 3, 4)));
int vfscanf(FILE * restrict __stream, const char * restrict __format, va_list) __attribute__((__format__ (__scanf__, 2, 0)));
int vscanf(const char * restrict __format, va_list) __attribute__((__format__ (__scanf__, 1, 0)));
int vsnprintf(char * restrict __str, size_t __size, const char * restrict __format, va_list) __attribute__((__format__ (__printf__, 3, 0)));
int vsscanf(const char * restrict __str, const char * restrict __format, va_list) __attribute__((__format__ (__scanf__, 2, 0)));
# 450 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_ssize_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_ssize_t.h" 3 4
typedef __darwin_ssize_t ssize_t;
# 451 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 2 3 4


int dprintf(int, const char * restrict, ...) __attribute__((__format__ (__printf__, 2, 3))) __attribute__((availability(macosx,introduced=10.7)));
int vdprintf(int, const char * restrict, va_list) __attribute__((__format__ (__printf__, 2, 0))) __attribute__((availability(macosx,introduced=10.7)));
ssize_t getdelim(char * *restrict __linep, size_t * restrict __linecapp, int __delimiter, FILE * restrict __stream) __attribute__((availability(macosx,introduced=10.7)));
ssize_t getline(char * *restrict __linep, size_t * restrict __linecapp, FILE * restrict __stream) __attribute__((availability(macosx,introduced=10.7)));
FILE *fmemopen(void * restrict __buf , size_t __size, const char * restrict __mode) __attribute__((availability(macos,introduced=10.13))) __attribute__((availability(ios,introduced=11.0))) __attribute__((availability(tvos,introduced=11.0))) __attribute__((availability(watchos,introduced=4.0)));
FILE *open_memstream(char * *__bufp, size_t *__sizep) __attribute__((availability(macos,introduced=10.13))) __attribute__((availability(ios,introduced=11.0))) __attribute__((availability(tvos,introduced=11.0))) __attribute__((availability(watchos,introduced=4.0)));
# 468 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 3 4
extern const int sys_nerr;
extern const char *const sys_errlist[];

int asprintf(char * *restrict, const char * restrict, ...) __attribute__((__format__ (__printf__, 2, 3)));
char * ctermid_r(char *);
char * fgetln(FILE *, size_t *__len);
const char *fmtcheck(const char *, const char *) __attribute__((format_arg(2)));
int fpurge(FILE *);
void setbuffer(FILE *, char *, int __size);
int setlinebuf(FILE *);
int vasprintf(char * *restrict, const char * restrict, va_list) __attribute__((__format__ (__printf__, 2, 0)));





FILE *funopen(const void *,
     int (* _Nullable)(void *, char *, int __n),
     int (* _Nullable)(void *, const char *, int __n),
     fpos_t (* _Nullable)(void *, fpos_t, int),
     int (* _Nullable)(void *));
# 503 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/secure/_stdio.h" 1 3 4
# 32 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/secure/_stdio.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/secure/_common.h" 1 3 4
# 33 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/secure/_stdio.h" 2 3 4
# 45 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/secure/_stdio.h" 3 4
extern int __sprintf_chk (char * restrict , int, size_t,
     const char * restrict, ...);
# 55 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/secure/_stdio.h" 3 4
extern int __snprintf_chk (char * restrict , size_t __maxlen, int, size_t,
      const char * restrict, ...);







extern int __vsprintf_chk (char * restrict , int, size_t,
      const char * restrict, va_list);







extern int __vsnprintf_chk (char * restrict , size_t __maxlen, int, size_t,
       const char * restrict, va_list);
# 504 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdio.h" 2 3 4
# 62 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/stdio.h" 2 3 4
# 45 "WinQuake/quakedef.h" 2
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/stdlib.h" 1 3 4
# 58 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/stdlib.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 1 3 4
# 64 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 65 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 2 3 4





# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/wait.h" 1 3 4
# 79 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/wait.h" 3 4
typedef enum {
 P_ALL,
 P_PID,
 P_PGID
} idtype_t;





# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_pid_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_pid_t.h" 3 4
typedef __darwin_pid_t pid_t;
# 90 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/wait.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_id_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_id_t.h" 3 4
typedef __darwin_id_t id_t;
# 91 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/wait.h" 2 3 4
# 109 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/wait.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/signal.h" 1 3 4
# 73 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/signal.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/appleapiopts.h" 1 3 4
# 74 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/signal.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 75 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/signal.h" 2 3 4







# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/machine/signal.h" 1 3 4
# 34 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/machine/signal.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/signal.h" 1 3 4
# 17 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/signal.h" 3 4
typedef int sig_atomic_t;
# 35 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/machine/signal.h" 2 3 4
# 83 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/signal.h" 2 3 4
# 146 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/signal.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/machine/_mcontext.h" 1 3 4
# 34 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/machine/_mcontext.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/_mcontext.h" 1 3 4
# 36 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/_mcontext.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/machine/_structs.h" 1 3 4
# 35 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/machine/_structs.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/arm/_structs.h" 1 3 4
# 41 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/arm/_structs.h" 3 4
struct __darwin_arm_exception_state
{
 __uint32_t __exception;
 __uint32_t __fsr;
 __uint32_t __far;
};
# 59 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/arm/_structs.h" 3 4
struct __darwin_arm_exception_state64
{
 __uint64_t __far;
 __uint32_t __esr;
 __uint32_t __exception;
};

struct __darwin_arm_exception_state64_v2
{
 __uint64_t __far;
 __uint64_t __esr;
};
# 89 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/arm/_structs.h" 3 4
struct __darwin_arm_thread_state
{
 __uint32_t __r[13];
 __uint32_t __sp;
 __uint32_t __lr;
 __uint32_t __pc;
 __uint32_t __cpsr;
};
# 148 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/arm/_structs.h" 3 4
struct __darwin_arm_thread_state64
{
 __uint64_t __x[29];
 __uint64_t __fp;
 __uint64_t __lr;
 __uint64_t __sp;
 __uint64_t __pc;
 __uint32_t __cpsr;
 __uint32_t __pad;
};
# 519 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/arm/_structs.h" 3 4
struct __darwin_arm_vfp_state
{
 __uint32_t __r[64];
 __uint32_t __fpscr;
};
# 538 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/arm/_structs.h" 3 4
struct __darwin_arm_neon_state64
{
 __uint128_t __v[32];
 __uint32_t __fpsr;
 __uint32_t __fpcr;
};

struct __darwin_arm_neon_state
{
 __uint128_t __v[16];
 __uint32_t __fpsr;
 __uint32_t __fpcr;
};
# 609 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/arm/_structs.h" 3 4
struct __arm_pagein_state
{
 int __pagein_error;
};



struct __darwin_arm_sme_state
{
 __uint64_t __svcr;
 __uint64_t __tpidr2_el0;
 __uint16_t __svl_b;
};


struct __darwin_arm_sve_z_state
{
 char __z[16][256];
} __attribute__((aligned(4)));


struct __darwin_arm_sve_p_state
{
 char __p[16][256 / 8];
} __attribute__((aligned(4)));


struct __darwin_arm_sme_za_state
{
 char __za[4096];
} __attribute__((aligned(4)));


struct __darwin_arm_sme2_state
{
 char __zt0[64];
} __attribute__((aligned(4)));
# 712 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/arm/_structs.h" 3 4
struct __arm_legacy_debug_state
{
 __uint32_t __bvr[16];
 __uint32_t __bcr[16];
 __uint32_t __wvr[16];
 __uint32_t __wcr[16];
};
# 735 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/arm/_structs.h" 3 4
struct __darwin_arm_debug_state32
{
 __uint32_t __bvr[16];
 __uint32_t __bcr[16];
 __uint32_t __wvr[16];
 __uint32_t __wcr[16];
 __uint64_t __mdscr_el1;
};


struct __darwin_arm_debug_state64
{
 __uint64_t __bvr[16];
 __uint64_t __bcr[16];
 __uint64_t __wvr[16];
 __uint64_t __wcr[16];
 __uint64_t __mdscr_el1;
};
# 777 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/arm/_structs.h" 3 4
struct __darwin_arm_cpmu_state64
{
 __uint64_t __ctrs[16];
};
# 36 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/machine/_structs.h" 2 3 4
# 37 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/_mcontext.h" 2 3 4




struct __darwin_mcontext32
{
 struct __darwin_arm_exception_state __es;
 struct __darwin_arm_thread_state __ss;
 struct __darwin_arm_vfp_state __fs;
};
# 64 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/_mcontext.h" 3 4
struct __darwin_mcontext64
{
 struct __darwin_arm_exception_state64 __es;
 struct __darwin_arm_thread_state64 __ss;
 struct __darwin_arm_neon_state64 __ns;
};
# 85 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/_mcontext.h" 3 4
typedef struct __darwin_mcontext64 *mcontext_t;
# 35 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/machine/_mcontext.h" 2 3 4
# 147 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/signal.h" 2 3 4

# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_pthread/_pthread_attr_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_pthread/_pthread_attr_t.h" 3 4
typedef __darwin_pthread_attr_t pthread_attr_t;
# 149 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/signal.h" 2 3 4

# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_sigaltstack.h" 1 3 4
# 42 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_sigaltstack.h" 3 4
struct __darwin_sigaltstack
{
 void *ss_sp;
 __darwin_size_t ss_size;
 int ss_flags;
};
typedef struct __darwin_sigaltstack stack_t;
# 151 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/signal.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_ucontext.h" 1 3 4
# 43 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_ucontext.h" 3 4
struct __darwin_ucontext
{
 int uc_onstack;
 __darwin_sigset_t uc_sigmask;
 struct __darwin_sigaltstack uc_stack;
 struct __darwin_ucontext *uc_link;
 __darwin_size_t uc_mcsize;
 struct __darwin_mcontext64 *uc_mcontext;



};


typedef struct __darwin_ucontext ucontext_t;
# 152 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/signal.h" 2 3 4


# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_sigset_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_sigset_t.h" 3 4
typedef __darwin_sigset_t sigset_t;
# 155 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/signal.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_size_t.h" 1 3 4
# 156 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/signal.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_uid_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_uid_t.h" 3 4
typedef __darwin_uid_t uid_t;
# 157 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/signal.h" 2 3 4

union sigval {

 int sival_int;
 void *sival_ptr;
};





struct sigevent {
 int sigev_notify;
 int sigev_signo;
 union sigval sigev_value;
 void (*sigev_notify_function)(union sigval);
 pthread_attr_t *sigev_notify_attributes;
};


typedef struct __siginfo {
 int si_signo;
 int si_errno;
 int si_code;
 pid_t si_pid;
 uid_t si_uid;
 int si_status;
 void *si_addr;
 union sigval si_value;
 long si_band;
 unsigned long __pad[7];
} siginfo_t;
# 269 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/signal.h" 3 4
union __sigaction_u {
 void (*__sa_handler)(int);
 void (*__sa_sigaction)(int, struct __siginfo *,
     void *);
};


struct __sigaction {
 union __sigaction_u __sigaction_u;
 void (*sa_tramp)(void *, int, int, siginfo_t *, void *);
 sigset_t sa_mask;
 int sa_flags;
};




struct sigaction {
 union __sigaction_u __sigaction_u;
 sigset_t sa_mask;
 int sa_flags;
};
# 331 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/signal.h" 3 4
typedef void (*sig_t)(int);
# 348 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/signal.h" 3 4
struct sigvec {
 void (*sv_handler)(int);
 int sv_mask;
 int sv_flags;
};
# 367 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/signal.h" 3 4
struct sigstack {
 char *ss_sp;
 int ss_onstack;
};
# 390 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/signal.h" 3 4
void(*signal(int, void (*)(int)))(int);
# 110 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/wait.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/resource.h" 1 3 4
# 72 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/resource.h" 3 4
# 1 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/stdint.h" 1 3 4
# 56 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/stdint.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/stdint.h" 1 3 4
# 23 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/stdint.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_types/_uint8_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_types/_uint8_t.h" 3 4
typedef unsigned char uint8_t;
# 24 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/stdint.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_types/_uint16_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_types/_uint16_t.h" 3 4
typedef unsigned short uint16_t;
# 25 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/stdint.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_types/_uint32_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_types/_uint32_t.h" 3 4
typedef unsigned int uint32_t;
# 26 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/stdint.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_types/_uint64_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_types/_uint64_t.h" 3 4
typedef unsigned long long uint64_t;
# 27 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/stdint.h" 2 3 4


typedef int8_t int_least8_t;
typedef int16_t int_least16_t;
typedef int32_t int_least32_t;
typedef int64_t int_least64_t;
typedef uint8_t uint_least8_t;
typedef uint16_t uint_least16_t;
typedef uint32_t uint_least32_t;
typedef uint64_t uint_least64_t;



typedef int8_t int_fast8_t;
typedef int16_t int_fast16_t;
typedef int32_t int_fast32_t;
typedef int64_t int_fast64_t;
typedef uint8_t uint_fast8_t;
typedef uint16_t uint_fast16_t;
typedef uint32_t uint_fast32_t;
typedef uint64_t uint_fast64_t;
# 58 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/stdint.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_types/_intmax_t.h" 1 3 4
# 32 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_types/_intmax_t.h" 3 4
typedef long int intmax_t;
# 59 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/stdint.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_types/_uintmax_t.h" 1 3 4
# 32 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_types/_uintmax_t.h" 3 4
typedef long unsigned int uintmax_t;
# 60 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/stdint.h" 2 3 4
# 57 "/Library/Developer/CommandLineTools/usr/lib/clang/17/include/stdint.h" 2 3 4
# 73 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/resource.h" 2 3 4


# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 76 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/resource.h" 2 3 4




# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_timeval.h" 1 3 4
# 34 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_timeval.h" 3 4
struct timeval
{
 __darwin_time_t tv_sec;
 __darwin_suseconds_t tv_usec;
};
# 81 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/resource.h" 2 3 4








typedef __uint64_t rlim_t;
# 152 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/resource.h" 3 4
struct rusage {
 struct timeval ru_utime;
 struct timeval ru_stime;
# 163 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/resource.h" 3 4
 long ru_maxrss;

 long ru_ixrss;
 long ru_idrss;
 long ru_isrss;
 long ru_minflt;
 long ru_majflt;
 long ru_nswap;
 long ru_inblock;
 long ru_oublock;
 long ru_msgsnd;
 long ru_msgrcv;
 long ru_nsignals;
 long ru_nvcsw;
 long ru_nivcsw;


};
# 200 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/resource.h" 3 4
typedef void *rusage_info_t;

struct rusage_info_v0 {
 uint8_t ri_uuid[16];
 uint64_t ri_user_time;
 uint64_t ri_system_time;
 uint64_t ri_pkg_idle_wkups;
 uint64_t ri_interrupt_wkups;
 uint64_t ri_pageins;
 uint64_t ri_wired_size;
 uint64_t ri_resident_size;
 uint64_t ri_phys_footprint;
 uint64_t ri_proc_start_abstime;
 uint64_t ri_proc_exit_abstime;
};

struct rusage_info_v1 {
 uint8_t ri_uuid[16];
 uint64_t ri_user_time;
 uint64_t ri_system_time;
 uint64_t ri_pkg_idle_wkups;
 uint64_t ri_interrupt_wkups;
 uint64_t ri_pageins;
 uint64_t ri_wired_size;
 uint64_t ri_resident_size;
 uint64_t ri_phys_footprint;
 uint64_t ri_proc_start_abstime;
 uint64_t ri_proc_exit_abstime;
 uint64_t ri_child_user_time;
 uint64_t ri_child_system_time;
 uint64_t ri_child_pkg_idle_wkups;
 uint64_t ri_child_interrupt_wkups;
 uint64_t ri_child_pageins;
 uint64_t ri_child_elapsed_abstime;
};

struct rusage_info_v2 {
 uint8_t ri_uuid[16];
 uint64_t ri_user_time;
 uint64_t ri_system_time;
 uint64_t ri_pkg_idle_wkups;
 uint64_t ri_interrupt_wkups;
 uint64_t ri_pageins;
 uint64_t ri_wired_size;
 uint64_t ri_resident_size;
 uint64_t ri_phys_footprint;
 uint64_t ri_proc_start_abstime;
 uint64_t ri_proc_exit_abstime;
 uint64_t ri_child_user_time;
 uint64_t ri_child_system_time;
 uint64_t ri_child_pkg_idle_wkups;
 uint64_t ri_child_interrupt_wkups;
 uint64_t ri_child_pageins;
 uint64_t ri_child_elapsed_abstime;
 uint64_t ri_diskio_bytesread;
 uint64_t ri_diskio_byteswritten;
};

struct rusage_info_v3 {
 uint8_t ri_uuid[16];
 uint64_t ri_user_time;
 uint64_t ri_system_time;
 uint64_t ri_pkg_idle_wkups;
 uint64_t ri_interrupt_wkups;
 uint64_t ri_pageins;
 uint64_t ri_wired_size;
 uint64_t ri_resident_size;
 uint64_t ri_phys_footprint;
 uint64_t ri_proc_start_abstime;
 uint64_t ri_proc_exit_abstime;
 uint64_t ri_child_user_time;
 uint64_t ri_child_system_time;
 uint64_t ri_child_pkg_idle_wkups;
 uint64_t ri_child_interrupt_wkups;
 uint64_t ri_child_pageins;
 uint64_t ri_child_elapsed_abstime;
 uint64_t ri_diskio_bytesread;
 uint64_t ri_diskio_byteswritten;
 uint64_t ri_cpu_time_qos_default;
 uint64_t ri_cpu_time_qos_maintenance;
 uint64_t ri_cpu_time_qos_background;
 uint64_t ri_cpu_time_qos_utility;
 uint64_t ri_cpu_time_qos_legacy;
 uint64_t ri_cpu_time_qos_user_initiated;
 uint64_t ri_cpu_time_qos_user_interactive;
 uint64_t ri_billed_system_time;
 uint64_t ri_serviced_system_time;
};

struct rusage_info_v4 {
 uint8_t ri_uuid[16];
 uint64_t ri_user_time;
 uint64_t ri_system_time;
 uint64_t ri_pkg_idle_wkups;
 uint64_t ri_interrupt_wkups;
 uint64_t ri_pageins;
 uint64_t ri_wired_size;
 uint64_t ri_resident_size;
 uint64_t ri_phys_footprint;
 uint64_t ri_proc_start_abstime;
 uint64_t ri_proc_exit_abstime;
 uint64_t ri_child_user_time;
 uint64_t ri_child_system_time;
 uint64_t ri_child_pkg_idle_wkups;
 uint64_t ri_child_interrupt_wkups;
 uint64_t ri_child_pageins;
 uint64_t ri_child_elapsed_abstime;
 uint64_t ri_diskio_bytesread;
 uint64_t ri_diskio_byteswritten;
 uint64_t ri_cpu_time_qos_default;
 uint64_t ri_cpu_time_qos_maintenance;
 uint64_t ri_cpu_time_qos_background;
 uint64_t ri_cpu_time_qos_utility;
 uint64_t ri_cpu_time_qos_legacy;
 uint64_t ri_cpu_time_qos_user_initiated;
 uint64_t ri_cpu_time_qos_user_interactive;
 uint64_t ri_billed_system_time;
 uint64_t ri_serviced_system_time;
 uint64_t ri_logical_writes;
 uint64_t ri_lifetime_max_phys_footprint;
 uint64_t ri_instructions;
 uint64_t ri_cycles;
 uint64_t ri_billed_energy;
 uint64_t ri_serviced_energy;
 uint64_t ri_interval_max_phys_footprint;
 uint64_t ri_runnable_time;
};

struct rusage_info_v5 {
 uint8_t ri_uuid[16];
 uint64_t ri_user_time;
 uint64_t ri_system_time;
 uint64_t ri_pkg_idle_wkups;
 uint64_t ri_interrupt_wkups;
 uint64_t ri_pageins;
 uint64_t ri_wired_size;
 uint64_t ri_resident_size;
 uint64_t ri_phys_footprint;
 uint64_t ri_proc_start_abstime;
 uint64_t ri_proc_exit_abstime;
 uint64_t ri_child_user_time;
 uint64_t ri_child_system_time;
 uint64_t ri_child_pkg_idle_wkups;
 uint64_t ri_child_interrupt_wkups;
 uint64_t ri_child_pageins;
 uint64_t ri_child_elapsed_abstime;
 uint64_t ri_diskio_bytesread;
 uint64_t ri_diskio_byteswritten;
 uint64_t ri_cpu_time_qos_default;
 uint64_t ri_cpu_time_qos_maintenance;
 uint64_t ri_cpu_time_qos_background;
 uint64_t ri_cpu_time_qos_utility;
 uint64_t ri_cpu_time_qos_legacy;
 uint64_t ri_cpu_time_qos_user_initiated;
 uint64_t ri_cpu_time_qos_user_interactive;
 uint64_t ri_billed_system_time;
 uint64_t ri_serviced_system_time;
 uint64_t ri_logical_writes;
 uint64_t ri_lifetime_max_phys_footprint;
 uint64_t ri_instructions;
 uint64_t ri_cycles;
 uint64_t ri_billed_energy;
 uint64_t ri_serviced_energy;
 uint64_t ri_interval_max_phys_footprint;
 uint64_t ri_runnable_time;
 uint64_t ri_flags;
};

struct rusage_info_v6 {
 uint8_t ri_uuid[16];
 uint64_t ri_user_time;
 uint64_t ri_system_time;
 uint64_t ri_pkg_idle_wkups;
 uint64_t ri_interrupt_wkups;
 uint64_t ri_pageins;
 uint64_t ri_wired_size;
 uint64_t ri_resident_size;
 uint64_t ri_phys_footprint;
 uint64_t ri_proc_start_abstime;
 uint64_t ri_proc_exit_abstime;
 uint64_t ri_child_user_time;
 uint64_t ri_child_system_time;
 uint64_t ri_child_pkg_idle_wkups;
 uint64_t ri_child_interrupt_wkups;
 uint64_t ri_child_pageins;
 uint64_t ri_child_elapsed_abstime;
 uint64_t ri_diskio_bytesread;
 uint64_t ri_diskio_byteswritten;
 uint64_t ri_cpu_time_qos_default;
 uint64_t ri_cpu_time_qos_maintenance;
 uint64_t ri_cpu_time_qos_background;
 uint64_t ri_cpu_time_qos_utility;
 uint64_t ri_cpu_time_qos_legacy;
 uint64_t ri_cpu_time_qos_user_initiated;
 uint64_t ri_cpu_time_qos_user_interactive;
 uint64_t ri_billed_system_time;
 uint64_t ri_serviced_system_time;
 uint64_t ri_logical_writes;
 uint64_t ri_lifetime_max_phys_footprint;
 uint64_t ri_instructions;
 uint64_t ri_cycles;
 uint64_t ri_billed_energy;
 uint64_t ri_serviced_energy;
 uint64_t ri_interval_max_phys_footprint;
 uint64_t ri_runnable_time;
 uint64_t ri_flags;
 uint64_t ri_user_ptime;
 uint64_t ri_system_ptime;
 uint64_t ri_pinstructions;
 uint64_t ri_pcycles;
 uint64_t ri_energy_nj;
 uint64_t ri_penergy_nj;
 uint64_t ri_secure_time_in_system;
 uint64_t ri_secure_ptime_in_system;
 uint64_t ri_neural_footprint;
 uint64_t ri_lifetime_max_neural_footprint;
 uint64_t ri_interval_max_neural_footprint;
 uint64_t ri_reserved[9];
};

typedef struct rusage_info_v6 rusage_info_current;
# 464 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/resource.h" 3 4
struct rlimit {
 rlim_t rlim_cur;
 rlim_t rlim_max;
};
# 499 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/resource.h" 3 4
struct proc_rlimit_control_wakeupmon {
 uint32_t wm_flags;
 int32_t wm_rate;
};
# 571 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/resource.h" 3 4
int getpriority(int, id_t);

int getiopolicy_np(int, int) __attribute__((availability(macosx,introduced=10.5)));

int getrlimit(int, struct rlimit *) __asm("_" "getrlimit" );
int getrusage(int, struct rusage *);
int setpriority(int, id_t, int);

int setiopolicy_np(int, int, int) __attribute__((availability(macosx,introduced=10.5)));

int setrlimit(int, const struct rlimit *) __asm("_" "setrlimit" );
# 111 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/wait.h" 2 3 4
# 186 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/wait.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/machine/endian.h" 1 3 4
# 37 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/machine/endian.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/endian.h" 1 3 4
# 61 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/endian.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_endian.h" 1 3 4
# 94 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_endian.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/machine/_endian.h" 1 3 4
# 37 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/machine/_endian.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/_endian.h" 1 3 4
# 95 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/_endian.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/__endian.h" 1 3 4
# 96 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/_endian.h" 2 3 4
# 38 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/machine/_endian.h" 2 3 4
# 95 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_endian.h" 2 3 4
# 131 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_endian.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/libkern/_OSByteOrder.h" 1 3 4
# 62 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/libkern/_OSByteOrder.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/libkern/arm/_OSByteOrder.h" 1 3 4
# 48 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/libkern/arm/_OSByteOrder.h" 3 4
static inline
__uint16_t
_OSSwapInt16(
 __uint16_t _data
 )
{

 return (__uint16_t)(_data << 8 | _data >> 8);
}

static inline
__uint32_t
_OSSwapInt32(
 __uint32_t _data
 )
{

 _data = __builtin_bswap32(_data);





 return _data;
}

static inline
__uint64_t
_OSSwapInt64(
 __uint64_t _data
 )
{

 return __builtin_bswap64(_data);
# 95 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/libkern/arm/_OSByteOrder.h" 3 4
}
# 63 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/libkern/_OSByteOrder.h" 2 3 4
# 132 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_endian.h" 2 3 4
# 62 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/arm/endian.h" 2 3 4
# 38 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/machine/endian.h" 2 3 4
# 187 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/wait.h" 2 3 4







union wait {
 int w_status;



 struct {

  unsigned int w_Termsig:7,
      w_Coredump:1,
      w_Retcode:8,
      w_Filler:16;






 } w_T;





 struct {

  unsigned int w_Stopval:8,
      w_Stopsig:8,
      w_Filler:16;





 } w_S;
};
# 246 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/wait.h" 3 4
pid_t wait(int *) __asm("_" "wait" );
pid_t waitpid(pid_t, int *, int) __asm("_" "waitpid" );

int waitid(idtype_t, id_t, siginfo_t *, int) __asm("_" "waitid" );


pid_t wait3(int *, int, struct rusage *);
pid_t wait4(pid_t, int *, int, struct rusage *);
# 71 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 2 3 4

# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/alloca.h" 1 3 4
# 30 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/alloca.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_size_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/alloca.h" 2 3 4




void * alloca(size_t __size);
# 73 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 2 3 4
# 91 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_size_t.h" 1 3 4
# 92 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 2 3 4


# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_ct_rune_t.h" 1 3 4
# 32 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_ct_rune_t.h" 3 4
typedef __darwin_ct_rune_t ct_rune_t;
# 95 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_rune_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_rune_t.h" 3 4
typedef __darwin_rune_t rune_t;
# 96 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 2 3 4


# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_wchar_t.h" 1 3 4
# 53 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_wchar_t.h" 3 4
typedef __darwin_wchar_t wchar_t;
# 99 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 2 3 4



typedef struct {
 int quot;
 int rem;
} div_t;

typedef struct {
 long quot;
 long rem;
} ldiv_t;


typedef struct {
 long long quot;
 long long rem;
} lldiv_t;


# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_null.h" 1 3 4
# 120 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 2 3 4
# 134 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 3 4
extern int __mb_cur_max;




# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/malloc/_malloc.h" 1 3 4
# 33 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/malloc/_malloc.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 34 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/malloc/_malloc.h" 2 3 4


# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_size_t.h" 1 3 4
# 37 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/malloc/_malloc.h" 2 3 4







# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/malloc/_malloc_type.h" 1 3 4
# 27 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/malloc/_malloc_type.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/malloc/_ptrcheck.h" 1 3 4
# 28 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/malloc/_malloc_type.h" 2 3 4


typedef unsigned long long malloc_type_id_t;




# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 36 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/malloc/_malloc_type.h" 2 3 4

# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_size_t.h" 1 3 4
# 38 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/malloc/_malloc_type.h" 2 3 4
# 51 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/malloc/_malloc_type.h" 3 4
__attribute__((availability(macos,introduced=14.0))) __attribute__((availability(ios,introduced=17.0))) __attribute__((availability(tvos,introduced=17.0))) __attribute__((availability(watchos,introduced=10.0))) __attribute__((availability(visionos,introduced=1.0))) __attribute__((availability(driverkit,introduced=23.0))) void * malloc_type_malloc(size_t size, malloc_type_id_t type_id) __attribute__((__warn_unused_result__)) __attribute__((alloc_size(1)));
__attribute__((availability(macos,introduced=14.0))) __attribute__((availability(ios,introduced=17.0))) __attribute__((availability(tvos,introduced=17.0))) __attribute__((availability(watchos,introduced=10.0))) __attribute__((availability(visionos,introduced=1.0))) __attribute__((availability(driverkit,introduced=23.0))) void * malloc_type_calloc(size_t count, size_t size, malloc_type_id_t type_id) __attribute__((__warn_unused_result__)) __attribute__((alloc_size(1,2)));
__attribute__((availability(macos,introduced=14.0))) __attribute__((availability(ios,introduced=17.0))) __attribute__((availability(tvos,introduced=17.0))) __attribute__((availability(watchos,introduced=10.0))) __attribute__((availability(visionos,introduced=1.0))) __attribute__((availability(driverkit,introduced=23.0))) void malloc_type_free(void * ptr, malloc_type_id_t type_id);
__attribute__((availability(macos,introduced=14.0))) __attribute__((availability(ios,introduced=17.0))) __attribute__((availability(tvos,introduced=17.0))) __attribute__((availability(watchos,introduced=10.0))) __attribute__((availability(visionos,introduced=1.0))) __attribute__((availability(driverkit,introduced=23.0))) void * malloc_type_realloc(void * ptr, size_t size, malloc_type_id_t type_id) __attribute__((__warn_unused_result__)) __attribute__((alloc_size(2)));
__attribute__((availability(macos,introduced=14.0))) __attribute__((availability(ios,introduced=17.0))) __attribute__((availability(tvos,introduced=17.0))) __attribute__((availability(watchos,introduced=10.0))) __attribute__((availability(visionos,introduced=1.0))) __attribute__((availability(driverkit,introduced=23.0))) void * malloc_type_valloc(size_t size, malloc_type_id_t type_id) __attribute__((__warn_unused_result__)) __attribute__((alloc_size(1)));
__attribute__((availability(macos,introduced=14.0))) __attribute__((availability(ios,introduced=17.0))) __attribute__((availability(tvos,introduced=17.0))) __attribute__((availability(watchos,introduced=10.0))) __attribute__((availability(visionos,introduced=1.0))) __attribute__((availability(driverkit,introduced=23.0))) void * malloc_type_aligned_alloc(size_t alignment, size_t size, malloc_type_id_t type_id) __attribute__((__warn_unused_result__)) __attribute__((alloc_size(2)));

__attribute__((availability(macos,introduced=14.0))) __attribute__((availability(ios,introduced=17.0))) __attribute__((availability(tvos,introduced=17.0))) __attribute__((availability(watchos,introduced=10.0))) __attribute__((availability(visionos,introduced=1.0))) __attribute__((availability(driverkit,introduced=23.0))) int malloc_type_posix_memalign(void * *memptr, size_t alignment, size_t size, malloc_type_id_t type_id) ;




typedef struct _malloc_zone_t malloc_zone_t;

__attribute__((availability(macos,introduced=14.0))) __attribute__((availability(ios,introduced=17.0))) __attribute__((availability(tvos,introduced=17.0))) __attribute__((availability(watchos,introduced=10.0))) __attribute__((availability(visionos,introduced=1.0))) __attribute__((availability(driverkit,introduced=23.0))) void * malloc_type_zone_malloc(malloc_zone_t *zone, size_t size, malloc_type_id_t type_id) __attribute__((__warn_unused_result__)) __attribute__((alloc_size(2)));
__attribute__((availability(macos,introduced=14.0))) __attribute__((availability(ios,introduced=17.0))) __attribute__((availability(tvos,introduced=17.0))) __attribute__((availability(watchos,introduced=10.0))) __attribute__((availability(visionos,introduced=1.0))) __attribute__((availability(driverkit,introduced=23.0))) void * malloc_type_zone_calloc(malloc_zone_t *zone, size_t count, size_t size, malloc_type_id_t type_id) __attribute__((__warn_unused_result__)) __attribute__((alloc_size(2,3)));
__attribute__((availability(macos,introduced=14.0))) __attribute__((availability(ios,introduced=17.0))) __attribute__((availability(tvos,introduced=17.0))) __attribute__((availability(watchos,introduced=10.0))) __attribute__((availability(visionos,introduced=1.0))) __attribute__((availability(driverkit,introduced=23.0))) void malloc_type_zone_free(malloc_zone_t *zone, void * ptr, malloc_type_id_t type_id);
__attribute__((availability(macos,introduced=14.0))) __attribute__((availability(ios,introduced=17.0))) __attribute__((availability(tvos,introduced=17.0))) __attribute__((availability(watchos,introduced=10.0))) __attribute__((availability(visionos,introduced=1.0))) __attribute__((availability(driverkit,introduced=23.0))) void * malloc_type_zone_realloc(malloc_zone_t *zone, void * ptr, size_t size, malloc_type_id_t type_id) __attribute__((__warn_unused_result__)) __attribute__((alloc_size(3)));
__attribute__((availability(macos,introduced=14.0))) __attribute__((availability(ios,introduced=17.0))) __attribute__((availability(tvos,introduced=17.0))) __attribute__((availability(watchos,introduced=10.0))) __attribute__((availability(visionos,introduced=1.0))) __attribute__((availability(driverkit,introduced=23.0))) void * malloc_type_zone_valloc(malloc_zone_t *zone, size_t size, malloc_type_id_t type_id) __attribute__((__warn_unused_result__)) __attribute__((alloc_size(2)));
__attribute__((availability(macos,introduced=14.0))) __attribute__((availability(ios,introduced=17.0))) __attribute__((availability(tvos,introduced=17.0))) __attribute__((availability(watchos,introduced=10.0))) __attribute__((availability(visionos,introduced=1.0))) __attribute__((availability(driverkit,introduced=23.0))) void * malloc_type_zone_memalign(malloc_zone_t *zone, size_t alignment, size_t size, malloc_type_id_t type_id) __attribute__((__warn_unused_result__)) __attribute__((alloc_size(3)));
# 45 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/malloc/_malloc.h" 2 3 4
# 54 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/malloc/_malloc.h" 3 4
void * malloc(size_t __size) __attribute__((__warn_unused_result__)) __attribute__((alloc_size(1))) ;
void * calloc(size_t __count, size_t __size) __attribute__((__warn_unused_result__)) __attribute__((alloc_size(1,2))) ;
void free(void * );
void * realloc(void * __ptr, size_t __size) __attribute__((__warn_unused_result__)) __attribute__((alloc_size(2))) ;
void * reallocf(void * __ptr, size_t __size) __attribute__((__warn_unused_result__)) __attribute__((alloc_size(2)));

void * valloc(size_t __size) __attribute__((__warn_unused_result__)) __attribute__((alloc_size(1))) ;




void * aligned_alloc(size_t __alignment, size_t __size) __attribute__((__warn_unused_result__)) __attribute__((alloc_align(1))) __attribute__((alloc_size(2))) __attribute__((availability(macosx,introduced=10.15))) __attribute__((availability(ios,introduced=13.0))) __attribute__((availability(tvos,introduced=13.0))) __attribute__((availability(watchos,introduced=6.0)));


int posix_memalign(void * *__memptr, size_t __alignment, size_t __size) __attribute__((availability(macosx,introduced=10.6)));
# 140 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_abort.h" 1 3 4
# 33 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_abort.h" 3 4
void abort(void) __attribute__((__cold__)) __attribute__((__noreturn__));
# 141 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 2 3 4


int abs(int) __attribute__((__const__));
int atexit(void (* _Nonnull)(void));


int at_quick_exit(void (*)(void));

double atof(const char *);
int atoi(const char *);
long atol(const char *);

long long
  atoll(const char *);

void *bsearch(const void * __key, const void * __base, size_t __nel,
     size_t __width, int (* _Nonnull __compar)(const void *, const void *));

div_t div(int, int) __attribute__((__const__));
void exit(int) __attribute__((__noreturn__));

char * getenv(const char *);
long labs(long) __attribute__((__const__));
ldiv_t ldiv(long, long) __attribute__((__const__));

long long
  llabs(long long);
lldiv_t lldiv(long long, long long);


int mblen(const char * __s, size_t __n);
size_t mbstowcs(wchar_t * restrict , const char * restrict, size_t __n);
int mbtowc(wchar_t * restrict, const char * restrict , size_t __n);

void qsort(void * __base, size_t __nel, size_t __width,
     int (* _Nonnull __compar)(const void *, const void *));


void quick_exit(int) __attribute__((__noreturn__));

int rand(void) __attribute__((__availability__(swift, unavailable, message="Use arc4random instead.")));

void srand(unsigned) __attribute__((__availability__(swift, unavailable, message="Use arc4random instead.")));
double strtod(const char *, char * *) __asm("_" "strtod" );
float strtof(const char *, char * *) __asm("_" "strtof" );
long strtol(const char *__str, char * *__endptr, int __base);
long double
  strtold(const char *, char * *);

long long
  strtoll(const char *__str, char * *__endptr, int __base);

unsigned long
  strtoul(const char *__str, char * *__endptr, int __base);

unsigned long long
  strtoull(const char *__str, char * *__endptr, int __base);


__attribute__((__availability__(swift, unavailable, message="Use posix_spawn APIs or NSTask instead. (On iOS, process spawning is unavailable.)")))
__attribute__((availability(macos,introduced=10.0))) __attribute__((availability(ios,unavailable)))
__attribute__((availability(watchos,unavailable))) __attribute__((availability(tvos,unavailable)))
int system(const char *) __asm("_" "system" );


size_t wcstombs(char * restrict , const wchar_t * restrict, size_t __n);
int wctomb(char *, wchar_t);


void _Exit(int) __attribute__((__noreturn__));
long a64l(const char *);
double drand48(void);
char * ecvt(double, int, int *restrict, int *restrict);
double erand48(unsigned short[3]);
char * fcvt(double, int, int *restrict, int *restrict);
char * gcvt(double, int, char *) ;
int getsubopt(char * *, char * const *, char * *);
int grantpt(int);

char *
  initstate(unsigned, char *, size_t __size);




long jrand48(unsigned short[3]) __attribute__((__availability__(swift, unavailable, message="Use arc4random instead.")));
char *l64a(long);
void lcong48(unsigned short[7]);
long lrand48(void) __attribute__((__availability__(swift, unavailable, message="Use arc4random instead.")));

__attribute__((__deprecated__("This function is provided for compatibility reasons only.  Due to security concerns inherent in the design of mktemp(3), it is highly recommended that you use mkstemp(3) instead.")))

char * mktemp(char *);
int mkstemp(char *);
long mrand48(void) __attribute__((__availability__(swift, unavailable, message="Use arc4random instead.")));
long nrand48(unsigned short[3]) __attribute__((__availability__(swift, unavailable, message="Use arc4random instead.")));
int posix_openpt(int);
char * ptsname(int);


int ptsname_r(int fildes, char * buffer, size_t buflen) __attribute__((availability(macos,introduced=10.13.4))) __attribute__((availability(ios,introduced=11.3))) __attribute__((availability(tvos,introduced=11.3))) __attribute__((availability(watchos,introduced=4.3)));


int putenv(char *) __asm("_" "putenv" );
long random(void) __attribute__((__availability__(swift, unavailable, message="Use arc4random instead.")));
int rand_r(unsigned *) __attribute__((__availability__(swift, unavailable, message="Use arc4random instead.")));

char * realpath(const char * restrict, char * restrict ) __asm("_" "realpath" "$DARWIN_EXTSN");



unsigned short * seed48(unsigned short[3]);
int setenv(const char * __name, const char * __value, int __overwrite) __asm("_" "setenv" );

void setkey(const char *) __asm("_" "setkey" );



char * setstate(const char *);
void srand48(long);

void srandom(unsigned);



int unlockpt(int);

int unsetenv(const char *) __asm("_" "unsetenv" );
# 277 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_dev_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_dev_t.h" 3 4
typedef __darwin_dev_t dev_t;
# 278 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_mode_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_mode_t.h" 3 4
typedef __darwin_mode_t mode_t;
# 279 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 2 3 4



uint32_t arc4random(void);
void arc4random_addrandom(unsigned char * , int __datlen)
    __attribute__((availability(macosx,introduced=10.0))) __attribute__((availability(macosx,deprecated=10.12,message="use arc4random_stir")))
    __attribute__((availability(ios,introduced=2.0))) __attribute__((availability(ios,deprecated=10.0,message="use arc4random_stir")))
    __attribute__((availability(tvos,introduced=2.0))) __attribute__((availability(tvos,deprecated=10.0,message="use arc4random_stir")))
    __attribute__((availability(watchos,introduced=1.0))) __attribute__((availability(watchos,deprecated=3.0,message="use arc4random_stir")));
void arc4random_buf(void * __buf, size_t __nbytes) __attribute__((availability(macosx,introduced=10.7)));
void arc4random_stir(void);
uint32_t
  arc4random_uniform(uint32_t __upper_bound) __attribute__((availability(macosx,introduced=10.7)));

int atexit_b(void (^ _Nonnull)(void)) __attribute__((availability(macosx,introduced=10.6)));
# 302 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 3 4
void *bsearch_b(const void * __key, const void * __base, size_t __nel,
     size_t __width, int (^ _Nonnull __compar)(const void *, const void *) __attribute__((__noescape__)))
     __attribute__((availability(macosx,introduced=10.6)));



char * cgetcap(char *, const char *, int);
int cgetclose(void);
int cgetent(char * *, char * *, const char *);
int cgetfirst(char * *, char * *);
int cgetmatch(const char *, const char *);
int cgetnext(char * *, char * *);
int cgetnum(char *, const char *, long *);
int cgetset(const char *);
int cgetstr(char *, const char *, char * *);
int cgetustr(char *, const char *, char * *);

int daemon(int, int) __asm("_" "daemon" ) __attribute__((availability(macosx,introduced=10.0,deprecated=10.5,message="Use posix_spawn APIs instead."))) __attribute__((availability(watchos,unavailable))) __attribute__((availability(tvos,unavailable)));
char * devname(dev_t, mode_t);
char * devname_r(dev_t, mode_t, char * buf, int len);
char * getbsize(int *, long *);
int getloadavg(double [], int __nelem);
const char
 *getprogname(void);
void setprogname(const char *);
# 336 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_stdlib.h" 3 4
int heapsort(void * __base, size_t __nel, size_t __width,
     int (* _Nonnull __compar)(const void *, const void *));

int heapsort_b(void * __base, size_t __nel, size_t __width,
     int (^ _Nonnull __compar)(const void *, const void *) __attribute__((__noescape__)))
     __attribute__((availability(macosx,introduced=10.6)));

int mergesort(void * __base, size_t __nel, size_t __width,
     int (* _Nonnull __compar)(const void *, const void *));

int mergesort_b(void * __base, size_t __nel, size_t __width,
     int (^ _Nonnull __compar)(const void *, const void *) __attribute__((__noescape__)))
     __attribute__((availability(macosx,introduced=10.6)));

void psort(void * __base, size_t __nel, size_t __width,
     int (* _Nonnull __compar)(const void *, const void *))
     __attribute__((availability(macosx,introduced=10.6)));

void psort_b(void * __base, size_t __nel, size_t __width,
     int (^ _Nonnull __compar)(const void *, const void *) __attribute__((__noescape__)))
     __attribute__((availability(macosx,introduced=10.6)));

void psort_r(void * __base, size_t __nel, size_t __width, void *,
     int (* _Nonnull __compar)(void *, const void *, const void *))
     __attribute__((availability(macosx,introduced=10.6)));

void qsort_b(void * __base, size_t __nel, size_t __width,
     int (^ _Nonnull __compar)(const void *, const void *) __attribute__((__noescape__)))
     __attribute__((availability(macosx,introduced=10.6)));

void qsort_r(void * __base, size_t __nel, size_t __width, void *,
     int (* _Nonnull __compar)(void *, const void *, const void *));
int radixsort(const unsigned char * * __base, int __nel, const unsigned char * __table,
     unsigned __endbyte);
int rpmatch(const char *)
 __attribute__((availability(macos,introduced=10.15))) __attribute__((availability(ios,introduced=13.0))) __attribute__((availability(tvos,introduced=13.0))) __attribute__((availability(watchos,introduced=6.0)));
int sradixsort(const unsigned char * * __base, int __nel, const unsigned char * __table,
     unsigned __endbyte);
void sranddev(void);
void srandomdev(void);

long long
 strtonum(const char *__numstr, long long __minval, long long __maxval, const char * *__errstrp)
 __attribute__((availability(macos,introduced=11.0))) __attribute__((availability(ios,introduced=14.0))) __attribute__((availability(tvos,introduced=14.0))) __attribute__((availability(watchos,introduced=7.0)));

long long
  strtoq(const char *__str, char * *__endptr, int __base);
unsigned long long
  strtouq(const char *__str, char * *__endptr, int __base);

extern char * suboptarg;
# 59 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/stdlib.h" 2 3 4
# 46 "WinQuake/quakedef.h" 2
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/string.h" 1 3 4
# 58 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/string.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_string.h" 1 3 4
# 64 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_string.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 65 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_string.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_size_t.h" 1 3 4
# 66 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_string.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_null.h" 1 3 4
# 67 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_string.h" 2 3 4






void *
  memchr(const void * __s, int __c, size_t __n);
int memcmp(const void * __s1, const void * __s2,
  size_t __n);
void *
  memcpy(void * __dst, const void * __src,
  size_t __n);
void *
  memmove(void * __dst,
  const void * __src, size_t __len);
void *
  memset(void * __b, int __c, size_t __len);
char *
  strcat(char * __s1, const char *__s2)
                                  ;
char * strchr(const char *__s, int __c);
int strcmp(const char *__s1, const char *__s2);
int strcoll(const char *__s1, const char *__s2);
char *
  strcpy(char * __dst, const char *__src)
                                  ;
size_t strcspn(const char *__s, const char *__charset);
char * strerror(int __errnum) __asm("_" "strerror" );
size_t strlen(const char *__s);
char *
  strncat(char * __s1,
  const char * __s2, size_t __n)
                                  ;
int strncmp(const char * __s1,
  const char * __s2, size_t __n);
char *
  strncpy(char * __dst,
        const char * __src, size_t __n)
                                        ;
char * strpbrk(const char *__s, const char *__charset);
char * strrchr(const char *__s, int __c);
size_t strspn(const char *__s, const char *__charset);
char * strstr(const char *__big, const char *__little);
char * strtok(char * __str, const char *__sep);
size_t strxfrm(char * __s1, const char *__s2, size_t __n);
# 125 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_string.h" 3 4
char *
        strtok_r(char * __str, const char *__sep,
        char * *__lasts);
# 139 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_string.h" 3 4
int strerror_r(int __errnum, char * __strerrbuf,
        size_t __buflen);
char * strdup(const char *__s1);
void *
        memccpy(void * __dst, const void * __src,
        int __c, size_t __n);
# 156 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_string.h" 3 4
char *
        stpcpy(char * __dst, const char *__src) ;
char *
        stpncpy(char * __dst,
        const char * __src, size_t __n)
        __attribute__((availability(macosx,introduced=10.7)))
                                        ;
char * strndup(const char * __s1, size_t __n) __attribute__((availability(macosx,introduced=10.7)));
size_t strnlen(const char * __s1, size_t __n) __attribute__((availability(macosx,introduced=10.7)));
char * strsignal(int __sig);






# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_rsize_t.h" 1 3 4
# 50 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_rsize_t.h" 3 4
typedef __darwin_size_t rsize_t;
# 173 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_string.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_errno_t.h" 1 3 4
# 30 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_errno_t.h" 3 4
typedef int errno_t;
# 174 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_string.h" 2 3 4


errno_t memset_s(void * __s, rsize_t __smax, int __c, rsize_t __n) __attribute__((availability(macosx,introduced=10.9)));
# 186 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_string.h" 3 4
void *
        memmem(const void * __big, size_t __big_len,
        const void * __little, size_t __little_len) __attribute__((availability(macosx,introduced=10.7)));
void memset_pattern4(void * __b, const void * __pattern4, size_t __len) __attribute__((availability(macosx,introduced=10.5)));
void memset_pattern8(void * __b, const void * __pattern8, size_t __len) __attribute__((availability(macosx,introduced=10.5)));
void memset_pattern16(void * __b, const void * __pattern16, size_t __len) __attribute__((availability(macosx,introduced=10.5)));

char *
        strcasestr(const char *__big, const char *__little);
__attribute__((availability(macosx,introduced=15.4))) __attribute__((availability(ios,introduced=18.4)))
__attribute__((availability(tvos,introduced=18.4))) __attribute__((availability(watchos,introduced=11.4)))
char *
        strchrnul(const char *__s, int __c);
char *
        strnstr(const char * __big, const char *__little, size_t __len);
size_t strlcat(char * __dst, const char *__source, size_t __size);
size_t strlcpy(char * __dst, const char *__source, size_t __size);
void strmode(int __mode, char * __bp);
char *
        strsep(char * *__stringp, const char *__delim);


void swab(const void * restrict, void * restrict, ssize_t __len);

__attribute__((availability(macosx,introduced=10.12.1))) __attribute__((availability(ios,introduced=10.1)))
__attribute__((availability(tvos,introduced=10.0.1))) __attribute__((availability(watchos,introduced=3.1)))
int timingsafe_bcmp(const void * __b1, const void * __b2, size_t __len);

__attribute__((availability(macosx,introduced=11.0))) __attribute__((availability(ios,introduced=14.0)))
__attribute__((availability(tvos,introduced=14.0))) __attribute__((availability(watchos,introduced=7.0)))
int strsignal_r(int __sig, char * __strsignalbuf, size_t __buflen);





# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_strings.h" 1 3 4
# 65 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_strings.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 66 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_strings.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_size_t.h" 1 3 4
# 67 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_strings.h" 2 3 4






int bcmp(const void *, const void *, size_t __n) ;
void bcopy(const void *, void *, size_t __n) ;
void bzero(void *, size_t __n) ;
char * index(const char *, int) ;
char * rindex(const char *, int) ;


int ffs(int);
int strcasecmp(const char *, const char *);
int strncasecmp(const char *, const char *, size_t);





int ffsl(long) __attribute__((availability(macosx,introduced=10.5)));
int ffsll(long long) __attribute__((availability(macosx,introduced=10.9)));
int fls(int) __attribute__((availability(macosx,introduced=10.5)));
int flsl(long) __attribute__((availability(macosx,introduced=10.5)));
int flsll(long long) __attribute__((availability(macosx,introduced=10.9)));





# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/secure/_strings.h" 1 3 4
# 32 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/secure/_strings.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 33 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/secure/_strings.h" 2 3 4
# 99 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_strings.h" 2 3 4
# 223 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_string.h" 2 3 4





# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/secure/_string.h" 1 3 4
# 32 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/secure/_string.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 33 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/secure/_string.h" 2 3 4
# 229 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/_string.h" 2 3 4
# 59 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/string.h" 2 3 4
# 47 "WinQuake/quakedef.h" 2
# 67 "WinQuake/quakedef.h"
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/fcntl.h" 1 3 4
# 23 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/fcntl.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 1 3 4
# 80 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 81 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 2 3 4


# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_size_t.h" 1 3 4
# 84 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 2 3 4
# 116 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_o_sync.h" 1 3 4
# 117 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 2 3 4
# 148 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_o_dsync.h" 1 3 4
# 149 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 2 3 4
# 373 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_s_ifmt.h" 1 3 4
# 374 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 2 3 4
# 393 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 3 4
struct flock {
 off_t l_start;
 off_t l_len;
 pid_t l_pid;
 short l_type;
 short l_whence;
};

# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_timespec.h" 1 3 4
# 33 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_timespec.h" 3 4
struct timespec
{
 __darwin_time_t tv_sec;
 long tv_nsec;
};
# 402 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 2 3 4






struct flocktimeout {
 struct flock fl;
 struct timespec timeout;
};
# 421 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 3 4
struct radvisory {
 off_t ra_offset;
 int ra_count;
};
# 434 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 3 4
typedef struct fsignatures {
 off_t fs_file_start;
 void *fs_blob_start;
 size_t fs_blob_size;



 size_t fs_fsignatures_size;
 char fs_cdhash[20];
 int fs_hash_type;
} fsignatures_t;

typedef struct fsupplement {
 off_t fs_file_start;
 off_t fs_blob_start;
 size_t fs_blob_size;
 int fs_orig_fd;
} fsupplement_t;
# 465 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 3 4
typedef struct fchecklv {
 off_t lv_file_start;
 size_t lv_error_message_size;
 void *lv_error_message;
} fchecklv_t;
# 479 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 3 4
typedef struct fgetsigsinfo {
 off_t fg_file_start;
 int fg_info_request;
 int fg_sig_is_platform;
} fgetsigsinfo_t;
# 494 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 3 4
typedef struct fstore {
 unsigned int fst_flags;
 int fst_posmode;
 off_t fst_offset;
 off_t fst_length;
 off_t fst_bytesalloc;
} fstore_t;


typedef struct fpunchhole {
 unsigned int fp_flags;
 unsigned int reserved;
 off_t fp_offset;
 off_t fp_length;
} fpunchhole_t;


typedef struct ftrimactivefile {
 off_t fta_offset;
 off_t fta_length;
} ftrimactivefile_t;


typedef struct fspecread {
 unsigned int fsr_flags;
 unsigned int reserved;
 off_t fsr_offset;
 off_t fsr_length;
} fspecread_t;




typedef struct fattributiontag {
 unsigned int ft_flags;
 unsigned long long ft_hash;
 char ft_attribution_name[255];
} fattributiontag_t;
# 559 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 3 4
#pragma pack(4)

struct log2phys {
 unsigned int l2p_flags;
 off_t l2p_contigbytes;


 off_t l2p_devoffset;


};

#pragma pack()
# 582 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_filesec_t.h" 1 3 4
# 30 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_filesec_t.h" 3 4
struct _filesec;
typedef struct _filesec *filesec_t;
# 583 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/fcntl.h" 2 3 4

typedef enum {
 FILESEC_OWNER = 1,
 FILESEC_GROUP = 2,
 FILESEC_UUID = 3,
 FILESEC_MODE = 4,
 FILESEC_ACL = 5,
 FILESEC_GRPUUID = 6,


 FILESEC_ACL_RAW = 100,
 FILESEC_ACL_ALLOCSIZE = 101
} filesec_property_t;






int open(const char *, int, ...) __asm("_" "open" );

int openat(int, const char *, int, ...) __asm("_" "openat" ) __attribute__((availability(macosx,introduced=10.10)));

int creat(const char *, mode_t) __asm("_" "creat" );
int fcntl(int, int, ...) __asm("_" "fcntl" );


int openx_np(const char *, int, filesec_t);




int open_dprotected_np( const char *, int, int, int, ...);
int openat_dprotected_np( int, const char *, int, int, int, ...);
int openat_authenticated_np(int, const char *, int, int);
int flock(int, int);
filesec_t filesec_init(void);
filesec_t filesec_dup(filesec_t);
void filesec_free(filesec_t);
int filesec_get_property(filesec_t, filesec_property_t, void *);
int filesec_query_property(filesec_t, filesec_property_t, int *);
int filesec_set_property(filesec_t, filesec_property_t, const void *);
int filesec_unset_property(filesec_t, filesec_property_t) __attribute__((availability(macosx,introduced=10.6)));
# 24 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/fcntl.h" 2 3 4
# 68 "WinQuake/quakedef.h" 2
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/unistd.h" 1 3 4
# 73 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/unistd.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/unistd.h" 1 3 4
# 84 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/unistd.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_posix_vdisable.h" 1 3 4
# 85 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/unistd.h" 2 3 4
# 132 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/unistd.h" 3 4
struct accessx_descriptor {
 unsigned int ad_name_offset;
 int ad_flags;
 int ad_pad[2];
};
# 180 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/unistd.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_size_t.h" 1 3 4
# 181 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/unistd.h" 2 3 4



# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 185 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/unistd.h" 2 3 4



int getattrlistbulk(int, void *, void *, size_t, uint64_t) __attribute__((availability(macosx,introduced=10.10)));
int getattrlistat(int, const char *, void *, void *, size_t, unsigned long) __attribute__((availability(macosx,introduced=10.10)));
int setattrlistat(int, const char *, void *, void *, size_t, uint32_t) __attribute__((availability(macosx,introduced=10.13))) __attribute__((availability(ios,introduced=11.0))) __attribute__((availability(tvos,introduced=11.0))) __attribute__((availability(watchos,introduced=4.0)));
ssize_t freadlink(int, char * restrict, size_t) __attribute__((availability(macos,introduced=13.0))) __attribute__((availability(ios,introduced=16.0))) __attribute__((availability(tvos,introduced=16.0))) __attribute__((availability(watchos,introduced=9.0)));
# 200 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/unistd.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_size_t.h" 1 3 4
# 201 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/unistd.h" 2 3 4



# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_gid_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_gid_t.h" 3 4
typedef __darwin_gid_t gid_t;
# 205 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/unistd.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 206 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/unistd.h" 2 3 4



int faccessat(int, const char *, int, int) __attribute__((availability(macosx,introduced=10.10)));
int fchownat(int, const char *, uid_t, gid_t, int) __attribute__((availability(macosx,introduced=10.10)));
int linkat(int, const char *, int, const char *, int) __attribute__((availability(macosx,introduced=10.10)));
ssize_t readlinkat(int, const char *, char *, size_t) __attribute__((availability(macosx,introduced=10.10)));
int symlinkat(const char *, int, const char *) __attribute__((availability(macosx,introduced=10.10)));
int unlinkat(int, const char *, int) __attribute__((availability(macosx,introduced=10.10)));
# 74 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/unistd.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 75 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/unistd.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/syslimits.h" 1 3 4
# 76 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/unistd.h" 2 3 4






# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_size_t.h" 1 3 4
# 83 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/unistd.h" 2 3 4


# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_useconds_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_useconds_t.h" 3 4
typedef __darwin_useconds_t useconds_t;
# 86 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/unistd.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_null.h" 1 3 4
# 87 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/unistd.h" 2 3 4
# 434 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/unistd.h" 3 4
void _exit(int) __attribute__((__noreturn__));
int access(const char *, int);
unsigned int
  alarm(unsigned int);
int chdir(const char *);
int chown(const char *, uid_t, gid_t);

int close(int) __asm("_" "close" );

int dup(int);
int dup2(int, int);
int execl(const char * __path, const char * __arg0, ...) __attribute__((availability(watchos,unavailable))) __attribute__((availability(tvos,unavailable)));
int execle(const char * __path, const char * __arg0, ...) __attribute__((availability(watchos,unavailable))) __attribute__((availability(tvos,unavailable)));
int execlp(const char * __file, const char * __arg0, ...) __attribute__((availability(watchos,unavailable))) __attribute__((availability(tvos,unavailable)));
int execv(const char * __path, char * const * __argv) __attribute__((availability(watchos,unavailable))) __attribute__((availability(tvos,unavailable)));
int execve(const char * __file, char * const * __argv, char * const * __envp) __attribute__((availability(watchos,unavailable))) __attribute__((availability(tvos,unavailable)));
int execvp(const char * __file, char * const * __argv) __attribute__((availability(watchos,unavailable))) __attribute__((availability(tvos,unavailable)));
pid_t fork(void) __attribute__((availability(watchos,unavailable))) __attribute__((availability(tvos,unavailable)));
long fpathconf(int, int);
char * getcwd(char *, size_t __size);
gid_t getegid(void);
uid_t geteuid(void);
gid_t getgid(void);



int getgroups(int __gidsetsize, gid_t []);

char * getlogin(void);
pid_t getpgrp(void);
pid_t getpid(void);
pid_t getppid(void);
uid_t getuid(void);
int isatty(int);
int link(const char *, const char *);
off_t lseek(int, off_t, int);
long pathconf(const char *, int);

int pause(void) __asm("_" "pause" );

int pipe(int [2]);

ssize_t read(int, void *, size_t __nbyte) __asm("_" "read" );

int rmdir(const char *);
int setgid(gid_t);
int setpgid(pid_t, pid_t);
pid_t setsid(void);
int setuid(uid_t);

unsigned int
  sleep(unsigned int) __asm("_" "sleep" );

long sysconf(int);
pid_t tcgetpgrp(int);
int tcsetpgrp(int, pid_t);
char * ttyname(int);


int ttyname_r(int, char *, size_t __len) __asm("_" "ttyname_r" );




int unlink(const char *);

ssize_t write(int __fd, const void * __buf, size_t __nbyte) __asm("_" "write" );
# 511 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/unistd.h" 3 4
size_t confstr(int, char *, size_t __len) __asm("_" "confstr" );

int getopt(int __argc, char * const [], const char *) __asm("_" "getopt" );

extern char *optarg;
extern int optind, opterr, optopt;
# 542 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/unistd.h" 3 4
__attribute__((__deprecated__)) __attribute__((availability(watchos,unavailable))) __attribute__((availability(tvos,unavailable)))

void * brk(const void *);
int chroot(const char *) ;


char * crypt(const char *, const char *);

void encrypt(char *, int) __asm("_" "encrypt" );



int fchdir(int);
long gethostid(void);
pid_t getpgid(pid_t);
pid_t getsid(pid_t);



int getdtablesize(void) ;
int getpagesize(void) __attribute__((__const__)) ;
char * getpass(const char *) ;




char * getwd(char *) ;


int lchown(const char *, uid_t, gid_t) __asm("_" "lchown" );

int lockf(int, int, off_t) __asm("_" "lockf" );

int nice(int) __asm("_" "nice" );

ssize_t pread(int __fd, void * __buf, size_t __nbyte, off_t __offset) __asm("_" "pread" );

ssize_t pwrite(int __fd, const void * __buf, size_t __nbyte, off_t __offset) __asm("_" "pwrite" );






__attribute__((__deprecated__)) __attribute__((availability(watchos,unavailable))) __attribute__((availability(tvos,unavailable)))

void * sbrk(int);



pid_t setpgrp(void) __asm("_" "setpgrp" );




int setregid(gid_t, gid_t) __asm("_" "setregid" );

int setreuid(uid_t, uid_t) __asm("_" "setreuid" );

void swab(const void * restrict , void * restrict , ssize_t __nbytes);
void sync(void);
int truncate(const char *, off_t);
useconds_t ualarm(useconds_t, useconds_t);
int usleep(useconds_t) __asm("_" "usleep" );


__attribute__((__deprecated__("Use posix_spawn or fork")))

pid_t vfork(void) __attribute__((availability(watchos,unavailable))) __attribute__((availability(tvos,unavailable)));


int fsync(int) __asm("_" "fsync" );

int ftruncate(int, off_t);
int getlogin_r(char *, size_t __namelen);
# 629 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/unistd.h" 3 4
int fchown(int, uid_t, gid_t);
int gethostname(char *, size_t __namelen);
ssize_t readlink(const char * restrict, char * restrict, size_t __bufsize);
int setegid(gid_t);
int seteuid(uid_t);
int symlink(const char *, const char *);
# 643 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/unistd.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/select.h" 1 3 4
# 75 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/select.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_fd_def.h" 1 3 4
# 32 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_fd_def.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 33 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_fd_def.h" 2 3 4
# 50 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_fd_def.h" 3 4
typedef struct fd_set {
 __int32_t fds_bits[((((1024) % ((sizeof(__int32_t) * 8))) == 0) ? ((1024) / ((sizeof(__int32_t) * 8))) : (((1024) / ((sizeof(__int32_t) * 8))) + 1))];
} fd_set;

int __darwin_check_fd_set_overflow(int, const void *, int) __attribute__((availability(macos,introduced=11.0))) __attribute__((availability(ios,introduced=14.0))) __attribute__((availability(tvos,introduced=14.0))) __attribute__((availability(watchos,introduced=7.0)));


inline __attribute__ ((__always_inline__)) int
__darwin_check_fd_set(int _a, const void *_b)
{

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

 if ((uintptr_t)&__darwin_check_fd_set_overflow != (uintptr_t) 0) {



  return __darwin_check_fd_set_overflow(_a, _b, 0);

 } else {
  return 1;
 }

#pragma clang diagnostic pop

}


inline __attribute__ ((__always_inline__)) int
__darwin_fd_isset(int _fd, const struct fd_set *_p)
{
 if (__darwin_check_fd_set(_fd, (const void *) _p)) {
  return _p->fds_bits[(unsigned long)_fd / (sizeof(__int32_t) * 8)] & ((__int32_t)(((unsigned long)1) << ((unsigned long)_fd % (sizeof(__int32_t) * 8))));
 }

 return 0;
}

inline __attribute__ ((__always_inline__)) void
__darwin_fd_set(int _fd, struct fd_set *const _p)
{
 if (__darwin_check_fd_set(_fd, (const void *) _p)) {
  (_p->fds_bits[(unsigned long)_fd / (sizeof(__int32_t) * 8)] |= ((__int32_t)(((unsigned long)1) << ((unsigned long)_fd % (sizeof(__int32_t) * 8)))));
 }
}

inline __attribute__ ((__always_inline__)) void
__darwin_fd_clr(int _fd, struct fd_set *const _p)
{
 if (__darwin_check_fd_set(_fd, (const void *) _p)) {
  (_p->fds_bits[(unsigned long)_fd / (sizeof(__int32_t) * 8)] &= ~((__int32_t)(((unsigned long)1) << ((unsigned long)_fd % (sizeof(__int32_t) * 8)))));
 }
}
# 76 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/select.h" 2 3 4








# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_time_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_time_t.h" 3 4
typedef __darwin_time_t time_t;
# 85 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/select.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_suseconds_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_suseconds_t.h" 3 4
typedef __darwin_suseconds_t suseconds_t;
# 86 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/select.h" 2 3 4
# 100 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/select.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_fd_setsize.h" 1 3 4
# 101 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/select.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_fd_set.h" 1 3 4
# 102 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/select.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_fd_clr.h" 1 3 4
# 103 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/select.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_fd_isset.h" 1 3 4
# 104 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/select.h" 2 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_fd_zero.h" 1 3 4
# 105 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/select.h" 2 3 4


# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_fd_copy.h" 1 3 4
# 108 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/select.h" 2 3 4






int pselect(int, fd_set * restrict, fd_set * restrict,
    fd_set * restrict, const struct timespec * restrict,
    const sigset_t * restrict)




__asm("_" "pselect" )




;




# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_select.h" 1 3 4
# 43 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_select.h" 3 4
int select(int, fd_set * restrict, fd_set * restrict,
    fd_set * restrict, struct timeval * restrict)





__asm("_" "select" )




;
# 132 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/select.h" 2 3 4
# 644 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/unistd.h" 2 3 4



# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_uuid_t.h" 1 3 4
# 31 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/_types/_uuid_t.h" 3 4
typedef __darwin_uuid_t uuid_t;
# 648 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/unistd.h" 2 3 4


void _Exit(int) __attribute__((__noreturn__));
int accessx_np(const struct accessx_descriptor *, size_t __sz, int *, uid_t);
int acct(const char *);
int add_profil(char *, size_t __bufsiz, unsigned long, unsigned int) __attribute__((availability(watchos,unavailable))) __attribute__((availability(tvos,unavailable)));
void endusershell(void);
int execvP(const char * __file, const char * __searchpath, char * const * __argv) __attribute__((availability(watchos,unavailable))) __attribute__((availability(tvos,unavailable)));
char * fflagstostr(unsigned long);
int getdomainname(char *, int __namelen);
int getgrouplist(const char *, int, int *, int *__ngroups);

# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/gethostuuid.h" 1 3 4
# 35 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/gethostuuid.h" 3 4
# 1 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/Availability.h" 1 3 4
# 36 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/gethostuuid.h" 2 3 4





int gethostuuid(uuid_t, const struct timespec *) __attribute__((availability(macos,introduced=10.5))) __attribute__((availability(ios,unavailable))) __attribute__((availability(tvos,unavailable))) __attribute__((availability(watchos,unavailable)));
# 661 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/unistd.h" 2 3 4

mode_t getmode(const void *, mode_t);
int getpeereid(int, uid_t *, gid_t *);
int getsgroups_np(int *, uuid_t);
char * getusershell(void);
int getwgroups_np(int *, uuid_t);
int initgroups(const char *, int);
int issetugid(void);
char * mkdtemp(char *);
int mknod(const char *, mode_t, dev_t);
int mkpath_np(const char *path, mode_t omode) __attribute__((availability(macosx,introduced=10.8)));
int mkpathat_np(int dfd, const char *path, mode_t omode)
  __attribute__((availability(macosx,introduced=10.12))) __attribute__((availability(ios,introduced=10.0)))
  __attribute__((availability(tvos,introduced=10.0))) __attribute__((availability(watchos,introduced=3.0)));
int mkstemp(char *);
int mkstemps(char *, int);
char * mktemp(char *);
int mkostemp(char * path, int oflags)
  __attribute__((availability(macosx,introduced=10.12))) __attribute__((availability(ios,introduced=10.0)))
  __attribute__((availability(tvos,introduced=10.0))) __attribute__((availability(watchos,introduced=3.0)));
int mkostemps(char * path, int slen, int oflags)
  __attribute__((availability(macosx,introduced=10.12))) __attribute__((availability(ios,introduced=10.0)))
  __attribute__((availability(tvos,introduced=10.0))) __attribute__((availability(watchos,introduced=3.0)));

int mkstemp_dprotected_np(char * path, int dpclass, int dpflags)
  __attribute__((availability(macosx,unavailable))) __attribute__((availability(ios,introduced=10.0)))
  __attribute__((availability(tvos,introduced=10.0))) __attribute__((availability(watchos,introduced=3.0)));
char * mkdtempat_np(int dfd, char * path)
  __attribute__((availability(macosx,introduced=10.13))) __attribute__((availability(ios,introduced=11.0)))
  __attribute__((availability(tvos,introduced=11.0))) __attribute__((availability(watchos,introduced=4.0)));
int mkstempsat_np(int dfd, char * path, int slen)
  __attribute__((availability(macosx,introduced=10.13))) __attribute__((availability(ios,introduced=11.0)))
  __attribute__((availability(tvos,introduced=11.0))) __attribute__((availability(watchos,introduced=4.0)));
int mkostempsat_np(int dfd, char * path, int slen, int oflags)
  __attribute__((availability(macosx,introduced=10.13))) __attribute__((availability(ios,introduced=11.0)))
  __attribute__((availability(tvos,introduced=11.0))) __attribute__((availability(watchos,introduced=4.0)));
int nfssvc(int, void *);
int profil(char *, size_t __bufsiz, unsigned long, unsigned int);

__attribute__((__deprecated__("Use of per-thread security contexts is error-prone and discouraged.")))
int pthread_setugid_np(uid_t, gid_t);
int pthread_getugid_np(uid_t *, gid_t *);

int reboot(int);
int revoke(const char *);

__attribute__((__deprecated__)) int rcmd(char * *, int, const char *, const char *, const char *, int *);
__attribute__((__deprecated__)) int rcmd_af(char * *, int, const char *, const char *, const char *, int *,
  int);
__attribute__((__deprecated__)) int rresvport(int *);
__attribute__((__deprecated__)) int rresvport_af(int *, int);
__attribute__((__deprecated__)) int iruserok(unsigned long, int, const char *, const char *);
__attribute__((__deprecated__)) int iruserok_sa(const void *, int, int, const char *, const char *);
__attribute__((__deprecated__)) int ruserok(const char *, int, const char *, const char *);

int setdomainname(const char *, int __namelen);
int setgroups(int, const gid_t *);
void sethostid(long);
int sethostname(const char *, int __namelen);

void setkey(const char *) __asm("_" "setkey" );



int setlogin(const char *);
void *setmode(const char *) __asm("_" "setmode" );
int setrgid(gid_t);
int setruid(uid_t);
int setsgroups_np(int, const uuid_t);
void setusershell(void);
int setwgroups_np(int, const uuid_t);
int strtofflags(char * *, unsigned long *, unsigned long *);
int swapon(const char *);
int ttyslot(void);
int undelete(const char *);
int unwhiteout(const char *);
void * valloc(size_t __size);

__attribute__((availability(watchos,unavailable))) __attribute__((availability(tvos,unavailable)))
__attribute__((availability(ios,deprecated=10.0,message="syscall(2) is unsupported; " "please switch to a supported interface. For SYS_kdebug_trace use kdebug_signpost().")))

__attribute__((availability(macosx,deprecated=10.12,message="syscall(2) is unsupported; " "please switch to a supported interface. For SYS_kdebug_trace use kdebug_signpost().")))

int syscall(int, ...);

extern char *suboptarg;
int getsubopt(char * *, char * const *, char * *);



int fgetattrlist(int,void*,void *,size_t __attrBufSize,unsigned int) __attribute__((availability(macosx,introduced=10.6)));
int fsetattrlist(int,void*,void *,size_t __attrBufSize,unsigned int) __attribute__((availability(macosx,introduced=10.6)));
int getattrlist(const char*,void*,void *,size_t __attrBufSize,unsigned int) __asm("_" "getattrlist" );
int setattrlist(const char*,void*,void *,size_t __attrBufSize,unsigned int) __asm("_" "setattrlist" );
int exchangedata(const char*,const char*,unsigned int) __attribute__((availability(watchos,unavailable))) __attribute__((availability(tvos,unavailable)));
int getdirentriesattr(int,void*,void *,size_t __attrBufSize,unsigned int*,unsigned int*,unsigned int*,unsigned int) __attribute__((availability(watchos,unavailable))) __attribute__((availability(tvos,unavailable)));
# 771 "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/unistd.h" 3 4
struct fssearchblock;
struct searchstate;

int searchfs(const char *, struct fssearchblock *, unsigned long *, unsigned int, unsigned int, struct searchstate *) __attribute__((availability(watchos,unavailable))) __attribute__((availability(tvos,unavailable)));
int fsctl(const char *,unsigned long,void *,unsigned int);
int ffsctl(int,unsigned long,void *,unsigned int) __attribute__((availability(macosx,introduced=10.6)));




int fsync_volume_np(int, int) __attribute__((availability(macosx,introduced=10.8)));
int sync_volume_np(const char *, int) __attribute__((availability(macosx,introduced=10.8)));

extern int optreset;
# 69 "WinQuake/quakedef.h" 2
# 218 "WinQuake/quakedef.h"
# 1 "WinQuake/bspfile.h" 1
# 59 "WinQuake/bspfile.h"
typedef struct
{
 int fileofs, filelen;
} lump_t;
# 82 "WinQuake/bspfile.h"
typedef struct
{
 float mins[3], maxs[3];
 float origin[3];
 int headnode[4];
 int visleafs;
 int firstface, numfaces;
} dmodel_t;

typedef struct
{
 int version;
 lump_t lumps[15];
} dheader_t;

typedef struct
{
 int nummiptex;
 int dataofs[4];
} dmiptexlump_t;


typedef struct miptex_s
{
 char name[16];
 unsigned width, height;
 unsigned offsets[4];
} miptex_t;


typedef struct
{
 float point[3];
} dvertex_t;
# 128 "WinQuake/bspfile.h"
typedef struct
{
 float normal[3];
 float dist;
 int type;
} dplane_t;
# 155 "WinQuake/bspfile.h"
typedef struct
{
 int planenum;
 short children[2];
 short mins[3];
 short maxs[3];
 unsigned short firstface;
 unsigned short numfaces;
} dnode_t;

typedef struct
{
 int planenum;
 short children[2];
} dclipnode_t;


typedef struct texinfo_s
{
 float vecs[2][4];
 int miptex;
 int flags;
} texinfo_t;




typedef struct
{
 unsigned short v[2];
} dedge_t;


typedef struct
{
 short planenum;
 short side;

 int firstedge;
 short numedges;
 short texinfo;


 byte styles[4];
 int lightofs;
} dface_t;
# 213 "WinQuake/bspfile.h"
typedef struct
{
 int contents;
 int visofs;

 short mins[3];
 short maxs[3];

 unsigned short firstmarksurface;
 unsigned short nummarksurfaces;

 byte ambient_level[4];
} dleaf_t;
# 219 "WinQuake/quakedef.h" 2
# 1 "WinQuake/common.h" 1
# 23 "WinQuake/common.h"
typedef unsigned char byte;






typedef enum {false, true} qboolean;



typedef struct sizebuf_s
{
 qboolean allowoverflow;
 qboolean overflowed;
 byte *data;
 int maxsize;
 int cursize;
} sizebuf_t;

void SZ_Alloc (sizebuf_t *buf, int startsize);
void SZ_Free (sizebuf_t *buf);
void SZ_Clear (sizebuf_t *buf);
void *SZ_GetSpace (sizebuf_t *buf, int length);
void SZ_Write (sizebuf_t *buf, void *data, int length);
void SZ_Print (sizebuf_t *buf, char *data);



typedef struct link_s
{
 struct link_s *prev, *next;
} link_t;


void ClearLink (link_t *l);
void RemoveLink (link_t *l);
void InsertLinkBefore (link_t *l, link_t *before);
void InsertLinkAfter (link_t *l, link_t *after);
# 88 "WinQuake/common.h"
extern qboolean bigendien;

extern short (*BigShort) (short l);
extern short (*LittleShort) (short l);
extern int (*BigLong) (int l);
extern int (*LittleLong) (int l);
extern float (*BigFloat) (float l);
extern float (*LittleFloat) (float l);



void MSG_WriteChar (sizebuf_t *sb, int c);
void MSG_WriteByte (sizebuf_t *sb, int c);
void MSG_WriteShort (sizebuf_t *sb, int c);
void MSG_WriteLong (sizebuf_t *sb, int c);
void MSG_WriteFloat (sizebuf_t *sb, float f);
void MSG_WriteString (sizebuf_t *sb, char *s);
void MSG_WriteCoord (sizebuf_t *sb, float f);
void MSG_WriteAngle (sizebuf_t *sb, float f);

extern int msg_readcount;
extern qboolean msg_badread;

void MSG_BeginReading (void);
int MSG_ReadChar (void);
int MSG_ReadByte (void);
int MSG_ReadShort (void);
int MSG_ReadLong (void);
float MSG_ReadFloat (void);
char *MSG_ReadString (void);

float MSG_ReadCoord (void);
float MSG_ReadAngle (void);



void Q_memset (void *dest, int fill, int count);
void Q_memcpy (void *dest, void *src, int count);
int Q_memcmp (void *m1, void *m2, int count);
void Q_strcpy (char *dest, char *src);
void Q_strncpy (char *dest, char *src, int count);
int Q_strlen (char *str);
char *Q_strrchr (char *s, char c);
void Q_strcat (char *dest, char *src);
int Q_strcmp (char *s1, char *s2);
int Q_strncmp (char *s1, char *s2, int count);
int Q_strcasecmp (char *s1, char *s2);
int Q_strncasecmp (char *s1, char *s2, int n);
int Q_atoi (char *str);
float Q_atof (char *str);



extern char com_token[1024];
extern qboolean com_eof;

char *COM_Parse (char *data);


extern int com_argc;
extern char **com_argv;

int COM_CheckParm (char *parm);
void COM_Init (char *path);
void COM_InitArgv (int argc, char **argv);

char *COM_SkipPath (char *pathname);
void COM_StripExtension (char *in, char *out);
void COM_FileBase (char *in, char *out);
void COM_DefaultExtension (char *path, char *extension);

char *va(char *format, ...);





extern int com_filesize;
struct cache_user_s;

extern char com_gamedir[128];

void COM_WriteFile (char *filename, void *data, int len);
int COM_OpenFile (char *filename, int *hndl);
int COM_FOpenFile (char *filename, FILE **file);
void COM_CloseFile (int h);

byte *COM_LoadStackFile (char *path, void *buffer, int bufsize);
byte *COM_LoadTempFile (char *path);
byte *COM_LoadHunkFile (char *path);
void COM_LoadCacheFile (char *path, struct cache_user_s *cu);


extern struct cvar_s registered;

extern qboolean standard_quake, rogue, hipnotic;
# 220 "WinQuake/quakedef.h" 2
# 1 "WinQuake/mathlib.h" 1
# 22 "WinQuake/mathlib.h"
typedef float vec_t;
typedef vec_t vec3_t[3];
typedef vec_t vec5_t[5];

typedef int fixed4_t;
typedef int fixed8_t;
typedef int fixed16_t;





struct mplane_s;

extern vec3_t vec3_origin;
extern int nanmask;
# 46 "WinQuake/mathlib.h"
void VectorMA (vec3_t veca, float scale, vec3_t vecb, vec3_t vecc);

vec_t _DotProduct (vec3_t v1, vec3_t v2);
void _VectorSubtract (vec3_t veca, vec3_t vecb, vec3_t out);
void _VectorAdd (vec3_t veca, vec3_t vecb, vec3_t out);
void _VectorCopy (vec3_t in, vec3_t out);

int VectorCompare (vec3_t v1, vec3_t v2);
vec_t Length (vec3_t v);
void CrossProduct (vec3_t v1, vec3_t v2, vec3_t cross);
float VectorNormalize (vec3_t v);
void VectorInverse (vec3_t v);
void VectorScale (vec3_t in, vec_t scale, vec3_t out);
int Q_log2(int val);

void R_ConcatRotations (float in1[3][3], float in2[3][3], float out[3][3]);
void R_ConcatTransforms (float in1[3][4], float in2[3][4], float out[3][4]);

void FloorDivMod (double numer, double denom, int *quotient,
  int *rem);
fixed16_t Invert24To16(fixed16_t val);
int GreatestCommonDivisor (int i1, int i2);

void AngleVectors (vec3_t angles, vec3_t forward, vec3_t right, vec3_t up);
int BoxOnPlaneSide (vec3_t emins, vec3_t emaxs, struct mplane_s *plane);
float anglemod(float a);
# 221 "WinQuake/quakedef.h" 2
# 1 "WinQuake/sys.h" 1
# 29 "WinQuake/sys.h"
int Sys_FileOpenRead (char *path, int *hndl);

int Sys_FileOpenWrite (char *path);
void Sys_FileClose (int handle);
void Sys_FileSeek (int handle, int position);
int Sys_FileRead (int handle, void *dest, int count);
int Sys_FileWrite (int handle, void *data, int count);
int Sys_FileTime (char *path);
void Sys_mkdir (char *path);




void Sys_MakeCodeWriteable (unsigned long startaddr, unsigned long length);




void Sys_DebugLog(char *file, char *fmt, ...);

void Sys_Error (char *error, ...);


void Sys_Printf (char *fmt, ...);


void Sys_Quit (void);

double Sys_FloatTime (void);

char *Sys_ConsoleInput (void);

void Sys_Sleep (void);



void Sys_SendKeyEvents (void);


void Sys_LowFPPrecision (void);
void Sys_HighFPPrecision (void);
void Sys_SetFPCW (void);
# 222 "WinQuake/quakedef.h" 2
# 1 "WinQuake/vid.h" 1
# 26 "WinQuake/vid.h"
typedef byte pixel_t;

typedef struct vrect_s
{
 int x,y,width,height;
 struct vrect_s *pnext;
} vrect_t;

typedef struct
{
 pixel_t *buffer;
 pixel_t *colormap;
 unsigned short *colormap16;
 int fullbright;
 unsigned rowbytes;
 unsigned width;
 unsigned height;
 float aspect;
 int numpages;
 int recalc_refdef;
 pixel_t *conbuffer;
 int conrowbytes;
 unsigned conwidth;
 unsigned conheight;
 int maxwarpwidth;
 int maxwarpheight;
 pixel_t *direct;

} viddef_t;

extern viddef_t vid;
extern unsigned short d_8to16table[256];
extern unsigned d_8to24table[256];
extern void (*vid_menudrawfn)(void);
extern void (*vid_menukeyfn)(int key);

void VID_SetPalette (unsigned char *palette);


void VID_ShiftPalette (unsigned char *palette);


void VID_Init (unsigned char *palette);




void VID_Shutdown (void);


void VID_Update (vrect_t *rects);


int VID_SetMode (int modenum, unsigned char *palette);



void VID_HandlePause (qboolean pause);
# 223 "WinQuake/quakedef.h" 2
# 1 "WinQuake/zone.h" 1
# 86 "WinQuake/zone.h"
void Memory_Init (void *buf, int size);

void Z_Free (void *ptr);
void *Z_Malloc (int size);
void *Z_TagMalloc (int size, int tag);

void Z_DumpHeap (void);
void Z_CheckHeap (void);
int Z_FreeMemory (void);

void *Hunk_Alloc (int size);
void *Hunk_AllocName (int size, char *name);

void *Hunk_HighAllocName (int size, char *name);

int Hunk_LowMark (void);
void Hunk_FreeToLowMark (int mark);

int Hunk_HighMark (void);
void Hunk_FreeToHighMark (int mark);

void *Hunk_TempAlloc (int size);

void Hunk_Check (void);

typedef struct cache_user_s
{
 void *data;
} cache_user_t;

void Cache_Flush (void);

void *Cache_Check (cache_user_t *c);



void Cache_Free (cache_user_t *c);

void *Cache_Alloc (cache_user_t *c, int size, char *name);



void Cache_Report (void);
# 224 "WinQuake/quakedef.h" 2

typedef struct {
  vec3_t origin;
  vec3_t angles;
  int modelindex;
  int frame;
  int colormap;
  int skin;
  int effects;
} entity_state_t;

# 1 "WinQuake/client.h" 1
# 22 "WinQuake/client.h"
typedef struct
{
 vec3_t viewangles;


 float forwardmove;
 float sidemove;
 float upmove;



} usercmd_t;

typedef struct
{
 int length;
 char map[64];
} lightstyle_t;

typedef struct
{
 char name[32];
 float entertime;
 int frags;
 int colors;
 byte translations[(1 << 6)*256];
} scoreboard_t;

typedef struct
{
 int destcolor[3];
 int percent;
} cshift_t;
# 72 "WinQuake/client.h"
typedef struct
{
 vec3_t origin;
 float radius;
 float die;
 float decay;
 float minlight;
 int key;



} dlight_t;



typedef struct
{
 int entity;
 struct model_s *model;
 float endtime;
 vec3_t start, end;
} beam_t;







typedef enum {
ca_dedicated,
ca_disconnected,
ca_connected
} cactive_t;





typedef struct
{
 cactive_t state;


 char mapstring[64];
 char spawnparms[2048];


 int demonum;
 char demos[8][16];



 qboolean demorecording;
 qboolean demoplayback;
 qboolean timedemo;
 int forcetrack;
 FILE *demofile;
 int td_lastframe;
 int td_startframe;
 float td_starttime;



 int signon;
 struct qsocket_s *netcon;
 sizebuf_t message;

} client_static_t;

extern client_static_t cls;





typedef struct
{
 int movemessages;



 usercmd_t cmd;


 int stats[32];
 int items;
 float item_gettime[32];
 float faceanimtime;

 cshift_t cshifts[4];
 cshift_t prev_cshifts[4];





 vec3_t mviewangles[2];

 vec3_t viewangles;

 vec3_t mvelocity[2];

 vec3_t velocity;

 vec3_t punchangle;


 float idealpitch;
 float pitchvel;
 qboolean nodrift;
 float driftmove;
 double laststop;

 float viewheight;
 float crouch;

 qboolean paused;
 qboolean onground;
 qboolean inwater;

 int intermission;
 int completed_time;

 double mtime[2];
 double time;


 double oldtime;



 float last_received_message;




 struct model_s *model_precache[256];
 struct sfx_s *sound_precache[256];

 char levelname[40];
 int viewentity;
 int maxclients;
 int gametype;


 struct model_s *worldmodel;
 struct efrag_s *free_efrags;
 int num_entities;
 int num_statics;
 entity_t viewent;

 int cdtrack, looptrack;


 scoreboard_t *scores;







} client_state_t;





extern cvar_t cl_name;
extern cvar_t cl_color;

extern cvar_t cl_upspeed;
extern cvar_t cl_forwardspeed;
extern cvar_t cl_backspeed;
extern cvar_t cl_sidespeed;

extern cvar_t cl_movespeedkey;

extern cvar_t cl_yawspeed;
extern cvar_t cl_pitchspeed;

extern cvar_t cl_anglespeedkey;

extern cvar_t cl_autofire;

extern cvar_t cl_shownet;
extern cvar_t cl_nolerp;

extern cvar_t cl_pitchdriftspeed;
extern cvar_t lookspring;
extern cvar_t lookstrafe;
extern cvar_t sensitivity;

extern cvar_t m_pitch;
extern cvar_t m_yaw;
extern cvar_t m_forward;
extern cvar_t m_side;





extern client_state_t cl;


extern efrag_t cl_efrags[640];
extern entity_t cl_entities[600];
extern entity_t cl_static_entities[128];
extern lightstyle_t cl_lightstyle[64];
extern dlight_t cl_dlights[32];
extern entity_t cl_temp_entities[64];
extern beam_t cl_beams[24];






dlight_t *CL_AllocDlight (int key);
void CL_DecayLights (void);

void CL_Init (void);

void CL_EstablishConnection (char *host);
void CL_Signon1 (void);
void CL_Signon2 (void);
void CL_Signon3 (void);
void CL_Signon4 (void);

void CL_Disconnect (void);
void CL_Disconnect_f (void);
void CL_NextDemo (void);


extern int cl_numvisedicts;
extern entity_t *cl_visedicts[256];




typedef struct
{
 int down[2];
 int state;
} kbutton_t;

extern kbutton_t in_mlook, in_klook;
extern kbutton_t in_strafe;
extern kbutton_t in_speed;

void CL_InitInput (void);
void CL_SendCmd (void);
void CL_SendMove (usercmd_t *cmd);

void CL_ParseTEnt (void);
void CL_UpdateTEnts (void);

void CL_ClearState (void);


int CL_ReadFromServer (void);
void CL_WriteToServer (usercmd_t *cmd);
void CL_BaseMove (usercmd_t *cmd);


float CL_KeyState (kbutton_t *key);
char *Key_KeynumToString (int keynum);




void CL_StopPlayback (void);
int CL_GetMessage (void);

void CL_Stop_f (void);
void CL_Record_f (void);
void CL_PlayDemo_f (void);
void CL_TimeDemo_f (void);




void CL_ParseServerMessage (void);
void CL_NewTranslation (int slot);




void V_StartPitchDrift (void);
void V_StopPitchDrift (void);

void V_RenderView (void);
void V_UpdatePalette (void);
void V_Register (void);
void V_ParseDamage (void);
void V_SetContentsColor (int contents);





void CL_InitTEnts (void);
void CL_SignonReply (void);
# 236 "WinQuake/quakedef.h" 2
# 1 "WinQuake/cmd.h" 1
# 38 "WinQuake/cmd.h"
void Cbuf_Init (void);


void Cbuf_AddText (char *text);



void Cbuf_InsertText (char *text);




void Cbuf_Execute (void);
# 69 "WinQuake/cmd.h"
typedef void (*xcommand_t) (void);

typedef enum
{
 src_client,

 src_command
} cmd_source_t;

extern cmd_source_t cmd_source;

void Cmd_Init (void);

void Cmd_AddCommand (char *cmd_name, xcommand_t function);




qboolean Cmd_Exists (char *cmd_name);


char *Cmd_CompleteCommand (char *partial);



int Cmd_Argc (void);
char *Cmd_Argv (int arg);
char *Cmd_Args (void);




int Cmd_CheckParm (char *parm);



void Cmd_TokenizeString (char *text);



void Cmd_ExecuteString (char *text, cmd_source_t src);



void Cmd_ForwardToServer (void);




void Cmd_Print (char *text);
# 237 "WinQuake/quakedef.h" 2
# 1 "WinQuake/cvar.h" 1
# 56 "WinQuake/cvar.h"
typedef struct cvar_s
{
 char *name;
 char *string;
 qboolean archive;
 qboolean server;
 float value;
 struct cvar_s *next;
} cvar_t;

void Cvar_RegisterVariable (cvar_t *variable);



void Cvar_Set (char *var_name, char *value);


void Cvar_SetValue (char *var_name, float value);


float Cvar_VariableValue (char *var_name);


char *Cvar_VariableString (char *var_name);


char *Cvar_CompleteVariable (char *partial);



qboolean Cvar_Command (void);




void Cvar_WriteVariables (FILE *f);



cvar_t *Cvar_FindVar (char *var_name);

extern cvar_t *cvar_vars;
# 238 "WinQuake/quakedef.h" 2
# 1 "WinQuake/draw.h" 1
# 24 "WinQuake/draw.h"
extern qpic_t *draw_disc;

void Draw_Init (void);
void Draw_Character (int x, int y, int num);
void Draw_DebugChar (char num);
void Draw_Pic (int x, int y, qpic_t *pic);
void Draw_TransPic (int x, int y, qpic_t *pic);
void Draw_TransPicTranslate (int x, int y, qpic_t *pic, byte *translation);
void Draw_ConsoleBackground (int lines);
void Draw_BeginDisc (void);
void Draw_EndDisc (void);
void Draw_TileClear (int x, int y, int w, int h);
void Draw_Fill (int x, int y, int w, int h, int c);
void Draw_FadeScreen (void);
void Draw_String (int x, int y, char *str);
qpic_t *Draw_PicFromWad (char *name);
qpic_t *Draw_CachePic (char *path);
# 239 "WinQuake/quakedef.h" 2
# 1 "WinQuake/net.h" 1
# 22 "WinQuake/net.h"
struct qsockaddr
{
 short sa_family;
 unsigned char sa_data[14];
};
# 119 "WinQuake/net.h"
typedef struct qsocket_s
{
 struct qsocket_s *next;
 double connecttime;
 double lastMessageTime;
 double lastSendTime;

 qboolean disconnected;
 qboolean canSend;
 qboolean sendNext;

 int driver;
 int landriver;
 int socket;
 void *driverdata;

 unsigned int ackSequence;
 unsigned int sendSequence;
 unsigned int unreliableSendSequence;
 int sendMessageLength;
 byte sendMessage [8192];

 unsigned int receiveSequence;
 unsigned int unreliableReceiveSequence;
 int receiveMessageLength;
 byte receiveMessage [8192];

 struct qsockaddr addr;
 char address[64];

} qsocket_t;

extern qsocket_t *net_activeSockets;
extern qsocket_t *net_freeSockets;
extern int net_numsockets;

typedef struct
{
 char *name;
 qboolean initialized;
 int controlSock;
 int (*Init) (void);
 void (*Shutdown) (void);
 void (*Listen) (qboolean state);
 int (*OpenSocket) (int port);
 int (*CloseSocket) (int socket);
 int (*Connect) (int socket, struct qsockaddr *addr);
 int (*CheckNewConnections) (void);
 int (*Read) (int socket, byte *buf, int len, struct qsockaddr *addr);
 int (*Write) (int socket, byte *buf, int len, struct qsockaddr *addr);
 int (*Broadcast) (int socket, byte *buf, int len);
 char * (*AddrToString) (struct qsockaddr *addr);
 int (*StringToAddr) (char *string, struct qsockaddr *addr);
 int (*GetSocketAddr) (int socket, struct qsockaddr *addr);
 int (*GetNameFromAddr) (struct qsockaddr *addr, char *name);
 int (*GetAddrFromName) (char *name, struct qsockaddr *addr);
 int (*AddrCompare) (struct qsockaddr *addr1, struct qsockaddr *addr2);
 int (*GetSocketPort) (struct qsockaddr *addr);
 int (*SetSocketPort) (struct qsockaddr *addr, int port);
} net_landriver_t;


extern int net_numlandrivers;
extern net_landriver_t net_landrivers[8];

typedef struct
{
 char *name;
 qboolean initialized;
 int (*Init) (void);
 void (*Listen) (qboolean state);
 void (*SearchForHosts) (qboolean xmit);
 qsocket_t *(*Connect) (char *host);
 qsocket_t *(*CheckNewConnections) (void);
 int (*QGetMessage) (qsocket_t *sock);
 int (*QSendMessage) (qsocket_t *sock, sizebuf_t *data);
 int (*SendUnreliableMessage) (qsocket_t *sock, sizebuf_t *data);
 qboolean (*CanSendMessage) (qsocket_t *sock);
 qboolean (*CanSendUnreliableMessage) (qsocket_t *sock);
 void (*Close) (qsocket_t *sock);
 void (*Shutdown) (void);
 int controlSock;
} net_driver_t;

extern int net_numdrivers;
extern net_driver_t net_drivers[8];

extern int DEFAULTnet_hostport;
extern int net_hostport;

extern int net_driverlevel;
extern cvar_t hostname;
extern char playername[];
extern int playercolor;

extern int messagesSent;
extern int messagesReceived;
extern int unreliableMessagesSent;
extern int unreliableMessagesReceived;

qsocket_t *NET_NewQSocket (void);
void NET_FreeQSocket(qsocket_t *);
double SetNetTime(void);




typedef struct
{
 char name[16];
 char map[16];
 char cname[32];
 int users;
 int maxusers;
 int driver;
 int ldriver;
 struct qsockaddr addr;
} hostcache_t;

extern int hostCacheCount;
extern hostcache_t hostcache[8];
# 266 "WinQuake/net.h"
extern double net_time;
extern sizebuf_t net_message;
extern int net_activeconnections;

void NET_Init (void);
void NET_Shutdown (void);

struct qsocket_s *NET_CheckNewConnections (void);


struct qsocket_s *NET_Connect (char *host);


qboolean NET_CanSendMessage (qsocket_t *sock);



int NET_GetMessage (struct qsocket_s *sock);






int NET_SendMessage (struct qsocket_s *sock, sizebuf_t *data);
int NET_SendUnreliableMessage (struct qsocket_s *sock, sizebuf_t *data);





int NET_SendToAll(sizebuf_t *data, int blocktime);



void NET_Close (struct qsocket_s *sock);
# 310 "WinQuake/net.h"
void NET_Poll(void);


typedef struct _PollProcedure
{
 struct _PollProcedure *next;
 double nextTime;
 void (*procedure)();
 void *arg;
} PollProcedure;

void SchedulePollProcedure(PollProcedure *pp, double timeOffset);

extern qboolean serialAvailable;
extern qboolean ipxAvailable;
extern qboolean tcpipAvailable;
extern char my_ipx_address[64];
extern char my_tcpip_address[64];
extern void (*GetComPortConfig) (int portNumber, int *port, int *irq, int *baud, qboolean *useModem);
extern void (*SetComPortConfig) (int portNumber, int port, int irq, int baud, qboolean useModem);
extern void (*GetModemConfig) (int portNumber, char *dialType, char *clear, char *init, char *hangup);
extern void (*SetModemConfig) (int portNumber, char *dialType, char *clear, char *init, char *hangup);

extern qboolean slistInProgress;
extern qboolean slistSilent;
extern qboolean slistLocal;

void NET_Slist_f (void);
# 240 "WinQuake/quakedef.h" 2
# 1 "WinQuake/progs.h" 1
# 21 "WinQuake/progs.h"
# 1 "WinQuake/pr_comp.h" 1
# 23 "WinQuake/pr_comp.h"
typedef int func_t;
typedef int string_t;

typedef enum {ev_void, ev_string, ev_float, ev_vector, ev_entity, ev_field, ev_function, ev_pointer} etype_t;
# 42 "WinQuake/pr_comp.h"
enum {
 OP_DONE,
 OP_MUL_F,
 OP_MUL_V,
 OP_MUL_FV,
 OP_MUL_VF,
 OP_DIV_F,
 OP_ADD_F,
 OP_ADD_V,
 OP_SUB_F,
 OP_SUB_V,

 OP_EQ_F,
 OP_EQ_V,
 OP_EQ_S,
 OP_EQ_E,
 OP_EQ_FNC,

 OP_NE_F,
 OP_NE_V,
 OP_NE_S,
 OP_NE_E,
 OP_NE_FNC,

 OP_LE,
 OP_GE,
 OP_LT,
 OP_GT,

 OP_LOAD_F,
 OP_LOAD_V,
 OP_LOAD_S,
 OP_LOAD_ENT,
 OP_LOAD_FLD,
 OP_LOAD_FNC,

 OP_ADDRESS,

 OP_STORE_F,
 OP_STORE_V,
 OP_STORE_S,
 OP_STORE_ENT,
 OP_STORE_FLD,
 OP_STORE_FNC,

 OP_STOREP_F,
 OP_STOREP_V,
 OP_STOREP_S,
 OP_STOREP_ENT,
 OP_STOREP_FLD,
 OP_STOREP_FNC,

 OP_RETURN,
 OP_NOT_F,
 OP_NOT_V,
 OP_NOT_S,
 OP_NOT_ENT,
 OP_NOT_FNC,
 OP_IF,
 OP_IFNOT,
 OP_CALL0,
 OP_CALL1,
 OP_CALL2,
 OP_CALL3,
 OP_CALL4,
 OP_CALL5,
 OP_CALL6,
 OP_CALL7,
 OP_CALL8,
 OP_STATE,
 OP_GOTO,
 OP_AND,
 OP_OR,

 OP_BITAND,
 OP_BITOR
};


typedef struct statement_s
{
 unsigned short op;
 short a,b,c;
} dstatement_t;

typedef struct
{
 unsigned short type;

 unsigned short ofs;
 int s_name;
} ddef_t;




typedef struct
{
 int first_statement;
 int parm_start;
 int locals;

 int profile;

 int s_name;
 int s_file;

 int numparms;
 byte parm_size[8];
} dfunction_t;



typedef struct
{
 int version;
 int crc;

 int ofs_statements;
 int numstatements;

 int ofs_globaldefs;
 int numglobaldefs;

 int ofs_fielddefs;
 int numfielddefs;

 int ofs_functions;
 int numfunctions;

 int ofs_strings;
 int numstrings;

 int ofs_globals;
 int numglobals;

 int entityfields;
} dprograms_t;
# 22 "WinQuake/progs.h" 2
# 1 "WinQuake/progdefs.h" 1
# 23 "WinQuake/progdefs.h"
# 1 "WinQuake/progdefs.q1" 1



typedef struct
{ int pad[28];
 int self;
 int other;
 int world;
 float time;
 float frametime;
 float force_retouch;
 string_t mapname;
 float deathmatch;
 float coop;
 float teamplay;
 float serverflags;
 float total_secrets;
 float total_monsters;
 float found_secrets;
 float killed_monsters;
 float parm1;
 float parm2;
 float parm3;
 float parm4;
 float parm5;
 float parm6;
 float parm7;
 float parm8;
 float parm9;
 float parm10;
 float parm11;
 float parm12;
 float parm13;
 float parm14;
 float parm15;
 float parm16;
 vec3_t v_forward;
 vec3_t v_up;
 vec3_t v_right;
 float trace_allsolid;
 float trace_startsolid;
 float trace_fraction;
 vec3_t trace_endpos;
 vec3_t trace_plane_normal;
 float trace_plane_dist;
 int trace_ent;
 float trace_inopen;
 float trace_inwater;
 int msg_entity;
 func_t main;
 func_t StartFrame;
 func_t PlayerPreThink;
 func_t PlayerPostThink;
 func_t ClientKill;
 func_t ClientConnect;
 func_t PutClientInServer;
 func_t ClientDisconnect;
 func_t SetNewParms;
 func_t SetChangeParms;
} globalvars_t;

typedef struct
{
 float modelindex;
 vec3_t absmin;
 vec3_t absmax;
 float ltime;
 float movetype;
 float solid;
 vec3_t origin;
 vec3_t oldorigin;
 vec3_t velocity;
 vec3_t angles;
 vec3_t avelocity;
 vec3_t punchangle;
 string_t classname;
 string_t model;
 float frame;
 float skin;
 float effects;
 vec3_t mins;
 vec3_t maxs;
 vec3_t size;
 func_t touch;
 func_t use;
 func_t think;
 func_t blocked;
 float nextthink;
 int groundentity;
 float health;
 float frags;
 float weapon;
 string_t weaponmodel;
 float weaponframe;
 float currentammo;
 float ammo_shells;
 float ammo_nails;
 float ammo_rockets;
 float ammo_cells;
 float items;
 float takedamage;
 int chain;
 float deadflag;
 vec3_t view_ofs;
 float button0;
 float button1;
 float button2;
 float impulse;
 float fixangle;
 vec3_t v_angle;
 float idealpitch;
 string_t netname;
 int enemy;
 float flags;
 float colormap;
 float team;
 float max_health;
 float teleport_time;
 float armortype;
 float armorvalue;
 float waterlevel;
 float watertype;
 float ideal_yaw;
 float yaw_speed;
 int aiment;
 int goalentity;
 float spawnflags;
 string_t target;
 string_t targetname;
 float dmg_take;
 float dmg_save;
 int dmg_inflictor;
 int owner;
 vec3_t movedir;
 string_t message;
 float sounds;
 string_t noise;
 string_t noise1;
 string_t noise2;
 string_t noise3;
} entvars_t;
# 24 "WinQuake/progdefs.h" 2
# 23 "WinQuake/progs.h" 2

typedef union eval_s
{
 string_t string;
 float _float;
 float vector[3];
 func_t function;
 int _int;
 int edict;
} eval_t;


typedef struct edict_s
{
 qboolean free;
 link_t area;

 int num_leafs;
 short leafnums[16];

 entity_state_t baseline;

 float freetime;
 entvars_t v;

} edict_t;




extern dprograms_t *progs;
extern dfunction_t *pr_functions;
extern char *pr_strings;
extern ddef_t *pr_globaldefs;
extern ddef_t *pr_fielddefs;
extern dstatement_t *pr_statements;
extern globalvars_t *pr_global_struct;
extern float *pr_globals;

extern int pr_edict_size;



void PR_Init (void);

void PR_ExecuteProgram (func_t fnum);
void PR_LoadProgs (void);

void PR_Profile_f (void);

edict_t *ED_Alloc (void);
void ED_Free (edict_t *ed);

char *ED_NewString (char *string);


void ED_Print (edict_t *ed);
void ED_Write (FILE *f, edict_t *ed);
char *ED_ParseEdict (char *data, edict_t *ent);

void ED_WriteGlobals (FILE *f);
void ED_ParseGlobals (char *data);

void ED_LoadFromFile (char *data);




edict_t *EDICT_NUM(int n);
int NUM_FOR_EDICT(edict_t *e);
# 114 "WinQuake/progs.h"
extern int type_size[8];

typedef void (*builtin_t) (void);
extern builtin_t *pr_builtins;
extern int pr_numbuiltins;

extern int pr_argc;

extern qboolean pr_trace;
extern dfunction_t *pr_xfunction;
extern int pr_xstatement;

extern unsigned short pr_crc;

void PR_RunError (char *error, ...);

void ED_PrintEdicts (void);
void ED_PrintNum (int ent);

eval_t *GetEdictFieldValue(edict_t *ed, char *field);
# 241 "WinQuake/quakedef.h" 2
# 1 "WinQuake/protocol.h" 1
# 242 "WinQuake/quakedef.h" 2
# 1 "WinQuake/render.h" 1
# 30 "WinQuake/render.h"
typedef struct efrag_s
{
 struct mleaf_s *leaf;
 struct efrag_s *leafnext;
 struct entity_s *entity;
 struct efrag_s *entnext;
} efrag_t;


typedef struct entity_s
{
 qboolean forcelink;

 int update_type;

 entity_state_t baseline;

 double msgtime;
 vec3_t msg_origins[2];
 vec3_t origin;
 vec3_t msg_angles[2];
 vec3_t angles;
 struct model_s *model;
 struct efrag_s *efrag;
 int frame;
 float syncbase;
 byte *colormap;
 int effects;
 int skinnum;
 int visframe;


 int dlightframe;
 int dlightbits;


 int trivial_accept;
 struct mnode_s *topnode;


} entity_t;


typedef struct
{
 vrect_t vrect;

 vrect_t aliasvrect;
 int vrectright, vrectbottom;
 int aliasvrectright, aliasvrectbottom;
 float vrectrightedge;

 float fvrectx, fvrecty;
 float fvrectx_adj, fvrecty_adj;
 int vrect_x_adj_shift20;
 int vrectright_adj_shift20;
 float fvrectright_adj, fvrectbottom_adj;

 float fvrectright;
 float fvrectbottom;
 float horizontalFieldOfView;

 float xOrigin;
 float yOrigin;

 vec3_t vieworg;
 vec3_t viewangles;

 float fov_x, fov_y;

 int ambientlight;
} refdef_t;





extern int reinit_surfcache;


extern refdef_t r_refdef;
extern vec3_t r_origin, vpn, vright, vup;

extern struct texture_s *r_notexture_mip;


void R_Init (void);
void R_InitTextures (void);
void R_InitEfrags (void);
void R_RenderView (void);
void R_ViewChanged (vrect_t *pvrect, int lineadj, float aspect);

void R_InitSky (struct texture_s *mt);

void R_AddEfrags (entity_t *ent);
void R_RemoveEfrags (entity_t *ent);

void R_NewMap (void);


void R_ParseParticleEffect (void);
void R_RunParticleEffect (vec3_t org, vec3_t dir, int color, int count);
void R_RocketTrail (vec3_t start, vec3_t end, int type);




void R_EntityParticles (entity_t *ent);
void R_BlobExplosion (vec3_t org);
void R_ParticleExplosion (vec3_t org);
void R_ParticleExplosion2 (vec3_t org, int colorStart, int colorLength);
void R_LavaSplash (vec3_t org);
void R_TeleportSplash (vec3_t org);

void R_PushDlights (void);





extern int reinit_surfcache;
extern qboolean r_cache_thrash;

int D_SurfaceCacheForRes (int width, int height);
void D_FlushCaches (void);
void D_DeleteSurfaceCache (void);
void D_InitCaches (void *buffer, int size);
void R_SetVrect (vrect_t *pvrect, vrect_t *pvrectin, int lineadj);
# 243 "WinQuake/quakedef.h" 2
# 1 "WinQuake/sbar.h" 1
# 26 "WinQuake/sbar.h"
extern int sb_lines;

void Sbar_Init (void);

void Sbar_Changed (void);


void Sbar_Draw (void);


void Sbar_IntermissionOverlay (void);


void Sbar_FinaleOverlay (void);
# 244 "WinQuake/quakedef.h" 2
# 1 "WinQuake/screen.h" 1
# 22 "WinQuake/screen.h"
void SCR_Init (void);

void SCR_UpdateScreen (void);


void SCR_SizeUp (void);
void SCR_SizeDown (void);
void SCR_BringDownConsole (void);
void SCR_CenterPrint (char *str);

void SCR_BeginLoadingPlaque (void);
void SCR_EndLoadingPlaque (void);

int SCR_ModalMessage (char *text);

extern float scr_con_current;
extern float scr_conlines;

extern int scr_fullupdate;
extern int sb_lines;

extern int clearnotify;
extern qboolean scr_disabled_for_loading;
extern qboolean scr_skipupdate;

extern cvar_t scr_viewsize;

extern cvar_t scr_viewsize;


extern int scr_copytop;
extern int scr_copyeverything;

extern qboolean block_drawing;

void SCR_UpdateWholeScreen (void);
# 245 "WinQuake/quakedef.h" 2
# 1 "WinQuake/server.h" 1
# 22 "WinQuake/server.h"
typedef struct
{
 int maxclients;
 int maxclientslimit;
 struct client_s *clients;
 int serverflags;
 qboolean changelevel_issued;
} server_static_t;



typedef enum {ss_loading, ss_active} server_state_t;

typedef struct
{
 qboolean active;

 qboolean paused;
 qboolean loadgame;

 double time;

 int lastcheck;
 double lastchecktime;

 char name[64];



 char modelname[64];
 struct model_s *worldmodel;
 char *model_precache[256];
 struct model_s *models[256];
 char *sound_precache[256];
 char *lightstyles[64];
 int num_edicts;
 int max_edicts;
 edict_t *edicts;


 server_state_t state;

 sizebuf_t datagram;
 byte datagram_buf[1024];

 sizebuf_t reliable_datagram;
 byte reliable_datagram_buf[1024];

 sizebuf_t signon;
 byte signon_buf[8192];
} server_t;





typedef struct client_s
{
 qboolean active;
 qboolean spawned;
 qboolean dropasap;
 qboolean privileged;
 qboolean sendsignon;

 double last_message;


 struct qsocket_s *netconnection;

 usercmd_t cmd;
 vec3_t wishdir;

 sizebuf_t message;

 byte msgbuf[8000];
 edict_t *edict;
 char name[32];
 int colors;

 float ping_times[16];
 int num_pings;


 float spawn_parms[16];


 int old_frags;
} client_t;
# 198 "WinQuake/server.h"
extern cvar_t teamplay;
extern cvar_t skill;
extern cvar_t deathmatch;
extern cvar_t coop;
extern cvar_t fraglimit;
extern cvar_t timelimit;

extern server_static_t svs;
extern server_t sv;

extern client_t *host_client;

extern jmp_buf host_abortserver;

extern double host_time;

extern edict_t *sv_player;



void SV_Init (void);

void SV_StartParticle (vec3_t org, vec3_t dir, int color, int count);
void SV_StartSound (edict_t *entity, int channel, char *sample, int volume,
    float attenuation);

void SV_DropClient (qboolean crash);

void SV_SendClientMessages (void);
void SV_ClearDatagram (void);

int SV_ModelIndex (char *name);

void SV_SetIdealPitch (void);

void SV_AddUpdates (void);

void SV_ClientThink (void);
void SV_AddClientToServer (struct qsocket_s *ret);

void SV_ClientPrintf (char *fmt, ...);
void SV_BroadcastPrintf (char *fmt, ...);

void SV_Physics (void);

qboolean SV_CheckBottom (edict_t *ent);
qboolean SV_movestep (edict_t *ent, vec3_t move, qboolean relink);

void SV_WriteClientdataToMessage (edict_t *ent, sizebuf_t *msg);

void SV_MoveToGoal (void);

void SV_CheckForNewClients (void);
void SV_RunClients (void);
void SV_SaveSpawnparms ();



void SV_SpawnServer (char *server);
# 246 "WinQuake/quakedef.h" 2
# 1 "WinQuake/sound.h" 1
# 29 "WinQuake/sound.h"
typedef struct
{
 int left;
 int right;
} portable_samplepair_t;

typedef struct sfx_s
{
 char name[64];
 cache_user_t cache;
} sfx_t;


typedef struct
{
 int length;
 int loopstart;
 int speed;
 int width;
 int stereo;
 byte data[1];
} sfxcache_t;

typedef struct
{
 qboolean gamealive;
 qboolean soundalive;
 qboolean splitbuffer;
 int channels;
 int samples;
 int submission_chunk;
 int samplepos;
 int samplebits;
 int speed;
 unsigned char *buffer;
} dma_t;


typedef struct
{
 sfx_t *sfx;
 int leftvol;
 int rightvol;
 int end;
 int pos;
 int looping;
 int entnum;
 int entchannel;
 vec3_t origin;
 vec_t dist_mult;
 int master_vol;
} channel_t;

typedef struct
{
 int rate;
 int width;
 int channels;
 int loopstart;
 int samples;
 int dataofs;
} wavinfo_t;

void S_Init (void);
void S_Startup (void);
void S_Shutdown (void);
void S_StartSound (int entnum, int entchannel, sfx_t *sfx, vec3_t origin, float fvol, float attenuation);
void S_StaticSound (sfx_t *sfx, vec3_t origin, float vol, float attenuation);
void S_StopSound (int entnum, int entchannel);
void S_StopAllSounds(qboolean clear);
void S_ClearBuffer (void);
void S_Update (vec3_t origin, vec3_t v_forward, vec3_t v_right, vec3_t v_up);
void S_ExtraUpdate (void);

sfx_t *S_PrecacheSound (char *sample);
void S_TouchSound (char *sample);
void S_ClearPrecache (void);
void S_BeginPrecaching (void);
void S_EndPrecaching (void);
void S_PaintChannels(int endtime);
void S_InitPaintChannels (void);


channel_t *SND_PickChannel(int entnum, int entchannel);


void SND_Spatialize(channel_t *ch);


qboolean SNDDMA_Init(void);


int SNDDMA_GetDMAPos(void);


void SNDDMA_Shutdown(void);
# 134 "WinQuake/sound.h"
extern channel_t channels[128];




extern int total_channels;







extern qboolean fakedma;
extern int fakedma_updates;
extern int paintedtime;
extern vec3_t listener_origin;
extern vec3_t listener_forward;
extern vec3_t listener_right;
extern vec3_t listener_up;
extern volatile dma_t *shm;
extern volatile dma_t sn;
extern vec_t sound_nominal_clip_dist;

extern cvar_t loadas8bit;
extern cvar_t bgmvolume;
extern cvar_t volume;

extern qboolean snd_initialized;

extern int snd_blocked;

void S_LocalSound (char *s);
sfxcache_t *S_LoadSound (sfx_t *s);

wavinfo_t GetWavinfo (char *name, byte *wav, int wavlength);

void SND_InitScaletable (void);
void SNDDMA_Submit(void);

void S_AmbientOff (void);
void S_AmbientOn (void);
# 247 "WinQuake/quakedef.h" 2
# 1 "WinQuake/wad.h" 1
# 39 "WinQuake/wad.h"
typedef struct
{
 int width, height;
 byte data[4];
} qpic_t;



typedef struct
{
 char identification[4];
 int numlumps;
 int infotableofs;
} wadinfo_t;

typedef struct
{
 int filepos;
 int disksize;
 int size;
 char type;
 char compression;
 char pad1, pad2;
 char name[16];
} lumpinfo_t;

extern int wad_numlumps;
extern lumpinfo_t *wad_lumps;
extern byte *wad_base;

void W_LoadWadFile (char *filename);
void W_CleanupName (char *in, char *out);
lumpinfo_t *W_GetLumpinfo (char *name);
void *W_GetLumpName (char *name);
void *W_GetLumpNum (int num);

void SwapPic (qpic_t *pic);
# 248 "WinQuake/quakedef.h" 2




# 1 "WinQuake/d_iface.h" 1
# 27 "WinQuake/d_iface.h"
typedef struct
{
 float u, v;
 float s, t;
 float zi;
} emitpoint_t;

typedef enum {
 pt_static, pt_grav, pt_slowgrav, pt_fire, pt_explode, pt_explode2, pt_blob, pt_blob2
} ptype_t;


typedef struct particle_s
{

 vec3_t org;
 float color;

 struct particle_s *next;
 vec3_t vel;
 float ramp;
 float die;
 ptype_t type;
} particle_t;



typedef struct polyvert_s {
 float u, v, zi, s, t;
} polyvert_t;

typedef struct polydesc_s {
 int numverts;
 float nearzi;
 msurface_t *pcurrentface;
 polyvert_t *pverts;
} polydesc_t;


typedef struct finalvert_s {
 int v[6];
 int flags;
 float reserved;
} finalvert_t;


typedef struct
{
 void *pskin;
 maliasskindesc_t *pskindesc;
 int skinwidth;
 int skinheight;
 mtriangle_t *ptriangles;
 finalvert_t *pfinalverts;
 int numtriangles;
 int drawtype;
 int seamfixupX16;
} affinetridesc_t;


typedef struct {
 float u, v, zi, color;
} screenpart_t;

typedef struct
{
 int nump;
 emitpoint_t *pverts;


 mspriteframe_t *pspriteframe;
 vec3_t vup, vright, vpn;
 float nearzi;
} spritedesc_t;

typedef struct
{
 int u, v;
 float zi;
 int color;
} zpointdesc_t;

extern cvar_t r_drawflat;
extern int d_spanpixcount;
extern int r_framecount;

extern qboolean r_drawpolys;

extern qboolean r_drawculledpolys;

extern qboolean r_worldpolysbacktofront;


extern qboolean r_recursiveaffinetriangles;






extern float r_aliasuvscale;

extern int r_pixbytes;
extern qboolean r_dowarp;

extern affinetridesc_t r_affinetridesc;
extern spritedesc_t r_spritedesc;
extern zpointdesc_t r_zpointdesc;
extern polydesc_t r_polydesc;

extern int d_con_indirect;




extern vec3_t r_pright, r_pup, r_ppn;


void D_Aff8Patch (void *pcolormap);
void D_BeginDirectRect (int x, int y, byte *pbitmap, int width, int height);
void D_DisableBackBufferAccess (void);
void D_EndDirectRect (int x, int y, int width, int height);
void D_PolysetDraw (void);
void D_PolysetDrawFinalVerts (finalvert_t *fv, int numverts);
void D_DrawParticle (particle_t *pparticle);
void D_DrawPoly (void);
void D_DrawSprite (void);
void D_DrawSurfaces (void);
void D_DrawZPoint (void);
void D_EnableBackBufferAccess (void);
void D_EndParticles (void);
void D_Init (void);
void D_ViewChanged (void);
void D_SetupFrame (void);
void D_StartParticles (void);
void D_TurnZOn (void);
void D_WarpScreen (void);

void D_FillRect (vrect_t *vrect, int color);
void D_DrawRect (void);
void D_UpdateRects (vrect_t *prect);




void D_PolysetUpdateTables (void);


extern int r_skydirect;
extern byte *r_skysource;
# 185 "WinQuake/d_iface.h"
extern void *acolormap;





typedef struct
{
 pixel_t *surfdat;
 int rowbytes;
 msurface_t *surf;
 fixed8_t lightadj[4];

 texture_t *texture;
 int surfmip;
 int surfwidth;
 int surfheight;
} drawsurf_t;

extern drawsurf_t r_drawsurf;

void R_DrawSurface (void);
void R_GenTile (msurface_t *psurf, void *pdest);
# 222 "WinQuake/d_iface.h"
extern float skyspeed, skyspeed2;
extern float skytime;

extern int c_surf;
extern vrect_t scr_vrect;

extern byte *r_warpbuffer;
# 253 "WinQuake/quakedef.h" 2
# 1 "WinQuake/model.h" 1
# 24 "WinQuake/model.h"
# 1 "WinQuake/modelgen.h" 1
# 52 "WinQuake/modelgen.h"
typedef enum {ST_SYNC=0, ST_RAND } synctype_t;


typedef enum { ALIAS_SINGLE=0, ALIAS_GROUP } aliasframetype_t;

typedef enum { ALIAS_SKIN_SINGLE=0, ALIAS_SKIN_GROUP } aliasskintype_t;

typedef struct {
 int ident;
 int version;
 vec3_t scale;
 vec3_t scale_origin;
 float boundingradius;
 vec3_t eyeposition;
 int numskins;
 int skinwidth;
 int skinheight;
 int numverts;
 int numtris;
 int numframes;
 synctype_t synctype;
 int flags;
 float size;
} mdl_t;



typedef struct {
 int onseam;
 int s;
 int t;
} stvert_t;

typedef struct dtriangle_s {
 int facesfront;
 int vertindex[3];
} dtriangle_t;






typedef struct {
 byte v[3];
 byte lightnormalindex;
} trivertx_t;

typedef struct {
 trivertx_t bboxmin;
 trivertx_t bboxmax;
 char name[16];
} daliasframe_t;

typedef struct {
 int numframes;
 trivertx_t bboxmin;
 trivertx_t bboxmax;
} daliasgroup_t;

typedef struct {
 int numskins;
} daliasskingroup_t;

typedef struct {
 float interval;
} daliasinterval_t;

typedef struct {
 float interval;
} daliasskininterval_t;

typedef struct {
 aliasframetype_t type;
} daliasframetype_t;

typedef struct {
 aliasskintype_t type;
} daliasskintype_t;
# 25 "WinQuake/model.h" 2
# 1 "WinQuake/spritegn.h" 1
# 70 "WinQuake/spritegn.h"
typedef struct {
 int ident;
 int version;
 int type;
 float boundingradius;
 int width;
 int height;
 int numframes;
 float beamlength;
 synctype_t synctype;
} dsprite_t;







typedef struct {
 int origin[2];
 int width;
 int height;
} dspriteframe_t;

typedef struct {
 int numframes;
} dspritegroup_t;

typedef struct {
 float interval;
} dspriteinterval_t;

typedef enum { SPR_SINGLE=0, SPR_GROUP } spriteframetype_t;

typedef struct {
 spriteframetype_t type;
} dspriteframetype_t;
# 26 "WinQuake/model.h" 2
# 47 "WinQuake/model.h"
typedef struct
{
 vec3_t position;
} mvertex_t;
# 59 "WinQuake/model.h"
typedef struct mplane_s
{
 vec3_t normal;
 float dist;
 byte type;
 byte signbits;
 byte pad[2];
} mplane_t;

typedef struct texture_s
{
 char name[16];
 unsigned width, height;
 int anim_total;
 int anim_min, anim_max;
 struct texture_s *anim_next;
 struct texture_s *alternate_anims;
 unsigned offsets[4];
} texture_t;
# 88 "WinQuake/model.h"
typedef struct
{
 unsigned short v[2];
 unsigned int cachededgeoffset;
} medge_t;

typedef struct
{
 float vecs[2][4];
 float mipadjust;
 texture_t *texture;
 int flags;
} mtexinfo_t;

typedef struct msurface_s
{
 int visframe;

 int dlightframe;
 int dlightbits;

 mplane_t *plane;
 int flags;

 int firstedge;
 int numedges;


 struct surfcache_s *cachespots[4];

 short texturemins[2];
 short extents[2];

 mtexinfo_t *texinfo;


 byte styles[4];
 byte *samples;
} msurface_t;

typedef struct mnode_s
{

 int contents;
 int visframe;

 short minmaxs[6];

 struct mnode_s *parent;


 mplane_t *plane;
 struct mnode_s *children[2];

 unsigned short firstsurface;
 unsigned short numsurfaces;
} mnode_t;



typedef struct mleaf_s
{

 int contents;
 int visframe;

 short minmaxs[6];

 struct mnode_s *parent;


 byte *compressed_vis;
 efrag_t *efrags;

 msurface_t **firstmarksurface;
 int nummarksurfaces;
 int key;
 byte ambient_sound_level[4];
} mleaf_t;


typedef struct
{
 dclipnode_t *clipnodes;
 mplane_t *planes;
 int firstclipnode;
 int lastclipnode;
 vec3_t clip_mins;
 vec3_t clip_maxs;
} hull_t;
# 189 "WinQuake/model.h"
typedef struct mspriteframe_s
{
 int width;
 int height;
 void *pcachespot;
 float up, down, left, right;
 byte pixels[4];
} mspriteframe_t;

typedef struct
{
 int numframes;
 float *intervals;
 mspriteframe_t *frames[1];
} mspritegroup_t;

typedef struct
{
 spriteframetype_t type;
 mspriteframe_t *frameptr;
} mspriteframedesc_t;

typedef struct
{
 int type;
 int maxwidth;
 int maxheight;
 int numframes;
 float beamlength;
 void *cachespot;
 mspriteframedesc_t frames[1];
} msprite_t;
# 232 "WinQuake/model.h"
typedef struct
{
 aliasframetype_t type;
 trivertx_t bboxmin;
 trivertx_t bboxmax;
 int frame;
 char name[16];
} maliasframedesc_t;

typedef struct
{
 aliasskintype_t type;
 void *pcachespot;
 int skin;
} maliasskindesc_t;

typedef struct
{
 trivertx_t bboxmin;
 trivertx_t bboxmax;
 int frame;
} maliasgroupframedesc_t;

typedef struct
{
 int numframes;
 int intervals;
 maliasgroupframedesc_t frames[1];
} maliasgroup_t;

typedef struct
{
 int numskins;
 int intervals;
 maliasskindesc_t skindescs[1];
} maliasskingroup_t;


typedef struct mtriangle_s {
 int facesfront;
 int vertindex[3];
} mtriangle_t;

typedef struct {
 int model;
 int stverts;
 int skindesc;
 int triangles;
 maliasframedesc_t frames[1];
} aliashdr_t;







typedef enum {mod_brush, mod_sprite, mod_alias} modtype_t;
# 300 "WinQuake/model.h"
typedef struct model_s
{
 char name[64];
 qboolean needload;

 modtype_t type;
 int numframes;
 synctype_t synctype;

 int flags;




 vec3_t mins, maxs;
 float radius;




 int firstmodelsurface, nummodelsurfaces;

 int numsubmodels;
 dmodel_t *submodels;

 int numplanes;
 mplane_t *planes;

 int numleafs;
 mleaf_t *leafs;

 int numvertexes;
 mvertex_t *vertexes;

 int numedges;
 medge_t *edges;

 int numnodes;
 mnode_t *nodes;

 int numtexinfo;
 mtexinfo_t *texinfo;

 int numsurfaces;
 msurface_t *surfaces;

 int numsurfedges;
 int *surfedges;

 int numclipnodes;
 dclipnode_t *clipnodes;

 int nummarksurfaces;
 msurface_t **marksurfaces;

 hull_t hulls[4];

 int numtextures;
 texture_t **textures;

 byte *visdata;
 byte *lightdata;
 char *entities;




 cache_user_t cache;

} model_t;



void Mod_Init (void);
void Mod_ClearAll (void);
model_t *Mod_ForName (char *name, qboolean crash);
void *Mod_Extradata (model_t *mod);
void Mod_TouchModel (char *name);

mleaf_t *Mod_PointInLeaf (float *p, model_t *model);
byte *Mod_LeafPVS (mleaf_t *leaf, model_t *model);
# 254 "WinQuake/quakedef.h" 2


# 1 "WinQuake/cdaudio.h" 1
# 21 "WinQuake/cdaudio.h"
int CDAudio_Init(void);
void CDAudio_Play(byte track, qboolean looping);
void CDAudio_Stop(void);
void CDAudio_Pause(void);
void CDAudio_Resume(void);
void CDAudio_Shutdown(void);
void CDAudio_Update(void);
# 257 "WinQuake/quakedef.h" 2
# 1 "WinQuake/console.h" 1
# 24 "WinQuake/console.h"
extern int con_totallines;
extern int con_backscroll;
extern qboolean con_forcedup;
extern qboolean con_initialized;
extern byte *con_chars;
extern int con_notifylines;

void Con_DrawCharacter (int cx, int line, int num);

void Con_CheckResize (void);
void Con_Init (void);
void Con_DrawConsole (int lines, qboolean drawinput);
void Con_Print (char *txt);
void Con_Printf (char *fmt, ...);
void Con_DPrintf (char *fmt, ...);
void Con_SafePrintf (char *fmt, ...);
void Con_Clear_f (void);
void Con_DrawNotify (void);
void Con_ClearNotify (void);
void Con_ToggleConsole_f (void);

void Con_NotifyBox (char *text);
# 258 "WinQuake/quakedef.h" 2
# 1 "WinQuake/crc.h" 1
# 22 "WinQuake/crc.h"
void CRC_Init(unsigned short *crcvalue);
void CRC_ProcessByte(unsigned short *crcvalue, byte data);
unsigned short CRC_Value(unsigned short crcvalue);
# 259 "WinQuake/quakedef.h" 2
# 1 "WinQuake/input.h" 1
# 22 "WinQuake/input.h"
void IN_Init (void);

void IN_Shutdown (void);

void IN_Commands (void);


void IN_Move (usercmd_t *cmd);


void IN_ClearStates (void);
# 260 "WinQuake/quakedef.h" 2
# 1 "WinQuake/keys.h" 1
# 120 "WinQuake/keys.h"
typedef enum {key_game, key_console, key_message, key_menu} keydest_t;

extern keydest_t key_dest;
extern char *keybindings[256];
extern int key_repeats[256];
extern int key_count;
extern int key_lastpress;

void Key_Event (int key, qboolean down);
void Key_Init (void);
void Key_WriteBindings (FILE *f);
void Key_SetBinding (int keynum, char *binding);
void Key_ClearStates (void);
# 261 "WinQuake/quakedef.h" 2
# 1 "WinQuake/menu.h" 1
# 28 "WinQuake/menu.h"
extern int m_activenet;




void M_Init (void);
void M_Keydown (int key);
void M_Draw (void);
void M_ToggleMenu_f (void);
# 262 "WinQuake/quakedef.h" 2
# 1 "WinQuake/view.h" 1
# 22 "WinQuake/view.h"
extern cvar_t v_gamma;

extern byte gammatable[256];
extern byte ramps[3][256];
extern float v_blend[4];

extern cvar_t lcd_x;


void V_Init (void);
void V_RenderView (void);
float V_CalcRoll (vec3_t angles, vec3_t velocity);
void V_UpdatePalette (void);
# 263 "WinQuake/quakedef.h" 2
# 1 "WinQuake/world.h" 1
# 22 "WinQuake/world.h"
typedef struct
{
 vec3_t normal;
 float dist;
} plane_t;

typedef struct
{
 qboolean allsolid;
 qboolean startsolid;
 qboolean inopen, inwater;
 float fraction;
 vec3_t endpos;
 plane_t plane;
 edict_t *ent;
} trace_t;







void SV_ClearWorld (void);


void SV_UnlinkEdict (edict_t *ent);




void SV_LinkEdict (edict_t *ent, qboolean touch_triggers);





int SV_PointContents (vec3_t p);
int SV_TruePointContents (vec3_t p);




edict_t *SV_TestEntityPosition (edict_t *ent);

trace_t SV_Move (vec3_t start, vec3_t mins, vec3_t maxs, vec3_t end, int type, edict_t *passedict);
# 264 "WinQuake/quakedef.h" 2







typedef struct {
  char *basedir;
  char *cachedir;
  int argc;
  char **argv;
  void *membase;
  int memsize;
} quakeparms_t;



extern qboolean noclip_anglehack;




extern quakeparms_t host_parms;

extern cvar_t sys_ticrate;
extern cvar_t sys_nostdout;
extern cvar_t developer;

extern qboolean host_initialized;
extern double host_frametime;
extern byte *host_basepal;
extern byte *host_colormap;
extern int host_framecount;
extern double realtime;


void Host_ClearMemory(void);
void Host_ServerFrame(void);
void Host_InitCommands(void);
void Host_Init(quakeparms_t *parms);
void Host_Shutdown(void);
void Host_Error(char *error, ...);
void Host_EndGame(char *message, ...);
void Host_Frame(float time);
void Host_Quit_f(void);
void Host_ClientCommands(char *fmt, ...);
void Host_ShutdownServer(qboolean crash);

extern qboolean
    msg_suppress_1;

extern int current_skill;



extern qboolean isDedicated;

extern int minimum_memory;




extern cvar_t chase_active;

void Chase_Init(void);
void Chase_Reset(void);
void Chase_Update(void);
# 2 "test.c" 2
int main() { return 0; }
