return {
    vstName = "Kontakt", name = "Kontakt", emptyPreset = "not found",
    presets = {"Black", "Death Piano", "Grandeur", "OB pad", "poor naming"},
    params = {A2 = "Chorus",A1 = "Reverb"},
    banks = {
        favorites = { name = "favorites", hue = 338, hikey = 127, sat = 38, nsolo = 0, lokey = 0,
            params = {A5 = "Wah"},
            presets = {"Grandeur", "OB pad"}
        },
        pianos = { name = "pianos", hikey = 127, sat = 80, lokey = 0, midiin = 1, hue = 40, nsolo = 0,
            params = {A1 = "Reverb"},
            presets = {"Black", "Death Piano", "Grandeur", "poor naming"}
        },
        bass = { name = "bass", hue = 261, lokey = 1, sat = 91.666666666667, nsolo = 1, hikey = 52,
            params = {},
            presets = {}
        },
        drums = { name = "drums", hikey = 79, sat = 45.3125, midiin = 1, lokey = 36, fakesus = 0, hue = 144, nsolo = 1,
            params = {},
            presets = {}
        }
    }
}