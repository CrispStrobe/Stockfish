#include <iostream>
#include <stdio.h>
#include <unistd.h>
#include <string.h>

// Updated paths to point to the shared subfolder
#include "stockfish/bitboard.h"
#include "stockfish/misc.h"
#include "stockfish/position.h"
#include "stockfish/types.h"
#include "stockfish/uci.h"
#include "stockfish/tune.h"

#include "ffi.h"

#define NUM_PIPES 2
#define PARENT_WRITE_PIPE 0
#define PARENT_READ_PIPE 1
#define READ_FD 0
#define WRITE_FD 1
#define PARENT_READ_FD (pipes[PARENT_READ_PIPE][READ_FD])
#define PARENT_WRITE_FD (pipes[PARENT_WRITE_PIPE][WRITE_FD])
#define CHILD_READ_FD (pipes[PARENT_WRITE_PIPE][READ_FD])
#define CHILD_WRITE_FD (pipes[PARENT_READ_PIPE][WRITE_FD])


const char *QUITOK = "quitok\n";
int pipes[NUM_PIPES][2];
char buffer[80];

extern "C" {

    // Stockfish's main function

int stockfish_main_internal(int argc, char **argv);

FFI_EXPORT int stockfish_init()
{
    pipe(pipes[PARENT_READ_PIPE]);
    pipe(pipes[PARENT_WRITE_PIPE]);
    return 0;
}

FFI_EXPORT int stockfish_main()
{
    dup2(CHILD_READ_FD, STDIN_FILENO);
    dup2(CHILD_WRITE_FD, STDOUT_FILENO);

    int argc = 1;
    char *argv[] = {(char*)"stockfish", NULL};
    int exitCode = stockfish_main_internal(argc, argv);

    std::cout << QUITOK << std::flush;
    return exitCode;
}

FFI_EXPORT ssize_t stockfish_stdin_write(char *data)
{
    return write(PARENT_WRITE_FD, data, strlen(data));
}

FFI_EXPORT char *stockfish_stdout_read()
{
    ssize_t count = read(PARENT_READ_FD, buffer, sizeof(buffer) - 1);
    if (count <= 0) return NULL;

    buffer[count] = 0;
    if (strcmp(buffer, QUITOK) == 0) return NULL;

    return buffer;
}

} // extern "C"