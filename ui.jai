/*

This is our wrapper around some GetRect widgets to support stuff like pulsating and support need_to_rerender in our program state

*/
our_button :: (r: GR.Rect, text: string, theme: *GR.Button_Theme = null, identifier: s64 = 0, loc := #caller_location, texture: *Texture = null, disable_over := false, disable_press := false, pulsate := false) -> (was_just_pressed: bool, state: *GR.Button_State, was_just_released: bool) {
    using current_program_state;

    was_just_pressed, state, was_just_released := GR.button(r, text, theme, identifier, loc, texture, disable_over, disable_press);

    if pulsate {
        need_to_rerender = true;
        GR.update_production_value_button(r, false, state, .OVER, theme);
    }

    if state.over_factor || state.pressed_factor {
        need_to_rerender = true;
    }
    return was_just_pressed, state, was_just_released;
}

arrow :: (base_rect: GR.Rect, state: *GR.Dropdown_State, theme: *GR.Dropdown_Theme, mapping_mode: Mapping_Mode) {
    using current_program_state;

    r := base_rect;
    dropdown_button_state := state.current_value_state;
    dropdown_button_theme := theme.theme_for_current_value;

    over_factor := dropdown_button_state.over_factor;
    down_effect_t := dropdown_button_state.down_effect_t;
    pressed_factor := dropdown_button_state.pressed_factor;
    if over_factor || down_effect_t || pressed_factor {
        need_to_rerender = true;
    }

    // Logic from button to make the arrow pulsate and flash
    base_color := dropdown_button_theme.surface_color;
    base_color = lerp(base_color, dropdown_button_theme.surface_color_over,  over_factor);
    base_color = lerp(base_color, dropdown_button_theme.surface_color_down,  down_effect_t);
    base_color = lerp(base_color, dropdown_button_theme.surface_color_flash, pressed_factor);

    Simp.immediate_quad(
        r.x , r.y,
        r.x + r.w , r.y + r.h,
        base_color,
    );

    color := my_theme.button_theme.frame_color;
    color = lerp(color, dropdown_button_theme.frame_color_over,  over_factor);
    color = lerp(color, dropdown_button_theme.frame_color_down,  down_effect_t);
    color = lerp(color, dropdown_button_theme.frame_color_flash, pressed_factor);

    base_h := r.h/2;
    base_y := r.y + base_h/2;
    base_x := r.x;

    arrow_width := r.w * 0.25;
    if mapping_mode == .OPPOSITE {
        Simp.immediate_triangle(
                .{base_x + arrow_width, base_y,            0},
                .{base_x              , base_y + base_h/2, 0},
                .{base_x + arrow_width, base_y + base_h,   0},
            color,
            color,
            color,
        );

        base_x = base_x + arrow_width;
        r.w = r.w - 2 * arrow_width;
    }

    if mapping_mode == .REMAP {
        r.w = r.w - arrow_width;
    }

    Simp.immediate_quad(
        base_x            , base_y + base_h/3,
        base_x + r.w , base_y + base_h/1.5,
        color,
    );

    if mapping_mode == .REMAP || mapping_mode == .OPPOSITE {
        Simp.immediate_triangle(
                .{base_x + r.w,               base_y           , 0},
                .{base_x + r.w + arrow_width, base_y + base_h/2, 0},
                .{base_x + r.w,               base_y + base_h  , 0},
            color,
            color,
            color,
        );
    }
}

our_checkbox :: (_r: Rect, text: string, selected: bool, theme: *Checkbox_Theme = null, identifier: s64 = 0, loc := #caller_location) -> changed: bool, checkbox_state: Checkbox_State {
    using current_program_state;

    changed, state := GR.base_checkbox(_r, text, selected, theme, identifier, loc);
    if state.base.action_duration_2 != -1 {
        need_to_rerender = true;
    }

    return changed, state;
}

