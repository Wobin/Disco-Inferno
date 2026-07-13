--[[
	Name: Disco Inferno
	Author: Wobin
	Date: 28/06/2026
	Version: 1.1.0
]]--

local mod = get_mod("Disco Inferno")
mod.version = "1.1.0"

local EyeLights = mod:io_dofile("Disco Inferno/scripts/mods/Disco Inferno/modules/eyelights")
local Jukebox = mod:io_dofile("Disco Inferno/scripts/mods/Disco Inferno/modules/jukebox")

local Breed = require("scripts/utilities/breed")
local CompanionServoSkullSettings = require("scripts/settings/companion/companion_servo_skull_settings")
local PortableRandom = require("scripts/foundation/utilities/portable_random")

local ScriptUnit = ScriptUnit
local Managers = Managers
local GameSession = GameSession
local pairs = pairs
local math_floor = math.floor

local unit_alive = Unit.alive
local unit_world = Unit.world
local breed_or_nil = Breed.unit_breed_or_nil

local SERVO_SKULL_BREED = "companion_servo_skull"
local STATES = CompanionServoSkullSettings.STATES
local ACTIVE_STATES = {
	[STATES.flamethrower] = true,
	[STATES.flamethrower_shooting] = true,
}

local LIGHT_PACKAGE = "content/weapons/player/attachments/flashlights/flashlight_01/flashlight_01"

local SWEEP_DEGREES = 12
local POLL_INTERVAL = 0.15

local DEFAULTS = {
	volume = 80,
	bpm = 100,
	intensity = 60,
	rainbow = false,
	colour_one = { 1, 0, 0 },
	colour_two = { 1, 0, 0 },
}

mod.parties = {}

local function log(fmt, ...)
	if mod:get("di_debug") then
		mod:info(fmt, ...)
	end
end

local function to_rgb(c, fallback)
	c = c or fallback

	if not c then
		return { 0, 0, 0 }
	end

	return {
		c[1] or c.r or 0,
		c[2] or c.g or 0,
		c[3] or c.b or 0,
	}
end

local function resolve_song_settings(song_key)
	local all = mod:get("di_song_settings")
	local s = song_key and all and all[song_key]

	if not s then
		return {
			volume = DEFAULTS.volume,
			bpm = DEFAULTS.bpm,
			intensity = DEFAULTS.intensity,
			rainbow = DEFAULTS.rainbow,
			colour_one = to_rgb(DEFAULTS.colour_one),
			colour_two = to_rgb(DEFAULTS.colour_two),
		}
	end

	local rainbow = DEFAULTS.rainbow

	if s.rainbow ~= nil then
		rainbow = s.rainbow
	end

	return {
		volume = s.volume or DEFAULTS.volume,
		bpm = s.bpm or DEFAULTS.bpm,
		intensity = s.intensity or DEFAULTS.intensity,
		rainbow = rainbow,
		colour_one = to_rgb(s.colour_one, DEFAULTS.colour_one),
		colour_two = to_rgb(s.colour_two, DEFAULTS.colour_two),
	}
end

local function random_colour(rand)
	local h = rand:random_range(0, 6)
	local sector = math_floor(h)
	local f = h - sector

	if sector >= 6 then
		sector = 5
		f = 1
	end

	if sector == 0 then
		return { 1, f, 0 }
	elseif sector == 1 then
		return { 1 - f, 1, 0 }
	elseif sector == 2 then
		return { 0, 1, f }
	elseif sector == 3 then
		return { 0, 1 - f, 1 }
	elseif sector == 4 then
		return { f, 0, 1 }
	end

	return { 1, 0, 1 - f }
end

local function skull_state(skull)
	local ok, state = pcall(function()
		local gs = Managers.state.game_session and Managers.state.game_session:game_session()
		local go_id = Managers.state.unit_spawner and Managers.state.unit_spawner:game_object_id(skull)

		if gs and go_id and GameSession.game_object_exists(gs, go_id) then
			return GameSession.game_object_field(gs, go_id, "state")
		end
	end)

	return ok and state or nil
end

mod.on_all_mods_loaded = function()
	mod.simple_audio = get_mod("SimpleAudio")

	if not mod.simple_audio then
		mod:echo(mod:localize("di_requires_sa"))
	end

	mod.jukebox = Jukebox:new(mod.simple_audio)
	mod._rand = PortableRandom:new(1337)

	local SettingsUI = mod:io_dofile("Disco Inferno/scripts/mods/Disco Inferno/modules/SettingsUI")
	mod.config = SettingsUI:new()

	mod:info("Disco Inferno " .. tostring(mod.version) .. " loaded")
end

mod.on_setting_changed = function(setting_id)
	if setting_id == "di_show_config" and mod.config then
		if mod:get("di_show_config") then
			mod.config:open()
		else
			mod.config:close()
		end
	end
end

local function ensure_package()
	if mod._package_loaded then
		return
	end

	local ok, handle = pcall(function()
		return Managers.package and Managers.package:load(LIGHT_PACKAGE, "Disco Inferno")
	end)

	mod.package_handle = ok and handle or nil
	mod._package_loaded = true
	log("ensure_package: ok=%s", tostring(ok))
end

mod.on_game_state_changed = function(status, state_name)
	if state_name ~= "StateGameplay" then
		return
	end

	if status == "enter" then
		ensure_package()

		if mod.jukebox then
			mod.jukebox:stop_sample()
			mod.jukebox:rebuild_playlist()
		end
	elseif status == "exit" then
		mod:teardown()
		mod._package_loaded = false
	end
