return {
    name = "test", emptyPreset = "not found",
    presets = {"Black", "poor naming", "Death Piano", "Grandeur", "OB pad"},
    params = {A1 = "Reverb",A2 = "Chorus"},
    banks = {
        favorites = { name = "favorites", hue = 260, sat = 90,
            params = {A5 = "Wah"},
            presets = {"OB pad", "Grandeur" }
        },
        pianos = { name = "pianos", hue = 40, sat = 80,
            params = {A1 = "Reverb"},
            presets = {"Grandeur", "Black", "Death Piano", "poor naming" }
        }
    }
}