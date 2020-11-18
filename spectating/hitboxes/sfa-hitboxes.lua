--[[
print("CPS-2 fighting game hitbox viewer")
print("February 20, 2012")
print("http://code.google.com/p/mame-rr/wiki/Hitboxes")
print("Lua hotkey 1: toggle blank screen")
print("Lua hotkey 2: toggle object axis")
print("Lua hotkey 3: toggle hitbox axis")
print("Lua hotkey 4: toggle pushboxes")
print("Lua hotkey 5: toggle throwable boxes")
--]]
local boxes = {
	      ["vulnerability"] = {color = 0x7777FF, fill = 0x40, outline = 0xFF},
	             ["attack"] = {color = 0xFF0000, fill = 0x40, outline = 0xFF},
	["proj. vulnerability"] = {color = 0x00FFFF, fill = 0x40, outline = 0xFF},
	       ["proj. attack"] = {color = 0xFF66FF, fill = 0x40, outline = 0xFF},
	               ["push"] = {color = 0x00FF00, fill = 0x20, outline = 0xFF},
	           ["tripwire"] = {color = 0xFF66FF, fill = 0x40, outline = 0xFF}, --sfa3
	             ["negate"] = {color = 0xFFFF00, fill = 0x40, outline = 0xFF}, --dstlk, nwarr
	              ["throw"] = {color = 0xFFFF00, fill = 0x40, outline = 0xFF},
	         ["axis throw"] = {color = 0xFFAA00, fill = 0x40, outline = 0xFF}, --sfa, sfa2, nwarr
	          ["throwable"] = {color = 0xF0F0F0, fill = 0x20, outline = 0xFF},
}

local globals = {
	axis_color           = 0xFFFFFFFF,
	blank_color          = 0xFFFFFFFF,
	axis_size            = 12,
	mini_axis_size       = 2,
	blank_screen         = false,
	draw_axis            = true,
	draw_mini_axis       = false,
	draw_pushboxes       = true,
	draw_throwable_boxes = false,
	no_alpha             = false, --fill = 0x00, outline = 0xFF for all box types
	ground_throw_height  = 0x50, --default for sfa & sfa2 if pushbox unavailable
}

--------------------------------------------------------------------------------
-- game-specific modules

local rb, rbs, rw, rws, rd = memory.readbyte, memory.readbytesigned, memory.readword, memory.readwordsigned, memory.readdword
local any_true, get_thrower, insert_throw, signed_register, define_box, get_x, get_y
local game, frame_buffer, throw_buffer

