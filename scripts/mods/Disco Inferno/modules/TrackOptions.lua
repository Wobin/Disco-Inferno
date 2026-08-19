local mod = get_mod("Disco Inferno")

local M = {}

local EXTENSIONS = { "mp3", "ogg", "oga", "opus", "wav", "flac", "m4a", "aac" }
local AUDIO_DIR = "mods/Disco Inferno/audio/"

local DEFAULTS = { volume = 80, bpm = 100, intensity = 60 }

local function checksum(text)
	local h = 5381

	for i = 1, #text do
		h = (h * 33 + string.byte(text, i)) % 4294967296
	end

	return h % 100000
end

local function safe_id(name)
	local s = string.lower(name)
	s = string.gsub(s, "%.%w+$", "")
	s = string.gsub(s, "[^%w]+", "_")
	s = string.gsub(s, "^_+", "")
	s = string.gsub(s, "_+$", "")
	s = string.sub(s, 1, 40)

	if s == "" then
		s = "track"
	end

	return s
end

local function to_channels(rgb)
	if type(rgb) ~= "table" then
		return nil
	end

	local r = tonumber(rgb.r) or 0
	local g = tonumber(rgb.g) or 0
	local b = tonumber(rgb.b) or 0

	return { 255, math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5) }
end

local function to_rgb(channels)
	if type(channels) ~= "table" or #channels < 4 then
		return { r = 0, g = 0, b = 0 }
	end

	return { r = channels[2] / 255, g = channels[3] / 255, b = channels[4] / 255 }
end

M.id_for = function(name)
	return "di_song_" .. safe_id(name) .. "_" .. tostring(checksum(name))
end

M.list_tracks = function()
	local sa = get_mod("SimpleAudio")
	local tracks, seen = {}, {}

	if not sa or type(sa.glob) ~= "function" then
		return tracks
	end

	for _, ext in ipairs(EXTENSIONS) do
		local ok, result = pcall(sa.glob, AUDIO_DIR .. "*." .. ext)

		if ok and result then
			local ok_list, list = pcall(result.list, result)

			if ok_list and type(list) == "table" then
				for i = 1, #list do
					local path = tostring(list[i])
					local name = string.match(path, "[^/]+$") or path

					if not seen[name] then
						seen[name] = true
						tracks[#tracks + 1] = { name = name, id = M.id_for(name) }
					end
				end
			end
		end
	end

	table.sort(tracks, function(a, b) return a.name < b.name end)

	return tracks
end

M.migrate = function(tracks)
	local old = mod:get("di_song_settings")

	if type(old) ~= "table" then
		return
	end

	for _, track in ipairs(tracks) do
		local s = old[track.name]

		if type(s) == "table" then
			local id = track.id

			if mod:get(id .. "_volume") == nil and tonumber(s.volume) then
				mod:set(id .. "_volume", tonumber(s.volume))
			end

			if mod:get(id .. "_intensity") == nil and tonumber(s.intensity) then
				mod:set(id .. "_intensity", tonumber(s.intensity))
			end

			if mod:get(id .. "_bpm") == nil and tonumber(s.bpm) then
				mod:set(id .. "_bpm", tonumber(s.bpm))
			end

			if mod:get(id .. "_light_mode") == nil then
				if s.rainbow then
					mod:set(id .. "_light_mode", "rainbow")
				else
					mod:set(id .. "_light_mode", "fixed")
				end
			end

			if mod:get(id .. "_colour_one") == nil then
				local c = to_channels(s.colour_one)

				if c then
					mod:set(id .. "_colour_one", c)
				end
			end

			if mod:get(id .. "_colour_two") == nil then
				local c = to_channels(s.colour_two)

				if c then
					mod:set(id .. "_colour_two", c)
				end
			end
		end
	end
end

M.sync = function(tracks)
	tracks = tracks or M.tracks or {}

	local out = {}

	for _, track in ipairs(tracks) do
		local id = track.id
		local entry = {
			volume = mod:get(id .. "_volume") or DEFAULTS.volume,
			bpm = mod:get(id .. "_bpm") or DEFAULTS.bpm,
			intensity = mod:get(id .. "_intensity") or DEFAULTS.intensity,
			rainbow = mod:get(id .. "_light_mode") ~= "fixed",
			colour_one = to_rgb(mod:get(id .. "_colour_one")),
			colour_two = to_rgb(mod:get(id .. "_colour_two")),
		}

		out[track.name] = entry
	end

	mod:set("di_song_settings", out, false)

	return out
end

M.build_widgets = function(tracks)
	local blocks, options = {}, { localize = false }

	options[1] = { text = mod:localize("di_select_song"), value = "none", show_widgets = {} }

	for i = 1, #tracks do
		local track = tracks[i]
		local id = track.id

		blocks[i] = {
			setting_id = id,
			type = "group",
			title = track.name,
			localize = false,
			sub_widgets = {
				{
					setting_id = id .. "_volume",
					type = "numeric",
					title = "di_song_volume",
					localize = true,
					default_value = DEFAULTS.volume,
					range = { 0, 200 },
					decimals_number = 0,
				},
				{
					setting_id = id .. "_bpm",
					type = "numeric",
					title = "di_song_bpm",
					localize = true,
					default_value = DEFAULTS.bpm,
					range = { 60, 220 },
					decimals_number = 0,
				},
				{
					setting_id = id .. "_intensity",
					type = "numeric",
					title = "di_song_intensity",
					localize = true,
					default_value = DEFAULTS.intensity,
					range = { 5, 200 },
					decimals_number = 0,
				},
				{
					setting_id = id .. "_light_mode",
					type = "dropdown",
					title = "di_random_lights",
					localize = true,
					default_value = "rainbow",
					options = {
						{ text = "di_lights_rainbow", value = "rainbow", show_widgets = {} },
						{ text = "di_lights_fixed", value = "fixed", show_widgets = { 1, 2 } },
					},
					sub_widgets = {
						{
							setting_id = id .. "_colour_one",
							type = "color",
							title = "di_light_left",
							localize = true,
							default_value = { 255, 255, 0, 0 },
							has_alpha = false,
						},
						{
							setting_id = id .. "_colour_two",
							type = "color",
							title = "di_light_right",
							localize = true,
							default_value = { 255, 255, 0, 0 },
							has_alpha = false,
						},
					},
				},
			},
		}

		options[i + 1] = { text = track.name, value = id, show_widgets = { i } }
	end

	local stored = mod:get("di_track_selector")

	if stored ~= nil then
		local known = false

		for i = 1, #options do
			if options[i].value == stored then
				known = true
				break
			end
		end

		if not known then
			mod:set("di_track_selector", "none")
		end
	end

	return {
		setting_id = "di_track_selector",
		type = "dropdown",
		title = "di_song_settings",
		default_value = "none",
		options = options,
		sub_widgets = blocks,
	}
end

M.selected_track = function(tracks)
	local id = mod:get("di_track_selector")

	if not id or id == "none" then
		return nil
	end

	for _, track in ipairs(tracks or M.tracks or {}) do
		if track.id == id then
			return track
		end
	end

	return nil
end

return M
