module('spell', package.seeall)

require 'tcod'
require 'class'
require 'util'
require 'mob'


Spell = class.Object:subclass {
   exclude = true,
   name = '<spell>',
   level = 1,
}

util.addRegister(Spell)

Heal = Spell:subclass {
   level = 1,
   mana = 25,
   heal = 30,

   onCast =
      function(self, player)
         player:heal(self.heal)
      end,
}

