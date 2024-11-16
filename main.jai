#if OS == .WINDOWS {
    #load "windows.jai";
} else #if OS == .LINUX {
    #load "linux.jai";
}

// Temp key while setting an actual mapping.
KEY_TEMP : u32 : 0x69696969;

// TODO: Temp guard it because uinput exposes the same names.
// WIll think later how to properly namespace it.
#if OS == .WINDOWS {
    KEY_ESC  : u32 : 0x01;
    KEY_W    : u32 : 0x11;
    KEY_A    : u32 : 0x1e;
    KEY_S    : u32 : 0x1f;
    KEY_D    : u32 : 0x20;
    KEY_L    : u32 : 0x26;
    KEY_O    : u32 : 0x18;
    KEY_U    : u32 : 0x16;
    KEY_P    : u32 : 0x19;
    KEY_9    : u32 : 0xA;
}

// I think 256 key codes should be enough for any type of keyboard...
// Indices are key scancodes
KEY_NAMES: [65535]string;

DIRECTION_LEFT : s32 : 0;
DIRECTION_RIGHT : s32 : 1;
DIRECTION_UP : s32 : 2;
DIRECTION_DOWN : s32 : 3;

BINDS :: u32.[KEY_A, KEY_D, KEY_W, KEY_S];
mapping_sources: [..]u32;
mapping_destinations: [..]u32;

IS_UP :: 0;
IS_DOWN :: 1;

current_time: float64;
last_time: float64;

scroll_value_mappings_region: float;

window_width := 800;
window_height := 600;

current_theme: s32 = xx Default_Themes.Default;
my_theme: Overall_Theme;  // This gets filled out by calling the Theme_Proc for current_theme.

// TODO: these buffers should probably be thread(context)-locals. Just in case...
key_name_buffer: [301]u16;
focused_program_path: [MAX_PATH_LENGTH]u16;
kb_real_state: [4]u32; // whether the key is pressed on a physical keyboard
kb_virtual_state: [4]u32; // whether the key is pressed on a software level

// TODO: On windows we get process exe name, on Linux (X11) we can only get the window title,
// so there is a discrepancy. Need to handle that somehow...
ALLOWED_PROGRAMS :: string.["Hollow Knight.exe"];

Mapping_State :: enum {
    NOTHING :: 0;
    SETTING_SOURCE :: 1;
    SETTING_DESTINATION :: 2;
    DELETING :: 3;
}

current_mapping_state := Mapping_State.NOTHING;

find_opposing_key_and_directions :: (scan_code: u32) -> (opposing_key: u32, direction: s32, opposing_direction: s32) {
    if scan_code == BINDS[DIRECTION_LEFT] return BINDS[DIRECTION_RIGHT], DIRECTION_LEFT, DIRECTION_RIGHT;
    if scan_code == BINDS[DIRECTION_RIGHT] return BINDS[DIRECTION_LEFT], DIRECTION_RIGHT, DIRECTION_LEFT;
    if scan_code == BINDS[DIRECTION_UP] return BINDS[DIRECTION_DOWN], DIRECTION_UP, DIRECTION_DOWN;
    if scan_code == BINDS[DIRECTION_DOWN] return BINDS[DIRECTION_UP], DIRECTION_DOWN, DIRECTION_UP;
    return 0, -1, -1;
}

get_key_mapping :: (source_scan_code: u32) -> destination_scan_code: u32 {
    found, index := array_find(mapping_sources, source_scan_code);
    if found return mapping_destinations[index];
    return 0;
}

SETTINGS_VERSION :: 1;

Platform :: enum u32 {
    WINDOWS;
    LINUX;
}

Mapping_Mode :: enum u32 {
    MAP;
    OVERRIDE;
    NEUTRAL;
}

Bind_Kind :: enum u32 {
    KEYBOARD;
    MOUSE;
    CONTROLLER;
}

Mapping_Bind :: struct {
    kind: Bind_Kind;
    code: u32;
}

Mapping :: struct {
    source: Mapping_Bind;
    destination: Mapping_Bind;
    mode: Mapping_Mode;
}

Profile :: struct {
    platform: Platform;
    program: string;
    mappings: [..]Mapping;
}

profiles: [..]Profile;

