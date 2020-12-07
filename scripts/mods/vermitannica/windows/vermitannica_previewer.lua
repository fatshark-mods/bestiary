local mod = get_mod("vermitannica")

local DEFAULT_ANGLE = -math.degrees_to_radians(45)
local stop_animating = false

local hero_spawn_home = Vector3Box(1.25, 0, 0)
local enemy_spawn_home = Vector3Box(-1.25, 0, 0)
local browser_camera_pan_ranges = {
    hero_browser = {
        x = {
            min = -0.50,
            max = 0.25
        },
        z = {
            min = -1.00,
            max = 0.75
        }
    },
    enemy_browser = {
        x = {
            min = -0.75,
            max = 0.75
        },
        z = {
            min = -1.25,
            max = 0.75
        }
    }
}

local camera_position_by_character = {
    witch_hunter = {
        z = 0.8,
        x = 0,
        y = 0.8
    },
    bright_wizard = {
        z = 0.8,
        x = 0,
        y = 0.6
    },
    dwarf_ranger = {
        z = 0.8,
        x = 0,
        y = 0.4
    },
    wood_elf = {
        z = 0.8,
        x = 0,
        y = 0.5
    },
    empire_soldier = {
        z = 0.8,
        x = 0,
        y = 0.7
    }
}

VermitannicaPreviewer = class(VermitannicaPreviewer)
VermitannicaPreviewer.NAME = "VermitannicaPreviewer"

function VermitannicaPreviewer:init()

    local equipment_units_data = {}
    equipment_units_data[InventorySettings.slots_by_name.slot_melee] = {}
    equipment_units_data[InventorySettings.slots_by_name.slot_ranged] = {}
    equipment_units_data[InventorySettings.slots_by_name.slot_skin] = {}
    equipment_units_data[InventorySettings.slots_by_name.slot_hat] = {}

    self._hero_unit_data = {
        hero_unit = nil,
        equipment_units_data = equipment_units_data
    }

    self._enemy_unit_data = {
        enemy_unit = nil,
        equipment_units_data = {}
    }

    self._default_look_target = { x = 0, y = 0, z = 0.9 }
    self._default_animation_data = {
        x = {
            value = 0
        },
        y = {
            value = 0
        },
        z = {
            value = 0
        }
    }
    self._camera_position_animation_data = table.clone(self._default_animation_data)

end

VermitannicaPreviewer.init = function (self, ingame_ui_context, optional_camera_character_positions, unique_id)
    self.profile_synchronizer = ingame_ui_context.profile_synchronizer
    self.input_manager = ingame_ui_context.input_manager
    self.ui_renderer = ingame_ui_context.ui_renderer
    self._item_info_by_slot = {}
    self.hero_unit = nil
    self._hero_camera_positions = optional_camera_character_positions or camera_position_by_character
    self._hero_equipment_units = {}
    self._hero_equipment_units[InventorySettings.slots_by_name.slot_melee.slot_index] = {}
    self._hero_equipment_units[InventorySettings.slots_by_name.slot_ranged.slot_index] = {}
    self.enemy_unit = nil
    self.enemy_weapon_units = {}
    self._hidden_units = {}
    self._hero_equipment_units_data = {}
    self._hero_equipment_units_data[InventorySettings.slots_by_name.slot_melee.slot_index] = {}
    self._hero_equipment_units_data[InventorySettings.slots_by_name.slot_ranged.slot_index] = {}
    self._requested_mip_streaming_units = {}
    local player_manager = Managers.player
    self.player_manager = player_manager
    self.peer_id = ingame_ui_context.peer_id
    self.unique_id = unique_id

    self._default_look_target = { x = 0, y = 0, z = 0.9 }

    self._camera_default_position = { x = 0, y = 0, z = 0 }
    self._unit_browser_positions = {
        hero_browser = { 0, 0, 0 },
        enemy_browser = { 0, 0, 0 }
    }

    self._default_animation_data = {
        x = {
            value = 0
        },
        y = {
            value = 0
        },
        z = {
            value = 0
        }
    }
    self._camera_position_animation_data = table.clone(self._default_animation_data)
    self._camera_rotation_animation_data = table.clone(self._default_animation_data)
    self._camera_gamepad_offset_data = { 0, 0, 0 }

    self:_load_packages({"resource_packages/inventory"})
end

VermitannicaPreviewer.destroy = function (self)
    self._session_id = self._session_id + 1

    Renderer.set_automatic_streaming(true)
    GarbageLeakDetector.register_object(self, "VermitannicaPreviewer")
end

function VermitannicaPreviewer:on_enter(viewport_widget)

    local preview_pass_data = viewport_widget.element.pass_data[1]
    self.viewport_fov = viewport_widget.style.viewport.fov
    self.world = preview_pass_data.world
    self.level = preview_pass_data.level
    self.viewport = preview_pass_data.viewport
    self.camera = ScriptViewport.camera(self.viewport)

    Application.set_render_setting("max_shadow_casting_lights", 16)

end

VermitannicaPreviewer.on_enter = function (self, viewport_widget, hero_name)
    table.clear(self._requested_mip_streaming_units)
    table.clear(self._hidden_units)

    self.viewport_widget = viewport_widget
    local preview_pass_data = viewport_widget.element.pass_data[1]
    self.viewport_fov = viewport_widget.style.viewport.fov
    self.world = preview_pass_data.world
    self.physics_world = World.get_data(self.world, "physics_world")
    self.level = preview_pass_data.level
    self.viewport = preview_pass_data.viewport
    self.camera = ScriptViewport.camera(self.viewport)
    self.hero_name = hero_name
    self._browser_mode = nil

    Application.set_render_setting("max_shadow_casting_lights", 16)

    self.camera_xy_angle_current = DEFAULT_ANGLE
    self.camera_xy_angle_target = DEFAULT_ANGLE
    self.camera_zoom_current = 1
    self.camera_zoom_target = 1
    self.camera_z_pan_current = 0
    self.camera_z_pan_target = 0
    self.camera_x_pan_current = 0
    self.camera_x_pan_target = 0
    self.hero_look_current = { 0, 5, 1 }
    self.hero_look_target = { 0, 5, 1 }
    self.enemy_look_current = { 0, 5, 1 }
    self.enemy_look_target = { 0, 5, 1 }
    self.camera_enemy_xy_angle_current = -DEFAULT_ANGLE
    self.camera_enemy_xy_angle_target = -DEFAULT_ANGLE

    self._session_id = self._session_id or 0

    local level_name = viewport_widget.style.viewport.level_name
    local object_set_names = LevelResource.object_set_names(level_name)

    for _, object_set_name in ipairs(object_set_names) do
        local unit_indices = LevelResource.unit_indices_in_object_set(level_name, object_set_name)
        self:show_level_units(unit_indices, false)
    end
end

VermitannicaPreviewer.trigger_level_event = function (self, event_name)
    Level.trigger_event(self.level, event_name)
end

VermitannicaPreviewer.show_level_units = function (self, unit_indices, visibility)
    local level = self.level

    for _, unit_index in pairs(unit_indices) do
        local unit = Level.unit_by_index(level, unit_index)

        if Unit.alive(unit) then
            Unit.set_unit_visibility(unit, visibility)

            if visibility then
                Unit.flow_event(unit, "unit_object_set_enabled")
            else
                Unit.flow_event(unit, "unit_object_set_disabled")
            end
        end
    end
end

VermitannicaPreviewer.has_units_spawned = function (self)
    return self.hero_unit ~= nil or self.enemy_unit ~= nil
end

VermitannicaPreviewer.prepare_exit = function (self)
    self:clear_all_units()
end

VermitannicaPreviewer.on_exit = function (self)
    self:_unload_all_packages()

    self._hero_loading_package_data = nil
    self._enemy_loading_package_data = nil

    local max_shadow_casting_lights = Application.user_setting("render_settings", "max_shadow_casting_lights")
    Application.set_render_setting("max_shadow_casting_lights", max_shadow_casting_lights)

    self._session_id = self._session_id + 1

    Renderer.set_automatic_streaming(true)
end

