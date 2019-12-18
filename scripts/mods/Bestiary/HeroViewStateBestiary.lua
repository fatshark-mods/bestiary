local mod = get_mod("bestiary")

local definitions = dofile("scripts/mods/Bestiary/Bestiary_widget_definitions")
local widget_definitions = definitions.widgets
local viewport_widget_definition = definitions.viewport_widget
local animation_definitions = definitions.animation_definitions
local scenegraph_definition = definitions.scenegraph_definition
local skaven_icons = definitions.skaven_icon_slots
local chaos_icons = definitions.chaos_icon_slots
local beastmen_icons = definitions.beastmen_icon_slots
local enemy_definitions = definitions.enemy_info
local camera_position_by_enemy = definitions.camera_position_by_enemy

local DO_RELOAD = false

local difficulty_list = {
    "",
    "Recruit",
    "Veteran",
    "Champion",
    "Legend",
    "Cataclysm",
    "Cataclysm 2",
    "Cataclysm 3"
}

HeroViewStateBestiary = class(HeroViewStateBestiary)
HeroViewStateBestiary.NAME = "HeroViewStateBestiary"

HeroViewStateBestiary.on_enter = function (self, params)
    print("[HeroViewState] Enter Substate HeroViewStateBestiary")

    self.parent = params.parent
    local ingame_ui_context = params.ingame_ui_context
    self.ingame_ui_context = ingame_ui_context
    self.ui_renderer = ingame_ui_context.ui_renderer
    self.ui_top_renderer = ingame_ui_context.ui_top_renderer
    self.input_manager = ingame_ui_context.input_manager
    self.voting_manager = ingame_ui_context.voting_manager
    self.profile_synchronizer = ingame_ui_context.profile_synchronizer
    self.statistics_db = ingame_ui_context.statistics_db
    self.render_settings = {
        snap_pixel_positions = true
    }
    self.wwise_world = params.wwise_world
    self.ingame_ui = ingame_ui_context.ingame_ui
    self._enemy_info = enemy_definitions

    self.world_previewer = params.world_previewer
    self.platform = PLATFORM
    local player_manager = Managers.player
    local local_player = player_manager:local_player()
    self._stats_id = local_player:stats_id()
    self.player_manager = player_manager
    self.peer_id = ingame_ui_context.peer_id
    self.local_player_id = ingame_ui_context.local_player_id
    self.player = local_player
    local profile_index = self.profile_synchronizer:profile_by_peer(self.peer_id, self.local_player_id)
    local profile_settings = SPProfiles[profile_index]
    local display_name = profile_settings.display_name
    local hero_attributes = Managers.backend:get_interface("hero_attributes")
    local career_index = hero_attributes:get(display_name, "career")
    self.hero_name = display_name
    self.career_index = career_index
    self.profile_index = profile_index
    self.is_server = self.parent.is_server
    self._animations = {}
    self._ui_animations = {}
    self._variation_index = 1

    self:create_ui_elements(params)

    self._deathwish_active = (mod.friend_mods.deathwish and Managers.vmf.persistent_tables.Deathwish.Deathwish.active)


    --[[if params.initial_state then
        params.initial_state = nil

        self:_start_transition_animation("on_enter", "on_enter")
    end--]]

    self:play_sound("hud_in_inventory_state_on")
end

