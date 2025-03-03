// #import,file "./modules/JDL/xcb.jai";
#load "./uinput.jai";
#load "./libinput.jai";
#load "./libudev.jai";

CURRENT_PLATFORM :: Platform.LINUX;
DEFAULT_WINDOW_CREATION_COLOR :: float.[.15,.15,.2];
DEFAULT_MSAA: s32 : 4;

uinput_fd: s32 = -1;

// This might backfire, because this is configurable on Linux
// Might want to allocate it at runtime instead
MAX_PATH_LENGTH :: 4096;
XKB_EVDEV_OFFSET : u32 : 8;

KB_HOOK_SET := false;

// major and minor are straight from Linux kernel
major :: inline (dev: u64) -> u64 {
    return dev >> 8;
}

minor :: inline (dev: u64) -> u64 {
    return dev & 0xff;
}

get_dpi_scale :: (window: Window_Type) -> float {
    // @TODO: Implement
    return 1;
}

detect_focused_program :: () {
    using current_program_state;
    // @TODO: Might be useful to detect currently focused program at the start.
    // Theoretically, it would always be us, but there's actually a possibility
    // to click on the icon and switch to other program faster than socd starts.
    // For example, when you in a full-screen game, click Windows, press socd shortcut
    // and then quickly switch back to the game within like 500 milliseconds.
    // I haven't been able to pull this off on Linux, but Windows is too slow
    // to attach all needed hooks.
    con := JDL.main_display.xcb.handle;
    net_active_atom: xcb.xcb_atom_t;
    net_name_old_atom: xcb.xcb_atom_t;
    active := "_NET_ACTIVE_WINDOW";
    active_cookie := xcb.xcb_intern_atom(con, cast(u8)false, cast(u8)active.count, active.data);

    active_error: *xcb.xcb_generic_error_t;
    active_reply := xcb.xcb_intern_atom_reply(con, active_cookie, *active_error);

    if !active_reply {
        log_error("Can't get _NET_ACTIVE_WINDOW atom, error is: %\n", active_error.*);
        return;
    }

    net_active_atom = active_reply.atom;
    defer c_free(active_reply);

    screen := xcb.xcb_setup_roots_iterator(xcb.xcb_get_setup(con)).data;
    root_window := screen.root;

    attrs: xcb.xcb_change_window_attributes_value_list_t;
    attrs.event_mask = cast(u32)xcb.xcb_event_mask_t.PROPERTY_CHANGE;

    change_cookie := xcb.xcb_change_window_attributes_aux_checked(con, root_window, .EVENT_MASK, *attrs);
    change_error := xcb.xcb_request_check(con, change_cookie);
    if change_error {
        log_error("Failed to listen to window focus events, error is %\n", change_error.*);
    }

    xcb.xcb_flush(con);

    while true {
        event := xcb.xcb_wait_for_event(con);
        if !event {
            log_error("I/O error while getting a window focused event");
            break;
        }
        response_type := event.response_type & ~0x80;
        if response_type == xcb.XCB_PROPERTY_NOTIFY {
            notify_event := cast(*xcb.xcb_property_notify_event_t)event;
            // 0 is NewState, 1 is Deleted. NewState is probably when a window gets focus
            if notify_event.atom == net_active_atom && notify_event.state == 0 {
                // On Sway, I get two focus events for the same window when switching from
                // another X11 window. But I get only one focus event when I switch from
                // Wayland window to X11 window. Weird, on pure X11 this doesn't happen.

                // TODO: Grabbing the server is kinda expensive and disruptive. And the only upside is that
                // it guarantees that the window that is focused won't get unfocused or destroyed
                // while we're fetching its options, which isn't a hard requirements for us.
                // So maybe we don't need to grab the server and just handle the situation where we get bogus
                // properties instead. Most likely, we'll get xcb_window_error_t
                xcb.xcb_grab_server(con);
                input_focus_reply := xcb.xcb_get_input_focus_reply(con, xcb.xcb_get_input_focus(con), null);
                focused_window := input_focus_reply.focus;

                name := get_x11_window_name(focused_window);
                log("Name: %\n", name);
                xcb.xcb_ungrab_server(con);
                xcb.xcb_flush(con);
                // TODO: Better way to handle the title name, contains is probably not very
                // robust. Also it's case-sensitive for now :(
                hook_is_set_by_profile := false;
                for profile: profiles {
                    if contains(profile.program, name) {
                        active_profile = *profile;
                        set_kb_hook();
                        hook_is_set_by_profile = true;
                        break;
                    }
                }
                if !hook_is_set_by_profile {
                    // This is likely a pointer on a stack, I have no idea how it worked,
                    // Because on Linux it literally dies lmao
                    global_profile := profiles[0];
                    if global_profile.mappings_array.count > 0 {
                        active_profile = *global_profile;
                        set_kb_hook();
                        continue;
                    }
                } else {
                    continue;
                }

                unset_kb_hook();
            }
        }
    }
}