local profile = {
{	games = {"sfa"},
	number = {players = 3, projectiles = 8},
	address = {
		player      = 0xFF8400,
		projectile  = 0xFF9000,
		screen_left = 0xFF8290,
	},
	offset = {
		object_space = 0x80,
		flip_x       = 0x0B,
		hitbox_ptr   = {player = 0x50, projectile = 0x50},
	},
	friends = {0x0D},
	box = {
		radius_read = rb,
		offset_read = rbs,
		val_x = 0x0, val_y = 0x1, rad_x = 0x2, rad_y = 0x3,
	},
	box_list = {
		{anim_ptr = 0x20, addr_table_ptr = 0x08, p_addr_table_ptr = 0x4, id_ptr = 0x0C, id_shift = 0x2, type = "push"},
		{anim_ptr = 0x20, addr_table_ptr = 0x00, p_addr_table_ptr = 0x0, id_ptr = 0x08, id_shift = 0x2, type = "vulnerability"},
		{anim_ptr = 0x20, addr_table_ptr = 0x02, p_addr_table_ptr = 0x0, id_ptr = 0x09, id_shift = 0x2, type = "vulnerability"},
		{anim_ptr = 0x20, addr_table_ptr = 0x04, p_addr_table_ptr = 0x0, id_ptr = 0x0A, id_shift = 0x2, type = "vulnerability"},
		{anim_ptr = 0x20, addr_table_ptr = 0x08, p_addr_table_ptr = 0x4, id_ptr = 0x0C, id_shift = 0x2, type = "throwable"},
		{anim_ptr = 0x20, addr_table_ptr = 0x06, p_addr_table_ptr = 0x2, id_ptr = 0x0B, id_shift = 0x4, type = "attack"},
	},
	breakpoints = {
		{["sfa"] = 0x020F14, func = function() --ground throws
			insert_throw({
				val_x = signed_register("d0"),
				rad_x = signed_register("d1"),
				type = "throw",
			})
		end},
		{["sfa"] = 0x020FF2, func = function() --air throws
			insert_throw({
				val_x = signed_register("d0"),
				rad_x = signed_register("d1"),
				val_y = signed_register("d2"),
				rad_y = signed_register("d3"),
				type = "axis throw",
			})
		end},
	},
	clones = {
		["sfar3"] = -0xB4, ["sfar2"] = -0x64, ["sfar1"] = -0x18, ["sfad"] = 0, ["sfau"] = -0x64, 
		["sfza"] = -0x64, ["sfzbr1"] = 0, ["sfzb"] = 0x5B4, ["sfzhr1"] = -0x64, ["sfzh"] = -0x18, 
		["sfzjr2"] = -0xB4, ["sfzjr1"] = -0x64, ["sfzj"] = 0, 
	},
	process_throw = function(obj, box)
		box.val_y = box.val_y or obj.val_y or globals.ground_throw_height/2
		box.rad_y = box.rad_y or obj.rad_y or globals.ground_throw_height/2

		box.val_x  = obj.pos_x + box.val_x * obj.flip_x
		box.val_y  = obj.pos_y - box.val_y
		box.left   = box.val_x - box.rad_x
		box.right  = box.val_x + box.rad_x
		box.top    = box.val_y - box.rad_y
		box.bottom = box.val_y + box.rad_y

		return box
	end,
	active = function() return any_true({
		(rd(0xFF8004) == 0x40000 and rd(0xFF8008) == 0x40000),
		(rw(0xFF8008) == 0x2 and rw(0xFF800A) > 0),
	}) end,
	invulnerable = function(obj, box) return any_true({
		rb(obj.base + 0x13B) > 0,
	}) end,
	unthrowable = function(obj, box) return any_true({
		rb(obj.base + 0x241) > 0,
		rw(obj.base + 0x004) ~= 0x200,
		rb(obj.base + 0x02F) > 0,
		bit.band(rd(rd(obj.base + 0x020) + 0x8), 0xFFFFFF00) == 0,
	}) end,
},
{	games = {"sfa2", "sfz2al"},
	number = {players = 3, projectiles = 26},
	address = {
		player      = 0xFF8400,
		projectile  = 0xFF9400,
		screen_left = 0xFF8290,
	},
	offset = {
		object_space = 0x80,
		flip_x       = 0x0B,
		hitbox_ptr   = {player = nil, projectile = 0x60},
	},
	friends = {0x17},
	box_list = {
		{anim_ptr = 0x1C, addr_table_ptr = 0x120, p_addr_table_ptr = 0x4, id_ptr = 0x0C, id_shift = 0x3, type = "push"},
		{anim_ptr = 0x1C, addr_table_ptr = 0x110, p_addr_table_ptr = 0x0, id_ptr = 0x08, id_shift = 0x3, type = "vulnerability"},
		{anim_ptr = 0x1C, addr_table_ptr = 0x114, p_addr_table_ptr = 0x0, id_ptr = 0x09, id_shift = 0x3, type = "vulnerability"},
		{anim_ptr = 0x1C, addr_table_ptr = 0x118, p_addr_table_ptr = 0x0, id_ptr = 0x0A, id_shift = 0x3, type = "vulnerability"},
		{anim_ptr = 0x1C, addr_table_ptr = 0x120, p_addr_table_ptr = 0x4, id_ptr = 0x0C, id_shift = 0x3, type = "throwable"},
		{anim_ptr = 0x1C, addr_table_ptr = 0x11C, p_addr_table_ptr = 0x2, id_ptr = 0x0B, id_shift = 0x5, type = "attack"},
	},
	breakpoints = {
		{["sfa2"] = 0x025516, ["sfz2al"] = 0x025C8A, func = function() --ground throws
			insert_throw({
				val_x = signed_register("d0"),
				rad_x = signed_register("d1"),
				type = "throw",
			})
		end},
		{["sfa2"] = 0x02564A, ["sfz2al"] = 0x025DD6, func = function() --tripwire
			insert_throw({
				val_x = signed_register("d0"),
				rad_x = signed_register("d1"),
				type = "throw",
			})
		end},
		{["sfa2"] = 0x025786, ["sfz2al"] = 0x025F12, func = function() --air throws
			insert_throw({
				val_x = signed_register("d0"),
				rad_x = signed_register("d1"),
				val_y = signed_register("d2"),
				rad_y = signed_register("d3"),
				type = "axis throw",
			})
		end},
	},
	clones = {
		["sfa2u"] = 0xBD2, ["sfa2ur1"] = 0xBC2, ["sfz2ad"] = 0xC0A, ["sfz2a"] = 0xC0A, 
		["sfz2br1"] = 0x48, ["sfz2b"] = 0x42, ["sfz2h"] = 0x48, ["sfz2jd"] = 0xC0A, ["sfz2j"] = 0xC0A, ["sfz2n"] = 0, 
		["sfz2al"] = 0, ["sfz2ald"] = 0, ["sfz2alb"] = 0, ["sfz2alh"] = 0, ["sfz2alj"] = -0x310, 
	},
	process_throw = function(obj, box)
		box.val_y = box.val_y or obj.val_y or globals.ground_throw_height/2
		box.rad_y = box.rad_y or obj.rad_y or globals.ground_throw_height/2

		box.val_x  = obj.pos_x + box.val_x * obj.flip_x
		box.val_y  = obj.pos_y - box.val_y
		box.left   = box.val_x - box.rad_x
		box.right  = box.val_x + box.rad_x
		box.top    = box.val_y - box.rad_y
		box.bottom = box.val_y + box.rad_y

		return box
	end,
	active = function() return any_true({
		(rd(0xFF8004) == 0x40000 and
		(rd(0xFF8008) == 0x40000 or rd(0xFF8008) == 0xA0000)),
		rw(0xFF8008) == 0x2 and rw(0xFF800A) > 0,
	}) end,
	invulnerable = function(obj, box) return any_true({
		rb(obj.base + 0x25B) > 0,
		rb(obj.base + 0x273) > 0,
		rb(obj.base + 0x13B) > 0,
	}) end,
	unthrowable = function(obj, box)
		if any_true({
				rb(0xFF810E) > 0,
				rb(obj.base + 0x273) > 0,
				bit.band(rd(rd(obj.base + 0x01C) + 0x8), 0xFFFFFF00) == 0,
			}) then
			return true
		elseif rb(0xFF0000 + rw(obj.base + 0x38) + 0x142) > 0 then --opponent in CC
			return any_true({
				rb(rd(obj.base + 0x01C) + 0xD) > 0,
			})
		else --not in CC
			return any_true({
				rb(obj.base + 0x241) > 0,
				rw(obj.base + 0x004) ~= 0x200,
				rb(obj.base + 0x031) > 0,
			})
		end
	end,
},
{	games = {"sfa3"},
	number = {players = 4, projectiles = 24},
	address = {
		player      = 0xFF8400,
		projectile  = 0xFF9400,
		screen_left = 0xFF8290,
	},
	offset = {
		object_space = 0x100,
		flip_x       = 0x0B,
		hitbox_ptr   = nil,
	},
	friends = {0x17, 0x22},
	box_list = {
		{anim_ptr =  nil, addr_table_ptr = 0x9C, id_ptr =  0xCB, id_shift = 0x3, type = "push"},
		{anim_ptr =  nil, addr_table_ptr = 0x90, id_ptr =  0xC8, id_shift = 0x3, type = "vulnerability"},
		{anim_ptr =  nil, addr_table_ptr = 0x94, id_ptr =  0xC9, id_shift = 0x3, type = "vulnerability"},
		{anim_ptr =  nil, addr_table_ptr = 0x98, id_ptr =  0xCA, id_shift = 0x3, type = "vulnerability"},
		{anim_ptr =  nil, addr_table_ptr = 0x9C, id_ptr =  0xCB, id_shift = 0x3, type = "throwable"}, --identical to pushbox
		{anim_ptr = 0x1C, addr_table_ptr = 0xA0, id_ptr =   0x9, id_shift = 0x5, type = "attack"},
	},
	throw_box_list = {
		{anim_ptr =  nil, addr_table_ptr = 0xA0, id_ptr = 0x32F, id_shift = 0x5, type = "throw", clear = true},
		{anim_ptr =  nil, addr_table_ptr = 0xA0, id_ptr =  0x82, id_shift = 0x5, type = "tripwire", clear = true},
	},
	watchpoints = {
		{offset = 0x32F, size = 1, func = function() insert_throw({
			id = bit.band(memory.getregister("m68000.d0"), 0xFF),
			anim_ptr = nil, addr_table_ptr = 0xA0, type = "throw", id_shift = 0x5,
		}) end},
		{offset = 0x1E4, size = 2, func = function() insert_throw({
			pos_x = bit.band(memory.getregister("m68000.d0"), 0xFFFF),
			anim_ptr = nil, addr_table_ptr = 0xA0, type = "tripwire", id_ptr = 0x82, id_shift = 0x5,
		}) end},
	},
	process_throw = function(obj, box)
		box.pos_x = box.pos_x and rws(obj.base + 0x1E4) + box.pos_x
		return define_box[game.box_type](obj, box)
	end,
	active = function() return any_true({
		(rd(0xFF8004) == 0x40000 and rd(0xFF8008) == 0x60000),
		(rw(0xFF8008) == 0x2 and rw(0xFF800A) > 0),
	}) end,
	invulnerable = function(obj, box) return any_true({
		rb(obj.base + 0x067) > 0,
		rb(obj.base + 0x25D) > 0,
		rb(obj.base + 0x0D6) > 0,
		rb(obj.base + 0x2CE) > 0,
	}) end,
	unpushable = function(obj, box) return any_true({
		rb(obj.base + 0x67) > 0,
	}) end,
	unthrowable = function(obj, box)
		if any_true({
				rb(obj.base + 0x25D) > 0,
				rb(obj.base + 0x23F) > 0,
				rb(obj.base + 0x2CE) > 0,
				bit.band(rd(obj.base + 0x0C8), 0xFFFFFF00) == 0,
				rb(obj.base + 0x067) > 0,
			}) then
			return true
		end
		local opp = { base = 0xFF0000 + rw(obj.base + 0x38)}
		opp.air = rb(opp.base + 0x31) > 0
		opp.VC  = rb(opp.base + 0xB9) > 0
		local status = rw(obj.base + 0x4)
		if opp.VC and rb(obj.base + 0x24E) == 0 then --VC: 02E37C
			return
		elseif not opp.air then --ground: 02E3FE
			return any_true({ --02E422
				status ~= 0x204 and status ~= 0x200 and rb(obj.base + 0x24E) == 0 and 
				(status ~= 0x202 or rb(obj.base + 0x54) ~= 0xC),
				rb(obj.base + 0x031) > 0,
			})
		else --air: 02E636
			return any_true({ --02E66E
				rb(obj.base + 0x031) == 0,
				rb(obj.base + 0x0D6) > 0,
				status ~= 0x204 and status ~= 0x200 and status ~= 0x202,
			})
		end
	end,
},
}

