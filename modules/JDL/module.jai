#module_parameters (DEFAULT_MSAA: s32 = 4);

#if OS == .WINDOWS {
    #load "windows.jai";
} else #if OS == .LINUX {
    #load "xcb_window.jai";
} else {
    #assert(false);
}

#scope_file
_main_display: Display;

#scope_module

#import "Basic";

DEFAULT_WINDOW_CREATION_COLOR :: float.[.15,.15,.2];

main_display :: *_main_display;

#scope_export

Display :: union {
    #as using xcb: XCB_Display;
}


Base_Display :: struct {
    type := Base_Display;

    windows: [..]*Window;
    create_window: #type (
        display: *Display,
        window_ret: *Window,
        width: s32, height: s32,
        window_name: string,
        window_x := 0, window_y := 0,
        parent: *Window = null,
        background_color_rgb: [3]float = DEFAULT_WINDOW_CREATION_COLOR) -> bool;

    wait_for_events: #type (display: *Display);

    get_dimensions: #type (
        window: *Window,
        right_handed: bool) -> x: s32, y: s32, width: s32, height: s32, success: bool;
}


Window :: union {
    #as using xcb: XCB_Window;
}

Base_Window :: struct {
    type := Window;
    display: *Display;
    window_minimized := false;
}


operator== :: (a_base: *Window, b_base: *Window) -> bool {
    if a_base.type == XCB_Window && b_base.type == XCB_Window {
        a := cast(*XCB_Window, a_base);
        b := cast(*XCB_Window, b_base);
        return a.handle == b.handle;
    }

    assert(false, "Not implemented for a: % and b:%", a_base.type, b_base.type);
    return false;
}


JDL_init :: () -> success: bool {
    success := xcb_init_display(main_display);

    // Error handling
    return success;
}


create_window :: (window_width: s32, window_height: s32, window_title: string) -> Window_Type {
    window := New(Window);
    success := main_display.create_window(
        main_display,
        window,
        window_width,
        window_height,
        window_title
    );

    if !success {
        // Error handling
    }

    array_add(*main_display.windows, window);

    return window;
}


get_dimensions :: inline (window: *Window, right_handed: bool) -> x: s32, y:s32, width: s32, height: s32, success := true {
    x, y, w, h, s := window.display.get_dimensions(window, right_handed);
    return x, y, w, h, s;
}


wait_for_events :: inline () {
    main_display.wait_for_events(main_display);
}


Window_Type :: *Window;
INVALID_WINDOW : Window_Type : null;

#import "Hash_Table";

