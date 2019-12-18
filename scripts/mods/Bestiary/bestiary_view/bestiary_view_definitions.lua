local mod = get_mod("bestiary")

local scenegraph_definition = {
    background = {
        vertical_alignment = "center",
        horizontal_alignment = "center",
        scale = "fit",
        position = { 0, 0, UILayer.ingame_player_list },
        size = { 1920, 1080 }
    }
}

local viewport_definition = {
    scenegraph_id = "background",
    element = UIElements.Viewport,
    style = {
        viewport = {
            scenegraph_id = "background",
            viewport_name = "bestiary_viewport",
            level_name = "levels/ui_keep_menu/world",
            fov = 78,
            world_name = "bestiary_world",
            world_flags = {
                Application.DISABLE_SOUND
            },
            layer = UILayer.ingame_player_list,
            camera_position = { 0, 2.5, 0.8 },
            camera_lookat = { 0, 0, 0.9 }
        }
    },
    content = {
        button_hotspot = {
            allow_multi_hover = true
        }
    }
}

return {
    scenegraph_definition = scenegraph_definition,
    viewport_definition = viewport_definition
}