our_dropdown :: (r: Rect, choices: [] string, current_value_pointer: *s32, theme: *Dropdown_Theme = null, disable_press := false, identifier: s64 = 0, z: s32 = 100, loc := #caller_location) -> changed: bool, Dropdown_State {
    if !theme  theme = *default_overall_theme.dropdown_theme;

    // r just describes the Rect for the top of the dropdown.
    // The individual elements below are sized according to theme.button_theme.

    // Draw the background behind the primary choice.

    label_current_value := theme.theme_for_current_value.label_theme;

    // Let's avoid an ABC in case the user passes us a dirty value.
    current_string := "";
    current_value := current_value_pointer.*;
    if (current_value >= 0) && (current_value < choices.count) {
        current_string = choices[current_value];
    }

    hash   := get_hash(loc, identifier);
    state  := find_or_create_state(Dropdown_State, hash);
    if state.original_value < 0 {
        state.original_value = current_value;
    }
    defer {
        GR.stop_using_state(state);
        state.last_getrect_frame -= 1;  // @Hack because we don't have a separate state rect for the popup. @Incomplete!
    }


    // Carve off the dropdown indicator from the rest of the button.
    indicator_width := theme.dropdown_indicator_aspect_ratio * r.h;
    r_right, r_left := cut_right(r, indicator_width);

    current := theme.theme_for_current_value;
    pressed, current_value_state := button(r, current_string, *current, identifier, loc, disable_press=disable_press);
    if theme.theme_for_current_value.rectangle_shape.rounding_flags & (.NORTHEAST | .SOUTHEAST) {
        current.rectangle_shape.rounding_flags = Rectangle_Shape.Rounding_Flags.NORTHEAST | .SOUTHEAST;
    }
    state.status = current_value_state.status;

    // Background rectangle for the arrow, so that the button label doesn't clip into it.
    // Alternatively, we could've drawn the arrow right on the button if a button label
    // had a separate rect that we could set on a button?
    surface_color, frame_color, frame_thickness := get_colors_and_thickness_for_button(*current, current_value_state);
    rounded_rectangle(r_right, current.rectangle_shape, surface_color, frame_color, frame_thickness_override = frame_thickness);

    if pressed {
        state.open = !state.open;
        if state.open active_widget_add   (state);
        else          active_widget_remove(state);
    }


    triangle_margin := r_right.w * 0.1;

    //
    // Update open_t for drawing arrows, etc.
    //

    dt := GR.current_dt;
    if state.open {
        state.open_t = GR.move_toward(state.open_t, 1, dt * theme.arrow_flip_up_rate);
    } else {
        state.open_t = GR.move_toward(state.open_t, 0, dt * theme.arrow_flip_down_rate);
    }

    //
    // Draw the dropdown arrow.
    //
    draw_procs.set_shader_for_color();
    {
        p0, p1, p2, p3 := get_quad(r_right);
        p4 := to_vec3(lerp(p2, p3, .5));
        p4.y -= triangle_margin;
        p5 := to_vec3(p1);
        p5.x -= triangle_margin;
        p5.y += triangle_margin;
        p6 := to_vec3(p0);
        p6.x += triangle_margin;
        p6.y += triangle_margin;

        p5 = lerp(p5, p4, .6);
        p6 = lerp(p6, p4, .6);

        k := 2.3*triangle_margin;
        p4.y -= k;
        p5.y -= k;
        p6.y -= k;

        if state.open_t {
            theta := -cast(float)(state.open_t * TAU * .25);
            barycenter := (p4 + p5 + p6) * (1 / 3.0);

            p4 -= barycenter;
            p5 -= barycenter;
            p6 -= barycenter;

            p4.xy = rotate(p4.xy, theta);
            p5.xy = rotate(p5.xy, theta);
            p6.xy = rotate(p6.xy, theta);

            p4 += barycenter;
            p5 += barycenter;
            p6 += barycenter;
        }

        draw_arrow(current_value_state, p4, p5, p6, *theme.theme_for_current_value);
    }

    state.hash                  = hash;
    state.loc                   = loc;
    state.current_value_pointer = current_value_pointer;
    state.current_value_state   = current_value_state;
    if state.open {
        state.base_rect             = r;
        state.choices               = choices;
        state.theme                 = theme.*;
        state.z                     = z;
    }

    GR.add_popup(draw_dropdown_popup, state, state.z);
    changed := current_value_pointer.* != state.original_value;
    if changed {
        state.original_value = current_value_pointer.*;
    }
    return changed, state;
}

#scope_file

GR :: #import "GetRect_LeftHanded";
#import "Simp";
