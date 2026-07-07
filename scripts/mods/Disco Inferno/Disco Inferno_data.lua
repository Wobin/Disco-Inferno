local mod = get_mod("Disco Inferno")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "di_show_config",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "di_debug",
				type = "checkbox",
				default_value = false,
			},
		},
	},
}
