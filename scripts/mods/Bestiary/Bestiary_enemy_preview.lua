local mod = get_mod("bestiary")

local DEFAULT_ANGLE = math.degrees_to_radians(0)
local stop_animating = false


mod:hook_safe(MenuWorldPreviewer, "on_enter", function (self)
    self._bestiary_camera_default_position = {
        z = 1,
        x = 0,
        y = 2.5
    }

    local rotation = Quaternion.axis_angle(Vector3(0, 0, 0.1), math.pi)
    ScriptCamera.set_local_rotation(self.camera, rotation)

    self.camera_z_pan_current = 0
    self.camera_z_pan_target = 0

    self.camera_zoom_current = 1.5
    self.camera_zoom_target = 1.5

end)

MenuWorldPreviewer.request_spawn_enemy_unit = function (self, enemy_name, callback, inventory_config, reset_camera)
    self._requested_enemy_spawn_data = {
        frame_delay = 3,
        enemy_name = enemy_name,
        callback = callback,
        inventory_config = inventory_config
    }

    self:clear_units(reset_camera)
end

MenuWorldPreviewer.prepare_exit_bestiary = function(self)
    self:clear_units_bestiary()
end

MenuWorldPreviewer.clear_units_bestiary = function(self, reset_camera, only_weapons)
    local world = self.world

    if self._weapon_units ~= nil then

        for i, unit_data in pairs(self._weapon_units) do
            World.destroy_unit(world, unit_data.weapon_unit)
        end

        --World.destroy_unit(world, self.weapon_unit)

        table.clear(self._weapon_units)
        self._weapon_units = nil
    end

    if self.character_unit ~= nil and not only_weapons then
        World.destroy_unit(world, self.character_unit)

        self.character_unit = nil

        if reset_camera then
            local default_animation_data = self._default_animation_data

            self:set_character_axis_offset("x", default_animation_data.x.value, 0.5, math.easeOutCubic)
            self:set_character_axis_offset("y", default_animation_data.y.value, 0.5, math.easeOutCubic)
            self:set_character_axis_offset("z", default_animation_data.z.value, 0.5, math.easeOutCubic)
        end
    end

    self._done_linking_units = false


end

