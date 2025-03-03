#module_parameters(DUMP_GL_ERRORS := false);

#load "./egl.jai";
#load "./gl.jai";

using egl_procs: EGL_Procs;
using egl_ext_procs: EGL_Ext_Procs;
using gl_procs: GL_Procs;
using gl_ext_procs: GL_Ext_Procs;

supported_extensions_populated := false;
GL_Available_Extensions :: Table(string, bool);
gl_available_extensions: GL_Available_Extensions;

populate_supported_extensions :: () {
    display: EGLDisplay = eglGetDisplay(xx EGL_DEFAULT_DISPLAY);
    // print("display:%\n", display);
    init := eglInitialize(display, null, null);
    // print("init:%\n", init);

    total_configs: s32;
    // eglGetConfigs(display, null, 0, *total_configs);
    // print("Total configs: %\n", total_configs);

    config_attribs: []EGLint = .[
        EGL_CONFORMANT, EGL_OPENGL_BIT,
        EGL_NONE,
    ];
    config: EGLConfig;
    num_configs: EGLint;
    choose := eglChooseConfig(display, config_attribs.data, *config, 1, *num_configs);
    // print("num: %, choose_res: %, config:%\n", num_configs,  choose, config);

    // TODO: This hardcodes desktop opengl
    // EGL GLES doesn't need to do this (and actually shoudln't)
    // Same with EGL_OPENGL_BIT above in config_attribs.
    ok := eglBindAPI(EGL_OPENGL_API);
    assert(xx ok, "Failed to select OpenGL API for EGL");

    context_: EGLContext  = eglCreateContext(display, config, xx EGL_NO_CONTEXT, null);
    // print("context:%\n", context_);
    result := eglMakeCurrent(display, xx EGL_NO_SURFACE, xx EGL_NO_SURFACE, context_);
    // print("res: %\n", result);

    // The NG way
    num: s32;
    glGetIntegerv(GL_NUM_EXTENSIONS, *num);
    if !num {
        // Fall back to the OG way
        extensions := glGetString(GL_EXTENSIONS);
        // print("ext_raw: %\n", extensions);
        if extensions {
            extensions_str := to_string(extensions);
            splitted := split(extensions_str, " ");

            for splitted {
                table_set(*gl_available_extensions, it, true);
                // print("%\n", it);
            }
        }

    } else {
        for 0..num-1 {
            ext:= to_string(glGetStringi(GL_EXTENSIONS, xx it));
            table_set(*gl_available_extensions, ext, true);
            // print("%\n", ext);
        }
    }

    egl_display_extensions := split(to_string(eglQueryString(display, EGL_EXTENSIONS)), " ",, temp);
    for egl_display_extensions {
        table_set(*gl_available_extensions, it, true);
    }

    egl_client_extensions := split(to_string(eglQueryString(xx EGL_NO_DISPLAY, EGL_EXTENSIONS)), " ",, temp);
    for egl_client_extensions {
        table_set(*gl_available_extensions, it, true);
    }

    eglDestroyContext(display, context_);
    eglTerminate(display);
    supported_extensions_populated = true;
}

loader_call :: #type (name: *u8) -> *void #c_call;
generic_c_call :: #type () #c_call;
loader_proc: loader_call;
load_procs :: (procs: *$T, libname: string) -> success := false {
    lib := dlopen(temp_c_string(libname), RTLD_NOW);
    if !lib {
        log_error("Failed to load %: %", libname, to_string(dlerror()));
        return false;
    }

    tis := cast(*Type_Info_Struct) type_info(T);
    for m : tis.members {
        notes := m.notes;

        if m.type.type == .POINTER {
            // Core/Compatibility procedures
            pi := cast(*Type_Info_Procedure) m.type;
            ppfn := cast(*generic_c_call)((cast(*u8) procs) + m.offset_in_bytes);
            if m.notes && array_find(m.notes, "gl_loader") {
                ppfn := cast(*loader_call)((cast(*u8) procs) + m.offset_in_bytes);
                ppfn.* = cast(loader_call) dlsym(lib, m.name.data);
                loader_proc = ppfn.*;
            } else {
                ppfn.* = cast(generic_c_call) loader_proc(m.name.data);
            }
            assert(!!(ppfn.*), "Failed to resolve function '%': %", m.name, to_string(dlerror()));
        }
    }

    return true;
}

load_extensions :: (procs: *$T) -> success := false  {
    if !supported_extensions_populated {
        populate_supported_extensions();
    }
    ti_ext := cast(*Type_Info_Struct) type_info(T);
    for m: ti_ext.members {
        if m.type.type == .BOOL {
            _, ext_found := table_find(*gl_available_extensions, m.name);
            ti := m.type;
            is_avail_ptr := cast(*bool)((cast(*u8)procs) + m.offset_in_bytes);
            is_avail_ptr.* = ext_found;
            if !ext_found {
                print("% is NO Tavailable\n", m.name);
                return false;
            }
            print("% is available\n", m.name);
        } else if m.type.type == .POINTER {
            pi := cast(*Type_Info_Procedure) m.type;
            ppfn := cast(*type_of(pi))((cast(*u8) procs) + m.offset_in_bytes);
            ppfn.* = xx loader_proc(m.name.data);
        }
    }

    return true;
}


