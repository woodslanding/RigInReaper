--Moon bank format, with no concern for reabank compatibility
--V2:  looking more like TAGS than banks.  There are just too many times a sound
--could belong in several categories...
--[[
   we want to populate the combos with two things:
    1.  a list of banks for this particular VST
    2.  a list of presets for the selected bank.
    so the function would be:  loadPresets(vstName,bankname)
    this would search the file vstName and return 2 values:
        1. a list of all the bank names for this vstName
        2. a list of all the presets in the bank 'bankname'
    selecting a bank parses the moonBank file, and creates bank lists for it
    -----------------------
    If we have a 1-button solution to converting vst built-in programs to RPLs,
    (updating) we can deal exclusively with RPLs.  

    for creating the .mbf file we need:
    1.  A means of viewing ALL presets for a vst (rpl list) and assigning each one
        to one or more banks.  This can be a fullscreen window with button arrays
        on the left for presets, and the right for banks.  The bank buttons are 
        multi-select, and bank data is written whenever the preset is changed. 
        they also need some indication of 'last selected', for bank editing. 
        It should show a lot of (32?) banks, with option for paging  
        It should be associated with a track so the selected preset can be auditioned.  
    2.  Also needs: Buttons for creating, renaming, reordering, coloring, and deleting banks/tags.
    3.  Need a window for assigning params to widgets, both globally and per bank.  Global could be
        in a page of main window, but bank should probably be accessed from the bank edit page.

    We should be able to save the current preset from this page.  When a preset has been edited,
    we can open this page and 
    1.  Just save the preset under its current name  or
    2.  Select a new name and bank(s) for the preset


return {
    name = 'Reaktor',
    emptyPreset = 'not found',
    --GLOBAL MAPPINGS, apply across all banks.
    params = {
        --don't map encoder push mappings, they are just for soloing (receive only on this track)
        --E1...E8,   --encoder mappings
        --L1...L8,   --lower button mappings  
        --U1...U8,   --upper button mappings
        --F1...F4,   --footswitch mappings
        --T1...T8,   --organ toggle mappings
        --D1...D9,   --drawbar mappings
        
        --names below are the actual param names from the plugin:
        E5='Attack', E6='Release', E7='Resonance', E8='Cutoff',  --support for curves? hi/low limits?
        U1='Mono/Poly',U2='Legato',
        L6='Chorus', L7='Delay', L8='Reverb',

    },
    banks =  {
        Prism = {
            name='Prism', hue=235, sat=.74556,
            --can override global mappings.  for simplicity, no overrides for individual presets
            params = {E1='Modal Bank', E2='Timer Delay'},       
            presets= {'Alpine Drive', 'Lead Bass', 'Mountain Clav', 'Showdown' } --etc.
        },
        Photone = {
            n='Photone', hue=120, sat=.32566,
            --all the same optional mappings
            presets= {'5th orch','Foxfur','Black Market'}
        },
        Favorites = {
            n='Favorites',hue=80, sat=.45566,
            --presets can exist in multiple banks
            presets = {'Alpine Drive','Rob Service','Black Market'}
        }
    }
}
MEANWHILE IN ANOTHER FILE--one vst per file
--************************************************************************************
plugin { 
    name='Kontakt', 
    emptyPreset = '',
    gParams = {}, 
    banks = {
        name='Pianos', hue=14,sat=.45, presets = {'Black','forster'}
    }
}
table.sort(plugin.presets)
--table.sort (t)
print('presets = {\"'..table.concat (plugin.presets,'\", \"')..'\" }')]]
