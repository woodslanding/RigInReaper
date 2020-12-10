return {
    vstName = "Reaktor5", name = "Reaktor", emptyPreset = "<empty>",
    presets = {"Lead Bass", "Mountain Home", "Quiet Place", "Red Cedar", "Rob Service", "Showdown"}, 
    params = {TGA2 = 23,TGB3 = 24},
    banks = {
        skanner = { name = "skanner", sat = 63, hikey = 109, hue = 247, 
            params = {A5 = "Wah"},
            presets = {"Lead Bass"}
        },
        favorites = { name = "favorites", sat = 90, hue = 10, 
            params = {A1 = "Reverb"},
            presets = {"Mountain Home", "Rob Service", "Showdown"}
        },
        prism = { name = "prism", trim = 87, sat = 71, hikey = 127, hue = 281, 
            params = {AT = 11,SWA6 = 1,SWB4 = 1,BC = 10,TGB4 = 10,PED2 = 1,TGA4 = 9,TGB2 = 6,EXP = 1,DRB2 = 6,TGB3 = 6,SWA4 = 1,TGA2 = 7,SWA7 = 1,MW = 9,SWB5 = 1},
            presets = {"Lead Bass", "Mountain Home", "Quiet Place", "Red Cedar", "Showdown"}
        }
    }
}