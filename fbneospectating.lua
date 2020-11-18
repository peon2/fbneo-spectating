print "fbneo basic spectator script for fightcade written by peon2."
print "Special thanks to the fightcade team for adding lua functionality."
print "Huge thanks to Dammit (dammit9x@hotmail.com) for writing the input-display and scrolling-input-display."
print "I'm not sure who exactly wrote the hitboxes scripts but I found them through the mame-rr github and that's where they point to as well."
print ""
print "Flip through the scrolling inputs with Macro 1 (Alt+1 on fc)"
print "Toggle the simple inputs with Macro 2 (Alt+2 on fc)"
print "Toggle hitboxes (if applicable) with Macro 3 (Alt+3 on fc)"

local cps3 = {sfiii=true, sfiii2=true, sfiii3nr1=true, redearth=true}
local cps2 = {sfa=true, sfa2u=true, sfa3=true, vhuntjr2=true, vhunt=true, vampjr1=true, vsav=true, vsavj=true, vsav2=true, ringdest=true, sgemf=true}
local sf2 = {sf2=true, sf2ce=true, sf2hf=true, ssf2t=true, ssf2=true, hsf2=true, ssf2xjr1=true}
local garou = {fatfury1=true, fatfury2=true, fatfursp=true, fatfury3=true, rbff1=true, rbffspec=true, rbff2=true, garou=true}
local kof = {kof94=true, kof95=true, kof96=true, kof97=true, kof98=true, kof99=true, kof2000=true, kof2001=true, kof2002=true}
local marvel = {xmcota=true, xmcotajr=true, xmcotaj3=true, xmcotaj2=true, xmcotaj1=true, xmcotah=true, msh=true, msha=true, mshjr1=true, mshud=true, mshu=true, mshb=true, mshh=true, mshj=true, xmvsf=true, xmvsfjr2=true, xmvsfar2=true, xmvsfar1=true, xmvsf=true, xmvsfa=true, mshvsf=true, mshvsfa1=true, mshvsf=true, mshvsfj1=true, mshvsfj=true, mshvsfu=true, mvsc=true}

local rom = emu.romname()
if cps3[rom] then
	print("Found rom "..rom.." to be a cps3 game")
	iconfile = "icons-capcom-32.png" -- scrolling inputs
	dofile("spectating\\hitboxes\\cps3-hitboxes.lua")
	dofile("spectating\\input-display.lua")
	dofile("spectating\\scrolling-input-display.lua")

	emu.registerstart(function() cps3regstart() inputdisplaystart() end)
	gui.register(function() cps3hitboxesreg() scrollinginputreg() inputdisplayreg() end)
	emu.registerafter(function() cps3hitboxesregafter() scrollinginputregafter() end)
elseif cps2[rom] then -- scrolling inputs arent working (crash)
	
	print("Found rom "..rom.." to be a cps2 game")
	iconfile = "icons-capcom-32.png" -- scrolling inputs
	dofile("spectating\\hitboxes\\cps2-hitboxes.lua")
	dofile("spectating\\input-display.lua")
	dofile("spectating\\scrolling-input-display.lua")
 
	
	emu.registerstart(function() cps2hitboxesregstart() inputdisplaystart() end) --  inputdisplaystart()
	gui.register(function() cps2hitboxesreg() scrollinginputreg() inputdisplayreg() end) --  scrollinginputreg()  
	emu.registerafter(function() cps2hitboxesregafter() scrollinginputregafter() end) --  scrollinginputregafter()
elseif sf2[rom] then -- make sure rom names are correct
	print("Found rom "..rom.." to be a sf2 game")
	iconfile = "icons-capcom-32.png" -- scrolling inputs
	dofile("spectating\\hitboxes\\sf2-hitboxes.lua")
	dofile("spectating\\input-display.lua")
	dofile("spectating\\scrolling-input-display.lua") --fix this

	emu.registerstart(function() sf2hitboxesregstart() inputdisplaystart() end) --
	gui.register(function() sf2hitboxesreg() scrollinginputreg() inputdisplayreg() end) --   
	emu.registerafter(function() sf2hitboxesregafter() scrollinginputregafter() end) -- 
		
elseif marvel[rom] then
	print("Found rom "..rom.." to be a marvel game")
	iconfile = "icons-capcom-32.png" -- scrolling inputs
	dofile("spectating\\input-display.lua")
	dofile("spectating\\scrolling-input-display.lua")
	dofile("spectating\\hitboxes\\marvel-hitboxes.lua")

	emu.registerstart(function() marvelhitboxesregstart() inputdisplaystart() end) -- inputdisplaystart() end) --
	gui.register(function() marvelhitboxesreg() scrollinginputreg()  inputdisplayreg() end) -- scrollinginputreg()  inputdisplayreg() end) --
	emu.registerafter(function() marvelhitboxesregafter() scrollinginputregafter() end) --  end) --
	
elseif garou[rom] then -- needs more testing
	print("Found rom "..rom.." to be a garou game")
	iconfile = "icons-neogeo-32.png" -- scrolling inputs
	dofile("spectating\\hitboxes\\garou-hitboxes.lua")
	dofile("spectating\\input-display.lua")
	dofile("spectating\\scrolling-input-display.lua")

	emu.registerstart(function()  inputdisplaystart() end) --garouhitboxesregstart()
	gui.register(function()  scrollinginputreg() inputdisplayreg() end) --garouhitboxesreg()
	emu.registerafter(function()  scrollinginputregafter() end) --garouhitboxesregafter()
	
elseif kof[rom] then -- needs more testing + checking roms
	print("Found rom "..rom.." to be a kof game")
	iconfile = "icons-neogeo-32.png" -- scrolling inputs
	dofile("spectating\\hitboxes\\kof-hitboxes.lua")
	dofile("spectating\\input-display.lua")
	dofile("spectating\\scrolling-input-display.lua")

	emu.registerstart(function() kofhitboxesregstart() inputdisplaystart() end)
	gui.register(function() kofhitboxesreg() scrollinginputreg() inputdisplayreg() end)
	emu.registerafter(function() kofhitboxesregafter() scrollinginputregafter() end)
	
elseif rom == "jojobanr1" then -- needs more testing + checking roms
	print("Found rom "..rom.." to be a jojo game")
	iconfile = "icons-jojos-32.png" -- scrolling inputs
	dofile("spectating\\hitboxes\\hftf-hitboxes.lua")
	dofile("spectating\\input-display.lua")
	dofile("spectating\\scrolling-input-display.lua")

	emu.registerstart(function() inputdisplaystart() end)
	gui.register(function() hftfhitboxesreg() scrollinginputreg() inputdisplayreg() end)
	emu.registerafter(function() hftfhitboxesregafter() scrollinginputregafter() end)

else
	print("Couldn't find a set for rom "..rom)
	iconfile = "icons-neogeo-32.png" -- scrolling inputs
	dofile("spectating\\input-display.lua")
	dofile("spectating\\scrolling-input-display.lua")

	emu.registerstart(function() inputdisplaystart() end)
	gui.register(function() scrollinginputreg() inputdisplayreg() end)
	emu.registerafter(function() scrollinginputregafter() end)
	
end