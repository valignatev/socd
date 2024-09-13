#load "./ioctl.jai";

//
// This file was auto-generated using the following command:
//
// jai generate.jai
//



INPUT_PROP_POINTER :: 0x00;
INPUT_PROP_DIRECT :: 0x01;
INPUT_PROP_BUTTONPAD :: 0x02;
INPUT_PROP_SEMI_MT :: 0x03;
INPUT_PROP_TOPBUTTONPAD :: 0x04;
INPUT_PROP_POINTING_STICK :: 0x05;
INPUT_PROP_ACCELEROMETER :: 0x06;

INPUT_PROP_MAX :: 0x1f;
INPUT_PROP_CNT :: INPUT_PROP_MAX + 1;

EV_SYN :: 0x00;
EV_KEY :: 0x01;
EV_REL :: 0x02;
EV_ABS :: 0x03;
EV_MSC :: 0x04;
EV_SW :: 0x05;
EV_LED :: 0x11;
EV_SND :: 0x12;
EV_REP :: 0x14;
EV_FF :: 0x15;
EV_PWR :: 0x16;
EV_FF_STATUS :: 0x17;
EV_MAX :: 0x1f;
EV_CNT :: EV_MAX+1;

SYN_REPORT :: 0;
SYN_CONFIG :: 1;
SYN_MT_REPORT :: 2;
SYN_DROPPED :: 3;
SYN_MAX :: 0xf;
SYN_CNT :: SYN_MAX+1;

KEY_RESERVED :: 0;
KEY_ESC :: 1;
KEY_1 :: 2;
KEY_2 :: 3;
KEY_3 :: 4;
KEY_4 :: 5;
KEY_5 :: 6;
KEY_6 :: 7;
KEY_7 :: 8;
KEY_8 :: 9;
KEY_9 :: 10;
KEY_0 :: 11;
KEY_MINUS :: 12;
KEY_EQUAL :: 13;
KEY_BACKSPACE :: 14;
KEY_TAB :: 15;
KEY_Q :: 16;
KEY_W :: 17;
KEY_E :: 18;
KEY_R :: 19;
KEY_T :: 20;
KEY_Y :: 21;
KEY_U :: 22;
KEY_I :: 23;
KEY_O :: 24;
KEY_P :: 25;
KEY_LEFTBRACE :: 26;
KEY_RIGHTBRACE :: 27;
KEY_ENTER :: 28;
KEY_LEFTCTRL :: 29;
KEY_A :: 30;
KEY_S :: 31;
KEY_D :: 32;
KEY_F :: 33;
KEY_G :: 34;
KEY_H :: 35;
KEY_J :: 36;
KEY_K :: 37;
KEY_L :: 38;
KEY_SEMICOLON :: 39;
KEY_APOSTROPHE :: 40;
KEY_GRAVE :: 41;
KEY_LEFTSHIFT :: 42;
KEY_BACKSLASH :: 43;
KEY_Z :: 44;
KEY_X :: 45;
KEY_C :: 46;
KEY_V :: 47;
KEY_B :: 48;
KEY_N :: 49;
KEY_M :: 50;
KEY_COMMA :: 51;
KEY_DOT :: 52;
KEY_SLASH :: 53;
KEY_RIGHTSHIFT :: 54;
KEY_KPASTERISK :: 55;
KEY_LEFTALT :: 56;
KEY_SPACE :: 57;
KEY_CAPSLOCK :: 58;
KEY_F1 :: 59;
KEY_F2 :: 60;
KEY_F3 :: 61;
KEY_F4 :: 62;
KEY_F5 :: 63;
KEY_F6 :: 64;
KEY_F7 :: 65;
KEY_F8 :: 66;
KEY_F9 :: 67;
KEY_F10 :: 68;
KEY_NUMLOCK :: 69;
KEY_SCROLLLOCK :: 70;
KEY_KP7 :: 71;
KEY_KP8 :: 72;
KEY_KP9 :: 73;
KEY_KPMINUS :: 74;
KEY_KP4 :: 75;
KEY_KP5 :: 76;
KEY_KP6 :: 77;
KEY_KPPLUS :: 78;
KEY_KP1 :: 79;
KEY_KP2 :: 80;
KEY_KP3 :: 81;
KEY_KP0 :: 82;
KEY_KPDOT :: 83;

KEY_ZENKAKUHANKAKU :: 85;
KEY_102ND :: 86;
KEY_F11 :: 87;
KEY_F12 :: 88;
KEY_RO :: 89;
KEY_KATAKANA :: 90;
KEY_HIRAGANA :: 91;
KEY_HENKAN :: 92;
KEY_KATAKANAHIRAGANA :: 93;
KEY_MUHENKAN :: 94;
KEY_KPJPCOMMA :: 95;
KEY_KPENTER :: 96;
KEY_RIGHTCTRL :: 97;
KEY_KPSLASH :: 98;
KEY_SYSRQ :: 99;
KEY_RIGHTALT :: 100;
KEY_LINEFEED :: 101;
KEY_HOME :: 102;
KEY_UP :: 103;
KEY_PAGEUP :: 104;
KEY_LEFT :: 105;
KEY_RIGHT :: 106;
KEY_END :: 107;
KEY_DOWN :: 108;
KEY_PAGEDOWN :: 109;
KEY_INSERT :: 110;
KEY_DELETE :: 111;
KEY_MACRO :: 112;
KEY_MUTE :: 113;
KEY_VOLUMEDOWN :: 114;
KEY_VOLUMEUP :: 115;
KEY_POWER :: 116;
KEY_KPEQUAL :: 117;
KEY_KPPLUSMINUS :: 118;
KEY_PAUSE :: 119;
KEY_SCALE :: 120;

KEY_KPCOMMA :: 121;
KEY_HANGEUL :: 122;
KEY_HANGUEL :: KEY_HANGEUL;
KEY_HANJA :: 123;
KEY_YEN :: 124;
KEY_LEFTMETA :: 125;
KEY_RIGHTMETA :: 126;
KEY_COMPOSE :: 127;