HeroViewStateBestiary.create_ui_elements = function(self, params)
    if self._viewport_widget then
        UIWidget.destroy(self.ui_renderer, self._viewport_widget)

        self._viewport_widget = nil
    end

    self.ui_scenegraph = UISceneGraph.init_scenegraph(scenegraph_definition)

    local widgets = {}
    local widgets_by_name = {}
    for name, widget_definition in pairs(widget_definitions) do
        if widget_definition then
            local widget = UIWidget.init(widget_definition)
            widgets[#widgets + 1] = widget
            widgets_by_name[name] = widget
        end
    end
    self._widgets = widgets
    self._widgets_by_name = widgets_by_name

    self:_clear_enemy_info()
    self._difficulty_index = mod:get("difficulty_index") or 1
    self._level_package_name = viewport_widget_definition.style.viewport.level_package_name
    self._inventory_package_name = "resource_packages/inventory"
    self._breed_common_package_name = "resource_packages/breeds_common_resources"

    Managers.package:load(self._level_package_name, "HeroViewStateBestiary")
    Managers.package:load(self._inventory_package_name, "HeroViewStateBestiary")

    self._show_loading_overlay = true

    UIRenderer.clear_scenegraph_queue(self.ui_renderer)

    self.ui_animator = UIAnimator:new(self.ui_scenegraph, animation_definitions)
end

HeroViewStateBestiary.update = function(self, dt, t)
    if DO_RELOAD then
        DO_RELOAD = false

        self:create_ui_elements()
    end

    local input_service = (self._input_blocked and fake_input_service) or self:input_service()

    self:draw(input_service, dt)

    local transitioning = self.parent:transitioning()
    local wanted_state = self:_wanted_state()

    if self.world_previewer then
        local anim_reset_delay = self._animation_reset_delay
        if anim_reset_delay then
            if anim_reset_delay == 0 then
                self._animation_reset_delay = nil
                self.enemy_name = nil
            else
                self._animation_reset_delay = anim_reset_delay - 1
            end
        end

        self.world_previewer:update_enemy(dt, t, false)
    end

    if not self._transition_timer then
       if not transitioning then
            if self:_has_active_level_vote() then
                local ignore_sound_on_close_menu = true

                self:close_menu(ignore_sound_on_close_menu)
            else
                self:_handle_input(dt, t)
            end
        end

        if wanted_state or self._new_state then
            self.parent:clear_wanted_state()

            return wanted_state or self._new_state
        end
    end
end

HeroViewStateBestiary.post_update = function (self, dt)
    if not self._viewport_widget and self:_initial_packages_loaded() then
        self._viewport_widget = UIWidget.init(viewport_widget_definition)
        self._fadeout_loading_overlay = true
    end

    --self:_update_loading_overlay_fadeout_animation(dt)    // TODO

    if not self.initialized and self._viewport_widget then
        local world_previewer = MenuWorldPreviewer:new(self.ingame_ui_context, camera_position_by_enemy, "bestiary")

        world_previewer:on_enter(self._viewport_widget, "bestiary")

        self.world_previewer = world_previewer
        self.initialized = true
    end

    if self.world_previewer then
        if self.enemy_unit_spawned then
            self:_update_enemy_sync()
        end

        self.world_previewer:post_update_enemy(dt)
    end

    self.ui_animator:update(dt)
    self:_update_animations(dt)

end

HeroViewStateBestiary._initial_packages_loaded = function(self)
    local level_package_loaded = Managers.package:has_loaded(self._level_package_name, "HeroViewStateBestiary")
    local inventory_package_loaded = Managers.package:has_loaded(self._inventory_package_name, "HeroViewStateBestiary")

    return level_package_loaded and inventory_package_loaded
end

HeroViewStateBestiary._update_enemy_sync = function (self)
    if self.enemy_name ~= self.requested_enemy_name then
        self.world_previewer:clear_units_bestiary()
        self.enemy_name = self.requested_enemy_name
        self._animation_reset_delay = nil
        self:spawn_enemy()

    end
end

HeroViewStateBestiary.spawn_enemy = function (self)
    local world_previewer = self.world_previewer

    if not world_previewer then
        return
    end

    self.enemy_unit_spawned = false

    local function callback()
        self.enemy_unit_spawned = true
    end

    local enemy_info = self._enemy_info[self.enemy_name] or {}

    world_previewer:spawn_enemy_unit(self.enemy_name, callback, enemy_info.inventory_config)
end

HeroViewStateBestiary.draw = function (self, input_service, dt)
    local ui_renderer = self.ui_renderer
    local ui_scenegraph = self.ui_scenegraph
    local render_settings = self.render_settings

    if self._viewport_widget then
        UIRenderer.begin_pass(ui_renderer, ui_scenegraph, input_service, dt, nil, self.render_settings)
        UIRenderer.draw_widget(ui_renderer, self._viewport_widget)
        UIRenderer.end_pass(ui_renderer)
    end

    UIRenderer.begin_pass(ui_renderer, ui_scenegraph, input_service, dt, nil, render_settings)

    local snap_pixel_positions = render_settings.snap_pixel_positions
    local alpha_multiplier = render_settings.alpha_multiplier or 1

    for _, widget in ipairs(self._widgets) do
        if widget.snap_pixel_positions ~= nil then
            render_settings.snap_pixel_positions = widget.snap_pixel_positions
        end

        render_settings.alpha_multiplier = widget.alpha_multiplier or alpha_multiplier

        UIRenderer.draw_widget(ui_renderer, widget)

        render_settings.snap_pixel_positions = snap_pixel_positions
    end

    UIRenderer.end_pass(ui_renderer)

    render_settings.alpha_multiplier = alpha_multiplier
end

HeroViewStateBestiary.play_sound = function (self, event)
    self.parent:play_sound(event)
end

HeroViewStateBestiary.input_service = function (self)
    return self.parent:input_service()
end

HeroViewStateBestiary._wanted_state = function (self)
    local new_state = self.parent:wanted_state()

    return new_state
end

HeroViewStateBestiary.close_menu = function (self, ignore_sound_on_close_menu)
    if not ignore_sound_on_close_menu then
        self:play_sound("Play_gui_achivments_menu_close")
    end

    ignore_sound_on_close_menu = true

    self.parent:close_menu(nil, ignore_sound_on_close_menu)
end

HeroViewStateBestiary._has_active_level_vote = function (self)
    local voting_manager = self.voting_manager
    local active_vote_name = voting_manager:vote_in_progress()
    local is_mission_vote = active_vote_name == "game_settings_vote" or active_vote_name == "game_settings_deed_vote"

    return is_mission_vote and not voting_manager:has_voted(Network.peer_id())
end

HeroViewStateBestiary._handle_input = function (self, dt, t)
    local esc_pressed = self:input_service():get("toggle_menu")
    local widgets_by_name = self._widgets_by_name
    local exit_button = widgets_by_name.exit_button
    local difficulty_button = widgets_by_name.difficulty_button
    local breed_cycle_button = widgets_by_name.breed_cycle_button
    local kill_button = widgets_by_name.kill_button

    if self:_is_tab_hovered(widgets_by_name.enemy_icons_skaven) or self:_is_tab_hovered(widgets_by_name.enemy_icons_chaos) then
        self:play_sound("play_gui_hero_select_hero_hover")
    end

    local enemy_index, enemy_race = self:_is_enemy_tab_selected()

    if enemy_index then
        self:_select_enemy_tab_by_index(enemy_index, enemy_race, true)
    end

    if self:_is_button_hover_enter(exit_button) or self:_is_button_hover_enter(difficulty_button) or self:_is_button_hover_enter(breed_cycle_button) then
        self:play_sound("play_gui_equipment_button_hover")
    end


    if esc_pressed or self:_is_button_pressed(exit_button) then
        self:play_sound("Play_hud_hover")
        self:close_menu()

        return
    end

    if self:_is_button_pressed(difficulty_button) then
        self:play_sound("Play_hud_hover")
        self:_change_difficulty()
    end

    if self:_is_button_pressed(breed_cycle_button) then
        self:play_sound("Play_hud_hover")
        self:_change_unit_variation()
    end

    if self:_is_button_pressed(kill_button) then
        self:play_sound("Play_hud_hover")
        self:_kill_enemy()
    end

    if (mod.friend_mods and mod.friend_mods.deathwish) and self._deathwish_active ~= Managers.vmf.persistent_tables.Deathwish.Deathwish.active then
        self._deathwish_active = Managers.vmf.persistent_tables.Deathwish.Deathwish.active
        self:_display_enemy_info()
    end

    self:_handle_tab_hover(widgets_by_name.enemy_icons_skaven, "icon")
    self:_handle_tab_hover(widgets_by_name.enemy_icons_chaos, "icon")
end

HeroViewStateBestiary._kill_enemy = function (self)
    local world_previewer = self.world_previewer
    if world_previewer then
        world_previewer:request_animation("ragdoll")
        self._animation_reset_delay = 175
    end
end

HeroViewStateBestiary._change_difficulty = function (self)
    if self._difficulty_index >= #Difficulties then
        self._difficulty_index = 1
    else
        self._difficulty_index = self._difficulty_index + 1
    end

    mod:set("difficulty_index", self._difficulty_index)
    self:_display_enemy_info()

end

HeroViewStateBestiary._change_unit_variation = function (self)
    local slots_to_use = self:_get_slots_to_use()
    local enemy_names = slots_to_use[self._enemy_index][2]

    if type(enemy_names) == "table" then     -- Enemy has variations or more than one unit
        if self._variation_index >= #enemy_names then
            self._variation_index = 1
        else
            self._variation_index = self._variation_index + 1
        end

        self.requested_enemy_name = enemy_names[self._variation_index]
        self:_display_enemy_info()
    end
end

HeroViewStateBestiary._is_button_hover_enter = function (self, widget)
    local content = widget.content
    local hotspot = content.button_hotspot

    return hotspot.on_hover_enter
end

HeroViewStateBestiary._is_button_hover_exit = function (self, widget)
    local content = widget.content
    local hotspot = content.button_hotspot

    return hotspot.on_hover_exit
end

HeroViewStateBestiary._is_button_hover = function (self, widget)
    local content = widget.content
    local hotspot = content.button_hotspot

    return hotspot.is_hover
end

HeroViewStateBestiary._is_button_pressed = function (self, widget)
    local content = widget.content
    local hotspot = content.button_hotspot or content.hotspot

    if hotspot.on_release then
        hotspot.on_release = false

        return true
    end
end

HeroViewStateBestiary._is_enemy_tab_selected = function (self)
    local widget = self._widgets_by_name.enemy_icons_skaven
    local widget_content = widget.content
    local amount = widget_content.amount

    for i = 1, amount, 1 do
        local name_sufix = "_" .. tostring(i)
        local hotspot_name = "hotspot" .. name_sufix
        local hotspot_content = widget_content[hotspot_name]

        if hotspot_content.on_pressed then
            self._selected_tab = "skaven"
            return i, "skaven"
        end
    end

    widget = self._widgets_by_name.enemy_icons_chaos
    widget_content = widget.content
    amount = widget_content.amount

    for i = 1, amount, 1 do
        local name_sufix = "_" .. tostring(i)
        local hotspot_name = "hotspot" .. name_sufix
        local hotspot_content = widget_content[hotspot_name]

        if hotspot_content.on_pressed then
            self._selected_tab = "chaos"
            return i, "chaos"
        end
    end
end

HeroViewStateBestiary._handle_tab_hover = function (self, widget, style_prefix)
    local hover_index = self:_is_tab_hovered(widget)

    if hover_index then
        self:_on_option_button_hover(widget, style_prefix .. "_" .. hover_index)
    end

    local dehover_index = self:_is_tab_dehovered(widget)

    if dehover_index then
        self:_on_option_button_dehover(widget, style_prefix .. "_" .. dehover_index)
    end
end

HeroViewStateBestiary._is_tab_hovered = function (self, widget)
    local widget_content = widget.content
    local amount = widget_content.amount

    for i = 1, amount, 1 do
        local name_sufix = "_" .. tostring(i)
        local hotspot_name = "hotspot" .. name_sufix
        local hotspot_content = widget_content[hotspot_name]

        if hotspot_content.on_hover_enter and not hotspot_content.is_selected then
            return i
        end
    end
end

HeroViewStateBestiary._is_tab_dehovered = function (self, widget)
    local widget_content = widget.content
    local amount = widget_content.amount

    for i = 1, amount, 1 do
        local name_sufix = "_" .. tostring(i)
        local hotspot_name = "hotspot" .. name_sufix
        local hotspot_content = widget_content[hotspot_name]

        if hotspot_content.on_hover_exit and not hotspot_content.is_selected then
            return i
        end
    end
end

HeroViewStateBestiary._deselect_enemy_tabs = function (self)
    self._enemy_index = nil

    local widget = self._widgets_by_name.enemy_icons_skaven
    local widget_content = widget.content
    local widget_style = widget.style
    local amount = widget_content.amount
    for i = 1, amount, 1 do
        local name_sufix = "_" .. tostring(i)
        local hotspot_name = "hotspot" .. name_sufix
        local hotspot_content = widget_content[hotspot_name]
        local icon_name = "icon" .. name_sufix
        hotspot_content.is_selected = false
        local icon_style = widget_style[icon_name]
        local icon_color = icon_style.color
        icon_color[2] = 100
        icon_color[3] = 100
        icon_color[4] = 100
    end

    widget = self._widgets_by_name.enemy_icons_chaos
    widget_content = widget.content
    widget_style = widget.style
    amount = widget_content.amount
    for i = 1, amount, 1 do
        local name_sufix = "_" .. tostring(i)
        local hotspot_name = "hotspot" .. name_sufix
        local hotspot_content = widget_content[hotspot_name]
        local icon_name = "icon" .. name_sufix
        hotspot_content.is_selected = false
        local icon_style = widget_style[icon_name]
        local icon_color = icon_style.color
        icon_color[2] = 100
        icon_color[3] = 100
        icon_color[4] = 100
    end

end

HeroViewStateBestiary._select_enemy_tab_by_index = function (self, index, race, play_sound)
    local deselect = (self._enemy_index_race == race and self._enemy_index == index)


    self:_deselect_enemy_tabs()

    if play_sound then
        self:play_sound("play_gui_hero_select_hero_click")
    end

    local widget = self._widgets_by_name["enemy_icons_"..race]
    local widget_content = widget.content
    local widget_style = widget.style
    local amount = widget_content.amount
    for i = 1, amount, 1 do
        local name_sufix = "_" .. tostring(i)
        local hotspot_name = "hotspot" .. name_sufix
        local hotspot_content = widget_content[hotspot_name]
        local icon_name = "icon" .. name_sufix
        local selected = i == index
        hotspot_content.is_selected = selected and not deselect
        local icon_style = widget_style[icon_name]
        local icon_color = icon_style.color
        icon_color[2] = (selected and 255) or 100
        icon_color[3] = (selected and 255) or 100
        icon_color[4] = (selected and 255) or 100
    end

    self._enemy_index = (not deselect and index) or nil
    self._enemy_index_race = (not deselect and race) or nil

    if deselect then
        self:_clear_enemy_info()
        self.enemy_name = nil
        self.requested_enemy_name = nil
        if self.world_previewer then
            self.world_previewer:prepare_exit_bestiary(true, true)
        end
    elseif self._enemy_index and self._enemy_index_race then
        self._variation_index = 1
        self:_display_enemy_info()
        self:_update_enemy_sync()
    end
end

HeroViewStateBestiary._get_slots_to_use = function (self)
    if self._enemy_index_race == "skaven" then
        return skaven_icons
    elseif self._enemy_index_race == "chaos" then
        return chaos_icons
    elseif self._enemy_index_race == "beastmen" then
        return beastmen_icons
    end
end

HeroViewStateBestiary._display_enemy_info = function (self)
    local widgets = self._widgets_by_name

    local slots_to_use = self:_get_slots_to_use()
    local enemy_name = slots_to_use[self._enemy_index][2]

    self:_clear_enemy_info()

    if type(enemy_name) == "table" then     -- Enemy has variations or more than one unit
        local index = self._variation_index or 1
        enemy_name = enemy_name[index]
        widgets.breed_cycle_button.content.visible = true
    end

    self.requested_enemy_name = enemy_name

    local enemy_info = self._enemy_info[enemy_name] or {}

    widgets.breed_cycle_button.content.title_text = enemy_info.name
    widgets.enemy_detail_name.content.text = enemy_info.name or ""

    if enemy_info.man_sized then
        widgets.enemy_detail_man_size_icon.content.visible = true
        widgets.enemy_detail_man_size_text.content.text = "Man-Sized"
    end

    if enemy_info.special == true then
        widgets.enemy_detail_elite_text.content.text = "Special"
        widgets.enemy_detail_special_icon.content.visible = true
    elseif enemy_info.lord == true then
        widgets.enemy_detail_elite_text.content.text = "Lord"
        widgets.enemy_detail_lord_icon.content.visible = true
    elseif enemy_info.boss == true then
        widgets.enemy_detail_elite_text.content.text = "Boss"
        widgets.enemy_detail_boss_icon.content.visible = true
    elseif enemy_info.elite == true then
        widgets.enemy_detail_elite_text.content.text = "Elite"
        widgets.enemy_detail_elite_icon.content.visible = true
        widgets.enemy_detail_elite_icon_glow.content.visible = true
    end

    local difficulty = DifficultySettings[Difficulties[self._difficulty_index]]

    widgets.enemy_detail_divider.content.visible = true

    widgets.enemy_detail_race_category.content.text = "Race"
    widgets.enemy_detail_race.content.text = (enemy_info.race and enemy_info.race:sub(1,1):upper()..enemy_info.race:sub(2)) or ""


    widgets.enemy_detail_armor_category.content.text = "Type"
    widgets.enemy_detail_armor.content.text = enemy_info.armor_category or ""

    widgets.enemy_detail_health_category.content.text = "Health"
    widgets.enemy_detail_health.content.text = (enemy_info.health and enemy_info.health[difficulty.rank]) or ""

    widgets.enemy_detail_mass_category.content.text = "Mass"
    if enemy_info.hit_mass then
        if type(enemy_info.hit_mass) == "table" then
            widgets.enemy_detail_mass.content.text = enemy_info.hit_mass[difficulty.rank] or ""
        else
            widgets.enemy_detail_mass.content.text = enemy_info.hit_mass or ""
        end
    end

    if enemy_info.block_mass then
        if type(enemy_info.block_mass) == "table" then
            widgets.enemy_detail_mass.content.text = widgets.enemy_detail_mass.content.text.." ("..(enemy_info.block_mass[difficulty.rank] or "")..")"
        else
            widgets.enemy_detail_mass.content.text = widgets.enemy_detail_mass.content.text.." ("..(enemy_info.block_mass or "")..")"
        end
    end

    widgets.enemy_detail_stagger_category.content.text = "Stagger Resist"
    if enemy_info.stagger_resist then
        if type(enemy_info.stagger_resist) == "table" then
            widgets.enemy_detail_stagger.content.text = enemy_info.stagger_resist[difficulty.rank] or ""
        else
            widgets.enemy_detail_stagger.content.text = enemy_info.stagger_resist or ""
        end
    end

    if enemy_info.linesman_mod or enemy_info.tank_mod or enemy_info.heavy_linesman_mod then
        widgets.enemy_detail_modifiers.content.text = "Mass Modifiers"

        if enemy_info.linesman_mod then
            widgets.enemy_detail_linesman.content.visible = true
            widgets.enemy_detail_linesman_text.content.text = "LINESMAN"
            widgets.enemy_detail_linesman_value.content.text = tostring(enemy_info.linesman_mod * 100).."%"
        end

        if enemy_info.heavy_linesman_mod then
            widgets.enemy_detail_heavy_linesman.content.visible = true
            widgets.enemy_detail_heavy_linesman_text.content.text = "HEAVY LINESMAN"
            widgets.enemy_detail_heavy_linesman_value.content.text = tostring(enemy_info.heavy_linesman_mod * 100).."%"
        end

        if enemy_info.tank_mod then
            widgets.enemy_detail_tank.content.visible = true
            widgets.enemy_detail_tank_text.content.text = "TANK"
            widgets.enemy_detail_tank_value.content.text = tostring(enemy_info.tank_mod * 100).."%"
        end
    end

    widgets.difficulty_button.content.visible = true
    local difficulty_text = Localize(difficulty.display_name)

    if self._deathwish_active and self._difficulty_index > 3 then difficulty_text = difficulty_text.." Deathwish" end

    widgets.difficulty_button.content.title_text = difficulty_text

    --widgets.lore_strings.content.text = enemy_info.lore_strings and enemy_info.lore_strings.desc or ""

    widgets.statistics_kills_text.content.text = enemy_info.lord and "Times Defeated" or "Total Slain"
    local slain_per_breed = self:_get_duplicate_breed_stats("slain_per_breed", enemy_info, enemy_name)
    widgets.statistics_slain_per_breed.content.text = tostring(slain_per_breed or 0)

    widgets.statistics_times_downed_text.content.text = "Times Downed / Killed"
    local downs_per_breed = self:_get_duplicate_breed_stats("times_downed_per_breed", enemy_info, enemy_name)
    widgets.statistics_times_downed.content.text = tostring(downs_per_breed or 0)

    widgets.statistics_damage_received_text.content.text = "Damage Received"
    local damage_received_per_breed = self:_get_duplicate_breed_stats("damage_received_per_breed", enemy_info, enemy_name)
    widgets.statistics_damage_received.content.text = string.format("%.2f", damage_received_per_breed or 0)

    widgets.statistics_melee_headshot_category.content.text = "by Melee Headshot"
    local melee_headshots_per_breed = self:_get_duplicate_breed_stats("headshots_per_breed_melee", enemy_info, enemy_name)
    local headshots_percent = slain_per_breed > 0 and melee_headshots_per_breed / slain_per_breed
    widgets.statistics_melee_headshot.content.text = tostring(melee_headshots_per_breed or 0) .. " (" .. string.format("%.1f", (headshots_percent or 0) * 100) .. "%)"

    widgets.statistics_ranged_headshot_category.content.text = "by Ranged Headshot"
    local ranged_headshots_per_breed = self:_get_duplicate_breed_stats("headshots_per_breed_ranged", enemy_info, enemy_name)
    headshots_percent = slain_per_breed > 0 and ranged_headshots_per_breed / slain_per_breed
    widgets.statistics_ranged_headshot.content.text = tostring(ranged_headshots_per_breed or 0) .. " (" .. string.format("%.1f", (headshots_percent or 0) * 100) .. "%)"

    local local_stats = mod.statistics_list
    if enemy_info.special then
        for i, stat_data in pairs(enemy_info.stats_data or {}) do
            local widget_name = "statistics_special_text"..tostring(i)
            widgets[widget_name].content.text = stat_data.text or 0

            widget_name = "statistics_special_value"..tostring(i)
            widgets[widget_name].content.text = local_stats[stat_data.stat] or 0
        end
    elseif enemy_info.boss then
        for i, stat_data in pairs(enemy_info.stats_data or {}) do
            local widget_name = "statistics_boss_text"..tostring(i)
            widgets[widget_name].content.text = stat_data.text or ""

            widget_name = "statistics_boss_value"..tostring(i)
            widgets[widget_name].content.text = local_stats[stat_data.stat] or 0
        end
    end

    widgets.kill_button.offset = {0, 0, 10}
    widgets.kill_button.content.visible = false

end

HeroViewStateBestiary._get_duplicate_breed_stats = function (self, stat, enemy_info, enemy_name)
    local total = 0
    local local_stats = mod.statistics_list
    local stat_name
    if enemy_info.combine_with then
        stat_name = stat .. "_" .. enemy_info.combine_with
        total = total + (local_stats[stat_name] or 0)
    end
    stat_name = stat .. "_" .. enemy_name
    total = total + (local_stats[stat_name] or 0)

    return total
end

HeroViewStateBestiary._clear_enemy_info = function (self)
    --if not self._enemy_index then
        self._widgets_by_name.kill_button.content.visible = false
        self._widgets_by_name.enemy_detail_divider.content.visible = false
        self._widgets_by_name.difficulty_button.content.visible = false
        self._widgets_by_name.breed_cycle_button.content.visible = false
        self._widgets_by_name.enemy_detail_elite_icon.content.visible = false
        self._widgets_by_name.enemy_detail_elite_icon_glow.content.visible = false
        self._widgets_by_name.enemy_detail_boss_icon.content.visible = false
        self._widgets_by_name.enemy_detail_lord_icon.content.visible = false
        self._widgets_by_name.enemy_detail_special_icon.content.visible = false
        self._widgets_by_name.enemy_detail_linesman.content.visible = false
        self._widgets_by_name.enemy_detail_heavy_linesman.content.visible = false
        self._widgets_by_name.enemy_detail_tank.content.visible = false
        self._widgets_by_name.enemy_detail_man_size_icon.content.visible = false
        for widget_name, widget in pairs(self._widgets_by_name) do
            if string.match(widget_name, "enemy_detail_") ~= nil and widget.content and widget.content.text then
                widget.content.text = ""
            elseif string.match(widget_name, "statistics_") ~= nil and widget.content and widget.content.text then
                widget.content.text = ""
            end
        end
    --end
end

HeroViewStateBestiary._on_option_button_hover = function (self, widget, style_id)
    local ui_animations = self._ui_animations
    local animation_name = "option_button_" .. style_id
    local widget_style = widget.style
    local pass_style = widget_style[style_id]
    local current_color_value = pass_style.color[2]
    local target_color_value = 255
    local total_time = UISettings.scoreboard.topic_hover_duration
    local animation_duration = (1 - current_color_value / target_color_value) * total_time

    for i = 2, 4, 1 do
        if animation_duration > 0 then
            ui_animations[animation_name .. "_hover_" .. i] = self:_animate_element_by_time(pass_style.color, i, current_color_value, target_color_value, animation_duration)
        else
            pass_style.color[i] = target_color_value
        end
    end
end

HeroViewStateBestiary._on_option_button_dehover = function (self, widget, style_id)
    local ui_animations = self._ui_animations
    local animation_name = "option_button_" .. style_id
    local widget_style = widget.style
    local pass_style = widget_style[style_id]
    local current_color_value = pass_style.color[1]
    local target_color_value = 100
    local total_time = UISettings.scoreboard.topic_hover_duration
    local animation_duration = current_color_value / 255 * total_time

    for i = 2, 4, 1 do
        if animation_duration > 0 then
            ui_animations[animation_name .. "_hover_" .. i] = self:_animate_element_by_time(pass_style.color, i, current_color_value, target_color_value, animation_duration)
        else
            pass_style.color[1] = target_color_value
        end
    end
end

HeroViewStateBestiary._animate_element_by_time = function (self, target, target_index, from, to, time)
    local new_animation = UIAnimation.init(UIAnimation.function_by_time, target, target_index, from, to, time, math.ease_out_quad)

    return new_animation
end

HeroViewStateBestiary._start_transition_animation = function (self, key, animation_name)
    local params = {
        wwise_world = self.wwise_world,
        render_settings = self.render_settings
    }
    local widgets = {}
    local anim_id = self.ui_animator:start_animation(animation_name, widgets, scenegraph_definition, params)
    self._animations[key] = anim_id
end

HeroViewStateBestiary._update_animations = function (self, dt)
    for name, animation in pairs(self._ui_animations) do
        UIAnimation.update(animation, dt)

        if UIAnimation.completed(animation) then
            self._ui_animations[name] = nil
        end
    end

    local animations = self._animations
    local ui_animator = self.ui_animator

    for animation_name, animation_id in pairs(animations) do
        if ui_animator:is_animation_completed(animation_id) then
            ui_animator:stop_animation(animation_id)

            animations[animation_name] = nil
        end
    end

    local widgets_by_name = self._widgets_by_name
    local exit_button = widgets_by_name.exit_button
    local difficulty_button = widgets_by_name.difficulty_button
    local breed_cycle_button = widgets_by_name.breed_cycle_button
    local kill_button = widgets_by_name.kill_button

    UIWidgetUtils.animate_default_button(exit_button, dt)
    UIWidgetUtils.animate_default_button(difficulty_button, dt)
    UIWidgetUtils.animate_default_button(breed_cycle_button, dt)
    UIWidgetUtils.animate_default_button(kill_button, dt)

end

HeroViewStateBestiary.on_exit = function (self)
    self.ui_animator = nil

    if self.world_previewer then
        self.world_previewer:prepare_exit_bestiary()
        self.world_previewer:on_exit()
        self.world_previewer:destroy()
    end

    if self._viewport_widget then
        UIWidget.destroy(self.ui_renderer, self._viewport_widget)

        self._viewport_widget = nil
    end

    Managers.package:unload(self._level_package_name, "HeroViewStateBestiary")
    Managers.package:unload(self._inventory_package_name, "HeroViewStateBestiary")

    self._level_package_name = nil
    self._inventory_package_name = nil
end

return