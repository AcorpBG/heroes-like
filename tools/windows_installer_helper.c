#include <windows.h>
#include <bcrypt.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

#define BUFFER_SIZE (64u * 1024u)
#define MAX_MANIFEST_BYTES (1024u * 1024u)
#define MAX_MANIFEST_FILES 64

typedef struct {
    char path[129];
    unsigned long long size;
    char digest[65];
} manifest_row;

static int sha256_file(const wchar_t *path, unsigned char digest[32]) {
    BCRYPT_ALG_HANDLE algorithm = NULL;
    BCRYPT_HASH_HANDLE hash = NULL;
    HANDLE file = INVALID_HANDLE_VALUE;
    PUCHAR object = NULL;
    PUCHAR buffer = NULL;
    DWORD object_size = 0;
    DWORD hash_size = 0;
    DWORD property_size = 0;
    DWORD bytes_read = 0;
    NTSTATUS status;
    int result = 1;

    status = BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, NULL, 0);
    if (status < 0) goto cleanup;
    status = BCryptGetProperty(algorithm, BCRYPT_OBJECT_LENGTH, (PUCHAR)&object_size,
                               sizeof(object_size), &property_size, 0);
    if (status < 0 || object_size == 0) goto cleanup;
    status = BCryptGetProperty(algorithm, BCRYPT_HASH_LENGTH, (PUCHAR)&hash_size,
                               sizeof(hash_size), &property_size, 0);
    if (status < 0 || hash_size != 32) goto cleanup;
    object = (PUCHAR)HeapAlloc(GetProcessHeap(), 0, object_size);
    buffer = (PUCHAR)HeapAlloc(GetProcessHeap(), 0, BUFFER_SIZE);
    if (object == NULL || buffer == NULL) goto cleanup;
    status = BCryptCreateHash(algorithm, &hash, object, object_size, NULL, 0, 0);
    if (status < 0) goto cleanup;
    file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
                       FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN, NULL);
    if (file == INVALID_HANDLE_VALUE) goto cleanup;
    for (;;) {
        if (!ReadFile(file, buffer, BUFFER_SIZE, &bytes_read, NULL)) goto cleanup;
        if (bytes_read == 0) break;
        status = BCryptHashData(hash, buffer, bytes_read, 0);
        if (status < 0) goto cleanup;
    }
    status = BCryptFinishHash(hash, digest, 32, 0);
    if (status < 0) goto cleanup;
    result = 0;

cleanup:
    if (file != INVALID_HANDLE_VALUE) CloseHandle(file);
    if (hash != NULL) BCryptDestroyHash(hash);
    if (object != NULL) HeapFree(GetProcessHeap(), 0, object);
    if (buffer != NULL) HeapFree(GetProcessHeap(), 0, buffer);
    if (algorithm != NULL) BCryptCloseAlgorithmProvider(algorithm, 0);
    return result;
}

static int safe_leaf(const char *value) {
    size_t index, length = strlen(value);
    if (length == 0 || length > 128) return 0;
    for (index = 0; index < length; ++index) {
        char c = value[index];
        if (!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
              (c >= '0' && c <= '9') || c == '.' || c == '_' || c == '-' || c == '+')) return 0;
    }
    return strcmp(value, ".") != 0 && strcmp(value, "..") != 0;
}

static int extract_quoted_value(const char *start, const char *key, char *output, size_t capacity) {
    const char *value = strstr(start, key);
    const char *end;
    size_t length;
    if (value == NULL) return 0;
    value += strlen(key);
    end = strchr(value, '"');
    if (end == NULL) return 0;
    length = (size_t)(end - value);
    if (length == 0 || length >= capacity) return 0;
    memcpy(output, value, length);
    output[length] = '\0';
    return 1;
}

static char *skip_space(char *cursor, const char *end) {
    while (cursor < end && (*cursor == ' ' || *cursor == '\t' || *cursor == '\r' || *cursor == '\n')) ++cursor;
    return cursor;
}

