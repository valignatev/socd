/*
~~TODOS~~
FOR SHIPPING:
- LINUX: Do not grab devices until we are able to create a virtual one. Otherwise we're really fucked
- Make program selector have a proper height
- Finalize settings when the program quits

FOR FUTURE:
- Disallow multiple binds for the same button
- Disallow to bind a button to itself
- Better focused program recognition. Now it's just case-sensitive string contains.
- Global Profile that is always active unless some other profile kicks in. Good for testing.
- Debug UI. Showing stuff like currently pressed key, when mappings kick in, list of mappings.
- Mouse bindings
- Controller bindings
- Localiazation - maybe just a text file with user-submitted strings.
*/

#if OS == .WINDOWS {
    #load "windows.jai";
} else #if OS == .LINUX {
    #load "linux.jai";
}

#load "./ui.jai";

// I think 256 key codes should be enough for any type of keyboard...
// Indices are key scancodes
KEY_NAMES: [65535]string;

IS_UP :: 0;
IS_DOWN :: 1;

current_time: float64;
last_time: float64;

scroll_value_profiles_region: float;
scroll_value_mappings_region: float;
scroll_value_new_profile: float;

the_window: Window_Type;
log_file: File;
the_window_hidden := false;
window_width := 900;
window_height := 750;

current_theme: s32 = xx Default_Themes.Default;
my_theme: Overall_Theme;  // This gets filled out by calling the Theme_Proc for current_theme.
subwindows_initted := false;
subwindow_info_new_profile: Subwindow_Info;
subwindow_new_profile_just_got_closed := false;
searchbar_should_be_active := true;
subwindow_info_presets_confirmation: Subwindow_Info;
default_button_height := 50.0;
default_padding := 10.0;

Mapping_State :: enum {
    NOTHING :: 0;
    SETTING_SOURCE :: 1;
    SETTING_DESTINATION :: 2;
    DELETING_MAPPING :: 3;

    ADDING_NEW_PROFILE :: 4;
}

Program_State :: struct {
    active_state: Mapping_State;
    next_state: Mapping_State;
    active_mapping: *Mapping;
    active_profile: *Profile;
    active_search: *Text_Input_State;
    need_to_scroll_profiles: bool;
    need_to_rerender := false;
    close_to_tray := false;
    // need_to_scroll_mappings_region: bool;
}
dummy_input_text_state: Text_Input_State;

current_program_state: Program_State;

dummy_bind := Mapping_Bind.{};
get_key_mapping :: (source_scan_code: u32) -> Mapping_Bind {
    using current_program_state;
    destination := or_return(table_find(*active_profile.mappings, source_scan_code));
    return destination;
}

SETTINGS_VERSION :: 1;

Platform :: enum u32 {
    WINDOWS;
    LINUX;
}

Mapping_Mode :: enum u32 {
    REMAP;
    OPPOSITE;
    NEUTRAL;
}

Bind_Kind :: enum u32 {
    KEYBOARD;
    MOUSE;
    CONTROLLER;
}

Mapping_Bind :: struct {
    kind: Bind_Kind;
    mode: Mapping_Mode;
    code: u32;
}

// TODO: change this, to array of mappings from source to destination, or a Hash_Table
Mapping :: struct {
    source: Mapping_Bind;
    destination: Mapping_Bind;
    mode: Mapping_Mode;
}

// hash_function :: (source: u32) -> u32 { return source + 2; }
// Key can be something like N lower bits is code, and then some high byte for the Bind_Kind.
Mappings :: Table(u32, Mapping_Bind, /*hash_function*/);

operator== :: (a: Mapping_Bind, b: Mapping_Bind) -> bool {
    if a.code == b.code && a.mode == b.mode && a.kind == b.kind return true;
    return false;
}

Profile :: struct {
    platform: Platform;
    program: string;
    mappings: Mappings;
    // Array of binds for showing in UI and for some interemediate states,
    // mostly because iteration over the hash table is not
    // consistent after adding/removing keys.
    mappings_array: [..]Mapping;
}

active_profile_index := -1;

profiles: [..]Profile;

Preset :: enum {
    WASD;
    ARROWS;
}

Preset_Data :: struct {
    preset: Preset;
    mode: Mapping_Mode;
}

selected_preset: Preset_Data;

