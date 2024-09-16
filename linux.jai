#load "./xcb.jai";
#load "./input.jai";
// This might backfire, because this is configurable on Linux
// Might want to allocate it at runtime instead
MAX_PATH_LENGTH :: 4096;

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
    con := xcb_connect(null, null);
    con_errors := xcb_connection_has_error(con);

    if con_errors {
        print("Can't connect to X11 with xcb, error cocde is: %\n", con_errors);
        return;
    }

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
        print("Can't get _NET_ACTIVE_WINDOW atom, error is: %\n", active_error.*);
        return;
    }

    if !name_reply {
        print("Can't get _NET_WM_NAME atom, error is: %\n", name_error.*);
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
        print("Failed to listen to window focus events, error is %\n", change_error.*);
    }

    xcb_flush(con);

    while true {
        event := xcb_wait_for_event(con);
        if !event {
            print("I/O error while getting a window focused event");
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
                // print("Event is %\n", notify_event.*);

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

                print("Name: %\n", name);
                xcb_ungrab_server(con);
                xcb_flush(con);
                c_free(name_reply);
                c_free(name_old_reply);
                // if name == "Hollow Knight" {
                //     set_kb_hook();
                // } else {
                //     unset_kb_hook();
                // }
            }
        }
    }
    c_free(name_reply);
    c_free(active_reply);
    return;
}

set_kb_hook :: () {
    return;
}

unset_kb_hook :: () {
    return;
}

Device :: struct {
    event_file: string;
    name: string;
    file_descriptor: s32;
}

Device_Candidate :: struct {
    using #as device: Device;
    // How likely it is an actual keyboard. The more - the better.
    score: s8;
}