MenuWorldPreviewer.update_enemy = function (self, dt, t, input_disabled)
    local character_unit = self.character_unit

    if character_unit then
        if self.camera_xy_angle_target > math.pi * 2 then
            self.camera_xy_angle_current = self.camera_xy_angle_current - math.pi * 2
            self.camera_xy_angle_target = self.camera_xy_angle_target - math.pi * 2
        end

        Unit.set_unit_visibility(character_unit, true)

        local character_xy_angle_new = math.lerp(self.camera_xy_angle_current, self.camera_xy_angle_target, 0.1)
        self.camera_xy_angle_current = character_xy_angle_new
        local player_rotation = Quaternion.axis_angle(Vector3(0, 0, 1), -character_xy_angle_new)

        Unit.set_local_rotation(character_unit, 0, player_rotation)

        if not stop_animating then
            -- Temporary hack to get warpfire throwers and ratling gunners to look where they're facing
            if self.enemy_name == "skaven_warpfire_thrower" or self.enemy_name == "skaven_ratling_gunner" then
                Unit.animation_event(character_unit, "attack_shoot_align")
            end

            if self._requested_animation then
                if self._requested_animation == "ragdoll" and self.enemy_name == "skaven_grey_seer" then
                    Unit.animation_event(character_unit, "death_backward")
                else
                    Unit.animation_event(character_unit, self._requested_animation)
                end

                self._requested_animation = nil
            end
            stop_animating = true
        end
    end

    if self.camera_z_pan_target < -1.25 then
        self.camera_z_pan_target = -1.25
    elseif self.camera_z_pan_target > 0.75 then
        self.camera_z_pan_target = 0.75
    end

    if self.camera_zoom_target > 1.50 then
        self.camera_zoom_target = 1.50
    elseif self.camera_zoom_target < 0.40 then
        self.camera_zoom_target = 0.40
    end

    local camera_z_pan_new = math.lerp(self.camera_z_pan_current, self.camera_z_pan_target, 0.1)
    self.camera_z_pan_current = camera_z_pan_new

    local camera_zoom_new = math.lerp(self.camera_zoom_current, self.camera_zoom_target, 0.1)
    self.camera_zoom_current = camera_zoom_new

    --self:_update_camera_animation_data(self._camera_character_position_animation_data, dt)
    --self:_update_camera_animation_data(self._camera_position_animation_data, dt)
    --self:_update_camera_animation_data(self._camera_rotation_animation_data, dt)

    local camera_default_position = self._bestiary_camera_default_position
    local camera_position_new = Vector3.zero()
    camera_position_new.x = camera_zoom_new * camera_default_position.x
    camera_position_new.y = camera_zoom_new * camera_default_position.y
    camera_position_new.z = camera_default_position.z - camera_z_pan_new
    local lookat_target = Vector3(0, 0, camera_position_new.z)
    local direction = Vector3.normalize(lookat_target - camera_position_new)
    local rotation = Quaternion.look(direction)

    ScriptCamera.set_local_position(self.camera, camera_position_new)
    ScriptCamera.set_local_rotation(self.camera, rotation)

    --local camera_position_animation_data = self._camera_position_animation_data
    --local camera_character_position_animation_data = self._camera_character_position_animation_data
    --local camera_gamepad_offset_data = self._camera_gamepad_offset_data
    --camera_position_new.x = camera_position_new.x + camera_position_animation_data.x.value + camera_character_position_animation_data.x.value + camera_gamepad_offset_data[1]
    --camera_position_new.y = camera_position_new.y + camera_position_animation_data.y.value + camera_character_position_animation_data.y.value + camera_gamepad_offset_data[2] + 0.65
    --camera_position_new.z = camera_position_new.z + camera_position_animation_data.z.value + camera_character_position_animation_data.z.value + camera_gamepad_offset_data[3] + 0.5

    local input_service = self.input_manager:get_service("hero_view")

    if not input_disabled then
        self:handle_mouse_input_bestiary(input_service, dt)
        self:handle_controller_input(input_service, dt)
    end
end

local mouse_pos_temp = {}
MenuWorldPreviewer.handle_mouse_input_bestiary = function (self, input_service, dt)
    local character_unit = self.character_unit

    if character_unit == nil then
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

    if is_hover then
        if input_service:get("left_press") then
            self.is_rotating_unit = true
            self.last_mouse_position = nil
        elseif input_service:get("right_press") then
            self.camera_xy_angle_target = DEFAULT_ANGLE
        elseif input_service:get("scroll_axis") then
            self.is_rotating_unit = true
        end
    end

    local is_rotating_unit = self.is_rotating_unit
    local left_mouse_hold = input_service:get("left_hold")
    local scroll_wheel = input_service:get("scroll_axis")
    local shift_hold = input_service:get("shift_hold")

    if is_rotating_unit and left_mouse_hold then
        if self.last_mouse_position then
            if shift_hold then
                if left_mouse_hold then
                    self.camera_z_pan_target = self.camera_z_pan_target - (mouse.y - self.last_mouse_position[2]) * 0.005
                end
            else
                if left_mouse_hold then
                    self.camera_xy_angle_target = self.camera_xy_angle_target - (mouse.x - self.last_mouse_position[1]) * 0.01
                end
            end
        end

        mouse_pos_temp[1] = mouse.x
        mouse_pos_temp[2] = mouse.y
        self.last_mouse_position = mouse_pos_temp
    elseif is_hover and is_rotating_unit and scroll_wheel then
        self.camera_zoom_target = self.camera_zoom_target - (scroll_wheel[2]) * 0.25
    elseif is_rotating_unit then
        self.is_rotating_unit = false
    end