gl_load :: () -> bool {
    result := true;
    result = load_procs(*egl_procs, "libEGL.so");
    if !result return result;
    result = load_procs(*gl_procs, "libGL.so");
    if !result return result;
    result = load_extensions(*egl_ext_procs);
    if !result return result;
    result = load_extensions(*gl_ext_procs);
    if !result return result;

    return result;
}


gl_create_context :: (display: *void, window: u64, major_version: s32, minor_version: s32, wanted_msaa: s32) -> EGLDisplay, EGLSurface, EGLContext, EGLConfig, chosen_msaa: s32 {
    gl_load();

    display: EGLDisplay;
    config: EGLConfig;
    egl_context: EGLContext;
    surface: EGLSurface;

    attrib_list: []EGLint = .[
        EGL_PLATFORM_XCB_SCREEN_EXT,
        0, // This is a screenp that you can get from 2nd argument of xcb_connect
        EGL_NONE,
    ];

    {
        display = eglGetPlatformDisplayEXT(
            EGL_PLATFORM_XCB_EXT,
            display,
            attrib_list.data,
        );
        assert(xx display != EGL_NO_DISPLAY, "Failed to get EGL display");

        major, minor: EGLint;

        if (!eglInitialize(display, *major, *minor)) {
            log_error("Cannot initialize EGL display\n");
            return display, surface, egl_context, config, wanted_msaa;
        }
        if (major < 1 || (major == 1 && minor < 5)) {
            log_error("EGL version 1.5 or higher required\n");
            return display, surface, egl_context, config, wanted_msaa;
        }
    }

    // Choose OpenGL API for EGL, by default it uses OpenGL ES
    ok := eglBindAPI(EGL_OPENGL_API);
    assert(xx ok, "Failed to select OpenGL API for EGL");

    // Choose Config
    attempted_msaa := wanted_msaa;
    {
        attr: []EGLint = .[
            EGL_SURFACE_TYPE,      EGL_WINDOW_BIT,
            EGL_CONFORMANT,        EGL_OPENGL_BIT,
            EGL_RENDERABLE_TYPE,   EGL_OPENGL_BIT,
            EGL_COLOR_BUFFER_TYPE, EGL_RGB_BUFFER,

            EGL_RED_SIZE,      8,
            EGL_GREEN_SIZE,    8,
            EGL_BLUE_SIZE,     8,
            EGL_DEPTH_SIZE,   24,
            EGL_STENCIL_SIZE,  8,

            EGL_SAMPLE_BUFFERS, xx !!attempted_msaa,
            EGL_SAMPLES,        attempted_msaa,

            EGL_NONE,
        ];

        count: EGLint;
        if (!eglChooseConfig(display, attr.data, *config, 1, *count) || count != 1)
        {
            log_error("Cannot choose EGL config\n");
        }
    }

    // Create EGL surface
    {
        attr: []EGLint = .[
            EGL_GL_COLORSPACE, EGL_GL_COLORSPACE_LINEAR, // or use EGL_GL_COLORSPACE_SRGB for sRGB framebuffer
            EGL_RENDER_BUFFER, EGL_BACK_BUFFER,
            EGL_NONE,
        ];

        surface = eglCreateWindowSurface(display, config, window, attr.data);
        if (xx surface == EGL_NO_SURFACE) {
            log_error("Cannot create EGL surface\n");
        }
    }

    // Create EGL context
    {
        attr: []EGLint = .[
            EGL_CONTEXT_MAJOR_VERSION, major_version,
            EGL_CONTEXT_MINOR_VERSION, minor_version,
            EGL_CONTEXT_OPENGL_PROFILE_MASK, EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT,

            // Ask for debug context for non "Release" builds
            // this is so we can enable debug callback
            EGL_CONTEXT_OPENGL_DEBUG, EGL_TRUE,
            EGL_NONE,
        ];

        egl_context = eglCreateContext(display, config, xx EGL_NO_CONTEXT, attr.data);
        if (xx egl_context == EGL_NO_CONTEXT)
        {
            log_error("Cannot create EGL context, OpenGL 4.5 not supported?\n");
            return display, surface, egl_context, config, wanted_msaa;
        }
    }

    return display, surface, egl_context, config, wanted_msaa;
}