VermitannicaPreviewer.clear_all_units = function (self)
    table.clear(self._requested_mip_streaming_units)

    self:_clear_enemy_units()
    self:_clear_hero_units()
end

VermitannicaPreviewer._clear_hero_units = function (self, reset_camera)
    local world = self.world

    for i = 1, 6, 1 do
        if type(self._hero_equipment_units[i]) == "table" then
            if self._hero_equipment_units[i].left then
                World.destroy_unit(world, self._hero_equipment_units[i].left)

                self._hero_equipment_units[i].left = nil
            end

            if self._hero_equipment_units[i].right then
                World.destroy_unit(world, self._hero_equipment_units[i].right)

                self._hero_equipment_units[i].right = nil
            end
        elseif self._hero_equipment_units[i] then
            World.destroy_unit(world, self._hero_equipment_units[i])

            self._hero_equipment_units[i] = nil
        end
    end

    if self.hero_unit ~= nil then
        World.destroy_unit(world, self.hero_unit)

        self.hero_unit = nil

        if reset_camera then
            local default_animation_data = self._default_animation_data

            self:set_hero_axis_offset("x", default_animation_data.x.value, 0.5, math.easeOutCubic)
            self:set_hero_axis_offset("y", default_animation_data.y.value, 0.5, math.easeOutCubic)
            self:set_hero_axis_offset("z", default_animation_data.z.value, 0.5, math.easeOutCubic)
        end
    end
end

VermitannicaPreviewer.trigger_unit_flow_event = function (self, unit, event_name)
    if unit and Unit.alive(unit) then
        Unit.flow_event(unit, event_name)
    end
end

VermitannicaPreviewer._clear_enemy_units = function (self, reset_camera)
    local world = self.world

    for i, unit_data in pairs(self.enemy_weapon_units) do
        World.destroy_unit(world, unit_data.weapon_unit)
        self.enemy_weapon_units[i] = nil
    end

    if self.enemy_unit then
        World.destroy_unit(world, self.enemy_unit)
        self.enemy_unit = nil
    end

    self._done_linking_units = false

    if reset_camera then
        local default_animation_data = self._default_animation_data

        self:set_camera_axis_offset("x", default_animation_data.x.value, 0.75, math.easeOutCubic)
        self:set_camera_axis_offset("y", default_animation_data.y.value, 0.75, math.easeOutCubic)
        self:set_camera_axis_offset("z", default_animation_data.z.value, 0.75, math.easeOutCubic)

        self.camera_zoom_target = 0
        self.camera_x_pan_target = 0
        self.camera_z_pan_target = 0
    end
end

VermitannicaPreviewer._load_packages = function (self, package_names)
    local reference_name = "vermitannica"
    local package_manager = Managers.package

    for index, package_name in ipairs(package_names) do
        package_manager:load(package_name, reference_name, nil, true)
    end
end

VermitannicaPreviewer._unload_all_packages = function (self)
    self:_unload_item_packages()
    self:_unload_hero_packages()
    self:_unload_enemy_packages()
end

VermitannicaPreviewer._unload_item_packages = function (self)
    local item_info_by_slot = self._item_info_by_slot

    for slot_type, data in pairs(item_info_by_slot) do
        self:_unload_item_packages_by_slot(slot_type)
    end
end

VermitannicaPreviewer._unload_hero_packages = function (self)
    local package_manager = Managers.package
    local reference_name = "vermitannica"
    local package_names

    if self._hero_loading_package_data then
        package_names = self._hero_loading_package_data.package_names
        for _, package_name in pairs(package_names) do
            if package_manager:can_unload(package_name) then
                package_manager:unload(package_name, reference_name)
            end
        end

        self._hero_loading_package_data = nil
    end

    if self._hero_weapons_loading_package_data then
        package_names = self._hero_weapons_loading_package_data.package_names
        for _, package_name in pairs(package_names) do
            if package_manager:can_unload(package_name) then
                package_manager:unload(package_name, reference_name)
            end
        end

        self._hero_weapons_loading_package_data = nil
    end
end

VermitannicaPreviewer._unload_enemy_packages = function (self)
    local package_manager = Managers.package
    local reference_name = "vermitannica"
    local package_names

    if self._enemy_loading_package_data then
        package_names = self._enemy_loading_package_data.package_names
        for _, package_name in pairs(package_names) do
            if package_manager:can_unload(package_name) then
                package_manager:unload(package_name, reference_name)
            end
        end

        self._enemy_loading_package_data = nil
    end

    if self._enemy_weapons_loading_package_data then
        package_names = self._enemy_weapons_loading_package_data.package_names
        for _, package_name in pairs(package_names) do
            package_manager:unload(package_name, reference_name)
        end

        self._enemy_weapons_loading_package_data = nil
    end
end

