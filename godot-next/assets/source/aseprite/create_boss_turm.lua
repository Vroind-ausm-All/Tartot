-- TARTOT · XVI Der Turm
-- Aseprite helper: creates a production-ready sprite document with layers/tags.
-- Run via File -> Scripts -> Open Script Folder, copy this file there, then run it.
local spr = Sprite(128, 160, ColorMode.RGB)
spr.filename = "boss_turm.aseprite"
spr:setPalette(Palette(8))
local pal = spr.palettes[1]
pal:setColor(0, Color{r=26,g=20,b=18,a=255})   -- Ink
pal:setColor(1, Color{r=239,g=227,b=200,a=255})-- Paper
pal:setColor(2, Color{r=201,g=180,b=142,a=255})-- Sepia 1
pal:setColor(3, Color{r=143,g=122,b=90,a=255}) -- Sepia 2
pal:setColor(4, Color{r=78,g=64,b=50,a=255})   -- Sepia 3
pal:setColor(5, Color{r=227,g=168,b=59,a=255}) -- Gold
pal:setColor(6, Color{r=179,g=38,b=43,a=255})  -- Blood
pal:setColor(7, Color{r=59,g=74,b=140,a=255})  -- Indigo

local layer_names = {"outline","body","face","gloves","cracks","lightning","fx"}
for _,name in ipairs(layer_names) do
  local l = spr:newLayer()
  l.name = name
end
spr.layers[1].name = "guide"

local function add_frames(n)
  while #spr.frames < n do spr:newEmptyFrame() end
end
add_frames(35)

local function tag(name, a, b)
  local t = spr:newTag(a,b)
  t.name = name
end

tag("idle", 1, 4)
tag("intro", 5, 9)
tag("attack", 10, 15)
tag("hit", 16, 18)
tag("break", 19, 24)
tag("phase_2", 25, 31)
tag("death", 32, 35)

for i=1,#spr.frames do
  spr.frames[i].duration = 1/12
end

-- Guide marks
local guide = spr.layers[1]
local img = Image(128,160,ColorMode.RGB)
img:clear()
local ink = pal:getColor(0)
local sepia = pal:getColor(2)
local red = pal:getColor(6)
local gold = pal:getColor(5)

-- rough silhouette guide, not final art
img:drawRectangle(Rectangle(38,40,52,100), sepia)
img:drawRectangle(Rectangle(38,40,52,100), ink, 2)
img:drawRectangle(Rectangle(45,22,12,22), sepia)
img:drawRectangle(Rectangle(70,22,12,22), sepia)
img:drawLine(Point(64,38), Point(58,75), red)
img:drawLine(Point(58,75), Point(72,103), red)
img:drawLine(Point(92,20), Point(78,52), gold)
spr:newCel(guide, spr.frames[1], img, Point(0,0))

app.activeSprite = spr
app.refresh()