end

MenuWorldPreviewer.post_update_enemy = function (self, dt)
    self:_update_units_visibility_bestiary(dt)
    self:_handle_enemy_spawn_request()
    self:_poll_enemy_package_loading()
end

MenuWorldPreviewer._update_units_visibility_bestiary = function (self, dt)

    if Unit.alive(self.character_unit) and (not self._wait_for_force_unhide or self._force_unhide_character) then
        local unit_visibility_frame_delay = self.unit_visibility_frame_delay

        if self._weapon_units ~= nil and not self._done_linking_units then
            for i, unit_data in pairs(self._weapon_units) do
                local wielded_node = unit_data.attachment_node_linking.wielded
                local unwielded_node = unit_data.attachment_node_linking.unwielded
                local linking_data = unit_data.attachment_node_linking

                if wielded_node then
                    linking_data = (self.should_unwield and self.enemy_name == "beastmen_ungor_archer" and unwielded_node[1]) or wielded_node[1]
                    local node_index = Unit.node(self.character_unit, linking_data.source)
                    local modifier = self.enemy_name == "skaven_loot_rat" and 1 or 0
                    World.link_unit(self.world, unit_data.weapon_unit, linking_data.target + modifier, self.character_unit, node_index)
                elseif linking_data then
                    AttachmentUtils.link(self.world, self.character_unit, unit_data.weapon_unit, unit_data.attachment_node_linking)
                else
                    World.destroy_unit(self.world, self._weapon_units[i].weapon_unit)
                    self._weapon_units[i] = nil
                end

                self._done_linking_units = true
            end

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

        if self.character_unit_hidden and Unit.alive(self.character_unit) then

            Unit.flow_event(self.character_unit, "lua_spawn_attachments")

            local skin_data = self.character_unit_skin_data
            local material_changes = skin_data and skin_data.material_changes

            if material_changes then
                local third_person_changes = material_changes.third_person
                local flow_unit_attachments = Unit.get_data(self.character_unit, "flow_unit_attachments") or {}

                for slot_name, material_name in pairs(third_person_changes) do
                    for _, unit in pairs(flow_unit_attachments) do
                        Unit.set_material(unit, slot_name, material_name)
                    end
                end
            end
            
            --[[ Remove following in 1.2 ]]
            if mod.pre_1_2_0 then
                local attachment_flow_events = self._attachment_flow_events or {}

                for unit, events in pairs(attachment_flow_events) do
                    if Unit.alive(unit) then
                        for i = 1, #events, 1 do
                            local event_name = events[i]

                            Unit.flow_event(unit, event_name)
                        end
                    end
                end

                table.clear(attachment_flow_events)
            end
            --[[ End remove ]]
            
            self.character_unit_hidden = false
        end

        self._force_unhide_character = false
    end
end

MenuWorldPreviewer._handle_enemy_spawn_request = function (self)
    if self._requested_enemy_spawn_data then
        local requested_enemy_spawn_data  = self._requested_enemy_spawn_data
        local frame_delay = requested_enemy_spawn_data.frame_delay

        if frame_delay == 0 then
            local enemy_name = requested_enemy_spawn_data.enemy_name
            local callback = requested_enemy_spawn_data.callback
            local inventory_config = requested_enemy_spawn_data.inventory_config

            self:_load_enemy_unit(enemy_name, callback, inventory_config)

            self._requested_enemy_spawn_data = nil
        else
            requested_enemy_spawn_data.frame_delay = frame_delay - 1
        end
    end
end

