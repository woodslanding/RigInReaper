return {
    vstName = "testVst (16 outs)", name = "Test", emptyPreset = "not found",
    presets = {"Black", "Death Piano", "Grandeur", "OB pad", "poor naming", "Really Rad Bass!"}, 
    params = {A1 = "Reverb",A2 = "Chorus"},
    banks = {
        { name = "basses", lokey = 1, hikey = 60, hue = 300, trim = 80, sat = 80, 
            params = {},
            presets = {"Really Rad Bass!"}
        },
        { name = "favorites", lokey = 30, hikey = 102, hue = 120, sat = 80, 
            params = {A5 = "Wah"},
            presets = {"Grandeur", "OB pad"}
        },
        { name = "pianos", lokey = 1, hikey = 127, hue = 10, sat = 60, 
            params = {A1 = "Reverb"},
            presets = {"Black", "Death Piano", "Grandeur", "poor naming"}
        }
    }
}