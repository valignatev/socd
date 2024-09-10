MAX_PATH_LENGTH :: MAX_PATH;
mapping_resolving_hook: HHOOK;
mapping_setting_hook: HHOOK;

scan_code_to_lparam :: (scan_code: u32) -> u32 {
    lparam := scan_code << 16;
    // TODO: Handle extended bit
    return lparam;
}

// Returns textual name of the key in UTF8
get_key_name :: (key_scan_code: u32) -> string {
    if key_scan_code == KEY_TEMP return "...";
    cached := KEY_NAMES[key_scan_code];
    if cached {
        return cached;
    }
    #if OS == .WINDOWS {
        lparam := scan_code_to_lparam(key_scan_code);
        length := GetKeyNameTextW(lparam, key_name_buffer.data, key_name_buffer.count);
        if length == 0 {
            error := GetLastError();
            log_error("Couldn't get the key name for the key with scancode %. Error is %\n", key_scan_code, error);
            return "KEY ERROR";
        }
        key_name, ok := wide_to_utf8_new(key_name_buffer.data, length);
        if !ok {
            error := GetLastError();
            log_error("Couldn't convert the key name to UTF8 for scancode %. Buffer content is %. Error is %\n", key_scan_code, key_name_buffer, error);
            return "KEY ERROR";
        }
        KEY_NAMES[key_scan_code] = key_name;
        return key_name;
    } else {
        return "NOT IMPLEMENTED";
    }
}

// TODO: Try to find a way to be more optimal (like bailing out earlier) on key repeats:
// https://learn.microsoft.com/en-us/windows/win32/winmsg/lowlevelkeyboardproc
low_level_keyboard_proc :: (n_code: s32, wparam: WPARAM, lparam: LPARAM) -> s64 #c_call {
    kb_input := cast(*KBDLLHOOKSTRUCT)lparam;

    // We ignore injected events so we don't mess with the inputs
    // we inject ourselves with SendInput.
    // TODO maybe it's better to set our own custom extended info and check it
    // instead of LLKHF_INJECTED so we know FOR SURE it's ours
    if n_code != HC_ACTION || kb_input.flags & LLKHF_INJECTED {
        return CallNextHookEx(null, n_code, wparam, lparam);
    }

    key_virtual_code := kb_input.vkCode;
    key_scan_code := kb_input.scanCode;
    ctx: Context;
    push_context ctx {
        key_name := get_key_name(key_scan_code);

        print("Key is % - %\n", key_scan_code, key_name);
        mapping := get_key_mapping(key_scan_code);
        if mapping {
            key_name := get_key_name(mapping);
            print("Found mapping: %\n", key_name);

            if wparam == WM_KEYDOWN || wparam == WM_SYSKEYDOWN {
                input: INPUT;
                input.type = .INPUT_KEYBOARD;
                input.ki = KEYBDINPUT.{0, cast(u16)mapping, KEYEVENTF_SCANCODE, 0, null};
                events_count := SendInput(1, *input, size_of(INPUT));
                if events_count == 0 {
                    error := GetLastError();
                    print("SendInput failed with error: %\n", error);
                }
                print("Sent % down events\n", events_count);
            } else if wparam == WM_KEYUP || wparam == WM_SYSKEYUP {
                print("Found up event\n");
                input: INPUT;
                input.type = .INPUT_KEYBOARD;
                input.ki = KEYBDINPUT.{0, cast(u16)mapping, KEYEVENTF_KEYUP | KEYEVENTF_SCANCODE, 0, null};
                events_count := SendInput(1, *input, size_of(INPUT));
                if events_count == 0 {
                    error := GetLastError();
                    print("SendInput failed with error: %\n", error);
                }
                print("Sent % up events\n", events_count);

            }
            return CallNextHookEx(null, n_code, wparam, lparam);
        }

        opposing_key, direction, opposing_direction := find_opposing_key_and_directions(key_scan_code);
        if !opposing_key {
            return CallNextHookEx(null, n_code, wparam, lparam);
        }

        if wparam == WM_KEYDOWN || wparam == WM_SYSKEYDOWN {
            kb_real_state[direction] = IS_DOWN;
            kb_virtual_state[direction] = IS_DOWN;
            if kb_real_state[opposing_direction] == IS_DOWN && kb_virtual_state[opposing_direction] == IS_DOWN {
                input: INPUT;
                input.type = .INPUT_KEYBOARD;
                input.ki = KEYBDINPUT.{0, cast(u16)opposing_key, KEYEVENTF_KEYUP | KEYEVENTF_SCANCODE, 0, null};
                events_count := SendInput(1, *input, size_of(INPUT));
                if events_count == 0 {
                    error := GetLastError();
                    print("SendInput failed with error: %\n", error);
                } else {
                    kb_virtual_state[opposing_direction] = IS_UP;
                }
                print("Sent % events\n", events_count);
            }
        } else if wparam == WM_KEYUP || wparam == WM_SYSKEYUP {
            kb_real_state[direction] = IS_UP;
            kb_virtual_state[direction] = IS_UP;
            if kb_real_state[opposing_direction] == IS_DOWN {
                input: INPUT;
                input.type = .INPUT_KEYBOARD;
                input.ki = KEYBDINPUT.{0, cast(u16)opposing_key, KEYEVENTF_SCANCODE, 0, null};
                events_count := SendInput(1, *input, size_of(INPUT));
                if events_count == 0 {
                    error := GetLastError();
                    print("SendInput failed with error: %\n", error);
                } else {
                    kb_virtual_state[opposing_direction] = IS_DOWN;
                }
            }
        }

        return CallNextHookEx(null, n_code, wparam, lparam);
    }
}