--------------------------------------------------------------------------------
-- post-process the modules

for game in ipairs(profile) do
	local g = profile[game]
	g.box_type = g.offset.id_ptr and "id ptr" or "hitbox ptr"
	g.ground_level = g.ground_level or -0x0F
	g.offset.player_space = g.offset.player_space or 0x400
	g.offset.pos_x = g.offset.pos_x or 0x10
	g.offset.pos_y = g.offset.pos_y or g.offset.pos_x + 0x4
	g.offset.hitbox_ptr = g.offset.hitbox_ptr or {}
	g.box = g.box or {}
	g.box.radius_read = g.box.radius_read or rw
	g.box.offset_read = g.box.radius_read == rw and rws or rbs
	g.box.val_x    = g.box.val_x or 0x0
	g.box.val_y    = g.box.val_y or 0x2
	g.box.rad_x    = g.box.rad_x or 0x4
	g.box.rad_y    = g.box.rad_y or 0x6
	g.box.radscale = g.box.radscale or 1
	g.no_hit       = g.no_hit       or function() end
	g.invulnerable = g.invulnerable or function() end
	g.unpushable   = g.unpushable   or function() end
	g.unthrowable  = g.unthrowable  or function() end
	g.projectile_active = g.projectile_active or function(obj)
		if rw(obj.base) > 0x0100 and rb(obj.base + 0x04) == 0x02 then
			return true
		end
	end
	g.special_projectiles = g.special_projectiles or {number = 0}
	g.breakables = g.breakables or {number = 0}