KEY_STOP :: 128;
KEY_AGAIN :: 129;
KEY_PROPS :: 130;
KEY_UNDO :: 131;
KEY_FRONT :: 132;
KEY_COPY :: 133;
KEY_OPEN :: 134;
KEY_PASTE :: 135;
KEY_FIND :: 136;
KEY_CUT :: 137;
KEY_HELP :: 138;
KEY_MENU :: 139;
KEY_CALC :: 140;
KEY_SETUP :: 141;
KEY_SLEEP :: 142;
KEY_WAKEUP :: 143;
KEY_FILE :: 144;
KEY_SENDFILE :: 145;
KEY_DELETEFILE :: 146;
KEY_XFER :: 147;
KEY_PROG1 :: 148;
KEY_PROG2 :: 149;
KEY_WWW :: 150;
KEY_MSDOS :: 151;
KEY_COFFEE :: 152;
KEY_SCREENLOCK :: KEY_COFFEE;
KEY_ROTATE_DISPLAY :: 153;
KEY_DIRECTION :: KEY_ROTATE_DISPLAY;
KEY_CYCLEWINDOWS :: 154;
KEY_MAIL :: 155;
KEY_BOOKMARKS :: 156;
KEY_COMPUTER :: 157;
KEY_BACK :: 158;
KEY_FORWARD :: 159;
KEY_CLOSECD :: 160;
KEY_EJECTCD :: 161;
KEY_EJECTCLOSECD :: 162;
KEY_NEXTSONG :: 163;
KEY_PLAYPAUSE :: 164;
KEY_PREVIOUSSONG :: 165;
KEY_STOPCD :: 166;
KEY_RECORD :: 167;
KEY_REWIND :: 168;
KEY_PHONE :: 169;
KEY_ISO :: 170;
KEY_CONFIG :: 171;
KEY_HOMEPAGE :: 172;
KEY_REFRESH :: 173;
KEY_EXIT :: 174;
KEY_MOVE :: 175;
KEY_EDIT :: 176;
KEY_SCROLLUP :: 177;
KEY_SCROLLDOWN :: 178;
KEY_KPLEFTPAREN :: 179;
KEY_KPRIGHTPAREN :: 180;
KEY_NEW :: 181;
KEY_REDO :: 182;

KEY_F13 :: 183;
KEY_F14 :: 184;
KEY_F15 :: 185;
KEY_F16 :: 186;
KEY_F17 :: 187;
KEY_F18 :: 188;
KEY_F19 :: 189;
KEY_F20 :: 190;
KEY_F21 :: 191;
KEY_F22 :: 192;
KEY_F23 :: 193;
KEY_F24 :: 194;

KEY_PLAYCD :: 200;
KEY_PAUSECD :: 201;
KEY_PROG3 :: 202;
KEY_PROG4 :: 203;
KEY_ALL_APPLICATIONS :: 204;
KEY_DASHBOARD :: KEY_ALL_APPLICATIONS;
KEY_SUSPEND :: 205;
KEY_CLOSE :: 206;
KEY_PLAY :: 207;
KEY_FASTFORWARD :: 208;
KEY_BASSBOOST :: 209;
KEY_PRINT :: 210;
KEY_HP :: 211;
KEY_CAMERA :: 212;
KEY_SOUND :: 213;
KEY_QUESTION :: 214;
KEY_EMAIL :: 215;
KEY_CHAT :: 216;
KEY_SEARCH :: 217;
KEY_CONNECT :: 218;
KEY_FINANCE :: 219;
KEY_SPORT :: 220;
KEY_SHOP :: 221;
KEY_ALTERASE :: 222;
KEY_CANCEL :: 223;
KEY_BRIGHTNESSDOWN :: 224;
KEY_BRIGHTNESSUP :: 225;
KEY_MEDIA :: 226;

KEY_SWITCHVIDEOMODE :: 227;

KEY_KBDILLUMTOGGLE :: 228;
KEY_KBDILLUMDOWN :: 229;
KEY_KBDILLUMUP :: 230;

KEY_SEND :: 231;
KEY_REPLY :: 232;
KEY_FORWARDMAIL :: 233;
KEY_SAVE :: 234;
KEY_DOCUMENTS :: 235;

KEY_BATTERY :: 236;

KEY_BLUETOOTH :: 237;
KEY_WLAN :: 238;
KEY_UWB :: 239;

KEY_UNKNOWN :: 240;

KEY_VIDEO_NEXT :: 241;
KEY_VIDEO_PREV :: 242;
KEY_BRIGHTNESS_CYCLE :: 243;
KEY_BRIGHTNESS_AUTO :: 244;

KEY_BRIGHTNESS_ZERO :: KEY_BRIGHTNESS_AUTO;
KEY_DISPLAY_OFF :: 245;

KEY_WWAN :: 246;
KEY_WIMAX :: KEY_WWAN;
KEY_RFKILL :: 247;

KEY_MICMUTE :: 248;

BTN_MISC :: 0x100;
BTN_0 :: 0x100;
BTN_1 :: 0x101;
BTN_2 :: 0x102;
BTN_3 :: 0x103;
BTN_4 :: 0x104;
BTN_5 :: 0x105;
BTN_6 :: 0x106;
BTN_7 :: 0x107;
BTN_8 :: 0x108;
BTN_9 :: 0x109;

BTN_MOUSE :: 0x110;
BTN_LEFT :: 0x110;
BTN_RIGHT :: 0x111;
BTN_MIDDLE :: 0x112;
BTN_SIDE :: 0x113;
BTN_EXTRA :: 0x114;
BTN_FORWARD :: 0x115;
BTN_BACK :: 0x116;
BTN_TASK :: 0x117;

BTN_JOYSTICK :: 0x120;
BTN_TRIGGER :: 0x120;
BTN_THUMB :: 0x121;
BTN_THUMB2 :: 0x122;
BTN_TOP :: 0x123;
BTN_TOP2 :: 0x124;
BTN_PINKIE :: 0x125;
BTN_BASE :: 0x126;
BTN_BASE2 :: 0x127;
BTN_BASE3 :: 0x128;
BTN_BASE4 :: 0x129;
BTN_BASE5 :: 0x12a;
BTN_BASE6 :: 0x12b;
BTN_DEAD :: 0x12f;

BTN_GAMEPAD :: 0x130;
BTN_SOUTH :: 0x130;
BTN_A :: BTN_SOUTH;
BTN_EAST :: 0x131;
BTN_B :: BTN_EAST;
BTN_C :: 0x132;
BTN_NORTH :: 0x133;
BTN_X :: BTN_NORTH;
BTN_WEST :: 0x134;
BTN_Y :: BTN_WEST;
BTN_Z :: 0x135;
BTN_TL :: 0x136;
BTN_TR :: 0x137;
BTN_TL2 :: 0x138;
BTN_TR2 :: 0x139;
BTN_SELECT :: 0x13a;
BTN_START :: 0x13b;
BTN_MODE :: 0x13c;
BTN_THUMBL :: 0x13d;
BTN_THUMBR :: 0x13e;