static int consume_literal(char **cursor, const char *end, const char *literal) {
    size_t length = strlen(literal);
    *cursor = skip_space(*cursor, end);
    if ((size_t)(end - *cursor) < length || memcmp(*cursor, literal, length) != 0) return 0;
    *cursor += length;
    return 1;
}

static int consume_quoted(char **cursor, const char *end, char *output, size_t capacity) {
    char *start;
    size_t length;
    *cursor = skip_space(*cursor, end);
    if (*cursor >= end || **cursor != '"') return 0;
    start = ++*cursor;
    while (*cursor < end && **cursor != '"') {
        unsigned char value = (unsigned char)**cursor;
        if (value < 0x20 || value == '\\') return 0;
        ++*cursor;
    }
    if (*cursor >= end) return 0;
    length = (size_t)(*cursor - start);
    if (length == 0 || length >= capacity) return 0;
    memcpy(output, start, length);
    output[length] = '\0';
    ++*cursor;
    return 1;
}

static int valid_version(const char *value) {
    size_t index, length = strlen(value);
    if (length == 0 || length > 128 ||
        !((value[0] >= '0' && value[0] <= '9') ||
          (value[0] >= 'A' && value[0] <= 'Z') ||
          (value[0] >= 'a' && value[0] <= 'z'))) return 0;
    for (index = 1; index < length; ++index) {
        char c = value[index];
        if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') ||
              (c >= 'a' && c <= 'z') || c == '.' || c == '_' ||
              c == '+' || c == '-')) return 0;
    }
    return 1;
}

static int valid_source_revision(const char *value) {
    size_t index, length = strlen(value);
    if (length != 40 && length != 64) return 0;
    for (index = 0; index < length; ++index)
        if (!((value[index] >= '0' && value[index] <= '9') ||
              (value[index] >= 'a' && value[index] <= 'f'))) return 0;
    return 1;
}

static int hex_digest(const char *value) {
    int index;
    if (strlen(value) != 64) return 0;
    for (index = 0; index < 64; ++index) {
        char c = value[index];
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))) return 0;
    }
    return 1;
}

