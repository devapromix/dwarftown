module('game', package.seeall)

require 'tcod'

require 'ui'
require 'map'
require 'mob'
require 'item'
require 'mapgen.world'
require 'text'

local K = tcod.k
local C = tcod.color
local T = require "BearLibTerminal"

local keybindings = {
   [{T.TK_KP_7}] = {'walk', {-1, -1}},
   [{T.TK_UP, T.TK_KP_8}] = {'walk', {0, -1}},
   [{T.TK_KP_9}] = {'walk', {1, -1}},
   [{T.TK_LEFT, T.TK_KP_4}] = {'walk', {-1, 0}},
   [{T.TK_W, T.TK_KP_5}] = 'wait',
   [{T.TK_RIGHT, T.TK_KP_6}] = {'walk', {1, 0}},
   [{T.TK_KP_1}] = {'walk', {-1, 1}},
   [{T.TK_DOWN, T.TK_KP_2}] = {'walk', {0, 1}},
   [{T.TK_KP_3}] = {'walk', {1, 1}},

   [{T.TK_G}] = 'pickUp',
   [{T.TK_D}] = 'drop',
   [{T.TK_I}] = 'inventory',
   [{T.TK_C}] = 'close',
   [{T.TK_X}] = 'look',
   [{T.TK_ESCAPE}] = 'quit',
   [{T.TK_H}] = 'help',

--   [{T.TK_F11}] = 'screenshot',
--   [{T.TK_F8}] = 'toggleColor',
--   [{T.TK_F12}] = 'mapScreenshot',
}

player = nil
turn = 0
wizard = false
local command = {}
local done = false

function init()
   local reason

   ui.init()
   map.init()

   ui.drawScreen(text.getLoadingScreen())
   local x, y = mapgen.world.createWorld()
   ui.drawScreen(text.getTitleScreen())
   repeat until T.has_input()

   player = mob.Player:make()

   local startingItems
   if not wizard then
      startingItems = {
         item.Torch,
         item.PotionHealth,
      }
   else
      startingItems = {
         item.PotionNightVision,
         item.PickAxe,
         item.Lamp,
         item.ArtifactWeapon,
      }
   end
   for _, icls in ipairs(startingItems) do
      table.insert(player.items, icls:make())
   end

   map.player = player
   player:putAt(x, y)

   turn = 0
   done = false
end

function mainLoop()
   ui.message('Find Dwarftown!')
   ui.message('Press ? for help.')
   while not done do
      ui.update()
      ui.newTurn()
      repeat until T.has_input()
      local key = T.read()
      executeCommand(key)

      while player.energy <= 0 and not player.dead do
         map.tick()
         turn = turn + 1
      end
      if player.dead then
         if game.wizard then
            if not ui.promptYN('Die? [[y/n]]') then
               player.hp = player.maxHp
               player.dead = false
            end
         end
         if player.dead then
            -- use real name, not 'something' or item
            local killer = player.killedBy.class.name
            ui.promptEnter('Game over: killed by %s. Press ENTER', killer)
            done = true
            reason = 'Killed by ' .. killer
         end
      elseif player.leaving then
         if player.nArtifacts == item.N_ARTIFACTS then
            ui.promptEnter('Congratulations! You have won. Press ENTER')
            reason = 'Won the game'
         end
         done = true
      end
   end

   reason = reason or 'Quit the game'
   saveCharacterDump(reason)

   tcod.console.flush()
   T.refresh()
end

-- Returns true if player spent a turn
function executeCommand(key)
   local cmd = getCommand(key)
   if type(cmd) == 'table' then
      command[cmd[1]](unpack(cmd[2]))
   elseif type(cmd) == 'string' then
      command[cmd]()
   end
end

function getCommand(key)
   for keys, cmd in pairs(keybindings) do
      for _, k in ipairs(keys) do
         if key == k then
            return cmd
         end
      end
   end
end

function command.walk(dx, dy)
   player:spendEnergy()
   if player:canAttack(dx, dy) then
      player:attack(dx, dy)
   elseif player:canWalk(dx, dy) then
      player:walk(dx, dy)
   elseif player:canOpen(dx, dy) then
      player:open(dx, dy)
   elseif player:canDig(dx, dy) then
      player:dig(dx, dy)
   else
      player:refundEnergy()
   end
end

function command.close(dx, dy)
   local dirs = {}
   for _, d in ipairs(util.dirs) do
      if player:canClose(d[1], d[2]) then
         table.insert(dirs, d)
      end
   end
   if #dirs == 0 then
      ui.message('There is no door here you can close.')
   elseif #dirs == 1 then
      player:spendEnergy()
      player:close(dirs[1][1], dirs[1][2])
   else
      ui.message('In what direction?')
      ui.newTurn()
      ui.update()
      local key = tcod.console.waitForKeypress(true)
      local cmd = getCommand(key)
      if type(cmd) == 'table' and cmd[1] == 'walk' then
         local dx, dy = unpack(cmd[2])
         if player:canClose(dx, dy) then
            player:spendEnergy()
            player:close(dx, dy)
         end
      end
   end
end

function command.quit()
   if ui.promptYN('Quit? [[y/n]]') then
      done = true
   end
end

function command.wait()
   player:spendEnergy()
   player:wait()
end

function command.pickUp()
   player:spendEnergy()
   local items = player.tile.items
   if items then
      if #items == 1 then
         player:pickUp(items[1])
         return
      end
      local item = ui.promptItems(player, items, 'Select an item to pick up')
      if item then
         player:pickUp(item)
         return
      else
         player:refundEnergy()
      end
   else
      ui.message('There is nothing here.')
      player:refundEnergy()
   end
end

function command.drop()
   local item = ui.promptItems(player, player.items, 'Select an item to drop')
   if item then
      player:drop(item)
      player:spendEnergy()
   end
end

function command.inventory()
   local item = ui.promptItems(player, player.items, 'Select an item to use')
   if item then
      player:use(item)
      player:spendEnergy()
   end
end

function command.look()
   ui.look()
end

function command.help()
   ui.help()
end

function command.screenshot()
   ui.screenshot()
   ui.message(C.green, 'Screenshot saved.')
end

function command.toggleColor()
   ui.coloredMem = not ui.coloredMem
   ui.update()
end

function command.mapScreenshot()
   ui.message('Saving map screenshot...')
   ui.mapScreenshot()
   ui.message(C.green, 'Map screenshot saved.')
end

function saveCharacterDump(reason)
   local f = io.open('character.txt', 'w')
   if not f then
      return
   end
   local function write(...)
      f:write(string.format(...))
   end
   write('  %s character dump\n\n%s\n\n%s\n\n',
         text.title, os.date(), reason)
   write('  SCREENSHOT\n\n')
   write(ui.stringScreenshot())
   write('\n\n  LAST MESSAGES\n\n')
   for i = 1, 15 do
      local n = #ui.messages-15+i
      if ui.messages[n] then
         write('%s\n', ui.messages[n].text)
      end
   end
   write('\n  INVENTORY\n\n')
   write(ui.stringItems(player.items))
   write('\n')
   f:close()
end