_opened_programs: [..]string;

get_x11_window_name :: (window: u32) -> string {
    result: string;

    xd := *JDL.main_display.xcb;
    con := xd.handle;
    name_error: *xcb.xcb_generic_error_t;
    name_old_error: *xcb.xcb_generic_error_t;

    // Some programs don't comply with EWMH and set old WM_NAME instead, try to get it as well
    name_cookie := xcb.xcb_get_property(con, 0, window, xd.atoms._NET_WM_NAME, xx xcb.xcb_get_property_type_t.XCB_GET_PROPERTY_TYPE_ANY, 0, U32_MAX);
    name_old_cookie := xcb.xcb_get_property(con, 0, window, xx xcb.xcb_atom_enum_t.WM_NAME, xx xcb.xcb_atom_enum_t.STRING, 0, U32_MAX);

    name_reply := xcb.xcb_get_property_reply(con, name_cookie, *name_error);
    name_old_reply := xcb.xcb_get_property_reply(con, name_old_cookie, *name_old_error);

    defer {
        c_free(name_reply);
        c_free(name_old_reply);
    }

    // On Sway, I get no reply when the X11 window loses focus and it switches
    // to a Wayland-native application. So I let it be...
    if !name_reply && !name_old_reply {
        // Maybe socd unhook logic here
        xcb.xcb_ungrab_server(con);
        xcb.xcb_flush(con);
        return "";
    }

    name_len := xcb.xcb_get_property_value_length(name_reply);
    name_old_len := xcb.xcb_get_property_value_length(name_old_reply);
    if !name_len {
        result.count = name_old_len;
        result.data = xcb.xcb_get_property_value(name_old_reply);
    } else {
        result.count = name_len;
        result.data = xcb.xcb_get_property_value(name_reply);
    }

    return result;
}

get_list_of_programs :: () -> []string {
    using current_program_state;
    con := JDL.main_display.xcb.handle;
    result := _opened_programs;

    screen := xcb.xcb_setup_roots_iterator(xcb.xcb_get_setup(con)).data;
    root_window := screen.root;

    tree_cookie := xcb.xcb_query_tree(con, root_window);
    tree_reply := xcb.xcb_query_tree_reply(con, tree_cookie, null);

    if (tree_reply) {
        children_data := xcb.xcb_query_tree_children(tree_reply);
        children_count := xcb.xcb_query_tree_children_length(tree_reply);

        children: []u32;
        children.data = children_data;
        children.count = children_count;

        for children {

            attrs_error: *xcb.xcb_generic_error_t;
            attrs_cookie := xcb.xcb_get_window_attributes(con, it);
            attrs_reply := xcb.xcb_get_window_attributes_reply(con, attrs_cookie, *attrs_error);

            registered_events := attrs_reply.all_event_masks;
            if registered_events & (.KEY_PRESS | .KEY_RELEASE | .BUTTON_PRESS | .BUTTON_RELEASE | .EXPOSURE | .VISIBILITY_CHANGE | .FOCUS_CHANGE) == 0 {
                continue;
            }

            defer c_free(attrs_reply);

            name := get_x11_window_name(it);
            if name.count > 0 {
                name_lower := to_lower_copy(name,, temp);
                search_lower := to_lower_copy(active_search.text,, temp);
                if (active_search.text.count && contains(name_lower, search_lower)) || !active_search.text.count array_add(*result, copy_string(name));
            }
        }
    }

    return result;
}

set_kb_hook :: () {
    KB_HOOK_SET = true;
    return;
}

unset_kb_hook :: () {
    KB_HOOK_SET = false;
    return;
}

Device :: struct {
    event_file: string;
    name: string;
    file_descriptor: s32;
}


