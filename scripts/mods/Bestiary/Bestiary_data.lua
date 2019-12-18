local mod = get_mod("bestiary")

return {
	name = "Bestiary",
	description = mod:localize("bestiary_description"),

    options = {
        widgets = {
            {
                setting_id = "remember_customizations",
                type = "checkbox",
                default_value = false
            },
            {
                setting_id = "open_bestiary_view",
                type = "keybind",
                default_value = {},
                keybind_global = false,
                keybind_trigger = "pressed",
                keybind_type = "view_toggle",
                view_name = "bestiary_view",
                transition_data = {
                    open_view_transition_name = "open_bestiary_view",

                    close_view_transition_name = "close_bestiary_view",

                    transition_fade = true
                },
            }
        },
    },

    custom_gui_textures = {
        textures = {
            "gui/bestiary/bestiary_atlas"
        },
        atlases = {
            {
                "materials/bestiary/bestiary_atlas",
                "bestiary_atlas",
                "bestiary_atlas_masked"
            }
        },
        ui_renderer_injections = {
            {
                "ingame_ui",
                "materials/bestiary/bestiary_atlas",
            },
        },
    },

}