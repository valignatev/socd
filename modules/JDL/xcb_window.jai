xcb :: #import,file "./xcb.jai";
xkb :: #import,file "./xkbcommon.jai";

Saved_Window_Info :: struct {

}


XCB_Display :: struct {
    #as using base: Base_Display;

    handle: *xcb.xcb_connection_t;
    screen: *xcb.xcb_screen_t;

    // atom_names: Table(xcb_atom_t, string);
    atoms: struct {
        INCR: xcb.xcb_atom_t;
        CLIPBOARD: xcb.xcb_atom_t;
        _NET_WM_ICON: xcb.xcb_atom_t;
        _NET_WM_STATE: xcb.xcb_atom_t;
        _NET_WM_STATE_MAXIMIZED_VERT: xcb.xcb_atom_t;
        _NET_WM_STATE_MAXIMIZED_HORZ: xcb.xcb_atom_t;
        _NET_WM_STATE_FULLSCREEN: xcb.xcb_atom_t;
        _NET_WM_NAME: xcb.xcb_atom_t;
        _NET_WM_ICON_NAME: xcb.xcb_atom_t;
        WM_PROTOCOLS: xcb.xcb_atom_t;
        WM_DELETE_WINDOW: xcb.xcb_atom_t;
    }

    base_xkb_event: u8;
    xkb_context: *xkb.xkb_context;
    xkb_keymap: *xkb.xkb_keymap;
    xkb_state: *xkb.xkb_state;

}


XCB_Window :: struct {
    #as using base: Base_Window;

    handle: xcb.xcb_window_t;
}


toggle_fullscreen :: (win: Window, desire_fullscreen: bool, saved: *Saved_Window_Info) -> success: bool, width: s32, height: s32 {
    return true, 0, 0;
}


xcb_init_display :: (display: *Display) -> bool {
    d := XCB_Display.{ base = display };
    d.base.type = XCB_Display;
    d.base.create_window = xcb_create_window;
    d.base.get_dimensions = xcb_get_dimensions;
    d.base.wait_for_events = xcb_wait_for_events;
    
    d.handle = xcb.xcb_connect(null, null);
    con_errors := xcb.xcb_connection_has_error(d.handle);

    if con_errors {
        // TODO: Figure out correct strategy for error handling;
        log_error("Can't connect to X11 with xcb, error code is: %\n", con_errors);
        return false;
    }

    // Intern Atoms
    tis := cast(*Type_Info_Struct) type_of(d.atoms);
    atom_infos: [..] struct {
        cookie: xcb.xcb_intern_atom_cookie_t;
        atom: *xcb.xcb_atom_t;
        name: string;
    };
    array_reserve(*atom_infos, tis.members.count);
    for atom: tis.members {
        array_add(*atom_infos, .{
            cookie = xcb.xcb_intern_atom(d.handle, xx false, xx atom.name.count, atom.name.data),
            atom = cast(*xcb.xcb_atom_t)(cast(*u8) *d.atoms + atom.offset_in_bytes),
            name = atom.name,
        });
    }

    for info: atom_infos {
        error: *xcb.xcb_generic_error_t;
        reply := xcb.xcb_intern_atom_reply(d.handle, info.cookie, *error);
        if !reply {
            log_error("Failed to intern X11 atom: %", error.*);
            continue;
        }

        info.atom.* = reply.atom;
        c_free(reply);
    }

    // and libxkbcommon
    major: u16 = 1;
    minor: u16 = 0;
    ret := xkb.xkb_x11_setup_xkb_extension(
        d.handle,
        major,
        minor,
        0,
        *major, *minor, *d.base_xkb_event, null,
    );

    if (!ret) {
        log_error("Couldn't setup XKB extension\n");
        return false; 
    }

    d.xkb_context = xkb.xkb_context_new(.NO_FLAGS);

    core_kbd_device_id := xkb.xkb_x11_get_core_keyboard_device_id(d.handle);
    if (core_kbd_device_id == -1) {
        log_error("Couldn't find core keyboard device\n");
        return false;
    } else {
        log("Core keyboard device is %\n", core_kbd_device_id);
    }

    d.xkb_keymap = xkb.xkb_x11_keymap_new_from_device(d.xkb_context, d.handle, core_kbd_device_id, 0);

    d.xkb_state = xkb.xkb_x11_state_new_from_device(d.xkb_keymap, d.handle, core_kbd_device_id);
    if (!d.xkb_state) {
        log_error("Couldn't create xkb state for device\n");
        return false;
    }

    display.xcb = d;
    return true;
}


xcb_create_window :: (display: *Display, window_ret: *Window, width: s32, height: s32, window_name: string, window_x := 0, window_y := 0, parent: *Window = INVALID_WINDOW, background_color_rgb := DEFAULT_WINDOW_CREATION_COLOR) -> bool {
    // assert display.xcb;
    xd := *display.xcb;
    window_ret.base.type = XCB_Window;
    window_ret.base.display = display;
    screen := xcb.xcb_setup_roots_iterator(xcb.xcb_get_setup(xd.handle)).data;
    xcb_file_descriptor := xcb.xcb_get_file_descriptor(xd.handle);

    event_mask := xcb.xcb_event_mask_t.EXPOSURE | .STRUCTURE_NOTIFY | .FOCUS_CHANGE | .ENTER_WINDOW | .LEAVE_WINDOW | .KEY_PRESS | .KEY_RELEASE | .BUTTON_PRESS | .BUTTON_RELEASE | .POINTER_MOTION;
    window := xcb.xcb_generate_id(xd.handle);
    prop_mask := xcb.xcb_cw_t.BACK_PIXEL | .EVENT_MASK;
    prop_list := u32.[screen.black_pixel, xx event_mask];

    xcb.xcb_create_window_checked(
        c=xd.handle,
        depth=xcb.XCB_COPY_FROM_PARENT,
        wid=window,
        parent=screen.root,
        x=xx window_x, y=xx window_y, width=xx width, height=xx height, border_width=1,
        _class=.XCB_WINDOW_CLASS_INPUT_OUTPUT,
        visual=screen.root_visual,
        value_mask=prop_mask,
        value_list=prop_list.data,
    );

    xcb.xcb_change_property(
        xd.handle,
        .REPLACE,
        window,
        xd.atoms.WM_PROTOCOLS,
        xx xcb.xcb_atom_enum_t.ATOM, 
        32, 1, *xd.atoms.WM_DELETE_WINDOW,
    );

    class_sz := tprint("%\0%\0", ifx window_name then window_name else "jai-application", "hitboxer");
    xcb.xcb_change_property(
        xd.handle,
        .REPLACE,
        window,
        xx xcb.xcb_atom_enum_t.WM_CLASS,
        xx xcb.xcb_atom_enum_t.STRING, 
        8, xx class_sz.count, class_sz.data,
    );

    xcb.xcb_map_window(xd.handle, window);
    xcb.xcb_flush(xd.handle);

    // OpenGL

    window_ret.handle = window;
    return true;;
}

xcb_get_dimensions :: (window: *Window, right_handed: bool) -> (x: s32, y: s32, width: s32, height: s32, success := true) {
    // xcb.xcb_check_usage(null, window);
    xw : *XCB_Window = window;
    cookie := xcb.xcb_get_geometry(xw.display.handle, xw.handle);
    geometry := xcb.xcb_get_geometry_reply(xw.display.handle, cookie, null);
    return 0, 0, xx geometry.width, geometry.height, true;
}


xcb_wait_for_events :: (display: *Display) {
}


#scope_file


libc :: #system_library "libc";
c_free :: (memory: *void) #foreign libc "free";
