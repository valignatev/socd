//
// This file was auto-generated using the following command:
//
// jai generate.jai
//



XKB_KEYCODE_INVALID :: 0xffffffff;
XKB_LAYOUT_INVALID :: 0xffffffff;
XKB_LEVEL_INVALID :: 0xffffffff;
XKB_MOD_INVALID :: 0xffffffff;
XKB_LED_INVALID :: 0xffffffff;

XKB_KEYCODE_MAX :: 0xffffffff - 1;

XKB_KEYSYM_MAX :: 0x1fffffff;

xkb_context :: struct {}

xkb_keymap :: struct {}

xkb_state :: struct {}

xkb_keycode_t :: u32;

xkb_keysym_t :: u32;

xkb_layout_index_t :: u32;

xkb_layout_mask_t :: u32;

xkb_level_index_t :: u32;

xkb_mod_index_t :: u32;

xkb_mod_mask_t :: u32;

xkb_led_index_t :: u32;

xkb_led_mask_t :: u32;

xkb_rule_names :: struct {
    rules:   *u8;

    model:   *u8;

    layout:  *u8;

    variant: *u8;

    options: *u8;
}

xkb_keysym_get_name :: (keysym: xkb_keysym_t, buffer: *u8, size: u64) -> s32 #foreign libxkbcommon;

xkb_keysym_flags :: enum u32 {
    NO_FLAGS         :: 0;
    CASE_INSENSITIVE :: 1;

    XKB_KEYSYM_NO_FLAGS         :: NO_FLAGS;
    XKB_KEYSYM_CASE_INSENSITIVE :: CASE_INSENSITIVE;
}

xkb_keysym_from_name :: (name: *u8, flags: xkb_keysym_flags) -> xkb_keysym_t #foreign libxkbcommon;

xkb_keysym_to_utf8 :: (keysym: xkb_keysym_t, buffer: *u8, size: u64) -> s32 #foreign libxkbcommon;

xkb_keysym_to_utf32 :: (keysym: xkb_keysym_t) -> u32 #foreign libxkbcommon;

xkb_utf32_to_keysym :: (ucs: u32) -> xkb_keysym_t #foreign libxkbcommon;

xkb_keysym_to_upper :: (ks: xkb_keysym_t) -> xkb_keysym_t #foreign libxkbcommon;

xkb_keysym_to_lower :: (ks: xkb_keysym_t) -> xkb_keysym_t #foreign libxkbcommon;

xkb_context_flags :: enum u32 {
    NO_FLAGS             :: 0;
    NO_DEFAULT_INCLUDES  :: 1;
    NO_ENVIRONMENT_NAMES :: 2;
    NO_SECURE_GETENV     :: 4;

    XKB_CONTEXT_NO_FLAGS             :: NO_FLAGS;
    XKB_CONTEXT_NO_DEFAULT_INCLUDES  :: NO_DEFAULT_INCLUDES;
    XKB_CONTEXT_NO_ENVIRONMENT_NAMES :: NO_ENVIRONMENT_NAMES;
    XKB_CONTEXT_NO_SECURE_GETENV     :: NO_SECURE_GETENV;
}

xkb_context_new :: (flags: xkb_context_flags) -> *xkb_context #foreign libxkbcommon;

xkb_context_ref :: (_context: *xkb_context) -> *xkb_context #foreign libxkbcommon;

xkb_context_unref :: (_context: *xkb_context) -> void #foreign libxkbcommon;

xkb_context_set_user_data :: (_context: *xkb_context, user_data: *void) -> void #foreign libxkbcommon;

xkb_context_get_user_data :: (_context: *xkb_context) -> *void #foreign libxkbcommon;

xkb_context_include_path_append :: (_context: *xkb_context, path: *u8) -> s32 #foreign libxkbcommon;

xkb_context_include_path_append_default :: (_context: *xkb_context) -> s32 #foreign libxkbcommon;

xkb_context_include_path_reset_defaults :: (_context: *xkb_context) -> s32 #foreign libxkbcommon;

xkb_context_include_path_clear :: (_context: *xkb_context) -> void #foreign libxkbcommon;

xkb_context_num_include_paths :: (_context: *xkb_context) -> u32 #foreign libxkbcommon;

xkb_context_include_path_get :: (_context: *xkb_context, index: u32) -> *u8 #foreign libxkbcommon;

