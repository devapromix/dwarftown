module('ui', package.seeall)

require 'tcod'
require 'map'
require 'mob'
require 'util'
require 'text'

local C = tcod.color
local T = require "BearLibTerminal"

SCREEN_W = 80
SCREEN_H = 25

VIEW_W = 48
VIEW_H = 23

STATUS_W = 29
STATUS_H = 12

MESSAGES_W = 30
MESSAGES_H = 10

coloredMem = false

local viewConsole
local messagesConsole
local rootConsole
local statusConsole

messages = {}

local ord = string.byte
local chr = string.char

function init()
   tcod.console.setCustomFont(
      'wrapper/terminal.png', tcod.FONT_LAYOUT_ASCII_INCOL, 16, 16)
   tcod.console.initRoot(
      SCREEN_W, SCREEN_H, 'Dwarftown', false, tcod.RENDERER_SDL)
   rootConsole = tcod.console.getRoot()

   viewConsole = tcod.Console(VIEW_W, VIEW_H)
   messagesConsole = tcod.Console(MESSAGES_W, MESSAGES_H)
   statusConsole = tcod.Console(STATUS_W, STATUS_H)

   messages = {}
end

function update()
   rootConsole:clear()
   T.clear()
   drawMap(map.player.x, map.player.y)
   drawMessages()
   drawStatus(map.player)
   blitConsoles()
   T.refresh()
end

function blitConsoles()
   tcod.console.blit(
      viewConsole, 0, 0, VIEW_W, VIEW_H,
      rootConsole, 1, 1)
   tcod.console.blit(
      statusConsole, 0, 0, STATUS_W, STATUS_H,
      rootConsole, 1+VIEW_W+1, 1)
   tcod.console.blit(
      messagesConsole, 0, 0, MESSAGES_W, MESSAGES_H,
      rootConsole, 1+VIEW_W+1, 1+STATUS_H+1)
   tcod.console.flush()
end

-- ui.message(color, format, ...)
-- ui.message(format, ...)
function message(a, ...)
   local msg = {new = true}
   if type(a) == 'string' then
      msg.text = string.format(a, ...)
      msg.color = C.white
   else
      msg.text = string.format(...)
      msg.color = a or C.white
   end
   msg.text = util.capitalize(msg.text)
   table.insert(messages, msg)
   drawMessages()
end

-- ui.prompt({K.ENTER, K.KPENTER}, '[[Game over. Press ENTER]]')
function prompt(keys, ...)
   message(...)
   update()
   newTurn()
   while true do
      repeat until T.has_input()
      local key = T.read()
      for _, k in ipairs(keys) do
         if k == key then
            return k
         elseif not k then
            return false
         end
      end
   end
end

function promptYN(...)
   local result = prompt({T.TK_Y, false}, C.green, ...)
   return result == T.TK_Y
end

function promptEnter(...)
   prompt({T.TK_ENTER, T.TK_RETURN}, C.yellow, ...)
end