static int read_manifest(const wchar_t *path, const char *platform, manifest_row rows[MAX_MANIFEST_FILES], int *row_count) {
    FILE *handle = _wfopen(path, L"rb");
    char *payload = NULL;
    long length;
    char metadata_value[256];
    char *cursor, *array_end;
    int count = 0;
    int result = 1;
    if (handle == NULL) return 1;
    if (fseek(handle, 0, SEEK_END) != 0) goto cleanup;
    length = ftell(handle);
    if (length <= 0 || (unsigned long)length > MAX_MANIFEST_BYTES) goto cleanup;
    if (fseek(handle, 0, SEEK_SET) != 0) goto cleanup;
    payload = (char *)malloc((size_t)length + 1);
    if (payload == NULL || fread(payload, 1, (size_t)length, handle) != (size_t)length) goto cleanup;
    payload[length] = '\0';
    cursor = payload;
    if (!consume_literal(&cursor, payload + length, "{") ||
        !consume_literal(&cursor, payload + length, "\"files\"") ||
        !consume_literal(&cursor, payload + length, ":") ||
        !consume_literal(&cursor, payload + length, "[")) goto cleanup;
    array_end = strchr(cursor, ']');
    if (array_end == NULL) goto cleanup;
    while ((cursor = skip_space(cursor, array_end)) < array_end) {
        char *object_end, *path_cursor, *sha_cursor, *size_cursor, *value_end;
        char *endptr;
        int prior;
        if (*cursor == ',') {
            if (count == 0) goto cleanup;
            cursor = skip_space(cursor + 1, array_end);
            if (cursor >= array_end) goto cleanup;
        } else if (count > 0) {
            goto cleanup;
        }
        if (cursor >= array_end) break;
        if (*cursor != '{' || (object_end = strchr(cursor, '}')) == NULL || object_end > array_end) goto cleanup;
        path_cursor = strstr(cursor, "\"path\": \"");
        sha_cursor = strstr(cursor, "\"sha256\": \"");
        size_cursor = strstr(cursor, "\"size_bytes\": ");
        if (count >= MAX_MANIFEST_FILES || path_cursor == NULL || sha_cursor == NULL || size_cursor == NULL ||
            path_cursor >= object_end || sha_cursor >= object_end || size_cursor >= object_end ||
            !(path_cursor < sha_cursor && sha_cursor < size_cursor) ||
            !extract_quoted_value(path_cursor, "\"path\": \"", rows[count].path, sizeof(rows[count].path)) ||
            !safe_leaf(rows[count].path) ||
            !extract_quoted_value(sha_cursor, "\"sha256\": \"", rows[count].digest, sizeof(rows[count].digest)) ||
            !hex_digest(rows[count].digest)) goto cleanup;
        value_end = strchr(path_cursor + strlen("\"path\": \""), '"');
        if (value_end == NULL || value_end >= sha_cursor || skip_space(cursor + 1, object_end) != path_cursor ||
            *skip_space(value_end + 1, object_end) != ',' ||
            skip_space(skip_space(value_end + 1, object_end) + 1, object_end) != sha_cursor) goto cleanup;
        value_end = strchr(sha_cursor + strlen("\"sha256\": \""), '"');
        if (value_end == NULL || value_end >= size_cursor || *skip_space(value_end + 1, object_end) != ',' ||
            skip_space(skip_space(value_end + 1, object_end) + 1, object_end) != size_cursor) goto cleanup;
        rows[count].size = _strtoui64(size_cursor + strlen("\"size_bytes\": "), &endptr, 10);
        if (endptr == size_cursor + strlen("\"size_bytes\": ") || rows[count].size == 0 ||
            skip_space(endptr, object_end) != object_end) goto cleanup;
        for (prior = 0; prior < count; ++prior) if (_stricmp(rows[prior].path, rows[count].path) == 0) goto cleanup;
        ++count;
        cursor = object_end + 1;
    }
    cursor = skip_space(cursor, array_end);
    if (count == 0 || cursor != array_end) goto cleanup;
    cursor = array_end + 1;
    if (!consume_literal(&cursor, payload + length, ",") ||
        !consume_literal(&cursor, payload + length, "\"platform\"") ||
        !consume_literal(&cursor, payload + length, ":") ||
        !consume_quoted(&cursor, payload + length, metadata_value, sizeof(metadata_value)) ||
        strcmp(metadata_value, platform) != 0 ||
        !consume_literal(&cursor, payload + length, ",") ||
        !consume_literal(&cursor, payload + length, "\"product_id\"") ||
        !consume_literal(&cursor, payload + length, ":") ||
        !consume_quoted(&cursor, payload + length, metadata_value, sizeof(metadata_value)) ||
        strcmp(metadata_value, "heroes-like") != 0 ||
        !consume_literal(&cursor, payload + length, ",") ||
        !consume_literal(&cursor, payload + length, "\"schema_id\"") ||
        !consume_literal(&cursor, payload + length, ":") ||
        !consume_quoted(&cursor, payload + length, metadata_value, sizeof(metadata_value)) ||
        strcmp(metadata_value, "heroes_like_platform_release_manifest_v2") != 0 ||
        !consume_literal(&cursor, payload + length, ",") ||
        !consume_literal(&cursor, payload + length, "\"source_date_epoch\"") ||
        !consume_literal(&cursor, payload + length, ":")) goto cleanup;
    cursor = skip_space(cursor, payload + length);
    if (cursor >= payload + length || *cursor < '0' || *cursor > '9') goto cleanup;
    {
        char *epoch_end;
        errno = 0;
        (void)_strtoui64(cursor, &epoch_end, 10);
        if (errno == ERANGE || epoch_end == cursor) goto cleanup;
        cursor = epoch_end;
    }
    if (!consume_literal(&cursor, payload + length, ",") ||
        !consume_literal(&cursor, payload + length, "\"source_revision\"") ||
        !consume_literal(&cursor, payload + length, ":") ||
        !consume_quoted(&cursor, payload + length, metadata_value, sizeof(metadata_value)) ||
        !valid_source_revision(metadata_value) ||
        !consume_literal(&cursor, payload + length, ",") ||
        !consume_literal(&cursor, payload + length, "\"version\"") ||
        !consume_literal(&cursor, payload + length, ":") ||
        !consume_quoted(&cursor, payload + length, metadata_value, sizeof(metadata_value)) ||
        !valid_version(metadata_value) ||
        !consume_literal(&cursor, payload + length, "}")) goto cleanup;
    cursor = skip_space(cursor, payload + length);
    if (cursor != payload + length) goto cleanup;
    *row_count = count;
    result = 0;
cleanup:
    if (payload != NULL) free(payload);
    fclose(handle);
    return result;
}

