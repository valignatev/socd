#load "./xcb.jai";
#load "./uinput.jai";
#load "./xkbcommon.jai";
#load "./libinput.jai";
#load "./libudev.jai";

CURRENT_PLATFORM := Platform.LINUX;

// This might backfire, because this is configurable on Linux
// Might want to allocate it at runtime instead
MAX_PATH_LENGTH :: 4096;
XKB_EVDEV_OFFSET : u32 : 8;

KB_HOOK_SET := false;

global_xcb_connection: *xcb_connection_t;
// I genuinely don't know how bad it is to make libxkbcommon stuff global. Seems working idk...
global_xkb_context: *xkb_context;
global_xkb_keymap: *xkb_keymap;
global_xkb_state: *xkb_state;

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

NET_NAME_ATOM: xcb_atom_t;
NET_NAME := "_NET_WM_NAME";

detect_focused_program :: () {
    // @TODO: Might be useful to detect currently focused program at the start.
    // Theoretically, it would always be us, but there's actually a possibility
    // to click on the icon and switch to other program faster than socd starts.
    // For example, when you in a full-screen game, click Windows, press socd shortcut
    // and then quickly switch back to the game within like 500 milliseconds.
    // I haven't been able to pull this off on Linux, but Windows is too slow
    // to attach all needed hooks.
    con := global_xcb_connection;
    net_active_atom: xcb_atom_t;
    net_name_old_atom: xcb_atom_t;
    active := "_NET_ACTIVE_WINDOW";
    active_cookie := xcb_intern_atom(con, cast(u8)false, cast(u8)active.count, active.data);

    active_error: *xcb_generic_error_t;
    active_reply := xcb_intern_atom_reply(con, active_cookie, *active_error);

    if !active_reply {
        log_error("Can't get _NET_ACTIVE_WINDOW atom, error is: %\n", active_error.*);
        return;
    }

    net_active_atom = active_reply.atom;

    screen := xcb_setup_roots_iterator(xcb_get_setup(con)).data;
    root_window := screen.root;

    attrs: xcb_change_window_attributes_value_list_t;
    attrs.event_mask = cast(u32)xcb_event_mask_t.PROPERTY_CHANGE;

    change_cookie := xcb_change_window_attributes_aux_checked(con, root_window, .EVENT_MASK, *attrs);
    change_error := xcb_request_check(con, change_cookie);
    if change_error {
        log_error("Failed to listen to window focus events, error is %\n", change_error.*);
    }

    xcb_flush(con);

    while true {
        event := xcb_wait_for_event(con);
        if !event {
            log_error("I/O error while getting a window focused event");
            break;
        }
        response_type := event.response_type & ~0x80;
        if response_type == XCB_PROPERTY_NOTIFY {
            notify_event := cast(*xcb_property_notify_event_t)event;
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
                xcb_grab_server(con);
                input_focus_reply := xcb_get_input_focus_reply(con, xcb_get_input_focus(con), null);
                focused_window := input_focus_reply.focus;

                name := get_x11_window_name(focused_window);
                log("Name: %\n", name);
                xcb_ungrab_server(con);
                xcb_flush(con);
                // TODO: Better way to handle the title name, contains is probably not very
                // robust. Also it's case-sensitive for now :(
                for profile: profiles {
                    if contains(profile.program, name) {
                        set_kb_hook();
                    } else {
                        unset_kb_hook();
                    }
                }
            }
        }
    }
    c_free(active_reply);
    return;
}

_opened_programs: [..]string;

