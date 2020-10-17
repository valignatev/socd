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

int real[4]; // whether the key is pressed for real on keyboard
int virtual[4]; // whether the key is pressed on a software level
int left;
int right;
int up;
int down;

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

int main() {
    left = 0x41; // a
    right = 0x44; // d
    up = 0x57; // w
    down = 0x53; // s
    /* left = 0x4C; // l */
    /* right = 0xDE; // ' */
    /* printf("left is %d, right is %d", left, right); */
  
    printf("\n\nPress Ctrl+C to exit\n");
    real[KEY_LEFT] = IS_UP;
    real[KEY_RIGHT] = IS_UP;
    real[KEY_UP] = IS_UP;
    real[KEY_DOWN] = IS_UP;
    virtual[KEY_LEFT] = IS_UP;
    virtual[KEY_RIGHT] = IS_UP;
    virtual[KEY_UP] = IS_UP;
    virtual[KEY_DOWN] = IS_UP;
    SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc, GetModuleHandle(NULL), 0);
    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0)) {}
    return 0;
}