init_settings :: () -> should_parse: bool, config: string, filename: string {

    found, exe_path, exe_name := split_from_right(get_path_of_running_executable(), #char "/");
    if !found {
        log_error("Error: unable to find path to the executable to find the config file next to it. Your settings won't be saved!\n");
        return false, "", "";
    }

    settings_filename := tprint("%/%", exe_path, "settings.socd");

    raw_settings, success := read_entire_file(settings_filename,, temp);
    if !success {
        log("Coulnd't find settings.socd file, trying to create a new one");
        written : = write_entire_file(settings_filename, tprint("[%] # Config version, do not delete this!!! Actually, you're not supposed to modify this by hand at all! You will regret manually editing this file!\n", SETTINGS_VERSION));
        if !written {
            // TODO: Error detection
            log_error("Couldn't create the settings.socd, your settings won't be saved!");
        }
        return false, "", settings_filename;
    }

    return true, raw_settings, settings_filename;
}

// TODO: Actually write a test for this lol
parse_settings :: (raw_settings: string, settings_filename: string) {
    handler: tfh.Text_File_Handler;
    defer tfh.deinit(*handler);

    tfh.start_from_memory(*handler, "settings.socd", settings_filename, raw_settings);

    if handler.failed {
        tfh.error(*handler, "Your settings won't be saved. Delete the file so we can properly re-create it.\n");
        return;
    }

    if handler.version != SETTINGS_VERSION {
        tfh.error(*handler, "Unexpected version! Expected: %, got: %\n", SETTINGS_VERSION, handler.version);
    }

    while true {
        line, line_found := tfh.consume_next_line(*handler);

        if !line_found break;
        // Looking for separator
        if !equal(line, "PROFILE_START") {
            tfh.warn(*handler, "Expected profile separator, but found %\n, assuming no profiles configured", line);
            break;
        }

        profile: Profile;
        profile_parsed := false;
        while !profile_parsed {
            line, line_found = tfh.consume_next_line(*handler);
            if !line_found {
                // No configured profiles
                tfh.warn(*handler, "Expected profile settings, but found %, assuming no profiles configured", line);
                break;
            }

            colon_found, left, right := split_from_left(line, #char ":");

            if !colon_found {
                if equal(left, "PROFILE_END") {
                    log("Profile parsed successfully\n");
                    array_add(*profiles, profile);
                    profile_parsed = true;
                } else {
                    error_msg :: #string ERR
Expected to find profile configuration string (aka something separated by colon) or PROFILE_END.
Ignoring the line and trying to continue parsing. Config line was `%`
                    ERR
                    tfh.error(*handler, error_msg, line);
                }
                continue;
            }

            left = trim(left);
            to_lower_in_place(left);
            if left == {
                case "program";
                    profile.program = trim(right);
                    log("Found profile program: %\n", profile.program);

                case "platform";
                    platform := trim(right);
                    to_upper_in_place(platform);
                    if platform == {
                        case "WINDOWS"; profile.platform = .WINDOWS;
                        case "LINUX"; profile.platform = .LINUX;
                        case;
                            tfh.error(*handler, "Incorrect platform: %. Assuming Windows\n", platform);
                            continue;
                    }

                case "mapping";
                    mapping: Mapping;
                    mapping_config := split(trim(right), separator=" ");
                    if mapping_config.count != 3 {
                        tfh.error(*handler, "Incorrect mapping configuration, ignoring it. Expected MODE:source_bind:destination_bind, got %\n", right);
                        continue;
                    }
                    // Mapping mode
                    {
                        mapping_mode := trim(mapping_config[0]);
                        to_upper_in_place(mapping_mode);
                        if mapping_mode == {
                            case "OVERRIDE"; mapping.mode = .OVERRIDE;
                            case "NEUTRAL"; mapping.mode = .NEUTRAL; case "MAP"; mapping.mode = .MAP;
                            case;
                                tfh.error(*handler, "Incorrect mapping mode, ignoring it. Expected one of OVERRIDE|NEUTRAL|MAP, got %\n", mapping_mode);
                                continue;
                        }
                    }

                    // Source bind
                    {
                        bind, success, remainder := string_to_int(mapping_config[1], T=u32);
                        if !success {
                            tfh.error(*handler, "Incorrect bind, ignoring it. Got % which is an illegal key/button code\n", bind);
                            continue;
                        }
                        if bind <= 0 || bind >= KEY_MAX {
                            tfh.error(*handler, "Key bind is out of bounds, ignoring it. Got %\n", bind);
                            continue;
                        }
                        mapping.source.code = bind;
                    }

                    // Dest bind, copy-paste
                    {
                        bind, success, remainder := string_to_int(mapping_config[2], T=u32);
                        if !success {
                            tfh.error(*handler, "Incorrect bind, ignoring it. Got % which is an illegal key/button code\n", bind);
                            continue;
                        }
                        if bind <= 0 || bind >= KEY_MAX {
                            tfh.error(*handler, "Key bind is out of bounds, ignoring it. Got %\n", bind);
                            continue;
                        }
                        mapping.destination.code = bind;
                    }

                    log("Mapping parsed: %\n", mapping);
                    array_add(*profile.mappings, mapping);

                case; tfh.error(*handler, "Unexpected profile configuration ignored: %\n", left);
            }
        }
        log("Parsed profile: %\n", profile);
    }
}

main :: () {

    success := platform_init();
    if !success {
        log_error("Initialization failed\n");
        exit(1);
    }

    the_window := create_window();

    // TODO: Need to separate detecting focused program and setting up keyboard hook. Probably...
    start_detecting_focused_program();

    #if OS == .LINUX {
        start_logging_keys();
    }

    Simp.set_render_target(the_window, .LEFT_HANDED);
    init_fonts(the_window);
    ui_init();

    // Set up mappings, temporarily
    array_add(*mapping_sources, KEY_P, KEY_U);
    array_add(*mapping_destinations, KEY_L, KEY_ESC);

    should_parse_config, raw_settings, settings_filename := init_settings();
    if should_parse_config {
        parse_settings(raw_settings, settings_filename);
    }

    quit := false;
    while !quit {
        current_time = seconds_since_init();
        dt := cast(float)(current_time - last_time);
        Clamp(*dt, 0, 0.1);
        last_time = current_time;

        Input.update_window_events();

        for Input.get_window_resizes() {
            // TODO: check that it's the window we care for and that dimensions indeed changed (like when moved to a monitor with different DPI).
            //  We also get these events when the window was only moved around on the same monitor without any changes.
            Simp.update_window(it.window);
            _, _, window_width, window_height = get_dimensions(the_window, true);
            init_fonts(the_window);
        }

        for event: Input.events_this_frame {
            if event.type == .QUIT then quit = true;

            getrect_handle_event(event);

            // TODO: handle alt+f4
        }
        if current_mapping_state == .NOTHING {
            unset_mapping_setting_hook();
        }

        draw_one_frame(dt, the_window);

        reset_temporary_storage();
        // TODO handle proper waiting for input
        sleep_milliseconds(10);
    }
}

draw_one_frame :: (dt: float, window: Window_Type) {
    proc := default_theme_procs[current_theme];
    my_theme = proc();
    set_default_theme(my_theme);  // Just in case we don't explicitly pass themes sometimes...!

    bg_col := my_theme.background_color;
    Simp.clear_render_target(bg_col.x, bg_col.y, bg_col.z, 1);

    x:, y:, window_width, window_height = get_dimensions(window, true);
    ui_per_frame_update(window, xx window_width, xx window_height, current_time);

    button_theme := my_theme.button_theme;
    button_theme.font = button_font;
    button_theme.enable_variable_frame_thickness = true;
    // 'k' is some resolution-adjusting unit of distance. Right now it is
    // 1/12.5 of the screen width, so 64px of 800x600.
    k := window_width * .08;

    //
    // Directions
    //
    r := get_rect(k*1.5, k*0.5, k, k);

    button_theme.label_theme.alignment = .Center;
    up_pressed := button(r, get_key_name(BINDS[DIRECTION_UP]), *button_theme);

    r = get_rect(k*0.5, k*1.5, k, k);
    button_theme.label_theme.alignment = .Center;
    left_pressed := button(r, get_key_name(BINDS[DIRECTION_LEFT]), *button_theme);

    r = get_rect(k*1.5, k*2.5, k, k);
    button_theme.label_theme.alignment = .Center;
    down_pressed := button(r, get_key_name(BINDS[DIRECTION_DOWN]), *button_theme);


    r = get_rect(k*2.5, k*1.5, k, k);
    button_theme.label_theme.alignment = .Center;
    right_pressed := button(r, get_key_name(BINDS[DIRECTION_RIGHT]), *button_theme);

    //
    // Mappings
    //
    mappings_theme := my_theme.scrollable_region_theme;
    mappings_theme.region_background.shape.rounding_flags = 0;

    r = get_rect(k*4, k*0.5, k*8, k*5);

    region, inside := begin_scrollable_region(r, *mappings_theme);
    mapping_row_height := k * 0.7;
    s := inside;
    s.h = mapping_row_height;
    s.y -= scroll_value_mappings_region;

    button_theme.label_theme.alignment = .Left;
    new_mappings_pressed := button(s, "Add mapping", *button_theme, disable_press = current_mapping_state != .NOTHING);

    s.y += floor(mapping_row_height * 1.1 + 1);

    // label_theme := my_theme.label_theme;
    // label_theme.alignment = .Left;
    // label_theme.font = button_font;

    // label(s, "Mappings will be here.", *label_theme);
    if new_mappings_pressed {
        array_insert_at(*mapping_sources, KEY_TEMP, 0);
        array_insert_at(*mapping_destinations, KEY_TEMP, 0);
        current_mapping_state = .SETTING_SOURCE;
        set_key_mapping_hook(window);
    }
    for mapping_sources {
        source_name := ifx it == KEY_TEMP "..." else get_key_name(it);
        text_source := tprint("%", source_name);
        destination_name := ifx mapping_destinations[it_index] == KEY_TEMP "..." else get_key_name(mapping_destinations[it_index]);
        text_destination := tprint("%", destination_name);
        r := get_rect(s.x, s.y, k*2, mapping_row_height);
        button_theme.label_theme.alignment = .Center;
        pressed_source := button(r, text_source, *button_theme, it_index, disable_press = current_mapping_state == .SETTING_DESTINATION);

        // Scuffed arrow
        Simp.set_shader_for_color(true);
        Simp.immediate_quad(s.x + k*2.1, s.y + mapping_row_height*0.4, s.x + k*3.2, s.y + mapping_row_height*0.6, button_theme.surface_color_over);
        Simp.immediate_triangle(
            .{s.x + k*3.2, s.y + mapping_row_height*0.1, 0},
            .{s.x + k*4,   s.y + mapping_row_height*0.5, 0},
            .{s.x + k*3.2, s.y + mapping_row_height*0.9, 0},
            button_theme.surface_color_over,
            button_theme.surface_color_over,
            button_theme.surface_color_over,
        );

        r = get_rect(s.x + k*4, s.y, k*2, mapping_row_height);
        pressed_destination := button(r, text_destination, *button_theme, it_index, disable_press = current_mapping_state == .SETTING_SOURCE);

        r = get_rect(s.x + k*6.1, s.y, s.w - k*6.1, mapping_row_height);
        pressed_delete_mapping := button(r, "X", *button_theme, it_index);
        if pressed_delete_mapping {
            current_mapping_state = .DELETING;
            // TODO: Deletion confirmation
            array_ordered_remove_by_index(*mapping_sources, it_index);
            array_ordered_remove_by_index(*mapping_destinations, it_index);
            current_mapping_state = .NOTHING;
        }
        s.y += floor(mapping_row_height * 1.1 + 1);
    }

    end_scrollable_region(region, s.x + s.w, s.y, *scroll_value_mappings_region);

    Simp.swap_buffers(window);
}

init_fonts :: (window: Window_Type) {
    if !working_directory_set {
        path := path_strip_filename(get_path_of_running_executable());
        set_working_directory(path);
        working_directory_set = true;
    }

    dpi := get_dpi_scale(window);
    if button_font {
        free(button_font);
        button_font = null;
    }
    pixel_height := window_height / dpi / 24;
    button_font = Simp.get_font_at_size("data", "OpenSans-Bold.ttf", cast(s64)(pixel_height * dpi));
    assert(button_font != null);
}

UI_Font :: Simp.Dynamic_Font;

button_font: *UI_Font;

working_directory_set := false;
mapping_resolving_hook_is_installed := false;
mapping_setting_hook_is_installed := false;

#import "Basic"()(TEMP_ALLOCATOR_POISON_FREED_MEMORY=true);
Input :: #import "Input";
Simp :: #import "Simp";
#import "GetRect_LeftHanded";
#import "Math";
#import "String";
#import "System";
#import "Window_Creation";
tfh :: #import "Text_File_Handler";