MenuWorldPreviewer._load_enemy_unit = function(self, enemy_name, callback, inventory_config)
    self.camera_xy_angle_target = DEFAULT_ANGLE
    self.camera_zoom_target = 1.5

    self:_unload_all_packages()

    local package_names = {}

    local enemy_alias = EnemyPackageLoaderSettings.alias_to_breed[enemy_name] or enemy_name

    local unit_name = "resource_packages/breeds/"..enemy_alias
    package_names[#package_names + 1] = unit_name

    local data = {
        num_loaded_packages = 0,
        package_names = package_names,
        num_packages = #package_names,
        callback = callback,
        enemy_name = enemy_name,
        inventory_config = inventory_config
    }

    self:_load_packages(package_names)
    self._enemy_loading_package_data = data
end

MenuWorldPreviewer._unload_all_packages_bestiary = function (self)
    self:_unload_enemy_packages()
    self:_unload_all_items()
end

MenuWorldPreviewer._poll_enemy_package_loading = function (self)
    local data = self._enemy_loading_package_data

    if not data or data.loaded then
        return
    end

    local requested_enemy_spawn_data = self._requested_enemy_spawn_data

    if requested_enemy_spawn_data then
        return
    end

    local reference_name = self:_reference_name()
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
        self:_spawn_enemy_unit(data.enemy_name, data.inventory_config)

        local callback = data.callback

        if callback then
            callback()
        end

        data.loaded = true
    end
end

MenuWorldPreviewer._spawn_enemy_unit = function (self, enemy_name, inventory_config)
    local world = self.world

    enemy_name = EnemyPackageLoaderSettings[enemy_name] or enemy_name
    stop_animating = false

    local unit_name = Breeds[enemy_name].base_unit
    local size_variation_range = Breeds[enemy_name].size_variation_range
    local size_vector = Vector3(1, 1, 1)
    if size_variation_range then
        local size_normalized = Math.random()
        local size = math.lerp(size_variation_range[1], size_variation_range[2], size_normalized)
        size_vector = Vector3(size, size, size)
    end

    local character_unit = World.spawn_unit(world, unit_name)
    Unit.set_local_scale(character_unit, 0, size_vector)

    Unit.set_unit_visibility(character_unit, false)

    self._hidden_units[character_unit] = true
    self.character_unit_hidden = true
    self.character_unit = character_unit

    self._current_inventory_config = inventory_config

    self:_spawn_weapon_units(inventory_config)

    self.unit_visibility_frame_delay = 5

    if Unit.has_lod_object(character_unit, "lod") then
        local lod_object = Unit.lod_object(character_unit, "lod")

        LODObject.set_static_select(lod_object, 0)
    end

    local enemy_camera_positions = self._character_camera_positions

    self._camera_current_position = enemy_camera_positions[enemy_name] or self.camera_default_position

    self.character_look_target = {
        0,
        3,
        1
    }
    self.character_look_current = self.character_look_target

    --local look_target = Vector3Aux.unbox(self.character_look_target)
    --local look_direction_anim_var = Unit.animation_find_variable(character_unit, "aim_target")
    --
    --Unit.animation_set_constraint_target(character_unit, look_direction_anim_var, look_target)
end

MenuWorldPreviewer._spawn_weapon_units = function (self, inventory_config)
    if not inventory_config or not Managers.package:has_loaded("resource_packages/inventory", "HeroViewStateBestiary")then
        return
    end

    local categories = {}
    if inventory_config.multiple_configurations then
        categories = InventoryConfigurations[inventory_config.multiple_configurations[2]].items      --[[ TODO: Wire up to buttons to change displayed config  ]]
    else
        categories = inventory_config.items
    end

    self._previous_animation = "idle"
    if inventory_config.anim_state_event then
        self:request_animation(inventory_config.anim_state_event)
        self._previous_animation = inventory_config.anim_state_event
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
    self._weapon_units = weapon_units

end

MenuWorldPreviewer.spawn_enemy_unit = function (self, enemy_name, callback, inventory_config)
    self.enemy_name = enemy_name
    local reset_camera = false

    self:request_spawn_enemy_unit(enemy_name, callback, inventory_config, reset_camera)
end

MenuWorldPreviewer.request_animation = function (self, requested_animation)
    self._requested_animation = requested_animation
    stop_animating = false
end
