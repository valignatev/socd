#load "./xcb.jai";
// This might backfire, because this is configurable on Linux
// Might want to allocate it at runtime instead
MAX_PATH_LENGTH :: 4096;

get_dpi_scale :: (window: Window_Type) -> float {
    // @TODO: Implement
    return 1;
}

start_detecting_focused_programs :: () {
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
    active := "_NET_ACTIVE_WINDOW";
    name := "_NET_WM_NAME";
    active_cookie := xcb_intern_atom(con, cast(u8)false, cast(u8)active.count, active.data);
    name_cookie := xcb_intern_atom(con, cast(u8)false, cast(u8)name.count, name.data);

    active_error: *xcb_generic_error_t;
    name_error: *xcb_generic_error_t;
    // @TODO: FREE THE REPLY
    active_reply := xcb_intern_atom_reply(con, active_cookie, *active_error);
    name_reply := xcb_intern_atom_reply(con, name_cookie, *name_error);

    if !active_reply {
        print("Can't get _NET_ACTIVE_WINDOW atom, error is: %\n", active_error.*);
        return;
    }

    if !name_reply {
        print("Can't get _NET_ACTIVE_WINDOW atom, error is: %\n", name_error.*);
        return;
    }

    net_active_atom = active_reply.atom;
    net_name_atom = name_reply.atom;

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
            if notify_event.atom == net_active_atom && notify_event.state == 0 {
                // On Sway, I get two focus events for the same window when switching from
                // another X11 window. But I get only one focus event when I switch from
                // Wayland window to X11 window. Weird, on pure X11 this doesn't happen.
                // print("Event is %\n", notify_event.*);

                xcb_grab_server(con);
                input_focus_reply := xcb_get_input_focus_reply(con, xcb_get_input_focus(con), null);
                focused_window := input_focus_reply.focus;

                name_error: *xcb_generic_error_t;
                name_cookie := xcb_get_property(con, 0, focused_window, net_name_atom, xx xcb_get_property_type_t.XCB_GET_PROPERTY_TYPE_ANY, 0, ~(cast(u32)0));
                name_reply := xcb_get_property_reply(con, name_cookie, *name_error);
                name: string;
                // print("Name Reply: %\n", name_reply.*);

                // On Sway, I get no reply when the X11 window loses focus and it switches
                // to a Wayland-native application. So I let it be...
                if !name_reply {
                    // Maybe socd unhook logic here
                    xcb_ungrab_server(con);
                    xcb_flush(con);
                    continue;
                }
                name.count = xcb_get_property_value_length(name_reply);
                name.data = xcb_get_property_value(name_reply);

                print("Name: %\n", name);
                xcb_ungrab_server(con);
                xcb_flush(con);
            }
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
