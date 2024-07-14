#load "./xcb.jai";
// This might backfire, because this is configurable on Linux
// Might want to allocate it at runtime instead
MAX_PATH_LENGTH :: 4096;

get_dpi_scale :: (window: Window_Type) -> float {
    // @TODO: Implement
    return 1;
}

start_detecting_focused_programs :: () {
    con := xcb_connect(null, null);
    con_errors := xcb_connection_has_error(con);

    if con_errors {
        print("Can't connect to X11 with xcb, error cocde is: %\n", con_errors);
        return;
    }

    net_active_atom: xcb_atom_t;
    atom_name := "_NET_ACTIVE_WINDOW";
    atom_cookie := xcb_intern_atom(con, cast(u8)false, cast(u8)atom_name.count, atom_name.data);

    atom_error: *xcb_generic_error_t;
    atom_reply := xcb_intern_atom_reply(con, atom_cookie, *atom_error);

    if !atom_reply {
        print("Can't get _NET_ACTIVE_WINDOW atom, error is: %\n", atom_error.*);
        return;
    }

    net_active_atom = atom_reply.atom;

    print("Atom: %\n", net_active_atom);

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
            print("Event is %\n", notify_event.*);
            // if notify_event.atom == net_active_atom && notify_event.state == 0 {
            //     print("Event is %\n", notify_event.*);
            // }
        }
    }
    return;
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

#import "X11";
// For some reason defaults in create_window fail with unknown identifier without import Window_Creation like this.
// Maybe a compiler bug? Need to ask about it
WC :: #import "Window_Creation";
