// This might backfire, because this is configurable on Linux
// Might want to allocate it at runtime instead
MAX_PATH_LENGTH :: 4096;

get_dpi_scale :: (window: Window_Type) -> float {
    return 1;
}

start_detecting_focused_programs :: () {
    return;
}

unset_mapping_setting_hook :: () {
    return;
}


set_key_mapping_hook :: (window: Window_Type) {
    return;
}

get_key_name :: (key_scan_code: u32) -> string {
    return "NOT IMPLEMENTED";
}

create_window :: () -> Window_Type {
    the_window := create_window(window_width, window_height, "Hitboxer");
    return the_window;
}

#import "X11";