BTN_DIGI :: 0x140;
BTN_TOOL_PEN :: 0x140;
BTN_TOOL_RUBBER :: 0x141;
BTN_TOOL_BRUSH :: 0x142;
BTN_TOOL_PENCIL :: 0x143;
BTN_TOOL_AIRBRUSH :: 0x144;
BTN_TOOL_FINGER :: 0x145;
BTN_TOOL_MOUSE :: 0x146;
BTN_TOOL_LENS :: 0x147;
BTN_TOOL_QUINTTAP :: 0x148;
BTN_STYLUS3 :: 0x149;
BTN_TOUCH :: 0x14a;
BTN_STYLUS :: 0x14b;
BTN_STYLUS2 :: 0x14c;
BTN_TOOL_DOUBLETAP :: 0x14d;
BTN_TOOL_TRIPLETAP :: 0x14e;
BTN_TOOL_QUADTAP :: 0x14f;

BTN_WHEEL :: 0x150;
BTN_GEAR_DOWN :: 0x150;
BTN_GEAR_UP :: 0x151;

KEY_OK :: 0x160;
KEY_SELECT :: 0x161;
KEY_GOTO :: 0x162;
KEY_CLEAR :: 0x163;
KEY_POWER2 :: 0x164;
KEY_OPTION :: 0x165;
KEY_INFO :: 0x166;
KEY_TIME :: 0x167;
KEY_VENDOR :: 0x168;
KEY_ARCHIVE :: 0x169;
KEY_PROGRAM :: 0x16a;
KEY_CHANNEL :: 0x16b;
KEY_FAVORITES :: 0x16c;
KEY_EPG :: 0x16d;
KEY_PVR :: 0x16e;
KEY_MHP :: 0x16f;
KEY_LANGUAGE :: 0x170;
KEY_TITLE :: 0x171;
KEY_SUBTITLE :: 0x172;
KEY_ANGLE :: 0x173;
KEY_FULL_SCREEN :: 0x174;
KEY_ZOOM :: KEY_FULL_SCREEN;
KEY_MODE :: 0x175;
KEY_KEYBOARD :: 0x176;
KEY_ASPECT_RATIO :: 0x177;
KEY_SCREEN :: KEY_ASPECT_RATIO;
KEY_PC :: 0x178;
KEY_TV :: 0x179;
KEY_TV2 :: 0x17a;
KEY_VCR :: 0x17b;
KEY_VCR2 :: 0x17c;
KEY_SAT :: 0x17d;
KEY_SAT2 :: 0x17e;
KEY_CD :: 0x17f;
KEY_TAPE :: 0x180;
KEY_RADIO :: 0x181;
KEY_TUNER :: 0x182;
KEY_PLAYER :: 0x183;
KEY_TEXT :: 0x184;
KEY_DVD :: 0x185;
KEY_AUX :: 0x186;
KEY_MP3 :: 0x187;
KEY_AUDIO :: 0x188;
KEY_VIDEO :: 0x189;
KEY_DIRECTORY :: 0x18a;
KEY_LIST :: 0x18b;
KEY_MEMO :: 0x18c;
KEY_CALENDAR :: 0x18d;
KEY_RED :: 0x18e;
KEY_GREEN :: 0x18f;
KEY_YELLOW :: 0x190;
KEY_BLUE :: 0x191;
KEY_CHANNELUP :: 0x192;
KEY_CHANNELDOWN :: 0x193;
KEY_FIRST :: 0x194;
KEY_LAST :: 0x195;
KEY_AB :: 0x196;
KEY_NEXT :: 0x197;
KEY_RESTART :: 0x198;
KEY_SLOW :: 0x199;
KEY_SHUFFLE :: 0x19a;
KEY_BREAK :: 0x19b;
KEY_PREVIOUS :: 0x19c;
KEY_DIGITS :: 0x19d;
KEY_TEEN :: 0x19e;
KEY_TWEN :: 0x19f;
KEY_VIDEOPHONE :: 0x1a0;
KEY_GAMES :: 0x1a1;
KEY_ZOOMIN :: 0x1a2;
KEY_ZOOMOUT :: 0x1a3;
KEY_ZOOMRESET :: 0x1a4;
KEY_WORDPROCESSOR :: 0x1a5;
KEY_EDITOR :: 0x1a6;
KEY_SPREADSHEET :: 0x1a7;
KEY_GRAPHICSEDITOR :: 0x1a8;
KEY_PRESENTATION :: 0x1a9;
KEY_DATABASE :: 0x1aa;
KEY_NEWS :: 0x1ab;
KEY_VOICEMAIL :: 0x1ac;
KEY_ADDRESSBOOK :: 0x1ad;
KEY_MESSENGER :: 0x1ae;
KEY_DISPLAYTOGGLE :: 0x1af;
KEY_BRIGHTNESS_TOGGLE :: KEY_DISPLAYTOGGLE;
KEY_SPELLCHECK :: 0x1b0;
KEY_LOGOFF :: 0x1b1;

KEY_DOLLAR :: 0x1b2;
KEY_EURO :: 0x1b3;

KEY_FRAMEBACK :: 0x1b4;
KEY_FRAMEFORWARD :: 0x1b5;
KEY_CONTEXT_MENU :: 0x1b6;
KEY_MEDIA_REPEAT :: 0x1b7;
KEY_10CHANNELSUP :: 0x1b8;
KEY_10CHANNELSDOWN :: 0x1b9;
KEY_IMAGES :: 0x1ba;
KEY_NOTIFICATION_CENTER :: 0x1bc;
KEY_PICKUP_PHONE :: 0x1bd;
KEY_HANGUP_PHONE :: 0x1be;

KEY_DEL_EOL :: 0x1c0;
KEY_DEL_EOS :: 0x1c1;
KEY_INS_LINE :: 0x1c2;
KEY_DEL_LINE :: 0x1c3;

KEY_FN :: 0x1d0;
KEY_FN_ESC :: 0x1d1;
KEY_FN_F1 :: 0x1d2;
KEY_FN_F2 :: 0x1d3;
KEY_FN_F3 :: 0x1d4;
KEY_FN_F4 :: 0x1d5;
KEY_FN_F5 :: 0x1d6;
KEY_FN_F6 :: 0x1d7;
KEY_FN_F7 :: 0x1d8;
KEY_FN_F8 :: 0x1d9;
KEY_FN_F9 :: 0x1da;
KEY_FN_F10 :: 0x1db;
KEY_FN_F11 :: 0x1dc;
KEY_FN_F12 :: 0x1dd;
KEY_FN_1 :: 0x1de;
KEY_FN_2 :: 0x1df;
KEY_FN_D :: 0x1e0;
KEY_FN_E :: 0x1e1;
KEY_FN_F :: 0x1e2;
KEY_FN_S :: 0x1e3;
KEY_FN_B :: 0x1e4;
KEY_FN_RIGHT_SHIFT :: 0x1e5;

KEY_BRL_DOT1 :: 0x1f1;
KEY_BRL_DOT2 :: 0x1f2;
KEY_BRL_DOT3 :: 0x1f3;
KEY_BRL_DOT4 :: 0x1f4;
KEY_BRL_DOT5 :: 0x1f5;
KEY_BRL_DOT6 :: 0x1f6;
KEY_BRL_DOT7 :: 0x1f7;
KEY_BRL_DOT8 :: 0x1f8;
KEY_BRL_DOT9 :: 0x1f9;
KEY_BRL_DOT10 :: 0x1fa;