static int join_root_leaf(const wchar_t *root, const char *leaf, wchar_t output[MAX_PATH * 4]) {
    wchar_t wide_leaf[256];
    size_t length = wcslen(root);
    if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, leaf, -1, wide_leaf, 256) == 0) return 1;
    if (length + wcslen(wide_leaf) + 2 >= MAX_PATH * 4) return 1;
    wcscpy(output, root);
    if (length > 0 && output[length - 1] != L'\\' && output[length - 1] != L'/') wcscat(output, L"\\");
    wcscat(output, wide_leaf);
    return 0;
}

static int verify_manifest_root(const wchar_t *manifest_path, const wchar_t *root, const char *platform,
                                int extra_count, wchar_t **extras) {
    manifest_row rows[MAX_MANIFEST_FILES];
    int row_count = 0, index, extra_index, entry_count = 0;
    wchar_t path[MAX_PATH * 4], pattern[MAX_PATH * 4];
    WIN32_FIND_DATAW found;
    HANDLE search;
    DWORD root_attributes = GetFileAttributesW(root);
    if (root_attributes == INVALID_FILE_ATTRIBUTES ||
        !(root_attributes & FILE_ATTRIBUTE_DIRECTORY) ||
        (root_attributes & FILE_ATTRIBUTE_REPARSE_POINT)) return 1;
    if (read_manifest(manifest_path, platform, rows, &row_count) != 0) return 1;
    for (extra_index = 0; extra_index < extra_count; ++extra_index) {
        char utf8_extra[256];
        int prior_extra;
        if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, extras[extra_index], -1,
                                utf8_extra, sizeof(utf8_extra), NULL, NULL) == 0 ||
            !safe_leaf(utf8_extra)) return 1;
        for (index = 0; index < row_count; ++index)
            if (_stricmp(utf8_extra, rows[index].path) == 0) return 1;
        for (prior_extra = 0; prior_extra < extra_index; ++prior_extra)
            if (_wcsicmp(extras[extra_index], extras[prior_extra]) == 0) return 1;
    }
    for (index = 0; index < row_count; ++index) {
        LARGE_INTEGER size;
        unsigned char digest[32];
        char actual[65];
        HANDLE file;
        int byte_index;
        if (join_root_leaf(root, rows[index].path, path) != 0) return 1;
        file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
        if (file == INVALID_HANDLE_VALUE || !GetFileSizeEx(file, &size)) { if (file != INVALID_HANDLE_VALUE) CloseHandle(file); return 1; }
        CloseHandle(file);
        if ((unsigned long long)size.QuadPart != rows[index].size || sha256_file(path, digest) != 0) return 1;
        for (byte_index = 0; byte_index < 32; ++byte_index) sprintf(actual + byte_index * 2, "%02x", digest[byte_index]);
        actual[64] = '\0';
        if (_stricmp(actual, rows[index].digest) != 0) return 1;
    }
    swprintf(pattern, MAX_PATH * 4, L"%ls\\*", root);
    search = FindFirstFileW(pattern, &found);
    if (search == INVALID_HANDLE_VALUE) return 1;
    do {
        int owned = 0;
        char utf8_name[256];
        if (wcscmp(found.cFileName, L".") == 0 || wcscmp(found.cFileName, L"..") == 0) continue;
        if (found.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) { FindClose(search); return 1; }
        if (WideCharToMultiByte(CP_UTF8, 0, found.cFileName, -1, utf8_name, sizeof(utf8_name), NULL, NULL) == 0) { FindClose(search); return 1; }
        for (index = 0; index < row_count; ++index) if (_stricmp(utf8_name, rows[index].path) == 0) owned = 1;
        for (extra_index = 0; extra_index < extra_count; ++extra_index) if (_wcsicmp(found.cFileName, extras[extra_index]) == 0) owned = 1;
        if (!owned) { FindClose(search); return 1; }
        ++entry_count;
    } while (FindNextFileW(search, &found));
    FindClose(search);
    return entry_count == row_count + extra_count ? 0 : 1;
}

