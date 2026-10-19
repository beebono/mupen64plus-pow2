// rg35xxsp bundle only: the g++-12 headers (parallel-rsp) reference std::__throw_bad_array_new_length (GLIBCXX_3.4.29), which the
// sysroot's static GCC 10 libstdc++.a lacks.  Weak, so a libstdc++ that has it wins.
#include <new>
namespace std { __attribute__((weak)) void __throw_bad_array_new_length() { throw std::bad_array_new_length(); } }

// The sysroot's glibc 2.31 libm exports pow@GLIBC_2.29 as the default; the static libstdc++ (num_put/num_get) pulls it in and would raise the
// bundle's glibc floor to 2.29.  Linked with -Wl,--wrap=pow: bind to the original pow@GLIBC_2.17 instead (same results as before 2.29's rewrite
// for the callers here: locale formatting).
extern "C" double pow_glibc217(double, double);
__asm__(".symver pow_glibc217,pow@GLIBC_2.17");
extern "C" double __wrap_pow(double x, double y) { return pow_glibc217(x, y); }