VermitannicaPreviewer.update = function (self, dt, t, input_disabled)
    local camera = self.camera

    local hero_unit = self.hero_unit
    local enemy_unit = self.enemy_unit
    local hero_weapon_units = self._hero_equipment_units

    if hero_unit then
        --if self._browser_mode and self._browser_mode ~= "hero_browser" then
        --    self:_set_hero_visibility(false)
        --else
        --    self:_set_hero_visibility(true)
        --end

        local target_position
        if self._browser_mode == "hero_browser" and self._unit_browser_positions["hero_browser"] then
            target_position = self._unit_browser_positions["hero_browser"]
        else
            target_position = Vector3Box.unbox(hero_spawn_home)
            --self.camera_xy_angle_target = DEFAULT_ANGLE
        end

        local hero_position_current = Unit.local_position(hero_unit, 0)
        local hero_position_new = {}
        hero_position_new.x = math.lerp(hero_position_current.x, target_position[1], 0.1)
        hero_position_new.y = math.lerp(hero_position_current.y, target_position[2], 0.1)
        hero_position_new.z = math.lerp(hero_position_current.z, target_position[3], 0.1)

        Unit.set_local_position(hero_unit, 0, Vector3(hero_position_new.x, hero_position_new.y, hero_position_new.z))

        if self.camera_xy_angle_target > math.pi * 2 then
            self.camera_xy_angle_current = self.camera_xy_angle_current - math.pi * 2
            self.camera_xy_angle_target = self.camera_xy_angle_target - math.pi * 2
        end

        local hero_xy_angle_new = math.lerp(self.camera_xy_angle_current, self.camera_xy_angle_target, 0.1)
        self.camera_xy_angle_current = hero_xy_angle_new
        local player_rotation = Quaternion.axis_angle(Vector3(0, 0, 1), -hero_xy_angle_new)

        Unit.set_local_rotation(hero_unit, 0, player_rotation)

        local look_target = Vector3Aux.unbox(self.hero_look_target)
        local aim_constraint_anim_var = Unit.animation_find_constraint_target(hero_unit, "aim_constraint_target")
        local rotated_constraint_position = Quaternion.rotate(player_rotation, look_target)

        Unit.animation_set_constraint_target(hero_unit, aim_constraint_anim_var, rotated_constraint_position)

        if not stop_animating then
            if self._requested_animation == "store_idle" then
                Unit.animation_event(hero_unit, self._requested_animation)

                self._requested_animation = nil
                stop_animating = true
            end

        end
    end

    if hero_weapon_units then

    end

    if enemy_unit then
        --if self._browser_mode and self._browser_mode ~= "enemy_browser" then
        --    Unit.set_unit_visibility(enemy_unit, false)
        --    local weapon_unit_data = self.enemy_weapon_units or {}
        --    for i, datum in ipairs(weapon_unit_data) do
        --        Unit.set_unit_visibility(datum.weapon_unit, false)
        --    end
        --
        --    local flow_unit_attachments = Unit.get_data(enemy_unit, "flow_unit_attachments") or {}
        --
        --    for _, unit in pairs(flow_unit_attachments) do
        --        Unit.set_unit_visibility(unit, false)
        --    end
        --
        --    Unit.flow_event(enemy_unit, "lua_attachment_hidden")
        --else
        --    Unit.set_unit_visibility(enemy_unit, true)
        --
        --    local flow_unit_attachments = Unit.get_data(enemy_unit, "flow_unit_attachments") or {}
        --
        --    for _, unit in pairs(flow_unit_attachments) do
        --        Unit.set_unit_visibility(unit, true)
        --    end
        --
        --    Unit.flow_event(enemy_unit, "lua_attachment_unhidden")
        --
        --    if self.enemy_weapon_units ~= nil and self._done_linking_units then
        --        local weapon_unit_data = self.enemy_weapon_units
        --        for i, datum in ipairs(weapon_unit_data) do
        --            Unit.set_unit_visibility(datum.weapon_unit, true)
        --        end
        --    end
        --end

        local target_position
        if self._browser_mode == "enemy_browser" and self._unit_browser_positions["enemy_browser"] then
            target_position = self._unit_browser_positions["enemy_browser"]
        else
            target_position = Vector3Box.unbox(enemy_spawn_home)
            --self.camera_enemy_xy_angle_target = -DEFAULT_ANGLE
        end

        local enemy_position_current = Unit.local_position(enemy_unit, 0)
        local enemy_position_new = {}
        enemy_position_new.x = math.lerp(enemy_position_current.x, target_position[1], 0.075)
        enemy_position_new.y = math.lerp(enemy_position_current.y, target_position[2], 0.075)
        enemy_position_new.z = math.lerp(enemy_position_current.z, target_position[3], 0.075)

        Unit.set_local_position(enemy_unit, 0, Vector3(enemy_position_new.x, enemy_position_new.y, enemy_position_new.z))

        if self.camera_enemy_xy_angle_target > math.pi * 2 then
            self.camera_enemy_xy_angle_current = self.camera_enemy_xy_angle_current - math.pi * 2
            self.camera_enemy_xy_angle_target = self.camera_enemy_xy_angle_target - math.pi * 2
        end

        local enemy_xy_angle_new = math.lerp(self.camera_enemy_xy_angle_current, self.camera_enemy_xy_angle_target, 0.1)
        self.camera_enemy_xy_angle_current = enemy_xy_angle_new
        local enemy_rotation = Quaternion.axis_angle(Vector3(0, 0, 1), -enemy_xy_angle_new)

        Unit.set_local_rotation(enemy_unit, 0, enemy_rotation)

        --if not stop_animating then
        --    -- Temporary hack to get warpfire throwers and ratling gunners to look where they're facing
        --    if self.enemy_name == "skaven_warpfire_thrower" or self.enemy_name == "skaven_ratling_gunner" then
        --        Unit.animation_event(enemy_unit, "attack_shoot_align")
        --    end
        --
        --    if self._requested_animation then
        --        if self._requested_animation == "ragdoll" and self.enemy_name == "skaven_grey_seer" then
        --            Unit.animation_event(enemy_unit, "death_backward")
        --        else
        --            if Unit.has_animation_event(enemy_unit, self._requested_animation) then
        --                Unit.animation_event(enemy_unit, self._requested_animation)
        --            end
        --        end
        --
        --        self._requested_animation = nil
        --    end
        --
        --    stop_animating = true
        --end

        --local has_animation_state_machine = Unit.has_animation_state_machine(enemy_unit)
        --if has_animation_state_machine then
        --    if Unit.animation_has_constraint_target(enemy_unit, "aim_target") then
        --        --local aim_constraint_anim_var = Unit.animation_find_constraint_target(enemy_unit, "aim_target")
        --        --if aim_constraint_anim_var then
        --        --    Unit.animation_set_constraint_target(enemy_unit, aim_constraint_anim_var, Unit.local_rotation(enemy_unit, 0))
        --        --end
        --        Unit.animation_event(enemy_unit, "attack_shoot_align")
        --    end
        --
        --    self.has_animation_state_machine = true
        --elseif self.has_animation_state_machine then
        --    self.has_animation_state_machine = false
        --
        --    Unit.enable_animation_state_machine(enemy_unit)
        --end

        if not Unit.has_animation_state_machine(enemy_unit) then
            Unit.enable_animation_state_machine(enemy_unit)

            self.waiting_for_state_machine = nil
        end

        if self._done_linking_units then
            if self._requested_animation and not self.waiting_for_state_machine then
                Unit.animation_event(enemy_unit, self._requested_animation)

                self._requested_animation = nil
            end
        end

    end

    self:_update_camera_animation_data(self._camera_position_animation_data, dt)

    local viewport_fov = self.viewport_fov
    local zoom_min = -viewport_fov / 4
    local zoom_max = viewport_fov / 2
    self.camera_zoom_target = math.clamp(self.camera_zoom_target, zoom_min, zoom_max)

    local camera_zoom_new = math.lerp(self.camera_zoom_current, self.camera_zoom_target, 0.1)
    self.camera_zoom_current = camera_zoom_new

    local x_pan_min = self._browser_mode and browser_camera_pan_ranges[self._browser_mode]["x"].min or -1.5
    local x_pan_max = self._browser_mode and browser_camera_pan_ranges[self._browser_mode]["x"].max or 1.5
    self.camera_x_pan_target = math.clamp(self.camera_x_pan_target, x_pan_min, x_pan_max)

    local camera_x_pan_new = math.lerp(self.camera_x_pan_current, self.camera_x_pan_target, 0.1)
    self.camera_x_pan_current = camera_x_pan_new

    local z_pan_min = self._browser_mode and browser_camera_pan_ranges[self._browser_mode]["z"].min or -1
    local z_pan_max = self._browser_mode and browser_camera_pan_ranges[self._browser_mode]["z"].max or 1
    self.camera_z_pan_target = math.clamp(self.camera_z_pan_target, z_pan_min, z_pan_max)

    local camera_z_pan_new = math.lerp(self.camera_z_pan_current, self.camera_z_pan_target, 0.1)
    self.camera_z_pan_current = camera_z_pan_new

    local camera_default_position = self._camera_default_position

    local camera_position_new = Vector3.zero()
    camera_position_new.x = camera_default_position.x - camera_x_pan_new
    camera_position_new.y = camera_default_position.y
    camera_position_new.z = math.max(camera_default_position.z + camera_z_pan_new, 0.05)

    local camera_position_animation_data = self._camera_position_animation_data
    local camera_gamepad_offset_data = self._camera_gamepad_offset_data
    camera_position_new.x = camera_position_new.x + camera_position_animation_data.x.value + camera_gamepad_offset_data[1]
    camera_position_new.y = camera_position_new.y + camera_position_animation_data.y.value + camera_gamepad_offset_data[2]
    camera_position_new.z = camera_position_new.z + camera_position_animation_data.z.value + camera_gamepad_offset_data[3]

    ScriptCamera.set_local_position(camera, camera_position_new)

    local look_target = self._default_look_target
    local direction = Vector3.normalize(Vector3(camera_position_new.x, look_target.y, camera_position_new.z) - camera_position_new)
    local camera_rotation_animation_data = self._camera_rotation_animation_data
    direction.x = direction.x + camera_rotation_animation_data.x.value
    direction.y = direction.y + camera_rotation_animation_data.y.value
    direction.z = direction.z + camera_rotation_animation_data.z.value
    local rotation = Quaternion.look(direction)

    ScriptCamera.set_local_rotation(camera, rotation)
    Camera.set_vertical_fov(camera, (math.pi * ( viewport_fov - camera_zoom_new) ) / 180)

    local input_service = self.input_manager:get_service("vermitannica_view")
    if not input_disabled then
        self:_handle_mouse_input(input_service, dt)
        self:_handle_controller_input(input_service, dt)
    end
end

VermitannicaPreviewer.post_update = function (self, dt)
    self:_update_units_visibility(dt)
    self:_poll_packages_loading()
    self:_handle_spawn_requests()
end

VermitannicaPreviewer.force_stream_highest_mip_levels = function (self)
    self._use_highest_mip_levels = true
end

VermitannicaPreviewer.force_hide_character = function (self)
    self._force_hide_character = true
end

VermitannicaPreviewer.force_unhide_character = function (self)
    self._force_hide_character = false
end

