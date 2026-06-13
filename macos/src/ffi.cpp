#include <iostream>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <sys/stat.h>
#include <dirent.h>

#ifdef __APPLE__
#include <libproc.h>
#include <mach-o/dyld.h>
#elif defined(__linux__)
#include <linux/limits.h>
#endif

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
char buffer[4096];

extern "C" {

int stockfish_main_internal(int argc, char **argv);

FFI_EXPORT int stockfish_init()
{
    pipe(pipes[PARENT_READ_PIPE]);
    pipe(pipes[PARENT_WRITE_PIPE]);

#ifdef __APPLE__
    // Get executable path and change to Resources directory for NNUE files
    char exec_path[1024];
    uint32_t size = sizeof(exec_path);

    if (_NSGetExecutablePath(exec_path, &size) == 0) {
        char bundle_path[1024];
        strcpy(bundle_path, exec_path);
        char *pos = strstr(bundle_path, "/Contents/MacOS/");
        if (pos) {
            *pos = '\0';
            char resources_path[1024];
            snprintf(resources_path, sizeof(resources_path), "%s/Contents/Resources", bundle_path);
            chdir(resources_path);
        }
    }
#elif defined(__linux__)
    // On Linux, NNUE files are expected next to the executable or in cwd
    char exec_path[PATH_MAX];
    ssize_t len = readlink("/proc/self/exe", exec_path, sizeof(exec_path) - 1);
    if (len != -1) {
        exec_path[len] = '\0';
        char *dir = strrchr(exec_path, '/');
        if (dir) {
            *dir = '\0';
            chdir(exec_path);
        }
    }
#endif

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
    // std::cerr << "STDIN >> " << data << std::flush;
    return write(PARENT_WRITE_FD, data, strlen(data));
}

FFI_EXPORT char *stockfish_stdout_read()
{
    ssize_t count = read(PARENT_READ_FD, buffer, sizeof(buffer) - 1);
    if (count <= 0) return NULL;
    buffer[count] = 0;
    if (strcmp(buffer, QUITOK) == 0) return NULL;
    // std::cerr << "STDOUT << " << buffer << std::flush;
    return buffer;
}

} // extern "C"