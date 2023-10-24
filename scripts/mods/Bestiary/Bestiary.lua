local mod = get_mod("bestiary")
local statistics_list_name = script_data["eac-untrusted"] and "modded_list" or "official_list"
mod.statistics_list = mod:get(statistics_list_name) or {}

mod.on_unload = function()
    mod:set(statistics_list_name, mod.statistics_list)
end

--mod:dofile("scripts/mods/Bestiary/bestiary_view/bestiary_view")
mod:dofile("scripts/mods/Bestiary/HeroViewStateBestiary")
mod:dofile("scripts/mods/Bestiary/Bestiary_enemy_preview")

if IngameMenuKeymaps.win32 then
    IngameMenuKeymaps.win32.right_hold = {
        "mouse",
        "right",
        "held"
    }
    IngameMenuKeymaps.win32.shift_hold = {
        "keyboard",
        "left shift",
        "held"
    }
    IngameMenuKeymaps.win32.ctrl_hold = {
        "keyboard",
        "left ctrl",
        "held"
    }
end

local player_definitions = StatisticsDefinitions.player

player_definitions.damage_received_per_breed = { value = 0, name = "damage_received_per_breed" }
player_definitions.times_downed_per_breed = { value = 0, name = "times_downed_per_breed" }
player_definitions.slain_per_breed = { value = 0, name = "slain_per_breed" }
player_definitions.headshots_per_breed_ranged = { value = 0, name = "headshots_per_breed_ranged" }
player_definitions.headshots_per_breed_melee = { value = 0, name = "headshots_per_breed_melee" }
player_definitions.globadier_enemies_suffocated = { value = 0, name = "globadier_enemies_suffocated" }
player_definitions.warpfire_enemies_incinerated = { value = 0, name = "warpfire_enemies_incinerated" }
for breed_name, _ in pairs(PlayerBreeds) do
    player_definitions.slain_per_breed[breed_name] = {
        value = 0,
        name = breed_name
    }

    player_definitions.damage_received_per_breed[breed_name] = {
        value = 0,
        name = breed_name
    }

    player_definitions.times_downed_per_breed[breed_name] = {
        value = 0,
        name = breed_name
    }

    player_definitions.headshots_per_breed_ranged[breed_name] = {
        value = 0,
        name = breed_name
    }
    player_definitions.headshots_per_breed_melee[breed_name] = {
        value = 0,
        name = breed_name
    }
end
for breed_name, breed in pairs(Breeds) do
    player_definitions.slain_per_breed[breed_name] = {
        value = 0,
        name = breed_name
    }

    player_definitions.damage_received_per_breed[breed_name] = {
        value = 0,
        name = breed_name
    }

    player_definitions.times_downed_per_breed[breed_name] = {
        value = 0,
        name = breed_name
    }

    player_definitions.headshots_per_breed_ranged[breed_name] = {
        value = 0,
        name = breed_name
    }
    player_definitions.headshots_per_breed_melee[breed_name] = {
        value = 0,
        name = breed_name
    }
end

mod:command("cc", "Clears Chat History", function ()
    Managers.chat:clear_chat()
end)

--local view_data = {
--    view_name = "bestiary_view",
--    view_settings = {
--        init_view_function = function (ingame_ui_context)
--            return BestiaryView:new(ingame_ui_context)
--        end,
--        active = {
--            inn = true,
--            ingame = false
--        },
--        blocked_transitions = {
--            inn = {},
--            ingame = {}
--        }
--    },
--    view_transitions = {
--        open_bestiary_view = function (ingame_ui)
--            ingame_ui.current_view = "bestiary_view"
--        end,
--        close_bestiary_view = function (ingame_ui)
--            ingame_ui.current_view = nil
--        end
--    }
--}
--mod:register_view(view_data)


mod:hook(HeroView, "init", function (orig_func, self, ingame_ui_context)

    local result = orig_func(self, ingame_ui_context)

    local bestiary = {
        name = "bestiary",
        state_name = "HeroViewStateBestiary",
        hotkey_disabled = false,
        draw_background_world = false,
        camera_position = {
            0,
            0,
            0
        },
        camera_rotation = {
            0,
            0,
            0
        },
        contains_new_content = function ()
            return false
        end
    }
    local settings_by_screen = self._state_machine_params.settings_by_screen

    local found = false
    for index, screen in ipairs(settings_by_screen) do
        if screen.name == "bestiary" then
            found = true
            break
        end
    end
    if not found then table.insert(settings_by_screen, bestiary) end

    mod.ingame_ui_context = ingame_ui_context

    return result
end)