get_x11_window_name :: (window: u32) -> string {
    result: string;

    con := global_xcb_connection;
    name_error: *xcb_generic_error_t;
    name_old_error: *xcb_generic_error_t;

    // Some programs don't comply with EWMH and set old WM_NAME instead, try to get it as well
    name_cookie := xcb_get_property(con, 0, window, NET_NAME_ATOM, xx xcb_get_property_type_t.XCB_GET_PROPERTY_TYPE_ANY, 0, U32_MAX);
    name_old_cookie := xcb_get_property(con, 0, window, xx xcb_atom_enum_t.WM_NAME, xx xcb_atom_enum_t.STRING, 0, U32_MAX);

    name_reply := xcb_get_property_reply(con, name_cookie, *name_error);
    name_old_reply := xcb_get_property_reply(con, name_old_cookie, *name_old_error);


    // On Sway, I get no reply when the X11 window loses focus and it switches
    // to a Wayland-native application. So I let it be...
    if !name_reply && !name_old_reply {
        // Maybe socd unhook logic here
        xcb_ungrab_server(con);
        xcb_flush(con);
        return "";
    }

    name_len := xcb_get_property_value_length(name_reply);
    name_old_len := xcb_get_property_value_length(name_old_reply);
    if !name_len {
        result.count = name_old_len;
        result.data = xcb_get_property_value(name_old_reply);
    } else {
        result.count = name_len;
        result.data = xcb_get_property_value(name_reply);
    }

    c_free(name_reply);
    c_free(name_old_reply);

    return result;
}