VermitannicaPreviewer._update_units_visibility = function (self, dt)
    if self.waiting_for_state_machine then
        return
    end

    local is_items_loaded = self:_is_all_items_loaded()

    if not is_items_loaded then
        return
    end

    local hero_unit = self.hero_unit
    local enemy_unit = self.enemy_unit

    if not Unit.alive(hero_unit) and not Unit.alive(enemy_unit) then
        return
    end

    if self._force_hide_character then
        return
    end

    if self:_update_unit_mip_streaming() then
        return
    end

    if self._stored_hero_animation then
        local force_play_animation = true

        self:play_hero_animation(self._stored_hero_animation, force_play_animation)

        self._stored_hero_animation = nil

        return
    end

    if self.hero_unit_hidden_after_spawn then
        self.hero_unit_hidden_after_spawn = false

        Unit.flow_event(hero_unit, "lua_spawn_attachments")

        if self._draw_hero == false then
            self:_set_hero_visibility(false)
        else
            self:_set_hero_visibility(true)
        end

        table.clear(self._hidden_units)
    else
        for unit, _ in pairs(self._hidden_units) do
            if Unit.alive(unit) then
                Unit.set_unit_visibility(unit, true)
            end

            self._hidden_units[unit] = nil
        end
    end

    if Unit.alive(enemy_unit) then
        local unit_visibility_frame_delay = self.unit_visibility_frame_delay

        if self.enemy_weapon_units ~= nil and not self._done_linking_units then
            for i, unit_data in pairs(self.enemy_weapon_units) do
                local wielded_node = unit_data.attachment_node_linking.wielded
                local unwielded_node = unit_data.attachment_node_linking.unwielded
                local linking_data = wielded_node and wielded_node[1] or unit_data.attachment_node_linking[1]

                if wielded_node then
                    linking_data = (self.should_unwield and self.enemy_name == "beastmen_ungor_archer" and unwielded_node[1]) or wielded_node[1]
                    local node_index = Unit.node(self.enemy_unit, linking_data.source)
                    local modifier = self.enemy_name == "skaven_loot_rat" and 1 or 0
                    World.link_unit(self.world, unit_data.weapon_unit, linking_data.target + modifier, self.enemy_unit, node_index)
                elseif linking_data then
                    AttachmentUtils.link(self.world, self.enemy_unit, unit_data.weapon_unit, unit_data.attachment_node_linking)
                else
                    World.destroy_unit(self.world, self.enemy_weapon_units[i].weapon_unit)
                    self.enemy_weapon_units[i] = nil
                end

            end
            self._done_linking_units = true
        end

        if unit_visibility_frame_delay and unit_visibility_frame_delay > 0 then
            self.unit_visibility_frame_delay = unit_visibility_frame_delay - 1

            return
        end

        for unit, _ in pairs(self._hidden_units) do
            if Unit.alive(unit) then
                Unit.set_unit_visibility(unit, true)
            end

            self._hidden_units[unit] = nil
        end

        self.force_unhide_character = false
    end
end

VermitannicaPreviewer._update_unit_mip_streaming = function (self)
    local mip_streaming_completed = true
    local num_units_handled = 0
    local requested_mip_streaming_units = self._requested_mip_streaming_units

    for unit, _ in pairs(requested_mip_streaming_units) do
        local unit_mip_streaming_completed = Renderer.is_all_mips_loaded_for_unit(unit)

        if unit_mip_streaming_completed then
            requested_mip_streaming_units[unit] = nil
        else
            mip_streaming_completed = false
        end

        num_units_handled = num_units_handled + 1
    end

    if not mip_streaming_completed then
        return true
    elseif num_units_handled > 0 then
        Renderer.set_automatic_streaming(true)
    end
end

VermitannicaPreviewer._request_mip_streaming_for_unit = function (self, unit)
    local requested_mip_streaming_units = self._requested_mip_streaming_units
    requested_mip_streaming_units[unit] = true

    Renderer.set_automatic_streaming(false)

    for unit, _ in pairs(requested_mip_streaming_units) do
        Renderer.request_to_stream_all_mips_for_unit(unit)
    end
end

VermitannicaPreviewer._set_hero_visibility = function (self, visible)
    self._draw_hero = visible

    if self.hero_unit_hidden_after_spawn then
        return
    end

    local hero_unit = self.hero_unit

    if Unit.alive(hero_unit) then
        Unit.set_unit_visibility(hero_unit, visible)

        local flow_unit_attachments = Unit.get_data(hero_unit, "flow_unit_attachments") or {}

        for _, unit in pairs(flow_unit_attachments) do
            Unit.set_unit_visibility(unit, visible)
        end

        local slots_by_slot_index = InventorySettings.slots_by_slot_index
        local attachment_lua_event = (visible and "lua_attachment_unhidden") or "lua_attachment_hidden"

        Unit.flow_event(hero_unit, attachment_lua_event)

        local hero_equipment_units = self._hero_equipment_units

        for slot_index, data in pairs(hero_equipment_units) do
            local slot = slots_by_slot_index[slot_index]
            local category = slot.category
            local slot_type = slot.type
            local is_weapon = category == "weapon"
            local show_unit

            if is_weapon then
                show_unit = visible and slot_type == self._wielded_slot_type
            else
                show_unit = visible
            end

            local weapon_lua_event = (show_unit and "lua_wield") or "lua_unwield"

            if type(data) == "table" then
                local left_unit = data.left
                local right_unit = data.right

                if Unit.alive(left_unit) then
                    Unit.flow_event(left_unit, weapon_lua_event)
                    Unit.set_unit_visibility(left_unit, show_unit)
                end

                if Unit.alive(right_unit) then
                    Unit.flow_event(right_unit, weapon_lua_event)
                    Unit.set_unit_visibility(right_unit, show_unit)
                end
            elseif Unit.alive(data) then
                if not is_weapon then
                    attachment_lua_event = (show_unit and "lua_attachment_unhidden") or "lua_attachment_hidden"

                    Unit.flow_event(data, attachment_lua_event)
                end

                Unit.flow_event(data, weapon_lua_event)
                Unit.set_unit_visibility(data, show_unit)
            end
        end

        if visible then
            local skin_data = self.hero_unit_skin_data
            local material_changes = skin_data.material_changes

            if material_changes then
                local third_person_changes = material_changes.third_person

                for slot_name, material_name in pairs(third_person_changes) do
                    for _, unit in pairs(flow_unit_attachments) do
                        Unit.set_material(unit, slot_name, material_name)
                    end
                end
            end

            for slot_name, data in pairs(self._item_info_by_slot) do
                if data.loaded then
                    local item_name = data.name
                    local item_template = ItemHelper.get_template_by_item_name(item_name)
                    local show_attachments_event = item_template.show_attachments_event

                    if show_attachments_event then
                        Unit.flow_event(hero_unit, show_attachments_event)
                    end
                end
            end
        end

        self.hero_unit_visible = visible
    end

    --local camera_move_duration = self._camera_move_duration
    --if camera_move_duration then
    --    local x, y, z = 0, 0, 0
    --
    --    if visible then
    --        local profile_name = self._current_profile_name
    --
    --        if profile_name then
    --            local hero_camera_positions = self._hero_camera_positions
    --            local new_hero_position = hero_camera_positions[profile_name]
    --            x = new_hero_position.x
    --            y = new_hero_position.y
    --            z = new_hero_position.z
    --        end
    --    end
    --
    --    self:set_hero_axis_offset("x", x, camera_move_duration, math.easeOutCubic)
    --    self:set_hero_axis_offset("y", y, camera_move_duration, math.easeOutCubic)
    --    self:set_hero_axis_offset("z", z, camera_move_duration, math.easeOutCubic)
    --end
end

VermitannicaPreviewer.hero_visible = function (self)
    return self.hero_unit_visible and Unit.alive(self.hero_unit)
end

VermitannicaPreviewer._update_camera_animation_data = function (self, animation_data, dt)
    for axis, data in pairs(animation_data) do
        if data.total_time then
            local old_time = data.time
            data.time = math.min(old_time + dt, data.total_time)
            local progress = math.min(1, data.time / data.total_time)
            local func = data.func
            data.value = (data.to - data.from) * ((func and func(progress)) or progress) + data.from

            if progress == 1 then
                data.total_time = nil
            end

        end
    end