function promptItems(player, items, ...)
   update()
   local text = string.format(...)
   itemConsole = tcod.Console(VIEW_W, #items + 2)
   T.clear_area(1,1,VIEW_W, #items + 2)
   itemConsole:setDefaultForeground(C.white)
   itemConsole:print(0, 0, text)
   T.print(1, 1, text)
   local v = ('%d/%d'):format(#player.items, player.maxItems)
   itemConsole:print(VIEW_W - #v, 0, v)
   T.print(VIEW_W - #v + 1, 1, v)

   local letter = ord('a')
   for i, it in ipairs(items) do
      local s
      local color
      if it.artifact then
         color = C.lightGreen
      else
         color = C.white
      end
      if it.equipped then
         s = ('%c *   %s'):format(letter+i-1, it.descr)
      else
         color = color * 0.5
         s = ('%c     %s'):format(letter+i-1, it.descr)
      end
      itemConsole:setDefaultForeground(color)
      itemConsole:print(0, i+1, s)
      T.print(1, i+2, s)

      local char, color = glyph(it.glyph)
      itemConsole:putCharEx(4, i+1, char, color,
                            C.black)
      T.put(5, i+2, char)
	end
   tcod.console.blit(itemConsole, 0, 0, VIEW_W, #items + 2,
             rootConsole, 1, 1)
   tcod.console.flush()
   T.refresh()
   if elvion then
      repeat until T.has_input()
      local key = T.read()
      if key >= T.TK_A and key <= T.TK_Z then
         local i = ord(key) - ord(T.TK_A) + 1
         if items[i] then
            return items[i]
         end
      end
   else
      local key = tcod.console.waitForKeypress(true)
      if ord(key.c) then
         local i = ord(key.c) - letter + 1
         if items[i] then
            return items[i]
         end
      end
   end
end

function stringItems(items)
   local lines = {}
   for i, it in ipairs(items) do
      local letter = ord('a') - 1 + i
      local s
      if it.equipped then
         s = ('%c * %s %s'):format(letter, it.glyph[1], it.descr)
      else
         s = ('%c   %s %s'):format(letter, it.glyph[1], it.descr)
      end
      table.insert(lines, s)
   end
   return table.concat(lines, '\n')
end

function newTurn()
   local i = #messages
   while i > 0 and messages[i].new do
      messages[i].new = false
      i = i - 1
   end
end

function drawStatus(player)
   local sector = map.getSector(player.x, player.y)
   local sectorName, sectorColor
   if sector then
      sectorName = sector.name
      sectorColor = sector.color
   end
   local lines = {
      {sectorColor or 'white', sectorName or ''},
      {'', ''},
      {'', 'Turn     %d', game.turn},
      {'', ''}, -- line 4: health bar
      {'', 'HP       %d/%d', player.hp, player.maxHp},
      {'', 'Level    %d (%d/%d)', player.level, player.exp, player.maxExp},
      {'', 'Attack   %s', dice.describe(player.attackDice)},
   }

   if player.armor ~= 0 then
      table.insert(lines, {'', 'Armor    %s', util.signedDescr(player.armor)})
   end
   if player.speed ~= 0 then
      table.insert(lines, {'', 'Speed    %s', util.signedDescr(player.speed)})
   end

   statusConsole:clear()
   T.clear_area(1+VIEW_W+1, 1, STATUS_W, STATUS_H)
   statusConsole:setDefaultForeground(C.lightGrey)
   T.color('light grey')
   for i, msg in ipairs(lines) do
      T.color(msg[1])
      local s = string.format(unpack(msg, 2))
      statusConsole:print(0, i-1, s)
      T.print(1+VIEW_W+1, i, s)
   end

   if player.hp < player.maxHp then
      local c = 'green'
	  if player.hp < player.maxHp * .66 then
	     c = 'yellow'
	  end
	  if player.hp < player.maxHp * .33 then
	     c = 'red'
      end
      drawHealthBar(3, player.hp / player.maxHp, c)
   end

   if player.enemy then
      local m = player.enemy
      if m.x and m.visible and
         map.dist(player.x, player.y, m.x, m.y) <= 2
      then
	      local f = ('%s (%d/%d)'):format(m.descr, m.hp, m.maxHp)
         local s = ('L%d %-18s %s'):format(
            m.level, f, dice.describe(m.attackDice))
         statusConsole:setDefaultForeground(m.glyph[2])
         T.color(m.glyph[2])
         statusConsole:print(0, STATUS_H-2, s)
         T.print(1+VIEW_W+1, STATUS_H-1, s)
         if m.hp < m.maxHp then
            drawHealthBar(STATUS_H-1, m.hp/m.maxHp, m.glyph[2])
         end
      else
         player.enemy = nil
      end
   end
end

function drawHealthBar(y, fract, color)
   color = color or 'white'
   local health = math.ceil((STATUS_W-2) * fract)
   --statusConsole:putCharEx(0, y, ord('['), C.grey, C.black)
   T.color('grey')
   T.print(1+VIEW_W+1, y+1, '[[')
   --statusConsole:putCharEx(STATUS_W - 1, y, ord(']'), C.grey, C.black)
   T.print(1+VIEW_W+1+STATUS_W - 1, y+1, ']]')
   for i = 1, STATUS_W-2 do
      if i - 1 < health then
         --statusConsole:putCharEx(i, y, ord('*'), color, C.black)
         T.color(color)
         T.put(1+VIEW_W+1+i, y+1, ord('*'))
      else
         --statusConsole:putCharEx(i, y, ord('-'), C.grey, C.black)
         T.color('grey')
         T.put(1+VIEW_W+1+i, y+1, ord('-'))
      end
   end
end

function drawMessages()
   messagesConsole:clear()
   T.clear_area(1+VIEW_W+1, 1+STATUS_H+1, MESSAGES_W, MESSAGES_H)

   local y = MESSAGES_H
   local i = #messages

   while y > 0 and i > 0 do
      local msg = messages[i]
      local color = msg.color
      if not msg.new then
         color = color * 0.6
         --color = 'darkest ' .. color
      end
      --messagesConsole:setDefaultForeground(color)
      T.color(color)
      local lines = splitMessage(msg.text, MESSAGES_W)
      for i, line in ipairs(lines) do
         local y1 = y - #lines + i - 1
         if y1 >= 0 then
            messagesConsole:print(0, y1, line)
            T.print(1+VIEW_W+1, 1+STATUS_H+1+y1, line);
         end
      end
      y = y - #lines
      i = i - 1
   end
end

function splitMessage(text, n)
   local lines = {}
   for _, w in ipairs(util.split(text, ' ')) do
      if #lines > 0 and w:len() + lines[#lines]:len() + 1 < n then
         lines[#lines] = lines[#lines] .. ' ' .. w
      else
         table.insert(lines, w)
      end
   end
   return lines
end

function drawMap(xPos, yPos)
   local xc = math.floor(VIEW_W/2)
   local yc = math.floor(VIEW_H/2)
   viewConsole:clear()
   T.clear_area(1, 1, VIEW_W, VIEW_H)
   for xv = 0, VIEW_W-1 do
      for yv = 0, VIEW_H-1 do
         local x = xv - xc + xPos
         local y = yv - yc + yPos
         local tile = map.get(x, y)
         if not tile.empty then
            local char, color = tileAppearance(tile)
            viewConsole:putCharEx(xv, yv, char, color, C.black)
            T.color(color)
            T.bkcolor(C.black)
            T.put(xv+1, yv+1, char);
         end
      end
   end
end

function glyph(g)
   local char = ord(g[1])
   local color = g[2] or C.pink
   return char, color
end

function tileAppearance(tile)
   local char, color

   if tile.visible then
      char, color = glyph(tile:getSeenGlyph())
      if map.player.nightVision then
         if tile.seenLight > 0 then
            color = color * 2
         end
      else
         if tile.seenLight == 0 then
            color = color * 0.7

            --[[
            local sat = color:getSaturation()
            local val = color:getValue()
            color = tcod.Color(color.r,color.g,color.b)
            color:setSaturation(sat*0.8)
            color:setValue(val*0.7)
            --]]
         end
      end
   else
      char, color = glyph(tile.memGlyph)
      if coloredMem then
         if tile.memLight == 0 then
            color = color * 0.35
         else
            color = color * 0.6
         end
      else
         if tile.memLight == 0 then
            color = C.darkerGrey * 0.6
         else
            color = C.darkerGrey
         end
      end
   end

   return char, color
end

function look()
   -- on-screen center
   local xc = math.floor(VIEW_W/2)
   local yc = math.floor(VIEW_H/2)
   -- on-map center
   local xPos, yPos = map.player.x, map.player.y
   -- on-screen cursor position
   local xv, yv = xc, yc

   local savedMessages = messages
   messages = {}

   ui.message('Look mode: use movement keys to look, ' ..
              'Alt-movement to jump.')
   ui.message('')
   local messagesLevel = #messages
   while true do

      -- Draw highlighted character
      local char = viewConsole:getChar(xv, yv)
      local color = viewConsole:getCharForeground(xv, yv)
      if char == ord(' ') then
         color = C.white
      end

      viewConsole:putCharEx(xv, yv, char, C.black, color)

      -- Describe position
      local x, y = xv - xc + xPos, yv - yc + yPos
      describeTile(map.get(x, y))

      blitConsoles()
      T.refresh()

      -- Clean up
      viewConsole:putCharEx(xv, yv, char, color, C.black)
      while #messages > messagesLevel do
         table.remove(messages, #messages)
      end

      -- Get keyboard input
      repeat until T.has_input()
      local key = T.read()
      local cmd = game.getCommand(key)
      if type(cmd) == 'table' and cmd[1] == 'walk' then
         local dx, dy = unpack(cmd[2])

         if T.check(T.TK_ALT) then
            dx, dy = dx*10, dy*10
         end

         if 0 <= xv+dx and xv+dx < VIEW_W and
            0 <= yv+dy and yv+dy < VIEW_H
         then
            xv, yv = xv+dx, yv+dy
         else -- try to scroll instead of moving the cursor
            if 0 <= xPos+dx and xPos+dx < map.WIDTH and
               0 <= yPos+dy and yPos+dy < map.HEIGHT
            then
               xPos = xPos + dx
               yPos = yPos + dy
               drawMap(xPos, yPos)
            end
         end
      elseif key ~= T.TK_SHIFT and key ~= T.TK_ALT and key ~= T.TK_CONTROL then
         break
      end
   end

   messages = savedMessages
   blitConsoles()
end

function describeTile(tile)
   if tile and tile.visible then
      message(tile.glyph[2], '%s.', tile.name)
      if tile.mob and tile.mob.visible then
         message(tile.mob.glyph[2], '%s.', tile.mob.descr)
      end
      if tile.items then
         for _, item in ipairs(tile.items) do
            message(item.glyph[2], '%s.', item.descr)
         end
      end
   else
      message(C.grey, 'Out of sight.')
   end
end

function help()
   T.clear()
   T.color('lighter grey')
   T.print(1, 1, text.helpText);
   T.refresh()
   repeat until T.has_input()
end

function screenshot()
   tcod.system.saveScreenshot(nil)
end

function stringScreenshot()
   local lines = {}

   for y = 0, SCREEN_H-1 do
      local line = ''
      for x = 0, SCREEN_W-1 do
         line = line .. chr(rootConsole:getChar(x, y))
      end
      table.insert(lines, line)
   end

   local sep = ''
   for x = 0, SCREEN_W-1 do
      sep = sep .. '-'
   end
   table.insert(lines, sep)
   table.insert(lines, 1, sep)

   return table.concat(lines, '\n')
end

---[[
function mapScreenshot()
   local con = tcod.Console(map.WIDTH, map.HEIGHT)
   con:clear()
   ---[[
   for x = 0, map.WIDTH-1 do
      for y = 0, map.HEIGHT-1 do
         --print(x,y)
         local tile = map.get(x, y)
         if not tile.empty then
            local char, color = tileAppearance(tile)
            con:putCharEx(x, y, char, color, C.black)
         end
      end
   end
   --]]
   --local image = tcod.Image(con)
   --print(con:getWidth(), con:getHeight())
   --image:refreshConsole(con)
   --image:save('map.png')
end
--]]

function drawScreen(sc)
   T.clear()
   local start = math.floor((SCREEN_H-#sc-1)/2)
   local center = math.floor(SCREEN_W/2)
   for i, line in ipairs(sc) do
      if type(line) == 'table' then
         local color
         color, line = unpack(line)
         T.color(color)
      end
	   T.print(center - math.floor(#line/2), start+i-1, line)
   end
   T.refresh()
end