KEY_NUMERIC_0 :: 0x200;
KEY_NUMERIC_1 :: 0x201;
KEY_NUMERIC_2 :: 0x202;
KEY_NUMERIC_3 :: 0x203;
KEY_NUMERIC_4 :: 0x204;
KEY_NUMERIC_5 :: 0x205;
KEY_NUMERIC_6 :: 0x206;
KEY_NUMERIC_7 :: 0x207;
KEY_NUMERIC_8 :: 0x208;
KEY_NUMERIC_9 :: 0x209;
KEY_NUMERIC_STAR :: 0x20a;
KEY_NUMERIC_POUND :: 0x20b;
KEY_NUMERIC_A :: 0x20c;
KEY_NUMERIC_B :: 0x20d;
KEY_NUMERIC_C :: 0x20e;
KEY_NUMERIC_D :: 0x20f;

KEY_CAMERA_FOCUS :: 0x210;
KEY_WPS_BUTTON :: 0x211;

KEY_TOUCHPAD_TOGGLE :: 0x212;
KEY_TOUCHPAD_ON :: 0x213;
KEY_TOUCHPAD_OFF :: 0x214;

KEY_CAMERA_ZOOMIN :: 0x215;
KEY_CAMERA_ZOOMOUT :: 0x216;
KEY_CAMERA_UP :: 0x217;
KEY_CAMERA_DOWN :: 0x218;
KEY_CAMERA_LEFT :: 0x219;
KEY_CAMERA_RIGHT :: 0x21a;

KEY_ATTENDANT_ON :: 0x21b;
KEY_ATTENDANT_OFF :: 0x21c;
KEY_ATTENDANT_TOGGLE :: 0x21d;
KEY_LIGHTS_TOGGLE :: 0x21e;

BTN_DPAD_UP :: 0x220;
BTN_DPAD_DOWN :: 0x221;
BTN_DPAD_LEFT :: 0x222;
BTN_DPAD_RIGHT :: 0x223;

KEY_ALS_TOGGLE :: 0x230;
KEY_ROTATE_LOCK_TOGGLE :: 0x231;
KEY_REFRESH_RATE_TOGGLE :: 0x232;

KEY_BUTTONCONFIG :: 0x240;
KEY_TASKMANAGER :: 0x241;
KEY_JOURNAL :: 0x242;
KEY_CONTROLPANEL :: 0x243;
KEY_APPSELECT :: 0x244;
KEY_SCREENSAVER :: 0x245;
KEY_VOICECOMMAND :: 0x246;
KEY_ASSISTANT :: 0x247;
KEY_KBD_LAYOUT_NEXT :: 0x248;
KEY_EMOJI_PICKER :: 0x249;
KEY_DICTATE :: 0x24a;
KEY_CAMERA_ACCESS_ENABLE :: 0x24b;
KEY_CAMERA_ACCESS_DISABLE :: 0x24c;
KEY_CAMERA_ACCESS_TOGGLE :: 0x24d;
KEY_ACCESSIBILITY :: 0x24e;
KEY_DO_NOT_DISTURB :: 0x24f;

KEY_BRIGHTNESS_MIN :: 0x250;
KEY_BRIGHTNESS_MAX :: 0x251;

KEY_KBDINPUTASSIST_PREV :: 0x260;
KEY_KBDINPUTASSIST_NEXT :: 0x261;
KEY_KBDINPUTASSIST_PREVGROUP :: 0x262;
KEY_KBDINPUTASSIST_NEXTGROUP :: 0x263;
KEY_KBDINPUTASSIST_ACCEPT :: 0x264;
KEY_KBDINPUTASSIST_CANCEL :: 0x265;

KEY_RIGHT_UP :: 0x266;
KEY_RIGHT_DOWN :: 0x267;
KEY_LEFT_UP :: 0x268;
KEY_LEFT_DOWN :: 0x269;

KEY_ROOT_MENU :: 0x26a;

KEY_MEDIA_TOP_MENU :: 0x26b;
KEY_NUMERIC_11 :: 0x26c;
KEY_NUMERIC_12 :: 0x26d;

KEY_AUDIO_DESC :: 0x26e;
KEY_3D_MODE :: 0x26f;
KEY_NEXT_FAVORITE :: 0x270;
KEY_STOP_RECORD :: 0x271;
KEY_PAUSE_RECORD :: 0x272;
KEY_VOD :: 0x273;
KEY_UNMUTE :: 0x274;
KEY_FASTREVERSE :: 0x275;
KEY_SLOWREVERSE :: 0x276;

KEY_DATA :: 0x277;
KEY_ONSCREEN_KEYBOARD :: 0x278;

KEY_PRIVACY_SCREEN_TOGGLE :: 0x279;

KEY_SELECTIVE_SCREENSHOT :: 0x27a;

KEY_NEXT_ELEMENT :: 0x27b;
KEY_PREVIOUS_ELEMENT :: 0x27c;

KEY_AUTOPILOT_ENGAGE_TOGGLE :: 0x27d;

KEY_MARK_WAYPOINT :: 0x27e;
KEY_SOS :: 0x27f;
KEY_NAV_CHART :: 0x280;
KEY_FISHING_CHART :: 0x281;
KEY_SINGLE_RANGE_RADAR :: 0x282;
KEY_DUAL_RANGE_RADAR :: 0x283;
KEY_RADAR_OVERLAY :: 0x284;
KEY_TRADITIONAL_SONAR :: 0x285;
KEY_CLEARVU_SONAR :: 0x286;
KEY_SIDEVU_SONAR :: 0x287;
KEY_NAV_INFO :: 0x288;
KEY_BRIGHTNESS_MENU :: 0x289;

KEY_MACRO1 :: 0x290;
KEY_MACRO2 :: 0x291;
KEY_MACRO3 :: 0x292;
KEY_MACRO4 :: 0x293;
KEY_MACRO5 :: 0x294;
KEY_MACRO6 :: 0x295;
KEY_MACRO7 :: 0x296;
KEY_MACRO8 :: 0x297;
KEY_MACRO9 :: 0x298;
KEY_MACRO10 :: 0x299;
KEY_MACRO11 :: 0x29a;
KEY_MACRO12 :: 0x29b;
KEY_MACRO13 :: 0x29c;
KEY_MACRO14 :: 0x29d;
KEY_MACRO15 :: 0x29e;
KEY_MACRO16 :: 0x29f;
KEY_MACRO17 :: 0x2a0;
KEY_MACRO18 :: 0x2a1;
KEY_MACRO19 :: 0x2a2;
KEY_MACRO20 :: 0x2a3;
KEY_MACRO21 :: 0x2a4;
KEY_MACRO22 :: 0x2a5;
KEY_MACRO23 :: 0x2a6;
KEY_MACRO24 :: 0x2a7;
KEY_MACRO25 :: 0x2a8;
KEY_MACRO26 :: 0x2a9;
KEY_MACRO27 :: 0x2aa;
KEY_MACRO28 :: 0x2ab;
KEY_MACRO29 :: 0x2ac;
KEY_MACRO30 :: 0x2ad;