end

VermitannicaPreviewer.set_camera_axis_offset = function (self, axis, value, animation_time, func_ptr, fixed_position)
    local data = self._camera_position_animation_data[axis]
    local camera_default_position = self._camera_default_position
    data.from = (animation_time and data.value) or value
    data.to = (fixed_position and value - camera_default_position[axis]) or value
    data.total_time = animation_time
    data.time = 0
    data.func = func_ptr or math.easeOutCubic
    data.value = data.from
end

VermitannicaPreviewer.set_camera_gamepad_offset = function (self, value)
    self._camera_gamepad_offset_data = value
end

VermitannicaPreviewer.set_camera_rotation_axis_offset = function (self, axis, value, animation_time, func_ptr)
    local data = self._camera_rotation_animation_data[axis]
    data.from = (animation_time and data.value) or value
    data.to = value
    data.total_time = animation_time
    data.time = 0
    data.func = func_ptr
    data.value = data.from
end

local mouse_pos_temp = {}
VermitannicaPreviewer._handle_mouse_input = function (self, input_service, dt)
    local hero_unit = self.hero_unit
    local enemy_unit = self.enemy_unit

    if hero_unit == nil and enemy_unit == nil then
        return
    end

    if not self.input_manager:is_device_active("mouse") then
        return
    end

    local mouse = input_service:get("cursor")

    if not mouse then
        return
    end

    local viewport_widget = self.viewport_widget
    local content = viewport_widget.content
    local button_hotspot = content.button_hotspot
    local is_hover = button_hotspot and button_hotspot.is_hover

    if is_hover and self._browser_mode ~= nil then
        local from = Camera.screen_to_world(self.camera, Vector3(mouse.x, mouse.y, 0), 0)
        local to = Camera.screen_to_world(self.camera, Vector3(mouse.x, mouse.y, 0), 1)
        local direction = to - from

        local hero_hit
        local enemy_hit
        if input_service:get("left_press") or input_service:get("right_press") then
            if hero_unit and self._draw_hero then
                local hero_unit_box, hero_box_dimension = Unit.box(hero_unit)
                hero_box_dimension[1] = hero_box_dimension[1] * 0.25
                hero_box_dimension[2] = hero_box_dimension[2] * 0.25

                hero_hit = Intersect.ray_box(from, direction, hero_unit_box, hero_box_dimension)
            end

            if enemy_unit and self._browser_mode == "enemy_browser" then
                local enemy_unit_box, enemy_box_dimension = Unit.box(enemy_unit)
                enemy_box_dimension[1] = enemy_box_dimension[1] * 0.25
                enemy_box_dimension[2] = enemy_box_dimension[2] * 0.25
                enemy_hit = Intersect.ray_box(from, direction, enemy_unit_box, enemy_box_dimension)
            end

            self.selected_unit = (hero_hit and hero_unit) or (enemy_hit and enemy_unit) or nil
            self.is_moving_camera = true
            self.last_mouse_position = nil
        end

        if input_service:get("scroll_axis") then
            self.is_moving_camera = true
        end

        local is_moving_camera = self.is_moving_camera
        local left_mouse_hold = input_service:get("left_hold")
        local right_mouse_hold = input_service:get("right_hold")
        local shift_hold = input_service:get("shift_hold")
        local scroll_wheel = input_service:get("scroll_axis")
        local middle_mouse_hold = input_service:get("middle_hold")

        if is_moving_camera and (left_mouse_hold or right_mouse_hold or scroll_wheel) then
            if self.last_mouse_position then
                if left_mouse_hold then

                    if self.selected_unit == hero_unit then
                        self.camera_xy_angle_target = self.camera_xy_angle_target - (mouse.x - self.last_mouse_position[1]) * 0.01
                    elseif self.selected_unit == enemy_unit then
                        self.camera_enemy_xy_angle_target = self.camera_enemy_xy_angle_target - (mouse.x - self.last_mouse_position[1]) * 0.01
                    end

                end

                if right_mouse_hold then
                    if self.last_mouse_position then
                        self.camera_z_pan_target = self.camera_z_pan_target - (mouse.y - self.last_mouse_position[2]) * 0.005
                        self.camera_x_pan_target = self.camera_x_pan_target - (mouse.x - self.last_mouse_position[1]) * 0.005
                    end

                    mouse_pos_temp[1] = mouse.x
                    mouse_pos_temp[2] = mouse.y
                    self.last_mouse_position = mouse_pos_temp
                end
            end

            if is_moving_camera and scroll_wheel and self._browser_mode ~= nil then
                self.camera_zoom_target = self.camera_zoom_target + (scroll_wheel[2]) * 5
            end

            mouse_pos_temp[1] = mouse.x
            mouse_pos_temp[2] = mouse.y
            self.last_mouse_position = mouse_pos_temp

        elseif is_moving_camera then
            self.is_moving_camera = false
            self.selected_unit = nil
        end
    end


end

VermitannicaPreviewer._handle_controller_input = function (self, input_service, dt)
    local hero_unit = self.hero_unit

    if hero_unit == nil then
        return
    end

    if not self.input_manager:is_device_active("gamepad") then
        return
    end

    local camera_move = input_service:get("gamepad_right_axis")

    if camera_move and Vector3.length(camera_move) > 0.01 then
        self.camera_xy_angle_target = self.camera_xy_angle_target + -camera_move.x * dt * 5
    end
end

VermitannicaPreviewer.start_hero_rotation = function (self, direction)
    if direction then
        self.rotation_direction = direction
    end
end

VermitannicaPreviewer.end_hero_rotation = function (self)

end

VermitannicaPreviewer.play_hero_animation = function (self, animation_event, force_play_animation)
    local hero_unit = self.hero_unit

    if hero_unit == nil then
        return
    end

    if not self.hero_unit_visible and not force_play_animation then
        self._stored_hero_animation = animation_event
    else
        Unit.animation_event(hero_unit, animation_event)
    end
end

VermitannicaPreviewer._is_all_items_loaded = function (self)
    local item_info_by_slot = self._item_info_by_slot
    local all_loaded = true

    for slot_name, data in pairs(item_info_by_slot) do
        if not data.loaded then
            all_loaded = false

            break
        end
    end

    return all_loaded
end

VermitannicaPreviewer._spawn_item = function (self, item_name, spawn_data)
    local world = self.world
    local hero_unit = self.hero_unit
    local scenegraph_links = {}
    local item_template = ItemHelper.get_template_by_item_name(item_name)
    local hero_material_changed = false

    for _, unit_spawn_data in ipairs(spawn_data) do
        local unit_name = unit_spawn_data.unit_name
        local item_slot_type = unit_spawn_data.item_slot_type
        local slot_index = unit_spawn_data.slot_index
        local unit_attachment_node_linking = unit_spawn_data.unit_attachment_node_linking
        local hero_material_changes = unit_spawn_data.hero_material_changes
        local material_settings = unit_spawn_data.material_settings

        if item_slot_type == "melee" or item_slot_type == "ranged" then
            local unit = World.spawn_unit(world, unit_name)

            self:_spawn_item_unit(unit, item_slot_type, item_template, unit_attachment_node_linking, scenegraph_links, material_settings)

            if unit_spawn_data.right_hand then
                self._hero_equipment_units[slot_index].right = unit
                self._hero_equipment_units_data[slot_index].right = {
                    unit_attachment_node_linking = unit_attachment_node_linking,
                    scenegraph_links = scenegraph_links
                }
            elseif unit_spawn_data.left_hand then
                self._hero_equipment_units[slot_index].left = unit
                self._hero_equipment_units_data[slot_index].left = {
                    unit_attachment_node_linking = unit_attachment_node_linking,
                    scenegraph_links = scenegraph_links
                }
            end
        else
            local unit = World.spawn_unit(world, unit_name)
            self._hero_equipment_units[slot_index] = unit
            self._hero_equipment_units_data[slot_index] = {
                unit_attachment_node_linking = unit_attachment_node_linking,
                scenegraph_links = scenegraph_links
            }

            self:_spawn_item_unit(unit, item_slot_type, item_template, unit_attachment_node_linking, scenegraph_links)

        end

        local show_attachments_event = item_template.show_attachments_event

        if show_attachments_event and self.hero_unit_visible then
            Unit.flow_event(hero_unit, show_attachments_event)
        end

        if hero_material_changes then
            local third_person_changes = hero_material_changes.third_person
            local flow_unit_attachments = Unit.get_data(hero_unit, "flow_unit_attachments") or {}

            for slot_name, material_name in pairs(third_person_changes) do
                for _, unit in pairs(flow_unit_attachments) do
                    Unit.set_material(unit, slot_name, material_name)
                end

                Unit.set_material(hero_unit, slot_name, material_name)

                hero_material_changed = true
            end
        end
    end

    if hero_material_changed and (self._use_highest_mip_levels or UISettings.wait_for_mip_streaming_character) then
        self:_request_mip_streaming_for_unit(hero_unit)
    end
