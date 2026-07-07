return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Disco Inferno` encountered an error loading the Darktide Mod Framework.")

		new_mod("Disco Inferno", {
			mod_script       = "Disco Inferno/scripts/mods/Disco Inferno/Disco Inferno",
			mod_data         = "Disco Inferno/scripts/mods/Disco Inferno/Disco Inferno_data",
			mod_localization = "Disco Inferno/scripts/mods/Disco Inferno/Disco Inferno_localization",
		})
	end,
	version = "1.0.0",
	packages = {},
}