KEY_MACRO_RECORD_START :: 0x2b0;
KEY_MACRO_RECORD_STOP :: 0x2b1;
KEY_MACRO_PRESET_CYCLE :: 0x2b2;
KEY_MACRO_PRESET1 :: 0x2b3;
KEY_MACRO_PRESET2 :: 0x2b4;
KEY_MACRO_PRESET3 :: 0x2b5;

KEY_KBD_LCD_MENU1 :: 0x2b8;
KEY_KBD_LCD_MENU2 :: 0x2b9;
KEY_KBD_LCD_MENU3 :: 0x2ba;
KEY_KBD_LCD_MENU4 :: 0x2bb;
KEY_KBD_LCD_MENU5 :: 0x2bc;

BTN_TRIGGER_HAPPY :: 0x2c0;
BTN_TRIGGER_HAPPY1 :: 0x2c0;
BTN_TRIGGER_HAPPY2 :: 0x2c1;
BTN_TRIGGER_HAPPY3 :: 0x2c2;
BTN_TRIGGER_HAPPY4 :: 0x2c3;
BTN_TRIGGER_HAPPY5 :: 0x2c4;
BTN_TRIGGER_HAPPY6 :: 0x2c5;
BTN_TRIGGER_HAPPY7 :: 0x2c6;
BTN_TRIGGER_HAPPY8 :: 0x2c7;
BTN_TRIGGER_HAPPY9 :: 0x2c8;
BTN_TRIGGER_HAPPY10 :: 0x2c9;
BTN_TRIGGER_HAPPY11 :: 0x2ca;
BTN_TRIGGER_HAPPY12 :: 0x2cb;
BTN_TRIGGER_HAPPY13 :: 0x2cc;
BTN_TRIGGER_HAPPY14 :: 0x2cd;
BTN_TRIGGER_HAPPY15 :: 0x2ce;
BTN_TRIGGER_HAPPY16 :: 0x2cf;
BTN_TRIGGER_HAPPY17 :: 0x2d0;
BTN_TRIGGER_HAPPY18 :: 0x2d1;
BTN_TRIGGER_HAPPY19 :: 0x2d2;
BTN_TRIGGER_HAPPY20 :: 0x2d3;
BTN_TRIGGER_HAPPY21 :: 0x2d4;
BTN_TRIGGER_HAPPY22 :: 0x2d5;
BTN_TRIGGER_HAPPY23 :: 0x2d6;
BTN_TRIGGER_HAPPY24 :: 0x2d7;
BTN_TRIGGER_HAPPY25 :: 0x2d8;
BTN_TRIGGER_HAPPY26 :: 0x2d9;
BTN_TRIGGER_HAPPY27 :: 0x2da;
BTN_TRIGGER_HAPPY28 :: 0x2db;
BTN_TRIGGER_HAPPY29 :: 0x2dc;
BTN_TRIGGER_HAPPY30 :: 0x2dd;
BTN_TRIGGER_HAPPY31 :: 0x2de;
BTN_TRIGGER_HAPPY32 :: 0x2df;
BTN_TRIGGER_HAPPY33 :: 0x2e0;
BTN_TRIGGER_HAPPY34 :: 0x2e1;
BTN_TRIGGER_HAPPY35 :: 0x2e2;
BTN_TRIGGER_HAPPY36 :: 0x2e3;
BTN_TRIGGER_HAPPY37 :: 0x2e4;
BTN_TRIGGER_HAPPY38 :: 0x2e5;
BTN_TRIGGER_HAPPY39 :: 0x2e6;
BTN_TRIGGER_HAPPY40 :: 0x2e7;

KEY_MIN_INTERESTING :: KEY_MUTE;
KEY_MAX :: 0x2ff;
KEY_CNT :: KEY_MAX+1;

REL_X :: 0x00;
REL_Y :: 0x01;
REL_Z :: 0x02;
REL_RX :: 0x03;
REL_RY :: 0x04;
REL_RZ :: 0x05;
REL_HWHEEL :: 0x06;
REL_DIAL :: 0x07;
REL_WHEEL :: 0x08;
REL_MISC :: 0x09;

REL_RESERVED :: 0x0a;
REL_WHEEL_HI_RES :: 0x0b;
REL_HWHEEL_HI_RES :: 0x0c;
REL_MAX :: 0x0f;
REL_CNT :: REL_MAX+1;

ABS_X :: 0x00;
ABS_Y :: 0x01;
ABS_Z :: 0x02;
ABS_RX :: 0x03;
ABS_RY :: 0x04;
ABS_RZ :: 0x05;
ABS_THROTTLE :: 0x06;
ABS_RUDDER :: 0x07;
ABS_WHEEL :: 0x08;
ABS_GAS :: 0x09;
ABS_BRAKE :: 0x0a;
ABS_HAT0X :: 0x10;
ABS_HAT0Y :: 0x11;
ABS_HAT1X :: 0x12;
ABS_HAT1Y :: 0x13;
ABS_HAT2X :: 0x14;
ABS_HAT2Y :: 0x15;
ABS_HAT3X :: 0x16;
ABS_HAT3Y :: 0x17;
ABS_PRESSURE :: 0x18;
ABS_DISTANCE :: 0x19;
ABS_TILT_X :: 0x1a;
ABS_TILT_Y :: 0x1b;
ABS_TOOL_WIDTH :: 0x1c;

ABS_VOLUME :: 0x20;
ABS_PROFILE :: 0x21;

ABS_MISC :: 0x28;

ABS_RESERVED :: 0x2e;

ABS_MT_SLOT :: 0x2f;
ABS_MT_TOUCH_MAJOR :: 0x30;
ABS_MT_TOUCH_MINOR :: 0x31;
ABS_MT_WIDTH_MAJOR :: 0x32;
ABS_MT_WIDTH_MINOR :: 0x33;
ABS_MT_ORIENTATION :: 0x34;
ABS_MT_POSITION_X :: 0x35;
ABS_MT_POSITION_Y :: 0x36;
ABS_MT_TOOL_TYPE :: 0x37;
ABS_MT_BLOB_ID :: 0x38;
ABS_MT_TRACKING_ID :: 0x39;
ABS_MT_PRESSURE :: 0x3a;
ABS_MT_DISTANCE :: 0x3b;
ABS_MT_TOOL_X :: 0x3c;
ABS_MT_TOOL_Y :: 0x3d;