local function set_mod_stat (stat, how, ...)
    if not stat then return end
    local arg_n = select("#", ...)
    if not how then arg_n = arg_n - 1 end

    local stat_path = ""
    for i = 1, arg_n, 1 do
        local arg_value = select(i, ...)
        stat = stat[arg_value]
        stat_path = stat_path..tostring(arg_value)..(i < arg_n and "_" or "")
    end

    local local_stats = mod.statistics_list
    local current_value = local_stats[stat_path] or 0
    local new_value
    if how == "increment" then
        new_value = current_value + 1
    elseif how == "decrement" then
        new_value = current_value - 1
    else
        new_value = current_value + select(arg_n + 1, ...)
    end

    local_stats[stat_path] = new_value
    --mod:set(mod.statistics_list, local_stats)
    mod.statistics_list = local_stats
end

mod:hook_safe(StatisticsDatabase, "increment_stat", function (self, id, ...)
    local arg_n = select("#", ...)
    local args = ""
    for i = 1, arg_n, 1 do
        args = args .. select(i, ...) .. (i < arg_n and "_" or "")
    end
    set_mod_stat(self.statistics[id], "increment", ...)
end)

mod:hook_safe(StatisticsDatabase, "decrement_stat", function (self, id, ...)
    set_mod_stat(self.statistics[id], "decrement", ...)
end)

mod:hook_safe(StatisticsDatabase, "modify_stat_by_amount", function (self, id, ...)
    set_mod_stat(self.statistics[id], nil, ...)
end)

mod:hook_safe(QuestSettings, "check_num_enemies_killed_by_poison", function (unit, unit_extension)
    set_mod_stat(mod.stats_id, "increment", "globadier_enemies_suffocated")
end)

mod:hook_safe(QuestSettings, "check_num_enemies_killed_by_warpfire", function (unit, attacker_unit)
    set_mod_stat(mod.stats_id, "increment", "warpfire_enemies_incinerated")
end)

mod:hook_safe(DeathSystem, "kill_unit", function (self, unit, killing_blow)
    local player_manager = Managers.player
    local player = player_manager:local_player()
    local player_unit = player.player_unit

    if player_unit == unit then
        local status_extension = ScriptUnit.extension(player_unit, "status_system")

        if not status_extension:is_knocked_down() then
            local attacker_unit = killing_blow[DamageDataIndex.ATTACKER]
            attacker_unit = AiUtils.get_actual_attacker_unit(attacker_unit)

            if Unit.alive(attacker_unit) then
                local breed = ( Unit.has_data(attacker_unit, "breed") == true and Unit.get_data(attacker_unit, "breed") ) or nil

                if breed ~= nil then
                    local breed_name = breed.name
                    mod.stats_db:increment_stat(mod.stats_id, "times_downed_per_breed", breed_name)
                end
            end
        end
    end

end)

mod:hook_safe(PlayerUnitHealthExtension, "knock_down", function (self, unit)
    local player_manager = Managers.player
    local player = player_manager:local_player()
    local player_unit = player.player_unit

    if player_unit == unit then
        local attacker_unit = mod.attacker_unit

        if Unit.alive(attacker_unit) then
            local breed = ( Unit.has_data(attacker_unit, "breed") == true and Unit.get_data(attacker_unit, "breed") ) or nil

            if breed ~= nil then
                local breed_name = breed.name
                mod.stats_db:increment_stat(mod.stats_id, "times_downed_per_breed", breed_name)
            end
        end

    end
end)

mod:hook_safe(StatisticsUtil, "register_kill", function (victim_unit, damage_data, stats_db)
    local player_manager = Managers.player
    local player = player_manager:local_player()
    local player_unit = player.player_unit

    local attacker_unit = AiUtils.get_actual_attacker_unit(damage_data[DamageDataIndex.ATTACKER])

    if Unit.alive(attacker_unit) and attacker_unit == player_unit then
        local breed = (Unit.has_data(victim_unit, "breed") == true and Unit.get_data(victim_unit, "breed") ) or nil

        if breed ~= nil then
            local breed_name = breed.name
            local hit_zone = damage_data[DamageDataIndex.HIT_ZONE]
            local damage_source = damage_data[DamageDataIndex.DAMAGE_SOURCE_NAME]
            local master_list_item = rawget(ItemMasterList, damage_source)

            stats_db:increment_stat(mod.stats_id, "slain_per_breed", breed_name)

            if master_list_item then
                local slot_type = master_list_item.slot_type

                if hit_zone == "head" then
                    if slot_type == "melee" then
                        stats_db:increment_stat(mod.stats_id, "headshots_per_breed_melee", breed_name)
                    elseif slot_type == "ranged" then
                        stats_db:increment_stat(mod.stats_id, "headshots_per_breed_ranged", breed_name)
                    end
                end
            end
        end
    end
end)

