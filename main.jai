/*
~~TODOS~~
FOR SHIPPING:
- Add currently active profile to settings file.
- Implement saving to the profile.
- Fix numpad bug on Windows
- [Works with libinput] Better device grab on Linux that doesn't just wait for the first pressed key.
- Better focused program recognition. Now it's just case-sensitive string contains.
- Profile add and delete.
- Better dropdown ui for mapping mode.
- Automatic scrol for when stuff doesn't fit into the scrollable region.
- Search autocomplete when selecting a program for new profile.

FOR FUTURE:
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

// Temp key while setting an actual mapping.
KEY_TEMP : u32 : 0x69696969;

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

window_width := 900;
window_height := 600;

current_theme: s32 = xx Default_Themes.Default;
my_theme: Overall_Theme;  // This gets filled out by calling the Theme_Proc for current_theme.
subwindows_initted := false;

subwindow_info_new_profile: Subwindow_Info;
subwindow_new_profile_just_got_closed := false;
subwindow_opened_for_the_first_time := false;

Mapping_State :: enum {
    NOTHING :: 0;
    SETTING_SOURCE :: 1;
    SETTING_DESTINATION :: 2;
    SETTING_JUST_SOURCE :: 3;
    SETTING_JUST_DESTINATION :: 4;
    DELETING_MAPPING :: 5;

    ADDING_NEW_PROFILE :: 6;
}

current_mapping_state := Mapping_State.NOTHING;

get_key_mapping :: (source_scan_code: u32) -> Mapping_Bind {
    destination, found := table_find(*active_profile.mappings, source_scan_code);
    if found return destination;
    return dummy_bind;
}

SETTINGS_VERSION :: 1;

Platform :: enum u32 {
    WINDOWS;
    LINUX;
}

// TODO: OVERRIDE -> OPPOSITE and MAP -> REMAP is probably better naming
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
    mode: Mapping_Mode;
    source: u32;
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

dummy_bind := Mapping_Bind.{};

operator== :: (a: Mapping_Bind, b: Mapping_Bind) -> bool {
    if a.code == b.code && a.mode == b.mode && a.kind == b.kind return true;
    return false;
}

Profile :: struct {
    platform: Platform;
    program: string;
    // mappings: [..]Mapping;
    mappings: Mappings;
    // Array of binds for showing in UI and for some interemediate states,
    // mostly because iteration over the hash table is not
    // consistent after adding/removing keys.
    mappings_array: [..]Mapping;
}

active_profile: Profile;
active_profile_index := -1;
active_mapping_index := -1;
profiles: [..]Profile;

CONFIG_HEADER :: #string HEADER
[%] # Config version, do not delete this!!! Actually, you're not supposed to modify this by hand at all! You will regret manually editing this file!

HEADER

init_settings :: () -> should_parse: bool, config: string, filename: string {

    found, exe_path, exe_name := split_from_right(get_path_of_running_executable(), #char "/");
    if !found {
        log_error("Error: unable to find path to the executable to find the config file next to it. Your settings won't be saved!\n");
        return false, "", "";
    }

    settings_filename := tprint("%/%", exe_path, "settings.socd");

    // @leak - raw_settings never freed
    raw_settings, success := read_entire_file(settings_filename);
    if !success {
        log("Coulnd't find settings.socd file, trying to create a new one");
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
                            case "OVERRIDE"; {
                                mapping.mode = .OVERRIDE;
                                mapping_bind.mode = .OVERRIDE;
                            }
                            case "NEUTRAL"; {
                                mapping.mode = .NEUTRAL;
                                mapping_bind.mode = .NEUTRAL;
                            }
                            case "MAP"; {
                                mapping.mode = .MAP;
                                mapping_bind.mode = .MAP;
                            }
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
                        if bind <= 0 || bind >= KEY_MAX {
                            tfh.error(*handler, "Key bind is out of bounds, ignoring it. Got %\n", bind);
                            continue;
                        }
                        mapping_bind.code = bind;
                        mapping.destination = .{code=bind, mode=mapping_bind.mode};
                    }

                    table_set(*profile.mappings, source, mapping_bind);
                    array_add(*profile.mappings_array, mapping);

                    if mapping.mode == .OVERRIDE {
                        table_set(*profile.mappings, mapping.destination.code, mapping.source);
                    }

                case; tfh.error(*handler, "Unexpected profile configuration ignored: %\n", left);
            }
        }
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

    subwindow_info_new_profile.open = false;

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

            if it.window == the_window {

                should_reinit := (it.width != window_width) || (it.height != window_height);

                window_width  = it.width;
                window_height = it.height;

                if should_reinit init_fonts(the_window);
            }
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
    my_theme.button_theme.font = button_font;
    my_theme.button_theme.enable_variable_frame_thickness = true;
    my_theme.button_theme.rectangle_shape.rounding_flags = 0;
    my_theme.button_theme.label_theme.alignment = .Left;
    set_default_theme(my_theme);  // Just in case we don't explicitly pass themes sometimes...!

    bg_col := my_theme.background_color;
    Simp.clear_render_target(bg_col.x, bg_col.y, bg_col.z, 1);

    x:, y:, window_width, window_height = get_dimensions(window, true);
    ui_per_frame_update(window, 800, 800, current_time);

    //
    // Profiles
    //
    profiles_theme := my_theme.scrollable_region_theme;
    profiles_theme.region_background.shape.rounding_flags = 0;
    profiles_theme.scrollbar_size = 0.01;

    profiles_width := 300.0;
    profiles_height := 500.0;
    r := get_rect(10, 10, profiles_width, profiles_height);
    profiles_region, inside_profiles_region := begin_scrollable_region(r, *profiles_theme);

    s := inside_profiles_region;
    s.h = 50;
    s.y -= scroll_value_profiles_region;

    profile_button_theme := my_theme.button_theme;
    profile_button_theme.frame_color = profile_button_theme.surface_color;
    for profiles {
        pressed := button(s, it.program, *profile_button_theme, identifier=it_index);
        if pressed {
            log("Profile % pressed\n", it.program);
            active_profile = it;
            active_profile_index = it_index;
        }

        s.y += floor(50 * 1.1 + 1);
    }

    end_scrollable_region(profiles_region, s.x + s.w, s.y, *scroll_value_profiles_region);

    add_button_rect := get_rect(10, profiles_height + 10 + 5, profiles_width / 2 - 5, 50);
    del_button_rect := get_rect(10 + profiles_width / 2 + 5, profiles_height + 10 + 5, profiles_width / 2 - 5, 50);

    _, _, add_profile_released := button(add_button_rect, "Add", *my_theme.button_theme, disable_press = (current_mapping_state != .NOTHING));
    if add_profile_released {
        current_mapping_state = .ADDING_NEW_PROFILE;
        subwindow_info_new_profile.open = true;
        new_profile := array_add(*profiles);
        active_profile = new_profile;
    }

    _, _, del_profile_released := button(del_button_rect, "Delete", *my_theme.button_theme, disable_press = (active_profile_index < 0));
    if del_profile_released {
        current_mapping_state = .NOTHING;
        active_profile = .{};
        array_ordered_remove_by_index(*profiles, active_profile_index);
        active_profile_index = -1;
    }

    //
    // New Profile subwindow
    //

    {
        theme := my_theme.subwindow_theme;
        // r := profiles_region;
        if !subwindows_initted {
            subwindow_info_new_profile.rect = r;
            subwindow_info_new_profile.title_text = "Select Window";
            subwindow_info_new_profile.draw = draw_new_profile_selector;
            subwindows_initted = true;
        }
        if subwindow_info_new_profile.open {
            subwindow_state := add_subwindow(*subwindow_info_new_profile, *theme);

        } else if profiles.count && profiles[profiles.count -1].program == "" {
            array_ordered_remove_by_index(*profiles, profiles.count - 1);
            current_mapping_state = .NOTHING;
        }
    }

    //
    // Active profile settings
    //
    profile_start := profiles_width + 30;
    profile_width := 500.0;

    add_mapping_rect := get_rect(profile_start, 10, profile_width, 50);
    _, _, add_mapping_released := button(add_mapping_rect, "Add mapping", *my_theme.button_theme);
    if add_mapping_released && current_mapping_state == .NOTHING {
        source := Mapping_Bind.{code=KEY_TEMP};
        dest := Mapping_Bind.{code=KEY_TEMP};
        array_insert_at(*active_profile.mappings_array, .{source=source, destination=dest}, 0);
        current_mapping_state = .SETTING_SOURCE;
        active_mapping_index = 0;
        set_key_mapping_hook(window);
    }


    //
    // EMERGENCY QUIT BUTTON. TODO: only enable it in debug mode
    //
    close_start := add_mapping_rect.w + add_mapping_rect.x + 10;
    close_rect := get_rect(close_start, 10, 50, 50);
    _, _, close_released := button(close_rect, "X", *my_theme.button_theme);
    if close_released {
        exit(1);
    }

    //
    // Mappings
    //
    mappings_theme := profiles_theme;
    mappings_theme.scrollbar_size = 0.01;
    mappings_height := 400.0;
    mappings_rect := get_rect(profile_start, 10 + add_mapping_rect.h + 10, profile_width, mappings_height);

    mappings_region, inside_mappings_region := begin_scrollable_region(mappings_rect, *mappings_theme);
    s = inside_mappings_region;
    s.y -= scroll_value_mappings_region;

    mappings_button_theme := my_theme.button_theme;
    mappings_button_theme.label_theme.alignment = .Center;

    dropdown_theme := *my_theme.dropdown_theme;
    dropdown_theme.theme_for_current_value = my_theme.button_theme;
    dropdown_theme.theme_for_each_choice.rectangle_shape.rounding_flags = 0;
    dropdown_theme.theme_for_current_choice.rectangle_shape.rounding_flags = 0;

    type_info_mapping_mode := type_info(Mapping_Mode);
    index_to_remove: s64 = -1;
    dropdown_state_to_clean_up: Dropdown_State;
    for * mapping: active_profile.mappings_array {
        button_width := (s.w - 50)/3 - 1;
        source_rect := get_rect(s.x, s.y, button_width, 50);
        source_name := get_key_name(mapping.source.code);
        _, _, released_source := button(source_rect, source_name, *mappings_button_theme, identifier=it_index, disable_press = current_mapping_state == .SETTING_DESTINATION);
        if released_source {
            current_mapping_state = .SETTING_JUST_SOURCE;
            active_mapping_index = it_index;
            mapping.*.source.code = KEY_TEMP;
            print("Source pressed\n");
        }

        mode_rect := get_rect(s.x + source_rect.w + 1, s.y, button_width, 50);
        changed, mode_state := dropdown(mode_rect, type_info_mapping_mode.names, xx *mapping.mode, dropdown_theme, identifier=mapping.source.code);
        // HACK: we might be reusing the leaked dropdown state with the same hash, left after removing a mapping with the same code
        // so test for null pointer. Need a better way to clear stale states, or remove current_value_pointer from it
        if changed {
            new_mode := cast(Mapping_Mode, mode_state.current_value_pointer.*);
            print("mappings before:\n");
            for active_profile.mappings {
                dest_formatted := tprint("mode: %, kind: %, code: %", it.mode, it.kind, get_key_name(it.code));
                print("source: %, dest: %\n", get_key_name(it_index), dest_formatted);
            }
            destination_ptr := table_find_pointer(*active_profile.mappings, mapping.source.code);
            old_mode := destination_ptr.mode;
            destination_ptr.*.mode = new_mode;

            if new_mode == .MAP {
                if old_mode == .OVERRIDE || old_mode == .NEUTRAL {
                    table_remove(*active_profile.mappings, destination_ptr.code);
                }

            } else if new_mode == .OVERRIDE || new_mode == .NEUTRAL {
                if old_mode == .MAP {
                    table_set(*active_profile.mappings, destination_ptr.code, .{mode=new_mode, code=mapping.source.code, kind=mapping.source.kind});
                } else {
                    dest_to_source_ptr := table_find_pointer(*active_profile.mappings, destination_ptr.code);
                    if dest_to_source_ptr dest_to_source_ptr.mode = new_mode;
                }
            }
            print("mappings after_last:\n");
            for active_profile.mappings {
                dest_formatted := tprint("mode: %, kind: %, code: %", it.mode, it.kind, get_key_name(it.code));
                print("source: %, dest: %\n", get_key_name(it_index), dest_formatted);
            }
        }

        dest_rect := get_rect(s.x + source_rect.w + 1 + mode_rect.w + 1, s.y, button_width, 50);
        dest_name := get_key_name(mapping.destination.code);
        _, _, released_dest := button(dest_rect, dest_name, *mappings_button_theme, identifier=it_index, disable_press = current_mapping_state == .SETTING_DESTINATION);
        if released_dest {
            current_mapping_state = .SETTING_JUST_DESTINATION;
            active_mapping_index = it_index;
            mapping.*.destination.code = KEY_TEMP;
            print("Dest pressed\n");
        }

        del_rect := get_rect(s.x + source_rect.w + 1 + mode_rect.w + 1 + dest_rect.w + 1 + 1, s.y, 50, 50);
        _, _, del_released := button(del_rect, "X", *mappings_button_theme, identifier=it_index);

        if del_released {
            index_to_remove = it_index;
            dropdown_state_to_clean_up = mode_state;
        }

        s.y += floor(50 * 1.1 + 1);

    }

    end_scrollable_region(mappings_region, s.x + s.w, s.y, *scroll_value_mappings_region);

    draw_popups();
    Simp.swap_buffers(window);

    if index_to_remove >= 0 {
        mapping_to_remove := active_profile.mappings_array[index_to_remove];
        table_remove(*active_profile.mappings, mapping_to_remove.source.code);
        if mapping_to_remove.mode == .OVERRIDE || mapping_to_remove.mode == .NEUTRAL {
            table_remove(*active_profile.mappings, mapping_to_remove.destination.code);
        }
        array_ordered_remove_by_index(*active_profile.mappings_array, index_to_remove);
        table_remove(*state_table, dropdown_state_to_clean_up.hash);

        index_to_remove = -1;
    }
}

draw_new_profile_selector :: (r: Rect, data: *void) {
    //                    r = get_rect(10.5*k, 4*k, 1.8*k, 3*k);
    region, inside := begin_scrollable_region(r);

    NUM_BUTTONS :: 30;
    // button_height = floor(inside.w * .22 + .5);

    // @Incomplete: Add the scrolling offset when we have it.
    // @Incomplete: Scroll value is in pixels, what happens if the screen changes resolution?
    s := inside;
    s.h = 50;
    s.y -= scroll_value_new_profile;
    // button_theme.label_theme.alignment = .Center;
    // button_theme.font = null;

    opened_windows := get_list_of_programs();
    for opened_windows {
        _, _, released := button(s, it, identifier=it_index);
        if released {
            print("Program % selected\n", it);
            subwindow_info_new_profile.open = false;
            profiles[profiles.count -1].program = copy_string(it);
            current_mapping_state = .NOTHING;
        }

        if it_index != opened_windows.count  {
            s.y += floor(50 * 1.1 + 0.5);  // Just so r.y is in the right place for end_scrollable_region().
        }
    }

    end_scrollable_region(region, s.x + s.w, s.y + s.h, *scroll_value_new_profile);
}

init_fonts :: (window: Window_Type) {
    if !working_directory_set {
        path := path_strip_filename(get_path_of_running_executable());
        set_working_directory(path);
        working_directory_set = true;
    }

    dpi := get_dpi_scale(window);

    // Window height was here
    pixel_height := 600 / dpi / 24;
    button_font = Simp.get_font_at_size("data", "OpenSans-Bold.ttf", cast(s64)(pixel_height * dpi));
    assert(button_font != null);
}

UI_Font :: Simp.Dynamic_Font;

button_font: *UI_Font;

working_directory_set := false;
mapping_resolving_hook_is_installed := false;
mapping_setting_hook_is_installed := false;

#import "Basic"()(TEMP_ALLOCATOR_POISON_FREED_MEMORY=true);
#import "Hash_Table";
Input :: #import "Input";
Simp :: #import "Simp";
#import "GetRect_LeftHanded";
#import "Math";
#import "String";
#import "System";
#import "Window_Creation";
tfh :: #import "Text_File_Handler";

#import "Print_Vars";
