module('text', package.seeall)

title = 'Dwarftown v1.2'

helpText = [[
--- Dwarftown ---

Dwarftown was once a rich, prosperous dwarven fortress. Unfortunately, a long
time ago it has fallen, conquered by goblins and other vile creatures.

Your task is to find Dwarftown and recover two legendary dwarven Artifacts
lost there. Good luck!

--- Keybindings ---

Move:  numpad,             Inventory:    i
       arrow keys,         Pick up:      g, ,
                           Drop:         d
Wait:  5, .                Quit:         q, Esc
Look:  x                   Help:         ?
                           Screenshot:   F11

--- Character dump ---

The game saves a character dump to character.txt file.

]]

function getTitleScreen()
   return {
      title,
      '',
      'by hmp <humpolec@gmail.com>',
      '',
      '',
      'Press any key to continue',
   }
end

function getLoadingScreen()
   local sc = getTitleScreen()
   sc[6] = 'Creating the world, please wait...'
   return sc
end