end

for _, box in pairs(boxes) do
	box.fill    = bit.lshift(box.color, 8) + (globals.no_alpha and 0x00 or box.fill)
	box.outline = bit.lshift(box.color, 8) + (globals.no_alpha and 0xFF or box.outline)
end

local projectile_type = {
	       ["attack"] = "proj. attack",
	["vulnerability"] = "proj. vulnerability",
}

local DRAW_DELAY = 1
if fba then
	DRAW_DELAY = DRAW_DELAY + 1
end
emu.registerfuncs = fba and memory.registerexec --0.0.7+


--------------------------------------------------------------------------------
-- functions referenced in the modules

any_true = function(condition)
	for n = 1, #condition do
		if condition[n] == true then return true end
	end
end


get_thrower = function(frame)
	local base = bit.band(0xFFFFFF, memory.getregister("m68000.a6"))
	for _, obj in ipairs(frame) do
		if base == obj.base then
			return obj
		end
	end
end


insert_throw = function(box)
	local f = frame_buffer[DRAW_DELAY]
	local obj = get_thrower(f)
	if not f.match_active or not obj then
		return
	end
	table.insert(throw_buffer[obj.base], game.process_throw(obj, box))
end


signed_register = function(register, bytes)
	local bits = bit.lshift(4, bytes or 2)
	local val = bit.band(memory.getregister("m68000." .. register), bit.lshift(1, bits) - 1)
	if bit.arshift(val, bits-1) > 0 then
		val = val - bit.lshift(1, bits)
	end
	return val