ABS_MAX :: 0x3f;
ABS_CNT :: ABS_MAX+1;

SW_LID :: 0x00;
SW_TABLET_MODE :: 0x01;
SW_HEADPHONE_INSERT :: 0x02;
SW_RFKILL_ALL :: 0x03;

SW_RADIO :: SW_RFKILL_ALL;
SW_MICROPHONE_INSERT :: 0x04;
SW_DOCK :: 0x05;
SW_LINEOUT_INSERT :: 0x06;
SW_JACK_PHYSICAL_INSERT :: 0x07;
SW_VIDEOOUT_INSERT :: 0x08;
SW_CAMERA_LENS_COVER :: 0x09;
SW_KEYPAD_SLIDE :: 0x0a;
SW_FRONT_PROXIMITY :: 0x0b;
SW_ROTATE_LOCK :: 0x0c;
SW_LINEIN_INSERT :: 0x0d;
SW_MUTE_DEVICE :: 0x0e;
SW_PEN_INSERTED :: 0x0f;
SW_MACHINE_COVER :: 0x10;
SW_MAX :: 0x10;
SW_CNT :: SW_MAX+1;

MSC_SERIAL :: 0x00;
MSC_PULSELED :: 0x01;
MSC_GESTURE :: 0x02;
MSC_RAW :: 0x03;
MSC_SCAN :: 0x04;
MSC_TIMESTAMP :: 0x05;
MSC_MAX :: 0x07;
MSC_CNT :: MSC_MAX+1;

LED_NUML :: 0x00;
LED_CAPSL :: 0x01;
LED_SCROLLL :: 0x02;
LED_COMPOSE :: 0x03;
LED_KANA :: 0x04;
LED_SLEEP :: 0x05;
LED_SUSPEND :: 0x06;
LED_MUTE :: 0x07;
LED_MISC :: 0x08;
LED_MAIL :: 0x09;
LED_CHARGING :: 0x0a;
LED_MAX :: 0x0f;
LED_CNT :: LED_MAX+1;

REP_DELAY :: 0x00;
REP_PERIOD :: 0x01;
REP_MAX :: 0x01;
REP_CNT :: REP_MAX+1;

SND_CLICK :: 0x00;
SND_BELL :: 0x01;
SND_TONE :: 0x02;
SND_MAX :: 0x07;
SND_CNT :: SND_MAX+1;

EV_VERSION :: 0x010001;

INPUT_KEYMAP_BY_INDEX :: 1 << 0;

ID_BUS :: 0;
ID_VENDOR :: 1;
ID_PRODUCT :: 2;
ID_VERSION :: 3;

BUS_PCI :: 0x01;
BUS_ISAPNP :: 0x02;
BUS_USB :: 0x03;
BUS_HIL :: 0x04;
BUS_BLUETOOTH :: 0x05;
BUS_VIRTUAL :: 0x06;

BUS_ISA :: 0x10;
BUS_I8042 :: 0x11;
BUS_XTKBD :: 0x12;
BUS_RS232 :: 0x13;
BUS_GAMEPORT :: 0x14;
BUS_PARPORT :: 0x15;
BUS_AMIGA :: 0x16;
BUS_ADB :: 0x17;
BUS_I2C :: 0x18;
BUS_HOST :: 0x19;
BUS_GSC :: 0x1A;
BUS_ATARI :: 0x1B;
BUS_SPI :: 0x1C;
BUS_RMI :: 0x1D;
BUS_CEC :: 0x1E;
BUS_INTEL_ISHTP :: 0x1F;
BUS_AMD_SFH :: 0x20;

MT_TOOL_FINGER :: 0x00;
MT_TOOL_PEN :: 0x01;
MT_TOOL_PALM :: 0x02;
MT_TOOL_DIAL :: 0x0a;
MT_TOOL_MAX :: 0x0f;

FF_STATUS_STOPPED :: 0x00;
FF_STATUS_PLAYING :: 0x01;
FF_STATUS_MAX :: 0x01;

FF_RUMBLE :: 0x50;
FF_PERIODIC :: 0x51;
FF_CONSTANT :: 0x52;
FF_SPRING :: 0x53;
FF_FRICTION :: 0x54;
FF_DAMPER :: 0x55;
FF_INERTIA :: 0x56;
FF_RAMP :: 0x57;

FF_EFFECT_MIN :: FF_RUMBLE;
FF_EFFECT_MAX :: FF_RAMP;

FF_SQUARE :: 0x58;
FF_TRIANGLE :: 0x59;
FF_SINE :: 0x5a;
FF_SAW_UP :: 0x5b;
FF_SAW_DOWN :: 0x5c;
FF_CUSTOM :: 0x5d;

FF_WAVEFORM_MIN :: FF_SQUARE;
FF_WAVEFORM_MAX :: FF_CUSTOM;

FF_GAIN :: 0x60;
FF_AUTOCENTER :: 0x61;

FF_MAX_EFFECTS :: FF_GAIN;

FF_MAX :: 0x7f;
FF_CNT :: FF_MAX+1;

/*
* The event structure itself
* Note that __USE_TIME_BITS64 is defined by libc based on
* application's request to use 64 bit time_t.
*/
input_event :: struct {
    time:  timeval;

    type:  u16;
    code:  u16;
    value: s32;
}

/*
* IOCTLs (0x00 - 0x7f)
*/
input_id :: struct {
    bustype: u16;
    vendor:  u16;
    product: u16;
    version: u16;
}

/**
* struct input_absinfo - used by EVIOCGABS/EVIOCSABS ioctls
* @value: latest reported value for the axis.
* @minimum: specifies minimum value for the axis.
* @maximum: specifies maximum value for the axis.
* @fuzz: specifies fuzz value that is used to filter noise from
*	the event stream.
* @flat: values that are within this value will be discarded by
*	joydev interface and reported as 0 instead.
* @resolution: specifies resolution for the values reported for
*	the axis.
*
* Note that input core does not clamp reported values to the
* [minimum, maximum] limits, such task is left to userspace.
*
* The default resolution for main axes (ABS_X, ABS_Y, ABS_Z,
* ABS_MT_POSITION_X, ABS_MT_POSITION_Y) is reported in units
* per millimeter (units/mm), resolution for rotational axes
* (ABS_RX, ABS_RY, ABS_RZ) is reported in units per radian.
* The resolution for the size axes (ABS_MT_TOUCH_MAJOR,
* ABS_MT_TOUCH_MINOR, ABS_MT_WIDTH_MAJOR, ABS_MT_WIDTH_MINOR)
* is reported in units per millimeter (units/mm).
* When INPUT_PROP_ACCELEROMETER is set the resolution changes.
* The main axes (ABS_X, ABS_Y, ABS_Z) are then reported in
* units per g (units/g) and in units per degree per second
* (units/deg/s) for rotational axes (ABS_RX, ABS_RY, ABS_RZ).
*/
input_absinfo :: struct {
    value:      s32;
    minimum:    s32;
    maximum:    s32;
    fuzz:       s32;
    flat:       s32;
    resolution: s32;
}