end

local function collect_active(out)
	local players = Managers.player and Managers.player:players()

	if not players then
		return
	end

	for _, player in pairs(players) do
		local owner_unit = player.player_unit

		if owner_unit and unit_alive(owner_unit) then
			local spawner = ScriptUnit.has_extension(owner_unit, "companion_spawner_system")

			if spawner then
				local companions = spawner:companion_units()

				for i = 1, #companions do
					local skull = companions[i]
					local breed = skull and unit_alive(skull) and breed_or_nil(skull)

					if breed and breed.name == SERVO_SKULL_BREED then
						local state = skull_state(skull)

						if state and ACTIVE_STATES[state] then
							out[skull] = true
						end
					end
				end
			end
		end
	end
end

local function start_party(skull)
	ensure_package()

	local song_key = mod.jukebox and mod.jukebox:choose(mod._rand)
	local o = resolve_song_settings(song_key)

	local world = unit_world(skull)
	local eyelights = EyeLights:new(world, skull, o.colour_one, o.colour_two)

	eyelights:spawn()

	mod.parties[skull] = {
		eyelights = eyelights,
		beat_timer = 0,
		strobe_on = true,
		sweep_sign = 1,
		song_key = song_key,
		opts = o,
	}

	eyelights:strobe(o.intensity, o.colour_one, o.colour_two)
	eyelights:track(SWEEP_DEGREES)

	if mod.jukebox then
		mod.jukebox:play(skull, song_key, o.volume)
	end

	log("start_party: skull=%s song=%s tracks=%d", tostring(skull), tostring(song_key), mod.jukebox and #mod.jukebox.tracks or 0)
end

local function end_party(skull)
	local party = mod.parties[skull]

	if not party then
		return
	end

	if party.eyelights then
		party.eyelights:despawn()
	end

	if mod.jukebox then
		mod.jukebox:stop()
	end

	mod.parties[skull] = nil
	log("end_party: skull=%s", tostring(skull))
end

local _active = {}
local _poll_timer = 0

mod.update = function(dt)
	if not mod:is_enabled() then
		return
	end

	if mod.config then
		mod.config:update()
	end

	_poll_timer = _poll_timer + dt

	if _poll_timer >= POLL_INTERVAL then
		_poll_timer = 0

		for skull in pairs(_active) do
			_active[skull] = nil
		end

		collect_active(_active)

		if mod._forced then
			for s in pairs(mod._forced) do
				if unit_alive(s) then
					_active[s] = true
				else
					mod._forced[s] = nil
				end
			end
		end

		for skull in pairs(_active) do
			if not mod.parties[skull] then
				start_party(skull)
			end
		end

		for skull in pairs(mod.parties) do
			if not _active[skull] or not unit_alive(skull) then
				end_party(skull)
			end
		end

		if mod._settings_dirty then
			mod._settings_dirty = false

			for _, party in pairs(mod.parties) do
				party.opts = resolve_song_settings(party.song_key)
			end
		end
	end

	for skull, party in pairs(mod.parties) do
		if not (party.eyelights and party.eyelights:alive()) then
			end_party(skull)
		else
			local o = party.opts
			local interval = 60 / (o.bpm > 0 and o.bpm or DEFAULTS.bpm)

			party.beat_timer = party.beat_timer + dt

			if party.beat_timer >= interval then
				party.beat_timer = party.beat_timer - interval
				party.strobe_on = not party.strobe_on
				party.sweep_sign = -party.sweep_sign

				local intensity = party.strobe_on and o.intensity or (o.intensity * 0.12)

				if o.rainbow then
					party.eyelights:strobe(intensity, random_colour(mod._rand), random_colour(mod._rand))
				else
					party.eyelights:strobe(intensity, o.colour_one, o.colour_two)
				end
			end

			party.eyelights:track(party.sweep_sign * SWEEP_DEGREES)
		end
	end
end

mod.teardown = function(self)
	for skull in pairs(self.parties) do
		end_party(skull)
	end

	self.parties = {}

	if self.jukebox then
		self.jukebox:stop_all()
	end
end

local function shutdown()
	if mod.config then
		pcall(function()
			mod.config:close()
		end)
	end

	mod:teardown()
end

mod.on_disabled = function()
	shutdown()
end

mod.on_unload = function()
	shutdown()
end

mod:command("di", mod:localize("di_open_setup"), function()
	mod:set("di_show_config", not mod:get("di_show_config"))
end)

mod:command("di_test", mod:localize("di_test_desc"), function(arg)
	local player = Managers.player and Managers.player:local_player(1)
	local owner_unit = player and player.player_unit

	if not (owner_unit and unit_alive(owner_unit)) then
		mod:echo(mod:localize("di_test_no_player"))
		return
	end

	local spawner = ScriptUnit.has_extension(owner_unit, "companion_spawner_system")
	local companions = spawner and spawner:companion_units()
	local found

	if companions then
		for i = 1, #companions do
			local skull = companions[i]
			local breed = skull and unit_alive(skull) and breed_or_nil(skull)

			if breed and breed.name == SERVO_SKULL_BREED then
				found = skull
			end
		end
	end

	if not found then
		mod:echo(mod:localize("di_test_no_skull"))
		return
	end

	mod._forced = mod._forced or {}

	if arg == "off" then
		mod._forced[found] = nil
		end_party(found)
		mod:echo(mod:localize("di_test_off"))
		return
	end

	mod._rand = mod._rand or PortableRandom:new(1337)
	mod._forced[found] = true
	mod:echo(mod:localize("di_test_on"))
end)
