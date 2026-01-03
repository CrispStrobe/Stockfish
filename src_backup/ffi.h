#ifndef STOCKFISH_FFI_H
#define STOCKFISH_FFI_H

#include <stddef.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

// No #include <iostream> or <iosfwd> here!

#if defined(_WIN32)
    #define FFI_EXPORT __declspec(dllexport)
#else
    #define FFI_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

FFI_EXPORT int stockfish_init();
FFI_EXPORT int stockfish_main();
FFI_EXPORT ssize_t stockfish_stdin_write(char *data);
FFI_EXPORT char *stockfish_stdout_read();

#ifdef __cplusplus
}
#endif

#endif