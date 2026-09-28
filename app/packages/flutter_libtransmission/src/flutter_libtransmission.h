#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT extern "C" __declspec(dllexport)
#elif __cplusplus
#define FFI_PLUGIN_EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

// Initialize a transmission session given a config dir and an app name.
FFI_PLUGIN_EXPORT void init_session(char *config_dir);

// Close transmission session.
FFI_PLUGIN_EXPORT void close_session();

// Invoked when a request completes, possibly from another thread.
// The json buffer must be released with free_response().
typedef void (*response_callback)(int64_t request_id, char *json);

// Submit a request and return immediately. The response is delivered through
// cb, tagged with request_id.
FFI_PLUGIN_EXPORT void request_async(int64_t request_id, char *json_string,
                                     response_callback cb);

// Release a buffer handed to a response_callback.
FFI_PLUGIN_EXPORT void free_response(char *json);

// Save current transmission settings to disk.
FFI_PLUGIN_EXPORT void save_settings();

// Reset all session settings
FFI_PLUGIN_EXPORT void reset_settings();