mapping_setting_hook_proc :: (n_code: s32, wparam: WPARAM, lparam: LPARAM) -> s64 #c_call {
    ctx: Context;
    push_context ctx {
        key_virtual_code := wparam;
        // How to interpret lparam: https://learn.microsoft.com/en-us/windows/win32/inputdev/about-keyboard-input
        hiword := (lparam >> 16) & 0xffff;
        // Scan code is bits 16-23, so byte 3, or the low byte of the hiword. It's a bit confusing...
        raw_scan_code := cast(u32)hiword & 0xff;
        key_scan_code : u32 = 0;

        // Extended bit is 24th. TODO: Use it, or we get confused with numlock is enabled vs when it's not\
        // Something like:
            // if (extended)  key_scan_code = MAKEWORD(key_scan_code, 0xE0);
        is_extended := cast(u32)(hiword & KF_EXTENDED) == KF_EXTENDED;

        if is_extended {
            print("We are extended\n");
            key_scan_code = (0xe0 << 8) | raw_scan_code;
        } else {
            key_scan_code = raw_scan_code;
        }

        // Transition state flag is bit 31
        is_down := hiword & KF_UP == 0;

        if is_down {
            length := GetKeyNameTextW(xx lparam, key_name_buffer.data, key_name_buffer.count);
        if length == 0 {
            error := GetLastError();
            log_error("Couldn't get the key name for the key with scancode %. Error is %\n", key_scan_code, error);
        }
        key_name, ok := wide_to_utf8_new(key_name_buffer.data, length);
        if !ok {
            error := GetLastError();
            log_error("Couldn't convert the key name to UTF8 for scancode %. Buffer content is %. Error is %\n", key_scan_code, key_name_buffer, error);
        }
            print("New mapping key pressed: %\n", key_name);
            if current_mapping_state == .SETTING_SOURCE {
                mapping_sources[0] = key_scan_code;
                current_mapping_state = .SETTING_DESTINATION;
            } else if current_mapping_state == .SETTING_DESTINATION {
                mapping_destinations[0] = key_scan_code;
                current_mapping_state = .NOTHING;
            }
        }
    }
    return CallNextHookEx(null, n_code, wparam, lparam);
}