get_list_of_programs :: () -> []string {
    using current_program_state;
    con := global_xcb_connection;
    result := _opened_programs;


    screen := xcb_setup_roots_iterator(xcb_get_setup(con)).data;
    root_window := screen.root;

    tree_cookie := xcb_query_tree(con, root_window);
    tree_reply := xcb_query_tree_reply(con, tree_cookie, null);

    if (tree_reply) {
        children_data := xcb_query_tree_children(tree_reply);
        children_count := xcb_query_tree_children_length(tree_reply);

        children: []u32;
        children.data = children_data;
        children.count = children_count;

        for children {

            attrs_error: *xcb_generic_error_t;
            attrs_cookie := xcb_get_window_attributes(con, it);
            attrs_reply := xcb_get_window_attributes_reply(con, attrs_cookie, *attrs_error);

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
                System :: #import "System";

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

    devices := split(devices_str, "\n\n");
    for devices {
        device_props := split(it, "\n");
        for prop: device_props {
            if prop == "N: Name=\"SOCD keyboard\"" {
                return true;
            }
        }
    }
    return false;
}

start_logging_keys_in_a_thread :: (arg: *void) -> *void #c_call {
    push_context {

        uinput_fd := open("/dev/uinput", O_RDWR | O_NONBLOCK);

        if uinput_fd < 0 {

            System :: #import "System";

            code, s := System.get_error_value_and_string();
            log_error("Could not open \"/dev/uinput\" for creating a virtual keyboard, error: %\n", s);
            log_error("Reopen the program with root privileges, or configure required udev rules\n");
            return null;
        }

        result := ioctl(uinput_fd, UI_SET_EVBIT, EV_KEY);
        if result == -1 {
            System :: #import "System";

            code, s := System.get_error_value_and_string();
            log_error("Coulnd't initialize virtual keyboard: %, %\n", code, s);
            return null;
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
            System :: #import "System";

            code, s := System.get_error_value_and_string();
            log_error("Couldn't setup a virtual keyboard: %, %\n", code, s);
            return null;
        }
        // Should I really call destroy? Seems like Linux destroys my virtual keyboard anyway
        // defer ioctl(uinput_fd, UI_DEV_DESTROY);
        result = ioctl(uinput_fd, UI_DEV_CREATE);
        if result == -1 {
            System :: #import "System";

            code, s := System.get_error_value_and_string();
            log_error("Couldn't create a virtual keyboard: %, %\n", code, s);
            return null;
        }

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
        // It's not necessary, OS should do that anyway
        close(uinput_fd);
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

            written := write(uinput_fd, input_events.data, size_of(input_event) * output_events.count);
            if written < 0 {
                log_error("Could not pass the event on\n");
            }

            // We're updating xkb state here for handling Numlock correctly, but we don't
            // even take advantage of that, because numpad keys are specialcased in get_key_name anyway
            // So maybe we don't even need to update the state at all. At least until we have a proper
            // keyboard layouts/localization support.
            xkb_keycode: xkb_keycode_t = XKB_EVDEV_OFFSET + key;
            xkb_state_update_key(global_xkb_state, xkb_keycode, xx state);
        }

        if key == KEY_NUMLOCK return;

        using current_program_state;
        if current_program_state.active_state == .SETTING_SOURCE || current_program_state.active_state == .SETTING_DESTINATION {
            next_state := Mapping_State.NOTHING;
            if ev.value == IS_DOWN && ev.type == EV_KEY {
                if active_state == .SETTING_SOURCE {
                    print("mappings before:\n");
                    for active_profile.mappings {
                        dest_formatted := tprint("mode: %, kind: %, code: %", it.mode, it.kind, get_key_name(it.code));
                        print("source: %, dest: %\n", get_key_name(it_index), dest_formatted);
                    }

                    old_source_code := active_mapping.source.code;
                    if old_source_code == KEY_RESERVED next_state = .SETTING_DESTINATION;

                    old_binding_from_old_source, found := table_find(*active_profile.mappings, old_source_code);
                    print("Old source is %\n", old_binding_from_old_source);

                    active_mapping.*.source.code = ev.code;
                    table_set(*active_profile.mappings, active_mapping.source.code, active_mapping.destination);

                    if active_mapping.mode == .OPPOSITE || active_mapping.mode == .NEUTRAL {
                        table_remove(*active_profile.mappings, active_mapping.destination.code);
                        table_set(*active_profile.mappings, active_mapping.destination.code, active_mapping.source);
                    }
                    // I don't think it matters whether we found it.
                    table_remove(*active_profile.mappings, old_source_code);

                    print("mappings after:\n");
                    for active_profile.mappings {
                        dest_formatted := tprint("mode: %, kind: %, code: %", it.mode, it.kind, get_key_name(it.code));
                        print("source: %, dest: %\n", get_key_name(it_index), dest_formatted);
                    }

                    log("Set source %\n", ev.code);
                } else if active_state == .SETTING_DESTINATION {
                    old_destination_code := active_mapping.destination.code;
                    active_mapping.*.destination.code = ev.code;

                    table_set(*active_profile.mappings, active_mapping.source.code, active_mapping.destination);
                    if active_mapping.mode == .OPPOSITE || active_mapping.mode == .NEUTRAL {
                        table_remove(*active_profile.mappings, old_destination_code);
                        table_set(*active_profile.mappings, active_mapping.destination.code, active_mapping.source);
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

    xkb_keycode: xkb_keycode_t = XKB_EVDEV_OFFSET + key_scan_code;
    keysym := xkb_state_key_get_one_sym(global_xkb_state, xkb_keycode);
    // This doesn't do anything for some reason
    keysym = xkb_keysym_to_upper(keysym);

    // First is a dummy call just to get a length of the string
    length := xkb_state_key_get_utf8(global_xkb_state, xkb_keycode, null, 0);
    if length {
        // Allocate one more for that sweet null terminator. We'll subtract the count later
        key_name = alloc_string(length + 1);
        xkb_state_key_get_utf8(global_xkb_state, xkb_keycode, key_name.data, xx (key_name.count));

    // If the key doesn't have utf8 representation in libxkbcommon (or it's a whitespace character) - get its keysym name instead.
    }
    // -1 to account for trailing null character
    if !length || !(trim(key_name).count - 1) {
        length := xkb_keysym_get_name(keysym, null, 0);
        key_name = alloc_string(length + 1);
        xkb_keysym_get_name(keysym, key_name.data, xx key_name.count);
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

// Mostly a copy from Window_Creation module with some custom window hints.
create_window :: (window_x := 0, window_y := 0, parent: Window_Type = None, background_color_rgb := WC.DEFAULT_WINDOW_CREATION_COLOR, wanted_msaa: s32 = WC.DEFAULT_MSAA) -> Window {
    width := window_width;
    height := window_height;
    window_name := "Hitboxer";
    if !x_global_display
        init_global_display();

    d := x_global_display;

    XLockDisplay(d);
    root := DefaultRootWindow(d);
    if parent == None then parent = root;

    screen := DefaultScreen(d);

    attr := s32.[
        GLX_RGBA,
        GLX_DEPTH_SIZE, 24,
        GLX_DOUBLEBUFFER,
        GLX_RED_SIZE, 8,
        GLX_GREEN_SIZE, 8,
        GLX_BLUE_SIZE, 8,
        GLX_STENCIL_SIZE, 8,
        GLX_SAMPLE_BUFFERS, cast(s32) ifx wanted_msaa then 1 else 0,
        GLX_SAMPLES,        wanted_msaa,
        None
    ];

    vi := glXChooseVisual(d, screen, attr.data);
    cmap := XCreateColormap(d, parent, vi.visual, AllocNone);

    to_u16 :: (f: float) -> u16 #expand {
        u := clamp(cast(s32)(f * 65535), 0, 65535);
        return cast(u16) u;
    }

    background_color: XColor;
    background_color.flags |= DoRed | DoGreen | DoBlue;
    background_color.red     = to_u16(background_color_rgb[0]);
    background_color.green   = to_u16(background_color_rgb[1]);
    background_color.blue    = to_u16(background_color_rgb[2]);
    XAllocColor(d, cmap, *background_color);

    swa: XSetWindowAttributes;
    swa.colormap = cmap;
    swa.event_mask = ExposureMask | KeyPressMask | KeyReleaseMask | ButtonPressMask | ButtonReleaseMask | StructureNotifyMask | FocusChangeMask | EnterWindowMask | LeaveWindowMask | PointerMotionHintMask | PointerMotionMask;
    swa.background_pixel = background_color.pixel;
    win := XCreateWindow(d, parent, xx window_x, xx window_y, xx width, xx height, 0, vi.depth, InputOutput, vi.visual, cast(u64) (CWColormap | CWEventMask), *swa);

    win_name := temp_c_string(window_name);
    if window_name then XStoreName(d, win, win_name);

    class_hints := XAllocClassHint();
    if class_hints {
        // this changes the application name for now (not the window title)
        // unset, gnome3 will just display "Unknown" in the activity bar and the dock
        if window_name {
            class_hints.res_name = win_name;
            class_hints.res_class = win_name;
        } else {
            class_hints.res_name = "jai-application";
            class_hints.res_class = "JAI-Application";
        }
        XSetClassHint(d, win, class_hints);
    }

    // My changes to set window type to force it into floating mode on
    // tiling window managers like i3wm
    // @cleanup: It's probably better to set max width and max height hints instead...
    props: [2]Atom;

    props[1] = XInternAtom(d, "_NET_WM_WINDOW_TYPE", False);
    props[0] = XInternAtom(d, "_NET_WM_WINDOW_TYPE_UTILITY", False);

    XChangeProperty(d, win, props[1], XA_ATOM, 32, PropModeReplace, cast(*u8)*props[0], 1);
    XMapWindow(d, win);

    XSetWMProtocols(d, win, *x_global_wm_delete_window, 1);


    // TODO: global
    x_global_input_context = XCreateIC(
        x_global_input_method,
        XNClientWindow, win,
        XNFocusWindow, win,
        XNInputStyle, XIMPreeditNothing | XIMStatusNothing,
        null,
    );

    if x_global_input_context {
        log_error("Could not create X11 input context\n");
    }

    array_add(*x_global_windows, win);

    XUnlockDisplay(d);
    return win;
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

libinput_opened_devices: Table(string, s32);
uinput_device_created := false;
virtual_device_path: string;

open_restricted :: (path_raw: *u8, flags: s32, user_data: *void) -> s32 #c_call {
    push_context {
        path := to_string(path_raw);

        if !uinput_device_created && is_virtual_device(path) {
            uinput_device_created = true;
            virtual_device_path = path;

            print("Bailed out of multiplexing a virtual keyboard %\n", path);
            return -1;
        }

        fd := open(path_raw, flags);

        table_add(*libinput_opened_devices, path, fd);
        if is_keyboard(fd, path) {
            print("%\n", path);
            grab_result := ioctl(fd, EVIOCGRAB, 1);
            if grab_result < 0 {
                log_error("Could not grab % for controlling its inputs\n", path);
            }
            return fd;
        }
        // TODO: port device closing shenanigans that offload it into a separate thread.
        // close(fd);
        return -1;
    }
}

close_restricted :: (fd: s32, user_data: *void) #c_call {
    close(fd);
}

interface_: libinput_interface = .{open_restricted, close_restricted};


platform_init :: (window: u64) -> success: bool #must {

    // x11 and libxkbcommon
    {
        // xcb X11 connection
        global_xcb_connection = xcb_connect(null, null);
        con_errors := xcb_connection_has_error(global_xcb_connection);

        if con_errors {
            log_error("Can't connect to X11 with xcb, error code is: %\n", con_errors);
            return false;
        }


        // Atoms
        name_error: *xcb_generic_error_t;
        name_cookie := xcb_intern_atom(global_xcb_connection, cast(u8)false, cast(u8)NET_NAME.count, NET_NAME.data);
        name_reply := xcb_intern_atom_reply(global_xcb_connection, name_cookie, *name_error);

        if !name_reply {
            log_error("Can't get _NET_WM_NAME atom, error is: %\n", name_error.*);
            return false;
        }
        NET_NAME_ATOM = name_reply.atom;

        // and libxkbcommon
        base_xkb_event: u8;

        major: u16 = 1;
        minor: u16 = 0;
        ret := xkb_x11_setup_xkb_extension(
            global_xcb_connection,
            major,
            minor,
            0,
            *major, *minor, *base_xkb_event, null,
        );

        if (!ret) {
            log_error("Couldn't setup XKB extension\n");
            return false;
        }

        global_xkb_context = xkb_context_new(.NO_FLAGS);

        core_kbd_device_id := xkb_x11_get_core_keyboard_device_id(global_xcb_connection);
        if (core_kbd_device_id == -1) {
            log_error("Couldn't find core keyboard device\n");
            return false;
        } else {
            log("Core keyboard device is %\n", core_kbd_device_id);
        }

        global_xkb_keymap = xkb_x11_keymap_new_from_device(global_xkb_context, global_xcb_connection, core_kbd_device_id, 0);

        global_xkb_state = xkb_x11_state_new_from_device(global_xkb_keymap, global_xcb_connection, core_kbd_device_id);
        if (!global_xkb_state) {
            log_error("Couldn't create xkb state for device\n");
            return false;
        }
    }

    // TODO: This should be in a separate thread, it affects startup times GREATLY!!!!
    // udev and libinput
    {
        udev = udev_new();
        if !udev_context {
            log_error("Couldn't initialize udev context\n");
            return false;
        }

        libinput = libinput_udev_create_context(*interface_, null, udev);
        if !libinput {
            log_error("Couldn't initialize libinput context\n");
            return false;
        }

        // NOTE: Is there any issue with hardcoding a single seat here?
        // Are setups where input devices are spread across multiple seats even exit?
        if libinput_udev_assign_seat(libinput, "seat0") == -1 {
            log_error("Libinput couldn't assign seat\n");
            return false;
        }
    }

    return true;
}

platform_deinit :: (window: u64) {
    // A funny "pretend to be fast" hack. On Linux, closing a lot of file descriptors
    // takes a while, so we can close the window instantly as if our program was very fast!
    XWithdrawWindow(x_global_display, window, 0);
}

libc :: #system_library "libc";
c_free :: (memory: *void) #foreign libc "free";

#import "Memory";
#import "POSIX";
#import "Sort";
#import "X11";
// To expose module-scoped WC.DEFAULT_WINDOW_CREATION_COLOR and WC.DEFAULT_MSAA
WC :: #import "Window_Creation";
