local mod = get_mod("Disco Inferno")

local TrackOptions = mod:io_dofile("Disco Inferno/scripts/mods/Disco Inferno/modules/TrackOptions")

mod.track_options = TrackOptions

local tracks = TrackOptions.list_tracks()

TrackOptions.tracks = tracks
TrackOptions.migrate(tracks)

local widgets = {
	{
		setting_id = "di_global_rainbow",
		type = "checkbox",
		tooltip = "di_global_rainbow_desc",
		default_value = false,
	},
	{
		setting_id = "di_global_volume",
		type = "numeric",
		tooltip = "di_global_volume_desc",
		default_value = 100,
		range = { 0, 200 },
		decimals_number = 0,
	},
	{
		setting_id = "di_debug",
		type = "checkbox",
		default_value = false,
	},
}

if #tracks > 0 then
	widgets[#widgets + 1] = TrackOptions.build_widgets(tracks)
	widgets[#widgets + 1] = {
		setting_id = "di_preview_track",
		type = "button",
		title = "di_preview_track",
		button_text = "di_preview_track_button",
		button_trigger = "pressed",
		function_name = "preview_selected_track",
	}
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = widgets,
	},
}
