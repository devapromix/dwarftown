package.path = package.path .. ';src/?.lua;src/?/init.lua;wrapper/?.lua'

require 'game'

local args = {...}

function main()
   game.open()
   game.init()
   game.mainLoop()
   game.close()
end

function handler(message)
   s = message .. '\n' .. debug.traceback()
   f = io.open('log.txt', 'w')
   f:write(s)
   print(s)
   return true
end

xpcall(main, handler)
--os.exit(0)
