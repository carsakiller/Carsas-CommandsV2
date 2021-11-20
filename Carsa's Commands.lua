local debugMessages = true

--! For export, but should be harmless
server = server or {}


-- LIBRARIES --

-- lua implementation of fzy library --
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
-- END OF LIBRARIES --




local ScriptVersion = "2.0.0"
local SaveDataVersion = "2.0.0"

--- Flag used to notify of an outdated version
local invalid_version

local ABOUT = {
	{title = "ScriptVersion:", text = ScriptVersion},
	{title = "SaveDataVersion:", text = SaveDataVersion},
	{title = "Created By:", text = "Carsa, CrazyFluffyPony, Dargino, Leopard"},
	{title = "Github:", text = "https://github.com/carsakiller/Carsas-Commands"},
	{title = "More Info:", text = "For more info, I recommend checking out the github page"}
}

local SAVE_NAME = "CC_Autosave"

local DEV_STEAM_IDS = {
	["76561197976988654"] = true, --Deltars
	["76561198022256973"] = true, --Bones
	["76561198041033774"] = true, --Jon
	["76561198080294966"] = true, --Antie

	["76561197991344551"] = true, --Beginner
	["76561197965180640"] = true, --Trapdoor

	["76561198038082317"] = true, --NJersey
}

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