end


get_x = function(x)
	return x - frame_buffer[DRAW_DELAY+1].screen_left
end


get_y = function(y)
	return emu.screenheight() - (y + game.ground_level) + frame_buffer[DRAW_DELAY+1].screen_top
end


--------------------------------------------------------------------------------
-- prepare the hitboxes

local display = true

togglehitboxdisplay = function() display = not display globals.draw_axis = not globals.draw_axis end

input.registerhotkey(3, togglehitboxdisplay) -- Has to be here or script crashes

local process_box_type = {
	["vulnerability"] = function(obj, box)
		if game.invulnerable(obj, box) or obj.friends then
			return false
		end
	end,

	["attack"] = function(obj, box)
		if game.no_hit(obj, box) then
			return false
		end
	end,

	["push"] = function(obj, box)
		if game.unpushable(obj, box) or obj.friends then
			return false
		end
	end,

	["negate"] = function(obj, box)
	end,

	["tripwire"] = function(obj, box)
		box.id = bit.rshift(box.id, 1) + 0x3E
		box.pos_x = box.pos_x or rws(obj.base + 0x1E4)
		if box.pos_x == 0 or rb(obj.base + 0x102) ~= 0x0E then
			return false
		elseif box.clear and not (rb(obj.base + 0x07) == 0x04 and rb(obj.base + 0xAA) == 0x0C) then
			memory.writeword(obj.base + 0x1E4, 0) --sfa3 w/o registerfuncs (bad)
		end
		box.pos_x = obj.pos_x + box.pos_x
	end,

	["throw"] = function(obj, box)
		if box.clear then
			memory.writebyte(obj.base + box.id_ptr, 0) --sfa3 w/o registerfuncs (bad)
		end
	end,

	["axis throw"] = function(obj, box)
	end,

	["throwable"] = function(obj, box)
		if game.unthrowable(obj, box) or obj.projectile then
			return false
		end
	end,
}


