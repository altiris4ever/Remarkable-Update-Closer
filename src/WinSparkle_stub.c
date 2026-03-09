#include <windows.h>

BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason, LPVOID lpReserved) {
    return TRUE;
}

void __cdecl win_sparkle_check_update_with_ui(void) {}
void __cdecl win_sparkle_check_update_with_ui_and_install(void) {}
void __cdecl win_sparkle_check_update_without_ui(void) {}
void __cdecl win_sparkle_cleanup(void) {}
void __cdecl win_sparkle_clear_http_headers(void) {}
int  __cdecl win_sparkle_get_automatic_check_for_updates(void) { return 0; }
long __cdecl win_sparkle_get_last_check_time(void) { return -1; }
int  __cdecl win_sparkle_get_update_check_interval(void) { return 0; }
void __cdecl win_sparkle_init(void) {}
void __cdecl win_sparkle_set_app_build_version(const wchar_t* build) {}
void __cdecl win_sparkle_set_app_details(const wchar_t* company, const wchar_t* app, const wchar_t* version) {}
void __cdecl win_sparkle_set_appcast_url(const char* url) {}
void __cdecl win_sparkle_set_automatic_check_for_updates(int state) {}
void __cdecl win_sparkle_set_can_shutdown_callback(void* callback) {}
void __cdecl win_sparkle_set_config_methods(void* methods) {}
void __cdecl win_sparkle_set_did_find_update_callback(void* callback) {}
void __cdecl win_sparkle_set_did_not_find_update_callback(void* callback) {}
void __cdecl win_sparkle_set_dsa_pub_pem(const char* pem) {}
void __cdecl win_sparkle_set_eddsa_public_key(const char* key) {}
void __cdecl win_sparkle_set_error_callback(void* callback) {}
void __cdecl win_sparkle_set_http_header(const char* name, const char* value) {}
void __cdecl win_sparkle_set_lang(const wchar_t* lang) {}
void __cdecl win_sparkle_set_langid(unsigned short langid) {}
void __cdecl win_sparkle_set_registry_path(const wchar_t* path) {}
void __cdecl win_sparkle_set_shutdown_request_callback(void* callback) {}
void __cdecl win_sparkle_set_update_cancelled_callback(void* callback) {}
void __cdecl win_sparkle_set_update_check_interval(int interval) {}
void __cdecl win_sparkle_set_update_dismissed_callback(void* callback) {}
void __cdecl win_sparkle_set_update_postponed_callback(void* callback) {}
void __cdecl win_sparkle_set_update_skipped_callback(void* callback) {}
void __cdecl win_sparkle_set_user_run_installer_callback(void* callback) {}