// This is basically test_bit from linux kernel: 
// https://github.com/torvalds/linux/blob/master/tools/testing/selftests/iommu/iommufd_utils.h#L34
test_key :: (key: u32) -> u32 #expand {
    return `key_bits[key/8] & (1 << (key % 8));
}

opened_file_descriptors_for_candidates: [256]s32;

close_descriptors :: (raw_descriptors: *void) -> *void #c_call {
    ctx: Context;
    push_context ctx {
        descriptors := cast([256]s32)raw_descriptors;
        for descriptors {
            if !it break;
            error := close(it);
            if error {
                System :: #import "System";

                code, s := System.get_error_value_and_string();
                print("Closing file descriptor '%' failed: code %, '%'.\n", it, code, s);
            } else {
                descriptors[it_index] = 0;
            }
        }
    }
    return null;
}

free_candidates :: (candidate_arrays: ..*[..]Device_Candidate) {
    for candidates: candidate_arrays {
        for candidates.* {
            if it.name.count free(it.name); 
        }
        array_free(candidates.*);
    }
    tid: pthread_t ;
    pthread_create(*tid, null, close_descriptors, *opened_file_descriptors_for_candidates);
}

keyboard_detector :: (file_info: *File_Visit_Info, device_candidates: *[..]Device_Candidate) {
    // print("%\n", file_info.*);

    device_fd := open(file_info.full_name.data, O_RDONLY);
    if device_fd < 0 {
        print("Couldn't open device % for checking out whether it's a keyboard\n", file_info.full_name);
        return;
    }

    candidate := array_add(device_candidates);
    candidate.event_file = file_info.full_name;
    candidate.file_descriptor = device_fd;

    name: [256]u8;
    evbit: u32;

    name_length := ioctl(device_fd, EVIOCGNAME(name.count), *name);
    if name_length < 0 {
        print("Couldn't get device name: %\n", candidate.event_file);
    } else {
        candidate.name = alloc_string(name_length - 1);
        copy(candidate.name.data, name.data, candidate.name.count);
    }

    evbit_result := ioctl(device_fd, EVIOCGBIT(0, size_of(type_of(evbit))), *evbit);

    // print("evbit: %\n, evbit_result: %\n", evbit, evbit_result);
    if !(evbit & (1 << EV_KEY)) {
        return;
    }

    candidate.score += 1;

    // Every key code is encoded as a single positional bit in the key_bits returned by EVIOCGBIT,
    // This is why we need KEY_MAX amount of bits, or (KEY_MAX / 8) + 1 amount of bytes.
    // At least on desktop Linux this is 96.
    key_bits_num :: (KEY_MAX / 8) + 1;
    key_bits: [key_bits_num]u8;
    keys_ioctl_result := ioctl(device_fd, EVIOCGBIT(EV_KEY, key_bits.count), *key_bits);
    if keys_ioctl_result != key_bits_num {
        print("Something is wrong with reading key bits from device %, ioctl result is %, skipping it...\n", cast(string)name, keys_ioctl_result);
        return;
    }

    if !(test_key(KEY_W) && test_key(KEY_A) && test_key(KEY_S) && test_key(KEY_D)) {
        return;
    }

    candidate.score += 10;

    device_stat: stat_t;
    stat_result := stat(file_info.full_name.data, *device_stat);
    if stat_result < 0 {
        print("Couldn't stat the device %\n", file_info.full_name);
    }
    dev_major := major(device_stat.st_rdev);
    dev_minor := minor(device_stat.st_rdev);
    dev_mode: string; 
    if device_stat.st_mode & S_IFMT == {
        case S_IFBLK;
            dev_mode = "block";
        case S_IFCHR;
            dev_mode = "char";
        case;
            dev_mode = "unexpected_device_type";
    };
    syspath := tprint("/sys/dev/%/%:%/device/", dev_mode, dev_major, dev_minor);
    absolute_path, success := get_absolute_path(syspath);
    if !success {
        print("Couldn't resolve absolute path to the device\n");
        return;
    }
    // print("syspath: %\n", syspath);

    protocol_string := tprint("%", "bInterfaceProtocol");
    sub_class_string := tprint("%", "bInterfaceSubClass");

    path := parse_path(absolute_path);
    // print("absolute_path: %\n", path);

    found := false;
    while !found {

        // Bail if we went all the way back to /sys/devices/pciXXXX:XX/XXXX:XX:XX.X/usbX/ and
        // haven't found the descriptors yet.
        if path.words.count <= 5 {
            break;
        }
        path.words[path.words.count - 1] = protocol_string;

        fully_exists, how_much := how_much_of_path_exists_on_the_local_filesystem(path);
        
        if fully_exists {
            found = true;
            break;
        }

        path.words.count -= 1;
    }

    if !found {
        // print("Coulnd't find interface protocol and interface subclass for the device %\n", candidate.event_file);
        return;
    }

    protocol_path := path_to_string(path,, temp);

    path.words[path.words.count - 1] = sub_class_string;
    sub_class_path := path_to_string(path,, temp);
    // print("%\n", protocol_path);
    // print("%\n", sub_class_path);

    protocol  := trim_right(patched_read_entire_file(protocol_path,, temp));
    sub_class := trim_right(patched_read_entire_file(sub_class_path,, temp));
    // print("bInterfaceProtocol: %\n", protocol);
    // print("bInterfaceSubClass: %\n", sub_class);

    // According to USB spec, it is a proper keyboard with both of those equal 1
    if protocol == "01" && sub_class == "01" {
        candidate.score += 100;
    }
}

log_keys :: () {
    candidates: [..]Device_Candidate;
    devices_high_confidence: [..]Device_Candidate;
    devices_meh_confidence:  [..]Device_Candidate;

    device: Device;

    result := visit_files("/dev/input", recursive=false, user_data=*candidates, proc=keyboard_detector, visit_symlinks=false, follow_directory_symlinks=false);

    reset_temporary_storage();
    if !result {
        print("Couldn't collect info about keyboard devices!\n");
    }

    for candidates {
        // If someone has over 256 device candidates - oh well, we're gonna leak those descriptors until the
        // program finishes.
        if it_index < opened_file_descriptors_for_candidates.count {
            opened_file_descriptors_for_candidates[it_index] = it.file_descriptor;
        }
        if it.score > 100 {
            array_add(*devices_high_confidence, it);
            array_unordered_remove_by_index(*candidates, it_index);
        } else if it.score > 10 {
            array_add(*devices_meh_confidence, it);
            array_unordered_remove_by_index(*candidates, it_index);
        }
    }

    if devices_high_confidence.count == 1 {
        device = devices_high_confidence[0];
        free_candidates(*devices_meh_confidence, *candidates);
    } else if devices_high_confidence.count > 1 {
        print("Found multiple keyboards, but we don't support that yet, selecting the first of them!\n");
        device = devices_high_confidence[0];
        array_unordered_remove_by_index(*devices_high_confidence, 0);
        free_candidates(*devices_high_confidence, *devices_meh_confidence, *candidates);
    } else if devices_meh_confidence.count > 0 {
        print("Couldn't find any keyboards with high enough confidence, you have to select one manually\n");
        // @TODO: Implement selecting a device
        free_candidates(*devices_high_confidence, *devices_meh_confidence, *candidates);
    } else {
        print("Coulnd't find any keyboards on your computer, you have to select the device manually\n");
        // @TODO: Implement selecting a device
        free_candidates(*devices_high_confidence, *devices_meh_confidence, *candidates);
    }

    // We will reopen the device with read+write permissions to actually work with it.
    device.file_descriptor = 0;
    print("Final device: %\n", device);
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
    // @TODO: Implement
    return;
}

get_key_name :: (key_scan_code: u32) -> string {
    // @TODO: Implement
    return "NOT IMPLEMENTED";
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

libc :: #system_library "libc";
c_free :: (memory: *void) #foreign libc "free";

#import "Memory";
#import "File";
#import "File_Utilities";
#import "POSIX";
#import "Sort";
#import "X11";
// For some reason defaults in create_window fail with unknown identifier without import Window_Creation like this.
// Maybe a compiler bug? Need to ask about it
WC :: #import "Window_Creation";