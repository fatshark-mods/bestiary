local mod = get_mod("bestiary")

BestiaryPreviewer = class(BestiaryPreviewer)

BestiaryPreviewer.init = function (self, ingame_ui_context)

    self.input_manager = ingame_ui_context.input_manager
    self.ui_renderer = ingame_ui_context.ui_renderer

    self.default_camera_position = {
        x = 0,
        y = 4.5,
        z = 2
    }

    self.default_camera_look_target = {
        x = 0,
        y = 3,
        z = 0.1
    }

end

BestiaryPreviewer.on_enter = function (self, viewport_widget)

    self.viewport_widget = viewport_widget

    local viewport_pass_data = viewport_widget.element.pass_data[1]
    self.viewport = viewport_pass_data.viewport
    self.world = viewport_pass_data.world
    self.level = viewport_pass_data.level

    self.camera = ScriptViewport.camera(self.viewport)
    self.physics_world = World.get_data(self.world, "physics_world")

end

BestiaryPreviewer.update_camera_pos_rot = function (self, dt, t)

    local default_camera_position = self.default_camera_position
    local new_camera_position = Vector3.zero()

    new_camera_position.x = default_camera_position.x
    new_camera_position.y = default_camera_position.y
    new_camera_position.z = default_camera_position.z

    local look_target = self.default_camera_look_target
    local look_direction = Vector3.normalize( Vector3(default_camera_position.x, look_target.y, default_camera_position.z) - new_camera_position )
    local look_rotation = Quaternion.look(look_direction)

    ScriptCamera.set_local_rotation(self.camera, look_rotation)
    ScriptCamera.set_local_position(self.camera, Vector3(default_camera_position.x, default_camera_position.y, default_camera_position.z))

end

BestiaryPreviewer.update = function (self, dt, t)

    self:update_camera_pos_rot(dt, t)

end

BestiaryPreviewer.on_exit = function (self)

    mod:debug("[BestiaryPreviewer] on_exit")

end