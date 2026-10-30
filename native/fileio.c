/* GooseCraft system I/O only. Formats, paging and gameplay live in Goose.
   Slice ABI verified against pinned Goose test/packages/pkg_own_c_impl.c. */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#else
#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>
#endif

typedef struct { uint8_t *data; int64_t len; } gc_bytes;

#ifdef _WIN32
static int gc_path(gc_bytes path, wchar_t out[4096]) {
    if (path.len <= 0 || path.len >= 4096 || memchr(path.data, 0, (size_t)path.len)) return 0;
    int n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
        (const char *)path.data, (int)path.len, out, 4095);
    if (!n) return 0;
    out[n] = 0;
    return 1;
}
#else
static int gc_path(gc_bytes path, char out[4096]) {
    if (path.len <= 0 || path.len >= 4096 || memchr(path.data, 0, (size_t)path.len)) return 0;
    memcpy(out, path.data, (size_t)path.len); out[path.len] = 0;
    return 1;
}
#endif

int64_t gc_read_bounded(gc_bytes path, gc_bytes out) {
    if (out.len < 0 || out.len > 2 * 1024 * 1024) return -1;
#ifdef _WIN32
    wchar_t name[4096];
    if (!gc_path(path, name)) return -1;
    FILE *file = _wfopen(name, L"rb");
#else
    char name[4096];
    if (!gc_path(path, name)) return -1;
    FILE *file = fopen(name, "rb");
#endif
    if (!file) return -1;
    size_t got = fread(out.data, 1, (size_t)out.len, file);
    int ok = fgetc(file) == EOF && !ferror(file);
    if (fclose(file) != 0) ok = 0;
    return ok ? (int64_t)got : -1;
}

int32_t gc_read_exact(gc_bytes path, gc_bytes out) {
    if (out.len < 0 || out.len > 16384) return 0;
    return gc_read_bounded(path, out) == out.len;
}

uint64_t gc_world_lock(gc_bytes path) {
#ifdef _WIN32
    wchar_t name[4096];
    if (!gc_path(path, name)) return 0;
    HANDLE h = CreateFileW(name, GENERIC_READ | GENERIC_WRITE, 0, NULL,
        OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    return h == INVALID_HANDLE_VALUE ? 0 : (uint64_t)(uintptr_t)h;
#else
    char name[4096];
    if (!gc_path(path, name)) return 0;
    int fd = open(name, O_CREAT | O_RDWR | O_CLOEXEC, 0600);
    if (fd < 0) return 0;
    if (flock(fd, LOCK_EX | LOCK_NB) != 0) { close(fd); return 0; }
    return (uint64_t)fd + 1;
#endif
}

int32_t gc_world_unlock(uint64_t handle) {
    if (!handle) return 0;
#ifdef _WIN32
    return CloseHandle((HANDLE)(uintptr_t)handle) != 0;
#else
    int fd = (int)(handle - 1);
    int ok = flock(fd, LOCK_UN) == 0;
    return close(fd) == 0 && ok;
#endif
}
