local mod = get_mod("Disco Inferno")

local ui_scale = 2
local WIDTH = 360
local HEIGHT = 240
local OFFSET = 550
local PADDING = 16
local first_run = true
local window_width = math.min(WIDTH * ui_scale, RESOLUTION_LOOKUP.width - OFFSET)
local window_height = math.min(HEIGHT * ui_scale, RESOLUTION_LOOKUP.height - OFFSET)
local padded_width = window_width - PADDING

local ipairs = ipairs
local Imgui = Imgui
local Imgui_checkbox = Imgui.checkbox
local Imgui_is_item_hovered = Imgui.is_item_hovered
local Imgui_begin_tool_tip = Imgui.begin_tool_tip
local Imgui_text = Imgui.text
local Imgui_end_tool_tip = Imgui.end_tool_tip
local Imgui_set_next_window_size = Imgui.set_next_window_size
local Imgui_begin_window = Imgui.begin_window
local Imgui_set_next_window_pos = Imgui.set_next_window_pos
local Imgui_set_window_font_scale = Imgui.set_window_font_scale
local Imgui_begin_combo = Imgui.begin_combo
local Imgui_selectable = Imgui.selectable
local Imgui_end_combo = Imgui.end_combo
local Imgui_slider_int = Imgui.slider_int
local Imgui_color_edit_3 = Imgui.color_edit_3
local Imgui_end_window = Imgui.end_window
local Imgui_same_line = Imgui.same_line
local Imgui_button = Imgui.button

local function default_song_settings()
	return {
		volume = 80,
		bpm = 100,
		intensity = 60,
		rainbow = false,
		colour_one = { r = 1, g = 0, b = 0 },
		colour_two = { r = 1, g = 0, b = 0 },
	}
end

local DiscoInfernoConfig = class("DiscoInfernoConfig")

function DiscoInfernoConfig:init()
	self._is_open = false
	self._working = nil
	self._working_key = nil
end

function DiscoInfernoConfig:open()
	local input_manager = Managers.input
	local name = self.__class_name

	if input_manager and not input_manager:cursor_active() then
		input_manager:push_cursor(name)
		self.pushedcursor = true
	end

	self._is_open = true
	Imgui.open_imgui()
end

function DiscoInfernoConfig:close()
	if mod:get("di_show_config") then
		mod:set("di_show_config", false, false)
	end

	if mod.jukebox then
		mod.jukebox:stop_sample()
	end

	local input_manager = Managers.input

	if self.pushedcursor and input_manager then
		input_manager:pop_cursor(self.__class_name)
		self.pushedcursor = false
	end

	self._is_open = false
	Imgui.close_imgui()
end

function DiscoInfernoConfig:working_settings(all_settings, key)
	local existing = all_settings[key]

	if existing then
		self._working_key = key
		self._working = existing

		return existing
	end

	if self._working_key ~= key or not self._working then
		self._working_key = key
		self._working = default_song_settings()
	end

	return self._working
end

function DiscoInfernoConfig:update()
	if not self._is_open then
		return
	end

	Imgui_set_next_window_size(window_width, window_height)

	if first_run then
		Imgui_set_next_window_pos((RESOLUTION_LOOKUP.width / 2) - (WIDTH / 2) - 100, (RESOLUTION_LOOKUP.height / 2) - (HEIGHT / 2) - 20)
		first_run = false
	end

	local _, closed = Imgui_begin_window(mod:localize("di_config_title"), "always_auto_resize")

	if closed then
		self:close()
	end

	Imgui_set_window_font_scale(ui_scale)

	local jukebox = mod.jukebox
	local songList = jukebox and jukebox:get_music()

	if not jukebox or not songList or #songList == 0 then
		Imgui_text(mod:localize("di_no_songs"))
		Imgui_end_window()

		return
	end

	local all_settings = mod:get("di_song_settings") or {}

	local function saveSettings(song_settings)
		all_settings[mod.selectedSong] = song_settings
		mod:set("di_song_settings", all_settings, false)
		mod._settings_dirty = true
	end

	if Imgui_begin_combo(mod:localize("di_song_current"), mod.selectedSong or "") then
		Imgui_selectable(mod:localize("di_song_select"), not mod.selectedSong)

		for _, v in ipairs(songList) do
			if Imgui_selectable(v.file_path, mod.selectedSong == v.file_path) then
				mod.selectedSong = v.file_path
			end
		end

		Imgui_end_combo()
	end

	if mod.selectedSong then
		local song_settings = self:working_settings(all_settings, mod.selectedSong)

		local newVolume = Imgui_slider_int(mod:localize("di_song_volume"), song_settings.volume or 80, 0, 200)
		if newVolume ~= song_settings.volume then
			song_settings.volume = newVolume
			saveSettings(song_settings)
		end

		Imgui_same_line()

		local playing = jukebox:is_sample_playing()
		local button_text = playing and "||" or ">"

		if Imgui_button(button_text) then
			if playing then
				jukebox:stop_sample()
			else
				jukebox:play_sample(mod.selectedSong, song_settings.volume)
			end
		end

		if Imgui_is_item_hovered() then
			Imgui_begin_tool_tip()
			Imgui_text(mod:localize("di_preview"))
			Imgui_end_tool_tip()
		end

		local newBpm = Imgui_slider_int(mod:localize("di_song_bpm"), song_settings.bpm or 100, 60, 220)
		if newBpm ~= song_settings.bpm then
			song_settings.bpm = newBpm
			saveSettings(song_settings)
		end

		local newIntensity = Imgui_slider_int(mod:localize("di_song_intensity"), song_settings.intensity or 60, 5, 200)
		if newIntensity ~= song_settings.intensity then
			song_settings.intensity = newIntensity
			saveSettings(song_settings)
		end

		local newRainbow = Imgui_checkbox(mod:localize("di_random_lights"), song_settings.rainbow)
		if newRainbow ~= song_settings.rainbow then
			song_settings.rainbow = newRainbow
			saveSettings(song_settings)
		end

		if not song_settings.rainbow then
			local existingColorOne = song_settings.colour_one or { r = 1, g = 0, b = 0 }
			local r, g, b = Imgui_color_edit_3(mod:localize("di_light_left"), existingColorOne.r, existingColorOne.g, existingColorOne.b)
			if r ~= existingColorOne.r or g ~= existingColorOne.g or b ~= existingColorOne.b then
				song_settings.colour_one = { r = r, g = g, b = b }
				saveSettings(song_settings)
			end

			local existingColorTwo = song_settings.colour_two or { r = 1, g = 0, b = 0 }
			local r2, g2, b2 = Imgui_color_edit_3(mod:localize("di_light_right"), existingColorTwo.r, existingColorTwo.g, existingColorTwo.b)
			if r2 ~= existingColorTwo.r or g2 ~= existingColorTwo.g or b2 ~= existingColorTwo.b then
				song_settings.colour_two = { r = r2, g = g2, b = b2 }
				saveSettings(song_settings)
			end
		end
	end

	Imgui_end_window()
end

return DiscoInfernoConfig
