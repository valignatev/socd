build :: () {
    w := compiler_create_workspace("Target Program");
    if !w {
        print("Workspace creation failed\n");
        return;
    }

    target_options := get_build_options(w);

    target_options.output_executable_name = "hitboxer";
    target_options.backend = .X64;
    set_build_options(target_options, w);

    set_build_options_dc(.{do_output=false});

    compiler_begin_intercept(w);
    add_build_file("./main.jai", w);

    while true {
        message := compiler_wait_for_message();
        if message.kind == .COMPLETE break;
    }

    compiler_end_intercept(w);

    #if OS == .WINDOWS {
        #import "Windows_Resources";
        exe_name := sprint("%.exe", target_options.output_executable_name);
        defer free(exe_name);

        success := set_icon_by_filename(exe_name, "icon.ico");
        if !success {
            log_error(
                "Failed to set the icon for exe '%' to filename '%'.\n",
                exe_name, "icon.ico",
            );
        }
        manifest_options: Manifest_Options;
        success = add_manifest_to_executable(exe_name, manifest_options);
        if !success {
            log_error("Couldn't add the manifest to the executable %\n", exe_name);
        }
    }
}

#run build();

#import "Basic";
#import "Compiler";
