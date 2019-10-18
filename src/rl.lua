package.path = package.path .. ';src/?.lua;src/?/init.lua;wrapper/?.lua'

require 'game'
require 'mapgen'
require 'mapgen.tree'

local args = {...}
local T = require "BearLibTerminal"

elvion = true

function main()
   T.open()
   T.refresh()
   game.init()
   game.mainLoop()
   T.close()
end

function handler(message)
   s = message .. '\n' .. debug.traceback()
   f = io.open('log.txt', 'w')
   f:write(s)
   print(s)
   return true
end

xpcall(main, handler)
os.exit(0)

T.refresh() 
repeat 
  key = T.read() 
until key == T.TK_CLOSE or key == T.TK_ESCAPE 