end

VermitannicaPreviewer._spawn_item_unit = function (self, unit, item_slot_type, item_template, unit_attachment_node_linking, scene_graph_links, material_settings)
    local world = self.world
    local hero_unit = self.hero_unit
    local hero_visible = self:hero_visible()

    if item_slot_type == "melee" or item_slot_type == "ranged" then
        if self._wielded_slot_type == item_slot_type then
            unit_attachment_node_linking = unit_attachment_node_linking.wielded

            if item_template.wield_anim then
                Unit.animation_event(hero_unit, item_template.wield_anim)
            end

            self._hidden_units[unit] = true
            local flow_event = (hero_visible and "lua_wield") or "lua_unwield"

            Unit.flow_event(unit, flow_event)
        else
            --unit_attachment_node_linking = unit_attachment_node_linking.unwielded
            --
            --Unit.flow_event(unit, "lua_unwield")
        end
    else
        local attachment_lua_event = (hero_visible and "lua_attachment_unhidden") or "lua_attachment_hidden"

        Unit.flow_event(unit, attachment_lua_event)

        self._hidden_units[unit] = true
    end

    Unit.set_unit_visibility(unit, false)

    if Unit.has_lod_object(unit, "lod") then
        local lod_object = Unit.lod_object(unit, "lod")

        LODObject.set_static_height(lod_object, 1)
    end

    GearUtils.link(world, unit_attachment_node_linking, scene_graph_links, hero_unit, unit)

    if material_settings then
        GearUtils.apply_material_settings(unit, material_settings)
    end

    if self._use_highest_mip_levels or UISettings.wait_for_mip_streaming_items then
        self:_request_mip_streaming_for_unit(unit)
    end
end

VermitannicaPreviewer._destroy_item_units_by_slot = function (self, slot_type)
    local world = self.world
    local hidden_units = self._hidden_units
    local requested_mip_streaming_units = self._requested_mip_streaming_units
    local item_info_by_slot = self._item_info_by_slot
    local data = item_info_by_slot[slot_type]
    local spawn_data = data.spawn_data

    if spawn_data then
        for _, unit_spawn_data in ipairs(spawn_data) do
            local item_slot_type = unit_spawn_data.item_slot_type
            local slot_index = unit_spawn_data.slot_index

            if item_slot_type == "melee" or item_slot_type == "ranged" then
                if unit_spawn_data.right_hand or unit_spawn_data.despawn_both_hands_units then
                    local old_unit_right = self._hero_equipment_units[slot_index].right

                    if old_unit_right ~= nil then
                        hidden_units[old_unit_right] = nil
                        requested_mip_streaming_units[old_unit_right] = nil

                        World.destroy_unit(world, old_unit_right)

                        self._hero_equipment_units[slot_index].right = nil
                    end
                end

                if unit_spawn_data.left_hand or unit_spawn_data.despawn_both_hands_units then
                    local old_unit_left = self._hero_equipment_units[slot_index].left

                    if old_unit_left ~= nil then
                        hidden_units[old_unit_left] = nil
                        requested_mip_streaming_units[old_unit_left] = nil

                        World.destroy_unit(world, old_unit_left)

                        self._hero_equipment_units[slot_index].left = nil
                    end
                end
            else
                local old_unit = self._hero_equipment_units[slot_index]

                if old_unit ~= nil then
                    hidden_units[old_unit] = nil
                    requested_mip_streaming_units[old_unit] = nil

                    World.destroy_unit(world, old_unit)

                    self._hero_equipment_units[slot_index] = nil
                end
            end
        end
    end
end

VermitannicaPreviewer.item_name_by_slot_type = function (self, item_slot_type)
    local item_info = self._item_info_by_slot[item_slot_type]

    return item_info and item_info.name
end

VermitannicaPreviewer.wielded_slot_type = function (self)
    return self._wielded_slot_type
end

VermitannicaPreviewer._poll_packages_loading = function (self)
    self:_poll_hero_packages_loading()
    self:_poll_enemy_packages_loading()
    self:_poll_item_package_loading()
end

VermitannicaPreviewer._poll_hero_packages_loading = function (self)
    local data = self._hero_loading_package_data

    if not data or data.loaded then
        return
    end

    if self._requested_hero_spawn_data then
        return
    end

    local reference_name = "vermitannica"
    local package_manager = Managers.package
    local package_names = data.package_names

    local all_packages_loaded = true
    for i = 1, #package_names, 1 do
        local package_name = package_names[i]

        if not package_manager:has_loaded(package_name, reference_name) then
            all_packages_loaded = false

            break
        end
    end

    if all_packages_loaded then
        local skin_data = data.skin_data
        local optional_scale = data.optional_scale
        local career_index = data.career_index
        local camera_move_duration = data.camera_move_duration

        self:_spawn_hero_unit(skin_data, optional_scale, career_index, camera_move_duration)

        local callback = data.callback

        if callback then
            callback()
        end

        data.loaded = true
    end
end

VermitannicaPreviewer._poll_enemy_packages_loading = function (self)
    local data = self._enemy_loading_package_data

    if not data or data.loaded then
        return
    end

    if self._requested_enemy_spawn_data then
        return
    end

    local reference_name = "vermitannica"
    local package_manager = Managers.package
    local package_names = data.package_names

    local all_packages_loaded = true
    for i = 1, #package_names, 1 do
        local package_name = package_names[i]

        if not package_manager:has_loaded(package_name, reference_name) then
            all_packages_loaded = false

            break
        end
    end

    if all_packages_loaded then
        local enemy_name = data.enemy_name

        self:_spawn_enemy_unit(enemy_name)

        local callback = data.callback

        if callback then
            callback()
        end

        data.loaded = true
    end
end

VermitannicaPreviewer.request_animation = function (self, requested_animation)
    self._requested_animation = requested_animation
end