mod:hook_safe(StatisticsUtil, "register_damage", function (victim_unit, damage_data, stats_db)
    local player_manager = Managers.player
    local player = player_manager:local_player()
    local player_unit = player.player_unit

    local attacker_unit = damage_data[DamageDataIndex.ATTACKER]
    attacker_unit = AiUtils.get_actual_attacker_unit(attacker_unit)

    if Unit.alive(attacker_unit) and victim_unit == player_unit then
        local status_extension = ScriptUnit.extension(player_unit, "status_system")

        if not status_extension:is_knocked_down() then
            mod.attacker_unit = attacker_unit
            local breed = ( Unit.has_data(attacker_unit, "breed") == true and Unit.get_data(attacker_unit, "breed") ) or nil

            if breed ~= nil then
                local breed_name = breed.name

                local damage_amount = damage_data[DamageDataIndex.DAMAGE_AMOUNT]

                stats_db:modify_stat_by_amount(mod.stats_id, "damage_received_per_breed", breed_name, damage_amount)
            end
        end
    end
end)

mod:hook_safe(StateInGameRunning, "update", function (self)
    mod.ingame_ui_context = self.ingame_ui_context
    mod.stats_db = self.ingame_ui_context.statistics_db
    mod.stats_id = self.ingame_ui_context.stats_id
end)

mod.on_all_mods_loaded = function ()
    mod.friend_mods = {}
    mod.friend_mods.deathwish = get_mod("Deathwish")
end

mod.open_bestiary_view = function ()
    if not mod.ingame_ui_context or not mod.ingame_ui_context.is_in_inn then
        return
    else
        local ingame_ui = mod.ingame_ui_context.ingame_ui
        ingame_ui:transition_with_fade("hero_view", {
            menu_state_name = "bestiary"
        })
    end
end
mod:command("bestiary", "Opens Bestiary (Enemy Compendium)", mod.open_bestiary_view)

mod.init_stats = function ()
    if not mod:get("stats_initialized") then
        local local_stats = mod.statistics_list

        for breed_name, breed in pairs(Breeds) do
            local spb = "slain_per_breed_"..breed_name
            local kpb = "kills_per_breed_"..breed_name
            if not local_stats[spb] then
                local_stats[spb] = local_stats[kpb] or 0
            else
                local_stats[spb] = local_stats[spb] + (local_stats[kpb] or 0)
            end
        end
        mod.statistics_list = local_stats

        mod:set("stats_initialized", true)
    end
end

mod.init_stats()

mod:hook_safe(HeroViewStateOverview, "_handle_input", function (self, dt, t)
    local bestiary_button = self._widgets_by_name.bestiary_button
    UIWidgetUtils.animate_default_button(bestiary_button, dt)

    if self:_is_button_hover_enter(bestiary_button) then
        self:play_sound("play_gui_equipment_button_hover")
    end

    if self:_is_button_pressed(bestiary_button) then
        self:requested_screen_change_by_name("bestiary")
    end
end)

mod:hook(HeroViewStateOverview, "create_ui_elements", function (orig_func, self, params)
    mod:hook_enable(UISceneGraph, "init_scenegraph")

    local result = orig_func(self, params)

    local bestiary_button_widget_definition = UIWidgets.create_default_button("bestiary_button", { 380, 42 }, nil, nil, "Bestiary", 24, nil, "button_detail_04", 34)
    local bestiary_button_widget = UIWidget.init(bestiary_button_widget_definition)
    self._widgets[#self._widgets + 1] = bestiary_button_widget
    self._widgets_by_name["bestiary_button"] = bestiary_button_widget

    mod:hook_disable(UISceneGraph, "init_scenegraph")

    return result
end)

mod:hook(UISceneGraph, "init_scenegraph", function (orig_func, scenegraph)
    scenegraph.bestiary_button = {
        vertical_alignment = "bottom",
        horizontal_alignment = "right",
        parent = "window",
        size = {
            380,
            42
        },
        position = {
            -150,
            -16,
            10
        }
    }

    return orig_func(scenegraph)
end)

mod:hook_disable(UISceneGraph, "init_scenegraph")