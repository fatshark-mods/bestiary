local mod = get_mod("bestiary")

mod:dofile("scripts/mods/Bestiary/bestiary_view/bestiary_previewer")

local definitions = mod:dofile("scripts/mods/Bestiary/bestiary_view/bestiary_view_definitions")
local scenegraph_definition = definitions.scenegraph_definition
local viewport_definition = definitions.viewport_definition

local blocked_input_service = {
    get = function () return end,
    has = function () return end
}

BestiaryView = class(BestiaryView)

BestiaryView.init = function (self, ingame_ui_context)

    mod:debug("[BestiaryView] init")

    self.ui_renderer = ingame_ui_context.ui_renderer
    self.input_manager = ingame_ui_context.input_manager
    self.ingame_ui = ingame_ui_context.ingame_ui

    local input_manager = self.input_manager
    input_manager:create_input_service("bestiary_view", "IngameMenuKeymaps", "IngameMenuFilters")
    input_manager:map_device_to_service("bestiary_view", "keyboard")
    input_manager:map_device_to_service("bestiary_view", "mouse")
    input_manager:map_device_to_service("bestiary_view", "gamepad")

    self.world_previewer = BestiaryPreviewer:new(ingame_ui_context)

end

BestiaryView.input_service = function (self)
    return (self.input_blocked and blocked_input_service) or self.input_manager:get_service("bestiary_view")
end

BestiaryView.create_ui_elements = function (self)

    self.viewport_widget = UIWidget.init(viewport_definition)

end

BestiaryView.on_enter = function (self, params)

    local input_manager = self.input_manager
    input_manager:block_device_except_service("bestiary_view", "keyboard", 1)
    input_manager:block_device_except_service("bestiary_view", "mouse", 1)
    input_manager:block_device_except_service("bestiary_view", "gamepad", 1)

    self:create_ui_elements()

    self.world_previewer:on_enter(self.viewport_widget)

    ShowCursorStack.push()

end

BestiaryView.on_exit = function (self)

    mod:debug("[BestiaryView] on_exit")

    ShowCursorStack.pop()

    local input_manager = self.input_manager
    input_manager:device_unblock_all_services("keyboard", 1)
    input_manager:device_unblock_all_services("mouse", 1)
    input_manager:device_unblock_all_services("gamepad", 1)

    if self.world_previewer then
        self.world_previewer:on_exit()
    end

    if self.viewport_widget then
        UIWidget.destroy(self.ui_renderer, self.viewport_widget)

        self.viewport_widget = nil
    end

    self.ingame_ui:transition_with_fade("exit_menu")

end

BestiaryView.draw = function (self, dt, input_service)

    self.ui_scenegraph = UISceneGraph.init_scenegraph(scenegraph_definition)

    local ui_renderer = self.ui_renderer
    UIRenderer.begin_pass(ui_renderer, self.ui_scenegraph, blocked_input_service, dt)

    if self.viewport_widget then
        UIRenderer.draw_widget(ui_renderer, self.viewport_widget)
    end

    UIRenderer.end_pass(ui_renderer)

end

BestiaryView.update = function (self, dt, t)

    self.world_previewer:update(dt, t)

    local input_service = self:input_service()
    self:draw(dt, input_service)

end