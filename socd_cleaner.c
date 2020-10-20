#include <windows.h>
#include <stdio.h>
#include <ctype.h>
#pragma comment(lib,"user32.lib")

// Maintaining our own key states bookkeeping is kinda cringe
// but we can't really use Get[Async]KeyState, see the first note at
// https://docs.microsoft.com/en-us/previous-versions/windows/desktop/legacy/ms644985(v=vs.85)
# define KEY_LEFT 0
# define KEY_RIGHT 1
# define KEY_UP 2
# define KEY_DOWN 3
# define IS_DOWN 1
# define IS_UP 0

const char *CLASS_NAME = "SOCD_CLASS";
char error_message_buffer[100];

int real[4]; // whether the key is pressed for real on keyboard
int virtual[4]; // whether the key is pressed on a software level
int left;
int right;
int up;
int down;
//                   a     d     w     s
const int WASD[4] = {0x41, 0x44, 0x57, 0x53};
const int WASD_ID = 666;
//                     <     >     ^     v
const int ARROWS[4] = {0x25, 0x27, 0x26, 0x28};
const int ARROWS_ID = 999;

int error_message(char* text) {
    int error = GetLastError();
    sprintf(error_message_buffer, text, error);
    MessageBox(
        NULL,
        error_message_buffer,
        "RIP",
        MB_OK | MB_ICONERROR);
    return 1;
}

void set_bindings(const int* bindings) {
    left = bindings[0];
    right = bindings[1];
    up = bindings[2];
    down = bindings[3];
}

int find_opposing_key(int key) {
    if (key == left) {
        return right;
    }
    if (key == right) {
        return left;
    }
    if (key == up) {
        return down;
    }
    if (key == down) {
        return up;
    }
    return -1;
}

int find_index_by_key(int key) {
    if (key == left) {
        return KEY_LEFT;
    }
    if (key == right) {
        return KEY_RIGHT;
    }
    if (key == up) {
        return KEY_UP;
    }
    if (key == down) {
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
        /* printf("%d\n", key); */
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
        /* printf("%d released\n", key); */
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

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    switch (uMsg) {
    case WM_DESTROY:
	PostQuitMessage(0);
	return 0;
    case WM_COMMAND:
        if (wParam == WASD_ID) {
            set_bindings(WASD);
        } else if (wParam == ARROWS_ID) {
            set_bindings(ARROWS);
        }
    }

    return DefWindowProc(hwnd, uMsg, wParam, lParam);
}

int main() {
    // You can compile with these flags instead of calling to FreeConsole
    // to get rid of a terminal window
    // cl socd_cleaner.c /link /SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup
    FreeConsole();
    set_bindings(WASD);

    real[KEY_LEFT] = IS_UP;
    real[KEY_RIGHT] = IS_UP;
    real[KEY_UP] = IS_UP;
    real[KEY_DOWN] = IS_UP;
    virtual[KEY_LEFT] = IS_UP;
    virtual[KEY_RIGHT] = IS_UP;
    virtual[KEY_UP] = IS_UP;
    virtual[KEY_DOWN] = IS_UP;

    HINSTANCE hInstance = (HINSTANCE)GetModuleHandle(NULL);
    SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc, hInstance, 0);

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
        WS_OVERLAPPEDWINDOW,
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
        100,
        100,
        30,
        hwndMain,
        (HMENU)WASD_ID,
        hInstance,
        NULL);
    if (wasd_hwnd == NULL) {
        return error_message("Failed to create WASD radiobutton, error code is %d");
    }

    if (CheckRadioButton(hwndMain, WASD_ID, ARROWS_ID, WASD_ID) == 0) {
        return error_message("Failed to select default keybindings, error code is %d");
    }

    HWND arrows_hwnd = CreateWindowEx(
        0,
        "BUTTON",
        "Arrows",
        WS_TABSTOP | WS_VISIBLE | WS_CHILD | BS_AUTORADIOBUTTON,
        10,
        120,
        100,
        30,
        hwndMain,
        (HMENU)ARROWS_ID,
        hInstance,
        NULL);
    if (arrows_hwnd == NULL) {
        return error_message("Failed to create Arrows radiobutton, error code is %d");
    }

    HWND text_hwnd = CreateWindowEx(
        0,
        "STATIC",
        "\"Last Wins\" is the only mode available as of now.",
        WS_VISIBLE | WS_CHILD,
        10,
        10,
        400,
        20,
        hwndMain,
        (HMENU)100,
        hInstance,
        NULL);
    if (text_hwnd == NULL) {
        return error_message("Failed to create Text, error code is %d");
    }
    HWND text1_hwnd = CreateWindowEx(
        0,
        "STATIC",
        "Arbitrary keybindings will be added later. For now, only WASD or Arrows. Hardcode your bindings and compile it yourself or DM me in discord (valignatev#7795), I can compile a version for you.",
        WS_VISIBLE | WS_CHILD,
        10,
        30,
        400,
        70,
        hwndMain,
        (HMENU)100,
        hInstance,
        NULL);
    if (text1_hwnd == NULL) {
        return error_message("Failed to create Text1, error code is %d");
    }

    ShowWindow(hwndMain, SW_SHOWDEFAULT);
    UpdateWindow(hwndMain);

    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0)) {
	TranslateMessage(&msg);
	DispatchMessage(&msg);
    }
    return 0;
}