/**
* struct input_keymap_entry - used by EVIOCGKEYCODE/EVIOCSKEYCODE ioctls
* @scancode: scancode represented in machine-endian form.
* @len: length of the scancode that resides in @scancode buffer.
* @index: index in the keymap, may be used instead of scancode
* @flags: allows to specify how kernel should handle the request. For
*	example, setting INPUT_KEYMAP_BY_INDEX flag indicates that kernel
*	should perform lookup in keymap by @index instead of @scancode
* @keycode: key code assigned to this scancode
*
* The structure is used to retrieve and modify keymap data. Users have
* option of performing lookup either by @scancode itself or by @index
* in keymap entry. EVIOCGKEYCODE will also return scancode or index
* (depending on which element was used to perform lookup).
*/
input_keymap_entry :: struct {
    flags:    u8;
    len:      u8;
    index:    u16;
    keycode:  u32;
    scancode: [32] u8;
}

input_mask :: struct {
    type:       u32;
    codes_size: u32;
    codes_ptr:  u64;
}

/**
* struct ff_replay - defines scheduling of the force-feedback effect
* @length: duration of the effect
* @delay: delay before effect should start playing
*/
ff_replay :: struct {
    length: u16;
    delay:  u16;
}

/**
* struct ff_trigger - defines what triggers the force-feedback effect
* @button: number of the button triggering the effect
* @interval: controls how soon the effect can be re-triggered
*/
ff_trigger :: struct {
    button:   u16;
    interval: u16;
}

/**
* struct ff_envelope - generic force-feedback effect envelope
* @attack_length: duration of the attack (ms)
* @attack_level: level at the beginning of the attack
* @fade_length: duration of fade (ms)
* @fade_level: level at the end of fade
*
* The @attack_level and @fade_level are absolute values; when applying
* envelope force-feedback core will convert to positive/negative
* value based on polarity of the default level of the effect.
* Valid range for the attack and fade levels is 0x0000 - 0x7fff
*/
ff_envelope :: struct {
    attack_length: u16;
    attack_level:  u16;
    fade_length:   u16;
    fade_level:    u16;
}

/**
* struct ff_constant_effect - defines parameters of a constant force-feedback effect
* @level: strength of the effect; may be negative
* @envelope: envelope data
*/
ff_constant_effect :: struct {
    level:    s16;
    envelope: ff_envelope;
}

/**
* struct ff_ramp_effect - defines parameters of a ramp force-feedback effect
* @start_level: beginning strength of the effect; may be negative
* @end_level: final strength of the effect; may be negative
* @envelope: envelope data
*/
ff_ramp_effect :: struct {
    start_level: s16;
    end_level:   s16;
    envelope:    ff_envelope;
}

/**
* struct ff_condition_effect - defines a spring or friction force-feedback effect
* @right_saturation: maximum level when joystick moved all way to the right
* @left_saturation: same for the left side
* @right_coeff: controls how fast the force grows when the joystick moves
*	to the right
* @left_coeff: same for the left side
* @deadband: size of the dead zone, where no force is produced
* @center: position of the dead zone
*/
ff_condition_effect :: struct {
    right_saturation: u16;
    left_saturation:  u16;

    right_coeff:      s16;
    left_coeff:       s16;

    deadband:         u16;
    center:           s16;
}

/**
* struct ff_periodic_effect - defines parameters of a periodic force-feedback effect
* @waveform: kind of the effect (wave)
* @period: period of the wave (ms)
* @magnitude: peak value
* @offset: mean value of the wave (roughly)
* @phase: 'horizontal' shift
* @envelope: envelope data
* @custom_len: number of samples (FF_CUSTOM only)
* @custom_data: buffer of samples (FF_CUSTOM only)
*
* Known waveforms - FF_SQUARE, FF_TRIANGLE, FF_SINE, FF_SAW_UP,
* FF_SAW_DOWN, FF_CUSTOM. The exact syntax FF_CUSTOM is undefined
* for the time being as no driver supports it yet.
*
* Note: the data pointed by custom_data is copied by the driver.
* You can therefore dispose of the memory after the upload/update.
*/
ff_periodic_effect :: struct {
    waveform:    u16;
    period:      u16;
    magnitude:   s16;
    offset:      s16;
    phase:       u16;

    envelope:    ff_envelope;

    custom_len:  u32;
    custom_data: *s16;
}

/**
* struct ff_rumble_effect - defines parameters of a periodic force-feedback effect
* @strong_magnitude: magnitude of the heavy motor
* @weak_magnitude: magnitude of the light one
*
* Some rumble pads have two motors of different weight. Strong_magnitude
* represents the magnitude of the vibration generated by the heavy one.
*/
ff_rumble_effect :: struct {
    strong_magnitude: u16;
    weak_magnitude:   u16;
}

/**
* struct ff_effect - defines force feedback effect
* @type: type of the effect (FF_CONSTANT, FF_PERIODIC, FF_RAMP, FF_SPRING,
*	FF_FRICTION, FF_DAMPER, FF_RUMBLE, FF_INERTIA, or FF_CUSTOM)
* @id: an unique id assigned to an effect
* @direction: direction of the effect
* @trigger: trigger conditions (struct ff_trigger)
* @replay: scheduling of the effect (struct ff_replay)
* @u: effect-specific structure (one of ff_constant_effect, ff_ramp_effect,
*	ff_periodic_effect, ff_condition_effect, ff_rumble_effect) further
*	defining effect parameters
*
* This structure is sent through ioctl from the application to the driver.
* To create a new effect application should set its @id to -1; the kernel
* will return assigned @id which can later be used to update or delete
* this effect.
*
* Direction of the effect is encoded as follows:
*	0 deg -> 0x0000 (down)
*	90 deg -> 0x4000 (left)
*	180 deg -> 0x8000 (up)
*	270 deg -> 0xC000 (right)
*/
ff_effect :: struct {
    type:      u16;
    id:        s16;
    direction: u16;
    trigger:   ff_trigger;
    replay:    ff_replay;

    u:         union {
        constant:  ff_constant_effect;
        ramp:      ff_ramp_effect;
        periodic:  ff_periodic_effect;
        condition: [2] ff_condition_effect; /* One for each axis */
        rumble:    ff_rumble_effect;
    };
}

