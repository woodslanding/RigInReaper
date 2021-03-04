--[[Last Edited: Mar 4 14:27]]
return {
    vstName = "Reaktor 6", name = "reaktor", emptyPreset = "",hue = 0, hikey = 127, sat = 0, midiin = 1, lokey = 0, 
    presets = {"2nd Harmonium", "Acoustic Bass", "alpen drive", "alto flute", "Bad Actor", "Bassonery", "Chirp Synth", "clank", "Clarinets", "Clear Bell", "ElectroClav", "ElectroTuba", "Fat Clav", "flutar", "frippery", "fuzz floot", "ghost flute", "ghost Train", "Glass Harp", "heavy breathing", "Horn Ensemble", "Hudi-gurdi", "Knell", "Kora", "Lead Bass", "Light Bulb", "lowrey", "Marxophone", "MoonFX", "More Quacking", "Mountain Home", "new whirled", "Obese Clav", "Oboid Jazz", "Panorama", "Prism", "Quacking", "quiet place ", "Rayong", "red cedar", "Saturated Ping", "SheenPad", "Showdown", "Silent Movie", "Silent Screen", "Silver Bowl", "Silver Screen", "Soft Koto", "steampipe", "Steel String", "Talkbox Bass", "theater flutes", "theater flutes 2", "Thin Pad", "Third Man", "treadwell pad", "Tubular Bells", "whisper cycle", "Winwood", "Wooden Bars", "Zenith", "Zithar Pad"}, 
    params = {},
    banks = {
        { name = "favorites", hue = 0, hikey = 127, sat = 74, lokey = 1, 
            params = {},
            presets = {"ElectroClav", "Fat Clav", "Lead Bass", "Soft Koto", "treadwell pad"}
        },
        { name = "moonFX", hikey = 127, sat = 63, midiin = 0, hue = 240, isfx = 1, lokey = 1, 
            params = {},
            presets = {"MoonFX"}
        },
        { name = "photone", hue = 60, hikey = 127, sat = 73, trim = -4, lokey = 1, 
            params = {},
            presets = {}
        },
        { name = "prism", hikey = 127, trim = 0, sat = 73, midiin = 1, hue = 278, lokey = 1, 
            params = {DRB5 = 18,ENC8 = 5,ENC7 = 17,ENC4 = 9,ENC1 = 10,SWA3 = 21,ENC6 = 4,ENC3 = 10,ENC5 = 18,SWA5 = 10,SWA4 = 21,ENC2 = 10,SWB2 = 21,SWB1 = 10,SWA6 = 21,SWB5 = 1,SWB3 = 11},
            presets = {"Bad Actor", "ElectroClav", "ghost flute", "Glass Harp", "Hudi-gurdi", "Kora", "Lead Bass", "Marxophone", "More Quacking", "Mountain Home", "Panorama", "Showdown", "Soft Koto", "whisper cycle", "Winwood"}
        }
    }
}