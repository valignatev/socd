#include <windows.h>
#include <stdio.h>
#include <ctype.h>
#include <shlwapi.h>
#pragma comment(lib,"user32.lib")
#pragma comment(lib,"shlwapi.lib")

// Maintaining our own key states bookkeeping is kinda cringe
// but we can't really use Get[Async]KeyState, see the first note at
// https://docs.microsoft.com/en-us/previous-versions/windows/desktop/legacy/ms644985(v=vs.85)
# define KEY_LEFT 0
# define KEY_RIGHT 1
# define KEY_UP 2
# define KEY_DOWN 3
# define IS_DOWN 1
# define IS_UP 0
# define whitelist_max_length 200

const char* CONFIG_NAME = "socd.conf";
const char* CLASS_NAME = "SOCD_CLASS";
char config_line[100];
char focused_program[MAX_PATH];
char programs_whitelist[whitelist_max_length][MAX_PATH] = {0};

HHOOK kbhook;
int hook_is_installed = 0;

int real[4]; // whether the key is pressed for real on keyboard
int virtual[4]; // whether the key is pressed on a software level
//              a     d     w     s
int WASD[4] = {0x41, 0x44, 0x57, 0x53};
const int WASD_ID = 100;
//                <     >     ^     v
int ARROWS[4] = {0x25, 0x27, 0x26, 0x28};
const int ARROWS_ID = 200;
// left, right, up, down
int CUSTOM_BINDS[4];
const int CUSTOM_ID = 300;

int error_message(char* text) {
    int error = GetLastError();
    // error is dword which is 32 bits, so 10 characters should be enough considering that we have an extra %d in the string
    char* error_buffer = malloc(strlen(text) + 10);
    sprintf(error_buffer, text, error);
    MessageBox(
               NULL,
               error_buffer,
               "RIP",
               MB_OK | MB_ICONERROR);
    return 1;
}

void write_settings(int* bindings) {
    FILE* config_file = fopen(CONFIG_NAME, "w");
    if (config_file == NULL) {
        // This writes to console that we're freeing sigh
        // Probably better to show MessageBox
        perror("Couldn't open the config file");
        return;
    }
    for (int i = 0; i < 4; i++) {
        fprintf(config_file, "%X\n", bindings[i]);
    }
    for (int i = 0; i < whitelist_max_length; i++) {
        if (programs_whitelist[i][0] == '\0') {
            break;
        }
        fprintf(config_file, "%s\n", programs_whitelist[i]);
    }
    fclose(config_file);
}

void set_bindings(int* bindings) {
    CUSTOM_BINDS[0] = bindings[0];
    CUSTOM_BINDS[1] = bindings[1];
    CUSTOM_BINDS[2] = bindings[2];
    CUSTOM_BINDS[3] = bindings[3];
}

void read_settings() {
    FILE* config_file = fopen(CONFIG_NAME, "r+");
    if (config_file == NULL) {
        set_bindings(WASD);
        write_settings(WASD);
        return;
    }
    
    // First 4 lines are key bindings
    for (int i=0; i < 4; i++) {
        char* result = fgets(config_line, 100, config_file);
        int button = (int)strtol(result, NULL, 16);
        CUSTOM_BINDS[i] = button;
    }
    
    // Then there are programs SOCD cleaner should track
    int i = 0;
    while (fgets(programs_whitelist[i], MAX_PATH, config_file) != NULL) {
        // Remove line ends from the line we just read.
        // Works for LF, CR, CRLF, LFCR etc
        programs_whitelist[i][strcspn(programs_whitelist[i], "\r\n")] = 0;
        i++;
    }
    for (int i = 0; i < whitelist_max_length; i++) {
        if (programs_whitelist[i][0] == '\0') {
            break;
        }
    }
    fclose(config_file);
}

int find_opposing_key(int key) {
    if (key == CUSTOM_BINDS[KEY_LEFT]) {
        return CUSTOM_BINDS[KEY_RIGHT];
    }
    if (key == CUSTOM_BINDS[KEY_RIGHT]) {
        return CUSTOM_BINDS[KEY_LEFT];
    }
    if (key == CUSTOM_BINDS[KEY_UP]) {
        return CUSTOM_BINDS[KEY_DOWN];
    }
    if (key == CUSTOM_BINDS[KEY_DOWN]) {
        return CUSTOM_BINDS[KEY_UP];
    }
    return -1;
}

int find_index_by_key(int key) {
    if (key == CUSTOM_BINDS[KEY_LEFT]) {
        return KEY_LEFT;
    }
    if (key == CUSTOM_BINDS[KEY_RIGHT]) {
        return KEY_RIGHT;
    }
    if (key == CUSTOM_BINDS[KEY_UP]) {
        return KEY_UP;
    }
    if (key == CUSTOM_BINDS[KEY_DOWN]) {
        return KEY_DOWN;
    }
    return -1;
}

LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
    KBDLLHOOKSTRUCT* kbInput = (KBDLLHOOKSTRUCT*)lParam;
    
    // We ignore injected events so we don't mess with the inputs
    // we inject ourselves with SendInput
    if (nCode != HC_ACTION || kbInput->flags & LLKHF_INJECTED) {
        return CallNextHookEx(NULL, nCode, wParam, lParam);
    }
    
    INPUT input;
    int key = kbInput->vkCode;
    int opposing = find_opposing_key(key);
    if (opposing < 0) {
        return CallNextHookEx(NULL, nCode, wParam, lParam);
    }
    int index = find_index_by_key(key);
    int opposing_index = find_index_by_key(opposing);
    
    // Holding Alt sends WM_SYSKEYDOWN/WM_SYSKEYUP
    // instead of WM_KEYDOWN/WM_KEYUP, check it as well
    if (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN) {
        real[index] = IS_DOWN;
        virtual[index] = IS_DOWN;
        if (real[opposing_index] == IS_DOWN && virtual[opposing_index] == IS_DOWN) {
            input.type = INPUT_KEYBOARD;
            input.ki = (KEYBDINPUT){opposing, 0, KEYEVENTF_KEYUP, 0, 0};
            SendInput(1, &input, sizeof(INPUT));
            virtual[opposing_index] = IS_UP;
        }
    }
    else if (wParam == WM_KEYUP || wParam == WM_SYSKEYUP) {
        real[index] = IS_UP;
        virtual[index] = IS_UP;
        if (real[opposing_index] == IS_DOWN) {
            input.type = INPUT_KEYBOARD;
            input.ki = (KEYBDINPUT){opposing, 0, 0, 0, 0};
            SendInput(1, &input, sizeof(INPUT));
            virtual[opposing_index] = IS_DOWN;
        }
    }
    return CallNextHookEx(NULL, nCode, wParam, lParam);
}

void set_kb_hook(HINSTANCE instance) {
    if (!hook_is_installed) {
        printf("hooking this shit\n");
        kbhook = SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc, instance, 0);
        if (kbhook != NULL) {
            hook_is_installed = 1;
        }
    }
}

void unset_kb_hook() {
    if (hook_is_installed) {
        printf("unhooking this shit\n");
        UnhookWindowsHookEx(kbhook);
        hook_is_installed = 0;
    }
}

void winEventProc(
    HWINEVENTHOOK hWinEventHook,
    DWORD event,
    HWND hwnd,
    LONG idObject,
    LONG idChild,
    DWORD idEventThread,
    DWORD dwmsEventTime
) {
    DWORD procId = 0;
    GetWindowThreadProcessId(hwnd, &procId);
    if (procId == 0) {
        // Sometimes when you minimize a window nothing is focused for a brief moment,
        // in this case windows sends "System Idle Process" as currently focused window
        // for some reason. Just ignore it
        return;
    }
    HANDLE hproc = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_QUERY_LIMITED_INFORMATION, 0, procId);
    if (hproc == NULL) {
        // Sometimes we can't open a process (#5 "access denied"). Ignore it I guess.
        if (GetLastError() == 5) {
            return;
        }
        error_message("Couldn't open active process, error code is: %d");
    }
    DWORD filename_size = MAX_PATH;
    // This function API is so fucking weird. Read its docs extremely carefully
    QueryFullProcessImageName(hproc, 0, focused_program, &filename_size);
    CloseHandle(hproc);
    PathStripPath(focused_program);
    
    HINSTANCE hInstance = (HINSTANCE)GetModuleHandle(NULL);
    // Linear scan let's fucking go, don't look here CS degree people
    for (int i = 0; i < whitelist_max_length; i++) {
        if (strcmp(focused_program, programs_whitelist[i]) == 0) {
            printf("Window activated: %s\n", focused_program);
            set_kb_hook(hInstance);
            return;
        } else if (programs_whitelist[i][0] == '\0') {
            break;
        }
    }
    unset_kb_hook();
}

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    switch (uMsg) {
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    case WM_COMMAND:
        if (wParam == WASD_ID) {
            set_bindings(WASD);
            write_settings(WASD);
        } else if (wParam == ARROWS_ID) {
            set_bindings(ARROWS);
            write_settings(ARROWS);
        }
    }

    return DefWindowProc(hwnd, uMsg, wParam, lParam);
}

