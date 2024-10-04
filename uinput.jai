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

UINPUT_IOCTL_BASE :: #char "U";

UI_DEV_CREATE :: #run _IO(UINPUT_IOCTL_BASE, 1);
UI_DEV_DESTROY :: #run _IO(UINPUT_IOCTL_BASE, 2);

/**
 * UI_DEV_SETUP - Set device parameters for setup
 *
 * This ioctl sets parameters for the input device to be created.  It
 * supersedes the old "struct uinput_user_dev" method, which wrote this data
 * via write(). To actually set the absolute axes UI_ABS_SETUP should be
 * used.
 *
 * The ioctl takes a "struct uinput_setup" object as argument. The fields of
 * this object are as follows:
 *              id: See the description of "struct input_id". This field is
 *                  copied unchanged into the new device.
 *            name: This is used unchanged as name for the new device.
 *  ff_effects_max: This limits the maximum numbers of force-feedback effects.
 *                  See below for a description of FF with uinput.
 *
 * This ioctl can be called multiple times and will overwrite previous values.
 * If this ioctl fails with -EINVAL, it is recommended to use the old
 * "uinput_user_dev" method via write() as a fallback, in case you run on an
 * old kernel that does not support this ioctl.
 *
 * This ioctl may fail with -EINVAL if it is not supported or if you passed
 * incorrect values, -ENOMEM if the kernel runs out of memory or -EFAULT if the
 * passed uinput_setup object cannot be read/written.
 * If this call fails, partial data may have already been applied to the
 * internal device.
 */
UI_DEV_SETUP :: #run _IOW(UINPUT_IOCTL_BASE, 3, uinput_setup);


UI_SET_EVBIT ::   #run _IOW(UINPUT_IOCTL_BASE, 100, s32);
UI_SET_KEYBIT ::  #run _IOW(UINPUT_IOCTL_BASE, 101, s32);
UI_SET_RELBIT ::  #run _IOW(UINPUT_IOCTL_BASE, 102, s32);
UI_SET_ABSBIT ::  #run _IOW(UINPUT_IOCTL_BASE, 103, s32);
UI_SET_MSCBIT ::  #run _IOW(UINPUT_IOCTL_BASE, 104, s32);
UI_SET_LEDBIT ::  #run _IOW(UINPUT_IOCTL_BASE, 105, s32);
UI_SET_SNDBIT ::  #run _IOW(UINPUT_IOCTL_BASE, 106, s32);
UI_SET_FFBIT ::   #run _IOW(UINPUT_IOCTL_BASE, 107, s32);
UI_SET_PHYS  ::   #run _IOW(UINPUT_IOCTL_BASE, 108, *u8);
UI_SET_SWBIT ::   #run _IOW(UINPUT_IOCTL_BASE, 109, s32);
UI_SET_PROPBIT :: #run _IOW(UINPUT_IOCTL_BASE, 110, s32);

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

