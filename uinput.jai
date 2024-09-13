#load "./input.jai";

//
// This file was auto-generated using the following command:
//
// jai generate.jai
//



UINPUT_VERSION :: 5;
UINPUT_MAX_NAME_SIZE :: 80;

EV_UINPUT :: 0x0101;
UI_FF_UPLOAD :: 1;
UI_FF_ERASE :: 2;

uinput_ff_upload :: struct {
    request_id: u32;
    retval:     s32;
    effect:     ff_effect;
    old:        ff_effect;
}

uinput_ff_erase :: struct {
    request_id: u32;
    retval:     s32;
    effect_id:  u32;
}

uinput_setup :: struct {
    id:             input_id;
    name:           [80] u8;
    ff_effects_max: u32;
}

uinput_abs_setup :: struct {
    code:    u16; /* axis code */

    /* __u16 filler; */
    absinfo: input_absinfo;
}

uinput_user_dev :: struct {
    name:           [80] u8;
    id:             input_id;
    ff_effects_max: u32;
    absmax:         [64] s32;
    absmin:         [64] s32;
    absfuzz:        [64] s32;
    absflat:        [64] s32;
}

#scope_file