xkb_log_level :: enum u32 {
    CRITICAL :: 10;
    ERROR    :: 20;
    WARNING  :: 30;
    INFO     :: 40;
    DEBUG    :: 50;

    XKB_LOG_LEVEL_CRITICAL :: CRITICAL;
    XKB_LOG_LEVEL_ERROR    :: ERROR;
    XKB_LOG_LEVEL_WARNING  :: WARNING;
    XKB_LOG_LEVEL_INFO     :: INFO;
    XKB_LOG_LEVEL_DEBUG    :: DEBUG;
}

xkb_context_set_log_level :: (_context: *xkb_context, level: xkb_log_level) -> void #foreign libxkbcommon;

xkb_context_get_log_level :: (_context: *xkb_context) -> xkb_log_level #foreign libxkbcommon;

xkb_context_set_log_verbosity :: (_context: *xkb_context, verbosity: s32) -> void #foreign libxkbcommon;

xkb_context_get_log_verbosity :: (_context: *xkb_context) -> s32 #foreign libxkbcommon;

xkb_context_set_log_fn :: (_context: *xkb_context, log_fn: #type (_context: *xkb_context, level: xkb_log_level, format: *u8, args: *void) -> void #c_call) -> void #foreign libxkbcommon;

xkb_keymap_compile_flags :: enum u32 {
    XKB_KEYMAP_COMPILE_NO_FLAGS :: 0;
}

xkb_keymap_new_from_names :: (_context: *xkb_context, names: *xkb_rule_names, flags: xkb_keymap_compile_flags) -> *xkb_keymap #foreign libxkbcommon;

xkb_keymap_format :: enum u32 {
    XKB_KEYMAP_FORMAT_TEXT_V1 :: 1;
}

// xkb_keymap_new_from_file :: (_context: *xkb_context, file: *FILE, format: xkb_keymap_format, flags: xkb_keymap_compile_flags) -> *xkb_keymap #foreign libxkbcommon;

xkb_keymap_new_from_string :: (_context: *xkb_context, _string: *u8, format: xkb_keymap_format, flags: xkb_keymap_compile_flags) -> *xkb_keymap #foreign libxkbcommon;

xkb_keymap_new_from_buffer :: (_context: *xkb_context, buffer: *u8, length: u64, format: xkb_keymap_format, flags: xkb_keymap_compile_flags) -> *xkb_keymap #foreign libxkbcommon;

xkb_keymap_ref :: (keymap: *xkb_keymap) -> *xkb_keymap #foreign libxkbcommon;

xkb_keymap_unref :: (keymap: *xkb_keymap) -> void #foreign libxkbcommon;

xkb_keymap_get_as_string :: (keymap: *xkb_keymap, format: xkb_keymap_format) -> *u8 #foreign libxkbcommon;

xkb_keymap_min_keycode :: (keymap: *xkb_keymap) -> xkb_keycode_t #foreign libxkbcommon;

xkb_keymap_max_keycode :: (keymap: *xkb_keymap) -> xkb_keycode_t #foreign libxkbcommon;

xkb_keymap_key_iter_t :: #type (keymap: *xkb_keymap, key: xkb_keycode_t, data: *void) -> void #c_call;

xkb_keymap_key_for_each :: (keymap: *xkb_keymap, iter: xkb_keymap_key_iter_t, data: *void) -> void #foreign libxkbcommon;

xkb_keymap_key_get_name :: (keymap: *xkb_keymap, key: xkb_keycode_t) -> *u8 #foreign libxkbcommon;

xkb_keymap_key_by_name :: (keymap: *xkb_keymap, name: *u8) -> xkb_keycode_t #foreign libxkbcommon;

xkb_keymap_num_mods :: (keymap: *xkb_keymap) -> xkb_mod_index_t #foreign libxkbcommon;

xkb_keymap_mod_get_name :: (keymap: *xkb_keymap, idx: xkb_mod_index_t) -> *u8 #foreign libxkbcommon;

xkb_keymap_mod_get_index :: (keymap: *xkb_keymap, name: *u8) -> xkb_mod_index_t #foreign libxkbcommon;

xkb_keymap_num_layouts :: (keymap: *xkb_keymap) -> xkb_layout_index_t #foreign libxkbcommon;

xkb_keymap_layout_get_name :: (keymap: *xkb_keymap, idx: xkb_layout_index_t) -> *u8 #foreign libxkbcommon;

xkb_keymap_layout_get_index :: (keymap: *xkb_keymap, name: *u8) -> xkb_layout_index_t #foreign libxkbcommon;

xkb_keymap_num_leds :: (keymap: *xkb_keymap) -> xkb_led_index_t #foreign libxkbcommon;

xkb_keymap_led_get_name :: (keymap: *xkb_keymap, idx: xkb_led_index_t) -> *u8 #foreign libxkbcommon;

xkb_keymap_led_get_index :: (keymap: *xkb_keymap, name: *u8) -> xkb_led_index_t #foreign libxkbcommon;

xkb_keymap_num_layouts_for_key :: (keymap: *xkb_keymap, key: xkb_keycode_t) -> xkb_layout_index_t #foreign libxkbcommon;

xkb_keymap_num_levels_for_key :: (keymap: *xkb_keymap, key: xkb_keycode_t, layout: xkb_layout_index_t) -> xkb_level_index_t #foreign libxkbcommon;

xkb_keymap_key_get_mods_for_level :: (keymap: *xkb_keymap, key: xkb_keycode_t, layout: xkb_layout_index_t, level: xkb_level_index_t, masks_out: *xkb_mod_mask_t, masks_size: u64) -> u64 #foreign libxkbcommon;

xkb_keymap_key_get_syms_by_level :: (keymap: *xkb_keymap, key: xkb_keycode_t, layout: xkb_layout_index_t, level: xkb_level_index_t, syms_out: **xkb_keysym_t) -> s32 #foreign libxkbcommon;

xkb_keymap_key_repeats :: (keymap: *xkb_keymap, key: xkb_keycode_t) -> s32 #foreign libxkbcommon;

xkb_state_new :: (keymap: *xkb_keymap) -> *xkb_state #foreign libxkbcommon;

xkb_state_ref :: (state: *xkb_state) -> *xkb_state #foreign libxkbcommon;

xkb_state_unref :: (state: *xkb_state) -> void #foreign libxkbcommon;

xkb_state_get_keymap :: (state: *xkb_state) -> *xkb_keymap #foreign libxkbcommon;

xkb_key_direction :: enum u32 {
    UP   :: 0;
    DOWN :: 1;

    XKB_KEY_UP   :: UP;
    XKB_KEY_DOWN :: DOWN;
}

xkb_state_component :: enum u32 {
    MODS_DEPRESSED   :: 1;
    MODS_LATCHED     :: 2;
    MODS_LOCKED      :: 4;
    MODS_EFFECTIVE   :: 8;
    LAYOUT_DEPRESSED :: 16;
    LAYOUT_LATCHED   :: 32;
    LAYOUT_LOCKED    :: 64;
    LAYOUT_EFFECTIVE :: 128;
    LEDS             :: 256;

    XKB_STATE_MODS_DEPRESSED   :: MODS_DEPRESSED;
    XKB_STATE_MODS_LATCHED     :: MODS_LATCHED;
    XKB_STATE_MODS_LOCKED      :: MODS_LOCKED;
    XKB_STATE_MODS_EFFECTIVE   :: MODS_EFFECTIVE;
    XKB_STATE_LAYOUT_DEPRESSED :: LAYOUT_DEPRESSED;
    XKB_STATE_LAYOUT_LATCHED   :: LAYOUT_LATCHED;
    XKB_STATE_LAYOUT_LOCKED    :: LAYOUT_LOCKED;
    XKB_STATE_LAYOUT_EFFECTIVE :: LAYOUT_EFFECTIVE;
    XKB_STATE_LEDS             :: LEDS;
}

xkb_state_update_key :: (state: *xkb_state, key: xkb_keycode_t, direction: xkb_key_direction) -> xkb_state_component #foreign libxkbcommon;

xkb_state_update_mask :: (state: *xkb_state, depressed_mods: xkb_mod_mask_t, latched_mods: xkb_mod_mask_t, locked_mods: xkb_mod_mask_t, depressed_layout: xkb_layout_index_t, latched_layout: xkb_layout_index_t, locked_layout: xkb_layout_index_t) -> xkb_state_component #foreign libxkbcommon;

xkb_state_key_get_syms :: (state: *xkb_state, key: xkb_keycode_t, syms_out: **xkb_keysym_t) -> s32 #foreign libxkbcommon;

xkb_state_key_get_utf8 :: (state: *xkb_state, key: xkb_keycode_t, buffer: *u8, size: u64) -> s32 #foreign libxkbcommon;

xkb_state_key_get_utf32 :: (state: *xkb_state, key: xkb_keycode_t) -> u32 #foreign libxkbcommon;

xkb_state_key_get_one_sym :: (state: *xkb_state, key: xkb_keycode_t) -> xkb_keysym_t #foreign libxkbcommon;

xkb_state_key_get_layout :: (state: *xkb_state, key: xkb_keycode_t) -> xkb_layout_index_t #foreign libxkbcommon;

xkb_state_key_get_level :: (state: *xkb_state, key: xkb_keycode_t, layout: xkb_layout_index_t) -> xkb_level_index_t #foreign libxkbcommon;

xkb_state_match :: enum u32 {
    ANY           :: 1;
    ALL           :: 2;
    NON_EXCLUSIVE :: 65536;

    XKB_STATE_MATCH_ANY           :: ANY;
    XKB_STATE_MATCH_ALL           :: ALL;
    XKB_STATE_MATCH_NON_EXCLUSIVE :: NON_EXCLUSIVE;
}

xkb_state_serialize_mods :: (state: *xkb_state, components: xkb_state_component) -> xkb_mod_mask_t #foreign libxkbcommon;

xkb_state_serialize_layout :: (state: *xkb_state, components: xkb_state_component) -> xkb_layout_index_t #foreign libxkbcommon;

xkb_state_mod_name_is_active :: (state: *xkb_state, name: *u8, type: xkb_state_component) -> s32 #foreign libxkbcommon;

xkb_state_mod_names_are_active :: (state: *xkb_state, type: xkb_state_component, match: xkb_state_match, __args: ..Any) -> s32 #foreign libxkbcommon;

xkb_state_mod_index_is_active :: (state: *xkb_state, idx: xkb_mod_index_t, type: xkb_state_component) -> s32 #foreign libxkbcommon;

xkb_state_mod_indices_are_active :: (state: *xkb_state, type: xkb_state_component, match: xkb_state_match, __args: ..Any) -> s32 #foreign libxkbcommon;

xkb_consumed_mode :: enum u32 {
    XKB :: 0;
    GTK :: 1;

    XKB_CONSUMED_MODE_XKB :: XKB;
    XKB_CONSUMED_MODE_GTK :: GTK;
}

xkb_state_key_get_consumed_mods2 :: (state: *xkb_state, key: xkb_keycode_t, mode: xkb_consumed_mode) -> xkb_mod_mask_t #foreign libxkbcommon;

xkb_state_key_get_consumed_mods :: (state: *xkb_state, key: xkb_keycode_t) -> xkb_mod_mask_t #foreign libxkbcommon;

xkb_state_mod_index_is_consumed2 :: (state: *xkb_state, key: xkb_keycode_t, idx: xkb_mod_index_t, mode: xkb_consumed_mode) -> s32 #foreign libxkbcommon;

xkb_state_mod_index_is_consumed :: (state: *xkb_state, key: xkb_keycode_t, idx: xkb_mod_index_t) -> s32 #foreign libxkbcommon;

xkb_state_mod_mask_remove_consumed :: (state: *xkb_state, key: xkb_keycode_t, mask: xkb_mod_mask_t) -> xkb_mod_mask_t #foreign libxkbcommon;

xkb_state_layout_name_is_active :: (state: *xkb_state, name: *u8, type: xkb_state_component) -> s32 #foreign libxkbcommon;

xkb_state_layout_index_is_active :: (state: *xkb_state, idx: xkb_layout_index_t, type: xkb_state_component) -> s32 #foreign libxkbcommon;

xkb_state_led_name_is_active :: (state: *xkb_state, name: *u8) -> s32 #foreign libxkbcommon;

xkb_state_led_index_is_active :: (state: *xkb_state, idx: xkb_led_index_t) -> s32 #foreign libxkbcommon;

xkb_x11_setup_xkb_extension :: (xcb_connection: *void, xkb_major_version: u16, xkb_minor_version: u16, flags: u32, xkb_major_version_out: *u16, xkb_minor_version_out: *u16, base_event_out: *u8, base_error_out: *u8) -> s32 #foreign libxkbcommon_x11;
xkb_x11_get_core_keyboard_device_id :: (xcb_connection: *void) -> s32 #foreign libxkbcommon_x11;
xkb_x11_keymap_new_from_device :: (ctx: *xkb_context, xkb_connection: *void, device_id: s32, flags: xkb_keymap_compile_flags) -> *xkb_keymap #foreign libxkbcommon_x11;
xkb_x11_state_new_from_device :: (keymap: *xkb_keymap, xcb_connection: *void, device_id: s32) -> *xkb_state #foreign libxkbcommon_x11;

#scope_file

libxkbcommon :: #library,system "libxkbcommon";
libxkbcommon_x11 :: #library,system "libxkbcommon-x11";
