return {
    name = "test2", emptyPreset = "not found",
    presets = {"Black", "Death Piano", "Gentleman", "Grandeur", "OB pad", "poor naming"}, 
    params = {A1 = "Reverb",A2 = "Chorus"},
    banks = {
        favorites = { name = "favorites", hue = 120, sat = 0.05,
            params = {A5 = "Wah"},
            presets = {"Gentleman", "OB pad"}
        },
        pianos = { name = "pianos", hue = 10, sat = 0.09,
            params = {A1 = "Reverb"},
            presets = {"Black", "Death Piano", "Grandeur", "poor naming"}
        }
    }
}