set_preset :: (preset: Preset, mode: Mapping_Mode) {
    using current_program_state;

    array_reset_keeping_memory(*active_profile.mappings_array);
    table_reset(*active_profile.mappings);

    mappings: [4]u32;
    if preset == .WASD {
        mappings[0] = 17; // W
        mappings[1] = 31; // S
        mappings[2] = 30; // A
        mappings[3] = 32; // D
    } else if preset == .ARROWS {
        #if CURRENT_PLATFORM == .WINDOWS {
            mappings[0] = 0xE148; // Up
            mappings[1] = 0xE150; // Down
            mappings[2] = 0xE14B; // Left
            mappings[3] = 0xE14D; // Right
        } else #if CURRENT_PLATFORM == .LINUX {
            mappings[0] = KEY_UP; // Up
            mappings[1] = KEY_DOWN; // Down
            mappings[2] = KEY_LEFT; // Left
            mappings[3] = KEY_RIGHT; // Right
        }
    }

    mapping1 := Mapping.{
        source=.{
            kind=.KEYBOARD,
            mode=mode,
            code=mappings[0],
        },
        destination=.{
            kind=.KEYBOARD,
            mode=mode,
            code=mappings[1],
        },
        mode=mode,
    };
    mapping2 := Mapping.{
        source=.{
            kind=.KEYBOARD,
            mode=mode,
            code=mappings[1],
        },
        destination=.{
            kind=.KEYBOARD,
            mode=mode,
            code=mappings[0],
        },
        mode=mode,
    };
    mapping3 := Mapping.{
        source=.{
            kind=.KEYBOARD,
            mode=mode,
            code=mappings[2],
        },
        destination=.{
            kind=.KEYBOARD,
            mode=mode,
            code=mappings[3],
        },
        mode=mode,
    };
    mapping4 := Mapping.{
        source=.{
            kind=.KEYBOARD,
            mode=mode,
            code=mappings[3],
        },
        destination=.{
            kind=.KEYBOARD,
            mode=mode,
            code=mappings[2],
        },
        mode=mode,
    };

    table_set(*active_profile.mappings, mapping1.source.code, mapping1.destination);
    table_set(*active_profile.mappings, mapping2.source.code, mapping2.destination);
    table_set(*active_profile.mappings, mapping3.source.code, mapping3.destination);
    table_set(*active_profile.mappings, mapping4.source.code, mapping4.destination);

    array_add(*active_profile.mappings_array, mapping1);
    array_add(*active_profile.mappings_array, mapping3);
    finalize_state();
}

CONFIG_HEADER :: #string HEADER
[%] # Config version, do not delete this!!! Actually, you're not supposed to modify this by hand at all! You will regret manually editing this file!

HEADER


my_logger :: (message: string, data: *void, info: Log_Info) {

#if DEBUG {
    runtime_support_default_logger(message, data, info);
    return;
}

    now := current_time_consensus();
    calendar_utc := to_calendar(now, .UTC);
    date_s := calendar_to_string(calendar_utc);
    formatted_message := tprint("%: %", date_s, message);

    length, success := file_length(log_file);
    if !success {

        // Just one attempt to reopen the log file again.
        log_file, success = file_open("./log.txt", for_writing=true, keep_existing_content=true);
        if !success {
            runtime_support_default_logger("Couldn't write to the log file: file_open\n", data, info);
            return;
        }

        length, success = file_length(log_file);
        if !success {
            runtime_support_default_logger("Couldn't write to the log file: file_len\n", data, info);
            return;
        }

    }
    if length {
        success := file_set_position(log_file, length);
        if !success {
            runtime_support_default_logger("Couldn't write to the log file: file_set_position\n", data, info);
            return;
        }
    }

    success = file_write(*log_file, xx formatted_message.data, formatted_message.count);
    if !success {
        runtime_support_default_logger("Couldn't write to the log file: file_write\n", data, info);
        return;
    }
}


