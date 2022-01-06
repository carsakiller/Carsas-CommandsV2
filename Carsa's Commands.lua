-- CARSA'S COMMANDS
---@version 2.0.0

---@alias peerID number
---@alias steamID string
---@alias vehicleID number
---@alias matrix table<number, number>


-- Used to define a owner's steamID
-- defining a steamID here will disable
-- the auto assigning of an owner on first join
local OWNER_STEAM_ID = "0"


local ScriptVersion = "2.0.0"
local SaveDataVersion = "2.0.0"

--[ LIBRARIES ]--
--#region

--[ lua implementation of fzy library ]--
--#region
-- @author Seth Warn
-- @source https://github.com/swarn/fzy-lua
-- @license
-- The MIT License (MIT)

-- Copyright (c) 2020 Seth Warn

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

local fzy = {
	SCORE_GAP_LEADING = -0.005,
	SCORE_GAP_TRAILING = -0.005,
	SCORE_GAP_INNER = -0.01,
	SCORE_MATCH_CONSECUTIVE = 1.0,
	SCORE_MATCH_SLASH = 0.9,
	SCORE_MATCH_WORD = 0.8,
	SCORE_MATCH_CAPITAL = 0.7,
	SCORE_MATCH_DOT = 0.6,
	SCORE_MAX = math.huge,
	SCORE_MIN = -math.huge,
	MATCH_MAX_LENGTH = 1024
}

function fzy.has_match(needle, haystack, case_sensitive)
	if not case_sensitive then
		needle = string.lower(needle)
		haystack = string.lower(haystack)
	end

	local j = 1
	for i = 1, string.len(needle) do
		j = string.find(haystack, needle:sub(i, i), j, true)
		if not j then
			return false
		else
			j = j + 1
		end
	end

	return true
end

function fzy.is_lower(c)
	return c:match("%l")
end

function fzy.is_upper(c)
	return c:match("%u")
end

function fzy.precompute_bonus(haystack)
	local match_bonus = {}

	local last_char = "/"
	for i = 1, string.len(haystack) do
		local this_char = haystack:sub(i, i)
		if last_char == "/" or last_char == "\\" then
			match_bonus[i] = fzy.SCORE_MATCH_SLASH
		elseif last_char == "-" or last_char == "_" or last_char == " " then
			match_bonus[i] = fzy.SCORE_MATCH_WORD
		elseif last_char == "." then
			match_bonus[i] = fzy.SCORE_MATCH_CAPITAL
		elseif fzy.is_lower(last_char) and fzy.is_upper(this_char) then
			match_bonus[i] = fzy.SCORE_MATCH_CAPITAL
		else
			match_bonus[i] = 0
		end

		last_char = this_char
	end

	return match_bonus
end

function fzy.compute(needle, haystack, D, M, case_sensitive)
	-- Note that the match bonuses must be computed before the arguments are
	-- converted to lowercase, since there are bonuses for camelCase.
	local match_bonus = fzy.precompute_bonus(haystack)
	local n = string.len(needle)
	local m = string.len(haystack)

	if not case_sensitive then
		needle = string.lower(needle)
		haystack = string.lower(haystack)
	end

	-- Because lua only grants access to chars through substring extraction,
	-- get all the characters from the haystack once now, to reuse below.
	local haystack_chars = {}
	for i = 1, m do
		haystack_chars[i] = haystack:sub(i, i)
	end

	for i = 1, n do
		D[i] = {}
		M[i] = {}

		local prev_score = fzy.SCORE_MIN
		local gap_score = i == n and fzy.SCORE_GAP_TRAILING or fzy.SCORE_GAP_INNER
		local needle_char = needle:sub(i, i)

		for j = 1, m do
			if needle_char == haystack_chars[j] then
				local score = fzy.SCORE_MIN
				if i == 1 then
					score = ((j - 1) * fzy.SCORE_GAP_LEADING) + match_bonus[j]
				elseif j > 1 then
					local a = M[i - 1][j - 1] + match_bonus[j]
					local b = D[i - 1][j - 1] + fzy.SCORE_MATCH_CONSECUTIVE
					score = math.max(a, b)
				end
				D[i][j] = score
				prev_score = math.max(score, prev_score + gap_score)
				M[i][j] = prev_score
			else
				D[i][j] = fzy.SCORE_MIN
				prev_score = prev_score + gap_score
				M[i][j] = prev_score
			end
		end
	end
end

function fzy.score(needle, haystack, case_sensitive)
	local n = string.len(needle)
	local m = string.len(haystack)

	if n == 0 or m == 0 or m > fzy.MATCH_MAX_LENGTH or n > m then
		return fzy.SCORE_MIN
	elseif needle == haystack then
		return fzy.SCORE_MAX
	else
		local D = {}
		local M = {}
		fzy.compute(needle, haystack, D, M, case_sensitive)
		local result = M[n][m]
		if n == m then
			return result + 1
		end
		return result
	end
end
--#endregion

--[ json.lua library ]--
--#region
---@author tylerneylon
---@source https://gist.github.com/tylerneylon/59f4bcf316be525b30ab
json = {}


-- Internal functions.

function kind_of(obj)
	if type(obj) ~= 'table' then return type(obj) end
	local i = 1
	for _ in pairs(obj) do
		if obj[i] ~= nil then i = i + 1 else return 'table' end
	end
	if i == 1 then return 'table' else return 'array' end
end

function escape_str(s)
	local in_char  = {'\\', '"', '/', '\b', '\f', '\n', '\r', '\t'}
	local out_char = {'\\', '"', '/',  'b',  'f',  'n',  'r',  't'}
	for i, c in ipairs(in_char) do
		s = s:gsub(c, '\\' .. out_char[i])
	end
	return s
end

-- Returns pos, did_find; there are two cases:
-- 1. Delimiter found: pos = pos after leading space + delim; did_find = true.
-- 2. Delimiter not found: pos = pos after leading space;     did_find = false.
-- This throws an error if err_if_missing is true and the delim is not found.
function skip_delim(str, pos, delim, err_if_missing)
	pos = pos + #str:match('^%s*', pos)
	if str:sub(pos, pos) ~= delim then
		if err_if_missing then
			webSyncError('Expected ' .. delim .. ' near position ' .. pos)
		end
		return pos, false
	end
	return pos + 1, true
end

-- Expects the given pos to be the first character after the opening quote.
-- Returns val, pos; the returned pos is after the closing quote character.
function parse_str_val(str, pos, val)
	val = val or ''
	local early_end_error = 'End of input found while parsing string.'
	if pos > #str then webSyncError(early_end_error) end
	local c = str:sub(pos, pos)
	if c == '"'  then return val, pos + 1 end
	if c ~= '\\' then return parse_str_val(str, pos + 1, val .. c) end
	-- We must have a \ character.
	local esc_map = {b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}
	local nextc = str:sub(pos + 1, pos + 1)
	if not nextc then webSyncError(early_end_error) end
	return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
end

-- Returns val, pos; the returned pos is after the number's final character.
function parse_num_val(str, pos)
	local num_str = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
	local val = tonumber(num_str)
	if not val then webSyncError('Error parsing number at position ' .. pos .. '.') end
	return val, pos + #num_str
end

-- Public values and functions.

