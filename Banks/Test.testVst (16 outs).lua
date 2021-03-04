--[[Last Edited: Mar 4 14:46]]
return {
    vstName = "testVst (16 outs)", name = "Test", emptyPreset = "not found",lokey = 0, sat = 0, midiin = 1, hue = 0, hikey = 127, 
    presets = {"Black", "Death Piano", "Grandeur", "OB pad", "poor naming", "Really Rad Bass!"}, 
    params = {A1 = "Reverb",hue = 300,A2 = "Chorus"},
    banks = {
        { name = "aardvarks", sat = 60, lokey = 1, hue = 160, hikey = 127, 
            params = {A1 = "Reverb"},
            presets = {}
        },
        { name = "basses", trim = 80, sat = 80, lokey = 1, hue = 300, hikey = 60, 
            params = {},
            presets = {"Really Rad Bass!"}
        },
        { name = "favorites", sat = 80, lokey = 30, hue = 120, hikey = 102, 
            params = {A5 = "Wah"},
            presets = {"Grandeur", "OB pad"}
        },
        { name = "pianos", sat = 60, lokey = 1, hue = 10, hikey = 127, 
            params = {},
            presets = {"Black", "Death Piano", "Grandeur", "poor naming"}
        }
    }
}