static int manifest_is_root_release_manifest(const wchar_t *manifest_path, const wchar_t *root) {
    wchar_t joined[MAX_PATH * 4], expected[MAX_PATH * 4], actual[MAX_PATH * 4];
    if (join_root_leaf(root, "release-manifest.json", joined) != 0) return 0;
    if (GetFullPathNameW(joined, MAX_PATH * 4, expected, NULL) == 0 ||
        GetFullPathNameW(manifest_path, MAX_PATH * 4, actual, NULL) == 0) return 0;
    return _wcsicmp(expected, actual) == 0;
}

static int copy_manifest_root(const wchar_t *manifest_path, const wchar_t *source,
                              const wchar_t *destination, const char *platform) {
    static wchar_t *source_extras[] = {L"release-manifest.json"};
    manifest_row rows[MAX_MANIFEST_FILES];
    int row_count = 0, index, destination_created = 0, result = 1;
    wchar_t source_path[MAX_PATH * 4], destination_path[MAX_PATH * 4];
    DWORD attributes;
    WIN32_FIND_DATAW found;
    HANDLE search;
    if (!manifest_is_root_release_manifest(manifest_path, source) ||
        read_manifest(manifest_path, platform, rows, &row_count) != 0 ||
        verify_manifest_root(manifest_path, source, platform, 1, source_extras) != 0) return 1;
    attributes = GetFileAttributesW(destination);
    if (attributes == INVALID_FILE_ATTRIBUTES) {
        if (!CreateDirectoryW(destination, NULL)) return 1;
        destination_created = 1;
    } else if (!(attributes & FILE_ATTRIBUTE_DIRECTORY) || (attributes & FILE_ATTRIBUTE_REPARSE_POINT)) {
        return 1;
    }
    swprintf(destination_path, MAX_PATH * 4, L"%ls\\*", destination);
    search = FindFirstFileW(destination_path, &found);
    if (search != INVALID_HANDLE_VALUE) {
        do {
            if (wcscmp(found.cFileName, L".") != 0 && wcscmp(found.cFileName, L"..") != 0) {
                FindClose(search);
                goto cleanup;
            }
        } while (FindNextFileW(search, &found));
        FindClose(search);
    }
    for (index = 0; index < row_count; ++index) {
        if (join_root_leaf(source, rows[index].path, source_path) != 0 ||
            join_root_leaf(destination, rows[index].path, destination_path) != 0 ||
            !CopyFileW(source_path, destination_path, TRUE)) goto cleanup;
    }
    if (join_root_leaf(destination, "release-manifest.json", destination_path) != 0 ||
        !CopyFileW(manifest_path, destination_path, TRUE) ||
        verify_manifest_root(destination_path, destination, platform, 1, source_extras) != 0) goto cleanup;
    result = 0;

cleanup:
    if (result != 0) {
        for (index = 0; index < row_count; ++index)
            if (join_root_leaf(destination, rows[index].path, destination_path) == 0) DeleteFileW(destination_path);
        if (join_root_leaf(destination, "release-manifest.json", destination_path) == 0) DeleteFileW(destination_path);
        if (destination_created) RemoveDirectoryW(destination);
    }
    return result;
}

