#include <iostream>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <libproc.h>
#include <mach-o/dyld.h>
#include <sys/stat.h>
#include <dirent.h>

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

void check_file_detailed(const char* path) {
    struct stat st;
    if (stat(path, &st) == 0) {
        std::cerr << "File: " << path << std::endl;
        std::cerr << "  Size: " << st.st_size << " bytes" << std::endl;
        std::cerr << "  Mode: " << std::oct << st.st_mode << std::dec << std::endl;
        std::cerr << "  Readable: " << (access(path, R_OK) == 0 ? "YES" : "NO") << std::endl;
        
        // Try to open and read first few bytes
        FILE* f = fopen(path, "rb");
        if (f) {
            unsigned char header[16];
            size_t read = fread(header, 1, 16, f);
            std::cerr << "  First " << read << " bytes: ";
            for (size_t i = 0; i < read; i++) {
                std::cerr << std::hex << (int)header[i] << " ";
            }
            std::cerr << std::dec << std::endl;
            fclose(f);
        } else {
            std::cerr << "  ERROR: Cannot open file!" << std::endl;
        }
    } else {
        std::cerr << "File: " << path << " - NOT FOUND" << std::endl;
    }
}

extern "C" {

int stockfish_main_internal(int argc, char **argv);

FFI_EXPORT int stockfish_init()
{
    std::cerr << "========== STOCKFISH INIT START ==========" << std::endl;
    
    pipe(pipes[PARENT_READ_PIPE]);
    pipe(pipes[PARENT_WRITE_PIPE]);
    
    // Get executable path
    char exec_path[1024];
    uint32_t size = sizeof(exec_path);
    
    if (_NSGetExecutablePath(exec_path, &size) == 0) {
        std::cerr << "Executable path: " << exec_path << std::endl;
        
        // Get app bundle path
        char bundle_path[1024];
        strcpy(bundle_path, exec_path);
        char *pos = strstr(bundle_path, "/Contents/MacOS/");
        if (pos) {
            *pos = '\0';
            std::cerr << "App bundle: " << bundle_path << std::endl;
            
            // Build Resources path
            char resources_path[1024];
            snprintf(resources_path, sizeof(resources_path), "%s/Contents/Resources", bundle_path);
            std::cerr << "Resources path: " << resources_path << std::endl;
            
            // Check for NNUE files in Resources with detailed info
            char nnue1[1024], nnue2[1024];
            snprintf(nnue1, sizeof(nnue1), "%s/nn-1111cefa1111.nnue", resources_path);
            snprintf(nnue2, sizeof(nnue2), "%s/nn-37f18f62d772.nnue", resources_path);
            
            std::cerr << "===== CHECKING NNUE FILES =====" << std::endl;
            check_file_detailed(nnue1);
            check_file_detailed(nnue2);
            std::cerr << "=============================" << std::endl;
            
            // Change to Resources directory
            if (chdir(resources_path) == 0) {
                char cwd[1024];
                getcwd(cwd, sizeof(cwd));
                std::cerr << "Changed working directory to: " << cwd << std::endl;
                
                // Check again with relative paths
                std::cerr << "===== CHECKING WITH RELATIVE PATHS =====" << std::endl;
                check_file_detailed("nn-1111cefa1111.nnue");
                check_file_detailed("nn-37f18f62d772.nnue");
                std::cerr << "=========================================" << std::endl;
            } else {
                std::cerr << "ERROR: Failed to change directory!" << std::endl;
            }
        }
    }
    
    std::cerr << "========== STOCKFISH INIT END ==========" << std::endl;
    return 0;
}

FFI_EXPORT int stockfish_main()
{
    std::cerr << "========== STOCKFISH MAIN START ==========" << std::endl;
    
    dup2(CHILD_READ_FD, STDIN_FILENO);
    dup2(CHILD_WRITE_FD, STDOUT_FILENO);
    
    int argc = 1;
    char *argv[] = {(char*)"stockfish", NULL};
    
    std::cerr << "Starting stockfish_main_internal..." << std::endl;
    int exitCode = stockfish_main_internal(argc, argv);
    
    std::cout << QUITOK << std::flush;
    std::cerr << "========== STOCKFISH MAIN END ==========" << std::endl;
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