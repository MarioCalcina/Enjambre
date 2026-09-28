#include "flutter_libtransmission.h"

#include <array>
#include <cstdlib>
#include <cstring>
#include <string>

#include "libtransmission/rpcimpl.h"
#include "libtransmission/transmission.h"
#include "libtransmission/utils.h"
#include "libtransmission/variant.h"
#include "libtransmission/quark.h"

using std::string;

tr_session *session;
std::string configDir;

FFI_PLUGIN_EXPORT void init_session(char *config_dir) {
  configDir = config_dir;

  tr_lib_init();
  auto settings = tr_sessionLoadSettings(configDir);
  tr_variantDictAddBool(&settings, TR_KEY_rename_partial_files, false);

  session = tr_sessionInit(configDir.c_str(), false, settings);

  tr_ctor *ctor = tr_ctorNew(session);
  tr_sessionLoadTorrents(session, ctor);
  tr_ctorFree(ctor);
}

FFI_PLUGIN_EXPORT void close_session() {
  save_settings();
  tr_sessionClose(session);
}

FFI_PLUGIN_EXPORT void request_async(int64_t request_id, char *json_string, response_callback cb) {
  // Not parsed inplace, so that the variant owns its strings rather than
  // holding views on a buffer that dies with this call.
  auto request = tr_variant_serde::json().parse(std::string(json_string)).value_or(tr_variant{});

  tr_rpc_request_exec(session, request, [request_id, cb](tr_variant&& resp) {
    auto const value = tr_variant_serde::json().compact().to_string(resp);
    auto *response = static_cast<char *>(std::malloc(value.length() + 1));
    std::memcpy(response, value.c_str(), value.length() + 1);
    cb(request_id, response);
  });
}

FFI_PLUGIN_EXPORT void free_response(char *json) {
  std::free(json);
}

FFI_PLUGIN_EXPORT void save_settings() {
  tr_variant settings;

  tr_variantInitDict(&settings, 0);
  tr_sessionSaveSettings(session, configDir.c_str(), settings);
}

FFI_PLUGIN_EXPORT void reset_settings() {
  auto default_settings = tr_sessionGetDefaultSettings();
  tr_variantDictAddBool(&default_settings, TR_KEY_rename_partial_files, false);
  tr_sessionSet(session, default_settings);
  tr_sessionSaveSettings(session, configDir.c_str(), default_settings);
}
