#load "./xcb.jai";
#load "./input.jai";
// This might backfire, because this is configurable on Linux
// Might want to allocate it at runtime instead
MAX_PATH_LENGTH :: 4096;

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

kb_scores: [..]string;

// This is basically test_bit from linux kernel: 
// https://github.com/torvalds/linux/blob/master/tools/testing/selftests/iommu/iommufd_utils.h#L34
test_key :: (key: u32) -> u32 #expand {
    return `key_bits[key/8] & (1 << (key % 8));
}

keyboard_detector :: (file_info: *File_Visit_Info, user_data: [..]string) {
    // print("%\n", file_info.*);

    device_fd := open(file_info.full_name.data, O_RDONLY);
    if device_fd < 0 {
        print("Couldn't open device % for checking out whether it's a keyboard\n", file_info.full_name);
        return;
    }

    name: [256]u8;
    evbit: u32;
    evbit_result := ioctl(device_fd, EVIOCGBIT(0, size_of(type_of(evbit))), *evbit);

    // print("evbit: %\n, evbit_result: %\n", evbit, evbit_result);
    if evbit & (1 << EV_KEY) {
        // Should be 96
        key_bits_num :: (KEY_MAX / 8) + 1;
        key_bits: [key_bits_num]u8;
        keys_ioctl_result := ioctl(device_fd, EVIOCGBIT(EV_KEY, key_bits.count), *key_bits);
        if keys_ioctl_result != key_bits_num {
            print("Something is wrong with reading key bits from device %, ioctl result is %, skipping it...\n", cast(string)name, keys_ioctl_result);
            return;
        }
        is_keyboard := true;
        if test_key(KEY_W) && test_key(KEY_A) && test_key(KEY_S) && test_key(KEY_D) {
            name_ioctl_result := ioctl(device_fd, EVIOCGNAME(name.count), *name);
            if name_ioctl_result < 0 {
                print("Couldn't get keyboard name: %, but we can still use it!\n", name_ioctl_result);
            } else {
                print("% - %\n", cast(string)name, file_info.full_name);
            }
        } else {
            is_keyboard = false;
        }
    }
}

log_keys :: () {
    result := visit_files("/dev/input", recursive=false, user_data=kb_scores, proc=keyboard_detector, visit_symlinks=false, follow_directory_symlinks=false,, temp);

    if !result {
        print("Couldn't collect info about keyboard devices!\n");
    }
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

#import "File_Utilities";
#import "X11";
#import "POSIX";
// For some reason defaults in create_window fail with unknown identifier without import Window_Creation like this.
// Maybe a compiler bug? Need to ask about it
WC :: #import "Window_Creation";