local ignore_multiple_configs_by_breed_name = {
    skaven_storm_vermin_warlord = true,
    beastmen_ungor_archer = true
}
VermitannicaPreviewer._spawn_enemy_weapon_units = function (self, inventory_config)
    if not inventory_config or not Managers.package:has_loaded("resource_packages/inventory", "vermitannica") then
        return
    end

    local anim_state_event
    local equip_anim
    local categories = {}
    if inventory_config.multiple_configurations then
        local index
        if ignore_multiple_configs_by_breed_name[self.enemy_name] then
            index = 1
        else
            index = math.random(1, #inventory_config.multiple_configurations)
        end

        local config = InventoryConfigurations[inventory_config.multiple_configurations[index]]
        anim_state_event = config.anim_state_event
        equip_anim = config.equip_anim
        categories = config.items

    else
        categories = inventory_config.items
    end

    anim_state_event = anim_state_event or inventory_config.anim_state_event
    if anim_state_event then
        self:request_animation(anim_state_event)
    elseif self._current_enemy_name == "skaven_warpfire_thrower" or self._current_enemy_name == "skaven_ratling_gunner" then
        self:request_animation("attack_shoot_align")
    end

    local weapon_unit_definitions = {}
    for i, category in ipairs(categories) do
        local target_index = math.random(1, #category)
        weapon_unit_definitions[#weapon_unit_definitions + 1] = category[target_index]
    end

    local weapon_units = {}
    for i, weapon_unit_definition in ipairs(weapon_unit_definitions) do

        local weapon_unit = World.spawn_unit(self.world, weapon_unit_definition.unit_name)
        Unit.set_unit_visibility(weapon_unit, false)

        self._hidden_units[weapon_unit] = true

        weapon_units[#weapon_units + 1] = {
            weapon_unit = weapon_unit,
            attachment_node_linking = weapon_unit_definition.attachment_node_linking
        }
    end
    self.enemy_weapon_units = weapon_units
end

local wait_for_state_machine = {
    chaos_exalted_sorcerer = true,
    chaos_exalted_sorcerer_drachenfels = true,
    chaos_corruptor_sorcerer = true,
    chaos_vortex_sorcerer = true
}
VermitannicaPreviewer._spawn_enemy_unit = function (self, enemy_name)
    local world = self.world

    self.enemy_name = enemy_name

    enemy_name = EnemyPackageLoaderSettings[enemy_name] or enemy_name

    local unit_name = Breeds[enemy_name].base_unit
    local enemy_unit = World.spawn_unit(world, unit_name)
    self.enemy_unit = enemy_unit

    local size_variation_range = Breeds[enemy_name].size_variation_range
    if size_variation_range then
        local size_normalized = Math.random()
        local size = math.lerp(size_variation_range[1], size_variation_range[2], size_normalized)
        Unit.set_local_scale(enemy_unit, 0, Vector3(size, size, size))
    end

    Unit.set_unit_visibility(enemy_unit, false)
    Unit.set_local_position(enemy_unit, 0, self._browser_mode == "enemy_browser" and Vector3(0, 0, 0) or Vector3Box.unbox(enemy_spawn_home))

    self.camera_enemy_xy_angle_target = (self._browser_mode == "enemy_browser" and 0) or -DEFAULT_ANGLE

    self._hidden_units[enemy_unit] = true
    self.enemy_unit_hidden = true

    local template_name = Breeds[enemy_name].default_inventory_template
    if type(template_name) == "table" then
        local index = math.random(1, #template_name)
        template_name = template_name[index]
    end

    local template_function = AIInventoryTemplates[template_name]

    local inventory_config
    if template_function then
        local config_name = template_function()
        inventory_config = InventoryConfigurations[config_name]
        self._current_inventory_config = inventory_config

        if self.enemy_name == "chaos_exalted_champion_norsca" then
            inventory_config = {
                anim_state_event = "to_spear",
                items = {
                    {
                        {
                            drop_on_hit = true,
                            unit_name = "units/weapons/enemy/wpn_chaos_set/wpn_chaos_2h_axe_03",
                            attachment_node_linking = AttachmentNodeLinking.ai_2h
                        }
                    }
                }
            }
        end

        self:_spawn_enemy_weapon_units(inventory_config)
    end

    self.unit_visibility_frame_delay = 5

    if Unit.has_lod_object(enemy_unit, "lod") then
        local lod_object = Unit.lod_object(enemy_unit, "lod")

        LODObject.set_static_select(lod_object, 0)
    end

    --local enemy_camera_positions = self._character_camera_positions

    --self._camera_current_position = enemy_camera_positions[enemy_name] or self.camera_default_position

    --local look_target = Vector3Aux.unbox(self.enemy_look_target)
    --
    --local aim_constraint_target = Breeds[enemy_name].aim_constraint_target
    --if aim_constraint_target then
    --    if type(aim_constraint_target) == "table" then
    --        aim_constraint_target = aim_constraint_target[1]
    --    end
    --
    --    local aim_constraint_anim_var = Unit.animation_find_constraint_target(enemy_unit, aim_constraint_target)
    --
    --    Unit.animation_set_constraint_target(enemy_unit, aim_constraint_anim_var, look_target)
    --end
end

VermitannicaPreviewer._spawn_hero_unit = function (self, skin_data, optional_scale, career_index)
    local world = self.world
    local unit_name = skin_data.third_person
    local tint_data = skin_data.color_tint
    local hero_unit = World.spawn_unit(world, unit_name)
    local material_changes = skin_data.material_changes

    if material_changes then
        local third_person_changes = material_changes.third_person

        for slot_name, material_name in pairs(third_person_changes) do
            Unit.set_material(hero_unit, slot_name, material_name)
        end
    end

    if tint_data then
        local gradient_variation = tint_data.gradient_variation
        local gradient_value = tint_data.gradient_value

        CosmeticUtils.color_tint_unit(hero_unit, self._current_profile_name, gradient_variation, gradient_value)
    end

    Unit.set_unit_visibility(hero_unit, false)
    Unit.set_local_position(hero_unit, 0, Vector3(1.25, 0.9, 0))

    self.hero_unit = hero_unit
    self.hero_unit_hidden_after_spawn = true
    self.hero_unit_visible = false
    self.hero_unit_skin_data = skin_data
    self._stored_hero_animation = nil

    if Unit.has_lod_object(hero_unit, "lod") then
        local lod_object = Unit.lod_object(hero_unit, "lod")

        LODObject.set_static_height(lod_object, 1)
    end

    --local look_target = Vector3Aux.unbox(self.hero_look_current)
    --local aim_constraint_anim_var = Unit.animation_find_constraint_target(hero_unit, "aim_constraint_target")

    --Unit.animation_set_constraint_target(hero_unit, aim_constraint_anim_var, look_target)

    local unit_box, box_dimension = Unit.box(hero_unit)

    if box_dimension then
        local default_unit_height_dimension = 1.7
        self.unit_max_look_height = (default_unit_height_dimension < box_dimension.z and 1.5) or 0.9
    else
        self.unit_max_look_height = 0.9
    end

    if optional_scale then
        local scale = Vector3(optional_scale, optional_scale, optional_scale)

        Unit.set_local_scale(hero_unit, 0, scale)
    end

    if self._use_highest_mip_levels or UISettings.wait_for_mip_streaming_character then
        self:_request_mip_streaming_for_unit(hero_unit)
    end

    if Unit.animation_has_variable(hero_unit, "career_index") then
        local variable_index = Unit.animation_find_variable(hero_unit, "career_index")

        Unit.animation_set_variable(hero_unit, variable_index, career_index)
    end

end

VermitannicaPreviewer.respawn_hero_unit = function (self, profile_name, career_index, callback)
    local reset_camera = true

    self:request_spawn_hero_unit(profile_name, career_index, callback, reset_camera)
end

VermitannicaPreviewer.get_equipped_item_info = function (self, slot)
    local item_slot_type = slot.type
    local item_info_by_slot = self._item_info_by_slot

    return item_info_by_slot[item_slot_type]
end

VermitannicaPreviewer.equip_item = function (self, item_name, slot, skin_name)

    local skin_data = self.hero_unit_skin_data

    if skin_data and skin_data.always_hide_attachment_slots then
        local hide_slot = false

        for _, slot_name in ipairs(skin_data.always_hide_attachment_slots) do
            if slot.name == slot_name then
                hide_slot = true

                break
            end
        end

        if hide_slot then
            return
        end
    end

    local item_slot_type = slot.type
    local slot_index = slot.slot_index
    local item_data = ItemMasterList[item_name]
    local item_units = BackendUtils.get_item_units(item_data, nil, skin_name)
    local item_template = ItemHelper.get_template_by_item_name(item_name)
    local spawn_data = {}
    local package_names = {}

    if item_slot_type == "melee" or item_slot_type == "ranged" then
        self._wielded_slot_type = item_slot_type
        local left_hand_unit = item_units.left_hand_unit
        local right_hand_unit = item_units.right_hand_unit
        local material_settings = item_units.material_settings
        local despawn_both_hands_units = right_hand_unit == nil or left_hand_unit == nil

        if left_hand_unit then
            local left_unit = left_hand_unit .. "_3p"
            spawn_data[#spawn_data + 1] = {
                left_hand = true,
                despawn_both_hands_units = despawn_both_hands_units,
                unit_name = left_unit,
                item_slot_type = item_slot_type,
                slot_index = slot_index,
                unit_attachment_node_linking = item_template.left_hand_attachment_node_linking.third_person,
                material_settings = material_settings
            }
            package_names[#package_names + 1] = left_unit
        end

        if right_hand_unit then
            local right_unit = right_hand_unit .. "_3p"
            if string.match(item_name, "dr_1h_throwing_axes") then
                right_unit = item_units.ammo_unit .. "_3p"
            end
            spawn_data[#spawn_data + 1] = {
                right_hand = true,
                despawn_both_hands_units = despawn_both_hands_units,
                unit_name = right_unit,
                item_slot_type = item_slot_type,
                slot_index = slot_index,
                unit_attachment_node_linking = item_template.right_hand_attachment_node_linking.third_person,
                material_settings = material_settings
            }

            if right_hand_unit ~= left_hand_unit then
                package_names[#package_names + 1] = right_unit
            end
        end
    elseif item_slot_type == "hat" then
        local unit = item_units.unit

        if unit then
            local attachment_slot_lookup_index = 1

            local attachment_slot_name = item_template.slots[attachment_slot_lookup_index]
            local hero_material_changes = item_template.character_material_changes
            spawn_data[#spawn_data + 1] = {
                unit_name = unit,
                item_slot_type = item_slot_type,
                slot_index = slot_index,
                unit_attachment_node_linking = item_template.attachment_node_linking[attachment_slot_name],
                hero_material_changes = hero_material_changes
            }
            package_names[#package_names + 1] = unit

            if hero_material_changes then
                package_names[#package_names + 1] = hero_material_changes.package_name
            end
        end
    end

    if #package_names > 0 then
        local item_info_by_slot = self._item_info_by_slot
        local previous_slot_data = item_info_by_slot[item_slot_type]

        if previous_slot_data then
            self:_destroy_item_units_by_slot(item_slot_type)
            self:_unload_item_packages_by_slot(item_slot_type)
        end

        item_info_by_slot[item_slot_type] = {
            name = item_name,
            package_names = package_names,
            spawn_data = spawn_data
        }

        self:_load_packages(package_names)
    end
end

VermitannicaPreviewer._unload_item_packages_by_slot = function (self, slot_type)
    local item_info_by_slot = self._item_info_by_slot

    if item_info_by_slot[slot_type] then
        local slot_type_data = item_info_by_slot[slot_type]
        local package_names = slot_type_data.package_names
        local package_manager = Managers.package
        local reference_name = "vermitannica"

        for _, package_name in ipairs(package_names) do
            if package_manager:can_unload(package_name) then
                package_manager:unload(package_name, reference_name)
            end
        end

        item_info_by_slot[slot_type] = nil
    end
end

VermitannicaPreviewer._poll_item_package_loading = function (self)
    local hero_unit = self.hero_unit

    if not Unit.alive(hero_unit) then
        return
    end

    if self._requested_hero_spawn_data then
        return
    end

    local reference_name = "vermitannica"
    local package_manager = Managers.package
    local item_info_by_slot = self._item_info_by_slot

    for slot_name, data in pairs(item_info_by_slot) do
        if not data.loaded then
            local package_names = data.package_names
            local all_packages_loaded = true

            for i = 1, #package_names, 1 do
                local package_name = package_names[i]

                if not package_manager:has_loaded(package_name, reference_name) then
                    all_packages_loaded = false

                    break
                end
            end

            if all_packages_loaded then
                data.loaded = true
                local item_name = data.name
                local spawn_data = data.spawn_data

                self:_spawn_item(item_name, spawn_data)
            end
        end
    end
end

VermitannicaPreviewer._handle_spawn_requests = function (self)
    if self._requested_hero_spawn_data then
        local data = self._requested_hero_spawn_data
        local frame_delay = data.frame_delay

        if frame_delay == 0 then
            local profile_name = data.profile_name
            local career_index = data.career_index
            local callback = data.callback
            local skin_name = data.skin_name

            self:_load_hero_unit(profile_name, career_index, callback, skin_name)

            self._requested_hero_spawn_data = nil
        else
            data.frame_delay = frame_delay - 1
        end
    end

    if self._requested_enemy_spawn_data then
        local data = self._requested_enemy_spawn_data
        local frame_delay = data.frame_delay


        if frame_delay == 0 then
            local enemy_name = data.enemy_name
            local callback = data.callback
            local camera_move_duration = data.camera_move_duration

            self:_load_enemy_unit(enemy_name, callback, camera_move_duration)

            self._requested_enemy_spawn_data = nil
        else
            data.frame_delay = frame_delay - 1
        end
    end
end

VermitannicaPreviewer._load_enemy_unit = function (self, enemy_name, callback, camera_move_duration)
    self:_unload_enemy_packages()

    camera_move_duration = camera_move_duration or 0.01

    self._camera_move_duration = camera_move_duration
    self._current_enemy_name = enemy_name

    local package_names = {}
    local enemy_alias = EnemyPackageLoaderSettings.alias_to_breed[enemy_name] or enemy_name

    local unit_name = "resource_packages/breeds/" .. enemy_alias
    package_names[#package_names + 1] = unit_name

    local data = {
        num_loaded_packages = 0,
        package_names = package_names,
        num_packages = #package_names,
        callback = callback,
        enemy_name = enemy_name
    }

    self:_load_packages(package_names)
    self._enemy_loading_package_data = data
end

VermitannicaPreviewer._load_hero_unit = function (self, profile_name, career_index, callback, skin_name)
    self.camera_xy_angle_target = DEFAULT_ANGLE

    self:_unload_hero_packages()
    self:_unload_item_packages()

    self._current_profile_name = profile_name

    local profile_index = FindProfileIndex(profile_name)
    local profile = SPProfiles[profile_index]
    local career = profile.careers[career_index]
    local career_name = career.name
    local skin_item = BackendUtils.get_loadout_item(career_name, "slot_skin")
    local item_data = skin_item and skin_item.data
    skin_name = skin_name or (item_data and item_data.name) or career.base_skin

    self._current_career_name = career_name
    self.hero_unit_skin_data = nil
    local package_names = {}
    local skin_data = Cosmetics[skin_name]
    local unit_name = skin_data.third_person

    package_names[#package_names + 1] = unit_name

    local material_changes = skin_data.material_changes
    if material_changes then
        local material_package = material_changes.package_name
        package_names[#package_names + 1] = material_package
    end

    local data = {
        num_loaded_packages = 0,
        career_name = career_name,
        skin_data = skin_data,
        career_index = career_index,
        package_names = package_names,
        num_packages = #package_names,
        callback = callback
    }

    self:_load_packages(package_names)

    self._hero_loading_package_data = data
end

VermitannicaPreviewer.request_spawn_hero_unit = function (self, profile_name, career_index, callback, camera_move_duration, skin_name, reset_camera)
    self._requested_hero_spawn_data = {
        frame_delay = 1,
        profile_name = profile_name,
        career_index = career_index,
        callback = callback,
        skin_name = skin_name,
        camera_move_duration = camera_move_duration
    }

    self:_clear_hero_units(reset_camera)
end

VermitannicaPreviewer.request_spawn_enemy_unit = function (self, enemy_name, callback, camera_move_duration, reset_camera)
    self._requested_enemy_spawn_data = {
        frame_delay = 1,
        enemy_name = enemy_name,
        callback = callback,
        camera_move_duration = camera_move_duration
    }

    self.waiting_for_state_machine = wait_for_state_machine[enemy_name]

    self:_clear_enemy_units()
end

VermitannicaPreviewer.request_browser_mode = function (self, browser_mode)
    self._browser_mode = browser_mode
    if not browser_mode then
        self.camera_enemy_xy_angle_target = -DEFAULT_ANGLE
        self.camera_xy_angle_target = DEFAULT_ANGLE
        self.camera_zoom_target = 0
        self.camera_z_pan_target = 0
        self.camera_x_pan_target = 0
        --self:_set_hero_visibility(true)
    elseif browser_mode == "enemy_browser" then
        self.camera_enemy_xy_angle_target = 0
        --self:_set_hero_visibility(false)
    elseif browser_mode == "hero_browser" then
        self.camera_xy_angle_target = (DEFAULT_ANGLE / 2)
        --self:_set_hero_visibility(true)
    end
end