// This is basically test_bit from linux kernel:
// https://github.com/torvalds/linux/blob/master/tools/testing/selftests/iommu/iommufd_utils.h#L34
// Every key code is encoded as a single positional bit in the key_bits returned by EVIOCGBIT,
// This is why we need KEY_MAX amount of bits, or (KEY_MAX / 8) + 1 amount of bytes.
// At least on desktop Linux this is 96.
test_key :: (key: u32) -> u32 #expand {
    return `key_bits[key/8] & (xx 1 << (key % 8));
}

File_Descriptors :: struct {
    counter: s32;
    array: [256]s32;
}

opened_file_descriptors_for_candidates: File_Descriptors;

close_descriptors :: (raw_descriptors: *void) -> *void #c_call {
    push_context {
        descriptors := cast(*File_Descriptors)raw_descriptors;
        for descriptors.array {
            if !it break;
            error := close(it);
            if error {
                code, s := System.get_error_value_and_string();
                log_error("Closing file descriptor '%' failed: code %, '%'.\n", it, code, s);
            } else {
                descriptors.array[it_index] = 0;
            }
        }
    }
    return null;
}

free_candidates :: (candidates: *[..]Device) {
    array_free(candidates.*);
    tid: pthread_t ;
    pthread_create(*tid, null, close_descriptors, *opened_file_descriptors_for_candidates);
}

read_entire_proc_info :: () -> [..]u8 {
    data: [..] u8;
    buff: [4096] u8;
    fd := open("/proc/bus/input/devices", O_RDONLY);
    if fd < 0 {
        log_error("Failed to open '/proc/bus/input/devices': %\n", errno());
        return data;
    }
    defer close(fd);

    while true {
        rs := read(fd, buff.data, buff.count);
        if rs < 0 {
            log_error("Failed to read data from '/proc/bus/input/devices': %\n", errno());
            return data;
        }
        if !rs break;
        array_reserve(*data, data.count + rs);
        memcpy(data.data + data.count, buff.data, rs);
        data.count += rs;
    }
    return data;
}

is_virtual_device :: (path: string) -> bool {
    devices_raw := read_entire_proc_info();
    defer array_free(devices_raw);
    devices_str : string = xx devices_raw;

    // This should never fail
    _, _, target_event := split_from_right(path, "/");

    devices := split(devices_str, "\n\n");
    get_handlers := false;
    for devices {
        device_props := split(it, "\n");
        for prop: device_props {
            if prop == "N: Name=\"SOCD keyboard\"" {
                get_handlers = true;
            }
            if get_handlers && begins_with(prop, "H: Handlers=") {
                handlers := split(slice(prop, 12, prop.count), " ",, temp);
                result := array_find(handlers, target_event);
                return result;
            }
        }
    }
    return false;
}

start_logging_keys_in_a_thread :: (arg: *void) -> *void #c_call {
    push_my_context();
    fd := libinput_get_fd(libinput);
    // TODO: apparently, libinput doesn't handle gamepads. So I need to open and add them to
    // this descriptor set myself. Sadge.
    fds := pollfd.{
        fd,
        POLLIN,
        0
    };
    while true {
        poll_result := poll(*fds, 1, -1);
        if poll_result <= 0 {
            log_error("libinput is cooked: % (ERROR REASON HERE)\n", errno());
        }

        libinput_dispatch(libinput);
        while event := libinput_get_event(libinput) {
            handle_libinput_event(event, uinput_fd);
            libinput_event_destroy(event);
        }
    }

    return null;
}

handle_libinput_event :: (event: *libinput_event, uinput_fd: s32) {

    // NOTE: It doesn't look like libinput passes us SYN events from the queue, so we have to
    // recreate it manually. it doesn't pass those HID events either. I wonder if it's fine to
    // just ignore them anyway?

    key_bits_num :: (KEY_MAX / 8) + 1;
    key_bits: [key_bits_num]u8;
    output_events: [2]input_event;
    input_events: [2]input_event;
    write_original := true;
    event_type := libinput_event_get_type(event);
    if event_type == .LIBINPUT_EVENT_POINTER_BUTTON {
        pointer_event := libinput_event_get_pointer_event(event);
        // printf ("pointer button event\n");
    }
    else if event_type == .LIBINPUT_EVENT_DEVICE_REMOVED {
        device := libinput_event_get_device(event);
        device_name := tprint("/dev/input/%", to_string(libinput_device_get_sysname(device)));
        if device_name == virtual_device_path {
            uinput_device_created = false;
        }
    }
    else if event_type == .LIBINPUT_EVENT_KEYBOARD_KEY {
        keyboard_event := libinput_event_get_keyboard_event(event);
        key := libinput_event_keyboard_get_key(keyboard_event);
        state := libinput_event_keyboard_get_key_state(keyboard_event);
        device := libinput_event_get_device(event);
        device_name := tprint("/dev/input/%", to_string(libinput_device_get_sysname(device)));
        // print("device_name: %\n", device_name);

        // Reconstruct input_event from libinput_event.
        input_events[0] = input_event.{
            time=.{},
            type=EV_KEY,
            code=cast(u16)key,
            value=xx state,
        };
        input_events[1] = input_event.{
            time=.{},
            type=EV_SYN,
            code=SYN_REPORT,
            value=0,
        };
        ev := input_events[0];
        if state == .LIBINPUT_KEY_STATE_PRESSED {
            print("% pressed\n", get_key_name(key));
        }

        // Pass the real event into our virtual device.
        defer if write_original {

            // print("writing_original: %\n", key);
            written := write(uinput_fd, input_events.data, size_of(input_event) * output_events.count);
            if written < 0 {
                log_error("Could not pass the event on\n");
            }

            // We're updating xkb state here for handling Numlock correctly, but we don't
            // even take advantage of that, because numpad keys are specialcased in get_key_name anyway
            // So maybe we don't even need to update the state at all. At least until we have a proper
            // keyboard layouts/localization support.
            xkb_keycode: xkb.xkb_keycode_t = XKB_EVDEV_OFFSET + key;
            xkb.xkb_state_update_key(JDL.main_display.xcb.xkb_state, xkb_keycode, xx state);
        }

        if key == KEY_NUMLOCK return;

        using current_program_state;
        if current_program_state.active_state == .SETTING_SOURCE || current_program_state.active_state == .SETTING_DESTINATION {
            next_state := Mapping_State.NOTHING;
            if ev.value == IS_DOWN && ev.type == EV_KEY {
                if active_state == .SETTING_SOURCE {
                    print("mappings before:\n");
                    for active_profile_in_ui.mappings {
                        dest_formatted := tprint("mode: %, kind: %, code: %", it.mode, it.kind, get_key_name(it.code));
                        print("source: %, dest: %\n", get_key_name(it_index), dest_formatted);
                    }

                    old_source_code := active_mapping.source.code;
                    if old_source_code == KEY_RESERVED next_state = .SETTING_DESTINATION;

                    old_binding_from_old_source, found := table_find(*active_profile_in_ui.mappings, old_source_code);
                    print("Old source is %\n", old_binding_from_old_source);

                    active_mapping.*.source.code = ev.code;
                    table_set(*active_profile_in_ui.mappings, active_mapping.source.code, active_mapping.destination);

                    if active_mapping.mode == .OPPOSITE || active_mapping.mode == .NEUTRAL {
                        table_remove(*active_profile_in_ui.mappings, active_mapping.destination.code);
                        table_set(*active_profile_in_ui.mappings, active_mapping.destination.code, active_mapping.source);
                    }
                    // I don't think it matters whether we found it.
                    table_remove(*active_profile_in_ui.mappings, old_source_code);

                    print("mappings after:\n");
                    for active_profile_in_ui.mappings {
                        dest_formatted := tprint("mode: %, kind: %, code: %", it.mode, it.kind, get_key_name(it.code));
                        print("source: %, dest: %\n", get_key_name(it_index), dest_formatted);
                    }

                    log("Set source %\n", ev.code);
                } else if active_state == .SETTING_DESTINATION {
                    next_state = .NOTHING;
                    old_destination_code := active_mapping.destination.code;
                    active_mapping.*.destination.code = ev.code;

                    table_set(*active_profile_in_ui.mappings, active_mapping.source.code, active_mapping.destination);
                    if active_mapping.mode == .OPPOSITE || active_mapping.mode == .NEUTRAL {
                        table_remove(*active_profile_in_ui.mappings, old_destination_code);
                        table_set(*active_profile_in_ui.mappings, active_mapping.destination.code, active_mapping.source);
                    }
                    log("Set destination %\n", ev.code);
                }

                if next_state == .NOTHING {
                    finalize_state();
                } else {
                    active_state = next_state;
                }
            }
            return;
        }

        if !KB_HOOK_SET {
            return;
        }

        // NOTE: We're counting on the correct mode being set on the destination keybind
        // in the hash table. At least for now
        bind := get_key_mapping(ev.code);
        if bind == dummy_bind {
            return;
        }

        if bind.mode == .REMAP {
            write_original = false;
            bind_name := get_key_name(bind.code);
            log("Found mapping: %\n", bind_name);
            output_events[0] = input_event.{
                type=EV_KEY,
                code=cast(u16)bind.code,
                value=ev.value,
            };
            output_events[1] = input_event.{
                type=EV_SYN,
                code=SYN_REPORT,
                value=0,
            };

            written := write(uinput_fd, output_events.data, size_of(input_event) * output_events.count);
            if written < 0 {
                log_error("Could not write one to one mapping for %\n", bind_name);
            }
            return;
        }

        if bind.mode == .OPPOSITE || bind.mode == .NEUTRAL {
            opposing_code := bind.code;

            device_fd, found := table_find(*libinput_opened_devices, device_name);
            if !found {
                log_error("Can't get an open file descriptor for %\n", device_name);
                return;
            }
            key_bit_result := ioctl(device_fd, EVIOCGKEY(key_bits.count), *key_bits);
            if key_bit_result < key_bits_num {
                log_error("Can't read the device key state\n");
                return;
            }
            if ev.value == 1 {
                if test_key(opposing_code) {
                    if bind.mode == .NEUTRAL {
                        write_original = false;
                    }
                    output_events[0] = input_event.{
                        type=EV_KEY,
                        code=cast(u16)opposing_code,
                        value=IS_UP,
                    };
                    output_events[1] = input_event.{
                        type=EV_SYN,
                        code=SYN_REPORT,
                        value=0,
                    };

                    written := write(uinput_fd, output_events.data, size_of(input_event) * output_events.count);
                    if written < 0 {
                        log_error("Could not release the key\n");
                    }
                }
            } else if ev.value == 0 {
                if test_key(opposing_code) {
                    output_events[0] = input_event.{
                        time=.{},
                        type=EV_KEY,
                        code=cast(u16)opposing_code,
                        value=IS_DOWN,
                    };
                    output_events[1] = input_event.{
                        time=.{},
                        type=EV_SYN,
                        code=SYN_REPORT,
                        value=0,
                    };
                    written := write(uinput_fd, output_events.data, size_of(input_event) * output_events.count);
                    if written < 0 {
                        log_error("Could not repress the key\n");
                    }
                }
            }
        }
    }
}

start_logging_keys :: () {
    tid: pthread_t;
    pthread_create(*tid, null, start_logging_keys_in_a_thread, null);
}

start_detecting_focused_program_in_a_thread :: (arg: *void) -> *void #c_call {
    push_context {
        detect_focused_program();
    }
    return null;
}

start_detecting_focused_program :: () {
    tid: pthread_t ;
    pthread_create(*tid, null, start_detecting_focused_program_in_a_thread, null);
}

unset_mapping_setting_hook :: () {
    // @TODO: Implement
    return;
}


set_key_mapping_hook :: (window: Window_Type) {
    // It does nothing for now, because logging loop handles that.
    return;
}

get_key_name :: (key_scan_code: u32) -> string {
    if key_scan_code == KEY_RESERVED return "...";
    cached := KEY_NAMES[key_scan_code];
    if cached return cached;

    // Special case for Escape - because libxkbcommon has ^[ for it as utf8 representation lol.
    if key_scan_code == {
        case KEY_ESC;
            KEY_NAMES[KEY_ESC] = "Esc";
            return "Esc";
        case KEY_BACKSPACE;
            KEY_NAMES[KEY_BACKSPACE] = "Backspace";
            return "Backspace";
        case KEY_DELETE;
            KEY_NAMES[KEY_DELETE] = "Del";
            return "Del";
        case KEY_PAGEUP;
            KEY_NAMES[KEY_PAGEUP] = "PgUp";
            return "PgUp";
        case KEY_PAGEDOWN;
            KEY_NAMES[KEY_PAGEDOWN] = "PgDown";
            return "PgDown";
        case KEY_KP0; return "Num 0";
        case KEY_KP1; return "Num 1";
        case KEY_KP2; return "Num 2";
        case KEY_KP3; return "Num 3";
        case KEY_KP4; return "Num 4";
        case KEY_KP5; return "Num 5";
        case KEY_KP6; return "Num 6";
        case KEY_KP7; return "Num 7";
        case KEY_KP8; return "Num 8";
        case KEY_KP9; return "Num 9";
        case KEY_KPMINUS; return "Num -";
        case KEY_KPPLUS; return "Num +";
        case KEY_KPDOT; return "NUM .";
        case KEY_KPENTER; return "Num Ent";
    }

    key_name: string;

    xkb_keycode: xkb.xkb_keycode_t = XKB_EVDEV_OFFSET + key_scan_code;
    keysym := xkb.xkb_state_key_get_one_sym(JDL.main_display.xkb_state, xkb_keycode);
    // This doesn't do anything for some reason
    keysym = xkb.xkb_keysym_to_upper(keysym);

    // First is a dummy call just to get a length of the string
    length := xkb.xkb_state_key_get_utf8(JDL.main_display.xcb.xkb_state, xkb_keycode, null, 0);
    if length {
        // Allocate one more for that sweet null terminator. We'll subtract the count later
        key_name = alloc_string(length + 1);
        xkb.xkb_state_key_get_utf8(JDL.main_display.xcb.xkb_state, xkb_keycode, key_name.data, xx (key_name.count));

    // If the key doesn't have utf8 representation in libxkbcommon (or it's a whitespace character) - get its keysym name instead.
    }
    // -1 to account for trailing null character
    if !length || !(trim(key_name).count - 1) {
        length := xkb.xkb_keysym_get_name(keysym, null, 0);
        key_name = alloc_string(length + 1);
        xkb.xkb_keysym_get_name(keysym, key_name.data, xx key_name.count);
    }

    key_name.count -= 1;

    // Capitalizing the key_name
    dummy := key_name;
    dummy.count = 1;
    // This only supports English letters
    to_upper_in_place(dummy);

    KEY_NAMES[key_scan_code] = key_name;
    return key_name;
}

udev: *udev_context;
libinput: *libinput_context;

// Straight up copypaste of keyboard detector
is_keyboard :: (device_fd: s32, device_path: string) -> bool {
    if device_fd < 0 {
        log_error("Couldn't open device % for checking out whether it's a keyboard\n", device_path);
        return false;
    }

    name: [256]u8;
    device_name: string;
    evbit: u32;

    name_length := ioctl(device_fd, EVIOCGNAME(name.count), *name);
    if name_length < 0 {
        log_error("Couldn't get device name: %\n", device_path);
    } else {
        device_name = alloc_string(name_length - 1);
        copy(device_name.data, name.data, device_name.count);
    }

    evbit_result := ioctl(device_fd, EVIOCGBIT(0, size_of(type_of(evbit))), *evbit);

    if !(evbit & (1 << EV_KEY)) {
        return false;
    }

    key_bits_num :: (KEY_MAX / 8) + 1;
    key_bits: [key_bits_num]u8;
    keys_ioctl_result := ioctl(device_fd, EVIOCGBIT(EV_KEY, key_bits.count), *key_bits);
    if keys_ioctl_result != key_bits_num {
        log_error("Something is wrong with reading key bits from device %, ioctl result is %, skipping it...\n", device_name, keys_ioctl_result);
        return false;
    }

    // TODO: Maybe extract these two ranges as keyboard ranges so they're reused here and when
    // creating a virtual keyboard.
    for KEY_ESC..cast(u32)KEY_MICMUTE {
        if test_key(it) return true;
    }
    for KEY_FN..cast(u32)KEY_FN_RIGHT_SHIFT {
        if test_key(it) return true;
    }
    return false;
}

platform_hide_to_tray :: (window: Window_Type) {

}

libinput_opened_devices: Table(string, s32);
uinput_device_created := false;
virtual_device_path: string;

open_restricted :: (path_raw: *u8, flags: s32, user_data: *void) -> s32 #c_call {
    push_my_context();
    path := to_string(path_raw);

    if !uinput_device_created && is_virtual_device(path) {
        uinput_device_created = true;
        virtual_device_path = path;

        print("Bailed out of multiplexing a virtual keyboard %\n", path);
        return -1;
    }

    fd := open(path_raw, flags);

    table_add(*libinput_opened_devices, path, fd);
    if is_keyboard(fd, path) && uinput_fd > 0 {
        print("%\n", path);
        // grab_result := ioctl(fd, EVIOCGRAB, 1);
        // if grab_result < 0 {
        //     log_error("Could not grab % for controlling its inputs\n", path);
        // }
        return fd;
    }
    // TODO: port device closing shenanigans that offload it into a separate thread.
    // close(fd);
    return -1;
}

close_restricted :: (fd: s32, user_data: *void) #c_call {
    close(fd);
}

interface_: libinput_interface = .{open_restricted, close_restricted};

platform_init :: () -> success: bool #must, init_reason: string {
    {
        uinput_fd = open("/dev/uinput", O_RDWR | O_NONBLOCK);

        if uinput_fd < 0 {
            code, s := System.get_error_value_and_string();
            // TODO: better error - hint the user at which exactly they need to configure in udev
            error_string := tprint("Could not open \"/dev/uinput\" for creating a virtual keyboard, error: %\n", s);
            error_string = tprint("% Reopen the program with root privileges, or configure required udev rules\n", error_string);
            return false, error_string;
        }

        result := ioctl(uinput_fd, UI_SET_EVBIT, EV_KEY);
        if result == -1 {
            code, s := System.get_error_value_and_string();
            error_string := tprint("Coulnd't initialize virtual keyboard: %, %\n", code, s);
            return false, error_string;
        }

        // Here I'm just trying to create a virtual keyboard with enough keys to hopefully
        // cover most usecases. It would be more reliable to first accumulate the union of all
        // available keys in open_restricted, and then use those keys here. But this is ok for now.
        // Inclusive intentionally
        for KEY_ESC..cast(u32)KEY_MICMUTE {
            result := ioctl(uinput_fd, UI_SET_KEYBIT, it);
            if result == -1 {
                log_error("Couldn't set keybit: %\n", it);
            }
        }
        for KEY_FN..cast(u32)KEY_FN_RIGHT_SHIFT {
            result := ioctl(uinput_fd, UI_SET_KEYBIT, it);
            if result == -1 {
                log_error("Couldn't set keybit: %\n", it);
            }
        }

        usetup: uinput_setup;
        usetup.id.bustype = BUS_USB;
        usetup.id.vendor = 0x6666;
        usetup.id.product = 0x6665;
        usetup.name = xx "SOCD keyboard".data;

        result = ioctl(uinput_fd, UI_DEV_SETUP, *usetup);
        if result == -1 {
            code, s := System.get_error_value_and_string();
            error_string := tprint("Couldn't setup a virtual keyboard: %, %\n", code, s);
            return false, error_string;
        }
        // Should I really call destroy? Seems like Linux destroys my virtual keyboard anyway
        result = ioctl(uinput_fd, UI_DEV_CREATE);
        if result == -1 {
            code, s := System.get_error_value_and_string();
            error_string := tprint("Couldn't create a virtual keyboard: %, %\n", code, s);
            return false, error_string;
        }
    }

    // TODO: This should be in a separate thread, it affects startup times GREATLY!!!!
    // udev and libinput
    {
        udev = udev_new();
        if !udev_context {
            return false, "Couldn't initialize udev context\n";
        }

        libinput = libinput_udev_create_context(*interface_, null, udev);
        if !libinput {
            return false, "Couldn't initialize libinput context\n";
        }

        // NOTE: Is there any issue with hardcoding a single seat here?
        // Are setups where input devices are spread across multiple seats even exit?
        if libinput_udev_assign_seat(libinput, "seat0") == -1 {
            return false, "Libinput couldn't assign seat\n";
        }
    }

    return true, "";
}

platform_after_window_created :: (window: Window_Type) -> bool #must {
    return true;
}

platform_deinit :: (window: Window_Type) {
    // If I don't destroy the virtual keyboard manually, I get stuck inputs when the program quits.
    ioctl(uinput_fd, UI_DEV_DESTROY);
    close(uinput_fd);
}

platform_wake_up_main_thread :: () {
    //
}

libc :: #system_library "libc";
c_free :: (memory: *void) #foreign libc "free";

#import "Memory";
#import "POSIX";
#import "Sort";
#import "String";
using JDL :: #import "JDL";
#import "Input";