EVIOCGVERSION    :: #run _IOR(#char "E", 0x01, s32);      /* get driver version */
EVIOCGID         :: #run _IOR(#char "E", 0x02, input_id); /* get device ID */
EVIOCGREP        :: #run _IOR(#char "E", 0x03, [2]u32);   /* get repeat settings */
EVIOCSREP        :: #run _IOW(#char "E", 0x03, [2]u32);   /* set repeat settings */

EVIOCGKEYCODE    :: #run _IOR(#char "E", 0x04, [2]u32);   /* get keycode */
EVIOCGKEYCODE_V2 :: #run _IOR(#char "E", 0x04, input_keymap_entry);
EVIOCSKEYCODE    :: #run _IOW(#char "E", 0x04, [2]u32);   /* set keycode */
EVIOCSKEYCODE_V2 :: #run _IOW(#char "E", 0x04, input_keymap_entry);

EVIOCGNAME :: (len: s32) -> u32 #expand { return _IOC(_IOC_READ, #char "E", 0x06, cast(u32)len); } /* get device name */
EVIOCGPHYS :: (len: s32) -> u32 #expand { return _IOC(_IOC_READ, #char "E", 0x07, cast(u32)len); } /* get physical location */
EVIOCGUNIQ :: (len: s32) -> u32 #expand { return _IOC(_IOC_READ, #char "E", 0x08, cast(u32)len); } /* get unique identifier */
EVIOCGPROP :: (len: s32) -> u32 #expand { return _IOC(_IOC_READ, #char "E", 0x09, cast(u32)len); } /* get device properties */

/**
 * EVIOCGMTSLOTS(len) - get MT slot values
 * @len: size of the data buffer in bytes
 *
 * The ioctl buffer argument should be binary equivalent to
 *
 * struct input_mt_request_layout {
 *	__u32 code;
 *	__s32 values[num_slots];
 * };
 *
 * where num_slots is the (arbitrary) number of MT slots to extract.
 *
 * The ioctl size argument (len) is the size of the buffer, which
 * should satisfy len = (num_slots + 1) * sizeof(__s32).  If len is
 * too small to fit all available slots, the first num_slots are
 * returned.
 *
 * Before the call, code is set to the wanted ABS_MT event type. On
 * return, values[] is filled with the slot values for the specified
 * ABS_MT code.
 *
 * If the request code is not an ABS_MT value, -EINVAL is returned.
 */
EVIOCGMTSLOTS :: (len: s32) -> u32 #expand { return _IOC(_IOC_READ, #char "E", 0x0a, cast(u32)len); }

EVIOCGKEY     :: (len: s32) -> u32 #expand { return _IOC(_IOC_READ, #char "E", 0x18, cast(u32)len); } /* get global key state */
EVIOCGLED     :: (len: s32) -> u32 #expand { return _IOC(_IOC_READ, #char "E", 0x19, cast(u32)len); } /* get all LEDs */
EVIOCGSND     :: (len: s32) -> u32 #expand { return _IOC(_IOC_READ, #char "E", 0x1a, cast(u32)len); } /* get all sounds status */
EVIOCGSW      :: (len: s32) -> u32 #expand { return _IOC(_IOC_READ, #char "E", 0x1b, cast(u32)len); } /* get all switch states */

EVIOCGBIT     :: (ev: u32, len: s32) -> u32 #expand { return _IOC(_IOC_READ, #char "E", 0x20 + ev, cast(u32)len); } /* get event bits */
EVIOCGABS     :: (abs: s32)          -> u32 #expand { return _IOR(#char "E", 0x40 + abs, input_absinfo); }          /* get abs value/limits */
EVIOCSABS     :: (abs: s32)          -> u32 #expand { return _IOW(#char "E", 0xc0 + abs, input_absinfo); }          /* set abs value/limits */

EVIOCSFF      :: # run _IOW(#char "E", 0x80, ff_effect); /* send a force effect to a force feedback device */
EVIOCRMFF     :: # run _IOW(#char "E", 0x81, s32      ); /* Erase a force effect */
EVIOCGEFFECTS :: # run _IOR(#char "E", 0x84, s32      ); /* Report number of effects playable at the same time */

EVIOCGRAB     :: # run _IOW(#char "E", 0x90, s32      ); /* Grab/Release device */
EVIOCREVOKE   :: # run _IOW(#char "E", 0x91, s32      ); /* Revoke device access */

/**
 * EVIOCGMASK - Retrieve current event mask
 *
 * This ioctl allows user to retrieve the current event mask for specific
 * event type. The argument must be of type "struct input_mask" and
 * specifies the event type to query, the address of the receive buffer and
 * the size of the receive buffer.
 *
 * The event mask is a per-client mask that specifies which events are
 * forwarded to the client. Each event code is represented by a single bit
 * in the event mask. If the bit is set, the event is passed to the client
 * normally. Otherwise, the event is filtered and will never be queued on
 * the client's receive buffer.
 *
 * Event masks do not affect global state of the input device. They only
 * affect the file descriptor they are applied to.
 *
 * The default event mask for a client has all bits set, i.e. all events
 * are forwarded to the client. If the kernel is queried for an unknown
 * event type or if the receive buffer is larger than the number of
 * event codes known to the kernel, the kernel returns all zeroes for those
 * codes.
 *
 * At maximum, codes_size bytes are copied.
 *
 * This ioctl may fail with ENODEV in case the file is revoked, EFAULT
 * if the receive-buffer points to invalid memory, or EINVAL if the kernel
 * does not implement the ioctl.
 */
EVIOCGMASK :: #run _IOR(#char "E", 0x92, input_mask); /* Get event-masks */

/**
 * EVIOCSMASK - Set event mask
 *
 * This ioctl is the counterpart to EVIOCGMASK. Instead of receiving the
 * current event mask, this changes the client's event mask for a specific
 * type.  See EVIOCGMASK for a description of event-masks and the
 * argument-type.
 *
 * This ioctl provides full forward compatibility. If the passed event type
 * is unknown to the kernel, or if the number of event codes specified in
 * the mask is bigger than what is known to the kernel, the ioctl is still
 * accepted and applied. However, any unknown codes are left untouched and
 * stay cleared. That means, the kernel always filters unknown codes
 * regardless of what the client requests.  If the new mask doesn't cover
 * all known event-codes, all remaining codes are automatically cleared and
 * thus filtered.
 *
 * This ioctl may fail with ENODEV in case the file is revoked. EFAULT is
 * returned if the receive-buffer points to invalid memory. EINVAL is returned
 * if the kernel does not implement the ioctl.
 */
EVIOCSMASK    :: #run _IOW(#char "E", 0x93, input_mask); /* Set event-masks */

EVIOCSCLOCKID :: #run _IOW(#char "E", 0xa0, s32       ); /* Set clockid to be used for timestamps */

