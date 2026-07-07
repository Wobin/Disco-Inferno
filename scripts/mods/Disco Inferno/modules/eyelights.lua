local mod = get_mod("Disco Inferno")

local Unit = Unit
local World = World
local Light = Light
local Vector3 = Vector3
local Quaternion = Quaternion
local math = math
local math_pi = math.pi
local math_rad = math.rad
local pairs = pairs
local pcall = pcall

local unit_node = Unit.node
local unit_alive = Unit.alive
local unit_light = Unit.light
local unit_world_position = Unit.world_position
local unit_world_rotation = Unit.world_rotation
local unit_set_local_position = Unit.set_local_position
local unit_set_local_rotation = Unit.set_local_rotation
local world_spawn_unit_ex = World.spawn_unit_ex
local world_destroy_unit = World.destroy_unit
local quaternion_forward = Quaternion.forward
local quaternion_right = Quaternion.right
local quaternion_look = Quaternion.look
local quaternion_rotate = Quaternion.rotate
local vector3_up = Vector3.up
local light_set_enabled = Light.set_enabled
local light_set_intensity = Light.set_intensity
local light_set_ies_profile = Light.set_ies_profile
local light_set_color_filter = Light.set_color_filter
local light_set_spot_reflector = Light.set_spot_reflector
local light_set_casts_shadows = Light.set_casts_shadows
local light_set_falloff_start = Light.set_falloff_start
local light_set_falloff_end = Light.set_falloff_end
local light_set_spot_angle_start = Light.set_spot_angle_start
local light_set_spot_angle_end = Light.set_spot_angle_end
local light_set_volumetric_intensity = Light.set_volumetric_intensity

local LIGHT_UNIT = "content/weapons/player/attachments/flashlights/flashlight_01/flashlight_01"
local IES_PROFILE = "content/environment/ies_profiles/narrow/flashlight_custom_03"

local EYE_NODE = "skull_aim_center"

local SPOT_START = 2 / 180 * math_pi
local SPOT_END = 26 / 180 * math_pi
local FALLOFF_START = 0
local FALLOFF_END = 30
local VOLUMETRIC = 14

local EYE_OFFSET_X = 0.06
local EYE_OFFSET_FWD = 0.05
local EYE_OFFSET_UP = 0.02

local function log(fmt, ...)
	if mod:get("di_debug") then
		mod:info(fmt, ...)
	end
end

local DiscoInfernoEyeLights = class("DiscoInfernoEyeLights")

DiscoInfernoEyeLights.init = function(self, world, skull_unit, colour_left, colour_right)
	self.world = world
	self.skull_unit = skull_unit
	self.colour_left = colour_left
	self.colour_right = colour_right or colour_left
	self.eye_node = nil
	self.lights = {}
	self.spawned = false
end

local function configure_light(light, color, intensity)
	if not light then
		return
	end

	light_set_enabled(light, true)
	light_set_casts_shadows(light, false)
	light_set_spot_reflector(light, true)
	light_set_ies_profile(light, IES_PROFILE)
	light_set_spot_angle_start(light, SPOT_START)
	light_set_spot_angle_end(light, SPOT_END)
	light_set_falloff_start(light, FALLOFF_START)
	light_set_falloff_end(light, FALLOFF_END)
	light_set_volumetric_intensity(light, VOLUMETRIC)
	light_set_intensity(light, intensity)
	light_set_color_filter(light, Vector3(color[1] or 1, color[2] or 0, color[3] or 0))
end

local function spawn_one(self, side, color)
	local world = self.world
	local skull = self.skull_unit
	local node = self.eye_node
	local pos = unit_world_position(skull, node)
	local rot = unit_world_rotation(skull, node)
	local ok, light_unit = pcall(world_spawn_unit_ex, world, LIGHT_UNIT, nil, pos, rot)

	if not ok or not light_unit then
		log("eyelights: spawn FAILED side=%d ok=%s err=%s", side, tostring(ok), tostring(light_unit))
		return nil
	end

	local light = unit_light(light_unit, 1)

	configure_light(light, color, 0)
	log("eyelights: spawned side=%d light=%s", side, tostring(light ~= nil))

	return { unit = light_unit, light = light, side = side }
end

DiscoInfernoEyeLights.spawn = function(self)
	if self.spawned then
		return
	end

	local skull = self.skull_unit

	if not (self.world and skull and unit_alive(skull)) then
		log("eyelights: cannot spawn - world=%s skull_alive=%s", tostring(self.world), tostring(skull and unit_alive(skull)))
		return
	end

	local node_ok, node = pcall(unit_node, skull, EYE_NODE)

	self.eye_node = (node_ok and node) or 1
	log("eyelights: node '%s' -> index=%s (ok=%s)", EYE_NODE, tostring(self.eye_node), tostring(node_ok))

	self.lights[-1] = spawn_one(self, -1, self.colour_left)
	self.lights[1] = spawn_one(self, 1, self.colour_right)
	self.spawned = true
	log("eyelights: spawn complete (left=%s right=%s)", tostring(self.lights[-1] ~= nil), tostring(self.lights[1] ~= nil))
end

DiscoInfernoEyeLights.track = function(self, sweep)
	local skull = self.skull_unit

	if not (skull and unit_alive(skull)) then
		return
	end

	local node = self.eye_node or 1
	local base = unit_world_position(skull, node)
	local skull_rot = unit_world_rotation(skull, 1)
	local fwd = quaternion_forward(skull_rot)
	local right = quaternion_right(skull_rot)
	local up = vector3_up()

	for _, e in pairs(self.lights) do
		if e and e.unit and unit_alive(e.unit) then
			local sweep_q = Quaternion(up, math_rad(e.side * sweep))
			local dir = quaternion_rotate(sweep_q, fwd)
			local pos = base + right * (e.side * EYE_OFFSET_X) + fwd * EYE_OFFSET_FWD + up * EYE_OFFSET_UP

			unit_set_local_position(e.unit, 1, pos)
			unit_set_local_rotation(e.unit, 1, quaternion_look(dir, up))
		end
	end
end

DiscoInfernoEyeLights.strobe = function(self, intensity, colour_left, colour_right)
	if colour_left then
		colour_right = colour_right or colour_left
		self.colour_left = colour_left
		self.colour_right = colour_right
	end

	for _, e in pairs(self.lights) do
		if e and e.light and e.unit and unit_alive(e.unit) then
			light_set_intensity(e.light, intensity)

			if colour_left then
				local color = (e.side < 0) and self.colour_left or self.colour_right
				light_set_color_filter(e.light, Vector3(color[1] or 1, color[2] or 0, color[3] or 0))
			end
		end
	end
end

DiscoInfernoEyeLights.alive = function(self)
	return self.skull_unit and unit_alive(self.skull_unit)
end

DiscoInfernoEyeLights.despawn = function(self)
	for i, e in pairs(self.lights) do
		if e and e.unit and unit_alive(e.unit) then
			pcall(world_destroy_unit, self.world, e.unit)
		end

		self.lights[i] = nil
	end

	self.spawned = false
end

return DiscoInfernoEyeLights