static int remove_manifest_root(const wchar_t *manifest_path, const wchar_t *root, const char *platform,
                                int extra_count, wchar_t **extras) {
    manifest_row rows[MAX_MANIFEST_FILES];
    int row_count = 0, index;
    wchar_t path[MAX_PATH * 4];
    if (!manifest_is_root_release_manifest(manifest_path, root) ||
        read_manifest(manifest_path, platform, rows, &row_count) != 0 ||
        verify_manifest_root(manifest_path, root, platform, extra_count, extras) != 0) return 1;
    for (index = 0; index < row_count; ++index) {
        if (join_root_leaf(root, rows[index].path, path) != 0 || !DeleteFileW(path)) return 1;
    }
    return 0;
}

int wmain(int argc, wchar_t **argv) {
    unsigned char digest[32];
    int index;
    if (argc == 4 && wcscmp(argv[1], L"list") == 0) {
        manifest_row rows[MAX_MANIFEST_FILES];
        int row_count = 0;
        char platform[64];
        if (WideCharToMultiByte(CP_UTF8, 0, argv[3], -1, platform, sizeof(platform), NULL, NULL) == 0 ||
            read_manifest(argv[2], platform, rows, &row_count) != 0) {
            fwprintf(stderr, L"heroes-like installer helper: manifest parsing failed\n");
            return 1;
        }
        for (index = 0; index < row_count; ++index) printf("%s\n", rows[index].path);
        return 0;
    }
    if (argc >= 5 && wcscmp(argv[1], L"verify") == 0) {
        char platform[64];
        if (WideCharToMultiByte(CP_UTF8, 0, argv[4], -1, platform, sizeof(platform), NULL, NULL) == 0 ||
            verify_manifest_root(argv[2], argv[3], platform, argc - 5, argv + 5) != 0) {
            fwprintf(stderr, L"heroes-like installer helper: manifest/root verification failed\n");
            return 1;
        }
        return 0;
    }
    if (argc == 6 && wcscmp(argv[1], L"copy") == 0) {
        char platform[64];
        if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, argv[5], -1,
                                platform, sizeof(platform), NULL, NULL) == 0 ||
            copy_manifest_root(argv[2], argv[3], argv[4], platform) != 0) {
            fwprintf(stderr, L"heroes-like installer helper: verified manifest copy failed\n");
            return 1;
        }
        return 0;
    }
    if (argc >= 5 && wcscmp(argv[1], L"remove") == 0) {
        char platform[64];
        if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, argv[4], -1,
                                platform, sizeof(platform), NULL, NULL) == 0 ||
            remove_manifest_root(argv[2], argv[3], platform, argc - 5, argv + 5) != 0) {
            fwprintf(stderr, L"heroes-like installer helper: verified manifest removal failed\n");
            return 1;
        }
        return 0;
    }
    if (argc != 3 || wcscmp(argv[1], L"sha256") != 0) {
        fwprintf(stderr, L"usage: heroes-like-installer-helper.exe sha256 FILE\n");
        fwprintf(stderr, L"       heroes-like-installer-helper.exe list MANIFEST PLATFORM\n");
        fwprintf(stderr, L"       heroes-like-installer-helper.exe verify MANIFEST ROOT PLATFORM [ALLOWED_EXTRA ...]\n");
        fwprintf(stderr, L"       heroes-like-installer-helper.exe copy MANIFEST SOURCE DESTINATION PLATFORM\n");
        fwprintf(stderr, L"       heroes-like-installer-helper.exe remove MANIFEST ROOT PLATFORM [ALLOWED_EXTRA ...]\n");
        return 2;
    }
    if (sha256_file(argv[2], digest) != 0) {
        fwprintf(stderr, L"heroes-like installer helper: SHA-256 failed\n");
        return 1;
    }
    for (index = 0; index < 32; ++index) printf("%02x", digest[index]);
    printf("\n");
    return 0;
}
