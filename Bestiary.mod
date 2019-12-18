return {
	run = function()
		fassert(rawget(_G, "new_mod"), "Bestiary must be lower than Vermintide Mod Framework in your launcher's load order.")

		new_mod("bestiary", {
			mod_script       = "scripts/mods/Bestiary/Bestiary",
			mod_data         = "scripts/mods/Bestiary/Bestiary_data",
			mod_localization = "scripts/mods/Bestiary/Bestiary_localization"
		})
	end,
	packages = {
		"resource_packages/Bestiary/Bestiary"
	}
}
