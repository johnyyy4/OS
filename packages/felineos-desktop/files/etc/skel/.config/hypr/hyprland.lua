-- Your Hyprland config (felineOS)
--
-- This loads the felineOS defaults first, so you keep getting theme fixes and
-- improvements through normal system updates. Put your own changes BELOW it;
-- anything you set here overrides the defaults.
--
-- Want full control instead? Delete the dofile line and copy
-- /usr/share/felineos/config/hypr/hyprland.lua into this file.
dofile("/usr/share/felineos/config/hypr/hyprland.lua")

-- Examples (remove the "--" to enable):
-- hl.config({ general = { gaps_out = 20 } })
-- hl.config({ input = { kb_layout = "pl" } })
-- hl.bind("SUPER + B", hl.dsp.exec_cmd("firefox"))
