return {
    name = "Reaktor", emptyPreset = "not found",
    presets = {"Lead Bass", "Mountain Home", "Quiet Place", "Red Cedar", "Rob Service", "Showdown"}, 
    params = {A1 = "Reverb",A2 = "Chorus"},
    banks = {
        favorites = { name = "favorites", hue = 10, sat = 90,
            params = {A1 = "Reverb"},
            presets = {"Lead Bass", "Mountain Home", "Rob Service", "Showdown"}
        },
        prism = { name = "prism", hue = 120, sat = 50,
            params = {A5 = "Wah"},
            presets = {"Lead Bass", "Mountain Home", "Quiet Place", "Red Cedar", "Showdown"}
        },
        skanner = { name = "skanner", hue = 2000, sat = 50,
            params = {A5 = "Wah"},
            presets = {"Rob Service"}
        }
    }
}