push_my_context :: () #expand {
    my_context: #Context;
    my_context.logger = my_logger;

    `push_context,defer_pop my_context;
}


init_settings :: () -> should_parse: bool, config: string, filename: string {

    found, exe_path, exe_name := split_from_right(System.get_path_of_running_executable(), #char "/");
    if !found {
        log_error("Error: unable to find path to the executable to find the config file next to it. Your settings won't be saved!\n");
        return false, "", "";
    }

    settings_filename := tprint("%/%", exe_path, "settings.socd");

    // @leak - raw_settings never freed
    raw_settings, success := read_entire_file(settings_filename);
    if !success {
        log("Coulnd't find settings.socd file, trying to create a new one\n");
        written : = write_entire_file(settings_filename, tprint(CONFIG_HEADER, SETTINGS_VERSION));
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

        // First, we search for known global settings
        colon_found, left, right := split_from_left(line, #char ":");
        // This means there are no global settings defined
        if !colon_found {
            // Then, we start lookign for profiles
            if !equal(line, "PROFILE_START") {
                tfh.warn(*handler, "Expected profile separator, but found %\n, assuming no profiles configured", line);
                break;
            }
        } else {
            left = trim(left);
            to_lower_in_place(left);
            if left == {
                case "close_to_tray";
                    result := trim(right);
                    if result == "true" current_program_state.close_to_tray = true;
                    continue;
                case; {
                    tfh.error(*handler, "Unexpected global configuration ignored: %\n", left);
                    continue;
                }
            }
        }

        profile: Profile;
        active := false;
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
                    if active {
                        active_profile_index = profiles.count - 1;
                    }
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

                case "active";
                    result := trim(right);
                    if result == "true" {
                        active = true;
                    }

                case "mapping";
                    mapping: Mapping;
                    mapping_bind: Mapping_Bind;
                    source: u32;
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
                            case "OPPOSITE"; {
                                mapping.mode = .OPPOSITE;
                                mapping_bind.mode = .OPPOSITE;
                            }
                            case "NEUTRAL"; {
                                mapping.mode = .NEUTRAL;
                                mapping_bind.mode = .NEUTRAL;
                            }
                            case "REMAP"; {
                                mapping.mode = .REMAP;
                                mapping_bind.mode = .REMAP;
                            }
                            case;
                                tfh.error(*handler, "Incorrect mapping mode, ignoring it. Expected one of OPPOSITE|NEUTRAL|REMAP, got %\n", mapping_mode);
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
                        if bind <= 0 {
                            tfh.error(*handler, "Key bind is out of bounds, ignoring it. Got %\n", bind);
                            continue;
                        }
                        source = bind;
                        mapping.source = .{code=bind, mode=mapping_bind.mode};
                    }

                    // Dest bind, copy-paste
                    {
                        bind, success, remainder := string_to_int(mapping_config[2], T=u32);
                        if !success {
                            tfh.error(*handler, "Incorrect bind, ignoring it. Got % which is an illegal key/button code\n", bind);
                            continue;
                        }
                        if bind <= 0 {
                            tfh.error(*handler, "Key bind is out of bounds, ignoring it. Got %\n", bind);
                            continue;
                        }
                        mapping_bind.code = bind;
                        mapping.destination = .{code=bind, mode=mapping_bind.mode};
                    }

                    table_set(*profile.mappings, source, mapping_bind);
                    array_add(*profile.mappings_array, mapping);

                    if mapping.mode == .OPPOSITE {
                        table_set(*profile.mappings, mapping.destination.code, mapping.source);
                    }

                case; tfh.error(*handler, "Unexpected profile configuration ignored: %\n", left);
            }
        }
    }
}

maybe_fixup_settings :: () {
    using current_program_state;
    rewrite_settings := false;

    defer if rewrite_settings {
        ok := serialize_settings();
        if !ok {
            log_error("Coulnd't migrate settings\n");
        }
    }
    // For now, we just check if settings have default profile in it, and if not - add it;
    default_found := false;
    default_index := 0;
    for profiles {
        if it.program == "Hitboxer Global" {
            default_found = true;
            default_index = it_index;
            break;
        }
    }

    default_mappings: Mappings;
    if !default_found {
        array_insert_at(*profiles, .{
            platform=CURRENT_PLATFORM,
            program="Hitboxer Global",
        }, 0);
        rewrite_settings = true;
    } else if default_index != 0 {
        profiles[0], profiles[default_index] = profiles[default_index], profiles[0];
        rewrite_settings = true;
    }

    if active_profile_index == -1 {
        active_profile_index = 0;
        rewrite_settings = true;
    }

}

serialize_settings :: () -> succes: bool {
    using current_program_state;
    success := false;
    allowed_to_write := false;

    found, exe_path, exe_name := split_from_right(System.get_path_of_running_executable(), #char "/");
    if !found {
        log_error("Error: unable to find path to the executable to find the config file next to it. Your settings changes won't be saved!\n");
        return success;
    }

    settings_filename := tprint("%/%", exe_path, "settings.socd");

    b: String_Builder;
    print_to_builder(*b, CONFIG_HEADER, SETTINGS_VERSION);

    print_to_builder(*b, "close_to_tray: %\n", close_to_tray);

    for profile: profiles {
        append(*b, "PROFILE_START\n");
        defer {
            append(*b, "PROFILE_END\n");
            allowed_to_write = true;
        }

        if it_index == active_profile_index append(*b, "active: true\n");

        print_to_builder(*b, "program: %\n", profile.program);
        print_to_builder(*b, "platform: %\n", enum_value_to_name(profile.platform));

        for mapping: profile.mappings_array {
            print_to_builder(*b, "mapping: % % %\n", enum_value_to_name(mapping.mode), mapping.source.code, mapping.destination.code);
        }
    }

    result := builder_to_string(*b);
    if allowed_to_write success = write_entire_file(settings_filename, result);
    if !success {
        log_error("Error: Could not store the settings to disk, your settings changes will not be saved!\n");
    }
    free(result);

    return success;
}

finalize_state :: () {
    using current_program_state;
    if active_state != .ADDING_NEW_PROFILE {
        log("mappings after:\n");
        for active_profile.mappings {
            dest_formatted := tprint("mode: %, kind: %, code: %", it.mode, it.kind, get_key_name(it.code));
            log("source: %, dest: %\n", get_key_name(it_index), dest_formatted);
        }
    }
    active_state = .NOTHING;
    serialize_settings();
}

main :: () {
    push_my_context();
    log_file=, success := file_open("./log.txt", for_writing=true, keep_existing_content=true);
    if !success {
        log_error("Couldn't open the log file, your errors will not be logged\n");
    }
    defer file_close(*log_file);

    current_program_state = .{active_state=.NOTHING, next_state=.NOTHING, active_mapping=null, active_search=*dummy_input_text_state};
    using current_program_state;

    success_init, init_reason := platform_init();
    if !success_init {
        log_error(init_reason);
        exit(1);
    }

    the_window = create_window();

    // I want to init everything after the Window, because if there's an error, I want to potentially
    // show it in the window, instead of yelling in the terminal like some pussy ass Linux nerd.
    success_post_window := platform_after_window_created(the_window);
    if !success_post_window {
        log_error("Post window creation initialization failed\n");
        exit(1);
    }

    // TODO: Need to separate detecting focused program and setting up keyboard hook. Probably...
    start_detecting_focused_program();

    start_logging_keys();

    Simp.set_render_target(the_window, .LEFT_HANDED);
    init_fonts(the_window);
    ui_init();

    subwindow_info_new_profile.open = false;
    subwindow_info_presets_confirmation.open = false;

    should_parse_config, raw_settings, settings_filename := init_settings();
    if should_parse_config {
        parse_settings(raw_settings, settings_filename);
    }
    maybe_fixup_settings();

    quit := false;
    while !quit {
        current_time = seconds_since_init();
        dt := cast(float)(current_time - last_time);
        Clamp(*dt, 0, 0.1);
        last_time = current_time;

        platform_wait_for_message();
        Input.update_window_events();

        for Input.get_window_resizes() {
            Simp.update_window(it.window);

            if it.window == the_window {
                should_reinit := (it.width != window_width) || (it.height != window_height);
                window_width  = it.width;
                window_height = it.height;

                if should_reinit init_fonts(the_window);
            }
        }

        is_altf4 := false;
        for event: Input.events_this_frame {
            if event.type == .KEYBOARD && event.key_pressed && event.key_code == .F4 && event.alt_pressed {
                is_altf4 = true;
            }
            if event.type == .QUIT {
                quit = true;
                platform_deinit(the_window);
            } else if event.type == .WINDOW_CLOSE || is_altf4 {
                if close_to_tray {
                    platform_hide_to_tray(the_window);
                } else {
                    quit = true;
                    platform_deinit(the_window);
                }
            }

            getrect_handle_event(event);

            // TODO: handle alt+f4
        }
        if active_state == .NOTHING {
            unset_mapping_setting_hook();
        }

        draw_one_frame(dt, the_window);

        reset_temporary_storage();
        // TODO handle proper waiting for input
        sleep_milliseconds(10);
    }
}

draw_one_frame :: (dt: float, window: Window_Type) {
    using current_program_state;

    next_y := 0.0;
    need_to_rerender = false;
    proc := default_theme_procs[current_theme];
    my_theme = proc();

    my_theme.label_theme.font = button_font;
    my_theme.label_theme.alignment = .Left;
    my_theme.label_theme.alignment_pad_ems = 0.0;

    my_theme.button_theme.font = button_font;
    my_theme.button_theme.enable_variable_frame_thickness = true;
    my_theme.button_theme.rectangle_shape.rounding_flags = 0;
    my_theme.button_theme.label_theme.alignment = .Left;

    my_theme.scrollable_region_theme.region_background.shape.rounding_flags = 0;
    my_theme.scrollable_region_theme.scrollbar_size = 0.01;

    my_theme.text_input_theme.rectangle_shape.rounding_flags = 0;
    my_theme.text_input_theme.button_theme.font = button_font;

    my_theme.subwindow_theme.title_bar.rectangle_shape.rounding_flags = 0;
    my_theme.subwindow_theme.region_background.shape.rounding_flags = 0;
    my_theme.subwindow_theme.resize_controls = 0;
    my_theme.subwindow_theme.subwindow_flags ^= .VISIBLE_RESIZE_CORNER;

    header_theme := my_theme.label_theme;
    header_theme.font = header_font;

    pulsating_button_theme := my_theme.button_theme;
    pulsating_button_theme.over_fade_in_speed = 20;
    pulsating_button_theme.frame_color = pulsating_button_theme.frame_color_flash;
    pulsating_button_theme.surface_color = pulsating_button_theme.surface_color_flash;

    checkbox_theme := my_theme.checkbox_theme;
    checkbox_theme.font = button_font; // @Cleanup: We have to manually set a font for now.

    button_height := default_button_height;
    padding := default_padding;

    set_default_theme(my_theme);  // Just in case we don't explicitly pass themes sometimes...!

    bg_col := my_theme.background_color;
    Simp.clear_render_target(bg_col.x, bg_col.y, bg_col.z, 1);

    x:, y:, window_width, window_height = get_dimensions(window, true);
    ui_per_frame_update(window, 800, 800, current_time);

    //
    // Profiles
    //
    left_side_width := 300.0;
    left_side_height := xx window_height;
    {
        profiles_width := left_side_width;
        profiles_height := 440.0;

        add_button_rect := get_rect(padding, next_y + padding, profiles_width / 2 - 5, button_height);
        del_button_rect := get_rect(padding + profiles_width / 2 + 5, next_y + padding, profiles_width / 2 - 5, button_height);

        next_y = add_button_rect.y + add_button_rect.h;

        _, _, add_profile_released := our_button(add_button_rect, "Add", *my_theme.button_theme, /*disable_press = (active_state != .NOTHING)*/);
        if add_profile_released {
            subwindow_info_new_profile.open = true;
            new_profile := array_add(*profiles);
            new_profile.platform = CURRENT_PLATFORM;
            active_profile = new_profile;
            active_profile_index = profiles.count - 1;
            active_state = .ADDING_NEW_PROFILE;
            need_to_scroll_profiles = true;
        }

        _, _, del_profile_released := our_button(del_button_rect, "Delete", *my_theme.button_theme, disable_press = (active_profile_index <= 0 || active_state != .NOTHING));
        if del_profile_released {
            array_ordered_remove_by_index(*profiles, active_profile_index);
            active_profile = *profiles[profiles.count - 1];
            active_profile_index = profiles.count - 1;;
            finalize_state();
        }

        r := get_rect(padding, next_y + padding, profiles_width, profiles_height);
        next_y = r.y + r.h;

        profiles_region, inside_profiles_region := begin_scrollable_region(r, *my_theme.scrollable_region_theme);

        program_rect := inside_profiles_region;
        program_rect.h = button_height;
        program_rect.y -= scroll_value_profiles_region;

        profile_button_theme := my_theme.button_theme;
        profile_button_theme.frame_color = profile_button_theme.surface_color;
        rendered_profiles_count := 0;
        for * profiles {
            if it.platform != CURRENT_PLATFORM continue;
            rendered_profiles_count += 1;

            if it_index == active_profile_index {
                active_profile = it;
            }

            profile_pulsating := active_profile == it && active_state == .ADDING_NEW_PROFILE;
            theme := ifx profile_pulsating pulsating_button_theme else profile_button_theme;
            if it == active_profile && active_state != .ADDING_NEW_PROFILE {
                theme.frame_color = theme.frame_color_over;
                theme.surface_color = theme.surface_color_over;
            }

            pressed, state := our_button(program_rect, it.program, *theme, identifier=it_index, disable_press = active_state == .ADDING_NEW_PROFILE, pulsate=profile_pulsating);

            if pressed {
                active_profile_index = it_index;
                finalize_state();
            }

            program_rect.y += floor(button_height * 1.1 + 1);
        }

        end_scrollable_region(profiles_region, program_rect.x + program_rect.w, program_rect.y, *scroll_value_profiles_region);

        // Is there a better way to snap scrollable region to the end?
        if need_to_scroll_profiles {
            scroll_scrollable_region(profiles_region, program_rect.y, *scroll_value_profiles_region);
            need_to_scroll_profiles = false;
        }
    }

    // Global settings
    {
        label_rect := get_rect(10, next_y + padding, left_side_width, button_height);
        label(label_rect, "Global settings", *header_theme);

        next_y = label_rect.y + label_rect.h;
        r := get_rect(10, next_y, left_side_width, button_height);
        changed, state := our_checkbox(r, "Close to tray", close_to_tray, *checkbox_theme);
        if changed {
            close_to_tray ^= changed;
            finalize_state();
        }
    }

    // Scuffed separator
    // Simp.immediate_quad(
    //     left_side_width + padding + padding/2, padding,
    //     left_side_width + padding + padding, xx window_height,
    //     my_theme.button_theme.text_color,
    // );

    right_side_start := left_side_width + 30;
    right_side_width := 500.0;
    next_y = padding;

    right_side_rect := get_rect(right_side_start, next_y, right_side_width, button_height);

    //
    // Active profile settings
    //
    {
        _, _, add_mapping_released := our_button(right_side_rect, "", *my_theme.button_theme);

        // This is just to "center" the label on top of arrows, because otherwise a button label
        // looks slightly off-center, because "Add mapping" button is wider than the scrollable area
        label_theme := my_theme.label_theme;
        label_theme.alignment = .Center;
        label_width := (right_side_width - 50);
        label_rect := get_rect(right_side_rect.x, right_side_rect.y, label_width, right_side_rect.h);
        label(label_rect, "Add mapping", *label_theme);

        next_y = label_rect.y + label_rect.h;

        if add_mapping_released && active_state == .NOTHING {
            log("mappings before:\n");
            for active_profile.mappings {
                dest_formatted := tprint("mode: %, kind: %, code: %", it.mode, it.kind, get_key_name(it.code));
                log("source: %, dest: %\n", get_key_name(it_index), dest_formatted);
            }
            active_state = .SETTING_SOURCE;
            next_state = .SETTING_DESTINATION;

            source := Mapping_Bind.{code=KEY_RESERVED};
            dest := Mapping_Bind.{code=KEY_RESERVED};
            array_insert_at(*active_profile.mappings_array, .{source=source, destination=dest}, 0);
            active_mapping = *active_profile.mappings_array[0];
            table_set(*active_profile.mappings, source.code, dest);
            set_key_mapping_hook(window);

            // need_to_scroll_mappings_region = true;
        }
    }

    //
    // EMERGENCY QUIT BUTTON. TODO: only enable it in debug mode
    //
    if DEBUG {
        close_start := right_side_rect.w + right_side_rect.x + 10;
        close_rect := get_rect(close_start, 10, button_height, button_height);
        _, _, close_released := our_button(close_rect, "X", *my_theme.button_theme);
        if close_released {
            exit(1);
        }
    }

    //
    // Mappings
    //
    mappings_theme := my_theme.scrollable_region_theme;
    mappings_theme.scrollbar_size = 0.01;
    mappings_height := 440.0;
    mappings_rect := get_rect(right_side_start, next_y + padding, right_side_width, mappings_height);

    next_y = mappings_rect.y + mappings_rect.h;

    mappings_region, inside_mappings_region := begin_scrollable_region(mappings_rect, *mappings_theme);
    s := inside_mappings_region;
    s.y -= scroll_value_mappings_region;

    mappings_button_theme := my_theme.button_theme;
    mappings_button_theme.label_theme.alignment = .Center;
    pulsating_button_theme.label_theme.alignment = .Center;

    dropdown_theme := *my_theme.dropdown_theme;
    dropdown_theme.theme_for_current_value = my_theme.button_theme;
    dropdown_theme.theme_for_each_choice.rectangle_shape.rounding_flags = 0;
    dropdown_theme.theme_for_each_choice.font = my_theme.button_theme.font;
    dropdown_theme.theme_for_current_choice.font = my_theme.button_theme.font;
    dropdown_theme.theme_for_current_choice.rectangle_shape.rounding_flags = 0;
    dropdown_theme.theme_for_current_value.text_color = my_theme.button_theme.surface_color;

    type_info_mapping_mode := type_info(Mapping_Mode);
    index_to_remove: s64 = -1;
    dropdown_state_to_clean_up: Dropdown_State;

    for * mapping: active_profile.mappings_array {
        button_width := (s.w - 50)/3 - 1;
        source_rect := get_rect(s.x, s.y, button_width, button_height);
        source_name := get_key_name(mapping.source.code);

        source_pulsating := active_mapping && active_mapping == mapping && active_state == .SETTING_SOURCE;
        source_theme := ifx source_pulsating pulsating_button_theme else mappings_button_theme;
        _, source_state, released_source := our_button(source_rect, source_name, *source_theme, identifier=it_index, disable_press = active_state == .SETTING_DESTINATION, pulsate = source_pulsating);

        // Making a button pulsating
        // if source_pulsating {
        //     update_production_value_button(source_rect, false, source_state, .OVER, *pulsating_button_theme);
        // }
        if released_source {
            active_state = .SETTING_SOURCE;
            log("mappings before:\n");
            for active_profile.mappings {
                dest_formatted := tprint("mode: %, kind: %, code: %", it.mode, it.kind, get_key_name(it.code));
                log("source: %, dest: %\n", get_key_name(it_index), dest_formatted);
            }
            active_mapping = mapping;
            set_key_mapping_hook(window);
        }

        mode_rect := get_rect(s.x + source_rect.w + 1, s.y, button_width, button_height);
        changed, mode_state := dropdown(mode_rect, type_info_mapping_mode.names, xx *mapping.mode, dropdown_theme, identifier=mapping.source.code);

        // HACK: we might be reusing the leaked dropdown state with the same hash, left after removing a mapping with the same code
        // so test for null pointer. Need a better way to clear stale states, or remove current_value_pointer from it
        if changed {
            active_mapping = mapping;
            new_mode := cast(Mapping_Mode, mode_state.current_value_pointer.*);
            destination_ptr := table_find_pointer(*active_profile.mappings, mapping.source.code);
            old_mode := destination_ptr.mode;
            destination_ptr.*.mode = new_mode;
            active_mapping.*.source.mode = new_mode;
            // We really rely on this one
            active_mapping.*.destination.mode = new_mode;

            if new_mode == .REMAP {
                if old_mode == .OPPOSITE || old_mode == .NEUTRAL {
                    table_remove(*active_profile.mappings, destination_ptr.code);
                }

            } else if new_mode == .OPPOSITE || new_mode == .NEUTRAL {
                if old_mode == .REMAP {
                    table_set(*active_profile.mappings, destination_ptr.code, .{mode=new_mode, code=mapping.source.code, kind=mapping.source.kind});
                } else {
                    dest_to_source_ptr := table_find_pointer(*active_profile.mappings, destination_ptr.code);
                    if dest_to_source_ptr dest_to_source_ptr.mode = new_mode;
                }
            }
            if next_state == .NOTHING {
                finalize_state();
            }
        }

        mode_r := get_rect(s.x + source_rect.w + 1, s.y, button_width, button_height);
        arrow(mode_r, *mode_state, dropdown_theme, mapping.mode);

        dest_rect := get_rect(s.x + source_rect.w + 1 + mode_rect.w + 1, s.y, button_width, button_height);
        dest_name := get_key_name(mapping.destination.code);

        dest_pulsating := active_mapping && active_mapping == mapping && active_state == .SETTING_DESTINATION;
        dest_theme := ifx dest_pulsating pulsating_button_theme else mappings_button_theme;
        _, dest_state, released_dest := our_button(dest_rect, dest_name, *dest_theme, identifier=it_index, disable_press = active_state == .SETTING_DESTINATION, pulsate = dest_pulsating);

        if released_dest {
            active_state = .SETTING_DESTINATION;
            active_mapping = mapping;
            set_key_mapping_hook(window);
        }

        del_rect := get_rect(s.x + source_rect.w + 1 + mode_rect.w + 1 + dest_rect.w + 1 + 1, s.y, button_height, button_height);
        _, _, del_released := our_button(del_rect, "X", *mappings_button_theme, identifier=it_index);

        // Delete mapping
        if del_released {
            index_to_remove = it_index;
            dropdown_state_to_clean_up = mode_state;
        }

        s.y += floor(button_height * 1.1 + 1);

    }

    end_scrollable_region(mappings_region, s.x + s.w, s.y, *scroll_value_mappings_region);

    // Presets
    presets_start_y := next_y + padding;
    {
        r := get_rect(s.x, presets_start_y, s.w, button_height);
        label(r, "Presets", *header_theme);

        r.w = r.w / 2;
        r.y += button_height;

        wasd_opposite_released: bool;
        arrows_opposite_released: bool;
        wasd_neutral_released: bool;
        arrows_neutral_released: bool;
        {
            _, _, wasd_opposite_released = our_button(r, "WASD Opposite", theme=*my_theme.button_theme);
            if wasd_opposite_released {
                selected_preset.preset = .WASD;
                selected_preset.mode = .OPPOSITE;
            }
            r.x += r.w + padding;
            _, _, arrows_opposite_released = our_button(r, "Arrows Opposite", theme=*my_theme.button_theme);
            if arrows_opposite_released {
                selected_preset.preset = .ARROWS;
                selected_preset.mode = .OPPOSITE;
            }
            r.x -= r.w + padding;
        }

        r.y += button_height + 1;
        {
            _, _, wasd_neutral_released = our_button(r, "WASD Neutral", theme=*my_theme.button_theme);
            if wasd_neutral_released {
                selected_preset.preset = .WASD;
                selected_preset.mode = .NEUTRAL;
            }
            r.x += r.w + padding;
            _, _, arrows_neutral_released = our_button(r, "Arrows Neutral", theme=*my_theme.button_theme);
            if arrows_neutral_released {
                selected_preset.preset = .ARROWS;
                selected_preset.mode = .NEUTRAL;
            }
            r.x -= r.w + padding;

        }
        if wasd_opposite_released || wasd_neutral_released || arrows_opposite_released || arrows_neutral_released {
            if active_profile.mappings_array.count > 0 {
                subwindow_info_presets_confirmation.open = true;
            } else {
                set_preset(selected_preset.preset, selected_preset.mode);
            }
        }
        subwindow_info_presets_confirmation.user_data = xx *selected_preset;

        next_y = r.y + r.h;
    }

    //
    // New Profile subwindow
    //
    {
        theme := my_theme.subwindow_theme;
        // r := profiles_region;
        if !subwindows_initted {
            subwindow_info_new_profile.rect = right_side_rect;
            subwindow_info_new_profile.rect.h = xx window_height - padding * 2;
            subwindow_info_new_profile.title_text = "Select Program";
            subwindow_info_new_profile.draw = draw_new_profile_selector;

            presets_confirm_rect := get_rect(right_side_rect.x, presets_start_y, right_side_rect.w, next_y - presets_start_y);
            subwindow_info_presets_confirmation.rect = presets_confirm_rect;
            // subwindow_info_presets_confirmation.rect.h = xx window_height - padding * 2;
            subwindow_info_presets_confirmation.title_text = "Confirm";
            subwindow_info_presets_confirmation.draw = draw_presets_confirmation;

            subwindows_initted = true;
        }
        if subwindow_info_new_profile.open {
            subwindow_state := add_subwindow(*subwindow_info_new_profile, *theme);

        } else if profiles.count && profiles[profiles.count -1].program == "" {
            array_ordered_remove_by_index(*profiles, profiles.count - 1);
            if profiles.count {
                active_profile = *profiles[profiles.count - 1];
                active_profile_index = profiles.count - 1;;
            }

            set_text(active_search, active_search.pre_modification_text, replace_pre_modification_text=false);
            finalize_state();
            searchbar_should_be_active = true;
        }

        if subwindow_info_presets_confirmation.open {
            add_subwindow(*subwindow_info_presets_confirmation, *theme);
        }
    }

    // if need_to_scroll_mappings_region {
    //     scroll_scrollable_region(mappings_region, s.y, *scroll_value_mappings_region);
    //     need_to_scroll_mappings_region = false;
    // }

    draw_popups();
    Simp.swap_buffers(window);

    if index_to_remove >= 0 {
        mapping_to_remove := active_profile.mappings_array[index_to_remove];
        table_remove(*active_profile.mappings, mapping_to_remove.source.code);
        if mapping_to_remove.mode == .OPPOSITE || mapping_to_remove.mode == .NEUTRAL {
            table_remove(*active_profile.mappings, mapping_to_remove.destination.code);
        }
        array_ordered_remove_by_index(*active_profile.mappings_array, index_to_remove);
        table_remove(*state_table, dropdown_state_to_clean_up.hash);

        index_to_remove = -1;
        finalize_state();
    }
    if need_to_rerender || GetRect.active_widget {
        platform_wake_up_main_thread();
    }
}

draw_new_profile_selector :: (r: Rect, data: *void) {
    using current_program_state;
    button_height := default_button_height;

    searchbar_rect := r;
    searchbar_rect.h = button_height;

    input_action : Text_Input_Action = ifx searchbar_should_be_active then .ACTIVATE else xx 0;
    action:, new_search:, active_search = text_input(searchbar_rect, active_search.text, *my_theme.text_input_theme, input_action = input_action);
    if action & .ENTERED {
        // TODO: kinda copypaste from below
        subwindow_info_new_profile.open = false;
        profiles[profiles.count - 1].program = copy_string(new_search);
        finalize_state();
        active_search.text = "";
        searchbar_should_be_active = true;
    }
    if action & .ESCAPED {
        subwindow_info_new_profile.open = false;
        active_search.text = "";
        searchbar_should_be_active = true;
    }

    if input_action {
        searchbar_should_be_active = false;
    }

    if !active_search.text {
        // +10 to offset for the text input caret.
        label_theme := my_theme.label_theme;
        label_theme.font = small_label_font;
        label_theme.alignment = .Right;
        label(searchbar_rect, "Type to narrow (Enter works too)...", *label_theme);
    }

    scrollable_rect := r;
    scrollable_rect.y = searchbar_rect.y + searchbar_rect.h;
    region, inside := begin_scrollable_region(scrollable_rect, *my_theme.scrollable_region_theme);

    s := inside;
    s.h = button_height;
    s.y -= scroll_value_new_profile;

    opened_windows := get_list_of_programs();
    for opened_windows {
        _, _, released := our_button(s, it, identifier=it_index);
        if released {
            print("Program % selected\n", it);
            subwindow_info_new_profile.open = false;
            profiles[profiles.count - 1].program = copy_string(it);
            active_search.text = "";
            finalize_state();
            searchbar_should_be_active = true;
        }

        if it_index != opened_windows.count  {
            s.y += floor(button_height * 1.1 + 0.5);  // Just so r.y is in the right place for end_scrollable_region().
        }
    }

    end_scrollable_region(region, s.x + s.w, s.y + s.h, *scroll_value_new_profile);
}

draw_presets_confirmation :: (base_r: Rect, data: *void) {
    using current_program_state;
    selected_preset := cast(*Preset_Data)data;

    // r.y += button_height - padding;
    r := base_r;
    r.h = default_button_height;

    label_theme := my_theme.label_theme;
    label_theme.font = header_font;
    label_theme.alignment = .Center;
    label(r, "Override current bindings?", *label_theme);

    button_theme := my_theme.button_theme;
    button_theme.label_theme.alignment = .Center;
    r.y += r.h + default_padding;
    r.w = r.w/2;
    _, _, ok_released := our_button(r, "Yes", theme=*button_theme);
    if ok_released {
        set_preset(selected_preset.preset, selected_preset.mode);
    }
    r.x += r.w;
    _, _, no_released := our_button(r, "No", theme=*button_theme);

    if ok_released || no_released {
        subwindow_info_presets_confirmation.open = false;
    }

}

scroll_scrollable_region :: (state: *Scrollable_Region_State, max_y: float, scroll_value: *float) {
    scroll_content_size := max(max_y - (state.inner_rect.y - scroll_value.*), state.inner_rect.h);
    max_scroll_value := scroll_content_size - state.inner_rect.h;
    scroll_value.* = max_scroll_value;
}

init_fonts :: (window: Window_Type) {
    if !working_directory_set {
        path := path_strip_filename(System.get_path_of_running_executable());
        set_working_directory(path);
        working_directory_set = true;
    }

    dpi := get_dpi_scale(window);

    // Window height was here
    pixel_height := 600 / dpi / 26;
    header_height := 600 / dpi / 20;
    small_height := 600 / dpi / 36;
    button_font = Simp.get_font_at_size("data", "Hack-Regular.ttf", cast(s64)(pixel_height * dpi));
    small_label_font = Simp.get_font_at_size("data", "Hack-Regular.ttf", cast(s64)(small_height * dpi));
    header_font = Simp.get_font_at_size("data", "Hack-Bold.ttf", cast(s64)(header_height * dpi));
    assert(button_font != null);
}

UI_Font :: Simp.Dynamic_Font;

small_label_font: *UI_Font;
button_font: *UI_Font;
header_font: *UI_Font;

working_directory_set := false;
mapping_resolving_hook_is_installed := false;
mapping_setting_hook_is_installed := false;

#import "Basic"()(TEMP_ALLOCATOR_POISON_FREED_MEMORY=true);
#import "Hash_Table";
Input :: #import "Input";
Simp :: #import "Simp";
using GetRect :: #import "GetRect_LeftHanded";
#import "Math";
#import "String";
System :: #import "System";
#import "Window_Creation";
tfh :: #import "Text_File_Handler";
#import "Reflection";
#import "File";
#import "File_Utilities";
#import "Control_Flow";