detect_focused_program :: (
    win_event_hook_handle: *void,
    // TODO: This is enum of "event constants":
    // https://learn.microsoft.com/en-us/windows/win32/winauto/event-constants
    event: u32,
    window: HWND,
    id_object: u32,
    id_child: u32,
    id_event_thread: u32,
    dwms_event_time: u32
) #c_call {
    inspected_window := GetForegroundWindow();
    process_id: u32 = 0;
    GetWindowThreadProcessId(inspected_window, *process_id);

    if !process_id {
        // Sometimes when you minimize a window nothing is focused for a brief moment,
        // in this case windows sends "System Idle Process" as currently focused window
        // for some reason. Just ignore it.
        return;
    }
    ctx: Context;
    push_context ctx {
        foreground_process := OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_QUERY_LIMITED_INFORMATION, 0, process_id);
        if !foreground_process {
            // Sometimes we can't open a process (#5 "access denied"). Ignore it I guess.
            if (GetLastError() == 5) {
                return;
            }
            print("Couldn't open the foreground process, error code is %\n", GetLastError());
        }

        filename_size : u32 = MAX_PATH;
        // This function API is so fucking weird. Read its docs extremely carefully
        QueryFullProcessImageNameW(foreground_process, 0, focused_program_path.data, *filename_size);
        CloseHandle(foreground_process);
        PathStripPathW(focused_program_path.data);
        focused_program_name, ok := wide_to_utf8_new(focused_program_path.data);
        print("Window activated: %\n", focused_program_name);

        program_handle := GetModuleHandleW(null);

        if array_find(ALLOWED_PROGRAMS, focused_program_name) {
            set_kb_hook(program_handle);
            return;
        }
        unset_kb_hook();
    }
}

start_detecting_focused_program :: () {
    SetWinEventHook(
        EVENT_OBJECT_FOCUS,
        EVENT_OBJECT_FOCUS,
        null,
        cast(*void)detect_focused_program,
        0,
        0,
        WINEVENT_OUTOFCONTEXT,
    );
}

set_kb_hook :: (instance: HINSTANCE) {
    if !mapping_resolving_hook_is_installed {
        print("hooking this shit\n");
        mapping_resolving_hook = SetWindowsHookExW(WH_KEYBOARD_LL, cast(HOOKPROC)low_level_keyboard_proc, instance, 0);
        if (mapping_resolving_hook != null) {
            mapping_resolving_hook_is_installed = true;
        } else {
            print("hook failed oopsie\n");
        }
    }
}

set_key_mapping_hook :: (window: Window_Type) {
    if !mapping_setting_hook_is_installed {
        // null as instance and GetCurrentThreadId() instead of zero to hook into inputs when focusing this program.
        // Otherwise, the hook will only listen to keyboard from all other programs except this one!
        mapping_setting_hook = SetWindowsHookExW(WH_KEYBOARD, cast(HOOKPROC)mapping_setting_hook_proc, null, GetCurrentThreadId());
        if (mapping_setting_hook != null) {
            mapping_setting_hook_is_installed = true;
            print("listening for new mapping\n");
        } else {
            error := GetLastError();
            log_error("mapping setting hook initialization failed: %\n", error);
        }
    }
}

unset_kb_hook :: () {
    if !mapping_resolving_hook_is_installed return;

    print("unhooking this shit\n");
    UnhookWindowsHookEx(mapping_resolving_hook);
    // Forget buttons that are pressed before unhooking from the keyboard
    // So that when we hook again we don't end up in a dirty state where one
    // of the buttons is being stuck from the previous hook
    kb_real_state[DIRECTION_LEFT] = IS_UP;
    kb_real_state[DIRECTION_RIGHT] = IS_UP;
    kb_real_state[DIRECTION_UP] = IS_UP;
    kb_real_state[DIRECTION_DOWN] = IS_UP;
    kb_virtual_state[DIRECTION_LEFT] = IS_UP;
    kb_virtual_state[DIRECTION_RIGHT] = IS_UP;
    kb_virtual_state[DIRECTION_UP] = IS_UP;
    kb_virtual_state[DIRECTION_DOWN] = IS_UP;
    mapping_resolving_hook_is_installed = false;
}

unset_mapping_setting_hook :: () {
    if !mapping_setting_hook_is_installed return;
    print("unhooking mapping setting hook\n");
    UnhookWindowsHookEx(mapping_setting_hook);
    mapping_setting_hook_is_installed = false;
}

get_dpi_scale :: (window: Window_Type) -> float {
    // TODO: Return 1.0 for Windows7, if we will ever support that.
    dpi := cast(float32) GetDpiForWindow(window);
    return dpi / 96.0;
}

create_window :: () -> Window_Type {
    // Windows is very bad at thread-switching by default unless you do this. Sad.
    timeBeginPeriod(1);
    the_window := create_window(window_width, window_height, "Hitboxer");
    // We can't specify style in create_window, so change it afterwards.
    // TLDR is that we want a regular window but without an ability to maximize and resize it.
    SetWindowLongPtrW(the_window, GWL_STYLE, WS_VISIBLE | WS_OVERLAPPED | WS_CAPTION | WS_MINIMIZEBOX | WS_SYSMENU);

    return the_window;
}

