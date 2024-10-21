#load "./xcb.jai";
#load "./uinput.jai";
#load "./xkbcommon.jai";

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

patched_read_entire_file :: (name: string, zero_terminated := false, log_errors := true) -> string, bool {
    s: string;
    f, success := file_open(name, log_errors = log_errors);
    if !success return s, false;

    defer file_close(*f);

    s, success = patched_read_entire_file(f, zero_terminated);

    if log_errors && !success {
        System :: #import "System";

        // If we put this error report at a lower level, we could
        // indicate how far into the file the error occurred, etc.
        code, s := System.get_error_value_and_string();
        log("Read of '%' failed: code %, '%'.\n", name, code, s);
    }

    return s, success;
}

patched_read_entire_file :: (f: File, zero_terminated := false) -> string, bool {
    length, success := file_length(f);
    if !success  return "", false;

    zero_termination_size := cast(s32) zero_terminated;
    data := cast(*u8) alloc(length + zero_termination_size);
    if data == null return "", false;

    // documentation seems to suggest that fread gaurantees size*count is fully read back otherwise error
    // NOTE(NOOOO) - actually, if the number is shorter than the error it might also be just EOF.
    // This is the case when reading from HID descriptor, for example, and fread doesn't distinguish between
    // errors and EOF, so need to test manually. Hense, use patched procedure for now until I report it.
    single_read_length := fread(data, 1, cast (u64) length, f.handle);
    if single_read_length != cast(u64) length && !feof(f.handle) {
        free(data);
        return "", false;
    }

    s: string;
    s.count = cast(s64) single_read_length;
    s.data  = data;

    if zero_terminated s.data[length] = 0;

    return s, true;
}

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
    // @TODO: Might be useful to detect currently focused program at the start.
    // Theoretically, it would always be us, but there's actually a possibility
    // to click on the icon and switch to other program faster than socd starts.
    // For example, when you in a full-screen game, click Windows, press socd shortcut
    // and then quickly switch back to the game within like 500 milliseconds.
    // I haven't been able to pull this off on Linux, but Windows is too slow
    // to attach all needed hooks.
    con := global_xcb_connection;
    net_active_atom: xcb_atom_t;
    net_name_atom: xcb_atom_t;
    net_name_old_atom: xcb_atom_t;
    active := "_NET_ACTIVE_WINDOW";
    name := "_NET_WM_NAME";
    active_cookie := xcb_intern_atom(con, cast(u8)false, cast(u8)active.count, active.data);
    name_cookie := xcb_intern_atom(con, cast(u8)false, cast(u8)name.count, name.data);

    active_error: *xcb_generic_error_t;
    name_error: *xcb_generic_error_t;
    active_reply := xcb_intern_atom_reply(con, active_cookie, *active_error);
    name_reply := xcb_intern_atom_reply(con, name_cookie, *name_error);

    if !active_reply {
        log_error("Can't get _NET_ACTIVE_WINDOW atom, error is: %\n", active_error.*);
        return;
    }

    if !name_reply {
        log_error("Can't get _NET_WM_NAME atom, error is: %\n", name_error.*);
        return;
    }

    net_active_atom = active_reply.atom;
    net_name_atom = name_reply.atom;

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

                name_error: *xcb_generic_error_t;
                name_old_error: *xcb_generic_error_t;

                // Some programs don't comply with EWMH and set old WM_NAME instead, try to get it as well
                name_cookie := xcb_get_property(con, 0, focused_window, net_name_atom, xx xcb_get_property_type_t.XCB_GET_PROPERTY_TYPE_ANY, 0, U32_MAX);
                name_old_cookie := xcb_get_property(con, 0, focused_window, xx xcb_atom_enum_t.WM_NAME, xx xcb_atom_enum_t.STRING, 0, U32_MAX);

                name_reply := xcb_get_property_reply(con, name_cookie, *name_error);
                name_old_reply := xcb_get_property_reply(con, name_old_cookie, *name_old_error);

                name: string;

                // On Sway, I get no reply when the X11 window loses focus and it switches
                // to a Wayland-native application. So I let it be...
                if !name_reply && !name_old_reply {
                    // Maybe socd unhook logic here
                    xcb_ungrab_server(con);
                    xcb_flush(con);
                    continue;
                }

                name_len := xcb_get_property_value_length(name_reply);
                name_old_len := xcb_get_property_value_length(name_old_reply);
                if !name_len {
                    name.count = name_old_len;
                    name.data = xcb_get_property_value(name_old_reply);
                } else {
                    name.count = name_len;
                    name.data = xcb_get_property_value(name_reply);
                }

                log("Name: %\n", name);
                xcb_ungrab_server(con);
                xcb_flush(con);
                c_free(name_reply);
                c_free(name_old_reply);
                // TODO: Better way to handle the title name, contains is probably not very
                // robust
                for ALLOWED_PROGRAMS {
                    if contains(it, name) {
                        set_kb_hook();
                    } else {
                        unset_kb_hook();
                    }
                }
            }
        }
    }
    c_free(name_reply);
    c_free(active_reply);
    return;
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
test_key :: (key: u32) -> u32 #expand {
    return `key_bits[key/8] & (xx 1 << (key % 8));
}

File_Descriptors :: struct {
    counter: s32;
    array: [256]s32;
}

opened_file_descriptors_for_candidates: File_Descriptors;

close_descriptors :: (raw_descriptors: *void) -> *void #c_call {
    ctx: Context;
    push_context ctx {
        descriptors := cast(*File_Descriptors)raw_descriptors;
        for descriptors.array {
            log("Closing file descriptor %\n", it);
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

keyboard_detector :: (file_info: *File_Visit_Info, device_candidates: *[..]Device) {
    device_fd := open(file_info.full_name.data, O_RDONLY);
    if device_fd < 0 {
        log_error("Couldn't open device % for checking out whether it's a keyboard\n", file_info.full_name);
        return;
    }

    opened_file_descriptors_for_candidates.array[opened_file_descriptors_for_candidates.counter] = device_fd;
    opened_file_descriptors_for_candidates.counter += 1;

    name: [256]u8;
    device_name: string;
    evbit: u32;

    name_length := ioctl(device_fd, EVIOCGNAME(name.count), *name);
    if name_length < 0 {
        log_error("Couldn't get device name: %\n", file_info.full_name);
    } else {
        device_name = alloc_string(name_length - 1);
        copy(device_name.data, name.data, device_name.count);
    }

    evbit_result := ioctl(device_fd, EVIOCGBIT(0, size_of(type_of(evbit))), *evbit);

    if !(evbit & (1 << EV_KEY)) {
        return;
    }

    // Every key code is encoded as a single positional bit in the key_bits returned by EVIOCGBIT,
    // This is why we need KEY_MAX amount of bits, or (KEY_MAX / 8) + 1 amount of bytes.
    // At least on desktop Linux this is 96.
    key_bits_num :: (KEY_MAX / 8) + 1;
    key_bits: [key_bits_num]u8;
    keys_ioctl_result := ioctl(device_fd, EVIOCGBIT(EV_KEY, key_bits.count), *key_bits);
    if keys_ioctl_result != key_bits_num {
        log_error("Something is wrong with reading key bits from device %, ioctl result is %, skipping it...\n", device_name, keys_ioctl_result);
        return;
    }

    if !(test_key(KEY_W) && test_key(KEY_A) && test_key(KEY_S) && test_key(KEY_D)) {
        return;
    }

    candidate := array_add(device_candidates);
    candidate.event_file = file_info.full_name;
    candidate.file_descriptor = device_fd;
    candidate.name = device_name;
}

get_loggable_device :: () -> *Device {
    candidates: [..]Device;
    device := New(Device);

    result := visit_files("/dev/input", recursive=false, user_data=*candidates, proc=keyboard_detector, visit_symlinks=false, follow_directory_symlinks=false,, temp);

    if !result {
        log_error("Couldn't collect info about keyboard devices!\n");
    }

    fds: [..]pollfd;
    array_reserve(*fds, candidates.count);

    for candidates {
        poll_event := array_add(*fds);
        poll_event.fd = it.file_descriptor;
        poll_event.events = POLLIN | POLLPRI;
        log("%\n", it);
    }

    poll_result := poll(fds.data, cast(u64)fds.count, -1);
    if poll_result <= 0 {
        log_error("Can't detect a keyboard: % (ERROR REASON HERE)\n", errno());
    }

    for fds {
        if (it.revents & POLLIN) {
            device.event_file = copy_string(candidates[it_index].event_file);
            device.name = copy_string(candidates[it_index].name);
            break;
        }
    }

    free_candidates(*candidates);
    reset_temporary_storage();
    log("Final device: %\n", device.*);

    return device;
}

// Fork of file_list that only returns directories under a path
dir_list :: (path: string, recursive := false, follow_directory_symlinks := true) -> [] string #must {
    files : [..] string;

    visitor :: (info: *File_Visit_Info, user_data: *[..] string) {
        array_add(user_data, copy_string(info.full_name));
    }

    visit_files(path, recursive, *files, visitor, follow_directory_symlinks=follow_directory_symlinks, visit_files=false, visit_directories=true);

    return files;
}

get_virtual_keyboard_path :: (info: *File_Visit_Info, user_data: $T) {
    if !info.is_directory {
        return;
    }

    uevent_path : = tprint("%/uevent", info.full_name);
    udevice_info, success := patched_read_entire_file(uevent_path);
    if !success {
        log_error("Couldn't read device uevent info: %\n", uevent_path);
        return;
    }

    has_our_product_string := begins_with(udevice_info, "PRODUCT=3/6666/6665");
    if !has_our_product_string {
        return;
    }

    dirs := dir_list(info.full_name);
    for dirs {
        if contains(it, "/event") {
            path_chunks := split(it, "/");
            event_name := path_chunks[path_chunks.count-1];
            log("Found event: %\n", event_name);

            return;
        }
    }
}

start_logging_keys_in_a_thread :: (arg: *void) -> *void #c_call {
    key_bits_num :: (KEY_MAX / 8) + 1;
    key_bits: [key_bits_num]u8;
    output_events: [2]input_event;

    ctx: Context;
    push_context ctx {
        device := get_loggable_device();

        device_fd := open(device.event_file.data, O_RDONLY);

        defer close(device_fd);
        if device_fd < 0 {
            log_error("Could not open % for reading its inputs\n", device.event_file);
        }
        device.file_descriptor = device_fd;

        key_bit_result := ioctl(device_fd, EVIOCGKEY(key_bits.count), *key_bits);
        if key_bit_result < key_bits_num {
            log_error("Can't read % key state\n", device.event_file);
            return null;
        }

        ev: input_event;
        // Wait for all button on the original keyboard to get unpressed before grabbing it.
        // The reason is - something else might be listening for inputs on the original keyboard
        // and it'll get stuck if we suddenly grab it. For example, touchpad prevents the cursor from moving
        // when you touch it while typing. If I grab the keyboard while it thinks that some key is pressed -
        // it goes into the infinite stuck loop until I ungrab the keyboard. Hence, this loop.
        // Maybe there's a better way to do it, idk...
        while true {
            size := read(device_fd, *ev, size_of(input_event));
            if ev.type != EV_KEY {
                continue;
            }

            key_bit_result = ioctl(device_fd, EVIOCGKEY(key_bits.count), *key_bits);
            if key_bit_result < key_bits_num {
                log_error("Can't read % key state\n", device.event_file);
                // Not sure if this is a continue or a return
                continue;
            }

            for KEY_ESC..cast(u16)KEY_MAX {
                if test_key(it) {
                    continue;
                }
            }
            break;
        }

        grab_result := ioctl(device_fd, EVIOCGRAB, 1);
        if grab_result < 0 {
            log_error("Could not grab % for controlling its inputs\n", device.event_file);
        }
        defer ioctl(device_fd, EVIOCGRAB, 0);

        uinput_fd := open("/dev/uinput", O_RDWR | O_NONBLOCK);

        if uinput_fd < 0 {

            System :: #import "System";

            code, s := System.get_error_value_and_string();
            log_error("Could not open \"/dev/uinput\" for creating a virtual keyboard, error: %\n", s);
            if code == EACCES log_error("Reopen the program with root privileges, or configure required udev rules\n");
            return null;
        }
        defer close(uinput_fd);

        keys_ioctl_result := ioctl(device_fd, EVIOCGBIT(EV_KEY, key_bits.count), *key_bits);
        if keys_ioctl_result != key_bits_num {
            log_error("Something is wrong with reading key bits from %, ioctl result is %, skipping it...\n", device.event_file, keys_ioctl_result);
            return null;
        }

        // TODO: Error handling
        ioctl(uinput_fd, UI_SET_EVBIT, EV_KEY);

        // Inclusive intentionally
        for KEY_ESC..cast(u32)KEY_MAX {
            if test_key(it) {
                ioctl(uinput_fd, UI_SET_KEYBIT, it);
            }
        }

        usetup: uinput_setup;
        usetup.id.bustype = BUS_USB;
        usetup.id.vendor = 0x6666;
        usetup.id.product = 0x6665;
        usetup.name = xx "SOCD keyboard".data;

        // NOTE: Documentation examples have UI_DEV_DESTROY call at the end of the program.
        // But Linux automatically cleans up a virtual keyboard when I close the program.
        // At least on my maching (tm). Maybe I should still call it?
        ioctl(uinput_fd, UI_DEV_SETUP, *usetup);
        ioctl(uinput_fd, UI_DEV_CREATE);

        sym_buffer: [256]u8;
        utf8_buffer: [256]u8;
        stop := false;
        while !stop {
            size := read(device_fd, *ev, size_of(input_event));

            if (size < size_of(input_event)) {
                log_error("Reading event from % failed\n", device.event_file);
                continue;
            }


            // Pass the real event into our virtual device.
            written := write(uinput_fd, *ev, size_of(input_event));
            if written < 0 {
                log_error("Could not pass the event on\n");
            }

            xkb_keycode: xkb_keycode_t = XKB_EVDEV_OFFSET + xx ev.code;
            keysym := xkb_state_key_get_one_sym(global_xkb_state, xkb_keycode);

            if ev.type == EV_KEY && ev.value == IS_DOWN {
                xkb_keysym_get_name(keysym, sym_buffer.data, sym_buffer.count);
                xkb_state_key_get_utf8(global_xkb_state, xkb_keycode, utf8_buffer.data, utf8_buffer.count);
                //log("Pressed: % - %\n", to_string(sym_buffer.data), to_string(utf8_buffer.data));
            }

            if current_mapping_state == .SETTING_SOURCE {
                if ev.value == IS_DOWN && ev.type == EV_KEY {
                    mapping_sources[0] = ev.code;
                    current_mapping_state = .SETTING_DESTINATION;
                }
                continue;
            } else if current_mapping_state == .SETTING_DESTINATION {
                if ev.value == IS_DOWN && ev.type == EV_KEY {
                    mapping_destinations[0] = ev.code;
                    current_mapping_state = .NOTHING;
                }
                continue;
            }

            if !KB_HOOK_SET {
                continue;
            }

            mapping := get_key_mapping(ev.code);

            if mapping {
                mapping_name := get_key_name(mapping);
                log("Found mapping: %\n", mapping_name);
                output_events[0] = input_event.{
                    type=EV_KEY,
                    code=cast(u16)mapping,
                    value=ev.value,
                };
                output_events[1] = input_event.{
                    type=EV_SYN,
                    code=SYN_REPORT,
                    value=0,
                };

                written := write(uinput_fd, output_events.data, size_of(input_event) * output_events.count);
                if written < 0 {
                    log_error("Could not write one to one mapping for %\n", mapping_name);
                }
                continue;
            }

            opposing_key, direction, opposing_direction := find_opposing_key_and_directions(ev.code);
            if !opposing_key {
                continue;
            }

            key_bit_result := ioctl(device_fd, EVIOCGKEY(key_bits.count), *key_bits);
            if key_bit_result < key_bits_num {
                log_error("Can't read % key state\n", device.event_file);
                continue;
            }
            if ev.value == 1 {
                if test_key(opposing_key) {
                    output_events[0] = input_event.{
                        type=EV_KEY,
                        code=cast(u16)opposing_key,
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
                if test_key(opposing_key) {
                    output_events[0] = input_event.{
                        time=.{},
                        type=EV_KEY,
                        code=cast(u16)opposing_key,
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
    return null;
}

start_logging_keys :: () {
    tid: pthread_t;
    pthread_create(*tid, null, start_logging_keys_in_a_thread, null);
}

start_detecting_focused_program_in_a_thread :: (arg: *void) -> *void #c_call {
    ctx: Context;
    push_context ctx {
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
    if key_scan_code == KEY_TEMP return "...";
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
        case KEY_PAGEUP;
            KEY_NAMES[KEY_PAGEUP] = "PgUp";
            return "PgUp";
        case KEY_PAGEDOWN;
            KEY_NAMES[KEY_PAGEDOWN] = "PgDown";
            return "PgDown";
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

    array_add(*x_global_windows, win);

    XUnlockDisplay(d);
    return win;
}


platform_init :: () -> success: bool #must {

    // init xcb X11 connection and libxkbcommon
    global_xcb_connection = xcb_connect(null, null);
    con_errors := xcb_connection_has_error(global_xcb_connection);

    if con_errors {
        log_error("Can't connect to X11 with xcb, error cocde is: %\n", con_errors);
        return false;
    }

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

    global_xkb_context = xkb_context_new(0);

    core_kbd_device_id := xkb_x11_get_core_keyboard_device_id(global_xcb_connection);
    if (core_kbd_device_id == -1) {
        log_error("Couldn't find core keyboard device\n");
        return false;
    } else {
        log("Core keyboard device is %\n", core_kbd_device_id);
    }

    global_xkb_keymap = xkb_x11_keymap_new_from_device(global_xkb_context, global_xcb_connection, core_kbd_device_id, 0);

    global_xkb_state = xkb_state_new(global_xkb_keymap);
    if (!global_xkb_state) {
        log_error("Couldn't create xkb state for device\n");
        return false;
    }

    return true;

}

libc :: #system_library "libc";
c_free :: (memory: *void) #foreign libc "free";

#import "Memory";
#import "File";
#import "File_Utilities";
#import "POSIX";
#import "Sort";
#import "X11";
// To expose module-scoped WC.DEFAULT_WINDOW_CREATION_COLOR and WC.DEFAULT_MSAA
WC :: #import "Window_Creation";
