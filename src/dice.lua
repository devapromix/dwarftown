module('dice', package.seeall)

function getFloat(lower, greater)
    return lower + math.random()  * (greater - lower);
end

function getInt(a, b)
   return math.random(a, b)
end

-- +1 or -1
function getSign()
   return getInt(0, 1)*2 - 1
end

-- roll AdB+C
function roll(d)
   local a, b, c = unpack(d)
   local n = c
   for i = 1, a do
      n = n + getInt(1, b)
   end
   return n
end

function describe(d)
   local a, b, c = unpack(d)

   s = a .. 'd' .. b
   if c > 0 then
      s = s .. '+' .. c
   elseif c < 0 then
      s = s .. '-' .. -c
   end
   return s
end

function choice(tbl)
   return tbl[getInt(1, #tbl)]
end

-- TODO frequencies
function choiceEx(tbl, level)
   if level and getInt(1, 40) == 1 then
      level = level + getInt(1, 3)
   end
   -- returns nothing or (item, freq)
   local function process(v)
      if level and level > 0 and v.level > level then
         return
      else
         return v, (v.freq or 1)
      end
   end

   local sum = 0
   for _, v in ipairs(tbl) do
      local it, freq = process(v)
      if it then
         sum = sum + freq
      end
   end
   sum = getFloat(0, sum-0.01)
   for _, v in ipairs(tbl) do
      local it, freq = process(v)
      if it then
         sum = sum - freq
         if sum < 0 then
            --print(level, it.name)
            return it
         end
      end
   end
   assert(false)
end

function shuffle(tbl)
   for i = #tbl, 2, -1 do
      local j = getInt(1, i)
      tbl[j], tbl[i] = tbl[i], tbl[j]
   end
end