HHOOK :: *void;
HOOKPROC :: *void;
WH_KEYBOARD :: 2;
WH_KEYBOARD_LL :: 13;

KBDLLHOOKSTRUCT :: struct {
   vkCode: u32;
   scanCode: u32;
   flags: u32;
   time: u32;
   dwExtraInfo: u32;
}

INPUT_Type :: enum u32 {
    INPUT_MOUSE :: 0;
    INPUT_KEYBOARD :: 1;
    INPUT_HARDWARE :: 2;
}

INPUT :: struct {
    type: INPUT_Type;
    mi: MOUSEINPUT;
    #place mi;
    ki: KEYBDINPUT;
    #place mi;
    hi: HARDWAREINPUT;
}

KEYEVENTF_KEYUP : u32 : 0x0002;
KEYEVENTF_SCANCODE : u32 : 0x0008;

KEYBDINPUT :: struct {
  wVk: u16;
  wScan: u16;
  dwFlags: u32;
  time: u32;
  dwExtraInfo: *u32;
}

MOUSEINPUT :: struct {
    dx: s32;
    dy: s32;
    mouseData: u32;
    dwFlags: u32;
    time: u32;
    dwExtraInfo: *u32;
}

HARDWAREINPUT :: struct {
    uMsg: u32;
    wParamL: u16;
    wParamH: u16;
}

HC_ACTION :: 0; // The wParam and lParam parameters contain information about a keyboard message.

KF_EXTENDED :: 0x0100; //  	Manipulates the extended key flag.
KF_DLGMODE :: 0x0800; //  	Manipulates the dialog mode flag, which indicates whether a dialog box is active.
KF_MENUMODE :: 0x1000; //  	Manipulates the menu mode flag, which indicates whether a menu is active.
KF_ALTDOWN :: 0x2000; //  	Manipulates the context code flag.
KF_REPEAT :: 0x4000; //  	Manipulates the previous key state flag.
KF_UP :: 0x8000; //  	Manipulates the transition state flag.

LLKHF_EXTENDED :: 0x0100 >> 8; // Test the extended-key flag.
LLKHF_INJECTED :: 0x00000010; // Test the event-injected (from any process) flag.

EVENT_OBJECT_FOCUS :: 0x8005;
WINEVENT_OUTOFCONTEXT :: 0;

PROCESS_QUERY_INFORMATION :: 0x0400;
PROCESS_QUERY_LIMITED_INFORMATION :: 0x1000;

user32 :: #system_library "user32";
kernel32 :: #system_library "kernel32";
shlwapi :: #system_library "shlwapi";

SetWindowsHookExW :: (idHook: s32, lpfn: HOOKPROC, hmod: HINSTANCE, dwThreadId: u32) -> HHOOK #foreign user32;
UnhookWindowsHookEx :: (hhk: HHOOK) -> s32 #foreign user32;
CallNextHookEx :: (hhk: HHOOK, nCode: s32, wParam: WPARAM, lParam: LPARAM) -> s64 #foreign user32;
GetKeyNameTextW :: (lparam: u32, lp_string: *u16, cch_size: s32) -> s32 #foreign user32;
// TODO: Make it a pointer to an array of INPUTs instead:
// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput
SendInput :: (cInputs: u32, pInputs: *INPUT, cbSize: s32) -> u32 #foreign user32;
GetWindowThreadProcessId :: (hwnd: HWND, lpdwProcessId: *u32) -> u32 #foreign user32;
SetWinEventHook :: (eventMin: u32, eventMax: u32, hmodWinEventProc: HMODULE, pfnWinEventProc: *void, idProcess: u32, idThread: u32, dwFlags: u32) -> HANDLE #foreign user32;
GetDpiForWindow :: (hWnd: HWND) -> u32 #foreign user32;
OpenProcess :: (dwDesiredAccess: u32, bInheritHandle: s32, dwProcessId: u32) -> HANDLE #foreign kernel32;
QueryFullProcessImageNameW :: (hProcess: HANDLE, dwFlags: u32, lpExeName: *u16, lpdwSize: *u32) -> s32 #foreign kernel32;
PathStripPathW :: (pszPath: *u16) #foreign shlwapi;


#import "Windows";
#import "Windows_Utf8";