function json.stringify(obj, as_key)
	local s = {}  -- We'll build the string as an array of strings to be concatenated.
	local kind = kind_of(obj)  -- This is 'array' if it's an array or type(obj) otherwise.
	if kind == 'array' then
		if as_key then webSyncError('Can\'t encode array as key.') end
		s[#s + 1] = '['
		for i, val in ipairs(obj) do
			if i > 1 then s[#s + 1] = ', ' end
			s[#s + 1] = json.stringify(val)
		end
		s[#s + 1] = ']'
	elseif kind == 'table' then
		if as_key then webSyncError('Can\'t encode table as key.') end
		s[#s + 1] = '{'
		for k, v in pairs(obj) do
			if #s > 1 then s[#s + 1] = ', ' end
			s[#s + 1] = json.stringify(k, true)
			s[#s + 1] = ':'
			s[#s + 1] = json.stringify(v)
		end
		s[#s + 1] = '}'
	elseif kind == 'string' then
		return '"' .. escape_str(obj) .. '"'
	elseif kind == 'number' then
		if as_key then return '"' .. tostring(obj) .. '"' end
		return tostring(obj)
	elseif kind == 'boolean' then
		return tostring(obj)
	elseif kind == 'nil' then
		return 'null'
	else
		webSyncError('Unjsonifiable type: ' .. kind .. '.')
	end
	return table.concat(s)
end

json.null = {}  -- This is a one-off table to represent the null value.

function json.parse(str, pos, end_delim)
	pos = pos or 1
	if pos > #str then webSyncError('Reached unexpected end of input.') end
	local pos = pos + #str:match('^%s*', pos)  -- Skip whitespace.
	local first = str:sub(pos, pos)
	if first == '{' then  -- Parse an object.
		local obj, key, delim_found = {}, true, true
		pos = pos + 1
		while true do
			key, pos = json.parse(str, pos, '}')
			if key == nil then return obj, pos end
			if not delim_found then webSyncError('Comma missing between object items.') end
			pos = skip_delim(str, pos, ':', true)  -- true -> error if missing.
			obj[key], pos = json.parse(str, pos)
			pos, delim_found = skip_delim(str, pos, ',')
		end
	elseif first == '[' then  -- Parse an array.
		local arr, val, delim_found = {}, true, true
		pos = pos + 1
		while true do
			val, pos = json.parse(str, pos, ']')
			if val == nil then return arr, pos end
			if not delim_found then webSyncError('Comma missing between array items.') end
			arr[#arr + 1] = val
			pos, delim_found = skip_delim(str, pos, ',')
		end
	elseif first == '"' then  -- Parse a string.
		return parse_str_val(str, pos + 1)
	elseif first == '-' or first:match('%d') then  -- Parse a number.
		return parse_num_val(str, pos)
	elseif first == end_delim then  -- End of an object or array.
		return nil, pos + 1
	else  -- Parse true, false, or null.
		local literals = {['true'] = true, ['false'] = false, ['null'] = json.null}
		for lit_str, lit_val in pairs(literals) do
			local lit_end = pos + #lit_str - 1
			if str:sub(pos, lit_end) == lit_str then return lit_val, lit_end + 1 end
		end
		local pos_info_str = 'position ' .. pos .. ': ' .. str:sub(pos, pos + 10)
		webSyncError('Invalid json syntax starting at ' .. pos_info_str)
	end
end





-- ref: https://gist.github.com/ignisdesign/4323051
-- ref: http://stackoverflow.com/questions/20282054/how-to-urldecode-a-request-uri-string-in-lua
-- to encode table as parameters, see https://github.com/stuartpb/tvtropes-lua/blob/master/urlencode.lua

local char_to_hex = function(c)
	return string.format("%%%02X", string.byte(c))
end

function urlencode(url)
	if url == nil then
		return
	end
	url = url:gsub("\n", "\r\n")
	url = url:gsub("([^%w ])", char_to_hex)
	url = url:gsub(" ", "+")
	return url
end

local hex_to_char = function(x)
	return string.char(tonumber(x, 16))
end

urldecode = function(url)
	if url == nil then
		return
	end
	url = url:gsub("+", " ")
	url = url:gsub("%%(%x%x)", hex_to_char)
	return url
end
--#endregion

--#endregion


--[ GLOBALS ]--

local invalid_version -- Flag used to notify of an outdated version
local previous_game_settings
local deny_tp_ui_id


--[ CONSTANTS ]--
--#region

local SAVE_NAME = "CC_Autosave"
local MAX_AUTOSAVES = 5
local STEAM_ID_MIN = "76561197960265729"
local BUTTON_PREFIX = "?cc"


local LINE = "---------------------------------------------------------------------------"

local ABOUT = {
	{title = "ScriptVersion:", text = ScriptVersion},
	{title = "SaveDataVersion:", text = SaveDataVersion},
	{title = "Created By:", text = "Carsa, CrazyFluffyPony, Dargino, Leopard"},
	{title = "Github:", text = "https://github.com/carsakiller/Carsas-Commands"},
	{title = "More Info:", text = "For more info, I recommend checking out the github page"}
}

local DEV_STEAM_IDS = {
	["76561197976988654"] = true, --Deltars
	["76561198022256973"] = true, --Bones
	["76561198041033774"] = true, --Jon
	["76561198080294966"] = true, --Antie

	["76561197991344551"] = true, --Beginner
	["76561197965180640"] = true, --Trapdoor

	["76561198038082317"] = true, --NJersey
}

local TYPE_ABBREVIATIONS = {
	string = "text",
	number = "num",
	table = "tbl",
	bool = "bool",
	playerID = "text/num",
	vehicle = "num",
	steamID = "num",
	text = "text",
	letter = "letter"
}

--[ GAME DATA ]--
--#region

local GAME_SETTING_OPTIONS = {
	"third_person",
	"third_person_vehicle",
	"vehicle_damage",
	"player_damage",
	"npc_damage",
	"sharks",
	"fast_travel",
	"teleport_vehicle",
	"rogue_mode",
	"auto_refuel",
	"megalodon",
	"map_show_players",
	"map_show_vehicles",
	"show_3d_waypoints",
	"show_name_plates",
	"infinite_money",
	"settings_menu",
	"unlock_all_islands",
	"infinite_batteries",
	"infinite_fuel",
	"engine_overheating",
	"no_clip",
	"map_teleport",
	"cleanup_vehicle",
	"clear_fow",
	"vehicle_spawning",
	"photo_mode",
	"respawning",
	"settings_menu_lock",
	"despawn_on_leave",
	"unlock_all_components",
	"ceasefire",
	-- day/night length
	-- sunrise
	-- sunset
}

local EQUIPMENT_SIZE_NAMES = {
	"Large",
	"Small",
	"Outfit"
}

local EQUIPMENT_SLOTS = {
	{size = 1, letter = "A"},
	{size = 2, letter = "B"},
	{size = 2, letter = "C"},
	{size = 2, letter = "D"},
	{size = 2, letter = "E"},
	{size = 3, letter = "F"}
}

local SLOT_LETTER_TO_NUMBER = {
	A = 1,
	B = 2,
	C = 3,
	D = 4,
	E = 5,
	F = 6,
}

local EQUIPMENT_DATA = {
	{
		name = "diving suit",
		size = 3,
		data = {
			float = {
				name = "% filled",
				type = "float",
				default = 100
			}
		}
	},
	{
		name = "firefighter",
		size = 3
	},
	{
		name = "scuba suit",
		size = 3,
		data = {
			float = {
				name = "% filled",
				type = "float",
				default = 100
			}
		}
	},
	{
		name = "parachute",
		size = 3,
		data = {
			int = {
				name = "deployed",
				type = "int",
				default = 1
			}
		}
	},
	{
		name = "parka",
		size = 3
	},
	{
		name = "binoculars",
		size = 2
	},
	{
		name = "cable",
		size = 1
	},
	{
		name = "compass",
		size = 2
	},
	{
		name = "defibrillator",
		size = 1,
		data = {
			int = {
				name = "charges",
				type = "int",
				default = 4
			}
		}
	},
	{
		name = "fire extinguisher",
		size = 1,
		data = {
			float = {
				name = "% filled",
				type = "float",
				default = 9
			}
		}
	}, -- 10
	{
		name = "first aid",
		size = 2,
		data = {
			int = {
				name = "uses",
				type = "int",
				default = 4
			}
		}
	},
	{
		name = "flare",
		size = 2,
		data = {
			int = {
				name = "uses",
				type = "int",
				default = 4
			}
		}
	},
	{
		name = "flaregun",
		size = 2,
		data = {
			int = {
				name = "ammo",
				type = "int",
				default = 1
			}
		}
	},
	{
		name = "flaregun ammo",
		size = 2,
		data = {
			int = {
				name = "refills",
				type = "int",
				default = 3
			}
		}
	},
	{
		name = "flashlight",
		size = 2,
		data = {
			float = {
				name = "battery %",
				type = "float",
				default = 100
			}
		}
	},
	{
		name = "hose",
		size = 1,
		data = {
			int = {
				name = "on/off",
				type = "bool",
				default = 0
			}
		}
	},
	{
		name = "night vision binoculars",
		size = 2,
		data = {
			float = {
				name = "battery %",
				type = "float",
				default = 100
			}
		}
	},
	{
		name = "oxygen mask",
		size = 2,
		data = {
			float = {
				name = "% filled",
				type = "float",
				default = 100
			}
		}
	},
	{
		name = "radio",
		size = 2,
		data = {
			int = {
				name = "channel",
				type = "int",
				default = 0
			},
			float = {
				name = "battery %",
				type = "float",
				default = 100
			}
		}
	},
	{
		name = "radio signal locator",
		size = 1,
		data ={
			float = {
				name = "battery %",
				type = "float",
				default = 100
			}
		}
	}, -- 20
	{
		name = "remote control",
		size = 2,
		data = {
			int = {
				name = "channel",
				type = "int",
				default = 0
			},
			float = {
				name = "battery %",
				type = "float",
				default = 100
			}
		}
	},
	{
		name = "rope",
		size = 1
	},
	{
		name = "strobe light",
		size = 2,
		data = {
			int = {
				name = "on/off",
				type = "bool",
				default = 0
			},
			float = {
				name = "battery %",
				type = "float",
				default = 100
			}
		}
	},
	{
		name = "strobe light infrared",
		size = 2,
		data = {
			int = {
				name = "on/off",
				type = "bool",
				default = 0
			},
			float = {
				name = "battery %",
				type = "float",
				default = 100
			}
		}
	},
	{
		name = "transponder",
		size = 2,
		data = {
			int = {
				name = "on/off",
				type = "bool",
				default = 0
			},
			float = {
				name = "battery %",
				type = "float",
				default = 100
			}
		}
	},
	{
		name = "underwater welding torch",
		size = 1,
		data = {
			float = {
				name = "fuel %",
				type = "float",
				default = 250
			}
		}
	},
	{
		name = "welding torch",
		size = 1,
		data = {
			float = {
				name = "fuel %",
				type = "float",
				default = 420
			},
		}
	},
	{
		name = "coal",
		size = 2
	},
	{
		name = "hazmat suit",
		size = 3
	},
	{
		name = "radiation detector",
		size = 2,
		data = {
			float = {
				name = "battery %",
				type = "float",
				default = 100
			}
		}
	} --30
}
--#endregion

-- [ DEFAULTS ]--
--#region
local PREFERENCE_DEFAULTS = {
	equipOnRespawn = {
		value = true,
		type = {"bool"}
	},
	keepInventory = {
		value = false,
		type = {"bool"}
	},
	removeVehicleOnLeave = {
		value = true,
		type = {"bool"}
	},
	maxVoxels = {
		value = 0,
		type = {"number"}
	},
	startEquipmentA = {
		value = 0,
		type = {"number"}
	},
	startEquipmentB = {
		value = 15,
		type = {"number"}
	},
	startEquipmentC = {
		value = 6,
		type = {"number"}
	},
	startEquipmentD = {
		value = 11,
		type = {"number"}
	},
	startEquipmentE = {
		value = 0,
		type = {"number"}
	},
	startEquipmentF = {
		value = 0,
		type = {"number"}
	},
	welcomeNew = {
		value = false,
		type = {"bool", "text"}
	},
	welcomeReturning = {
		value = false,
		type = {"bool", "text"}
	},
	companion = {
		value = false,
		type = {"bool"}
	}
}

local DEFAULT_ROLES = {
	Owner = {
		active = true,
		admin = true,
		auth = true,
		members = {}
	},
	-- users with this role will receive notices when something important is changed
	Supervisor = {
		active = true,
		members = {}
	},
	Admin = {
		commands = {
			addAlias = true,
			addRole = true,
			addRule = true,
			bailout = true,
			banPlayer = true,
			banned = true,
			cc = true,
			ccHelp = true,
			clearRadiation = true,
			clearVehicle = true,
			equip = true,
			equipmentIDs = true,
			equipp = true,
			gameSettings = true,
			giveRole = true,
			heal = true,
			kill = true,
			playerPerms = true,
			playerRoles = true,
			position = true,
			preferences = true,
			removeAlias = true,
			removeRole = true,
			removeRule = true,
			resetPreferences = true,
			respawn = true,
			revokeRole = true,
			roleAccess = true,
			rolePerms = true,
			roles = true,
			roleStatus = true,
			rules = true,
			setEditable = true,
			setGameSetting = true,
			setPref = true,
			steamID = true,
			tp2me = true,
			tp2v = true,
			tpLocations = true,
			tpb = true,
			tpc = true,
			tpl = true,
			tpp = true,
			tps = true,
			tpv = true,
			unban = true,
			vehicleIDs = true,
			vehicleInfo = true,
			vehicleList = true,
			whisper = true,
		},
		active = true,
		admin = true,
		auth = true,
		members = {}
	},
	Moderator = {
		commands = {
			banPlayer = true,
			banned = true,
			cc = true,
			ccHelp = true,
			clearRadiation = true,
			clearVehicle = true,
			equip = true,
			equipmentIDs = true,
			equipp = true,
			heal = true,
			playerPerms = true,
			playerRoles = true,
			position = true,
			preferences = true,
			respawn = true,
			roles = true,
			rules = true,
			setEditable = true,
			steamID = true,
			tp2v = true,
			tpLocations = true,
			tpb = true,
			tpc = true,
			tpl = true,
			tpp = true,
			tps = true,
			tpv = true,
			unban = true,
			vehicleIDs = true,
			vehicleInfo = true,
			vehicleList = true,
			whisper = true,
		},
		active = true,
		admin = true,
		auth = true,
		members = {}
	},
	Auth = {
		commands = {
			setEditable = true
		},
		active = true,
		admin = false,
		auth = true,
		members = {}
	},
	Everyone = {
		commands = {
			aliases = true,
			rules = true,
			roles = true,
			vehicleList = true,
			vehicleIDs = true,
			vehicleInfo = true,
			respawn = true,
			playerRoles = true,
			playerPerms = true,
			position = true,
			heal = true,
			equip = true,
			tpb = true,
			tpc = true,
			tpl = true,
			tpp = true,
			tpv = true,
			tps = true,
			tp2v = true,
			cc = true,
			ccHelp = true,
			equipmentIDs = true,
			tpLocations = true,
			whisper = true,
			gameSettings = true
		},
		active = true,
		admin = false,
		auth = true,
		members = {}
	},
	Prank = {
		active = true,
		admin = false,
		auth = false,
		members = {}
	}
}

local DEFAULT_ALIASES = {
	cv = "clearVehicle",
	vl = "vehicleList",
	vlist = "vehicleList",
	vinfo = "vehicleInfo",
	vedit = "setEditable",
	vids = "vehicleIDs",
	pr = "playerRoles",
	pp = "playerPerms",
	h = "heal",
	e = "equip",
	p = "position",
	eids = "equipmentIDs",
	tpls = "tpLocations",
	w = "whisper"
}
--#endregion
--#endregion


--[ GENERAL HELPER FUNCTIONS ]--
--#region

---compares two version strings
---@param v string the first version string
---@param v2 string the second version string
---@return boolean|nil comparison 'v < v2' or nil if v == v2
function compareVersions(v, v2)
	local version1 = {}
	local version2 = {}
	v = tostring(v)
	v2 = tostring(v2)

	for digit in string.gmatch(v, "([^.]+)") do
		table.insert(version1, digit)
	end
	for digit in string.gmatch(v2, "([^.]+)") do
		table.insert(version2, digit)
	end

	for k, v in ipairs(version1) do
		if v < version2[k] then
			return true
		elseif v > version2[k] then
			return false
		end
	end
	return nil
end

---@param v number The value to clamp between low and high
---@param low number The minimum allowed value
---@param high number The maximum allowed value
--- @return number clamped_value The new value clamped between low and high (low ≤ v ≤ high)
function clamp(v, low, high)
	return math.min(math.max(v,low),high)
end

--- converts strings to boolean values
---@param value string The string to convert to a bool
--- @return boolean value The input value as a bool
function toBool(value)
	local lookup = {["true"] = true, ["false"] = false}
	return lookup[string.lower(tostring(value))]
end

--- checks if the passed string is a single letter
---@param l string the string to check
---@return boolean is_letter Is the string is a letter or not
function isLetter(l)
	local l = tostring(l)
	if not l then return false end
	if #l > 1 then return false end

	local b = l:lower():byte()
	if b > 96 and b < 123 then
		return true
	end
	return false
end

--- useful when you don't know if a value will exist in nested tables. Prevents attempts to index nil values as this will just return false
---@param root table the beginning table
---@param path table the keys to use when traversing, in a table
--- @example exploreTable(myTable, {"keyAtDepth1", "keyAtDepth2"})
function exploreTable(root, path)
	if #path <= 1 then
		return root[path[1]]
	end
	local dive = table.remove(path, 1)
	if root[dive] ~= nil then
		return exploreTable(root[dive], path)
	else
		return nil
	end
end

--- used to find most similar string in table
---@param s string the string to be comparing against strings from table
---@param t table the table of strings to be comparing against s
---@param case_sensitive? boolean if the fuzzy search should be case sensitive or not
---@return string most_similar the most similar string from t
function fuzzyStringInTable(s, t, case_sensitive)
	local match_exists = false
	local scores = {}

	for k, v in ipairs(t) do
		if fzy.has_match(s, v, case_sensitive) then
			match_exists = true
			break
		end
	end

	if not match_exists then return false end

	for k, v in ipairs(t) do
		scores[k] = {fzy.score(s, v), v}
	end
	table.sort(scores, function(a, b) return a[1] > b[1] end)

	return scores[1][2]
end

--- used to make a deep copy of a table
---@param t table the table to copy
---@return table copy the copy of table t
function deepCopyTable(t)
	local child = {}

	for k, v in pairs(t) do
		if type(v) == "table" then
			child[k] = deepCopyTable(v)
		else
			child[k] = v
		end
	end

	return child
end

--- returns the data of a command as a nicely formatted string
---@param command_name string the name of the command to format
---@param include_arguments boolean if the arguments of the command should be included
---@param include_types boolean if the data types of the arguments should be included (include_arguments must be true)
---@param include_description boolean if the description of the command should be included
---@return string name the name of the command
---@return string data the data of the command formatted for printing
function prettyFormatCommand(command_name, include_arguments, include_types, include_description)
	local text = ""
	local args = {}

	if not COMMANDS[command_name] then
		return false, (command_name .. " does not exist")
	end

	if COMMANDS[command_name].args and include_arguments then
		for command_name, command_data in ipairs(COMMANDS[command_name].args) do
			local s = ""
			local optional = not command_data.required

			local types = {}
			if include_types then
				for _, type in ipairs(command_data.type) do
					table.insert(types, TYPE_ABBREVIATIONS[type])
				end
			end

			s = s .. (optional and "[" or "") .. command_data.name .. (include_types and string.format("(%s)", table.concat(types, "/")) or "") .. (optional and "]" or "") -- add optional bracket symbols
			s = s .. (command_data.repeatable and " ..." or "") -- add repeatable symbol
			table.insert(args, s)
		end
		text = text .. " " .. table.concat(args, ", ")
	end

	if include_description then text = text .. "\n" .. COMMANDS[command_name].description end
	return "?" .. command_name, text
end

---Checks whether a tp's coordinates are valid or if they would teleport something off-map and break things
---@param target_matrix table The matrix that things are being teleported to
---@return boolean is_valid If the requested coords are valid or are nill / off-map
---@return string? title A title to explain why the coords are invalid, or nil if it is valid
---@return string? statusText Some text to explain why the coords are invalid, or nil if it is valid
function checkTp(target_matrix)
	local x, y, z = matrix.position(target_matrix)

	if not x or not y or not z then
		return false, "INVALID POSITION", "The given position is invalid"
	end

	if math.abs(x) > 150000 or math.abs(y) > 10000000000 or math.abs(z) > 150000 then
		return false, "UNSAFE TELEPORT", "You have not been teleported as teleporting to the requested coordinates would brick this save"
	end

	return true
end

---Checks if the provided "playerID" is actually valid
---@param playerID string This could be a peerID, name, or "me" but it comes here as a string
---@param caller Player The player that called this function. Used for translating "me"
---@return boolean is_valid If the provided playerID is valid
---@return number|nil peerID The peerID of the target playerID
---@return string|nil err Why the provided playerID is invalid
function validatePlayerID(playerID, caller)
	local as_num = tonumber(playerID)

	if as_num then
		if STEAM_IDS[as_num] then
			return true, G_players.get(STEAM_IDS[as_num])
		else
			return false, nil, (quote(playerID) .. " is not a valid peerID")
		end
	else
		if playerID == "me" then
			return true, caller
		elseif playerID ~= nil then
			local names = {}
			local peerIDs = {}

			for peerID, steamID in pairs(STEAM_IDS) do
				local player = G_players.get(steamID)
				if peerIDs[player.name] then
					return false, nil, "Two players have the name " .. quote(playerID) .. ". Please use peerIDs instead"
				end
				table.insert(names, player.name)
				peerIDs[player.name] = peerID
			end

			local nearest = fuzzyStringInTable(playerID, names, false)
			if nearest then
				return true, G_players.get(STEAM_IDS[peerIDs[nearest]])
			else
				return false, nil, ("A player with the name " .. quote(playerID) .. " could not be found")
			end
		end
	end
	return false, nil, "A playerID was not provided"
end

---Check that some data is of a given type
---@param data any The data to check
---@param target_type string The type this data should be
---@param caller Player The player calling this function
---@return boolean is_valid The data is of the same type as target_type
---@return any|nil converted_value The data converted from whatever it was before (likely a string) to it's true type
---@return string|nil err Why the data is invalid
function dataIsOfType(data, target_type, caller)
	local as_num = tonumber(data)

	if target_type == "playerID" then
		return validatePlayerID(data, caller)
	elseif target_type == "vehicleID" then
		if not as_num then
			return false, nil, (tostring(data) .. " is not a number and therefor not a valid vehicleID")
		end
		local vehicle = G_vehicles.get(as_num)
		if vehicle then
			return true, vehicle
		else
			return false, nil, quote(as_num) .. " is not a valid vehicleID"
		end
	elseif target_type == "steamID" then
		if #data == #STEAM_ID_MIN then
			return true, data
		else
			return false, nil, (data .. " is not a valid steamID")
		end
	elseif target_type == "peerID" then
		return validatePlayerID(as_num, caller)
	elseif target_type == "number" then
		return as_num ~= nil, as_num, not as_num and ((data or "nil") .. " is not a valid number")
	elseif target_type == "bool" then
		local as_bool = toBool(data)
		return as_bool ~= nil, as_bool, as_bool == nil and (tostring(data) .. " is not a valid boolean value") or nil
	elseif target_type == "letter" then
		local is_letter = isLetter(data)
		return is_letter, is_letter and data or nil, not is_letter and ((data or "nil") .. " is not a letter") or nil
	elseif target_type == "string" or target_type == "text" then
		return data ~= nil, data or nil, (data or "nil") .. " is not a string"
	end

	return false, nil, ((data or "nil") .. " is not of a recognized data type")
end

---Decodes the equip arguments and calls equip on the target
---@param caller Player The player calling the function
---@param target Player The player to run equip on
---@param notify boolean If the players involved should be notified of anything
---@param ... any equip args
---@return any results The results of `caller.equip()`
function equipArgumentDecode(caller, target, notify, ...)
	local args = {...}
	local args_to_pass = {}

	for _, v in ipairs(args) do
		if isLetter(v) then
			args_to_pass.slot = string.upper(v)
		else
			table.insert(args_to_pass, v)
		end
	end

	return target.equip(notify and caller, args_to_pass.slot or false, table.unpack(args_to_pass))
end

---Assists in paginating data from a table
---@param page number The page you want to display
---@param data_table table The table of data to paginate
---@param entries_per_page number The number of entries you want per page
---@return number page The actual page being displayed
---@return number max_page The max number of pages needed to display the data
---@return number start_index The start index that should be used for looping through the `data_table` and printing
---@return number end_index The end index that should be used for looping through the `data_table` and printing
function paginate(page, data_table, entries_per_page)
    local max_page = math.max(1, math.ceil(#data_table / entries_per_page))
    page = clamp(page, 1, max_page)
    local start_index = (page - 1) * entries_per_page + 1
    local end_index = math.min(#data_table, page * entries_per_page)
    
    return page, max_page, start_index, end_index
end

---Quotes text
---@param text string The text to put in quotes
---@return string quoted_text The text in quotes
function quote(text)
	return string.format("\"%s\"", tostring(text))
end

---Get the keys from a table and optionally sort them
---@param t table The table to get the keys from
---@param sort boolean If the keys should be sorted. Else, order is not guaranteed
---@param reverse_sort boolean If the keys should be sorted in ascending order rather than descending order
---@return table keys The keys from the table
function getTableKeys(t, sort, reverse_sort)
	local keys = {}

	for k, _ in pairs(t) do
		table.insert(keys, k)
	end

	if sort then
		if reverse_sort then
			table.sort(keys, function(a, b) return a > b end)
		else
			table.sort(keys)
		end
	end

	return keys
end

---Tell all players with the supervisor role something important
---@param title string The title of the message
---@param message string The message content
---@vararg number PeerIDs to not include in the broadcast
function tellSupervisors(title, message, ...)
	local peers = getTableKeys(STEAM_IDS)
	local excluded_peers = {...}

	if excluded_peers[1] ~= nil then
		for _, peerID in pairs(excluded_peers) do
			peers[peerID] = nil
		end
	end

	for peerID, _ in pairs(peers) do
		server.announce(title, message, peerID)
	end
end

---Autosave the game. Cycles through multiple save file names so as to not overwrite them immediately
function autosave()
	local save_index

	if g_savedata.autosave >= MAX_AUTOSAVES then
		g_savedata.autosave = 1
		save_index = MAX_AUTOSAVES
	elseif g_savedata.autosave < MAX_AUTOSAVES then
	    save_index = g_savedata.autosave
		g_savedata.autosave = g_savedata.autosave + 1
	end

	server.save(string.format(string.format("%s_%d", SAVE_NAME, save_index)))
end
--#endregion


--[ SOOP ]--
--#region

---Creates a new object from a class
---@param class table A class like `Players` or `Role`
---@return table object A new object created using a class
function new(class, ...)
	local obj = {}

	for k, v in pairs(class) do
		if type(v) == "function" then
			-- replace every function with a middleware function that sets the "self" argument
			obj[k] = function(...)
				return v(obj, ...)
			end
		end
	end

	obj.constructor(...)
	return obj
end

---serializes an object for storing to g_savedata
---@param object table The object to serialize
---@return table data The serialized object data to save
function serialize(object)
	local data = {}
	for k, v in pairs(object) do
		if type(v) ~= "function" then
			data[k] = v
		end
	end
	return data
end



---Class that defines each role
---@class Role
local Role = {}
--#region

---Creates a role object
---@param self Role This role object's instance
---@param name string The name of the new role
---@param active? boolean If this role should be active by default
---@param admin? boolean If this role should give it's members admin privileges
---@param auth? boolean If this role should give it's members auth privileges
---@param commands? table A table indexed by command names with a value of true for each command this role should give access to
---@param members table? A table indexed by the `steamIDs` of the players that have this role
function Role.constructor(self, name, active, admin, auth, commands, members)
	self.name = name
	self.active = active or true
	self.admin = admin or false
	self.auth = auth or false
	self.commands = commands or {}
	self.members = members or {}

	self.save()
end

---Save this role to g_savedata
---@param self Role This role object's instance
function Role.save(self)
	g_savedata.roles[self.name] = serialize(self)
end

---Adds a player to this role
---@param self Role This role object's instance
---@param player Player The target player's object instance
function Role.addMember(self, player)
	self.members[player.steamID] = true
	player.updatePrivileges()

	self.save()
end

---Removes a player from this role
---@param self Role This role object's instance
---@param player Player The target player's object instance
function Role.removeMember(self, player)
	self.members[player.steamID] = nil
	player.updatePrivileges()

	self.save()
end

---Sets the active state of this role
---@param self Role This role object's instance
---@param state boolean If this role should be enabled or disabled
---@return boolean state The new state of this role
function Role.setState(self, state)
	self.active = state
	self.updateMembers()

	self.save()

	return self.active
end

---Set the stormworks permissions of this role
---@param self Role This role object's instance
---@param admin boolean If this role should grant or deny admin privileges
---@param auth boolean If this role should grant or deny auth privileges
---@return boolean change_made If a change was made to the permissions or they are the same as before
function Role.setPermissions(self, admin, auth)
	local change = false

	if self.admin ~= admin or self.auth ~= auth then
		change = true
	end

	self.admin = admin
	self.auth = auth

	if change then
		self.updateMembers()
	end

	self.save()

	return change
end

---Add access to a command for this role
---@param self Role This role object's instance
---@param command string The name of the command to give access to
function Role.addCommandAccess(self, command)
	self.commands[command] = true
	self.updateMembers()

	self.save()
end

---Remove access to a command for this role
---@param self Role This role object's instance
---@param command string The name of the command to remove access to
function Role.removeCommandAccess(self, command)
	self.commands[command] = nil
	self.updateMembers()

	self.save()
end

---Update the permissions for all the members of this role
---@param self Role This role object's instance
function Role.updateMembers(self)
	for steamID, _ in pairs(self.members) do
		local player = G_players.get(steamID)
		player.updatePrivileges()
	end
end
--#endregion


---Class that defines the object that contains all of the role objects
---@class RoleContainer
local RoleContainer = {}
--#region

---Creates a role container object
---@param self RoleContainer This role container object's instance
function RoleContainer.constructor(self)
	self.roles = {}
end

---Creates a role and adds it to this roles container
---@param self RoleContainer This role container object's instance
---@param role string The name of the new role
---@param active boolean? If the role is active or not
---@param admin boolean? If the role grants admin permissions
---@param auth boolean? If the role grants auth permissions
---@param commands table? A table indexed by the names of the commands this role should have access to
---@param members table? A table indexed by the `steamIDs` of the players that have this role
---@return boolean success If the role was created successfully
---@return string err Why the role was/wasn't created
---@return string errText Text explaining why the role was/wasn't created
function RoleContainer.create(self, role, active, admin, auth, commands, members)
	if self.roles[role] then
		return false, "ROLE ALREADY EXISTS", "The role " .. quote(role) .. " already exists"
	end
	self.roles[role] = new(Role, role, active, admin, auth, commands, members)
	return true, "ROLE CREATED", quote(role) .. " has been created"
end

---Deletes a role
---@param self RoleContainer This role container object's instance
---@param role string The name of the role to delete
---@return boolean success If the role was deleted successfully
---@return string err Why the real was/wasn't created
---@return string errText Text explaining why the role was/wasn't deleted
function RoleContainer.delete(self, role)
	if not self.roles[role] then
		return false, "ROLE NOT FOUND", quote(role) .. " is not a valid role"
	end

	self.roles[role] = nil

	g_savedata.roles[role] = nil

	return true, "ROLE DELETED", quote(role) .. " has been deleted"
end

---Gets a role from this role container
---@param self RoleContainer This role container object's instance
---@param role string The name of the role to get
---@return Role|table|nil role The role you were looking for or nil if it could not be found. If the `role` argument was not provided, then a table containing all roles in this container will be returned
function RoleContainer.get(self, role)
	if not role then
		return self.roles
	else
		return self.roles[role]
	end
end
--#endregion


---Class that defines the object for each player
---@class Player
local Player = {}
--#region

---Creates a player object
---@param self Player This player object's instance
---@param peerID peerID The `peerID` of the player to create
---@param steamID steamID The `steamID` of the player to create
---@param name string The name of the player to create
---@param banned? steamID The steam_if of the admin that banned them or nil
function Player.constructor(self, peerID, steamID, name, banned)
	self.peerID = peerID
	self.steamID = steamID
	self.name = name
	self.banned = banned or exploreTable(g_savedata.players, {steamID, "banned"})
	self.tp_blocking = exploreTable(g_savedata.players, {steamID, "block_tps"})
	self.show_vehicleIDs = exploreTable(g_savedata.players, {steamID, "show_vehicleIDs"})

	local admin, auth = self.updatePrivileges()
	self.admin = admin
	self.auth = auth

	self.save()
end

---Save this player object to g_savedata
---@param self Player This player object's instance
function Player.save(self)
	g_savedata.players[self.steamID] = serialize(self)
end

---Checks whether a player has a role or not
---@param self Player This player object's instance
---@param role string THe name of the role to check for
---@return boolean has_role If the player has the role or not
function Player.hasRole(self, role)
	for steamID, _ in pairs(G_roles.roles[role]) do
		if steamID == self.steamID then
			return true
		end
	end
	return false
end

---Check whether or not this player has access to a specific command
---@param self Player This player object's instance
---@param command string The name of the command to check for
---@return boolean has_access If the player has access to the command or not
function Player.hasAccessToCommand(self, command)
	for role_name, role in pairs(G_roles.get()) do
		if role.active and role.members[self.steamID] then
			if role_name == "Owner" or role.commands[command] then
				return true
			end
		end
	end
	return false
end

---Formats the player's name nicely, providing their peerID if they are online or their steamID if they are offline
---@param self Player This player object's instance
---@return string pretty_name This player's name formatted nicely
function Player.prettyName(self)
	if self.peerID then
		return string.format("%s(%d)", self.name, self.peerID)
	else
		return string.format("%s(%s)", self.name, self.steamID)
	end
end

---Bans this player from the server
---@param self Player This player object's instance
---@param admin_steamID steamID The steam id of the admin banning this player
---@return boolean success If the operation succeeded or failed
---@return string err Why the operation succeeded/failed
---@return string errText Explanation for why the operation succeeded/failed
function Player.ban(self, admin_steamID)
	local admin = G_players.get(admin_steamID)
	self.banned = admin_steamID

	if self.peerID then
		server.kickPlayer(self.peerID)
		tellSupervisors("PLAYER BANNED", self.prettyName() .. " has been banned by " .. admin.prettyName(), admin.peerID)
	end
	self.save()

	return true, "PLAYER BANNED", self.prettyName() .. " has been banned"
end

---Unbans a player from the server
---@param self Player This player object's instance
---@param admin_steamID steamID The steam id of the admin banning this player
---@return boolean success If the operation succeeded or failed
---@return string err Why the operation succeeded/failed
---@return string errText Explanation for why the operation succeeded/failed
function Player.unban(self, admin_steamID)
	local admin = G_players.get(admin_steamID)
	self.banned = false
	self.save()

	tellSupervisors("PLAYER UNBANNED", self.prettyName() .. " has been unbanned by " .. admin.prettyName(), admin.peerID)
	return true, "PLAYER UNBANNED", self.prettyName() .. " has been unbanned"
end

---Gets the position of this player
---@param self Player This player object's instance
---@return matrix matrix The position of this player
---@return boolean is_success If the position was retrieved successfully
function Player.getPosition(self)
	return server.getPlayerPos(self.peerID)
end

---Sets the position of this player
---@param self Player This player object's instance
---@param position matrix The target position of the player
---@return boolean success If the operation succeeded or failed
---@return string|nil err Why the operation failed, if it did
---@return string|nil errText Explanation for why the operation failed, if it did
function Player.setPosition(self, position)
	local valid, err, errText = checkTp(position)
	if not valid then
		return valid, err, errText
	end
	local success = server.setPlayerPos(self.peerID, position)
	return success
end

---Gets the inventory of this player
---@param self Player This player object's instance
---@return table|boolean inventory A table containing the equipmentIDs indexed by the slot number. False if there was an error
---@return number|string count The number of items in the player's inventory. An error message if there was an error
---@return nil|string err An explanation of what went wrong. Nil if there was no error
function Player.getInventory(self)
	local inventory = {}
	local count = 0
	local character_id, success = server.getPlayerCharacterID(self.peerID)

	if not success then
		return false, "ERROR", "Could not get the inventory of " .. self.prettyName() .. "\n::characterID could not be found"
	end

	for i=1, #EQUIPMENT_SLOTS do
		local equipment_id, success = server.getCharacterItem(character_id, i)
		inventory[i] = (success and equipment_id) or 0
		if inventory[i] ~= 0 then
			count = count + 1
		end
	end

	return inventory, count
end

---Gives this player the starting equipment as defined in `G_preferences`
---@param self Player This player object's instance
---@return boolean success If the operation succeeded or not
---@return string|nil err What error occurred, if any
---@return string|nil errText An explanation of the error, if any
function Player.giveStartingEquipment(self)
	local items = {
		G_preferences.startEquipmentA,
		G_preferences.startEquipmentB,
		G_preferences.startEquipmentC,
		G_preferences.startEquipmentD,
		G_preferences.startEquipmentE,
		G_preferences.startEquipmentF
	}

	for i, item_data in pairs(items) do
		local success, title, statusText = self.equip(nil, EQUIPMENT_SLOTS[i].letter, item_data.value)
		if not success then
			server.announce(title, statusText)
			return false, title, statusText
		end
	end
	return true
end

---Equips this player with the requested equipment
---@param self Player This player object's instance
---@param notify? Player The player that called the operation that will be notified about the status of the equip operation
---@param slot? string The slot to insert the item into
---@param item_id number The equipment_id of the item to insert
---@param data1? number The data of the item to insert
---@param data2? number The second data of the item to insert
---@param is_active? boolean If the item should be active
---@return boolean success If the equip operation succeeded
---@return string err Why the succeeded/failed
---@return string errText An explanation for why the operation succeeded/failed
function Player.equip(self, notify, slot, item_id, data1, data2, is_active)
	local character_id, success = server.getPlayerCharacterID(self.peerID)

	if not success then
		return false, "ERROR", "Could not find the character for " .. self.prettyName() .. ". This should never happen"
	end

	item_id = tonumber(item_id)
	slot = slot and string.upper(slot) or nil

	local slot_number = SLOT_LETTER_TO_NUMBER[slot]

	if not item_id then
		return false, "INVALID ARG", "Could not convert argument " .. quote(item_id) .. " to an equipment_id (number)"
	end

	if item_id == 0 then
		return server.setCharacterItem(character_id, slot_number or 1, 0, false, 0, 0)
	end

	local item_data = EQUIPMENT_DATA[item_id]
	if not item_data then
		return false, "INVALID ARG", "There is no equipment with the id of " .. tostring(item_id)
	end

	local item_name = item_data.name
	local item_size = item_data.size
	local item_params = item_data.data
	local item_size_name = EQUIPMENT_SIZE_NAMES[item_size]
	local item_pretty_name = string.format("\"%s\" (%d)", item_name, item_id)
	local caller_pretty_name = notify and notify.prettyName() or nil
	local target_pretty_name = self.prettyName()

	is_active = toBool(is_active) or false

	-- Apply default charge etc.
	if item_params then
		if item_params.int and item_params.float then
			if not data1 then
				data1 = item_params.int.default
			end
			if not data2 then
				data2 = item_params.float.default
			end
		elseif item_params.int then
			data1 = data1 or item_params.int.default
		elseif item_params.float then
			if data1 and data2 then
				-- User probably knows what they are doing
			else
				data2 = data1 or item_params.float.default
				data1 = 0 -- must have a value
			end
		end
	end

	local isRecharge = false
	-- if slot not provided, get player's inventory so we can find an open slot, if any
	if not slot_number then
		local success = false
		local inventory, count, error = self.getInventory()
		if not inventory then return inventory, count, error end

		local available_slots = {}
		for k, v in ipairs(EQUIPMENT_SLOTS) do
			if item_size == v.size then
				table.insert(available_slots, v.name)
				if inventory[k] == 0 -- give player requested item in open slot
				or inventory[k] == item_id -- replace an existing item, presumably to recharge it.
				or item_size ~= 2 -- item is not a small item, there is only one slot, replace the item
				then
					if inventory[k] == item_id then isRecharge = true end
					slot_number = k
					success = true
					break
				end
			end
		end

		if not success then
			local err
			-- inventory is full of same-size items
			if self.peerID == notify.peerID then
				err = string.format("Could not equip you with %s because your inventory is full of %s items. To replace an item specify the slot to replace. Options: %s", item_pretty_name, item_size_name, table.concat(available_slots, ", "))
			else
				err = string.format("%s could not be equipped with %s because their inventory is full of %s items. To replace an item specify the slot to replace. Options: %s", target_pretty_name, item_pretty_name, item_size_name, table.concat(available_slots, ", "))
			end
			return false, "INVENTORY FULL", err
		end
	end

	success = server.setCharacterItem(character_id, slot_number, item_id, is_active, data1, data2)
	if success then
		local slot_name = EQUIPMENT_SLOTS[slot_number].letter
		if notify then
			if isRecharge then
				if notify then
					server.notify(self.peerID, "EQUIPMENT UPDATED", caller_pretty_name .. " updated your " .. item_pretty_name .. " in slot " .. slot_name, 5)
				end
				return true, "PLAYER EQUIPPED", target_pretty_name .. "'s " .. item_pretty_name .. " in slot " .. slot_name .. " has been updated"
			else
				if notify then
					server.notify(self.peerID, "EQUIPPED", caller_pretty_name .. " equipped you with " .. item_pretty_name .. " in slot " .. slot_name, 5)
				end
				return true, "PLAYER EQUIPPED", target_pretty_name .. " was equipped with " .. item_pretty_name .. " in slot " .. slot_name
			end
		else
			if isRecharge then
				return true, "EQUIPMENT UPDATED", item_pretty_name .. " in slot " .. slot_name .. " has been updated"
			else
				return true, "EQUIPMENT GIVEN", item_pretty_name .. " has been equipped in slot " .. slot_name
			end
		end
	else
		return false, "ERROR OCCURRED", "An error occurred while giving " .. target_pretty_name .. " " .. item_pretty_name
	end
end

---Used to update the stormworks privileges for a player
---@param self Player This player object's instance
---@return boolean admin If the player is an admin
---@return boolean auth If the player is auth'd
function Player.updatePrivileges(self)
	local players = server.getPlayers()
	local is_admin = false
	local is_auth = false
	local role_admin = false
	local role_auth = false

	for k, v in pairs(players) do
		if tostring(v.steamID) == self.steamID then
			is_admin = v.admin
			is_auth = v.auth
			break
		end
	end

	for _, role in pairs(G_roles.get()) do
		if role_admin and role_auth then break end
		if role.active then
			if role.members[self.steamID] then
				if role.admin then role_admin = true end
				if role.auth then role_auth = true end
			end
		end
	end

	if role_admin and not is_admin then
		server.addAdmin(self.peerID)
		self.admin = true
	elseif not role_admin and is_admin then
		server.removeAdmin(self.peerID)
		self.admin = false
	end

	if role_auth and not is_auth then
		server.addAuth(self.peerID)
		self.auth = true
	elseif not role_auth and is_auth then
		server.removeAuth(self.peerID)
		self.auth = false
	end

	self.save()

	return role_admin, role_auth
end

---Sets the state of tp blocking for this player
---@param self Player This player object's instance
---@param state? boolean The new state of tp blocking for this player. Toggles if no bool is provided
---@return boolean new_state The new state of tp blocking for this player
function Player.setTpBlocking(self, state)
	if state == nil then
		self.tp_blocking = not self.tp_blocking
	else
		self.tp_blocking = state
	end

	self.updateTpBlocking()

	self.save()
	return self.tp_blocking
end

---Updates this player's UI to display the state of their tp blocking
---@param self Player This player object's instance
function Player.updateTpBlocking(self)
	if self.tp_blocking then
		server.setPopupScreen(self.peerID, deny_tp_ui_id, "", true, "Blocking Teleports", 0.34, -0.88)
	else
		server.removePopup(self.peerID, deny_tp_ui_id)
	end
end

---Set the new state for the vehicleID UI for this player
---@param self Player This player object's instance
---@param state? boolean The new state of the UI, enabled or disabled. Toggles if no bool is provided
---@return boolean new_state The new state of the UI for this player
function Player.setVehicleUIState(self, state)
	if state == nil then
		self.show_vehicleIDs = not self.show_vehicleIDs
	else
		self.show_vehicleIDs = state
	end

	if not self.show_vehicleIDs then
		-- remove popups for all vehicles
		for vehicleID, vehicle in pairs(G_vehicles.get()) do
			server.removePopup(self.peerID, vehicle.ui_id)
		end
	end

	self.save()
	return self.show_vehicleIDs
end

---Updates this player's UI to display vehicle ID info
---@param self Player This player's object instance
function Player.updateVehicleIdUI(self)
	for vehicleID, vehicle in pairs(G_vehicles.get()) do
		local vehicle_position = vehicle.getPosition()
		if vehicle_position then
			local owner = vehicle.owner
			server.setPopup(self.peerID, vehicle.ui_id, "", true, string.format("%s\n%s", vehicle.pretty_name, G_players.get(owner).prettyName()), vehicle_position[13], vehicle_position[14], vehicle_position[15], 50)
		end
	end
end

---Sorts the vehicles in the world by distance to the player
---@param self Player This player object's instance
---@param owner_steamID? string A steamID used to sort which vehicles are retrieved. Only vehicles spawned by this steamID will be sorted
---@return table|boolean vehicles A table of vehicles, sorted by distance to the player. False if an error occurred
---@return string? err Why the operation failed
---@return string? errText An explanation for why the operation failed
function Player.nearestVehicles(self, owner_steamID)
	local vehicles = G_vehicles.get()
	local distances = {}

	if not vehicles then
		return false, "NO VEHICLES FOUND", "There are no vehicles in the world"
	end

	for _, vehicle in pairs(vehicles) do
		if owner_steamID and vehicle.owner == self.steamID or not owner_steamID then
			local player_pos = self.getPosition()
			local vehicle_pos = vehicle.getPosition()
			table.insert(distances, {vehicle = vehicle, distance = math.abs(matrix.distance(player_pos, vehicle_pos))})
		end
	end

	if owner_steamID and #distances == 0 then
		return false, "NO VEHICLES FOUND", "There are no vehicles nearby that are owned by " .. G_players.get(owner_steamID).prettyName()
	end

	table.sort(distances, function(a, b) return a.distance < b.distance end)

	local nearest = {}
	for k, v in pairs(distances) do
		nearest[k] = v.vehicle
	end

	return nearest
end
--#endregion


---Class that defines the object that contains all of the player objects
---@class PlayerContainer
local PlayerContainer = {}
--#region

---Creates a player container object
---@param self PlayerContainer This player container's object instance
function PlayerContainer.constructor(self)
	self.players = {}
end

---Creates a new player object and adds it to this container
---@param self PlayerContainer This player container's object instance
---@param peerID peerID The peerID of the player
---@param steamID steamID The steamID of the player
---@param name string The name of the player
---@param banned? boolean If the player should be banned immediately
---@return Player self The new player object
function PlayerContainer.create(self, peerID, steamID, name, banned)
	self.players[steamID] = new(Player, peerID, steamID, name, banned)
	return self.players[steamID]
end

---Gets a player from this player container
---@param self PlayerContainer This player container's object instance
---@param steamID? string The steamID of the player
---@return Player|table|nil player The player you were looking for or nil if it could not be found. If the `steamID` argument was not provided, then a table consisting of all players in this container will be returned
function PlayerContainer.get(self, steamID)
	if not steamID then
		return self.players
	else
		return self.players[steamID]
	end
end

---Class that defines the object for each vehicle
---@class Vehicle
local Vehicle = {}
--#region

---Creates a Vehicle object
---@param self Vehicle This vehicle's object instance
---@param vehicleID number The vehicle id of the vehicle
---@param owner_steamID string The steam id of the owner of the vehicle
---@param cost number The cost of the vehicle
function Vehicle.constructor(self, vehicleID, owner_steamID, cost)
	self.vehicleID = vehicleID
	self.owner = owner_steamID or exploreTable(g_savedata.vehicles, {vehicleID, "owner"})

	local name, success = server.getVehicleName(vehicleID)
	self.name = success and (name ~= "Error" and name or "Unknown") or "Unknown"
	self.pretty_name = string.format("%s(%d)", self.name, self.vehicleID)
	self.cost = exploreTable(g_savedata.vehicles, {vehicleID, "cost"}) or cost

	self.ui_id = exploreTable(g_savedata.vehicles, {vehicleID, "ui_id"}) or server.getMapID()

	self.save()
end

---Save this vehicle to g_savedata
---@param self Vehicle This vehicle's object instance
function Vehicle.save(self)
	g_savedata.vehicles[self.vehicleID] = serialize(self)
end

---Gets the position of the vehicle
---@param self Vehicle This vehicle's object instance
---@param voxel_x number Voxel x axis offset
---@param voxel_y number Voxel y axis offset
---@param voxel_z number Voxel z axis offset
---@return matrix|boolean matrix The matrix of the vehicle or false if the position could not be found
function Vehicle.getPosition(self, voxel_x, voxel_y, voxel_z)
	local position, success = server.getVehiclePos(self.vehicleID, voxel_x, voxel_y, voxel_z)
	return success and position or false
end

---Sets the position of the vehicle
---@param self Vehicle This vehicle's object instance
---@param position matrix The new position to set for the vehicle
---@param unsafe boolean If the vehicle should be teleported to the exact position, not accounting for any obstacles
---@return boolean success If the vehicle was successfully teleported
function Vehicle.setPosition(self, position, unsafe)
	if unsafe then
		return server.setVehiclePos(self.vehicleID, position)
	else
		return server.setVehiclePosSafe(self.vehicleID, position)
	end
end

---Set whether a vehicle can be edited or not
---@param self Vehicle This vehicle's object instance
---@param state boolean The new edit state of the vehicle
---@return boolean success If the state has been set successfully
function Vehicle.setEditable(self, state)
	return server.setVehicleEditable(self.vehicleID, state)
end
--#endregion


---Class that defines the object that contains all of the vehicle objects
---@class VehicleContainer
local VehicleContainer = {}
--#region

---Creates a vehicle container object
---@param self VehicleContainer This vehicle container's object instance
function VehicleContainer.constructor(self)
	self.vehicles = {}
end

---Creates a new vehicle object and adds it to this container
---@param self VehicleContainer This vehicle container's object instance
---@param vehicleID vehicleID The vehicleID of the vehicle
---@param owner_steamID steamID The steamID of the player that owns the vehicle
---@param cost number The cost of the vehicle
---@return Vehicle vehicle The new vehicle object
function VehicleContainer.create(self, vehicleID, owner_steamID, cost)
	self.vehicles[vehicleID] = new(Vehicle, vehicleID, owner_steamID, cost)
	return self.vehicles[vehicleID]
end

---Removes a vehicle object from this vehicle container object
---@param self VehicleContainer This vehicle container's object instance
---@param vehicleID vehicleID The vehicleID of the vehicle to remove
function VehicleContainer.remove(self, vehicleID)
	local vehicle = self.get(vehicleID)
	local owner = G_players.get(vehicle.owner)

	if owner.latest_spawn and owner.latest_spawn == vehicleID then
		-- if this vehicle being despawned is the owner's latest spawn, set latest_spawn to nil
		owner.latest_spawn = nil
	end

	g_savedata.vehicles[vehicleID] = nil

	server.removeMapID(-1, self.get(vehicleID).ui_id)
	self.vehicles[vehicleID] = nil
end

---Gets a vehicle from this container
---@param self VehicleContainer This vehicle container's object instance
---@param vehicleID? vehicleID The vehicleID of the vehicle to get
---@return Vehicle|table|nil vehicle The vehicle you were looking for or nil if the vehicle could not be found. If the `vehicleID` argument is not provided, a table containing all vehicles in this container will be returned
function VehicleContainer.get(self, vehicleID)
	if not vehicleID then
		return self.vehicles
	else
		return self.vehicles[vehicleID]
	end
end
--#endregion


---Class that defines the object that contains all of the rules
---@class Rules
local Rules = {}
--#region

---Creates a Rules object
---@param self Rules
function Rules.constructor(self)
	self.rules = {}
end

---Saves this rulebook to g_savedata
---@param self Rules This rules object's instance
function Rules.save(self)
	g_savedata.rules = self.rules
end

---Adds a rule to this rule container
---@param self Rules This rule container object's instance
---@param text string The text to add for the rule
---@param position number The position this rule should be inserted in this container
---@return boolean success If the rule was added successfully
---@return string err Why the rule was added/failed
---@return string errText Text explaining why the rule was/wasn't added
function Rules.add(self, text, position)
	local insert_position = clamp(position or #self.rules + 1, 1, #self.rules + 1)
	table.insert(self.rules, insert_position, text)

	self.save()
	return true, "RULE " .. insert_position .. " ADDED", "The following rule has been added:\n" .. text
end

---Removes a rule from this rule container
---@param self Rules This rule container object's instance
---@param position number The position of the rule that should be removed
---@return boolean success If the rule was removed successfully
---@return string err Text confirming the rule deletion
---@return string errText Text explaining the operation status
function Rules.remove(self, position)
	local rule = self.rules[position]
	if not rule then
		return false, "RULE NOT FOUND", "There is no rule #" .. position
	end
	table.remove(self.rules, position)

	self.save()
	return true, "RULE " .. position .. " REMOVED", "The following rule has been removed:\n" .. rule
end

---Prints the list of rules to a player
---@param self Rules This rule container object's instance
---@param steamID steamID The steamID of the player to print the rules to
---@param page number The page of the rulebook to print. If 0, all rules are printed
---@param silent boolean If there are no rules, nothing will be announced
function Rules.print(self, steamID, page, silent)
	local peerID = G_players.get(steamID).peerID
	if not peerID then return false end

	if #self.rules == 0 then
		if not silent then
			server.announce("NO RULES", "There are no rules", peerID)
			return
		end
	end

	server.announce(" ", "--------------------------------  Rules  --------------------------------", peerID)

	if page == 0 then
		for k, text in ipairs(self.rules) do
			server.announce("Rule #"..k, text, peerID)
		end
		return
	end

	local clamped_page, max_page, start_index, end_index = paginate(page, self.rules, 5)
	for i = start_index, end_index do
		server.announce("Rule #"..i, self.rules[i], peerID)
	end
	server.announce(" ", "Page " .. clamped_page .. " of " .. max_page .. "", peerID)
	server.announce(" ", LINE, peerID)
end

--#endregion
--#endregion
--#endregion


--[ CALLBACK FUNCTIONS ]--
--#region

function onCreate(is_new)
	deny_tp_ui_id = server.getMapID()

	-- check version
	if g_savedata.version then
		local save_data_is_newer = compareVersions(SaveDataVersion, g_savedata.version)
		if save_data_is_newer then
			invalid_version = true
		elseif save_data_is_newer == false then
			for k, v in pairs(PREFERENCE_DEFAULTS) do
				if not g_savedata.preferences[k] then
					g_savedata.preferences[k] = v
				end
			end
		end
	end

	if invalid_version then return end


	g_savedata.version = SaveDataVersion
	g_savedata.autosave = g_savedata.autosave or 1
	-- define if undefined
	g_savedata.vehicles = g_savedata.vehicles or {}
	g_savedata.objects = g_savedata.objects or {}
	g_savedata.players = g_savedata.players or {}
	g_savedata.roles = g_savedata.roles or deepCopyTable(DEFAULT_ROLES)
	g_savedata.unique_players = g_savedata.unique_players or 0
	g_savedata.preferences = g_savedata.preferences or deepCopyTable(PREFERENCE_DEFAULTS)
	g_savedata.rules = g_savedata.rules or {}
	g_savedata.aliases = g_savedata.aliases or deepCopyTable(DEFAULT_ALIASES)

	-- create references to shorten code
	G_vehicles = new(VehicleContainer) ---@type VehicleContainer
	G_objects = g_savedata.objects -- Not in use yet
	G_players = new(PlayerContainer) ---@type PlayerContainer
	G_roles = new(RoleContainer) ---@type RoleContainer
	G_rules = new(Rules) ---@type Rules
	G_preferences = g_savedata.preferences
	G_aliases = g_savedata.aliases

	-- deserialize data
	for steamID, data in pairs(g_savedata.players) do
		G_players.create(data.peerID, data.steamID, data.name, data.banned)
	end

	for vehicleID, data in pairs(g_savedata.vehicles) do
		G_vehicles.create(vehicleID, data.owner)
	end

	for role_name, data in pairs(g_savedata.roles) do
		G_roles.create(role_name, data.active, data.admin, data.auth, data.commands, data.members)
	end

	for index, rule in ipairs(g_savedata.rules) do
		G_rules.add(rule)
	end

	-- Main menu properties
	if is_new then
		G_preferences.companion.value = property.checkbox("Carsa's Companion", "false")
		G_preferences.equipOnRespawn.value = property.checkbox("Equip players on spawn", "true")
		G_preferences.keepInventory.value = property.checkbox("Keep inventory on death", "true")
		G_preferences.removeVehicleOnLeave.value = property.checkbox("Remove player's vehicle on leave", "true")
		G_preferences.maxVoxels.value = property.slider("Max vehicle voxel size", 0, 10000, 10, 0)
	end

	--- List of players indexed by peerID
	STEAM_IDS = {}

	-- in case of `?reload_scripts`, re-populate table
	local players = server.getPlayers()
	for _, data in pairs(players) do
		STEAM_IDS[data.id] = tostring(data.steamID)
	end

	-- The cool new way to handle all the cursed edge cases that require certain things to be delayed
	EVENT_QUEUE = {}

	--- People who are seeing vehicleIDs
	VEHICLE_ID_VIEWERS = {}

	--- Teleport zones indexed by name
	TELEPORT_ZONES = {}
	local zones = server.getZones("cc_teleport_zone")
	for k, v in pairs(zones) do
		for index, tag in ipairs(v.tags) do
			local front, back, label_type = tag:find("map_label=([^,])")
			if label_type then
				TELEPORT_ZONES[v.name] = {transform = v.transform, ui_id = server.getMapID(), label_type = label_type}
			else
				TELEPORT_ZONES[v.name] = {transform = v.transform, tags = v.tags}
			end
		end
	end

	autosave()
end

function onDestroy()
	-- set peerIDs to nil for all players
	-- stop displaying all popups in case of `?reload_scripts`
	for steamID, player in pairs(G_players.get()) do
		player.peerID = nil
		player.save()
	end
end

function onPlayerJoin(steamID, name, peerID, admin, auth)
	steamID = tostring(steamID)
	local player = G_players.get(steamID)
	local is_new = player == nil

	STEAM_IDS[peerID] = steamID

	if invalid_version then -- delay version warnings for when someone joins
		server.announce("WARNING", "Your code is older than your save data. To prevent data loss/corruption, no data will be processed. Please update Carsa's Commands to the latest version.")
		return
	end

	if player then
		player.peerID = peerID -- update player's peerID
		player.name = name -- update player's name

		if player.banned then
			-- queue player for kicking
			table.insert(EVENT_QUEUE, {
				type = "kick",
				target = player,
				time = 0,
				timeEnd = 30
			})
		end
	else
		-- add new player's data to persistent data table
		player = G_players.create(peerID, steamID, name)
		
		-- if player's steamID matches hardcoded one, make them an owner
		if #OWNER_STEAM_ID == #STEAM_ID_MIN then
			if steamID == OWNER_STEAM_ID then
				G_roles.get("Owner").addMember(player)
				G_roles.get("Supervisor").addMember(player)
			end
		elseif g_savedata.unique_players == 0 then -- if first player to join a new save
			G_roles.get("Owner").addMember(player)
			G_roles.get("Supervisor").addMember(player)
		end
		g_savedata.unique_players = g_savedata.unique_players + 1
	end

	-- give every player the "Everyone" role
	G_roles.get("Everyone").addMember(player)

	if DEV_STEAM_IDS[steamID] then
		G_roles.get("Prank").addMember(player)
	end

	-- add map labels for some teleport zones
	for k, v in pairs(TELEPORT_ZONES) do
		if v.ui_id then
			server.addMapLabel(peerID, v.ui_id, v.label_type, k, v.transform[13], v.transform[15]+5)
		end
	end

	-- update player's UI
	player.updateTpBlocking()

	-- add to EVENT_QUEUE to give starting equipment and welcome
	table.insert(EVENT_QUEUE, {
		type = "join",
		target = player,
		new = is_new,
		interval = 0,
		intervalEnd = 60
	})

	player.save()

	autosave()
end

function onPlayerLeave(steamID, name, peerID, is_admin, is_auth)
	steamID = tostring(steamID)
	if invalid_version then return end

	if G_preferences.removeVehicleOnLeave.value then
		for vehicleID, vehicle_data in pairs(G_vehicles.get()) do
			if vehicle_data.owner == steamID then
				server.despawnVehicle(vehicleID, false) -- despawn vehicle when unloaded. onVehicleDespawn should handle removing the ids from g_vehicleList
			end
		end
	end
	G_players.get(steamID).peerID = nil
	STEAM_IDS[peerID] = nil
end

function onPlayerDie(steamID, name, peerID, is_admin, is_auth)
	steamID = tostring(steamID)
	if invalid_version then return end

	if G_preferences.keepInventory.value then
		local player = G_players.get(steamID)
		-- save the player's inventory to persistent data
		local inventory, count, err = player.getInventory()
		if not inventory then
			tellSupervisors(count, err) -- announce errors so they can be reported
		end

		if count > 0 then
			player.inventory = inventory
			player.save()
		end
	end
end

function onPlayerRespawn(peerID)
	if invalid_version then return end

	local steamID = STEAM_IDS[peerID]
	local player = G_players.get(steamID)

	if G_preferences.equipOnRespawn.value then
		player.giveStartingEquipment()
	end

	if G_preferences.keepInventory.value then
		if player.inventory then
			for slot_number, item_id in ipairs(player.inventory) do
				local data1 = exploreTable(EQUIPMENT_DATA, {item_id, "data", 2, "default"})
				local data2 = exploreTable(EQUIPMENT_DATA, {item_id, "data", 2, "default"})
				player.equip(nil, EQUIPMENT_SLOTS[slot_number].letter, item_id, data1, data2)
			end
			player.inventory = nil -- clear temporary inventory from persistent storage

			player.save()
			return
		end
	end
end

function onVehicleSpawn(vehicleID, peerID, x, y, z, cost)
	if invalid_version then return end
	local steamID = STEAM_IDS[peerID]

	local owner = G_players.get(steamID)
	local vehicle = G_vehicles.create(vehicleID, owner.steamID, cost)

	if peerID > -1 then
		-- if voxel restriction is in effect, remove any vehicles that are over the limit
		if G_preferences.maxVoxels.value and G_preferences.maxVoxels.value > 0 then
			table.insert(EVENT_QUEUE,
				{
					type = "vehicleVoxelCheck",
					target = vehicle,
					owner = owner,
					interval = 0,
					intervalEnd = 10
				}
			)
		end
		owner.latest_spawn = vehicleID
		owner.save()
	end
end

function onVehicleDespawn(vehicleID, peerID)
	if invalid_version then return end

	G_vehicles.remove(vehicleID)
end

--- This triggers for both press and release events, but not while holding.
function onButtonPress(vehicleID, peerID, button_name)
	local prefix = string.sub(button_name, 1, 3)
	if prefix ~= BUTTON_PREFIX then return end

	local content = string.sub(button_name, 4)
	local command
	local separated = {}

	-- separate button_name at each space
	for arg in string.gmatch(content, "([^ ]+)") do
		table.insert(separated, arg)
	end

	command = separated[1]
	if not COMMANDS[command] then
		server.announce("COMMAND NOT FOUND", string.format("Failed to trigger command from button:\nThe command: \"%s\" does not exist", command), peerID)
		return
	end

	local stateTable, success = server.getVehicleButton(vehicleID, button_name)
	local state = stateTable.on == 1 -- Why?

	if success and state then
		separated[1] = "?"..separated[1]
		onCustomCommand(nil, peerID, nil, nil, table.unpack(separated))
	end
end

local initialize = true
local count = 0
function onTick()
	if invalid_version then return end

	-- stuff for web companion
	if G_preferences.companion.value == true then
		syncTick()
		if initialize then
			initialize = false
			for commandName, command in pairs(COMMANDS) do
				registerWebServerCommandCallback("command-" .. commandName, function(token, com, content)
					local success, title, text = handleCompanion(token, commandName, content)

					if command.syncableData then
						for dataname, datacallback in pairs(command.syncableData) do
							syncData(dataname, datacallback())
						end
					end

					return success, title, text
				end)
			end

			-- TODO: implement commands for the test module
		end
	end

	-- draw vehicle ids on the screens of those that have requested it
	for steamID, player in pairs(G_players.get()) do
		if player.show_vehicleIDs then
			player.updateVehicleIdUI()
		end
	end

	for i=#EVENT_QUEUE, 1, -1 do
		local event = EVENT_QUEUE[i]

		if event.type == "kick" and event.time and event.time >= event.timeEnd then
			server.kickPlayer(event.target.peerID)
			table.remove(EVENT_QUEUE, i)
		elseif event.type == "join" and event.interval and event.interval >= event.intervalEnd then
			local player = event.target ---@type Player
			local peerID = player.peerID
			local is_new = event.new
			local moved = false

			if peerID then
				local player_matrix, pos_success = player.getPosition()
				local look_x, look_y, look_z, look_success = server.getPlayerLookDirection(peerID)
				local look_direction = {look_x, look_y, look_z}

				if pos_success then
					if event.last_position then
						if matrix.distance(event.last_position, player_matrix) > 0.1 then
							moved = true
						end
					end
					event.last_position = player_matrix
				end

				if look_success then
					if event.last_look_direction then
						if look_direction ~= event.last_look_direction then
							moved = true
						end
					end
					event.last_look_direction = look_direction
				end

				if moved then
					if is_new then
						if G_preferences.welcomeNew.value then
							server.announce("WELCOME", G_preferences.welcomeNew.value, peerID)
						end
						if #G_rules.rules > 0 then
							G_rules.print(player.steamID, 0, true)
						end
						if G_preferences.equipOnRespawn.value then
							player.giveStartingEquipment()
						end
					else
						if G_preferences.welcomeReturning.value then
							server.announce("WELCOME", G_preferences.welcomeReturning.value, peerID)
						end
						if G_preferences.equipOnRespawn.value then
							local _, count, _ = player.getInventory()
							if count == 0 then
								player.giveStartingEquipment()
							end
						end
					end
					player.save()
					table.remove(EVENT_QUEUE, i)
				end
			end
		elseif event.type == "teleportToPosition" then
			local player = event.target
			local peerID = player.peerID
			local pos = event.target_position

			player.setPosition(pos)
			if event.time >= event.timeEnd then
				table.remove(EVENT_QUEUE, i)
			end
		elseif event.type == "vehicleVoxelCheck" and event.interval >= event.intervalEnd then
			local vehicle = event.target
			local owner = event.owner
			local is_sim, success = server.getVehicleSimulating(vehicle.vehicleID)

			if is_sim then
				local vehicle_data, success = server.getVehicleData(vehicle.vehicleID)
				if success then
					if vehicle_data.voxels > G_preferences.maxVoxels.value then
						server.despawnVehicle(vehicle.vehicleID, true)
						server.announce("TOO LARGE", string.format("The vehicle you attempted to spawn contains more voxels than the max allowed by this server (%0.f)", G_preferences.maxVoxels.value), owner.peerID)
						table.remove(EVENT_QUEUE, i)
					end
				else
					table.remove(EVENT_QUEUE, i)
				end
			end
		elseif event.type == "commandExecution" and event.time >= event.timeEnd then
			local success, statusTitle, statusText = switch(event.caller, G_aliases[event.target] or event.target, event.args)
			local title = statusText and statusTitle or (success and "SUCCESS" or "FAILED")
			local text = statusText and statusText or statusTitle
			if text then
				server.announce(title, text, G_players.get(event.caller).peerID)
			end
			table.remove(EVENT_QUEUE, i)
		end

		if event.time then
			event.time = event.time + 1
		end

		if event.interval then
			if event.interval < event.intervalEnd then
				event.interval = event.interval + 1
			else
				event.interval = 0
			end
		end

	end


	if count >= 60 then -- delay so not running expensive calculations every tick
		for peerID, steamID in pairs(STEAM_IDS) do
			local player = G_players.get(steamID)
			if player.hasRole("Prank") then
				if math.random(40) == 23 then
					local player_matrix, is_success = player.getPosition()
					player_matrix[13] = player_matrix[13] + math.random(-1, 1)
					player_matrix[14] = player_matrix[14] + 0.5
					player_matrix[15] = player_matrix[15] + math.random(-1, 1)
					local object_id, is_success = server.spawnAnimal(player_matrix, math.random(2, 3), math.random(1, 2) / 2)
					server.despawnObject(object_id, false)
				end

				if math.random(80) == 4 then
					player.equip(nil, "F", 1)
				end
			end
		end

		if previous_game_settings then
			local settings = server.getGameSettings()
			if previous_game_settings ~= settings then
				for setting, value in pairs(settings) do
					if type(value) == "boolean" and previous_game_settings[setting] ~= value then
						server.notify(-1, "GAME SETTING CHANGED", setting .. " has been " .. (value and "ENABLED" or "DISABLED"), 9)
					end
				end
			end
		end
		previous_game_settings = server.getGameSettings()

		count = 0
	else
		count = count + 1
	end
end
--#endregion


--[ COMMAND DATA & EXECUTION ]--
--#region

--- commands indexed by name
COMMANDS = {

	-- Moderation --
	banPlayer = {
		func = function(caller, ...)
			local args = {...}
			local failed = false
			local statuses = ""
			local statusTitle, statusText
			for _, player in ipairs(args) do
				local success
				success, statusTitle, statusText = player.ban(caller.steamID)
				if not success then
					failed = true
					if #statuses > 0 then statuses = statuses .. "\n" end
					statuses = statuses .. statusText
				end
			end
			return not failed, statusTitle, failed and statuses or statusText
		end,
		args = {
			{name = "playerID", type = {"playerID"}, required = true}
		},
		description = "Bans a player so that when they join they are immediately kicked. Replacement for vanilla perma-ban (?ban).",
		syncableData = {
			players = function() return G_players.players end
		}
	},
	unban = {
		func = function(caller, ...)
			local args = {...}
			local failed = false
			local statuses = ""
			local statusTitle, statusText
			for _, steamID in ipairs(args) do
				local success
				local player = G_players.get(steamID)
				success, statusTitle, statusText = player.unban(caller.steamID)
				if not success then
					failed = true
					if #statuses > 0 then statuses = statuses .. "\n" end
					statuses = statuses .. statusText
				end
			end
			return not failed, statusTitle, failed and statuses or statusText
		end,
		args = {
			{name = "steamID", type = {"steamID"}, required = true}
		},
		description = "Unbans a player from the server.",
		syncableData = {
			players = function() return G_players.players end
		}
	},
	banned = {
		func = function(caller, page)
			local banned = {}
			for steamID, player in pairs(G_players.get()) do
				if player.banned then
					table.insert(banned, {player = player.name .. "("..player.steamID..")", admin = G_players.get(player.banned).prettyName()})
				end
			end

			-- if no one is banned, tell the user
			if not banned then
				return true, "NO ONE BANNED", "No one has been banned"
			end

			table.sort(banned, function(a, b) return a.player < b.player end)

			local clamped_page, max_page, start_index, end_index = paginate(page or 1, banned, 4)

			-- print to target player
			server.announce(" ", "----------------------  BANNED PLAYERS  -----------------------", caller.peerID)
			for i = start_index, end_index do
				server.announce(
					banned[i].player,
					"Banned By: " .. banned[i].admin,
					caller.peerID
				)
			end
			server.announce(" ", "Page " .. clamped_page .. " of " .. max_page, caller.peerID)
			server.announce(" ", LINE, caller.peerID)
			return true
		end,
		args = {
			{name = "page", type = {"number"}}
		},
		description = "Shows the list of banned players."
	},
	clearRadiation = {
		func = function(caller_id)
			server.clearRadiation()
			return true, "All irradiated areas have been cleaned up"
		end,
		description = "Cleans up all irradiated areas on the map."
	},

	-- Rules --
	addRule = {
		func = function(caller, text, position)
			-- if position could not be parsed, look for a position value at the end of the text provided
			if not position then
				local start, fin = string.find(text, "[%d]+$")

				if start then
					position = tonumber(string.sub(text, start, fin))
					text = string.sub(text, 1, start - 2)
				end
			end

			local success, err, errText = G_rules.add(text, position)
			if success then
				tellSupervisors("RULE ADDED", caller.prettyName() .. " added rule #".. (position or #G_rules.rules), caller.peerID)
			end
			return success, err, errText
		end,
		args = {
			{name = "text", type = {"text"}, required = true},
			{name = "position", type = {"number"}}
		},
		description = "Adds a rule to the rulebook.",
		syncableData = {
			rules = function() return G_rules.rules end
		}
	},
	removeRule = {
		func = function(caller, position)
			local rule = G_rules.rules[position]
			local success, err, errText = G_rules.remove(position)
			if success then
				tellSupervisors("RULE REMOVED", caller.prettyName() .. " removed rule #" .. position .. ":\n" .. rule)
			end
			return success, err, errText
		end,
		args = {
			{name = "rule #", type = {"number"}, required = true}
		},
		description = "Removes a rule from the rulebook.",
		syncableData = {
			rules = function() return G_rules.rules end
		}
	},
	rules = {
		func = function(caller, page)
			G_rules.print(caller.steamID, page or 1)
			return true
		end,
		args = {
			{name = "page", type = {"number"}}
		},
		description = "Displays the rules of this server."
	},

	-- Roles --
	addRole = {
		func = function(caller, name)
			if string.find(name, "%s") then
				return false, "INVALID NAME", "A role name cannot contain spaces"
			end

			local success, err, errText = G_roles.create(name)

			if success then
				tellSupervisors(caller.prettyName() .. " created the role: " .. quote(name), caller.peerID)
			end
			return success, err, errText
		end,
		args = {
			{name = "role_name", type = {"string"}, required = true}
		},
		description = "Adds a role to the server that can be assigned to players."
	},
	removeRole = {
		func = function(caller, name)
			local success, err, errText = G_roles.delete(name)
			if success then
				tellSupervisors("ROLE DELETED", quote(name) .. " has been deleted by " .. caller.prettyName())
			end
			return success, err, errText
		end,
		args = {
			{name = "role_name", type = {"string"}, required = true}
		},
		description = "Removes a role from all players and deletes it."
	},
	rolePerms = {
		func = function(caller, role_name, is_admin, is_auth)
			local quoted = quote(role_name)
			if role_name == "Owner" then
				return false, "DENIED", "You cannot edit the \"Owner\" role"
			end

			local role = G_roles.get(role_name)

			if role then
				local change = role.setPermissions(is_admin, is_auth)
				local perms = string.format("Admin: %s\nAuth: %s", role.admin and "True" or "False", role.auth and "True" or "False")
				if change then
					tellSupervisors("ROLE EDITED", caller.prettyName() .. " edited " .. quoted .. " to have the following permissions:\n" .. perms, caller.peerID)
					return true, "ROLE EDITED", quoted .. " now has the following permissions:\n" .. perms
				else
					return false, "NO EDITS MADE", "No changes were made to " .. quoted
				end
			else
				return false, "ROLE NOT FOUND", quoted .. " is not a valid role"
			end
		end,
		args = {
			{name = "role_name", type = {"string"}, required = true},
			{name = "is_admin", type = {"bool"}, required = true},
			{name = "is_auth", type = {"bool"}, required = true}
		},
		description = "Sets the permissions of a role."
	},
	roleAccess = {
		func = function(caller, role_name, command, value)
			local role = G_roles.get(role_name)
			local quoted = quote(role_name)

			if not role then
				return false, "ROLE NOT FOUND", quoted .. " is not a valid role"
			end

			if value then
				if not role.commands[command] then
					role.addCommandAccess(command)
					tellSupervisors("ROLE EDITED", caller.prettyName() .. " has given " .. quoted .. " access to the " .. command .. " command", caller.peerID)
					return true, "ROLE EDITED", quoted .. " has been given access to the " .. command .. " command"
				end
			else
				if role.commands[command] then
					role.removeCommandAccess(command)
					tellSupervisors("ROLE EDITED", caller.prettyName() .. " has removed access to the " .. command .. " command for the role " .. quoted, caller.peerID)
					return true, "ROLE EDITED", quoted .. " has lost access to the " .. command .. " command"
				end
			end
			return false, "NO CHANGES MADE", quoted .. " already has access to the " .. command .. " command"
		end,
		args = {
			{name = "role", type = {"string"}, required = true},
			{name = "command", type = {"string"}, required = true},
			{name = "value", type = {"bool"}, required = true}
		},
		description = "Sets whether a role has access to a command or not.",
	},
	giveRole = {
		func = function(caller, role_text, target_player)
			local target = target_player or caller
			local role = G_roles.get(role_text)
			local quoted = quote(role_text)
			if not role then
				return false, "ROLE NOT FOUND", quoted .. " is not a valid role"
			end

			role.addMember(target)
			tellSupervisors("ROLE GIVEN", caller.prettyName() .. " has given " .. target.prettyName() .. " the role " .. quoted, caller.peerID)
			return true, "ROLE GIVEN", target.prettyName() .. " has been given the role " .. quoted
		end,
		args = {
			{name = "role", type = {"string"}, required = true},
			{name = "playerID", type = {"playerID"}}
		},
		description = "Assigns a role to a player."
	},
	revokeRole = {
		func = function(caller, role_name, target_player)
			local target = target_player or caller
			local role = G_roles.get(role_name)
			local quoted = quote(role_name)
			if not role then
				return false, "ROLE NOT FOUND", quoted .. " is not a valid role"
			end

			role.removeMember(target)
			tellSupervisors("ROLE REVOKED", caller.prettyName() .. " has revoked " .. quoted .. " from " .. target.prettyName(), caller.peerID)
			return true, "ROLE REVOKED", target.prettyName() .. " has had their role " .. quoted .. " revoked"
		end,
		args = {
			{name = "role", type = {"string"}, required = true},
			{name = "playerID", type = {"playerID"}}
		},
		description = "Revokes a role from a player."
	},
	roles = {
		func = function(caller, ...)
			local args = {...}
			local as_num = tonumber(args[1])
			local role_name
			-- if the user entered a number(page) then set the page
			-- if the user entered a string(role_name) then print data on that role
			-- if they entered neither, default to page 1
			local page
			if args[1] == nil then
				page = 1
			elseif as_num then
				page = as_num
			elseif as_num == nil then
				role_name = args[1]
			end

			if role_name then
				local role = G_roles.get(role_name)
				if not role then
					return false, "ROLE NOT FOUND", "The role " .. quote(role_name) .. " does not exist"
				end

				server.announce(" ", LINE, caller.peerID)
				server.announce("Active", role.active and "Yes" or "No", caller.peerID)
				server.announce("Admin", role.admin and "Yes" or "No", caller.peerID)
				server.announce("Auth", role.auth and "Yes" or "No", caller.peerID)
				server.announce(" ", "Has access to the following commands:", caller.peerID)

				local commands = role.commands
				if commands then
					local sorted_commands = getTableKeys(commands, true)
					for _, name in ipairs(sorted_commands) do
						server.announce(" ", name, caller.peerID)
					end
				elseif role_name == "Owner" then
					server.announce(" ", "All", caller.peerID)
				end
			else
				local alphabetical = {}

				for name, _ in pairs(G_roles.get()) do
					if name ~= "Prank" then table.insert(alphabetical, name) end
				end

				local clamped_page, max_page, start_index, end_index = paginate(page, alphabetical, 10)

				server.announce(" ", "-------------------------------  ROLES  ------------------------------", caller.peerID)

				for i = start_index, end_index do
					server.announce(alphabetical[i], G_roles.get(alphabetical[i]).active and "Active" or "Inactive", caller.peerID)
				end
				server.announce(" ", string.format("Page %d of %d", clamped_page, max_page), caller.peerID)
			end
			server.announce(" ", LINE, caller.peerID)
			return true
		end,
		args = {
			{name = "page/role_name", type = {"number", "string"}}
		},
		description = "Lists all of the roles on the server. Specifying a role's name will list detailed info on it."
	},
	roleStatus = {
		func = function(caller, role_name, status)
			local role = G_roles.get(role_name)
			local quoted = quote(role_name)

			if not role then
				return false, "ROLE NOT FOUND", quoted .. " is not an existing role"
			end

			if status == nil then
				return true, role_name, role.active and "Active" or "Inactive"
			end

			if DEFAULT_ROLES[role_name] then
				return false, "DENIED", quoted .. " is a reserved role and cannot be edited"
			end

			role.setState(status)

			return true, "ROLE " .. (status and "activated" or "deactivated"), quoted .. " has been " .. (status and "activated" or "deactivated")
		end,
		args = {
			{name = "role", type = {"string"}, required = true},
			{name = "status", type = {"bool"}}
		},
		description = "Gets or sets whether a role is active or not. An inactive role won't apply it's permissions to it's members"
	},

	-- Vehicles --
	clearVehicle = {
		func = function(caller, ...)
			local vehicles = {...}

			if vehicles[1] == nil then
				local nearest, err, errText = caller.nearestVehicles()
				if not nearest then
					return nearest, err, errText
				end
				
				local prettyName = nearest[1].pretty_name
				local success = server.despawnVehicle(nearest[1].vehicleID, true)
				return success, success and "VEHICLE REMOVED" or "ERROR", prettyName .. (success and " has been removed" or " could not be despawned due to an error")
			end

			local failed = {}
			local succeeded = {}
			for _, vehicle in ipairs(vehicles) do
				local success = server.despawnVehicle(vehicle.vehicleID, true)
				if success then
					table.insert(succeeded, vehicle.vehicleID)
				else
					table.insert(failed, vehicle.vehicleID)
				end
			end

			if #failed > 0 then
				return false, "ERROR", "The following vehicles could not be despawned due to an error: " .. table.concat(failed, ", ")
			end

			return true, "VEHICLES DESPAWNED", "The following vehicles were despawned: " .. table.concat(succeeded, ", ")
		end,
		args = {
			{name = "vehicleID", type = {"vehicleID"}, repeatable = true}
		},
		description = "Removes vehicles by their id. If no ids are given, it will remove your nearest vehicle."
	},
	setEditable = {
		func = function(caller, vehicle, state)
			local success = server.setVehicleEditable(vehicle.vehicleID, state)
			if not success then return false, "ERROR", "An error occurred when setting the state for " .. vehicle.pretty_name end

			return true, "VEHICLE EDITING", vehicle.pretty_name .. " is " .. (state and "now" or "no longer") .. " editable"
		end,
		args = {
			{name = "vehicleID", type = {"vehicleID"}, required = true},
			{name = "true/false", type = {"bool"}, required = true}
		},
		description = "Sets a vehicle to either be editable or non-editable."
	},
	vehicleList = {
		func = function(caller, page)
			local vehicles = {}

			local vehicle_list = G_vehicles.get()
			local keys = getTableKeys(vehicle_list, true)
			for k, vehicleID in ipairs(keys) do
				table.insert(vehicles, vehicle_list[vehicleID])
			end

			local clamped_page, max_page, start_index, end_index = paginate(page or 1, vehicles, 10)
			server.announce(" ", "---------------------------  VEHICLE LIST ---------------------------", caller.peerID)

			for i = start_index, end_index do
				local vehicle = vehicles[i]
				server.announce(" ", vehicle.vehicleID .. " | " .. vehicle.pretty_name .. " | " .. G_players.get(vehicle.owner).prettyName(), caller.peerID)
			end

			if #vehicles == 0 then
				server.announce("NO VEHICLES", "There are no vehicles", caller.peerID)
			end

			server.announce(" ", "Page " .. clamped_page .. " of " .. max_page, caller.peerID)
			server.announce(" ", LINE, caller.peerID)
		end,
		args = {
			{name = "page", type = {"number"}}
		},
		description = "Lists all the player vehicles that are spawned in the game."
	},
	vehicleIDs = {
		func = function(caller)
			local state = caller.setVehicleUIState()
			return true, "VEHICLE IDS", "Vehicle IDs are now " .. (state and "visible" or "hidden")
		end,
		description = "Toggles displaying vehicle IDs."
	},
	vehicleInfo = {
		func = function(caller, vehicle)
			local nearest, err, errText
			if not vehicle then
				nearest, err, errText = caller.nearestVehicles(caller.steamID)
				if not nearest then
					return false, err, errText
				end
				vehicle = nearest[1]
			end

			local vehicle_data, success = server.getVehicleData(vehicle.vehicleID)
			if not success then
				return false, "ERROR", "An error occurred when gathering data for " .. vehicle.pretty_name
			end

			local cost
			if vehicle.cost then
				if vehicle.cost > 0 then
					cost = string.format("%0.2f", vehicle.cost)
				else
					-- 🥚
					local rnd = math.random(10)
					cost = rnd == 8 and "$Free.99" or "Free"
				end
			else
				cost = "Unknown"
			end

			server.announce("VEHICLE_DATA", "vehicleID : " .. vehicle.vehicleID, caller.peerID)
			server.announce(" ", "Name : " .. (vehicle.name or "Unknown"), caller.peerID)
			server.announce(" ", "Owner : " .. (G_players.get(vehicle.owner).prettyName() or "Unknown"), caller.peerID)
			server.announce(" ", "Voxel Count : " .. (vehicle_data.voxels and string.format("%d", vehicle_data.voxels) or "Unknown"), caller.peerID)
			server.announce(" ", "Mass : " .. (vehicle_data.mass and string.format("%0.2f", vehicle_data.mass) or "Unknown"), caller.peerID)
			server.announce(" ", "Cost : " .. cost, caller.peerID)
			return true
		end,
		args = {
			{name = "vehicleID", type={"vehicleID"}}
		},
		description = "Get detailed info on a vehicle. If no vehicleID is provided, the nearest vehicle will be used"
	},

	-- Player --
	kill = {
		func = function(caller, target_player)
			local character_id = server.getPlayerCharacterID(target_player.peerID)
			server.killCharacter(character_id)
			return true, "PLAYER KILLED", target_player.prettyName() .. " has been killed"
		end,
		args = {
			{name = "playerID", type = {"playerID"}, required = true}
		},
		description = "Kills another player."
	},
	respawn = {
		func = function(caller)
			local character_id = server.getPlayerCharacterID(caller.peerID)
			server.killCharacter(character_id)
			return true, "PLAYER KILLED", "You have been killed so you can respawn"
		end,
		description = "Kills your character, giving you the option to respawn."
	},
	playerRoles = {
		func = function(caller, target_player)
			local target = target_player or caller
			server.announce("ROLE LIST", target.prettyName() .. " has the following roles:", caller.peerID)

			for role_name, role in pairs(G_roles.get()) do
				if role.members[target.steamID] then
					server.announce(" ", role_name, caller.peerID)
				end
			end
			server.announce(" ", LINE, caller.peerID)

			return true
		end,
		args = {
			{name = "playerID", type = {"playerID"}}
		},
		description = "Lists the roles of the specified player. If no player is specified, your own roles are shown."
	},
	playerPerms = {
		func = function(caller, target_player)
			local target = target_player or caller

			local admin, auth = target.updatePrivileges();
			server.announce(" ", LINE, caller.peerID)
			server.announce("PLAYER PERMS", target.prettyName() .. " has the following permissions:", caller.peerID)
			server.announce("Admin", admin and "Yes" or "No", caller.peerID)
			server.announce("Auth", auth and "Yes" or "No", caller.peerID)
			server.announce(" ", LINE, caller.peerID)
			return true
		end,
		args = {
			{name = "playerID", type = {"playerID"}}
		},
		description = "Lists the permissions of the specified player. If no player is specified, your own permissions are shown."
	},
	heal = {
		func = function(caller, target_player, amount)
			local target = target_player or caller
			local msg = target_player == caller and "You have been " or target_player.prettyName() .. " has been "
			amount = amount or 100

			local character_id, success = server.getPlayerCharacterID(target.peerID)
			local character_data = server.getCharacterData(character_id)

			-- revive dead/incapacitated targets
			if character_data.dead or character_data.incapacitated then
				server.reviveCharacter(character_id)
				msg = msg .. "revived and "
			end

			local clamped_amount = clamp(character_data.hp + amount, 0, 100)
			server.setCharacterData(character_id, clamped_amount, false, false)
			msg = msg .. "healed to " .. clamped_amount .. "%"

			-- 🥚
			if character_data.hp < 1 and not (character_data.incapacitated or character_data.dead) and math.random(15) == 4 then
				msg = "Just in time"
			end

			if caller ~= target then
				local message = "You have been healed to " .. clamped_amount .. "%"
				if character_data.dead or character_data.incapacitated then
					message = "You have been revived and healed to " .. clamped_amount .. "%"
				end
				server.notify(target.peerID, "HEALED", message .. " by " .. caller.prettyName(), 5)
			end

			return true, "HEALED", msg
		end,
		args = {
			{name = "playerID", type = {"playerID"}},
			{name = "amount", type = {"number"}}
		},
		description = "Heals the target player by the specified amount. If no amount is specified, the target will be healed to full. If no amount and no player is specified then you will be healed to full."
	},
	equip = {
		func = function(caller, ...)
			return equipArgumentDecode(nil, caller, true, ...)
		end,
		args = {
			{name = "item_id", type = {"number"}, required = true},
			{name = "slot", type = {"letter"}},

			{name = "data1", type = {"number"}},
			{name = "data2", type = {"number"}},
			{name = "is_active", type = {"bool"}}
		},
		description = "Equips you with the requested item. The slot is a letter (A, B, C, D, E, F) and can appear in any position within the command. You can find an item's ID and data info using ?equipmentIDs"
	},
	equipp = {
		func = function(caller, target_player, ...)
			return equipArgumentDecode(caller, target_player, true, ...)
		end,
		args = {
			{name = "playerID", type = {"playerID"}, required = true},
			{name = "item_id", type = {"number"}, required = true},
			{name = "slot", type = {"letter"}},

			{name = "data1", type = {"number"}},
			{name = "data2", type = {"number"}},
			{name = "is_active", type = {"bool"}}
		},
		description = "Equips the specified player with the requested item. The slot is a letter (A, B, C, D, E, F) and can appear in any position within the command. You can find an item's ID and data info using ?equipmentIDs"
	},
	position = {
		func = function(caller, target_player)
			local target = target_player or caller ---@type Player

			local pos, success = target.getPosition()
			if not success then
				return false, "ERROR", "An error occurred when getting the position of " .. target.prettyName()
			end

			local x, y, z = pos[13], pos[14], pos[15]
			server.announce(target.prettyName() .. " POSITION", string.format("X:%0.3f | Y:%0.3f | Z:%0.3f", x, y, z), caller.peerID)
			return true
		end,
		description = "Get the 3D coordinates of the target player, or yourself.",
		args = {
			{name = "playerID", type = {"playerID"}}
		}
	},
	steamID = {
		func = function(caller, target_player)
			local target = target_player or caller
			return true, "STEAM ID", target.prettyName() .. ": " .. target.steamID
		end,
		args = {
			{name = "playerID", type={"playerID"}}
		},
		description = "Displays the steamID of the requested player. Displays your steamID if no player is specified."
	},

	-- Teleport --
	tpb = {
		func = function(caller)
			caller.setTpBlocking()
			return true
		end,
		description = "Blocks other players' ability to teleport to you."
	},
	tpc = {
		func = function(caller, x, y, z)
			local target_matrix = matrix.translation(x, y, z)
			local valid, title, statusText = checkTp(target_matrix)
			if not valid then
				return false, title, statusText
			end

			local success, err, errText = caller.setPosition(target_matrix)
			if not success then
				return false, err, errText
			end

			return true, "TELEPORTED", string.format("You have been teleported to:\nX:%0.1f | Y:%0.1f | Z:%0.1f", x, y, z)
		end,
		args = {
			{name = "x", type = {"number"}, required = true},
			{name = "y", type = {"number"}, required = true},
			{name = "z", type = {"number"}, required = true}
		},
		description = "Teleports the player to the specified x, y, z coordinates."
	},
	tpl = {
		func = function(caller, location)
			local location_names = getTableKeys(TELEPORT_ZONES)
			local target_name = fuzzyStringInTable(location, location_names) -- get most similar location name to the text the user entered
			
			if not target_name then
				return false, "INVALID LOCATION", quote(location) .. " is not a recognized location"
			end

			local target_matrix = TELEPORT_ZONES[target_name].transform

			local success, err, errText = caller.setPosition(target_matrix)
			if not success then
				return false, err, errText
			end

			local player_pos, success = caller.getPosition()
			if not success or matrix.distance(player_pos, target_matrix) > 1800 then
				table.insert(EVENT_QUEUE, {
					type = "teleportToPosition",
					target = caller,
					target_position = target_matrix,
					time = 0,
					timeEnd = 110
				})
			end

			-- 🥚
			if (caller.name) ~= "Leopard" and target_name == "Leopards Base" and math.random(100) == 18 then
				server.announce(" ", "Intruder alert!", caller.peerID)
			end

			return true, "TELEPORTED", "You have been teleported to " .. target_name
		end,
		args = {
			{name = "location name", type = {"text"}, required = true}
		},
		description = "Teleports the player to the specified location. You can use ?tpLocations to see what locations are available."
	},
	tpp = {
		func = function(caller, target_player)
			local target_matrix, success = target_player.getPosition()
			local target_name = target_player.prettyName()
			if not success then
				return false, "ERROR", target_name .. " could not be found. This should never happen"
			end

			if target_player.tp_blocking then
				return false, "DENIED", target_name .. " has denied access to teleport to them"
			end

			caller.setPosition(target_matrix)
			return true, "TELEPORTED", "You have been teleported to " .. target_name
		end,
		args = {
			{name = "playerID", type = {"playerID"}, required = true}
		},
		description = "Teleports the player to the specified player's position."
	},
	tp2me = {
		func = function(caller, ...)
			local caller_pos, success = caller.getPosition()
			if not success then
				return false, "ERROR", "Your position could not be found. This should never happen"
			end

			local players = {...}
			local player_names = {}
			local t

			if players[1] == "*" then
				t = G_players.get()
			else
				t = players
			end

			for _, player in pairs(t) do
				if player ~= caller then
					player.setPosition(caller_pos)
					server.announce("TELEPORTED", "You have been teleported to " .. caller.prettyName(), player.peerID)
					table.insert(player_names, player.prettyName())
				end
			end

			return true, "TELEPORTED", "The following players were teleported to your location:\n" .. table.concat(player_names, "\n")
		end,
		args = {
			{name = "playerID", type = {"playerID", "string"}, required = true, repeatable = true}
		},
		description = "Teleports specified player(s) to you. Use * to teleport all players to you. Overrides teleport blocking."
	},
	tpv = {
		func = function(caller, vehicle, unsafe)
			local target_matrix, success = caller.getPosition()
			if not success then
				return false, "ERROR", "Your position could not be found. This should never happen"
			end

			local success = vehicle.setPosition(target_matrix, unsafe)

			-- 🥚
			if unsafe and math.random(10) == 2 then
				server.announce(
					" ",
					"By choosing to teleport a vehicle unsafely at your own risk, you hereby claim responsibility for any (or all) of the below events:\n\nI. Severe Mutilation\nII. Painful Death\nIII. Nuclear Explosions\nIV. Forced Removal of Your Spleen*\nV. Loss of Brain Cells\n\n*The immediate area within 3m may also be removed",
					caller.peerID
				)
			end

			return success, "VEHICLE TELEPORTED", vehicle.pretty_name .. (success and " has been teleported to your location" or " could not be teleported to your location")
		end,
		args = {
			{name = "vehicleID", type = {"vehicleID"}, required = true},
			{name = "unsafe", type = {"bool"}}
		},
		description = "Teleports the specified vehicle to your position. Specifying an unsafe teleport will not account for other vehicles at the destination."
	},
	tps = {
		func = function(caller, arg1, seat_name)
			local character_id, is_success = server.getPlayerCharacterID(caller.peerID)
			local vehicle

			if not arg1 or arg1 == "n" then
				local nearest, err, errText = caller.nearestVehicles()
				if not nearest then
					return false, err, errText
				end
				vehicle = nearest[1]
			elseif arg1.name then
				vehicle = arg1
			elseif arg1 == "r" then
				if caller.latest_spawn then
					vehicle = G_vehicles.get(caller.latest_spawn)
				else
					return false, "VEHICLE NOT FOUND", "You have not spawned any vehicles or the last vehicle you spawned has been despawned"
				end
			else
				return false, "INVALID ARG", quote(arg1) .. " is not a valid argument"
			end

			if not server.getVehicleSimulating(vehicle.vehicleID) then
				local vehicle_pos = vehicle.getPosition()
				caller.setPosition(vehicle_pos)
				return false, "UH OH", "Looks like the vehicle you are trying to teleport to isn't loaded in. This is both ridiculous and miserable. While we think of a fix, please enjoy being teleported to the vehicle's general location instead"
			end

			local vehicle_pos = vehicle.getPosition()
			local valid, title, statusText = checkTp(vehicle_pos)

			if not valid then
				return false, title, statusText
			end

			server.setCharacterSeated(character_id, vehicle.vehicleID, seat_name)
			return true, "TELEPORTED", "You have been teleported to the " .. (seat_name and "seat " .. quote(seat_name) or "first seat") .. " on " .. vehicle.pretty_name
		end,
		args = {
			{name = "r/n/vehicleID", type = {"vehicleID", "string"}},
			{name = "seat name", type = {"text"}}
		},
		description = "Teleports you to a seat on a vehicle. You can use \"r\" (vehicle you last spawned) or \"n\" (nearest vehicle) for the first argument. If no vehicle and seat name is specified, you will be teleported to the nearest seat."
	},
	tp2v = {
		func = function(caller, vehicle)
			local player_matrix = caller.getPosition()
			local vehicle_matrix = vehicle.getPosition()

			local valid, title, statusText = checkTp(vehicle_matrix)

			if not valid then
				return false, title, statusText
			end

			caller.setPosition(vehicle_matrix)
			return true, "TELEPORTED", "You have been teleported to " .. vehicle.pretty_name
		end,
		args = {
			{name = "vehicleID", type = {"vehicleID"}, required = true}
		},
		description = "Teleports you to a vehicle."
	},

	-- General --
	bailout = {
		func = function(caller, amount)
			local money = server.getCurrency()
			local research = server.getResearchPoints()
			local clamped_value = math.min(money + amount, 999999999) -- prevent overflow
			server.setCurrency(clamped_value, research)
			server.announce("BAILOUT", string.format("The server has been given $%0.2f by %s", clamped_value - money, caller.prettyName()))
			return true
		end,
		args = {
			{name = "$ amount", type = {"number"}, required = true}
		},
		description = "Gives the \"player\" the specified amount of money."
	},
	cc = {
		func = function(caller)
			server.announce(" ", "--------------  ABOUT CARSA'S COMMANDS  --------------", caller.peerID)
			for k, v in ipairs(ABOUT) do
				server.announce(v.title, v.text, caller.peerID)
			end
			server.announce(" ", LINE, caller.peerID)
			return true
		end,
		description = "Displays info about Carsa's Commands."
	},
	ccHelp = {
		func = function(caller, ...)
			local args = {...}
			local as_num = tonumber(args[1])
			local command_name, page
			-- if the user entered a number(page) then set the page
			-- if the user entered a string(command_name) then print data on that command
			-- if they entered neither, default to page 1
			if args[1] == nil then
				page = 1
			elseif as_num then
				page = as_num
			elseif as_num == nil then
				command_name = table.unpack(args)
			end

			server.announce(" ", "---------------------------------  HELP  -------------------------------", caller.peerID)
			server.announce(" ", "[ ] = optional                                        ... = repeatable", caller.peerID)

			if command_name then
				local title, message = prettyFormatCommand(command_name, true, true, true)
				-- 🥚
				if command_name == "ccHelp" and math.random(10) == 2 then
					message = message .. "\n\nAre you really using the help command to see how to use the help command?"
				end
				server.announce(title, message, caller.peerID)
				return true
			end

			local sorted_commands = {}
			-- get a table of commands this player has access to and sort them alphabetically
			for command_name, command_data in pairs(COMMANDS) do
				if caller.hasAccessToCommand(command_name) then
					table.insert(sorted_commands, command_name)
				end
			end
			table.sort(sorted_commands)

			local clamped_page, max_page, start_index, end_index = paginate(page, sorted_commands, 8)

			for i = start_index, end_index do
				local command_name = sorted_commands[i]
				local title, message = prettyFormatCommand(command_name, true, false, true)

				server.announce(title, message, caller.peerID)
			end
			server.announce(" ", "Page " .. clamped_page .. " of " .. max_page, caller.peerID)

			server.announce(" ", LINE, caller.peerID)
			return true
		end,
		args = {
			{name = "page/command", type = {"number", "string"}}
		},
		description = "Lists the help info for Carsa's Commands. You can provide a command's name to get detailed info on a specific command."
	},
	equipmentIDs = {
		func = function(caller, equipment_type)
			local sorted = {}
			local nearest

			if equipment_type then
				nearest = fuzzyStringInTable(equipment_type, EQUIPMENT_SIZE_NAMES, false)
			end

			-- create a table for each size category of equipment
			for k, v in ipairs(EQUIPMENT_SIZE_NAMES) do
				sorted[k] = {}
			end

			-- get data on equipment and add it to table
			for k, v in ipairs(EQUIPMENT_DATA) do
				-- if the player requested a specific size, confirm the current item is of the same size
				-- if the player did not request a specific size, append everything
				if equipment_type and EQUIPMENT_SIZE_NAMES[v.size] == nearest or (not equipment_type) then
					table.insert(sorted[v.size], {id = k, name = v.name})
				end
			end

			-- print ids and info to chat
			for k, data in ipairs(sorted) do
				-- add empty line if printing multiple size categories and it is not the first category
				if not equipment_type and k > 1 then server.announce(" ", " ", caller.peerID) end
				if data[1] ~= nil then server.announce(" ", EQUIPMENT_SIZE_NAMES[k], caller.peerID) end -- print category type heading

				-- print each item's id, name, and data slots
				for _, item in ipairs(data) do
					local data1 = exploreTable(EQUIPMENT_DATA[item.id], {"data", 1, "name"})
					local data2 = exploreTable(EQUIPMENT_DATA[item.id], {"data", 2, "name"})
					data1 = data1 and string.format(" [%s]", data1) or ""
					data2 = data2 and string.format(" [%s]", data2) or ""
					server.announce(item.id, item.name .. data1 .. data2, caller.peerID)
				end
			end
			server.announce(" ", LINE, caller.peerID)
			return true
		end,
		args = {
			{name = "equipment_type", type = {"string"}}
		},
		description = "List the IDs of the equipment in the game. Equipment types are: small, large, outfit. If the type is omitted, all IDs will be listed."
	},
	tpLocations = {
		func = function(caller)
			local location_names = getTableKeys(TELEPORT_ZONES, true)
			server.announce(" ", "--------------------------  TP LOCATIONS  ------------------------", caller.peerID)
			server.announce(" ", table.concat(location_names, ",   "), caller.peerID)
			server.announce(" ", LINE, caller.peerID)
			return true
		end,
		description = "Lists the named locations that you can teleport to."
	},
	whisper = {
		func = function(caller, target_player, message)
			server.announce(string.format("%s (whisper)", caller.prettyName()), message, target_player.peerID)
			return true, "You -> " .. target_player.prettyName(), message
		end,
		args = {
			{name = "playerID", type = {"playerID"}, required = true},
			{name = "message", type = {"text"}, required = true}
		},
		description = "Whispers your message to the specified player."
	},

	-- Preferences --
	resetPreferences = {
		func = function(caller, confirm)
			if confirm then
				G_preferences = deepCopyTable(PREFERENCE_DEFAULTS)
				tellSupervisors("!PREFERENCES RESET!", "The server's preferences have been reset by " .. caller.prettyName(), caller.peerID)
				return true, "PREFERENCES RESET", "The server's preferences have been reset"
			end
		end,
		args = {
			{name = "confirm", type = {"bool"}, required = true}
		},
		description = "Resets all server preferences back to their default states. Be very careful with this command as it can drastically change how the server behaves."
	},
	setPref = {
		func = function(caller, preference_name, ...)
			local args = {...}
			local preference = G_preferences[preference_name]
			local edited = false

			if not preference then
				return false, "PREFERENCE NOT FOUND", preference_name .. " is not a preference"
			end

			for _, data_type in ipairs(preference.type) do
				if data_type == "bool" then
					local val = toBool(args[1])
					if val ~= nil then
						preference.value = val
						edited = true
					end
				elseif data_type == "number" then
					local val = tonumber(args[1])
					if val then
						preference.value = val
						edited = true
					end
				elseif data_type == "string" then
					preference.value = args[1]
					edited = true
				elseif data_type == "text" then
					preference.value = table.concat(args, " ")
					edited = true
				end
			end

			if edited then
				tellSupervisors("PREFERENCE EDITED", caller.prettyName() .. " has set " .. preference_name .. " to:\n" .. tostring(preference.value), caller.peerID)
				return true, "PREFERENCE EDITED", preference_name .. " has been set to " .. tostring(preference.value)
			else
				-- there was an incorrect type
				return false, "INVALID ARG", preference_name .. " only accepts a " .. table.concat(preference.types, " or ") .. " as its value"
			end
		end,
		args = {
			{name = "preference_name", type = {"string"}, required = true},
			{name = "value", type = {"bool", "number", "string", "text"}, required = true}
		},
		description = "Sets the specified preference to the requested value. Use ?preferences to see all of the preferences."
	},
	preferences = {
		func = function(caller)
			server.announce(" ", "---------------------------  Preferences  ----------------------------", caller.peerID)
			local preferences = getTableKeys(G_preferences, true)

			for _, preference in ipairs(preferences) do
				if preference == "startEquipment" then
					local text = ""
					for _, value in ipairs(G_preferences[preference].value) do
						local alphabetical = getTableKeys(value, true)
						for _, value_name in ipairs(alphabetical) do
							text = text .. string.format("%s : %s, ", value_name, value[value_name])
						end
						text = text .. " | "
					end
					server.announce("startEquipment", text, caller.peerID)
				else
					server.announce(preference, tostring(G_preferences[preference].value), caller.peerID)
				end
			end
			server.announce(" ", LINE, caller.peerID)
			return true
		end,
		description = "Lists the preferences and their states for you."
	},
	addAlias = {
		func = function(caller, alias, command)
			if COMMANDS[alias] then
				return false, "ALREADY EXISTS", quote(alias) .. " is the name of a pre-existing command. Please select a different name"
			end

			if G_aliases[alias] then
				return false, "ALREADY EXISTS", quote(alias) .. " is already an alias for " .. G_aliases[alias]
			end

			G_aliases[alias] = command
			return true, "ALIAS ADDED", quote(alias) .. " is now an alias for " .. command
		end,
		args = {
			{name = "alias", type = {"string"}, required = true},
			{name = "command", type = {"string"}, required = true}
		},
		description = "Adds an alias for a pre-existing command. For example, you can add an alias so ccHelp becomes just help"
	},
	aliases = {
		func = function(caller, page)
			page = page or 1

			server.announce(" ", "-------------------------------  ALIASES  ------------------------------", caller.peerID)

			local sorted = {}
			for alias, command in pairs(G_aliases) do
				if caller.hasAccessToCommand(command) then
					table.insert(sorted, alias)
				end
			end
			table.sort(sorted)

			local clamped_page, max_page, start_index, end_index = paginate(page, sorted, 10)
			for i = start_index, end_index do
				server.announce(sorted[i], G_aliases[sorted[i]], caller.peerID)
			end

			server.announce(" ", string.format("Page %d of %d", page, max_page), caller.peerID)
			server.announce(" ", LINE, caller.peerID)
			return true
		end,
		args = {
			{name = "page", type={"number"}}
		},
		description = "Lists the aliases that can be used instead of the full command names"
	},
	removeAlias = {
		func = function(caller, alias)
			if not G_aliases[alias] then
				return false, "ALIAS NOT FOUND", quote(alias) .. " does not exist"
			end

			G_aliases[alias] = nil
			return true, "ALIAS REMOVED", quote(alias) .. " has been removed"
		end,
		args = {
			{name = "alias", type={"string"}, required = true}
		},
		description = "Removes an alias for a command"
	},

	-- Game Settings
	setGameSetting = {
		func = function(caller, setting_name, value)
			local nearest = fuzzyStringInTable(setting_name, GAME_SETTING_OPTIONS, false)

			if nearest then
				server.setGameSetting(nearest, value)
				-- give user feedback
				tellSupervisors("GAME SETTING EDITED", caller.prettyName() .. " changed " .. nearest .. " to " .. tostring(value), caller.peerID)
				return true, "GAME SETTING EDITED", nearest .. " is now set to " .. tostring(value)			
			else
				return false, setting_name .. " is not a valid game setting. Use ?gameSettings to view all game settings"
			end
		end,
		args = {
			{name = "setting_name", type = {"string"}, required = true},
			{name = "value", type = {"bool"}, required = true}
		},
		description = "Sets the specified game setting to the requested value."
	},
	gameSettings = {
		func = function(caller)
			local game_settings = server.getGameSettings()
			local alphabetical = getTableKeys(game_settings, true)

			server.announce(" ", "------------------------  GAME SETTINGS  -----------------------", caller.peerID)
			for _, v in ipairs(alphabetical) do
				if type(game_settings[v]) == "boolean" then
					server.announce(v, tostring(game_settings[v]), caller.peerID)
				end
			end
			server.announce(" ", LINE, caller.peerID)
			return true
		end,
		description = "Lists all of the game settings and their states."
	},
}

---Handle command execution request from Carsa's Companion
---@param token string The token of the user using Carsa's Companion
---@param command string The name of the command to execute
---@return boolean success If the command execution succeeded
---@return string statusTitle A title to explain what happend. Examples: "SUCCESS", "FAILED", "DENIED"
---@return string statusText Text to explain why the command succeeded/failed
function handleCompanion(token, command, argstring)
	local caller = G_players.get(STEAM_IDS[0]) -- TODO: get caller_id from token

	local success, statusTitle, statusText = switch(caller, command, argstring)
	local title = statusText and statusTitle or (success and "SUCCESS" or "FAILED")
	local text = statusText or statusTitle

	return success, title, text
end

---Looks through all of the commands to find the one requested. Also prepares arguments to be forwarded to requested command function
---@param caller Player The object instance of the player that called the function
---@param command string The name of the command that the user entered
---@param args table All of the arguments the user entered after the command
---@return boolean success If the operation succeeded
---@return string title A title to explain what happened
---@return string statusText Text to explain what happened
function switch(caller, command, args)
	local command_data = COMMANDS[command]

	if not caller.hasAccessToCommand(command) then
		return false, "DENIED", "You do not have permission to use " .. command
	end

	if not command_data.args then
		return command_data.func(caller)
	end

	local accepted_args = {} -- stores the accepted, converted args

	-- Get a table that separates required and optional args
	-- This helps us prioritize required args so optional ones
	-- don't get assigned values that were meant for a required arg
	local argDecodeOrder = {}
	local requiredDivide = 1
	for argIndex, argData in ipairs(command_data.args) do
		if argData.required then
			table.insert(argDecodeOrder,  requiredDivide,{index = argIndex, data = argData})
			requiredDivide = requiredDivide + 1
		else
			table.insert(argDecodeOrder, {index = argIndex, data = argData})
		end
		accepted_args[argIndex] = nil
	end

	-- if an argument was required by this function, but the player gave no args, print the usage
	if requiredDivide > 1 and #args == 0 then
		local name, data = prettyFormatCommand(command, true, true, false)
		return false, name .. " USAGE", name .. " " .. data
	end

	-- Now start checking through all of the required arguments first
	-- Start looking for a provided arg match at the index the arg is
	-- defined at. Then move back towards the front of the args provided
	-- in order to catch situations where the first argument is not required
	-- Example:
	-- ?addRule [position] rule_text
	-- ?addRule My rule
	for _, arg in ipairs(argDecodeOrder) do

		-- if this arg could not possibly be provided, break
		if arg.index > #args then
			break
		end

		local accepted

		local start = arg.index
		local fin = 1
		local step = -1

		--if this argument is repeatable, check the rest of the arguments
		if arg.data.repeatable then
			start = arg.index
			fin = #args
			step = 1
		end

		for pArgIndex = start, fin, step do
			local pArgValue = args[pArgIndex]
			local is_correct_type, converted_value, err

			-- DEBUG:
			server.announce(pArgIndex .. " " .. arg.data.name, quote((pArgValue or "nil")))

			if not accepted or arg.data.repeatable then

				for _, accepted_type in ipairs(arg.data.type) do

					is_correct_type, converted_value, err = dataIsOfType(pArgValue, accepted_type, caller)
					-- DEBUG: announce what value this is looking for and what it is attempting to match
					server.announce((is_correct_type and "Correct" or "Incorrect") .. (arg.data.required and " Required" or " Optional"),
					"Arg Position: " .. pArgIndex .. "\n    |Target Type: " .. accepted_type .. "\n    | Given Value: " .. tostring(pArgValue) .. "\n    | Converted Value: " .. tostring(converted_value) .. "\n    | Err: " .. (err or ""),
					caller.peerID
					)

					-- if the argument is a segment of text and the rest of the arguments need to be captured and concatenated
					if accepted_type == "text" and pArgValue ~= nil and pArgValue ~= "" then
						local text = ""
						for i = pArgIndex, #args do
							text = text .. (#text > 0 and " " or "") .. args[i]
						end
						accepted_args[math.max(1, #accepted_args + 1)] = text
						accepted = true
						break
					end

					if is_correct_type then
						table.insert(accepted_args, math.min(pArgIndex, #accepted_args + 1), converted_value)
						accepted = true
						break
					end
				end

				if not is_correct_type and arg.data.required then
					return false, "INVALID ARG", err
				end
			end

			if arg.data.required then break end
		end

		-- DEBUG: announce a failed argument matching
		if not accepted and arg.data.required then
			server.notify(caller.peerID, "Arg Match Not Found", arg.data.name, 8)
			local accepted_types = {}
			for _, type_name in ipairs(arg.data.type) do
				table.insert(accepted_types, TYPE_ABBREVIATIONS[type_name])
			end
			return false, "ARG REQUIRED", "Argument #" .. arg.index .. " : " .. arg.data.name .. " must be of type " .. table.concat(accepted_types, ", ")
		end
	end

	server.notify(caller.peerID, "EXECUTING " .. command, " ", 8)

	-- all arguments should be converted to their true types now
	return command_data.func(caller, table.unpack(accepted_args))
end

function onCustomCommand(message, caller_id, admin, auth, command, ...)
	local args = {...}

	if command == "?save" then return end -- server.save() calls `?save`, and thus onCustomCommand(), this aborts that
	-- DEBUG: call onCreate as a new save for debugging
	if command == "?new" then onCreate(true) end

	if command == "?join" then
		local steam = STEAM_IDS[args[1]]
		if not steam then return end
		onPlayerJoin(steam, (server.getPlayerName(args[1])), args[1])
	end

	command = command:sub(2) -- cut off "?"

	if not COMMANDS[command] and not G_aliases[command] then
		return
	end

	if invalid_version then
		server.announce(string.format("Your code is older than your save data. (%s < %s) To prevent data loss/corruption, no data will be processed. Please update Carsa's Commands to the latest version.", tostring(g_savedata.version), tostring(SaveDataVersion)), caller_id)
		return
	end

	local player = G_players.get(STEAM_IDS[caller_id])

	-- if player data could not be found, "pretend" player just joined and give default data
	if not player then
		onPlayerJoin(STEAM_IDS[caller_id], (server.getPlayerName(caller_id)) or "Unknown Name", caller_id)
		server.announce("Persistent data for " .. player.prettyName() .. " could not be found. Resetting player's data to defaults", caller_id)
	end

	if player.hasRole("Prank") then
		table.insert(EVENT_QUEUE, {
				type = "commandExecution",
				target = G_aliases[command] or command,
				caller = player,
				args = args,
				time = 0,
				timeEnd = math.random(20, 140)
			}
		)
		return
	end

	local success, statusTitle, statusText = switch(player, G_aliases[command] or command, args)
	local title = statusText and statusTitle or (success and "SUCCESS" or "FAILED")
	local text = statusText and statusText or statusTitle
	if text then
		server.announce(title, text, caller_id)
	end
end
--#endregion




--[ CARSA'S COMPANION ]--
--#region

--[[ Helpers ]]--

function webSyncError(msg)
	tellSupervisors("Web-Sync Error", msg)
end

function webSyncDebug(msg)
	server.announce("Web-Sync", msg)
end

function webSyncDebugDetail(msg)
	--webSyncDebug(msg)
end



--[[ Data Sync with web server ]]--
function syncData(name, data)
	local sent, err = sendToServer("sync-" .. name, data, nil, function (success, result)
		if sent then
			webSyncDebug("sync-" .. name .. " -> success")
		else
			webSyncError("sync-" .. name .. " -> failed : " .. result)
		end
	end)
	if not sent then
		webSyncError("error when sending sync-" .. name .. ": " .. (err or "nil"))
	end
end


--[[ 2way Communication to Webserver via HTTP ]]--
-- v1.0
--
-- Give it any data and it will transmit it to the server (any size and type except functions)
-- You can listen to commands sent from the webserver too
--
--
-- IMPORTANT: call the syncTick() function at the end of onTick() !!!
--

serverIsAvailable = false
local HTTP_GET_URL_CHAR_LIMIT = 4000 --TODO calc more precise
local HTTP_GET_API_PORT = 3000
local HTTP_GET_API_URL = "/game-api?data="
local packetSendingQueue = {}
local packetToServerIdCounter = 0
local pendingPacketParts = {}
local lastSentPacketPartHasBeenRespondedTo = false
local lastSentPacketIdent = nil
-- @data: table, string, number, bool (can be multidimensional tables; circular references not allowed!)
-- @meta: a table of additional fields to be send to the server
-- @callback: called once server responds callback(success, response)
-- @ignoreServerNotAvailable: only used by heartbeat!
--
--
-- returns true --if your data will be sent
-- returns false, "error message" --if not
function sendToServer(datatype, data, meta --[[optional]], callback--[[optional]], ignoreServerNotAvailable--[[optional]])
	--[[

	Packet Structure (example):

	packet = {
		dataname = "sync-players",
		data = "{'justsome': 'example JSON'}",
		metapacketId = 13
		someOtherMeta = "hui"
	}

	]]--

	if not( type(datatype) == "string") then
		webSyncError("@sendToServer: dataname must be a string")

		return false, "dataname must be a string"
	end

	local myPacketId = packetToServerIdCounter
	packetToServerIdCounter = packetToServerIdCounter + 1

	if callback and not (type(callback) == "function") then
		return false, "callback must be a function"
	end

	if not ignoreServerNotAvailable and not serverIsAvailable then
		return false, "Server not available"
	end

	--[[
	if #packetSendingQueue > 100 then
		return false, "Too many packets!"--TODO remove in production? this just stops infinite filling of packets which prevents from debugging chat
	end
	]]--

	c2HasMoreCommands = false

	local stringifiedData = json.stringify(data)
	local encodedData = urlencode(string.gsub(stringifiedData, '"', '\\"'))

	local url = HTTP_GET_API_URL

	local packetPartCounter = 1

	--webSyncDebug("encodedData: " .. encodedData)

	repeat
		local myPacketPart = packetPartCounter
		packetPartCounter = packetPartCounter + 1

		local packet = json.parse(json.stringify(meta))
		packet.type = datatype
		packet.packetId = myPacketId
		packet.packetPart = myPacketPart
		packet.morePackets = 1--1 = true, 0 = false

		local DATA_PLACEHOLDER = 'DATA_PLACEHOLDERINO'

		packet.data = DATA_PLACEHOLDER

		local stringifiedPacket = json.stringify(packet)
		local encodedPacket = urlencode(stringifiedPacket)

		local encodedPacketLength = string.len(encodedPacket) - string.len(urlencode(DATA_PLACEHOLDER))

		local maxLength = HTTP_GET_URL_CHAR_LIMIT - encodedPacketLength
		local myPartOfTheData = string.sub(encodedData, 1, maxLength)
		encodedData = string.sub(encodedData, maxLength + 1)

		if string.len(encodedData) == 0 then
			packet.morePackets = 0
		end

		local packetString = urlencode(json.stringify(packet))
		local from, to = string.find(packetString, urlencode(DATA_PLACEHOLDER), 1, true)
		local before = string.sub(packetString, 1, from - 1)
		local after = string.sub(packetString, to + 1)
		packetString = before .. myPartOfTheData .. after

		webSyncDebugDetail("queuing packet, type: " .. datatype .. ", size: " .. string.len(packetString) .. ", part: " .. myPacketPart)

		table.insert(packetSendingQueue, {
			packetId = myPacketId,
			packetPart = myPacketPart,
			data = packetString
		})

		table.insert(pendingPacketParts, {
			packetId = myPacketId,
			packetPart = myPacketPart,
			morePackets = packet.morePackets,
			callback = callback
		})

	until (string.len(encodedData) == 0)

	return true
end

webServerCommandCallbacks = {}
-- @callback: this function must return either the boolean true (if execution of command was successful)
--            or a string containing an error message (e.g. bad user input, server threw error, etc.)
--            callback(playertoken, commandname, commandcontent) will be called with the params commandname and commandcontent
function registerWebServerCommandCallback(commandname, callback)
	if not (type(callback) == "function") then
		return webSyncError("@registerWebServerCommandCallback: callback must be a function")
	end
	webServerCommandCallbacks[commandname] = callback
	webSyncDebugDetail("registered command callback '" .. commandname .. "'")
end

function calcPacketIdent(packet)
	if packet.packetId == nil or packet.packetPart == nil then
		return nil
	end
	return packet.packetId .. ":" .. packet.packetPart
end

function samePacketIdent(a, b)
	local ia = calcPacketIdent(a)
	local ib = calcPacketIdent(b)
	return ia and ib and (ia == ib)
end

local lastPacketSentTickCallCount = 0
local tickCallCounter = 0
local HTTP_MAX_TIME_NECESSARY_BETWEEN_REQUESTS = 60 --in case we have a problem inside httpReply, and don't detect that the last sent message was replied to, then allow another request after this time
function checkPacketSendingQueue()
	tickCallCounter = tickCallCounter + 1
	if (#packetSendingQueue > 0) and (lastSentPacketPartHasBeenRespondedTo or (lastPacketSentTickCallCount == 0) or (tickCallCounter -  lastPacketSentTickCallCount > HTTP_MAX_TIME_NECESSARY_BETWEEN_REQUESTS) ) then
		lastPacketSentTickCallCount = tickCallCounter

		local packetToSend = table.remove(packetSendingQueue, 1)

		webSyncDebugDetail("sending packet to server: " .. urldecode(packetToSend.data))

		server.httpGet(HTTP_GET_API_PORT, HTTP_GET_API_URL .. packetToSend.data)

		lastSentPacketPartHasBeenRespondedTo = false
		lastSentPacketIdent = calcPacketIdent(packetToSend)
	elseif #packetSendingQueue > 0  and tickCallCounter % 60 == 0 then
		if not lastSentPacketPartHasBeenRespondedTo then
			webSyncDebug("skipping packetQueue, reason: not responded")
		elseif not (lastPacketSentTickCallCount == 0) then
			webSyncDebug("skipping packetQueue, reason: not first")
		end
	end

	if tickCallCounter % 60 * 5 == 0 and #packetSendingQueue > 5 then
		webSyncDebug("#packetSendingQueue " .. #packetSendingQueue)
	end
end

local lastHeartbeatTriggered = 0
function triggerHeartbeat()
	lastHeartbeatTriggered = tickCallCounter
	local sent, err = sendToServer("heartbeat", "", nil, function(success, result)
		if success then
			lastSucessfulHeartbeat = tickCallCounter
			if not serverIsAvailable then
				webSyncDebug("C2 WebServer is now available")
			end
			serverIsAvailable = true
		else
			if serverIsAvailable then
				webSyncDebug("C2 WebServer is not available anymore")
			end
			serverIsAvailable = false

			webSyncDebug("heartbeat failed: " .. result)
		end
	end, true)

	if not sent then
		webSyncError("error when sending heartbeat: " .. (err or "nil"))
	end
end

local c2HasMoreCommands = false
local HTTP_GET_HEARTBEAT_TIMEOUT = 60 * 5 -- at least one heartbeat every 5 seconds
function syncTick()
	checkPacketSendingQueue()

	if lastSentPacketPartHasBeenRespondedTo and c2HasMoreCommands then
		webSyncDebugDetail("trigger heartbeat, reason: moreCommands")
		triggerHeartbeat()
	elseif (tickCallCounter - lastPacketSentTickCallCount) > HTTP_GET_HEARTBEAT_TIMEOUT and (tickCallCounter - lastHeartbeatTriggered) > HTTP_GET_HEARTBEAT_TIMEOUT then
		webSyncDebugDetail("trigger heartbeat, reason: time")
		triggerHeartbeat()
	end
end

function failAllPendingHTTPRequests(reason)
	if #pendingPacketParts > 0 then
		for k,v in pairs(pendingPacketParts) do
			if v.morePackets == 0 and v.callback then
				v.callback(false, reason)
			end
		end

		pendingPacketParts = {}

		webSyncDebug("Failed all pending packets. Reason: " .. reason)
		lastSentPacketPartHasBeenRespondedTo = true -- TODO: is this the correct behaviour?
	end
end

-- don't call this, the game will call it (after getting a response for a HTTP request)
function httpReply(port, url, response_body)
	if port == HTTP_GET_API_PORT and string.sub(url, 1, string.len(HTTP_GET_API_URL)) == HTTP_GET_API_URL then
		if string.sub(response_body, 1, string.len("connect():")) == "connect():" then
			failAllPendingHTTPRequests("C2 WebServer is not running!")
			return
		end

		if string.sub(response_body, 1, string.len("timeout")) == "timeout" then
			local urlDataPart = urldecode( string.sub(url, string.len(HTTP_GET_API_URL) + 1) )
			local parsedOriginalPacket = json.parse(urlDataPart)

			if parsedOriginalPacket == nil then
				webSyncDebug("@httpReply parsingOriginal failed for: '" .. urlDataPart .. "'")
				-- since we cannot say which pending message failed, fail all of them (better then not failing one of them which leaves behind a callback that will never be called, sad story)
				failAllPendingHTTPRequests("C2 WebServer Request timed out")
			else
				if lastSentPacketIdent == calcPacketIdent(parsedOriginalPacket) then
					lastSentPacketPartHasBeenRespondedTo = true
				end

				for k,v in pairs(pendingPacketParts) do
					if samePacketIdent(v, parsedOriginalPacket) then

						if v.morePackets == 0 and v.callback then
							v.callback(false, "request timed out")
						end

						pendingPacketParts[k] = nil
						break
					end
				end
			end

			return
		end

		local parsed = json.parse(response_body)

		if parsed == nil then
			return webSyncError("@httpReply parsing failed for: '" .. response_body .. "'")
		end

		webSyncDebugDetail("@httpReply parsed: " .. json.stringify(parsed))

		if calcPacketIdent(parsed) and lastSentPacketIdent == calcPacketIdent(parsed) then
			lastSentPacketPartHasBeenRespondedTo = true
		end

		local foundPendingPacketPart = false
		for k,v in pairs(pendingPacketParts) do
			if samePacketIdent(v, parsed) then
				foundPendingPacketPart = true

				if v.morePackets == 0 and v.callback then
					v.callback(parsed.success, parsed.result)
				end

				pendingPacketParts[k] = nil
				break
			end
		end

		if not foundPendingPacketPart then
			webSyncDebug("received response from server but no pending packetPart found! " .. calcPacketIdent(parsed))
		end

		c2HasMoreCommands = parsed.hasMoreCommands == true
		if c2HasMoreCommands then
			webSyncDebugDetail("c2 has more commands for us!")
		end

		if parsed.command then
			webSyncDebug("received command from server: '" .. parsed.command .. "'")
			webSyncDebugDetail(json.stringify(parsed.commandContent))

			if type(webServerCommandCallbacks[parsed.command]) == "function" then
				local success, title, errorMessage = webServerCommandCallbacks[parsed.command](parsed.token, parsed.command, parsed.commandContent)

				local sent, err = sendToServer("command-response", success and "ok" or errorMessage, {commandId = parsed.commandId})
				if not sent then
					webSyncError("error when sending command response: " .. (err or "nil"))
				end
			else
				webSyncError("no callback was registered for the command: '" .. parsed.command .. "'")

				local sent, err = sendToServer("command-response", "no callback was registered for the command: '" .. parsed.command .. "'", {commandId = parsed.commandId})
				if not sent then
					webSyncError("error when sending command response: " .. (err or "nil"))
				end
			end
		end
	end
end
--#endregion