define_box = {
	["hitbox ptr"] = function(obj, box_entry)
		local box = copytable(box_entry)

		if obj.projectile and box.no_projectile then
			return nil
		end

		if not box.id then
			box.id_base = (box.anim_ptr and rd(obj.base + box.anim_ptr)) or obj.base
			box.id = rb(box.id_base + box.id_ptr)
		end

		if process_box_type[box.type](obj, box) == false or box.id == 0 then
			return nil
		end

		local addr_table
		if not obj.hitbox_ptr then
			addr_table = rd(obj.base + box.addr_table_ptr)
		else
			local table_offset = obj.projectile and box.p_addr_table_ptr or box.addr_table_ptr
			addr_table = obj.hitbox_ptr + rws(obj.hitbox_ptr + table_offset)
		end
		box.address = addr_table + bit.lshift(box.id, box.id_shift)

		box.rad_x = game.box.radius_read(box.address + game.box.rad_x)/game.box.radscale
		box.rad_y = game.box.radius_read(box.address + game.box.rad_y)/game.box.radscale
		box.val_x = game.box.offset_read(box.address + game.box.val_x)
		box.val_y = game.box.offset_read(box.address + game.box.val_y)
		if box.type == "push" then
			obj.val_y, obj.rad_y = box.val_y, box.rad_y
		end

		box.val_x  = (box.pos_x or obj.pos_x) + box.val_x * obj.flip_x
		box.val_y  = (box.pos_y or obj.pos_y) - box.val_y
		box.left   = box.val_x - box.rad_x
		box.right  = box.val_x + box.rad_x
		box.top    = box.val_y - box.rad_y
		box.bottom = box.val_y + box.rad_y

		box.type = obj.projectile and not obj.friends and projectile_type[box.type] or box.type

		return box
	end,

	["id ptr"] = function(obj, box_entry) --ringdest only
		local box = copytable(box_entry)

		if process_box_type[box.type](obj, box) == false then
			return nil
		end

		if box.addr_table_base then
			box.address = box.addr_table_base + bit.lshift(obj.id_offset, 2)
		else
			box.address = rd(obj.base + box.addr_table_ptr)
		end

		box.rad_x = game.box.radius_read(box.address + game.box.rad_x)/game.box.radscale
		box.rad_y = game.box.radius_read(box.address + game.box.rad_y)/game.box.radscale
		if box.rad_x == 0 or box.rad_y == 0 then
			return nil
		end
		box.val_x = game.box.offset_read(box.address + game.box.val_x)
		box.val_y = game.box.offset_read(box.address + game.box.val_y)

		box.val_x  = obj.pos_x + (box.rad_x + box.val_x) * obj.flip_x
		box.val_y  = obj.pos_y - (box.rad_y + box.val_y)
		box.left   = box.val_x - box.rad_x
		box.right  = box.val_x + box.rad_x
		box.top    = box.val_y - box.rad_y
		box.bottom = box.val_y + box.rad_y

		box.type = obj.projectile and projectile_type[box.type] or box.type

		return box
	end,

	["range given"] = function(obj, box_entry) --dstlk/nwarr throwable; nwarr ranged
		local box = copytable(box_entry)

		box.base_x  = rw(obj.base + box.base_x)
		box.range_x = rb(obj.base + box.range_x)
		if process_box_type[box.type](obj, box) == false or box.base_x == 0 or box.range_x == 0 then
			return nil
		end
		box.right = get_x(box.base_x) - box.range_x
		box.left  = get_x(box.base_x) + box.range_x
		if box.type == "axis throw" then --nwarr ranged
			box.bottom = get_y(game.ground_level)
			box.top    = get_y(rw(obj.base + box.range_y))
		else
			box.top    = obj.pos_y - rb(obj.base + box.range_y)
			if rb(obj.base + box.air_state) > 0 then
				box.bottom = box.top + 0xC --air throwable; verify range @ 033BE0 [dstlk] & 029F50 [nwarr]
			else
				box.bottom = obj.pos_y --ground throwable
			end
		end
		box.val_x = (box.left + box.right)/2
		box.val_y = (box.bottom + box.top)/2

		return box
	end,

	["dimensions"] = function(obj, box_entry) --cybots throwable
		local box = copytable(box_entry)

		if process_box_type[box.type](obj, box) == false then
			return nil
		end
		box.hval = rws(obj.base + box.dimensions + 0x0)
		box.vval = rws(obj.base + box.dimensions + 0x2)
		box.hrad =  rw(obj.base + box.dimensions + 0x4)
		box.vrad =  rw(obj.base + box.dimensions + 0x6)

		box.hval   = obj.pos_x + box.hval * obj.flip_x
		box.vval   = obj.pos_y - box.vval
		box.left   = box.hval - box.hrad
		box.right  = box.hval + box.hrad
		box.top    = box.vval - box.vrad
		box.bottom = box.vval + box.vrad

		return box
	end,
}


local get_ptr = {
	["hitbox ptr"] = function(obj)
		obj.hitbox_ptr = obj.projectile and game.offset.hitbox_ptr.projectile or game.offset.hitbox_ptr.player
		obj.hitbox_ptr = obj.hitbox_ptr and rd(obj.base + obj.hitbox_ptr) or nil
	end,

	["id ptr"] = function(obj) --ringdest only
		obj.id_offset = rw(obj.base + game.offset.id_ptr)
	end,
}