int main() {
    // You can compile with these flags instead of calling to FreeConsole
    // to get rid of a terminal window
    // cl socd_cleaner.c /link /SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup
    FreeConsole();

    real[KEY_LEFT] = IS_UP;
    real[KEY_RIGHT] = IS_UP;
    real[KEY_UP] = IS_UP;
    real[KEY_DOWN] = IS_UP;
    virtual[KEY_LEFT] = IS_UP;
    virtual[KEY_RIGHT] = IS_UP;
    virtual[KEY_UP] = IS_UP;
    virtual[KEY_DOWN] = IS_UP;

    HINSTANCE hInstance = (HINSTANCE)GetModuleHandle(NULL);
    
    read_settings();
    // Means no allowed programes were set up, just globally set the hook.
    if (programs_whitelist[0][0] == '\0') {
        set_kb_hook(hInstance);
        
        // At least one allowed program is specified,
        // handle hooking/unhooking when program gets focused/unfocused
    } else {
        SetWinEventHook(
            EVENT_OBJECT_FOCUS,
            EVENT_OBJECT_FOCUS,
            hInstance,
            (WINEVENTPROC)winEventProc,
            0,
            0,
            WINEVENT_OUTOFCONTEXT
            );
    }
    
    WNDCLASSEX wc;
    wc.cbSize = sizeof(WNDCLASSEX);
    wc.style = 0;
    wc.lpfnWndProc = WindowProc;
    wc.cbClsExtra = 0;
    wc.cbWndExtra = 0;
    wc.hInstance = hInstance;
    wc.hIcon = LoadIcon(NULL, IDI_APPLICATION);
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wc.lpszMenuName = NULL;
    wc.lpszClassName = CLASS_NAME;
    wc.hIconSm = LoadIcon(NULL, IDI_APPLICATION);
    
    if (RegisterClassEx(&wc) == 0) {
        return error_message("Failed to register window class, error code is %d");
    };
    
    HWND hwndMain = CreateWindowEx(
        0,
        CLASS_NAME,
        "SOCD helper for Epic Gamers!",
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        460,
        200,
        NULL,
        NULL,
        hInstance,
        NULL);
    if (hwndMain == NULL) {
        return error_message("Failed to create a window, error code is %d");
    }
    
    HWND wasd_hwnd = CreateWindowEx(
        0,
        "BUTTON",
        "WASD",
        WS_TABSTOP | WS_VISIBLE | WS_CHILD | BS_AUTORADIOBUTTON,
        10,
        90,
        100,
        30,
        hwndMain,
        (HMENU)WASD_ID,
        hInstance,
        NULL);
    if (wasd_hwnd == NULL) {
        return error_message("Failed to create WASD radiobutton, error code is %d");
    }
    
    HWND arrows_hwnd = CreateWindowEx(
        0,
        "BUTTON",
        "Arrows",
        WS_TABSTOP | WS_VISIBLE | WS_CHILD | BS_AUTORADIOBUTTON,
        10,
        110,
        100,
        30,
        hwndMain,
        (HMENU)ARROWS_ID,
        hInstance,
        NULL);
    if (arrows_hwnd == NULL) {
        return error_message("Failed to create Arrows radiobutton, error code is %d");
    }
    
    HWND custom_hwnd = CreateWindowEx(
        0,
        "BUTTON",
        "Custom",
        WS_TABSTOP | WS_VISIBLE | WS_CHILD | BS_AUTORADIOBUTTON,
        10,
        130,
        100,
        30,
        hwndMain,
        (HMENU)CUSTOM_ID,
        hInstance,
        NULL);
    if (custom_hwnd == NULL) {
        return error_message("Failed to create Custom radiobutton, error code is %d");
    }
    
    int check_id;
    if (memcmp(CUSTOM_BINDS, WASD, sizeof(WASD)) == 0) {
        check_id = WASD_ID;
    } else if (memcmp(CUSTOM_BINDS, ARROWS, sizeof(ARROWS)) == 0) {
        check_id = ARROWS_ID;
    } else {
        check_id = CUSTOM_ID;
    }
    if (CheckRadioButton(hwndMain, WASD_ID, CUSTOM_ID, check_id) == 0) {
        return error_message("Failed to select default keybindings, error code is %d");
    }
    
    HWND text_hwnd = CreateWindowEx(
        0,
        "STATIC",
        ("\"Last Wins\" is the only mode available as of now.\n"
         "I'll add custom binding interface later. "
         "For now, you can set them in socd.conf in the first 4 rows. "
         "The order is left, right, up, down."),
        WS_VISIBLE | WS_CHILD,
        10,
        10,
        400,
        80,
        hwndMain,
        (HMENU)100,
        hInstance,
        NULL);
    if (text_hwnd == NULL) {
        return error_message("Failed to create Text, error code is %d");
    }
    
    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
    return 0;
}
