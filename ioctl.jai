//
// This file was auto-generated using the following command:
//
// jai generate.jai
//



_IOC_NRBITS :: 8;
_IOC_TYPEBITS :: 8;

_IOC_SIZEBITS :: 14;

_IOC_DIRBITS :: 2;

_IOC_NRMASK :: (1 << _IOC_NRBITS)-1;
_IOC_TYPEMASK :: (1 << _IOC_TYPEBITS)-1;
_IOC_SIZEMASK :: (1 << _IOC_SIZEBITS)-1;
_IOC_DIRMASK :: (1 << _IOC_DIRBITS)-1;

_IOC_NRSHIFT :: 0;
_IOC_TYPESHIFT :: _IOC_NRSHIFT+_IOC_NRBITS;
_IOC_SIZESHIFT :: _IOC_TYPESHIFT+_IOC_TYPEBITS;
_IOC_DIRSHIFT :: _IOC_SIZESHIFT+_IOC_SIZEBITS;

_IOC_NONE :: 0;

_IOC_WRITE :: 1;

_IOC_READ :: 2;

IOC_IN :: _IOC_WRITE << _IOC_DIRSHIFT;
IOC_OUT :: _IOC_READ << _IOC_DIRSHIFT;
IOC_INOUT :: (_IOC_WRITE|_IOC_READ) << _IOC_DIRSHIFT;
IOCSIZE_MASK :: _IOC_SIZEMASK << _IOC_SIZESHIFT;
IOCSIZE_SHIFT :: _IOC_SIZESHIFT;

_IOC :: (dir: u32, io_type: u32, nr: u32, size: u32) -> u32 #expand {
    result: u32 = (dir           << _IOC_DIRSHIFT)  | 
                  (io_type       << _IOC_TYPESHIFT) |
                  (nr            << _IOC_NRSHIFT)   |
                  (size          << _IOC_SIZESHIFT);
    return result;
}

/*
 * Used to create numbers.
 *
 * NOTE: _IOW means userland is writing and kernel is reading. _IOR
 * means userland is reading and kernel is writing.
 */
_IO :: (io_type: u32, nr: u32) -> u32 #expand {
    return _IOC(_IOC_NONE, io_type, nr, 0);
}

_IOR :: (io_type: u32, nr: u32, $type: Type) -> u32 #expand {
    return _IOC(_IOC_READ, io_type, nr, size_of(type));
}

_IOW :: (io_type: u32, nr: u32, $type: Type) -> u32 #expand {
    return _IOC(_IOC_WRITE, io_type, nr, size_of(type));
}

_IOWR :: (io_type: u32, nr: u32, $type: Type) -> u32 #expand {
    return _IOC(_IOC_READ|_IOC_WRITE, io_type, nr, size_of(type));
}

_IOR_BAD :: (io_type: u32, nr: u32, $type: Type) -> u32 #expand {
    return _IOC(_IOC_READ, io_type, nr, size_of(type));
}

_IOW_BAD :: (io_type: u32, nr: u32, $type: Type) -> u32 #expand {
    return _IOC(_IOC_WRITE, io_type, nr, size_of(type));
}

_IOWR_BAD :: (io_type: u32, nr: u32, $type: Type) -> u32 #expand {
    return _IOC(_IOC_READ|_IOC_WRITE, io_type, nr, size_of(type));
}

/* used to decode ioctl numbers.. */
_IOC_DIR :: (nr: u32) -> u32 #expand {
    return (nr >> _IOC_DIRSHIFT) & _IOC_DIRMASK;
}

_IOC_TYPE :: (nr: u32) -> u32 #expand {
    return (nr >> _IOC_TYPESHIFT) & _IOC_TYPEMASK;
}

_IOC_NR :: (nr: u32) -> u32 #expand {
    return (nr >> _IOC_NRSHIFT) & _IOC_NRMASK;
}

_IOC_SIZE :: (nr: u32) -> u32 #expand {
    return (nr >> _IOC_SIZESHIFT) & _IOC_SIZEMASK;
}

// TCGETS2      :: #run _IOR(#char "T", 0x2A, termios2       );
// TCSETS2      :: #run _IOW(#char "T", 0x2B, termios2       );
// TCSETSW2     :: #run _IOW(#char "T", 0x2C, termios2       );
// TCSETSF2     :: #run _IOW(#char "T", 0x2D, termios2       );
TIOCGPTN     :: #run _IOR(#char "T", 0x30, u32            ); /* Get Pty Number (of pty-mux device) */
TIOCSPTLCK   :: #run _IOW(#char "T", 0x31, s32            );  /* Lock/unlock Pty */
TIOCGDEV     :: #run _IOR(#char "T", 0x32, u32            ); /* Get primary device node of /dev/console */
TIOCSIG      :: #run _IOW(#char "T", 0x36, s32            );  /* pty: generate signal */
TIOCGPKT     :: #run _IOR(#char "T", 0x38, s32            ); /* Get packet mode state */
TIOCGPTLCK   :: #run _IOR(#char "T", 0x39, s32            ); /* Get Pty lock state */
TIOCGEXCL    :: #run _IOR(#char "T", 0x40, s32            ); /* Get exclusive mode state */
TIOCGPTPEER  :: #run _IO( #char "T",  0x41                ); /* Safely open the slave */
// TIOCGISO7816 :: #run _IOR(#char "T", 0x42, serial_iso7816 );
// TIOCSISO7816 :: #run _IOWR(#char "T", 0x43, serial_iso7816);

//
// This file was auto-generated using the following command:
//
// jai generate.jai
//



NCC :: 8;

TIOCM_LE :: 0x001;
TIOCM_DTR :: 0x002;
TIOCM_RTS :: 0x004;
TIOCM_ST :: 0x008;
TIOCM_SR :: 0x010;
TIOCM_CTS :: 0x020;
TIOCM_CAR :: 0x040;
TIOCM_RNG :: 0x080;
TIOCM_DSR :: 0x100;
TIOCM_CD :: TIOCM_CAR;
TIOCM_RI :: TIOCM_RNG;

N_TTY :: 0;
N_SLIP :: 1;
N_MOUSE :: 2;
N_PPP :: 3;
N_STRIP :: 4;
N_AX25 :: 5;
N_X25 :: 6;
N_6PACK :: 7;
N_MASC :: 8;
N_R3964 :: 9;
N_PROFIBUS_FDL :: 10;
N_IRDA :: 11;
N_SMSBLOCK :: 12;
N_HDLC :: 13;
N_SYNC_PPP :: 14;
N_HCI :: 15;

winsize :: struct {
    ws_row:    u16;
    ws_col:    u16;
    ws_xpixel: u16;
    ws_ypixel: u16;
}

termio :: struct {
    c_iflag: u16; /* input mode flags */
    c_oflag: u16; /* output mode flags */
    c_cflag: u16; /* control mode flags */
    c_lflag: u16; /* local mode flags */
    c_line:  u8; /* line discipline */
    c_cc:    [8] u8; /* control characters */
}

#scope_file