local update_object = function(obj)
	obj.flip_x = rb(obj.base + game.offset.flip_x) > 0 and -1 or 1
	obj.pos_x  = get_x(rws(obj.base + game.offset.pos_x))
	obj.pos_y  = get_y(rws(obj.base + game.offset.pos_y))
	get_ptr[game.box_type](obj)
	for _, box_entry in ipairs(game.box_list) do
		table.insert(obj, define_box[box_entry.method or game.box_type](obj, box_entry))
	end
	return obj
end


local friends_status = function(id)
	for _, friend in ipairs(game.friends or {}) do
		if id == friend then
			return true
		end
	end
end


local read_projectiles = function(f)
	for i = 1, game.number.projectiles do
		local obj = {base = game.address.projectile + (i-1) * game.offset.object_space}
		if game.projectile_active(obj) then
			obj.projectile = true
			obj.friends = friends_status(rb(obj.base + 0x02))
			table.insert(f, update_object(obj))
		end
	end

	for i = 1, game.special_projectiles.number do --for nwarr only
		local obj = {base = game.special_projectiles.start + (i-1) * game.special_projectiles.space}
		local id = rb(obj.base + 0x02)
		for _, valid in ipairs(game.special_projectiles.no_box) do
			if id == valid then
				obj.pos_x = get_x(rws(obj.base + game.offset.pos_x))
				obj.pos_y = get_y(rws(obj.base + game.offset.pos_y))
				table.insert(f, obj)
				break
			end
		end
		for _, valid in ipairs(game.special_projectiles.whitelist) do
			if id == valid then
				obj.projectile, obj.hit_only, obj.friends = true, true, friends_status(id)
				table.insert(f, update_object(obj))
				break
			end
		end
	end
--[[
	for i = 1, game.breakables.number do --for dstlk, nwarr
		local obj = {base = game.breakables.start + (i-1) * game.breakables.space}
		local status = rb(obj.base + 0x04)
		if status == 0x02 then
			obj.projectile = true
			obj.x_adjust = 0x1C*((f.screen_left-0x100)/0xC0-1)
			table.insert(f, update_object(obj))
		end
	end
]]
end