#if DUMP_GL_ERRORS {
    DumpGLErrors :: (tag: string, loc := #caller_location) -> bool {
        had_error := false;

        if glGetDebugMessageLogARB {
            while true {
                Source, Type, ID: GLuint;
                Length: GLint;

                BUFFER_SIZE :: 4096;
                Buffer: [BUFFER_SIZE] u8;
                Severity: GLenum;

                if glGetDebugMessageLogARB(1, size_of(type_of(Buffer)), xx *Source, xx *Type, *ID, *Severity, xx *Length, Buffer.data) {
                    GL_DEBUG_TYPE_ERROR_ARB :: 0x824C;
                    HIGH   :: 0x9146;
                    MEDIUM :: 0x9147;
                    //                if Type == GL_DEBUG_TYPE_ERROR_ARB {
                    if (Severity == MEDIUM) || (Severity == HIGH) {
                        s: string;
                        s.count = Length-1;  // The Length includes a terminating 0, apparently.
                        s.data = Buffer.data;

                        log("[%] %:%: %\n", tag, loc.fully_pathed_filename, loc.line_number, s);

                        // @@ Is there a way to print this only if the above function is not filtered? Tag print line to also include trace?
                        //trace : []string = Debug.backtrace();
                        //defer Debug.free_backtrace(trace);
                        //for trace { print("    %", it); if it_index > 4 break; }

                        had_error = true;
                    }
                } else {
                    break;
                }
            }
        } else {
            while true {
                error := glGetError();
                if error == GL_NO_ERROR break;

                had_error = true;
                log("[%] %:%: GL error 0x%\n", tag, loc.fully_pathed_filename, loc.line_number, formatInt(error, base = 16, minimum_digits = 4));
            }
        }

        return had_error;
    }
} else {
    DumpGLErrors :: inline (#discard tag: string, #discard loc := #caller_location) -> bool {
        return false;  // @Hack
    }
}

#scope_file

is_debug_context : bool;

get_string_for_type :: (type: GLenum) -> string {
    if (type == GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR_ARB) return "deprecated behavior";
    if (type == GL_DEBUG_TYPE_ERROR_ARB) return "error";
    if (type == GL_DEBUG_TYPE_OTHER_ARB) return "other";
    if (type == GL_DEBUG_TYPE_PERFORMANCE_ARB) return "performance";
    if (type == GL_DEBUG_TYPE_PORTABILITY_ARB) return "portability";
    if (type == GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR_ARB) return "undefined behavior";
    return "unknown";
}
get_string_for_source :: (source: GLenum) -> string{
    if (source == GL_DEBUG_SOURCE_API_ARB) return "API";
    if (source == GL_DEBUG_SOURCE_APPLICATION_ARB) return "application";
    if (source == GL_DEBUG_SOURCE_OTHER_ARB) return "other";
    if (source == GL_DEBUG_SOURCE_SHADER_COMPILER_ARB) return "shader compiler";
    if (source == GL_DEBUG_SOURCE_THIRD_PARTY_ARB) return "third party";
    if (source == GL_DEBUG_SOURCE_WINDOW_SYSTEM_ARB) return "window system";
    return "unknown";
}
get_string_for_severity :: (severity: GLenum) -> string {
    if (severity == GL_DEBUG_SEVERITY_HIGH_ARB) return "high";
    if (severity == GL_DEBUG_SEVERITY_MEDIUM_ARB) return "medium";
    if (severity == GL_DEBUG_SEVERITY_LOW_ARB) return "low";
    return "unknown";
}


debug_log_params : struct {
    break_on_error: bool;
    logger: Logger;
};

gl_debug_log :: (source: GLenum, type: GLenum, id: GLuint, severity: GLenum, length: GLsizei, message: *u8, userParam: *void) #c_call {
    TEMPORARY_STORAGE_SIZE :: 1000;
    storage_buf: [TEMPORARY_STORAGE_SIZE] u8;

    storage: Temporary_Storage;
    storage.data = storage_buf.data;
    storage.size = TEMPORARY_STORAGE_SIZE;

    new_context: #Context;
    new_context.temporary_storage = *storage;
    new_context.logger = debug_log_params.logger;

    push_context new_context {
        assert(userParam == *debug_log_params);

        // Ignore application and 'other' messages.
        if (source != GL_DEBUG_SOURCE_APPLICATION_ARB && type != GL_DEBUG_TYPE_OTHER_ARB && type != GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR_ARB) {
            log("OGL: type = %; source = %; id = %; severity = %", get_string_for_type(type), get_string_for_source(source), id, get_string_for_severity(severity));
            log("OGL: message = %", to_string(message));
        }
        if debug_log_params.break_on_error {
            //if (type == GL_DEBUG_TYPE_ERROR_ARB) Debug.breakpoint();
            if (type == GL_DEBUG_TYPE_ERROR_ARB) debug_break();
        }
    }
}

#scope_export

gl_enable_debug_output :: (break_on_error: bool = false) {
    debug_log_params.break_on_error = break_on_error;
    debug_log_params.logger         = context.logger;

    if #exists(GL_VERSION_4_3) {
        if break_on_error glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
        glDebugMessageCallback(gl_debug_log, *debug_log_params);
    } else if GL_ARB_debug_output {
        if break_on_error glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS_ARB);
        glDebugMessageCallbackARB(gl_debug_log, *debug_log_params);
    }
}


#scope_file

#import "Basic";
#import "Hash_Table";
#import "String";
#import "POSIX";