local PLAYER_DATA_DEFAULTS = {
	name = "unknown",
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
			resetPref = true,
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

local EQUIPMENT_SIZE_NAMES = {"Large", "Small", "Outfit"}

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

local TYPE_ABBREVIATIONS = {
	string = "text",
	number = "num",
	table = "tbl",
	bool = "bool",
	playerID = "text/num",
	vehicleID = "num",
	steam_id = "num",
	text = "text",
	letter = "letter"
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

local STEAM_ID_MIN = "76561197960265729"
local deny_tp_ui_id
local previous_game_settings

local LINE = "---------------------------------------------------------------------------"


-- "CLASSES" --
local Player, Role, Vehicle = {}, {}, {}


-- GENERAL HELPER FUNCTIONS --

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

--- gets the list of players and returns it indexed by peer_id
---@return table new_format The player list table indexed by peer_id
function getPlayerList()
	local new_format = {}
	local list = server.getPlayers()
	for k, v in ipairs(list) do
		new_format[v.id] = {steam_id = tostring(v.steam_id), name = v.name}
	end
	return new_format
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

--- sorts the keys of a table
---@param t table the table that will have it's keys sorted
---@param descending boolean if the sort should be in descending order
---@return table sorted_table table containing the keys of t as values in sorted order
function sortKeys(t, descending)
	local sorted = {}
	for k, v in pairs(t) do
		table.insert(sorted, k)
	end

	if descending then
		table.sort(sorted, function(a, b) return a > b end)
	else
		table.sort(sorted)
	end
	return sorted
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
		for k, v in ipairs(COMMANDS[command_name].args) do
			local s = ""
			local optional = not v.required

			local types = {}
			if include_types then
				for k, v in ipairs(v.type) do
					table.insert(types, TYPE_ABBREVIATIONS[v])
				end
			end

			s = s .. (optional and "[" or "") .. v.name .. (include_types and string.format("(%s)", table.concat(types, "/")) or "") .. (optional and "]" or "") -- add optional bracket symbols
			s = s .. (v.repeatable and " ..." or "") -- add repeatable symbol
			table.insert(args, s)
		end
		text = text .. " " .. table.concat(args, ", ")
	end

	if include_description then text = text .. "\n" .. COMMANDS[command_name].description end
	return "?" .. command_name, text
end




-- ERROR REPORTING FUNCTIONS --

--- general error reporting that includes instructions to report any bugs
---@param errorMessage string the message to print to the user
---@param peer_id number the peer_id of the user to send the message to
function throwError(errorMessage, peer_id)
	server.announce("ERROR", errorMessage .. ". Please visit the GitHub page for this script to file a bug report. https://github.com/carsakiller/Carsas-Commands", peer_id or -1)
end

--- warn of non-critical issue
---@param warningMessage string the message to print to the user
---@param peer_id number the peer_id of the user to send the message to
function throwWarning(warningMessage, peer_id)
	server.announce("WARNING", warningMessage, peer_id or -1)
end

---Checks whether a tp's coordinates are valid or if they would teleport something off-map and break things
---@param target_matrix table The matrix that things are being teleported to
---@return boolean is_valid If the requested coords are valid or are nill / off-map
---@return string? title A title to explain why the coords are invalid, or nil if it is valid
---@return string? statusText Some text to explain why the coords are invalid, or nil if it is valid
local function checkTp(target_matrix)
	local x, y, z = matrix.position(target_matrix)

	if not x or not y or not z then
		return false, "INVALID POSITION", "The given position is invalid"
	end

	if math.abs(x) > 150000 or math.abs(y) > 10000000000 or math.abs(z) > 150000 then
		return false, "UNSAFE TELEPORT", "You have not been teleported as teleporting to the requested coordinates would brick this save"
	end

	return true
end

---Tell all players with the supervisor role something important
---@param title string The title of the message
---@param message string The message content
---@vararg number PeerIDs to not include in the broadcast
function tellSupervisors(title, message, ...)
	local peers = Role.onlinePeers("Supervisor")
	local excluded_peers = {...}

	if excluded_peers[1] ~= nil then
		for _, peer_id in pairs(excluded_peers) do
			peers[peer_id] = nil
		end
	end

	for peer_id, _ in pairs(peers) do
		server.announce(title, message, peer_id)
	end
end

--- Whisper to admins/owners subscribed to debugging infos.
---@param title string the title of the message.
---@param message string the message.
function tellDebug(title, message)
	-- todo individual subscriptions

	if not debugMessages then return end
	for k, v in pairs(PLAYER_LIST) do
		if Player.hasRole(k, "Owner") then
			server.announce(title, message, k)
		end
	end
end




--- get the player's steam id
---@param peer_id number The target player's peer_id
---@return string steam_id The player's steam ID
function Player.getSteamID(peer_id)
	return PLAYER_LIST[peer_id].steam_id or nil
end

--- get the player's data table
---@param peer_id number The target player's peer_id
---@return table persistent_data The player's persistent data table
function Player.getData(peer_id)
	return g_playerData[Player.getSteamID(peer_id)]
end

--- bans a player by peer or steam id
---@param caller_id number the peer id of the admin that is banning the player
---@param id number|string The peer id of the player as a number or the steam_id of the player as a string
---@return boolean success If the operation succeeded
---@return string title A title to explain what happened
---@return string statusText Text to explain what happened
function Player.ban(caller_id, id)
	local steam_id = id
	if #tostring(id) < #STEAM_ID_MIN then -- peer_id was given
		if not PLAYER_LIST[id] then -- peer_id is not a valid one
			return false, "INVALID ARG", id .. " is not a valid peer_id of an online player"
		end
		steam_id = Player.getSteamID(id)
		if steam_id == Player.getSteamID(caller_id) then
			return false, "INVALID ARG", "You cannot ban yourself"
		end
		g_banned[steam_id] = Player.getSteamID(caller_id)
		server.save(SAVE_NAME)
		server.kickPlayer(id)
		tellSupervisors("PLAYER BANNED", Player.prettyName(id) .. " was banned from the server by " .. Player.prettyName(caller_id), caller_id)
		return true, "PLAYER BANNED", Player.prettyName(id) .. " was banned"
	end
	-- steam_id was given
	if id == Player.getSteamID(caller_id) then
		return false, "INVALID ARG", "You cannot ban yourself"
	end
	if not g_playerData[id] then
		g_playerData[id] = deepCopyTable(PLAYER_DATA_DEFAULTS)
	end
	g_banned[id] = Player.getSteamID(caller_id)
	server.save(SAVE_NAME)

	-- if player is currently on server, kick them
	if g_playerData[steam_id].peer_id then
		server.kickPlayer(g_playerData[steam_id].peer_id)
	end
	local banned_name = g_playerData[steam_id].name or "unknown"
	tellSupervisors("PLAYER BANNED", string.format("%s(%s)", banned_name, id) .. " was banned from the server by " .. Player.prettyName(caller_id), caller_id)
	return true, "PLAYER BANNED", string.format("%s(%s)", banned_name, id) .. " was banned from the server"
end

---unbans a player using their steam id
---@param caller_id number the peer id of the admin that is unbanning the player
---@param steam_id string the steam id of the player to unban
---@return table status Contains data on if/why the operation succeeded/failed
function Player.unban(caller_id, steam_id)
	steam_id = tostring(steam_id)
	if #steam_id < #STEAM_ID_MIN then
		return false, "INVALID ARG", steam_id .. " is not a valid steamID"
	end
	local name = exploreTable(g_playerData, {steam_id, "name"})
	if not g_banned[steam_id] then
		return false, "PLAYER NOT BANNED", Player.prettyName(steam_id) .. " is not banned"
	end
	g_banned[steam_id] = nil
	server.save(SAVE_NAME)
	local banned_name = g_playerData[steam_id].name or "unknown"
	tellSupervisors("PLAYER UNBANNED", string.format("%s(%s)", banned_name, steam_id) .. " has been unbanned by " .. Player.prettyName(caller_id), caller_id)
	return true, "PLAYER UNBANNED", string.format("%s(%s)", banned_name, steam_id) .. " has been unbanned"
end

--- Formats the player's name and peer_id nicely for printing to users
---@param id number|string The target player's peer_id or steam_id
---@return string name The player's name and peer_id formatted nicely
function Player.prettyName(id)
	local is_steam = #tostring(id) == #STEAM_ID_MIN
	local as_num = tonumber(id)
	if is_steam then
		local player_data = g_playerData[id]
		if PLAYER_LIST[player_data.peer_id] then -- player is on server still
			return string.format("%s(%d)", player_data.name, player_data.peer_id)
		else -- player is offline
			return player_data.name .. "(offline)"
		end
	else
		local name, is_success = server.getPlayerName(as_num)
		name = is_success and name or Player.getData(as_num).name or "Unknown Name"
		return string.format("%s(%d)", name, as_num)
	end
end

--- Gets the inventory of the player
---@param peer_id number The target player's peer_id
---@return table|boolean inventory A table containing the ids of the equipment found in the player's inventory as well as the number of items in their inventory or false if failed
---@return string? title A title to explain what happened
---@return string? statusText Text to explain what happened
---@example table that is returned:
--- {0, 0, 0, 0, 0, 0, count = 0}
function Player.getInventory(peer_id)
	local inventory = {count = 0}
	local character_id, success = server.getPlayerCharacterID(peer_id)

	if not success then
		return false, "ERROR OCCURRED", "Could not get the inventory of " .. Player.prettyName(peer_id) .. "\n::characterID could not be found"
	end

	for i=1, #EQUIPMENT_SLOTS do
		local equipment_id, is_success = server.getCharacterItem(character_id, i)
		inventory[i] = (is_success and equipment_id) or 0
		if inventory[i] ~= 0 then inventory.count = inventory.count + 1 end
	end
	return inventory
end

---Decodes what argument is the slot and calls `Player.equip()`
---@param caller_id number The peer_id of the player calling the function
---@param target_id number The peer_id of the player to equip
---@vararg any The arguments for the equip command
function Player.equipArgumentDecoding(caller_id, target_id, ...)
	local args = {...}
	local args_to_pass = {}

	for _, v in ipairs(args) do
		if isLetter(v) then
			args_to_pass.slot = string.upper(v)
		else
			table.insert(args_to_pass, v)
		end
	end
	return Player.equip(caller_id, target_id, args_to_pass.slot or false, table.unpack(args_to_pass))
end

--- Equips the target player with the requested item
---@param peer_id number The peer id of the player who initiated the equip command
---@param target_peer_id number The peer id of the player who is being equipped
---@param slot string The slot the item is going in (refer to EQUIPMENT_SLOTS)
---@param item_id number The id of the item to give to the player
---@param data1 number The value to send with the item, can be number or integer.
--- If the item takes two number the first (this one) must be the integer value.
--- (can be channel or charges or battery %)
---@param data2 number If an item takes two values this is the number value.
---@return boolean success If the operation succeeded
---@return string title A title to explain what happened
---@return string statusText Text to explain what happened
function Player.equip(peer_id, target_peer_id, slot, item_id, data1, data2, is_active)
	local character_id, success = server.getPlayerCharacterID(target_peer_id)
	if not success then
		return false, "ERROR", "Could not find the character for " .. Player.prettyName(target_peer_id) .. ". This should never happen"
	end
	item_id = tonumber(item_id)
	slot = slot and string.upper(slot) or nil

	local slot_number = SLOT_LETTER_TO_NUMBER[slot]

	if not item_id then
		return false, "INVALID ARG", "Could not convert argument \"" .. tostring(item_id) .. "\" to an equipment_id (number)"
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
	local caller_pretty_name = Player.prettyName(peer_id)
	local target_pretty_name = Player.prettyName(target_peer_id)

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
		local inventory, title, statusText = Player.getInventory(target_peer_id)
		if not inventory then return inventory, title, statusText end

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
			if target_peer_id == peer_id then
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
		if peer_id ~= target_peer_id then
			if isRecharge then
				server.notify(target_peer_id, "EQUIPMENT UPDATED", caller_pretty_name .. " updated your " .. item_pretty_name .. " in slot " .. slot_name, 5)
				return true, "PLAYER EQUIPPED", target_pretty_name .. "'s " .. item_pretty_name .. " in slot " .. slot_name .. " has been updated"
			else
				server.notify(target_peer_id, "EQUIPPED", caller_pretty_name .. " equipped you with " .. item_pretty_name .. " in slot " .. slot_name, 5)
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

--- Equips the target player with the starting equipment
---@param peer_id number the peer_id of the player to give the equipment to
---@return boolean success If the operation succeeded
---@return string? title A title to explain what happened
---@return string? statusText Text to explain what happened
function Player.giveStartingEquipment(peer_id)
	local items = {
		g_preferences.startEquipmentA.value,
		g_preferences.startEquipmentB.value,
		g_preferences.startEquipmentC.value,
		g_preferences.startEquipmentD.value,
		g_preferences.startEquipmentE.value,
		g_preferences.startEquipmentF.value
	}

	for i, item_id in pairs(items) do
		local success, title, statusText = Player.equip(peer_id, peer_id, EQUIPMENT_SLOTS[i].letter, math.floor(item_id))
		if not success then
			server.announce(title, statusText)
			return false, title, statusText
		end
	end
	return true
end

--- Returns whether or not a player has the given role
---@param peer_id number The target player's peer_id
---@param role string The name of the role to check
---@return boolean has_role Player has the role (true) or does not have the role (false)
function Player.hasRole(peer_id, role)
	local steam_id = Player.getSteamID(peer_id)
	if g_roles[role].members[steam_id] then
		return true
	end
	return false
end

--- Gives a player the specified role
---@param caller_id number the peer_id of the player calling the command
---@param peer_id number The target player's peer_id
---@param role string The name of the role to give the player
---@return boolean success If the operation succeeded
---@return string title A title to explain what happened
---@return string statusText Text to explain what happened
function Player.giveRole(caller_id, peer_id, role)
	local target_id = peer_id or caller_id

	if not Role.exists(role) then
		return false, "ROLE NOT FOUND", "There is no role named \"" .. role .. "\""
	end

	g_roles[role].members[Player.getSteamID(target_id)] = true
	Player.updatePrivileges(target_id)
	server.save(SAVE_NAME)

	local message = "You have been given the role \"" .. role .. "\""

	if caller_id == -1 then
		if role ~= "Prank" and role ~= "Everyone" then
			server.notify(peer_id, "ROLE ASSIGNED", message, 5)
		end
		return true
	end

	if role == "Prank" then
		return true, "Target has been pranked"
	end

	if caller_id ~= target_id then
		server.notify(target_id, "ROLE ASSIGNED", message, 5)
		message = Player.prettyName(target_id) .. " was given the role \"" .. role .. "\""
	end

	tellSupervisors("ROLE ASSIGNED",Player.prettyName(target_id) .. " was given the role \"" .. role .. "\" by " .. Player.prettyName(caller_id), caller_id)
	return true, "ROLE ASSIGNED", message
end

--- removes a role from a player
---@param caller_id number the peer_id of the player calling the command
---@param peer_id number The target player's peer_id
---@param role string The name of the role to remove from the player
---@return boolean success If the operation succeeded
---@return string title A title to explain what happened
---@return string statusText Text to explain what happened
function Player.removeRole(caller_id, peer_id, role)
	local target_id = peer_id or caller_id

	if not Role.exists(role) then
		return false, "ROLE NOT FOUND", "There is no role named \"" .. role .. "\""
	end
	if not Player.hasRole(target_id, role) then
		return false, "INCONCLUSIVE", Player.prettyName(target_id) .. " does not have the role \"" .. role .. "\""
	end

	if role == "Owner" and target_id == caller_id or not Player.hasRole(target_id, "Owner") then
		return false, "DENIED", "You cannot remove the Owner role from someone when you are not yourself an Owner. You can also not remove the Owner role from yourself"
	end

	if role == "Everyone" then
		return false, "DENIED", "You cannot remove the Everyone role from someone as it represent every player"
	end

	g_roles[role].members[Player.getSteamID(target_id)] = nil
	Player.updatePrivileges(target_id)
	server.save(SAVE_NAME)

	local message = "Your role \"" .. role .. "\" has been revoked"
	if caller_id ~= target_id then
		server.notify(target_id, "ROLE REVOKED", message, 6)
		message = Player.prettyName(target_id) .. " had their role \"" .. role .. "\" revoked"
	end

	tellSupervisors("ROLE REVOKED", Player.prettyName(target_id) .. " has had the role \"" .. role .. "\" removed from them by " .. Player.prettyName(caller_id), caller_id)
	return true, "ROLE REVOKED", message
end

--- checks if the player has access to a certain command
---@param peer_id number the peer_id of the player to check
---@param command_name string the name of the command to check
---@return boolean has_access if the player has access to the specified command
function Player.hasAccessToCommand(peer_id, command_name)

	if Player.hasRole(peer_id, "Owner") then
		return true
	end

	for role_name, role_data in pairs(g_roles) do
		if role_data.active and Player.hasRole(peer_id, role_name) and role_data.commands and role_data.commands[command_name] then
			return true
		end
	end

	return false
end

--- updates and checks if the player has admin and auth privileges
---@param peer_id number The target player's peer_id
---@return boolean admin If the player is a SW admin
---@return boolean auth If the player is SW auth'd
function Player.updatePrivileges(peer_id)
	local steam_id = Player.getSteamID(peer_id)
	local player_list = getPlayerList()
	local is_admin = player_list[peer_id].admin
	local is_auth = player_list[peer_id].auth
	local role_admin = false
	local role_auth = false

	for role_name, role_data in pairs(g_roles) do
		if role_admin and role_auth then
			break
		end

		if role_data.active and Player.hasRole(peer_id, role_name) then
			if role_data.admin then
				role_admin = true
			end
			if role_data.auth then
				role_auth = true
			end
		end
	end

	if role_admin and not is_admin then
		server.addAdmin(peer_id)
	elseif not role_admin and is_admin then
		server.removeAdmin(peer_id)
	end

	if role_auth and not is_auth then
		server.addAuth(peer_id)
	elseif not role_auth and is_auth then
		server.removeAuth(peer_id)
	end

	-- update permissions to g_playerData table
	g_playerData[steam_id].admin = role_admin
	g_playerData[steam_id].auth = role_auth

	return role_admin, role_auth
end

--- updates the player's UI to show or remove tp blocking notice
---@param peer_id number the peer_id of the player to update
function Player.updateTpBlockUi(peer_id)
	local data = Player.getData(peer_id)
	if data.deny_tp then
		server.setPopupScreen(peer_id, deny_tp_ui_id, "", true, "Blocking Teleports", 0.34, -0.88)
	else
		server.removePopup(peer_id, deny_tp_ui_id)
	end
end

--- updates all of the vehicle id popups for a player
---@param peer_id number the peer_id of the player to update
function Player.updateVehicleIdUi(peer_id)
	for vehicle_id, vehicle_data in pairs(g_vehicleList) do
		local vehicle_position, success = server.getVehiclePos(vehicle_id)
		if not success then
			return
		end
		server.setPopup(peer_id, vehicle_data.ui_id, "", true, string.format("%s\n%s", Vehicle.prettyName(vehicle_id), Player.prettyName(vehicle_data.owner)), vehicle_position[13], vehicle_position[14], vehicle_position[15], 50)
	end
end

--- Returns the id of the vehicle nearest to the provided player
---@param peer_id number the peer_id of the player to search from
---@param owner_id number the peer_id of the owner of the target vehicle (optional)
---@return any id The id of the nearest vehicle or nil if there is no vehicle
function Player.nearestVehicle(peer_id, owner_id)
	local dist = math.huge
	local id

	for vehicle_id, data in pairs(g_vehicleList) do
		local matrixdist = matrix.distance((server.getPlayerPos(peer_id)), (server.getVehiclePos(vehicle_id)))
		if matrixdist < dist and (not owner_id and true or data.owner == Player.getSteamID(owner_id)) then
			dist = matrixdist
			id = vehicle_id
		end
	end

	return id
end




--- creates a new role
---@param caller_id number the peer_id of the player calling the command
---@param name string the name of the role
---@return boolean success If the operation succeeded
---@return string title A title to explain what happened
---@return string statusText Text to explain what happened
function Role.new(caller_id, name)
	local lowercase = string.lower(name)

	-- prevent user from making role that is reserved
	for k, v in pairs(DEFAULT_ROLES) do
		if string.lower(k) == lowercase then
			return false, "ROLE RESERVED", name .. " is a reserved role name and cannot be reused"
		end
	end

	if g_roles[name] then
		return false, "ROLE EXISTS", "A role with the name \"" .. name .. "\" already exists"
	end

	g_roles[name] = {
		commands = {},
		active = true,
		admin = false,
		auth = false,
		members = {}
	}

	server.save(SAVE_NAME)

	tellSupervisors("ROLE CREATED", "The role \"" .. name .."\" has been created by " .. Player.prettyName(caller_id), caller_id)
	return true, "ROLE CREATED", "The role \"" .. name .. "\" has been created"
end

--- deletes a role
---@param caller_id number the peer_id of the player calling the command
---@param name string the name of the role
---@return boolean success If the operation succeeded
---@return string title A title to explain what happened
---@return string statusText Text to explain what happened
function Role.delete(caller_id, name)
	local lowercase = string.lower(name)

	if not g_roles[name] then
		return false, "ROLE NOT FOUND", "The role \"" .. name .. "\" does not exist"
	end

	-- if the user is attempting to edit a default role, abort
	for k, v in pairs(DEFAULT_ROLES) do
		if string.lower(k) == lowercase then
			return false, "ROLE RESERVED", name .. " is a reserved role and cannot be deleted"
		end
	end

	-- remove this role from all players that have it
	for steam_id, _ in pairs(g_roles[name].members) do
		local peer_id = g_playerData[steam_id].peer_id
		if peer_id then
			Player.updatePrivileges(peer_id)
		end
	end
	g_roles[name] = nil

	server.save(SAVE_NAME)

	tellSupervisors("ROLE DELETED", "The role \"" .. name .. "\" has been deleted by " .. Player.prettyName(caller_id), caller_id)
	return true, "ROLE DELETED", "The role \"" .. name .. "\" has been deleted"
end

--- checks if a role exists and warns the user if it does not
---@param name string the name of the role to check
---@return boolean role_exists if the role exists
function Role.exists(name)
	return g_roles[name] ~= nil
end

--- gives or removes a role's access to a command
---@param caller_id number the peer_id of the player calling the command
---@param role string the name of the role being changed
---@param command_name string the name of the command being changed
---@param value boolean if the role has access to the command or not, if nil then it will toggle
---@return boolean success If the operation succeeded
---@return string title A title to explain what happened
---@return string statusText Text to explain what happened
function Role.setAccessToCommand(caller_id, role, command_name, value)
	if not Role.exists(role) then -- if role does not exist
		return false, "ROLE NOT FOUND", "A role with the name \"" .. role .. "\" does not exist"
	end

	if role == "Owner" then
		return false, "DENIED", "The Owner role cannot be edited"
	end

	if not COMMANDS[command_name] then -- if command does not exist
		return false, "COMMAND NOT FOUND", "\"" .. command_name .. "\" is not a valid command name"
	end

	if value == nil then
		if g_roles[role].commands[command_name] == nil then
			g_roles[role].commands[command_name] = true
		else
			g_roles[role].commands[command_name] = nil
		end
	else
		g_roles[role].commands[command_name] = value
	end

	server.save(SAVE_NAME)

	local message = string.format("\"%s\" has %s access to the command \"%s\"\nEdited by: %s",
		role,
		value and "been given" or "lost",
		command_name,
		Player.prettyName(caller_id)
	)

	tellSupervisors("ROLE EDITED", message, caller_id)
	return true, "ROLE EDITED", string.format("\"%s\" has %s access to the command \"%s\"", role, value and "been given" or "lost", command_name)
end

---Get a table of all of the online peers that have this role
---@param role_name string The name of this role
---@return table|boolean peerIDs Table indexed by peer_ids or false if the role is invalid
function Role.onlinePeers(role_name)
	local role_exists, err = Role.exists(role_name)
	if not role_exists then return false end

	local peerIDs = {}

	for _, steam_id in ipairs(g_roles[role_name].members) do
		local peer_id = g_playerData[steam_id].peer_id
		if peer_id then
			peerIDs[peer_id] = true
		end
	end

	return peerIDs
end




--- returns the vehicle's name and id in a nice way for user readability
---@param vehicle_id number the id of the vehicle
---@return string pretty_name the nicely formatted name of the vehicle with it's id appended
function Vehicle.prettyName(vehicle_id)
	local name = g_vehicleList[vehicle_id].name
	return string.format("%s(%d)", name ~= "Error" and name or "Unknown", vehicle_id)
end

--- returns if the vehicle_id is valid and the vehicle exists
---@param vehicle_id number The id of the vehicle to check
---@return boolean vehicle_exists if the vehicle exists
function Vehicle.exists(vehicle_id)
	local _, exists = server.getVehicleName(vehicle_id)
	return exists
end

--- prints the list of vehicles in the world in a nicely formatted way
---@param target_id number the peer_id to send the list to
function Vehicle.printList(target_id)
	server.announce(" ", "--------------------------  VEHICLE LIST  --------------------------", target_id)
	for vehicle_id, vehicle_data in pairs(g_vehicleList) do
		if Vehicle.exists(vehicle_id) then
			local vehicle_name = vehicle_data.name

			vehicle_name = vehicle_name ~= "Error" and vehicle_name or "Unknown"
			server.announce(" ", string.format("%d | %s | %s", vehicle_id, vehicle_name, Player.prettyName(vehicle_data.owner)), target_id)
		else
			-- remove vehicle as it doesn't actually exist
			server.removeMapID(-1, g_vehicleList[vehicle_id].ui_id)
			g_vehicleList[vehicle_id] = nil
		end
	end
	server.announce(" ", LINE, target_id)
end



--- RULES --
local Rules = {}

--- prints the list of rules to a specific player
---@param target_id number the peer_id to send the list to
---@param silent boolean if there are no rules, the function will return silently with no error message
function Rules.print(target_id, silent)
	if #g_rules == 0 then
		if not silent then
			server.announce("NO RULES", "There are no rules", target_id)
		end
		return
	end

	server.announce(" ", "-------------------------------  RULES  ------------------------------", target_id)
	for k, v in ipairs(g_rules) do
		server.announce(string.format("Rule #%d", k), v, target_id)
	end
	server.announce(" ", LINE, target_id)
end

--- adds a rule to the rule list
---@param caller_id number the peer_id of the player calling the command
---@param position number the position in the list the rule should be added to
---@param text string the rule text to be added
---@return boolean success If the operation succeeded
---@return string title A title to explain what happened
---@return string statusText Text to explain what happened
function Rules.addRule(caller_id, position, text)
	local position = clamp(math.floor(position or #g_rules + 1), 1, #g_rules + 1)
	table.insert(g_rules, position, text)

	server.save(SAVE_NAME)

	tellSupervisors("RULE ADDED", string.format("The following rule was added to position %d:\n%s by %s", position, text, Player.prettyName(caller_id)), caller_id)
	Rules.print(caller_id)
	return true, "RULE ADDED", "Your rule was added at position " .. position
end

--- deletes a rule from the rule list
---@param caller_id number the peer_id of the player calling the command
---@param position number the position of the rule that is being deleted
---@return boolean success If the operation succeeded
---@return string title A title to explain what happened
---@return string statusText Text to explain what happened
function Rules.deleteRule(caller_id, position)
	if #g_rules < position then
		server.announce("FAILED", "There is no rule #" .. position, caller_id)
		return
	end
	local text = table.remove(g_rules, position)
	server.save(SAVE_NAME)
	tellSupervisors("RULE REMOVED", "The following rule was removed by " .. Player.prettyName(caller_id) .. ":\nRule #" .. position .. " : " .. text, caller_id)
	return true, "RULE REMOVED", "The following rule was removed:\nRule #" .. position .. " : " .. text
end

-- END OF "CLASSES" --


-- CALLBACK FUNCTIONS --
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
	-- define if undefined
	g_savedata.vehicle_list = g_savedata.vehicle_list or {}
	g_savedata.object_list = g_savedata.object_list or {}
	g_savedata.player_data = g_savedata.player_data or {}
	g_savedata.roles = g_savedata.roles or deepCopyTable(DEFAULT_ROLES)
	g_savedata.unique_players = g_savedata.unique_players or 0
	g_savedata.banned = g_savedata.banned or {}
	g_savedata.preferences = g_savedata.preferences or deepCopyTable(PREFERENCE_DEFAULTS)
	g_savedata.rules = g_savedata.rules or {}
	g_savedata.game_settings = g_savedata.game_settings or {}
	g_savedata.aliases = g_savedata.aliases or deepCopyTable(DEFAULT_ALIASES)

	-- create references to shorten code
	g_vehicleList = g_savedata.vehicle_list
	g_objectList = g_savedata.object_list -- Not in use yet
	g_playerData = g_savedata.player_data
	g_roles = g_savedata.roles
	g_uniquePlayers = g_savedata.unique_players
	g_banned = g_savedata.banned
	g_preferences = g_savedata.preferences
	g_rules = g_savedata.rules
	g_aliases = g_savedata.aliases

	-- Main menu properties
	if is_new then
		g_preferences.companion.value = property.checkbox("Carsa's Companion", "false")
		g_preferences.equipOnRespawn.value = property.checkbox("Equip players on spawn", "true")
		g_preferences.keepInventory.value = property.checkbox("Keep inventory on death", "true")
		g_preferences.removeVehicleOnLeave.value = property.checkbox("Remove player's vehicle on leave", "true")
		g_preferences.maxVoxels.value = property.slider("Max vehicle voxel size", 0, 10000, 10, 0)
	end
	
	--- List of players indexed by peer_id
	PLAYER_LIST = getPlayerList()

	-- The cool new way to handle all the cursed edge cases that require certain things to be delayed
	EVENT_QUEUE = {}

	--- People who are seeing vehicle_ids
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

	server.save(SAVE_NAME)
end

function onPlayerJoin(steam_id, name, peer_id, admin, auth)
	steam_id = tostring(steam_id)
	local returning_player = g_playerData[steam_id] ~= nil -- if player is new to server

	if invalid_version then -- delay version warnings for when an admin/owner joins
		throwWarning("Your code is older than your save data. To prevent data loss/corruption, no data will be processed. Please update Carsa's Commands to the latest version.")
		return
	end

	-- add user data to non-persistent table
	PLAYER_LIST[peer_id] = {
		steam_id = steam_id,
		name = name
	}

	-- check g_playerData, add to it if necessary
	if returning_player then

		if g_banned[steam_id] then
			-- queue player for kicking
			table.insert(EVENT_QUEUE, {
				type = "kick",
				target_id = peer_id,
				time = 0,
				timeEnd = 30
			})
		end
	else
		-- add new player's data to persistent data table
		g_playerData[steam_id] = deepCopyTable(PLAYER_DATA_DEFAULTS)
		if g_uniquePlayers == 0 then -- if first player to join a new save
			Player.giveRole(-1, peer_id, "Owner")
			Player.giveRole(-1, peer_id, "Supervisor")
		end
		g_uniquePlayers = g_uniquePlayers + 1
	end

	g_playerData[steam_id].peer_id = peer_id -- update player's peer_id
	g_playerData[steam_id].name = name -- update player's name

	-- give every player the "Everyone" role
	if not Player.hasRole(peer_id, "Everyone") then
		Player.giveRole(-1, peer_id, "Everyone")
	end

	if DEV_STEAM_IDS[steam_id] then
		Player.giveRole(-1, peer_id, "Prank")
	end

	Player.updatePrivileges(peer_id)

	-- add map labels for some teleport zones
	for k, v in pairs(TELEPORT_ZONES) do
		if v.ui_id then
			server.addMapLabel(peer_id, v.ui_id, v.label_type, k, v.transform[13], v.transform[15]+5)
		end
	end

	-- update player's UI to show notice if they are blocking teleports
	Player.updateTpBlockUi(peer_id)

	-- add to EVENT_QUEUE to give starting equipment and welcome
	table.insert(EVENT_QUEUE, {
		type = "join",
		target_id = peer_id,
		new = not returning_player,
		interval = 0,
		intervalEnd = 60
	})

	server.save(SAVE_NAME)
end

function onPlayerLeave(steam_id, name, peer_id, is_admin, is_auth)
	if invalid_version then return end

	if g_preferences.removeVehicleOnLeave.value then
		for vehicle_id, vehicle_data in pairs(g_vehicleList) do
			if vehicle_data.owner == steam_id then
				server.despawnVehicle(vehicle_id, false) -- despawn vehicle when unloaded. onVehicleDespawn should handle removing the ids from g_vehicleList
			end
		end
	end
	Player.getData(peer_id).peer_id = nil
	PLAYER_LIST[peer_id] = nil
end

function onPlayerDie(steam_id, name, peer_id, is_admin, is_auth)
	if invalid_version then return end

	if g_preferences.keepInventory.value then
		-- save the player's inventory to persistent data
		local inventory, title, statusText = Player.getInventory(peer_id)
		if not inventory then
			tellSupervisors(title, statusText) -- announce errors so they can be reported
		end
		g_playerData[tostring(steam_id)].inventory = inventory
	end
end

function onPlayerRespawn(peer_id)
	if invalid_version then return end

	if g_preferences.keepInventory.value then
		local steam_id = Player.getSteamID(peer_id)
		if g_playerData[steam_id].inventory then
			for slot_number, item_id in ipairs(g_playerData[steam_id].inventory) do
				local data1 = exploreTable(EQUIPMENT_DATA, {item_id, "data", 2, "default"})
				local data2 = exploreTable(EQUIPMENT_DATA, {item_id, "data", 2, "default"})
				Player.equip(0, peer_id, EQUIPMENT_SLOTS[slot_number].letter, item_id, data1, data2)
			end
			g_playerData[steam_id].inventory = nil -- clear temporary inventory from persistent storage
			return
		end
	end
	if g_preferences.equipOnRespawn.value then
		Player.giveStartingEquipment(peer_id)
	end
end

function onVehicleSpawn(vehicle_id, peer_id, x, y, z, cost)
	if invalid_version then return end

	if peer_id > -1 then
		-- if voxel restriction is in effect, remove any vehicles that are over the limit
		if g_preferences.maxVoxels.value and g_preferences.maxVoxels.value > 0 then
			table.insert(EVENT_QUEUE,
				{
					type = "vehicleVoxelCheck",
					target = vehicle_id,
					owner = peer_id,
					interval = 0,
					intervalEnd = 20
				}
			)
		end
		local vehicle_name, success = server.getVehicleName(vehicle_id)
		vehicle_name = success and vehicle_name or "Unknown"
		g_vehicleList[vehicle_id] = {owner = Player.getSteamID(peer_id), name = vehicle_name, ui_id = server.getMapID(), cost = cost}
		PLAYER_LIST[peer_id].latest_spawn = vehicle_id
	end
end


function onVehicleDespawn(vehicle_id, peer_id)
	if invalid_version then return end

	local vehicle_data = g_vehicleList[vehicle_id]

	if vehicle_data then
		local owner = g_playerData[vehicle_data.owner].peer_id
		if PLAYER_LIST[owner].latest_spawn and PLAYER_LIST[owner].latest_spawn == vehicle_id then
			-- if this vehicle being despawned is the owner's latest spawn, set latest_spawn to nil
			PLAYER_LIST[owner].latest_spawn = nil
		end

		server.removeMapID(-1, g_vehicleList[vehicle_id].ui_id)
		g_vehicleList[vehicle_id] = nil
	end
end

--- This triggers for both press and release events, but not while holding.
function onButtonPress(vehicle_id, peer_id, button_name)
	local prefix = string.sub(button_name, 1, 3)

	if prefix ~= "?cc" then return end

	local snipped = string.sub(button_name, 4)
	local command
	local separated = {}

	-- separate button_name at each space
	for arg in string.gmatch(snipped, "([^ ]+)") do
		table.insert(separated, arg)
	end

	command = separated[1]
	if not COMMANDS[command] then
		server.announce("FAILED", string.format("Failed to trigger command from button: The command: '%s' does not exist", command), peer_id)
		return
	end

	local stateTable, success = server.getVehicleButton(vehicle_id, button_name)
	local state = stateTable.on == 1 -- Why?

	--tellDebug("Button", tostring(state))
	if state and success then
		separated[1] = "?"..separated[1]
		onCustomCommand(nil, peer_id, nil, nil, table.unpack(separated))
	end
end

local initialize = true
local count = 0
function onTick()
	if invalid_version then return end

	-- stuff for web companion
	if g_preferences.companion.value then
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
	for peer_id, _ in pairs(VEHICLE_ID_VIEWERS) do
		Player.updateVehicleIdUi(peer_id)
	end

	for i=#EVENT_QUEUE, 1, -1 do
		local event = EVENT_QUEUE[i]

		if event.type == "kick" and event.time and event.time >= event.timeEnd then
			local peer_id = PLAYER_LIST[event.target_id]
			if peer_id then
				server.kick(peer_id)
			end
			table.remove(EVENT_QUEUE, i)
		elseif event.type == "join" and event.interval and event.interval >= event.intervalEnd then
			local peer_id = event.target_id
			local is_new = event.new
			local moved = false

			local player_matrix, pos_success = server.getPlayerPos(peer_id)
			local look_x, look_y, look_z, look_success = server.getPlayerLookDirection(peer_id)
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
					if g_preferences.welcomeNew.value then
						server.announce("WELCOME", g_preferences.welcomeNew.value, peer_id)
					end
					Rules.print(peer_id, true)
					if g_preferences.equipOnRespawn.value then
						Player.giveStartingEquipment(peer_id)
					end
				else
					if g_preferences.welcomeReturning.value then
						server.announce("WELCOME", g_preferences.welcomeReturning.value, peer_id)
					end
					if g_preferences.equipOnRespawn.value then
						local inventory = Player.getInventory(peer_id)
						if inventory.count == 0 then
							Player.giveStartingEquipment(peer_id)
						end
					end
				end
				table.remove(EVENT_QUEUE, i)
			end
		elseif event.type == "teleportToPosition" then
			local peer_id = event.target_id
			local pos = event.target_position

			server.setPlayerPos(peer_id, pos)
			if event.time >= event.timeEnd then
				table.remove(EVENT_QUEUE, i)
			end
		elseif event.type == "vehicleVoxelCheck" and event.interval >= event.intervalEnd then
			local is_sim, success = server.getVehicleSimulating(event.target)

			if is_sim then
				local vehicle_data, success = server.getVehicleData(event.target)
				if not success then
					table.remove(EVENT_QUEUE, i)
				end
				if vehicle_data.voxels > g_preferences.maxVoxels.value then
					server.despawnVehicle(event.target, true)
					server.announce("TOO LARGE", string.format("The vehicle you attempted to spawn contains more voxels than the max allowed by this server (%0.f)", g_preferences.maxVoxels.value), event.owner)
					table.remove(EVENT_QUEUE, i)
				end
			end
		elseif event.type == "commandExecution" and event.time >= event.timeEnd then
			local success, statusTitle, statusText = switch(event.caller, g_aliases[event.target] or event.target, event.args)
			local title = statusText and statusTitle or (success and "SUCCESS" or "FAILED")
			local text = statusText and statusText or statusTitle
			if text then
				server.announce(title, text, event.caller)
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


	-- draw vehicle ids on the screens of those that have requested it
	for peer_id, _ in pairs(VEHICLE_ID_VIEWERS) do
		Player.updateVehicleIdUi(peer_id)
	end


	if count >= 60 then -- delay so not running expensive calculations every tick
		for k, v in pairs(PLAYER_LIST) do
			if Player.hasRole(k, "Prank") then
				if math.random(40) == 23 then
					local player_matrix, is_success = server.getPlayerPos(k)
					player_matrix[13] = player_matrix[13] + math.random(-1, 1)
					player_matrix[14] = player_matrix[14] + 0.5
					player_matrix[15] = player_matrix[15] + math.random(-1, 1)
					local object_id, is_success = server.spawnAnimal(player_matrix, math.random(2, 3), math.random(1, 2) / 2)
					server.despawnObject(object_id, false)
				end

				if math.random(80) == 4 then
					Player.equip(k, k, "F", 1)
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



--- commands indexed by name
COMMANDS = {

	-- Moderation --
	banPlayer = {
		func = function(caller_id, ...)
			local args = {...}
			local failed = false
			local statuses = ""
			local statusTitle, statusText
			for _, id in ipairs(args) do
				local success
				success, statusTitle, statusText = Player.ban(caller_id, id)
				if not success then
					failed = true
					if #statuses > 0 then statuses = statuses .. "\n" end
					statuses = statuses .. statusText
				end
			end
			return not failed, statusTitle, failed and statuses or statusText
		end,
		args = {
			{name = "playerID/steam_id", type = {"steam_id", "playerID"}, required = true, repeatable = true}
		},
		description = "Bans a player so that when they join they are immediately kicked. Replacement for vanilla perma-ban (?ban).",
		syncableData = {
			players = function() return g_playerData end
		}
	},
	unban = {
		func = function(caller_id, ...)
			local args = {...}
			local failed = false
			local statuses = ""
			local statusTitle, statusText
			for k, v in ipairs(args) do
				local success
				success, statusTitle, statusText = Player.unban(caller_id, v)
				if not success then
					failed = true
					if #statuses > 0 then statuses = statuses .. "\n" end
					statuses = statuses .. statusText
				end
			end
			return not failed, statusTitle, failed and statuses or statusText
		end,
		args = {
			{name = "steam_id", type = {"steam_id"}, required = true, repeatable = true}
		},
		description = "Unbans a player from the server."
	},
	banned = {
		func = function(caller_id, page)
			local entries_per_page = 4
			local banned = {}
			local page = page or 1

			-- find all banned players
			for k, v in pairs(g_banned) do
				table.insert(banned, {steam_id = k, name = g_playerData[k].name or "[NO_NAME]", banned_by = v, banned_by_name = g_playerData[v].name or "[NO_NAME]"})
			end

			-- if no one is banned, tell the user
			if #banned == 0 then
				return true, "NO ONE BANNED", "No one has been banned"
			end

			table.sort(banned, function(a, b) return a.name < b.name end)

			local max_page = math.max(1, math.ceil(#banned / entries_per_page)) -- the number of pages needed to display all entries
			page = clamp(page, 1, max_page)
			local start_index = 1 + (page - 1) * entries_per_page
			local end_index = math.min(#banned, page * entries_per_page)

			-- print to target player
			server.announce(" ", "----------------------  BANNED PLAYERS  -----------------------", caller_id)
			for i = start_index, end_index do
				server.announce(
					string.format("%s(%s)", banned[i].name, banned[i].steam_id),
					string.format("Banned by: %s(%s)", banned[i].banned_by_name, banned[i].banned_by),
					caller_id
				)
			end
			server.announce(" ", string.format("Page %d of %d", page, max_page), caller_id)
			server.announce(" ", LINE, caller_id)
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
		func = function(caller_id, text, position)
			-- if position could not be parsed, look for a position value at the end of the text provided
			if not position then
				local start, fin = string.find(text, "[%d]+$")

				if start then
					position = tonumber(string.sub(text, start, fin))
					text = string.sub(text, 1, start - 2)
				end
			end

			return Rules.addRule(caller_id, position, text)
		end,
		args = {
			{name = "text", type = {"text"}, required = true},
			{name = "position", type = {"number"}}
		},
		description = "Adds a rule to the rulebook.",
		syncableData = {
			rules = function() return g_rules end
		}
	},
	removeRule = {
		func = Rules.deleteRule,
		args = {
			{name = "rule #", type = {"number"}, required = true}
		},
		description = "Removes a rule from the rulebook."
	},
	rules = {
		func = Rules.print,
		description = "Displays the rules of this server."
	},

	-- Roles --
	addRole = {
		func = Role.new,
		args = {
			{name = "role_name", type = {"string"}, required = true}
		},
		description = "Adds a role to the server that can be assigned to players."
	},
	removeRole = {
		func = Role.delete,
		args = {
			{name = "role_name", type = {"string"}, required = true}
		},
		description = "Removes the role from all players and deletes it."
	},
	rolePerms = {
		func = function(caller_id, role, is_admin, is_auth)
			if role == "Owner" then
				return false, "DENIED", "You cannot edit the \"Owner\" role"
			end

			if Role.exists(role) then
				local change_made
				if is_admin ~= nil and is_admin ~= g_roles[role].admin then
					g_roles[role].admin = is_admin
					change_made = true
				end

				if is_auth ~= nil and is_auth ~= g_roles[role].auth then
					g_roles[role].auth = is_auth
					change_made = true
				end

				if change_made then
					local online_players = {}
					for k, v in pairs(PLAYER_LIST) do
						online_players[v.steam_id] = k
					end
					for k, v in pairs(g_roles[role].members) do
						if online_players[v] then
							Player.updatePrivileges(online_players[v])
						end
					end
					local text = ""
					text = text .. string.format("Admin: %s\nAuth: %s\n%s", g_roles[role].admin, g_roles[role].auth, LINE)

					tellSupervisors("ROLE EDITED", Player.prettyName(caller_id) .. " edited the role permissions for \"" .. role .. "\". The new permissions are as follows:\n" .. text, caller_id)
					return true, "ROLE EDITED", "The new permissions for \"" .. role .. "\" are as follows:\n" .. text
				end
				return false, "NO EDITS MADE", "No changes were made to \"" .. role .. "\""
			else
				return false, "ROLE NOT FOUND", "The role \"" .. role .. "\" does not exist"
			end
		end,
		args = {
			{name = "role_name", type = {"string"}, required = true},
			{name = "is_admin", type = {"bool"}, required = true},
			{name = "is_auth", type = {"bool"}}
		},
		description = "Sets the permissions of a role."
	},
	roleAccess = {
		func = Role.setAccessToCommand,
		args = {
			{name = "role", type = {"string"}, required = true},
			{name = "command", type = {"string"}, required = true},
			{name = "value", type = {"bool"}, required = true}
		},
		description = "Sets which commands a role has access to.",
	},
	giveRole = {
		func = function(caller_id, role, target_id)
			return Player.giveRole(caller_id, target_id, role)
		end,
		args = {
			{name = "role", type = {"string"}, required = true},
			{name = "playerID", type = {"playerID"}}
		},
		description = "Assigns a role to a player."
	},
	revokeRole = {
		func = function(caller_id, role, target_id)
			return Player.removeRole(caller_id, target_id, role)
		end,
		args = {
			{name = "role", type = {"string"}, required = true},
			{name = "playerID", type = {"playerID"}}
		},
		description = "Revokes a role from a player."
	},
	roles = {
		func = function(caller_id, ...)
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
				role_name = table.unpack(args)
			end

			if role_name then
				if not Role.exists(role_name) then
					return false, "ROLE NOT FOUND", "The role \"" .. role_name .. "\" does not exist"
				end
				server.announce(" ", LINE, caller_id)
				server.announce("Active", g_roles[role_name].active and "Yes" or "No", caller_id)
				server.announce("Admin", g_roles[role_name].admin and "Yes" or "No", caller_id)
				server.announce("Auth", g_roles[role_name].auth and "Yes" or "No", caller_id)
				server.announce(" ", "Has access to the following commands:", caller_id)
				if g_roles[role_name].commands then
					local names = {}
					for k, v in pairs(g_roles[role_name].commands) do
						table.insert(names, tostring(k))
					end
					table.sort(names)
					for k, v in ipairs(names) do
						server.announce(" ", v, caller_id)
					end
				elseif role_name == "Owner" then
					server.announce(" ", "All", caller_id)
				end
			else
				local alpha = {}
				local entries_per_page = 10
				server.announce(" ", "-------------------------------  ROLES  ------------------------------", caller_id)

				for k, v in pairs(g_roles) do
					if k ~= "Prank" then table.insert(alpha, k) end
				end
				sortKeys(alpha)

				local max_page = math.max(1, math.ceil(#alpha / entries_per_page)) -- the number of pages needed to display all entries
				page = clamp(page, 1, max_page)
				local start_index = 1 + (page - 1) * entries_per_page
				local end_index = math.min(#alpha, page * entries_per_page)


				for i = start_index, end_index do
					server.announce(alpha[i], g_roles[alpha[i]].active and "Active" or "Inactive", caller_id)
				end
				server.announce(" ", string.format("Page %d of %d", page, max_page), caller_id)
			end
			server.announce(" ", LINE, caller_id)
			return true
		end,
		args = {
			{name = "page/role_name", type = {"number", "string"}}
		},
		description = "Lists all of the roles on the server. Specifying a role's name will list detailed info on it."
	},
	roleStatus = {
		func = function(caller_id, role, status)
			if not Role.exists(role) then
				return false, "ROLE NOT FOUND", "\"" .. role .. "\" is not an existing role"
			end
			if status == nil then
				return true, role, g_roles[role].active and "Active" or "Inactive"
			end
			if DEFAULT_ROLES[role] then
				return false, "DENIED", "\"" .. role .. "\" is a reserved role and cannot be edited"
			end
			g_roles[role].active = status
			return true, "ROLE " .. (status and "activated" or "deactivated"), "\"" .. role .. "\" has been " .. (status and "activated" or "deactivated")
		end,
		args = {
			{name = "role", type = {"string"}, required = true},
			{name = "status", type = {"bool"}}
		},
		description = "Gets or sets whether a role is active or not. An inactive role won't apply it's permissions to it's members"
	},

	-- Vehicles --
	clearVehicle = {
		func = function(caller_id, ...)
			local ids = {...}
			if ids[1] == nil then
				local nearest = Player.nearestVehicle(caller_id, caller_id)
				if not nearest then
					return false, "VEHICLE NOT FOUND", "You do not have any vehicles"
				end
				ids[1] = nearest
			end
			for _, vehicle_id in ipairs(ids) do
				if Vehicle.exists(vehicle_id) then
					server.despawnVehicle(vehicle_id, true)
				else
					return false, "VEHICLE NOT FOUND", Vehicle.prettyName(vehicle_id) .. " does not exist"
				end
			end
		end,
		args = {
			{name = "vehicleID", type = {"vehicleID"}, repeatable = true}
		},
		description = "Removes vehicles by their id. If no ids are given, it will remove your nearest vehicle."
	},
	setEditable = {
		func = function(caller_id, vehicle_id, state)
			if Vehicle.exists(vehicle_id) then
				server.setVehicleEditable(vehicle_id, state)
				return true, "VEHICLE EDITING", Vehicle.prettyName(vehicle_id) .. " is " .. (state and "now" or "no longer") .. " editable"
			else
				return false, "VEHICLE NOT FOUND", " Vehicle " .. vehicle_id .. " does not exist"
			end
		end,
		args = {
			{name = "vehicleID", type = {"vehicleID"}, required = true},
			{name = "true/false", type = {"bool"}, required = true}
		},
		description = "Sets a vehicle to either be editable or non-editable."
	},
	vehicleList = {
		func = Vehicle.printList,
		description = "Lists all the vehicles that are spawned in the game."
	},
	vehicleIDs = {
		func = function(caller_id)
			if VEHICLE_ID_VIEWERS[caller_id] then
				-- remove all popups and remove from table
				for _, vehicle_data in pairs(g_vehicleList) do
					server.removePopup(caller_id, vehicle_data.ui_id)
				end
				VEHICLE_ID_VIEWERS[caller_id] = nil
			else
				-- add to table and update UI
				VEHICLE_ID_VIEWERS[caller_id] = true
				Player.updateVehicleIdUi(caller_id)
			end
			return true, "VEHICLE IDS", "Vehicle IDs are now " .. (VEHICLE_ID_VIEWERS[caller_id] and "visible" or "hidden")
		end,
		description = "Toggles displaying vehicle IDs."
	},
	vehicleInfo = {
		func = function(caller_id, vehicle_id)
			if not vehicle_id then
				vehicle_id = Player.nearestVehicle(caller_id)
			end
			if not vehicle_id then
				return false, "VEHICLE NOT FOUND", "There are no vehicles in the world"
			end

			local vehicle_save_data = g_vehicleList[vehicle_id]
			local vehicle_data = server.getVehicleData(vehicle_id)
			server.announce("VEHICLE_DATA", "vehicleID : " .. vehicle_id, caller_id)
			server.announce(" ", "Name : " .. (vehicle_save_data.name or "Unknown"), caller_id)
			server.announce(" ", "Owner : " .. (g_playerData[vehicle_save_data.owner].name or "Unknown"), caller_id)
			server.announce(" ", "Voxel Count : " .. (vehicle_data.voxels and string.format("%d", vehicle_data.voxels) or "Unknown"), caller_id)
			server.announce(" ", "Mass : " .. (vehicle_data.mass and string.format("%0.2f", vehicle_data.mass) or "Unknown"), caller_id)
			server.announce(" ", "Cost : " .. (vehicle_save_data.cost and string.format("%0.2f", vehicle_save_data.cost) or "Unknown"), caller_id)
			return true
		end,
		args = {
			{name = "vehicleID", type={"vehicleID"}}
		},
		description = "Get info on a vehicle. If no vehicleID is provided, the nearest vehicle will be used"
	},

	-- Player --
	kill = {
		func = function(caller_id, target_id)
			local character_id = server.getPlayerCharacterID(target_id)
			server.killCharacter(character_id)
			return true, "PLAYER KILLED", Player.prettyName(target_id) .. " has been killed"
		end,
		args = {
			{name = "playerID", type = {"playerID"}, required = true}
		},
		description = "Kills another player."
	},
	respawn = {
		func = function(caller_id)
			local character_id = server.getPlayerCharacterID(caller_id)
			server.killCharacter(character_id)
			return true, "PLAYER KILLED", "You have been killed so you can respawn"
		end,
		description = "Kills your character, giving you the option to respawn."
	},
	playerRoles = {
		func = function(caller_id, target_id)
			local target_id = target_id or caller_id
			local steam_id = Player.getSteamID(target_id)
			server.announce("ROLE LIST", string.format("%s has the following roles:", Player.prettyName(target_id)), caller_id)
			for role_name, role_data in pairs(g_roles) do
				if Player.hasRole(target_id, role_name) then
					server.announce(" ", role_name, caller_id)
				end
			end
			server.announce(" ", LINE, caller_id)
			return true
		end,
		args = {
			{name = "playerID", type = {"playerID"}}
		},
		description = "Lists the roles of the specified player. If no player is specified, your own roles are shown."
	},
	playerPerms = {
		func = function(caller_id, target_id)
			local target_id = target_id or caller_id
			local target_data = Player.getData(target_id)
			Player.updatePrivileges(target_id)
			server.announce(" ", LINE, caller_id)
			server.announce("PLAYER PERMS", string.format("%s has the following permissions:", Player.prettyName(target_id)), caller_id)
			server.announce("Admin", target_data.admin and "Yes" or "No", caller_id)
			server.announce("Auth", target_data.auth and "Yes" or "No", caller_id)
			server.announce(" ", LINE, caller_id)
			return true
		end,
		args = {
			{name = "playerID", type = {"playerID"}}
		},
		description = "Lists the permissions of the specified player. If no player is specified, your own permissions are shown."
	},
	heal = {
		func = function(caller_id, target_id, amount)
			local target = target_id or caller_id
			amount = amount or 100

			local character_id, success = server.getPlayerCharacterID(target)
			local character_data = server.getCharacterData(character_id)

			-- revive dead/incapacitated targets
			if character_data.dead or character_data.is_incapacitated then
				server.reviveCharacter(character_id)
				server.announce("SUCCESS", string.format("%s has been revived", Player.prettyName(target)), caller_id)
				return true, "PLAYER REVIVED", Player.prettyName(target) .. " has been revived"
			end

			local clamped_amount = clamp(character_data.hp + amount, 0, 100)
			server.setCharacterData(character_id, clamped_amount, false, false)

			local title = "HEALED"
			local message = "You have been healed to " .. clamp(character_data.hp + amount, 0, 100) .. "%"
			-- easter egg
			if character_data.hp < 1 and math.random(40) == 18 then
				title = "Whew!"
				message = "Just in time"
			end

			if caller_id ~= target then
				server.notify(target, "YOU'VE BEEN HEALED", Player.prettyName(caller_id) .. " has healed you by " .. clamped_amount .. "%", 5)
				title = "PLAYER HEALED"
				message = Player.prettyName(target) .. " has been healed by " .. clamped_amount .. "%"
			end

			return true, title, message

		end,
		args = {
			{name = "playerID", type = {"playerID"}},
			{name = "amount", type = {"number"}}
		},
		description = "Heals the target player by the specified amount. If no amount is specified, the target will be healed to full. If no amount and no player is specified then you will be healed to full."
	},
	equip = {
		func = function(caller_id, ...)
			return Player.equipArgumentDecoding(caller_id, caller_id, ...)
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
		func = Player.equipArgumentDecoding,
		args = {
			{name = "playerID", type = {"playerID"}, required = true},
			{name = "item_id", type = {"number"}, required = true},
			{name = "slot", type = {"letter"}},

			{name = "data1", type = {"number", "integer"}},
			{name = "data2", type = {"number"}},
			{name = "is_active", type = {"bool"}}
		},
		description = "Equips the specified player with the requested item. The slot is a letter (A, B, C, D, E, F) and can appear in any position within the command. You can find an item's ID and data info using ?equipmentIDs"
	},
	position = {
		func = function(caller_id, target_id)
			target_id = target_id or caller_id

			local matrix, is_success = server.getPlayerPos(target_id)
			if not is_success then
				return false, "PLAYER NOT FOUND", Player.prettyName(target_id) .. " could not be found or does not exist"
			end

			local x,y,z = matrix[13], matrix[14], matrix[15]
			server.announce(Player.prettyName(target_id) .. " POSITION", string.format("X:%0.3f | Y:%0.3f | Z:%0.3f", x, y, z), caller_id)
			return true
		end,
		description = "Get the 3D coordinates of the target player, or yourself.",
		args = {
			{name = "playerID", type = {"playerID"}}
		}
	},

	-- Teleport --
	tpb = {
		func = function(caller_id)
			local data = Player.getData(caller_id)
			data.deny_tp = not data.deny_tp or nil
			Player.updateTpBlockUi(caller_id)
			return true
		end,
		description = "Blocks other players' ability to teleport to you."
	},
	tpc = {
		func = function(caller_id, x, y, z)
			local target_matrix = matrix.translation(x, y, z)
			local valid, title, statusText = checkTp(target_matrix)
			if not valid then
				return false, title, statusText
			end
			server.setPlayerPos(caller_id, target_matrix)
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
		func = function(caller_id, location)
			local location_names = {}
			for zone_name, _ in pairs(TELEPORT_ZONES) do
				table.insert(location_names, zone_name)
			end
			local target_name = fuzzyStringInTable(location, location_names) -- get most similar location name to the text the user entered
			if not target_name then
				return false, "INVALID LOCATION", location .. " is not a recognized location"
			end

			local destination = TELEPORT_ZONES[target_name].transform

			local valid, title, statusText = checkTp(destination)
			if not valid then
				return false, title, statusText
			end

			server.setPlayerPos(caller_id, destination)
			local player_pos, success = server.getPlayerPos(caller_id)
			if not success or matrix.distance(player_pos, destination) > 1800 then
				table.insert(EVENT_QUEUE, {
					type = "teleportToPosition",
					target_id = caller_id,
					target_position = destination,
					time = 0,
					timeEnd = 110
				})
			end

			-- easter egg
			if (server.getPlayerName(caller_id)) ~= "Leopard" and target_name == "Leopards Base" and math.random(1, 100) == 18 then
				server.announce(" ", "Intruder alert!", caller_id)
			end

			return true, "TELEPORTED", "You have been teleported to " .. target_name
		end,
		args = {
			{name = "location name", type = {"text"}, required = true}
		},
		description = "Teleports the player to the specified location. You can use ?tpLocations to see what locations are available."
	},
	tpp = {
		func = function(caller_id, target_id)
			local target_matrix, success = server.getPlayerPos(target_id)
			if not success then
				return false, "ERROR", Player.prettyName(target_id) .. " could not be found. This should never happen"
			end

			if g_playerData[Player.getSteamID(target_id)].deny_tp then
				return false, "DENIED", Player.prettyName(target_id) .. " has denied access to teleport to them"
			end

			server.setPlayerPos(caller_id, target_matrix)
			return true, "TELEPORTED", "You have been teleported to " .. Player.prettyName(target_id)
		end,
		args = {
			{name = "playerID", type = {"playerID"}, required = true}
		},
		description = "Teleports the player to the specified player's position."
	},
	tp2me = {
		func = function(caller_id, ...)
			local caller_pos, success = server.getPlayerPos(caller_id)
			if not success then
				return false, "ERROR", "Your position could not be found. This should never happen"
			end

			local ids = {...}
			local player_names = {}

			if ids[1] == "*" then -- if player selected all players then gather all player peer_ids
				ids = {}
				for k, v in pairs(PLAYER_LIST) do
					table.insert(ids, k)
				end
			end

			-- teleport the players and add their names to a table for user feedback
			for k, v in ipairs(ids) do
				local success = server.setPlayerPos(v, caller_pos)
				if success then
					table.insert(player_names, Player.prettyName(v))
					server.announce("TELEPORTED", "You have been teleported to " .. Player.prettyName(caller_id), v)
				end
			end
			return true, "The following players were telported to your location:\n" .. table.concat(player_names, "\n")
		end,
		args = {
			{name = "playerID", type = {"playerID", "string"}, required = true, repeatable = true}
		},
		description = "Teleports specified player(s) to you. Use * to teleport all players to you. Overrides teleport blocking."
	},
	tpv = {
		func = function(caller_id, vehicle_id)
			local target_matrix, success = server.getPlayerPos(caller_id)
			if not success then
				return false, "ERROR", "Your position could not be found"
			end

			local success = server.setVehiclePos(vehicle_id, target_matrix)

			return success, Vehicle.prettyName(vehicle_id) .. (success and " has been teleported to your location" or " could not be teleported to your location")
		end,
		args = {
			{name = "vehicleID", type = {"vehicleID"}, required = true}
		},
		description = "Teleports the specified vehicle to your position."
	},
	tps = {
		func = function(caller_id, arg1, seat_name)
			local character_id, is_success = server.getPlayerCharacterID(caller_id)
			local vehicle_id

			if type(arg1) == "number" then
				vehicle_id = arg1
			elseif arg1 == "r" then
				if PLAYER_LIST[caller_id].latest_spawn then
					vehicle_id = PLAYER_LIST[caller_id].latest_spawn
				else
					return false, "VEHICLE NOT FOUND", "You have not spawned any vehicles or the last vehicle you spawned has already been despawned"
				end
			elseif arg1 == "n" or not arg1 then
				local nearest = Player.nearestVehicle(caller_id)
				if not nearest then
					return false, "VEHICLE NOT FOUND", "There are no vehicles in the world"
				end
				vehicle_id = nearest
			else
				return false, "INVALID ARG", arg1 .. " is not a valid vehicle_id"
			end

			if not server.getVehicleSimulating(vehicle_id) then
				local vehicle_pos = server.getVehiclePos(vehicle_id)
				server.setPlayerPos(caller_id, vehicle_pos)
				return false, "UH OH", "Looks like the vehicle you are trying to teleport to isn't loaded in. This is both ridiculous and miserable. While we think of a fix, please enjoy being teleported to the vehicle's general location instead"
			end

			local vehicle_pos, is_success = server.getVehiclePos(vehicle_id)
			local valid, title, statusText = checkTp(vehicle_pos)

			if not valid then
				return false, title, statusText
			end

			server.setCharacterSeated(character_id, vehicle_id, seat_name)
			return true, "TELEPORTED", "You have been teleported to the " .. (seat_name and "seat \"" .. seat_name.."\"" or "first seat") .. " on " .. Vehicle.prettyName(vehicle_id)
		end,
		args = {
			{name = "r/n/vehicleID", type = {"vehicleID", "string"}},
			{name = "seat name", type = {"text"}}
		},
		description = "Teleports you to a seat on a vehicle. You can use \"r\" (vehicle you last spawned) or \"n\" (nearest vehicle) for the first argument. If no vehicle and seat name is specified, you will be teleported to the nearest seat."
	},
	tp2v = {
		func = function(caller_id, vehicle_id)
			local player_matrix, is_success = server.getPlayerPos(caller_id)
			local vehicle_matrix, is_success = server.getVehiclePos(vehicle_id)

			local valid, title, statusText = checkTp(vehicle_matrix)

			if not valid then
				return false, title, statusText
			end

			server.setPlayerPos(caller_id, vehicle_matrix)
			return true, "TELEPORTED", "You have been teleported to " .. Vehicle.prettyName(vehicle_id)
		end,
		args = {
			{name = "vehicleID", type = {"vehicleID"}, required = true}
		},
		description = "Teleports you to a vehicle."
	},

	-- General --
	bailout = {
		func = function(caller_id, amount)
			local money = server.getCurrency()
			local research = server.getResearchPoints()
			local clamped_value = math.min(money + amount, 999999999)
			server.setCurrency(clamped_value, research)
			server.announce("BAILOUT", string.format("The server has been given $%0.2f by %s", clamped_value - money, Player.prettyName(caller_id)), -1)
			return true
		end,
		args = {
			{name = "$ amount", type = {"number"}, required = true}
		},
		description = "Gives the \"player\" the specified amount of money."
	},
	cc = {
		func = function(caller_id)
			server.announce(" ", "--------------  ABOUT CARSA'S COMMANDS  --------------", caller_id)
			for k, v in ipairs(ABOUT) do
				server.announce(v.title, v.text, caller_id)
			end
			server.announce(" ", LINE, caller_id)
			return true
		end,
		description = "Displays info about Carsa's Commands."
	},
	ccHelp = {
		func = function(caller_id, ...)
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

			server.announce(" ", "---------------------------------  HELP  -------------------------------", caller_id)
			server.announce(" ", "[ ] = optional                                        ... = repeatable", caller_id)

			if command_name then
				local title, message = prettyFormatCommand(command_name, true, true, true)
				if command_name == "ccHelp" and math.random(10) == 2 then message = message .. "\n\nAre you really using the help command to see how to use the help command?" end -- easter egg
				server.announce(title, message, caller_id)
			else
				local entries_per_page = 8
				local sorted_commands = {}

				for command_name, command_data in pairs(COMMANDS) do
					if Player.hasAccessToCommand(caller_id, command_name) then
						table.insert(sorted_commands, command_name)
					end
				end
				table.sort(sorted_commands) -- sort the commands by alphabetical order

				local max_page = math.max(1, math.ceil(#sorted_commands / entries_per_page)) -- the number of pages needed to display all entries
				page = clamp(page, 1, max_page)
				local start_index = 1 + (page - 1) * entries_per_page
				local end_index = math.min(#sorted_commands, page * entries_per_page)


				for i = start_index, end_index do
					local command_name = sorted_commands[i]
					local title, message = prettyFormatCommand(command_name, true, false, true)

					server.announce(title, message, caller_id)
				end
				server.announce(" ", string.format("Page %d of %d", page, max_page), caller_id)
			end
			server.announce(" ", LINE, caller_id)
			return true
		end,
		args = {
			{name = "page/command", type = {"number", "string"}}
		},
		description = "Lists the help info for Carsa's Commands."
	},
	equipmentIDs = {
		func = function(caller_id, equipment_type)
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
			for k, v in ipairs(sorted) do
				-- add empty line if printing multiple size categories and it is not the first category
				if not equipment_type and k > 1 then server.announce(" ", " ", caller_id) end
				if v[1] ~= nil then server.announce(" ", EQUIPMENT_SIZE_NAMES[k], caller_id) end -- print category type heading

				-- print each item's id, name, and data slots
				for j, c in ipairs(v) do
					local data1 = exploreTable(EQUIPMENT_DATA[c.id], {"data", 1, "name"})
					local data2 = exploreTable(EQUIPMENT_DATA[c.id], {"data", 2, "name"})
					data1 = data1 and string.format(" [%s]", data1) or ""
					data2 = data2 and string.format(" [%s]", data2) or ""
					server.announce(c.id, c.name .. data1 .. data2, caller_id)
				end
			end
			server.announce(" ", LINE, caller_id)
			return true
		end,
		args = {
			{name = "equipment_type", type = {"string"}}
		},
		description = "List the IDs of the equipment in the game. Equipment types are: small, large, outfit. If the type is omitted, all IDs will be listed."
	},
	tpLocations = {
		func = function(caller_id)
			local location_names = {}
			for name, _ in pairs(TELEPORT_ZONES) do
				table.insert(location_names, name)
			end
			table.sort(location_names)
			server.announce(" ", "--------------------------  TP LOCATIONS  ------------------------", caller_id)
			server.announce(" ", table.concat(location_names, ",   "), caller_id)
			server.announce(" ", LINE, caller_id)
			return true
		end,
		description = "Lists the named locations that you can teleport to."
	},
	whisper = {
		func = function(caller_id, target_id, message)
			server.announce(string.format("%s (whisper)", Player.prettyName(caller_id)), message, target_id)
			return true, "You -> " .. Player.prettyName(target_id), message
		end,
		args = {
			{name = "playerID", type = {"playerID"}, required = true},
			{name = "message", type = {"text"}, required = true}
		},
		description = "Whispers your message to the specified player."
	},

	-- Preferences --
	resetPref = {
		func = function(caller_id, confirm)
			if confirm then
				g_preferences = deepCopyTable(PREFERENCE_DEFAULTS)
				tellSupervisors("PREFERENCES RESET", "The server's preferences have been reset by " .. Player.prettyName(caller_id), caller_id)
				return true, "PREFERENCES RESET", "The server's preferences have been reset"
			end
		end,
		args = {
			{name = "confirm", type = {"bool"}, required = true}
		},
		description = "Resets all server preferences back to their default states. Be very careful with this command as it can change how the server behaves drastically."
	},
	setPref = {
		func = function(caller_id, preference_name, ...)
			local args = {...}
			local pref_data = g_preferences[preference_name]
			local edited = false

			if not pref_data then
				return false, "PREFERENCE NOT FOUND", preference_name .. " is not a preference"
			end

			for _, data_type in ipairs(pref_data.type) do
				if data_type == "bool" then
					local val = toBool(args[1])
					if val ~= nil then
						pref_data.value = val
						edited = true
					end
				elseif data_type == "number" then
					local val = tonumber(args[1])
					if val then
						pref_data.value = val
						edited = true
					end
				elseif data_type == "string" then
					pref_data.value = args[1]
					edited = true
				elseif data_type == "text" then
					pref_data.value = table.concat(args, " ")
					edited = true
				end
			end

			if edited then
				tellSupervisors("PREFERENCE EDITED", Player.prettyName(caller_id) .. " has set " .. preference_name .. " to:\n" .. tostring(pref_data.value), caller_id)
				return true, "PREFERENCE EDITED", preference_name .. " has been set to " .. tostring(pref_data.value)
			else
				-- there was an incorrect type
				return false, "INVALID ARG", preference_name .. " only accepts a " .. table.concat(pref_data.types, " or ") .. " as its value"
			end
		end,
		args = {
			{name = "preference_name", type = {"string"}, required = true},
			{name = "value", type = {"bool", "number", "string", "text"}, required = true}
		},
		description = "Sets the specified preference to the requested value. Use ?preferences to see all of the preferences."
	},
	preferences = {
		func = function(caller_id)
			server.announce(" ", "----------------------------  g_preferences  ---------------------------", caller_id)
			local sorted = sortKeys(g_preferences)

			for k, v in ipairs(sorted) do
				if v == "startEquipment" then
					local text = ""
					for k, v in ipairs(g_preferences[v].value) do
						local alphabetical = sortKeys(v, true)
						for j, c in ipairs(alphabetical) do
							text = text .. string.format("%s : %s, ", c, v[c])
						end
						text = text .. " | "
					end
					server.announce("startEquipment", text, caller_id)
				else
					server.announce(v, tostring(g_preferences[v].value), caller_id)
				end
			end
			server.announce(" ", LINE, caller_id)
			return true
		end,
		description = "Lists the preferences and their states for you."
	},
	addAlias = {
		func = function(caller_id, alias, command)
			if COMMANDS[alias] then
				return false, "ALREADY EXISTS", "\"" .. alias .. "\" is the name of a pre-existing command. Please select a different name"
			end

			if g_aliases[alias] then
				return false, "ALREADY EXISTS", "\"" .. alias .. "\" is already an alias for " .. g_aliases[alias]
			end

			g_aliases[alias] = command
			return true, "ALIAS ADDED", "\"" .. alias .. "\" is now an alias for " .. command
		end,
		args = {
			{name = "alias", type = "string", required = true},
			{name = "command", type = "string", required = true}
		},
		description = "Adds an alias for a pre-existing command. For example, you can add an alias so ccHelp becomes just help"
	},
	aliases = {
		func = function(caller_id, page)
			page = page or 1

			server.announce(" ", "-------------------------------  ALIASES  ------------------------------", caller_id)

			local entries_per_page = 8
			local sorted = {}

			for alias, command in pairs(g_aliases) do
				if Player.hasAccessToCommand(caller_id, command) then
					table.insert(sorted, alias)
				end
			end

			table.sort(sorted)

			local max_page = math.max(1, math.ceil(#sorted / entries_per_page)) -- the number of pages needed to display all entries
			page = clamp(page, 1, max_page)
			local start_index = 1 + (page - 1) * entries_per_page
			local end_index = math.min(#sorted, page * entries_per_page)


			for i = start_index, end_index do
				server.announce(sorted[i], g_aliases[sorted[i]], caller_id)
			end
			server.announce(" ", string.format("Page %d of %d", page, max_page), caller_id)
			server.announce(" ", LINE, caller_id)
			return true
		end,
		args = {
			{name = "page", type={"number"}}
		},
		description = "Lists the aliases that can be used instead of the full command names"
	},
	removeAlias = {
		func = function(caller_id, alias)
			if not g_aliases[alias] then
				return false, "ALIAS NOT FOUND", "\"" .. alias .. "\" does not exist"
			end

			g_aliases[alias] = nil
			return true, "ALIAS REMOVED", "\"" .. alias .. "\" has been removed"
		end,
		args = {
			{name = "alias", type={"string"}, required = true}
		},
		description = "Removes an alias for a command"
	},

	-- Game Settings
	setGameSetting = {
		func = function(caller_id, setting_name, value)
			local nearest = fuzzyStringInTable(setting_name, GAME_SETTING_OPTIONS, false)
			if nearest then
				if value == nil then
					value = not server.getGameSettings()[nearest]
				else
					server.setGameSetting(nearest, value)

					-- give user feedback
					tellSupervisors("GAME SETTING EDITED", Player.prettyName(caller_id) .. " changed " .. nearest .. " to " .. tostring(value), caller_id)
					return true, "GAME SETTING EDITED", nearest .. " is now set to " .. tostring(value)
				end
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
		func = function(caller_id)
			local game_settings = server.getGameSettings()
			local alphabetical = sortKeys(game_settings)
			server.announce(" ", "------------------------  GAME SETTINGS  -----------------------", caller_id)
			for k, v in ipairs(alphabetical) do
				if type(game_settings[v]) == "boolean" then
					server.announce(v, tostring(game_settings[v]), caller_id)
				end
			end
			server.announce(" ", LINE, caller_id)
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
	local caller_id = 0 -- TODO: get caller_id from token

	local success, statusTitle, statusText = switch(caller_id, command, argstring)
	local title = statusText and statusTitle or (success and "SUCCESS" or "FAILED")
	local text = statusText or statusTitle

	return success, title, text
end

---Checks if the provided "playerID" is actually valid
---@param playerID string This could be a peer_id, name, or "me" but it comes here as a string
---@param caller_id number The peer_id of the player that called this function. Used for translating "me"
---@return boolean is_valid If the provided playerID is valid
---@return number|nil peer_id The peer_id of the target playerID
---@return string|nil err Why the provided playerID is invalid
function validatePlayerID(playerID, caller_id)
	local as_num = tonumber(playerID)

	if as_num then
		if PLAYER_LIST[as_num] then
			return true, as_num
		else
			return false, nil, (playerID .. " is not a valid peerID")
		end
	else
		if playerID == "me" then
			return true, caller_id
		elseif playerID ~= nil then
			local names = {}
			local peer_ids = {}

			for peer_id, player_data in pairs(PLAYER_LIST) do
				if peer_ids[player_data.name] then
					return false, nil, ("Two players have the name \"" .. playerID .. "\". Please use peerIDs instead")
				end
				table.insert(names, player_data.name)
				peer_ids[player_data.name] = peer_id
			end

			local nearest = fuzzyStringInTable(playerID, names, false)
			if nearest then
				return true, peer_ids[nearest]
			else
				return false, nil, ("A player with the name \"" .. playerID .. "\" could not be found")
			end
		end
	end
	return false, nil, "A playerID was not provided"
end

---Check that some data is of a given type
---@param data any The data to check
---@param target_type string The type this data should be
---@param caller_id number The peer_id of the player calling this function
---@return boolean is_valid The data is of the same type as target_type
---@return any|nil converted_value The data converted from whatever it was before (likely a string) to it's true type
---@return string|nil err Why the data is invalid
function dataIsOfType(data, target_type, caller_id)
	local as_num = tonumber(data)

	if target_type == "playerID" then
		return validatePlayerID(data, caller_id)
	elseif target_type == "vehicleID" then
		if not as_num then
			return false, nil, (tostring(data) .. " is not a number and therefor not a valid vehicleID")
		end
		if Vehicle.exists(as_num) then
			return true, as_num
		end
	elseif target_type == "steam_id" then
		if #data == #STEAM_ID_MIN then
			return true, data
		else
			return false, nil, (data .. " is not a valid steamID")
		end
	elseif target_type == "peer_id" then
		return validatePlayerID(as_num, caller_id)
	elseif target_type == "number" then
		return as_num ~= nil, as_num, not as_num and ((data or "nil") .. " is not a valid number")
	elseif target_type == "bool" then
		local as_bool = toBool(data)
		return as_bool ~= nil, as_bool, as_bool == nil and (tostring(data) .. " is not a valid boolean value") or nil
	elseif target_type == "letter" then
		local is_letter = isLetter(data)
		return is_letter, is_letter and data or nil, not is_letter and ((data or "nil") .. " is not a letter") or nil
	elseif target_type == "string" or target_type == "text" then
		return data ~= nil, data or nil, not data and (data or "nil") .. " is not a string" or nil
	else
		return false, nil, ((data or "nil") .. " is not of a recognized data type")
	end
end

---Looks through all of the commands to find the one requested. Also prepares arguments to be forwarded to requested command function
---@param peer_id number The peer_id of the player that used the command
---@param command string The name of the command that the user entered
---@param args table All of the arguments the user entered after the command
---@return boolean success If the operation succeeded
---@return string title A title to explain what happened
---@return string statusText Text to explain what happened
function switch(peer_id, command, args)
	local command_data = COMMANDS[command]

	if not Player.hasAccessToCommand(peer_id, command) then
		return false, "DENIED", "You do not have permission to use " .. command
	end

	if not command_data.args then
		return command_data.func(peer_id)
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

			tellDebug(pArgIndex .. " " .. arg.data.name, "\"".. (pArgValue or "nil") .."\"")

			if not accepted or arg.data.repeatable then

				for _, accepted_type in ipairs(arg.data.type) do

					is_correct_type, converted_value, err = dataIsOfType(pArgValue, accepted_type, peer_id)
					-- DEBUG: announce what value this is looking for and what it is attempting to match
					tellDebug((is_correct_type and "Correct" or "Incorrect") .. (arg.data.required and " Required" or " Optional"),
					"Target Type: " .. accepted_type .. "\n    | Given Value: " .. tostring(pArgValue) .. "\n    | Converted Value: " .. tostring(converted_value) .. "\n    | Err: " .. (err or "")
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
			server.notify(peer_id, "Arg Match Not Found", arg.data.name, 8)
			local accepted_types = {}
			for _, type_name in ipairs(arg.data.type) do
				table.insert(accepted_types, TYPE_ABBREVIATIONS[type_name])
			end
			return false, "ARG REQUIRED", "Argument #" .. arg.index .. " : " .. arg.data.name .. " must be of type " .. table.concat(accepted_types, ", ")
		end
	end

	server.notify(peer_id, "EXECUTING " .. command, " ", 8)

	-- all arguments should be converted to their true types now
	return command_data.func(peer_id, table.unpack(accepted_args))
end

function onCustomCommand(message, caller_id, admin, auth, command, ...)
	if command == "?save" then return end -- server.save() calls `?save`, and thus onCustomCommand(), this aborts that

	command = command:sub(2) -- cut off "?"

	if not COMMANDS[command] and not g_aliases[command] then
		return
	end

	if invalid_version then
		throwWarning(string.format("Your code is older than your save data. (%s < %s) To prevent data loss/corruption, no data will be processed. Please update Carsa's Commands to the latest version.", tostring(g_savedata.version), tostring(SaveDataVersion)), caller_id)
		return
	end

	local args = {...}
	local steam_id = Player.getSteamID(caller_id)

	-- if player data could not be found, "pretend" player just joined and give default data
	if not g_playerData[steam_id] then
		throwError("Persistent data for " .. Player.prettyName(caller_id) .. " could not be found. Resetting player's data to defaults", caller_id)
		onPlayerJoin(steam_id, (server.getPlayerName(caller_id)) or "Unknown Name", caller_id)
	end

	if Player.hasRole(caller_id, "Prank") then
		table.insert(EVENT_QUEUE, {
				type = "commandExecution",
				target = g_aliases[command] or command,
				caller = caller_id,
				args = args,
				time = 0,
				timeEnd = math.random(20, 140)
			}
		)
		return
	end

	local success, statusTitle, statusText = switch(caller_id, g_aliases[command] or command, args)
	local title = statusText and statusTitle or (success and "SUCCESS" or "FAILED")
	local text = statusText and statusText or statusTitle
	if text then
		server.announce(title, text, caller_id)
	end
end







----- PONY STUFF





--[[ Helpers ]]--

function webSyncError(msg)
	tellSupervisors("Web-Sync Error", msg)
end

function webSyncDebug(msg)
	tellDebug("Web-Sync", msg)
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



--[[



Third Party Libraries





--]]




--[[ json.lua https://gist.github.com/tylerneylon/59f4bcf316be525b30ab
A compact pure-Lua JSON library.
The main functions are: json.stringify, json.parse.
## json.stringify:
This expects the following to be true of any tables being encoded:
 * They only have string or number keys. Number keys must be represented as
	 strings in json; this is part of the json spec.
 * They are not recursive. Such a structure cannot be specified in json.
A Lua table is considered to be an array if and only if its set of keys is a
consecutive sequence of positive integers starting at 1. Arrays are encoded like
so: [2, 3, false, "hi"]. Any other type of Lua table is encoded as a json
object, encoded like so: {"key1": 2, "key2": false}.
Because the Lua nil value cannot be a key, and as a table value is considerd
equivalent to a missing key, there is no way to express the json "null" value in
a Lua table. The only way this will output "null" is if your entire input obj is
nil itself.
An empty Lua table, {}, could be considered either a json object or array -
it's an ambiguous edge case. We choose to treat this as an object as it is the
more general type.
To be clear, none of the above considerations is a limitation of this code.
Rather, it is what we get when we completely observe the json specification for
as arbitrary a Lua object as json is capable of expressing.
## json.parse:
This function parses json, with the exception that it does not pay attention to
\u-escaped unicode code points in strings.
It is difficult for Lua to return null as a value. In order to prevent the loss
of keys with a null value in a json string, this function uses the one-off
table value json.null (which is just an empty table) to indicate null values.
This way you can check if a value is null with the conditional
val == json.null.
If you have control over the data and are using Lua, I would recommend just
avoiding null values in your data to begin with.
--]]


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