local update_hitboxes = function()
	if not game then
		return
	end
	local screen_left_ptr = game.address.screen_left or game.get_cam_ptr()
	local screen_top_ptr  = game.address.screen_top or screen_left_ptr + 0x4

	for f = 1, DRAW_DELAY do
		frame_buffer[f] = copytable(frame_buffer[f+1])
	end

	frame_buffer[DRAW_DELAY+1] = {
		match_active = game.active(),
		screen_left = rws(screen_left_ptr),
		screen_top  = rws(screen_top_ptr),
	}
	local f = frame_buffer[DRAW_DELAY+1]
	if not f.match_active then
		return
	end

	for p = 1, game.number.players do
		local player = {base = game.address.player + (p-1) * game.offset.player_space}
		if rb(player.base) > 0 then
			table.insert(f, update_object(player))
			local tb = throw_buffer[player.base]
			table.insert(player, tb[1])
			for frame = 1, #tb-1 do
				tb[frame] = tb[frame+1]
			end
			table.remove(tb)
		end
	end
	read_projectiles(f)

	f = frame_buffer[DRAW_DELAY]
	for _, obj in ipairs(f or {}) do
		if obj.projectile then
			break
		end
		for _, box_entry in ipairs(game.throw_box_list or {}) do
			if not (emu.registerfuncs and box_entry.clear) then
				table.insert(obj, define_box[box_entry.method or game.box_type](obj, box_entry))
			end
		end
	end

	f.max_boxes = 0
	for _, obj in ipairs(f or {}) do
		f.max_boxes = math.max(f.max_boxes, #obj)
	end
	f.max_boxes = f.max_boxes+1
end


function sfahitboxesregafter()
	update_hitboxes()
end


--------------------------------------------------------------------------------
-- draw the hitboxes

local draw_hitbox = function(hb)
	if not hb or any_true({
		not globals.draw_pushboxes and hb.type == "push",
		not globals.draw_throwable_boxes and hb.type == "throwable",
		not display,
	}) then return
	end

	if globals.draw_mini_axis then
		gui.drawline(hb.val_x, hb.val_y-globals.mini_axis_size, hb.val_x, hb.val_y+globals.mini_axis_size, boxes[hb.type].outline)
		gui.drawline(hb.val_x-globals.mini_axis_size, hb.val_y, hb.val_x+globals.mini_axis_size, hb.val_y, boxes[hb.type].outline)
	end

	gui.box(hb.left, hb.top, hb.right, hb.bottom, boxes[hb.type].fill, boxes[hb.type].outline)
end


local draw_axis = function(obj)
	gui.drawline(obj.pos_x, obj.pos_y-globals.axis_size, obj.pos_x, obj.pos_y+globals.axis_size, globals.axis_color)
	gui.drawline(obj.pos_x-globals.axis_size, obj.pos_y, obj.pos_x+globals.axis_size, obj.pos_y, globals.axis_color)
	--gui.text(obj.pos_x, obj.pos_y, string.format("%06X", obj.base)) --debug
end


local render_hitboxes = function()
	gui.clearuncommitted()
	local f = frame_buffer[1]
	if not f.match_active then
		return
	end

	if globals.blank_screen then
		gui.box(0, 0, emu.screenwidth(), emu.screenheight(), globals.blank_color)
	end

	for entry = 1, f.max_boxes or 0 do
		for _, obj in ipairs(f) do
			draw_hitbox(obj[entry])
		end
	end

	if globals.draw_axis then
		for _, obj in ipairs(f) do
			draw_axis(obj)
		end
	end
end


function sfahitboxesreg()
	render_hitboxes()
end


--------------------------------------------------------------------------------
-- hotkey functions



--[[
input.registerhotkey(1, function()
	globals.blank_screen = not globals.blank_screen
	render_hitboxes()
	emu.message((globals.blank_screen and "activated" or "deactivated") .. " blank screen mode")
end)


input.registerhotkey(2, function()
	globals.draw_axis = not globals.draw_axis
	render_hitboxes()
	emu.message((globals.draw_axis and "showing" or "hiding") .. " object axis")
end)


input.registerhotkey(3, function()
	globals.draw_mini_axis = not globals.draw_mini_axis
	render_hitboxes()
	emu.message((globals.draw_mini_axis and "showing" or "hiding") .. " hitbox axis")
end)


input.registerhotkey(4, function()
	globals.draw_pushboxes = not globals.draw_pushboxes
	render_hitboxes()
	emu.message((globals.draw_pushboxes and "showing" or "hiding") .. " pushboxes")
end)


input.registerhotkey(5, function()
	globals.draw_throwable_boxes = not globals.draw_throwable_boxes
	render_hitboxes()
	emu.message((globals.draw_throwable_boxes and "showing" or "hiding") .. " throwable boxes")
end)
]]--

--------------------------------------------------------------------------------
-- initialize on game startup

local initialize_bps = function()
	for _, pc in ipairs(globals.breakpoints or {}) do
		memory.registerexec(pc, nil)
	end
	for _, addr in ipairs(globals.watchpoints or {}) do
		memory.registerwrite(addr, nil)
	end
	globals.breakpoints, globals.watchpoints = {}, {}
end


local initialize_fb = function()
	frame_buffer = {}
	for f = 1, DRAW_DELAY + 1 do
		frame_buffer[f] = {}
	end
end


local initialize_throw_buffer = function()
	throw_buffer = {}
	for p = 1, game.number.players do
		throw_buffer[game.address.player + (p-1) * game.offset.player_space] = {}
	end
end


local whatgame = function()
	print()
	game = nil
	initialize_fb()
	initialize_bps()
	for _, module in ipairs(profile) do
		for _, shortname in ipairs(module.games) do
			if emu.romname() == shortname or emu.parentname() == shortname then
				game = module
				initialize_throw_buffer()
				if not emu.registerfuncs then
					if game.breakpoints then
						print("(FBA-rr 0.0.7+ can show throwboxes for this game.)")
					end
					return
				end
				for _, bp in ipairs(game.breakpoints or {}) do
					local pc = bp[emu.romname()] or bp[shortname] + game.clones[emu.romname()]
					memory.registerexec(pc, bp.func)
					table.insert(globals.breakpoints, pc)
				end
				for _, wp in ipairs(game.watchpoints or {}) do
					for p = 1, game.number.players do
						local addr = game.address.player + (p-1) * game.offset.player_space + wp.offset
						memory.registerwrite(addr, wp.size, wp.func)
						table.insert(globals.watchpoints, addr)
					end
				end
				return
			end
		end
	end
	print("unsupported game: " .. emu.gamename())
end


savestate.registerload(function()
	initialize_fb()
end)


function sfahitboxesregstart()
	whatgame()
end