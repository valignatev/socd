/*

This is our wrapper around some GetRect widgets to support stuff like pulsating and support need_to_rerender in our program state

*/
our_button :: (r: GR.Rect, text: string, theme: *GR.Button_Theme = null, identifier: s64 = 0, loc := #caller_location, texture: *Texture = null, disable_over := false, disable_press := false, pulsate := false) -> (was_just_pressed: bool, state: *GR.Button_State, was_just_released: bool) {
    using current_program_state;

    was_just_pressed, state, was_just_released := GR.button(r, text, theme, identifier, loc, texture, disable_over, disable_press);

    if pulsate {
        need_to_rerender = true;
        // GR.update_production_value_button(r, false, state, .OVER, *pulsating_button_theme);
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

#scope_file

GR :: #import "GetRect_LeftHanded";
#import "Simp";
