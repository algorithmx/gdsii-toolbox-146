/* Minimal mex.h stub for building tests without Octave/Matlab.
   Provides only the symbols used by convert_float_gcc.h (mexErrMsgTxt).
   Do not use this stub for production MEX builds. */
#ifndef MEX_H_STUB
#define MEX_H_STUB
#ifdef __cplusplus
extern "C" {
#endif
static inline void mexErrMsgTxt(const char* msg) {
    /* In test builds, print to stderr and abort. */
    fprintf(stderr, "mexErrMsgTxt: %s\n", msg ? msg : "(null)");
    abort();
}
#ifdef __cplusplus
}
#endif
#endif /* MEX_H_STUB */
