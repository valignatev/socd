#include <windows.h>
#include <stdio.h>
#include <ctype.h>
#pragma comment(lib,"user32.lib")

// Maintaining our own key states bookkeeping is kinda cringe
// but we can't really use Get[Async]KeyState, see the first note at
// https://docs.microsoft.com/en-us/previous-versions/windows/desktop/legacy/ms644985(v=vs.85)
# define KEY_LEFT 0
# define KEY_RIGHT 1
# define IS_DOWN 1
# define IS_UP 0

int real[2]; // whether the key is pressed for real on keyboard
int virtual[2]; // whether the key is pressed on a software level
int left;
int right;

LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
    KBDLLHOOKSTRUCT* kbInput = (KBDLLHOOKSTRUCT*)lParam;

    // We ignore injected events so we don't mess with the inputs
    // we inject ourselves with SendInput
    if (nCode != HC_ACTION || kbInput->flags & LLKHF_INJECTED) {
        return CallNextHookEx(NULL, nCode, wParam, lParam);
    }

    INPUT ip;
    INPUT ip1;
    int key = kbInput->vkCode;
    // Holding Alt sends WM_SYSKEYDOWN/WM_SYSKEYUP
    // instead of WM_KEYDOWN/WM_KEYUP, check it as well
    if (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN) {
        /* printf("%d\n", key); */
        if (key == left) {
            /* printf("left pressed\n"); */
            real[KEY_LEFT] = IS_DOWN;
            virtual[KEY_LEFT] = IS_DOWN;
            if (real[KEY_RIGHT] == IS_DOWN && virtual[KEY_RIGHT] == IS_DOWN) {
                ip.type = INPUT_KEYBOARD;
                ip.ki = (KEYBDINPUT){right, 0, KEYEVENTF_KEYUP, 0, 0};
                ip1.type = INPUT_KEYBOARD;
                ip1.ki = (KEYBDINPUT){left, 0, 0, 0, 0};
                INPUT arr[2] = {ip, ip1};
                SendInput(2, arr, sizeof(INPUT));
                virtual[KEY_RIGHT] = IS_UP;
            }
        }
        else if (key == right) {
            /* printf("right pressed\n"); */
            real[KEY_RIGHT] = IS_DOWN;
            virtual[KEY_RIGHT] = IS_DOWN;
            if (real[KEY_LEFT] == IS_DOWN && virtual[KEY_LEFT] == IS_DOWN) {
                ip.type = INPUT_KEYBOARD;
                ip.ki = (KEYBDINPUT){left, 0, KEYEVENTF_KEYUP, 0, 0};
                ip1.type = INPUT_KEYBOARD;
                ip1.ki = (KEYBDINPUT){right, 0, 0, 0, 0};
                INPUT arr[2] = {ip, ip1};
                SendInput(2, arr, sizeof(INPUT));
                virtual[KEY_LEFT] = IS_UP;
            }
        }
    }
    else if (wParam == WM_KEYUP || wParam == WM_SYSKEYUP) {
        if (key == left) {
            /* printf("left released\n"); */
            real[KEY_LEFT] = IS_UP;
            virtual[KEY_LEFT] = IS_UP;
            if (real[KEY_RIGHT] == IS_DOWN) {
                ip.type = INPUT_KEYBOARD;
                ip.ki = (KEYBDINPUT){right, 0, 0, 0, 0};
                ip1.type = INPUT_KEYBOARD;
                ip1.ki = (KEYBDINPUT){left, 0, KEYEVENTF_KEYUP, 0, 0};
                INPUT arr[2] = {ip1, ip};
                SendInput(2, arr, sizeof(INPUT));
                virtual[KEY_RIGHT] = IS_DOWN;
            }
        }
        else if (key == right) {
            /* printf("right released\n"); */
            real[KEY_RIGHT] = IS_UP;
            virtual[KEY_RIGHT] = IS_UP;
            if (real[KEY_LEFT] == IS_DOWN) {
                ip.type = INPUT_KEYBOARD;
                ip.ki = (KEYBDINPUT){left, 0, 0, 0, 0};
                ip1.type = INPUT_KEYBOARD;
                ip1.ki = (KEYBDINPUT){right, 0, KEYEVENTF_KEYUP, 0, 0};
                INPUT arr[2] = {ip1, ip};
                SendInput(2, arr, sizeof(INPUT));
                virtual[KEY_LEFT] = IS_DOWN;
            }
        }
    }
    return CallNextHookEx(NULL, nCode, wParam, lParam);
}

int main() {
    left = 0x41; // a
    right = 0x44; // d
    /* left = 0x4C; // l */
    /* right = 0xDE; // ' */
    /* printf("left is %d, right is %d", left, right); */
  
    printf("\n\nPress Ctrl+C to exit\n");
    real[KEY_LEFT] = IS_UP;
    real[KEY_RIGHT] = IS_UP;
    virtual[KEY_LEFT] = IS_UP;
    virtual[KEY_RIGHT] = IS_UP;
    SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc, GetModuleHandle(NULL), 0);
    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0)) {}
    return 0;
}
