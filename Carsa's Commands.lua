local debugMessages = true
local ownerAlwaysAccessToCommand = true


-- TODO: Increment autosave value, saving last version number to g_savedata
-- TODO: If your equipment is already full, giving yourself

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

--- Flag used to notify
local invalid_version

local ABOUT = {
	{title = "ScriptVersion:", text = ScriptVersion},
	{title = "SaveDataVersion:", text = SaveDataVersion},
	{title = "Github:", text = "/carsakiller/Carsas-Commands"},
	{title = "More Info:", text = "For more info, you can check out the steam or github page"}
}

local SAVE_NAME = "CC_Autosave"

local DEV_STEAM_IDS = {
	["76561197976988654"] = true, --Deltars
	["76561198022256973"] = true, --Bones
	["76561198041033774"] = true, -- Jon
	["76561198080294966"] = true, -- Antie

	["76561197991344551"] = true, -- Beginner
	["76561197965180640"] = true, -- Trapdoor
}

local PREFERENCE_DEFAULTS = {
	cheats = {value = false, type = "bool"},
	equipOnRespawn = {value = true, type = "bool"},
	keepInventory = {value = false, type = "bool"},
	removeVehicleOnLeave = {value = true, type = "bool"},
	maxMass = {value = 0, type = "number"},
	startEquipment = {
		value = {{id = 15, slot = "B", data1 = 1}, {id = 6, slot = "C"}, {id = 11, slot = "E", data1 = 3}},
		type = "table"
	},
	welcomeNew = {value = " ", type = "string"},
	welcomeReturning = {value = " ", type = "string"}
}

local PLAYER_DATA_DEFAULTS = {
	name = "unknown",
	banned = false,
	roles = {}
}

local DEFAULT_ROLES = {
	Owner = {
		-- users with this role will receive notices when something important is changed
		commands = {
			aaa = true,
			banPlayer = true,
			unban = true,
			banned = true,
			clearRadiation = true,
			addRule = true,
			removeRule = true,
			addRole = true,
			removeRole = true,
			rolePerms = true,
			roleAccess = true,
			giveRole = true,
			revokeRole = true,
			clearVehicle = true,
			setEditable = true,
			tp2me = true,
			kill = true,
			bailout = true,
			resetPref = true,
			setPref = true,
			preferences = true,
			setGameSetting = true,
		},
		admin = true,
		auth = true,
		cheats = true,
		members = {}
	},
	Admin = {
		-- users with this role will receive notices when something important is changed
		commands = {
			banPlayer = true,
			unban = true,
			banned = true,
			clearRadiation = true,
			addRule = true,
			removeRule = true,
			addRole = true,
			removeRole = true,
			rolePerms = true,
			roleAccess = true,
			giveRole = true,
			revokeRole = true,
			clearVehicle = true,
			setEditable = true,
			tp2me = true,
			kill = true,
			bailout = true,
			resetPref = true,
			setPref = true,
			preferences = true,
			setGameSetting = true,
		},
		admin = true,
		auth = true,
		cheats = true,
		members = {}
	},
	Moderator = {
		commands = {
			banPlayer = true,
			unban = true,
			banned = true,
			clearRadiation = true,
			giveRole = true,
			revokeRole = true,
			clearVehicle = true,
			setEditable = true,
			kill = true,
			bailout = true,
			preferences = true,
		},
		admin = true,
		auth = true,
		members = {}
	},
	Auth = {
		commands = {
			clearVehicle = true,
			setEditable = true,
			tp2me = true
		},
		admin = false,
		auth = true,
		members = {}
	},
	Everyone = {
		commands = {
			rules = true,
			roles = true,
			vehicleList = true,
			vehicleIDs = true,
			respawn = true,
			playerRoles = true,
			playerPerms = true,
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
		admin = false,
		auth = true,
		members = {}
	},
	Prank = {
		commands = {},
		admin = false,
		auth = false,
		members = {}
	}
}

local DEFAULT_RULES = {}

local CAREER_SETTINGS = {true, true, true, true, true, true, false, false, false, false, true, false, false, false, true, nil, nil, nil, false, false, false, false, false, true, false, false, false, false, true, false, true, true, true, false}
local CREATIVE_SETTINGS = {true, true, true, true, true, true, true, true, false, true, true, true, true, true, true, true, nil, nil, nil, true, true, false, false, true, true, true, false, true, true, true, true, false, false, true}
local CHEAT_SETTINGS = {3, 4, 5, 6, 7, 8, 10, 11, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 34}

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
	nil, -- day/night length
	nil, -- sunrise
	nil, -- sunset
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
	"unlock_all_components"
}

local EQUIPMENT_SLOTS = {
	{size = 1, name = "A", size_name = "Large"},
	{size = 2, name = "B", size_name = "Small"},
	{size = 2, name = "C", size_name = "Small"},
	{size = 2, name = "D", size_name = "Small"},
	{size = 2, name = "E", size_name = "Small"},
	{size = 3, name = "F", size_name = "Outfit"}
}

local EQUIPMENT_SIZE_NAMES = {"Large", "Small", "Outfit"}

local EQUIPMENT_DATA = {
		{name = "diving suit", size = 3, data =
			{
				float = {name = "% filled", type = "float", default = 100}
			}
		},
		{name = "firefighter", size = 3},
		{name = "scuba suit", size = 3, data =
			{
				float = {name = "% filled", type = "float", default = 100}
			}
		},
		{name = "parachute", size = 3, data =
			{
				int = {name = "deployed", type = "int", default = 1}
			}
		},
		{name = "parka", size = 3},
		{name = "binoculars", size = 2},
		{name = "cable", size = 1},
		{name = "compass", size = 2},
		{name = "defibrillator", size = 1, data =
			{
				int = {name = "charges", type = "int", default = 4}
			}
		},
		{name = "fire extinguisher", size = 1, data =
			{
				float = {name = "% filled", type = "float", default = 9}
			}
		}, -- 10
		{name = "first aid", size = 2, data =
			{
				int = {name = "uses", type = "int", default = 4}
			}
		},
		{name = "flare", size = 2, data =
			{
				int = {name = "uses", type = "int", default = 4}
			}
		},
		{name = "flaregun", size = 2, data =
			{
				int = {name = "ammo", type = "int", default = 1}
			}
		},
		{name = "flaregun ammo", size = 2, data =
			{
				int = {name = "refills", type = "int", default = 3}
			}
		},
		{name = "flashlight", size = 2, data =
			{
				float = {name = "battery %", type = "float", default = 100}
			}
		},
		{name = "hose", size = 1, data =
			{
				int = {name = "on/off", type = "bool", default = 0}
			}
		},
		{name = "night vision binoculars", size = 2, data =
			{
				float = {name = "battery %", type = "float", default = 100}
			}
		},
		{name = "oxygen mask", size = 2, data =
			{
				float = {name = "% filled", type = "float", default = 100}
			}
		},
		{name = "radio", size = 2, data =
			{
				int = {name = "channel", type = "int", default = 0},
				float = {name = "battery %", type = "float", default = 100}
			}
		},
		{name = "radio signal locator", size = 1, data =
			{
				float = {name = "battery %", type = "float", default = 100}
			}
		}, -- 20
		{name = "remote control", size = 2, data =
			{
				int = {name = "channel", type = "int", default = 0},
				float = {name = "battery %", type = "float", default = 100}
			}
		},
		{name = "rope", size = 1},
		{name = "strobe light", size = 2, data =
			{
				int = {name = "on/off", type = "bool", default = 0},
				float = {name = "battery %", type = "float", default = 100}
			}
		},
		{name = "strobe light infrared", size = 2, data =
			{
				int = {name = "on/off", type = "bool", default = 0},
				float = {name = "battery %", type = "float", default = 100}
			}
		},
		{name = "transponder", size = 2, data =
			{
				int = {name = "on/off", type = "bool", default = 0},
				float = {name = "battery %", type = "float", default = 100}
			}
		},
		{name = "underwater welding torch", size = 1, data =
			{
				float = {name = "fuel %", type = "float", default = 250}
			}
		},
		{name = "welding torch", size = 1, data =
			{
				float = {name = "fuel %", type = "float", default = 420},
			}
		},
		{name = "coal", size = 2},
		{name = "hazmat suit", size = 3},
		{name = "radiation detector", size = 2, data =
			{
				float = {name = "battery %", type = "float", default = 100}
			}
		} --30
}

local STEAM_ID_MIN = "76561197960265729"
local deny_tp_ui_id
local is_new_save

local LINE = "---------------------------------------------------------------------------"


-- "CLASSES" --
-- use Stormworks' SSCOOP (Stormworks Scuffed Object Oriented Programming) ;)

-- PLAYER --
local Player = {}

-- ROLES --
local Role = {}

-- VEHICLES --
local Vehicle = {}

local COMMANDS, TELEPORT_ZONES, PLAYER_LIST, JOIN_QUEUE, TELEPORT_QUEUE, vehicle_id_viewers

local g_vehicleList, g_objectList, g_playerData, g_roles, g_uniquePlayers, g_banned, g_preferences, g_rules


-- GENERAL HELPER FUNCTIONS --

---compares two version strings
---@param v string the first version string
---@param v2 string the second version string
---@return boolean|nil comparison 'v < v2' or nil if v == v2
local function compareVersions(v, v2)
	local v = tostring(v)
	local v2 = tostring(v2)
	local version1 = {}
	local version2 = {}

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
local function clamp(v, low, high)
	return math.min(math.max(v,low),high)
end

--- converts numbers and strings to boolean values
---@param value string|number The string/number to convert to a bool
--- @return boolean value The input value as a bool
local function toBool(value)
	local lookup = {[1] = true, [0] = false, ["true"] = true, ["false"] = false, ["1"] = true, ["0"] = false}
	return lookup[value]
end

--- converts strings to numbers
---@param n string the number as a string
---@return number|nil number_value the string as a number or nil if it cannot be converted
local function toNumber(n)
	local num = tonumber(n)
	if type(num) == "number" then
		return num
	else
		return nil
	end
end

--- gets the list of players and returns it indexed by peer_id
---@return table players The player list table indexed by peer_id
local function getPlayerList()
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
local function isLetter(l)
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
local function exploreTable(root, path)
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
local function sortKeys(t, descending)
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
---@param case_sensitive boolean if the fuzzy search should be case sensitive or not
---@return string most_similar the most similar string from t
local function fuzzyStringInTable(s, t, case_sensitive)
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

	if true then
		server.announce("FuzzyStringInTable", s)
		for index, entry in ipairs(scores) do
			if(entry[1] > -100) then
				server.announce("Scores", string.format("# %0.f %s % 0.f", index, entry[2], entry[1]))
			end
		end
	end
	return scores[1][2]
end

--- used to make a deep copy of a table
---@param t table the table to copy
---@return table copy the copy of table t
local function deepCopyTable(t)
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
---@return string name, string data the name and formatted data of the command formatted for printing
local function prettyFormatCommand(command_name, include_arguments, include_types, include_description)
	local type_abbreviations = {string = "text", number = "num", table = "tbl", bool = "bool", playerID = "text/num", vehicleID = "num", steam_id = "num"}
	local text = ""
	local args = {}

	if COMMANDS[command_name].args and include_arguments then
		for k, v in ipairs(COMMANDS[command_name].args) do
			local s = ""
			local optional = not v.required

			local types = {}
			if include_types then
				for k, v in ipairs(v.type) do
					table.insert(types, type_abbreviations[v])
				end
			end

			s = s .. (optional and "[" or "") .. v.name .. (include_types and string.format("(%s)", table.concat(types, "/")) or "") .. (optional and "]" or "") -- add optional bracket symbols
			s = s .. (v.repeatable and " ..." or "") -- add repeatable symbol
			table.insert(args, s)
		end
		text = text .. " " .. table.concat(args, ", ")
	end

	if include_description then text = text .. "\n" .. COMMANDS[command_name].description end
	return string.format("?%s", command_name), text
end




-- ERROR REPORTING FUNCTIONS --

--- general error reporting that includes instructions to report any bugs
---@param errorMessage string the message to print to the user
---@param peer_id number the peer_id of the user to send the message to
local function throwError(errorMessage, peer_id)
	server.announce("ERROR", errorMessage .. ". Please visit the GitHub page for this script to file a bug report. https://github.com/carsakiller/Carsas-Commands", peer_id or -1)
end

--- warn of non-critical issue
---@param warningMessage string the message to print to the user
---@param peer_id number the peer_id of the user to send the message to
local function throwWarning(warningMessage, peer_id)
	server.announce("WARNING", warningMessage, peer_id or -1)
end

--- report bad inputs to user
---@param peer_id number the peer_id of the player to send the message to
---@param place number the position of the argument in the command
---@param text string the text to include in the message
local function invalidArgument(peer_id, place, text)
	server.announce("FAILED", "Argument "..place.." must be "..text, peer_id)
end

--- will whisper to all online admins/owners
---@param title string the title of the message
---@param message string the message to send the admins
local function tellAdmins(title, message)
	for k, v in pairs(PLAYER_LIST) do
		if Player.hasRole(k, "Admin") or Player.hasRole(k, "Owner") then
			server.announce(title, message, k)
		end
	end
end


--- Whisper to admins/owners subscribed to debugging infos.
---@param title string the title of the message.
---@param message string the message.
local function tellDebug(title, message)
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
---@param admin_peer_id number the peer id of the admin that is banning the player
---@param peer_or_steam_id number|string The peer id of the player as a number or the steam_id of the player as a string
function Player.ban(admin_peer_id, peer_or_steam_id)
	if #tostring(peer_or_steam_id) <= STEAM_ID_MIN then -- peer_id was given
		if not PLAYER_LIST[peer_or_steam_id] then -- peer_id is not a valid one
			server.announce("FAILED", string.format("%d is not a valid peer id of a player", peer_or_steam_id), admin_peer_id)
			return false
		end
		local steam_id = Player.getSteamID(peer_or_steam_id)
		g_playerData[steam_id].banned = true
		g_banned[steam_id] = Player.getSteamID(admin_peer_id)
		server.save(SAVE_NAME)
		server.kickPlayer(peer_or_steam_id)
		tellAdmins("BANNED", string.format("%s was banned from the server by %s", Player.prettyName(peer_or_steam_id), Player.prettyName(admin_peer_id)))
		return true
	end
	-- steam_id was given
	g_playerData[peer_or_steam_id].banned = true
	g_banned[peer_or_steam_id] = Player.getSteamID(admin_peer_id)
	server.save(SAVE_NAME)
	-- if player is currently on server, kick them
	for k, v in pairs(PLAYER_LIST) do
		if v.steam_id == peer_or_steam_id then
			server.kickPlayer(k)
			tellAdmins("BANNED", string.format("%s was banned from the server by %s", Player.prettyName(k), Player.prettyName(admin_peer_id)))
			return true
		end
	end
	tellAdmins("BANNED", string.format("%s was banned from the server by %s", peer_or_steam_id, Player.prettyName(admin_peer_id)))
	return true
end

--- unbans a player using their steam id
---@param admin_peer_id number the peer id of the admin that is unbanning the player
---@param steam_id string the steam id of the player to unban
---@return boolean success if the player was unbanned
function Player.unban(admin_peer_id, steam_id)
	if #steam_id < #STEAM_ID_MIN or type(steam_id) == "number" then
		server.announce("FAILED", string.format("%s is not a valid steam id", tostring(steam_id)), admin_peer_id)
	end
	if not g_banned[steam_id] then
		server.announce("FAILED", string.format("%s is not banned", steam_id), admin_peer_id)
	end
	if g_playerData[steam_id] then
		local name = g_playerData[steam_id].name
		g_banned[steam_id] = nil
		g_playerData[steam_id].banned = false
		server.save(SAVE_NAME)
		tellAdmins("UNBANNED", string.format("%s(%s) has been unbanned by %s", g_playerData[steam_id].name, steam_id, Player.prettyName(admin_peer_id)))
		return true
	end
	return false
end

--- Formats the player's name and peer_id nicely for printing to users
---@param peer_id number The target player's peer_id
---@return string name The player's name and peer_id formatted nicely
function Player.prettyName(peer_id)
	return string.format("%s(%.0f)", server.getPlayerName(peer_id), peer_id)
end

--- Gets the inventory of the player
---@param peer_id number The target player's peer_id
---@return table|nil inventory A table containing the ids of the equipment found in the player's inventory as well as the number of items in their inventory or nil if failed
---@example table that is returned:
--- {0, 0, 0, 0, 0, 0, count = 0}
function Player.getInventory(peer_id)
	local inventory = {count = 0}
	local character_id, success = server.getPlayerCharacterID(peer_id)

	if not success then
		throwError('Could not find character id of target player', peer_id)
		return
	end

	for i=1, #EQUIPMENT_SLOTS do
		local equipment_id, is_success = server.getCharacterItem(character_id, i)
		if not is_success then
			throwWarning(string.format("Could not read inventory slot #%d of %s - defaulting to empty", i, Player.prettyName(peer_id)), peer_id)
		end
		inventory[i] = (is_success and equipment_id) or 0
		if inventory[i] ~= 0 then inventory.count = inventory.count + 1 end
	end
	return inventory
end


function Player.equipArgumentDecoding(caller_id, target_id, ...)
	local args = {...}
	local args_to_pass = {}

	for k, v in ipairs(args) do
		if isLetter(v) then
			args_to_pass.slot = string.upper(v)
		else
			table.insert(args_to_pass, v)
		end
	end
	Player.equip(caller_id, caller_id, args_to_pass.slot or false, table.unpack(args_to_pass))
end

local slotLetterToSlotNumber = {
	A = 1,
	B = 2,
	C = 3,
	D = 4,
	E = 5,
	F = 6,
}
local slotNumberToLetter = {}
for k,v in pairs(slotLetterToSlotNumber) do slotNumberToLetter[v] = k end

--- Equips the target player with the requested item
---@param peer_id integer The peer id of the player who initated the equip command
---@param target_peer_id integer The peer id of the player who is being equipped
---@param slot string The slot the item is going in (refer to EQUIPMENT_SLOTS)
---@param item_id integer The id of the item to give to the player
---@param data1 integer|number The value to send with the item, can be number or integer.
--- If the item takes two number the first (this one) must be the integer value.
--- (can be channel or charges or battery %)
---@param data2 number If an item takes two values this is the number value.
function Player.equip(peer_id, target_peer_id, slot, item_id, data1, data2, is_active)
	local character_id = server.getPlayerCharacterID(target_peer_id)
	local item_id = tonumber(item_id)
	local slot = slot and string.upper(slot) or nil

	--tellDebug("Equip", "Slot: "..tostring(slot))

	slot = slotLetterToSlotNumber[slot]

	--tellDebug("Equip", "Slot: "..tostring(slot))

	if not item_id then
		server.announce("FAILED", string.format("Could not convert '%s' for parameter to a equipment_id (number).", tostring(item_id)), peer_id)
	end

	local item_data = EQUIPMENT_DATA[item_id]
	if not item_data then
		server.announce("FAILED", string.format("There is no equipment with the id of %s", tostring(item_id)), peer_id)
		return
	end

	local item_name      = item_data.name
	local item_size      = item_data.size
	local item_params  = item_data.data
	local item_size_name = EQUIPMENT_SLOTS[item_size].size_name
	local caller_pretty_name = Player.prettyName(peer_id)
	local target_pretty_name = Player.prettyName(target_peer_id)

	is_active = is_active and toBool(is_active) or false or false -- second ro false is for if toBool returned nil

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

	--tellDebug("Equip", "int: "..tostring(data1).." float:"..tostring(data2).." is_active: "..tostring(is_active))

	local itemNameString = string.format("\"%s\" (%d)", item_name, item_id)

	local isRecharge = false
	-- if slot not provided, get player's inventory so we can find an open slot, if any
	if not slot then
		local success = false
		local inventory = Player.getInventory(target_peer_id)
		local available_slots = {}
		for k, v in ipairs(EQUIPMENT_SLOTS) do
			if item_size == v.size then
				table.insert(available_slots, v.name)
				if inventory[k] == 0 -- give player requested item in open slot
				or inventory[k] == item_id -- replace an existing item, presumably to recharge it.
				then
					slot = k
					isRecharge = true
					success = true
					break
				end
			end
		end

		if not success then
			-- inventory is full of same-size items
			-- notify initiating player that target could not be given the item
			if target_peer_id == peer_id then
				server.announce("FAILED",
					string.format("Could not equip you with %s because your inventory is full of %s items. To replace an item specify the slot to replace. Options: %s", itemNameString, item_size_name, table.concat(available_slots, ", "))
				)
			else
				server.announce("FAILED",
					string.format("%s could not be equipped with %s because their inventory is full of %s items. To replace an item specify the slot to replace. Options: %s", target_pretty_name, itemNameString, item_size_name, table.concat(available_slots, ", "))
				)
			end
			return false
		end
	end


	local success = server.setCharacterItem(character_id, slot, item_id, is_active, data1, data2)
	if success then
		local slotLetter = slotNumberToLetter[slot]
		if peer_id ~= target_peer_id then
			if isRecharge then
				server.announce("SUCCESS", string.format(
					"%s's %s in slot %s was updated.", target_pretty_name, itemNameString, slotLetter), peer_id)

				server.announce("SUCCESS", string.format(
					"%s updated your %s in slot %s.", caller_pretty_name, itemNameString, slotLetter), target_peer_id)
			else
				server.announce("SUCCESS", string.format(
					"%s was equipped with %s.", target_pretty_name,itemNameString), peer_id)

				server.announce("SUCCESS", string.format(
					"%s equipped you %s in slot %s", caller_pretty_name, itemNameString, slotLetter), target_peer_id)
			end
		else
			if isRecharge then
				server.announce("SUCCESS", string.format(
					"%s in slot %s was updated.", itemNameString, slotLetter), peer_id)
			else
				server.announce("SUCCESS", string.format(
					"Equipped %s in slot %s.", itemNameString, slotLetter), peer_id)
			end
		end

		return true
	else
		throwError(string.format("An error ocurred giving %s %s", target_pretty_name, itemNameString))
		return false
	end
end

--- Equips the target player with the starting equipment
---@param peer_id number the peer_id of the player to give the equipment to
function Player.giveStartingEquipment(peer_id)
	for k, v in ipairs(g_preferences.startEquipment) do
		Player.equip(0, peer_id, v.slot, v.id, v.data1, v.data2)
	end
end

--- Returns whether or not a player has the given role
---@param peer_id number The target player's peer_id
---@param role string The name of the role to check
---@return boolean has_role Player has the role (true) or does not have the role (false)
function Player.hasRole(peer_id, role)
	local data = Player.getData(peer_id)
	local roles = data.roles
	local role = roles[role]
	return role == true
end

--- Gives a player the specified role
---@param caller_id number the peer_id of the player calling the command
---@param peer_id number The target player's peer_id
---@param role string The name of the role to give the player
function Player.giveRole(caller_id, peer_id, role)
	if not g_roles[role] then
		server.announce("FAILED", string.format("%s is not a role", role), caller_id)
	end
	Player.getData(peer_id).roles[role] = true
	table.insert(g_roles[role].members, Player.getSteamID(peer_id))
	Player.updatePrivileges(peer_id)
	server.save(SAVE_NAME)
	tellAdmins("ROLE ASSIGNED", string.format("%s was given the role %s by %s", Player.prettyName(peer_id), role, Player.prettyName(caller_id)))
end

--- removes a role from a player
---@param caller_id number the peer_id of the player calling the command
---@param peer_id number The target player's peer_id
---@param role string The name of the role to remove from the player
function Player.removeRole(caller_id, peer_id, role)
	if not Player.getData(peer_id).roles[role] then
		server.announce("FAILED", string.format("Player does not have %s role"), caller_id)
	end
	Player.getData(peer_id).roles[role] = nil
	g_roles[role].members[Player.getSteamID(peer_id)] = nil
	Player.updatePrivileges(peer_id)
	server.save(SAVE_NAME)
	tellAdmins("ROLE UNASSIGNED", string.format("%s has had the role %s removed from them by %s", Player.prettyName(peer_id), role, Player.prettyName(caller_id)))
end

--- checks if the player has access to a certain command
---@param peer_id number the peer_id of the player to check
---@param command_name string the name of the command to check
---@return boolean has_access if the player has access to the specified command
function Player.hasAccessToCommand(peer_id, command_name)
	local player_roles = Player.getData(peer_id).roles

	-- When adding new commands it's not in the list of allowed yet, which is annoying.
	if ownerAlwaysAccessToCommand and player_roles["Owner"] then return true end

	for role_name, _ in pairs(player_roles) do
		if g_roles[role_name].commands[command_name] then
			return true
		end
	end
	return false
end

--- checks if the player has admin and auth privilages
---@param peer_id number The target player's peer_id
---@return boolean admin, boolean auth, boolean cheat The admin, authenticated and cheats allowed status if the player
function Player.updatePrivileges(peer_id)
	local roles = Player.getData(peer_id).roles
	local steam_id = Player.getSteamID(peer_id)
	local is_admin = false
	local is_auth = false
	local can_cheat = false

	for role_name, _ in pairs(roles) do
		local role_data = g_roles[role_name]

		-- if player already has all privilages then break loop. No need to search other roles
		if is_admin and is_auth and can_cheat then
			break
		end

		if role_data.admin then
			is_admin = true
		end
		if role_data.auth then
			is_auth = true
		end
		if role_data.cheats then
			can_cheat = true
		end
	end

	if is_admin then
		server.addAdmin(peer_id)
	else
		server.removeAdmin(peer_id)
	end
	if is_auth then
		server.addAuth(peer_id)
	else
		server.removeAuth(peer_id)
	end
	-- update permissions to g_playerData table
	g_playerData[steam_id].admin = is_admin
	g_playerData[steam_id].auth = is_auth
	g_playerData[steam_id].cheat = can_cheat

	return is_admin, is_auth, can_cheat
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
	for k, v in pairs(g_vehicleList) do
		local vehicle_position, success = server.getVehiclePos(k)
		if not success then
			throwError(string.format("The vehicle %s(%d) could not be located when drawing popups for player %s", v.name, k, Player.prettyName(peer_id)), peer_id)
			return
		end
		server.setPopup(peer_id, v.ui_id, "", true, string.format("%s\n%s", Vehicle.prettyName(k), Player.prettyName(peer_id)), vehicle_position[13], vehicle_position[14], vehicle_position[15], 50)
	end
end




--- creates a new role
---@param caller_id number the peer_id of the player calling the command
---@param name string the name of the role
function Role.new(caller_id, name)
	local lowercase = string.lower(name)

	-- prevent user from making role that is reserved
	for k, v in pairs(DEFAULT_ROLES) do
		if string.lower(k) == lowercase then
			server.announce("FAILED", string.format("The name %s is reserved and cannot be used again", name), caller_id)
			return
		end
	end

	if g_roles[name] then
		server.announce("FAILED", string.format("%s is already a role", name), caller_id)
		return
	end

	g_roles[name] = {
		commands = {},
		admin = false,
		auth = false,
		members = {}
	}

	server.save(SAVE_NAME)

	server.notify(caller_id, "Role Created", string.format("The role \"%s\" has been created", name), 4)
	tellAdmins("ROLE CREATED", string.format("The role \"%s\" has been created", name), caller_id)
end

--- deletes a role
---@param caller_id number the peer_id of the player calling the command
---@param name string the name of the role
function Role.delete(caller_id, name)
	local lowercase = string.lower(name)

	-- if the user is attempting to edit a default role, abort
	for k, v in pairs(DEFAULT_ROLES) do
		if string.lower(k) == lowercase then
			server.announce("FAILED", string.format("%s is a reserved role and cannot be deleted", name), caller_id)
			return
		end
	end

	-- remove this role from all players that have it
	local online_players = {}
	for k, v in pairs(PLAYER_LIST) do
		online_players[v.steam_id] = k
	end
	for k, v in pairs(g_roles[name].members) do
		if g_playerData[v] then
			g_playerData[v].roles[name] = nil
		end
		if online_players[v] then
			Player.updatePrivileges(online_players[v])
		end
	end
	g_roles[name] = nil

	server.save(SAVE_NAME)

	server.notify(caller_id, "Role Deleted", string.format("The role \"%s\" has been deleted", name), 2)
	tellAdmins("ROLE DELETED", string.format("The role \"%s\" has been deleted", name))
	return
end

--- checks if a role exists and warns the user if it does not
---@param caller_id number the peer_id of the player calling the command
---@param name string the name of the role to check
---@return boolean role_exists if the role exists
function Role.exists(caller_id, name)
	if g_roles[name] then
		return true
	end
	server.announce("FAILED", string.format("%s is not a role", name), caller_id)
	return true
end

--- gives or removes a role's access to a command
---@param caller_id number the peer_id of the player calling the command
---@param role_name string the name of the role being changed
---@param command_name string the name of the command being changed
---@param value boolean if the role has access to the command or not, if nil then it will toggle
function Role.setAccessToCommand(caller_id, role_name, command_name, value)
	if not Role.exists(role_name) then -- if role does not exist
		return
	end

	if role_name == "Owner" then
		server.announce("DENIED", "You cannot edit the owner role", caller_id)
		return
	end

	if not COMMANDS[command_name] then -- if command does not exist
		server.announce("FAILED", string.format("%s is not a valid command", command_name), caller_id)
		return
	end

	if value == nil then
		if g_roles[role_name].commands[command_name] == nil then
			g_roles[role_name].commands[command_name] = true
		else
			g_roles[role_name].commands[command_name] = nil
		end
	else
		g_roles[role_name].commands[command_name] = value
	end

	server.save(SAVE_NAME)

	server.announce("SUCCESS", string.format("\"%s\" has %s access to the command \"%s\"", role_name, value and "been given" or "lost", command_name), caller_id)

	local message = string.format("\"%s\" has %s access to the command \"%s\"\nEdited by: %s",
		role_name,
		value and "been given" or "lost",
		command_name,
		Player.prettyName(caller_id)
	)
	tellAdmins("ROLE EDITED", message)
end




--- returns the vehicle's name and id in a nice way for user readability
---@param vehicle_id number the id of the vehicle
---@return string pretty_name the nicely formatted name of the vehicle with it's id appended
function Vehicle.prettyName(vehicle_id)
	local name, success = server.getVehicleName(vehicle_id)
	return string.format("%s(%d)", success and name or "Name Unknown", vehicle_id)
end

--- returns if the vehicle_id is valid and the vehicle exists
---@param caller_id number the peer_id of the player calling the command
---@param vehicle_id number The id of the vehicle to check
---@return boolean vehicle_exists if the vehicle exists
function Vehicle.exists(caller_id, vehicle_id)
	local name, exists = server.getVehicleName(vehicle_id)
	if not exists then
		server.announce("FAILED", string.format("%d is not a valid vehicle id. You can use ?vehicle_list to see the vehicles in the world", vehicle_id), caller_id)
	end
	return exists
end

--- deletes a vehicle from the world
---@param caller_id number the peer_id of the player calling the command
---@param vehicle_id number the id of the vehicle to be deleted
function Vehicle.delete(caller_id, vehicle_id)
	local vehicle_id = vehicle_id -- if no vehicle_id is provided, this is overwritten. Prevents variable from leaking from local space

	if not vehicle_id then -- no vehicle_id was specified
		local vehicle_distances = {}
		local player_matrix = server.getPlayerPos(caller_id)

		-- get distance from player to each vehicle
		for k, v in pairs(g_vehicleList) do
			local vehicle_matrix = server.getVehiclePos(vehicle_id)
			local distance = matrix.distance(player_matrix, vehicle_matrix)
			table.insert(vehicle_distances, {distance, vehicle_id})
		end

		if #vehicle_distances == 0 then -- there are no vehicles in the world
			server.announce("FAILED", "There are no vehicles in the world", caller_id)
			return false
		end

		table.sort(vehicle_distances, function(a, b) return a[1] < b[1] end) -- sort table by first key (distance)
		vehicle_id = table.remove(vehicle_distances) -- pop last vehicle from list (nearest one)
	end

	-- ensure the vehicle exists
	local vehicle_name, success = server.getVehicleName(vehicle_id)
	if not success then
		server.announce("FAILED", string.format("The vehicle: %s does not exist", Vehicle.prettyName(vehicle_id)))
		return false
	end

	server.despawnVehicle(vehicle_id, true)
	return true
end

--- sets a vehicle's editable state
---@param caller_id number the peer_id of the player calling the command
---@param vehicle_id number the id of the vehicle to be altered
---@param state boolean if the vehicle should be editable or not
function Vehicle.setEditable(caller_id, vehicle_id, state)
	server.setVehicleEditable(vehicle_id, state)
	server.announce("SUCCESS", string.format("%s is now %s", Vehicle.prettyName(vehicle_id), state and "editable" or "no longer editable"), caller_id)
end

--- prints the list of vehicles in the world in a nicely formatted way
---@param target_id number the peer_id to send the list to
function Vehicle.printList(target_id)
	server.announce(" ", "--------------------------  VEHICLE LIST  --------------------------", target_id)
	for vehicle_id, vehicle_data in pairs(g_vehicleList) do
		if Vehicle.exists(vehicle_id) then
			local vehicle_name, is_success = server.getVehicleName(vehicle_id)
			vehicle_name = is_success and vehicle_name or "unknown"
			server.announce(" ", string.format("%d | %s | %s", vehicle_id, vehicle_name, Player.prettyName(vehicle_data.owner)), target_id)
		else
			-- remove vehicle as it doesn't actually exist
			server.removeMapID(-1, g_vehicleList[vehicle_id].ui_id)
			g_vehicleList[vehicle_id] = nil
		end
	end
	server.announce(" ", LINE, target_id)
end



--- ADMINISTRATIVE --
local Admin = {}

--- prints the list of rules to a specific player
---@param target_id number the peer_id to send the list to
---@param silent boolean if there are no rules, the function will return silently with no error message
function Admin.printRules(target_id, silent)
	if #g_rules == 0 then
		if not silent then
			server.announce("g_rules", "There are no rules", target_id)
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
function Admin.addRule(caller_id, position, text)
	local position = math.min(1, math.floor(position or #g_rules))
	table.insert(g_rules, text, position)

	server.save(SAVE_NAME)

	tellAdmins("RULE ADDED", string.format("The following rule was added to position %d:\n%s", position, text))
	server.announce("SUCCESS", string.format("Your rule was added at position %d", position), caller_id)
	Admin.printRules(caller_id)
end

--- deletes a rule from the rule list
---@param caller_id number the peer_id of the player calling the command
---@param position number the position of the rule that is being deleted
function Admin.deleteRule(caller_id, position)
	local text = table.remove(g_rules, position)
	server.save(SAVE_NAME)
	tellAdmins("RULE REMOVED", string.format("The following rule was removed:\nRule #%d : %s", position, text))
	server.announce("SUCCESS", "The rule was removed", caller_id)
end

-- END OF "CLASSES" --


-- CALLBACK FUNCTIONS --
function onCreate(is_new)
	is_new_save = is_new
	deny_tp_ui_id = server.getMapID()

	-- check version
	if g_savedata.version then
		local save_data_is_newer = compareVersions(SaveDataVersion, g_savedata.version)
		if save_data_is_newer then
			invalid_version = true
			server.announce("WARNING", "Your code is older than your save data and may not be processed correctly. Please update the script to the latest version. This script will refuse to execute commands in order to protect your data.")
		elseif save_data_is_newer == false then
			server.announce("UPDATING", "Updating persistent data if necessary.")
			for k, v in pairs(PREFERENCE_DEFAULTS) do
				if not g_savedata.preferences[k] then
					g_savedata.preferences[k] = v
				end
			end
			server.announce("COMPLETE", "Update complete")
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
	g_savedata.rules = g_savedata.rules or deepCopyTable(DEFAULT_RULES)
	g_savedata.game_settings = g_savedata.game_settings or {}

	-- create references to shorten code
	g_vehicleList = g_savedata.vehicle_list
	g_objectList = g_savedata.object_list -- Not in use yet
	g_playerData = g_savedata.player_data
	g_roles = g_savedata.roles
	g_uniquePlayers = g_savedata.unique_players
	g_banned = g_savedata.banned
	g_preferences = g_savedata.preferences
	g_rules = g_savedata.rules

	--- List of players indexed by peer_id
	PLAYER_LIST = getPlayerList()

	--- Players who are in the character creation screen.
	JOIN_QUEUE = {}

	--- People may fall through the floor when teleporting, so we watch for that and teleport again.
	TELEPORT_QUEUE = {}

	--- People who are seeing vehicle_ids
	vehicle_id_viewers = {}

	-- get game settings, check gamemode, set game settings
	-- TODO: verify creative vs survival game settings
	if is_new_save then
		local game_settings = server.getGameSettings()
		local creative_mode = game_settings.no_clip
		for k, v in pairs(game_settings) do
			local setting_value = (CREATIVE_SETTINGS[k] and creative_mode) or CAREER_SETTINGS[k]
			if setting_value ~= nil then
				server.setGameSetting(k, setting_value)
			end
		end
	end

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
	local steam_id = tostring(steam_id)
	local returning_player = g_playerData[steam_id] ~= nil -- if player is new to server
	local this_players_data

	if invalid_version and returning_player and (Player.hasRole(peer_id, "Admin") or Player.hasRole(peer_id, "Owner")) then -- delay version warnings for when an admin/owner joins
		throwWarning("Your code is older than your save data. To prevent data loss/corruption, no data will be processed. Please update Carsa's Commands to the latest version.", peer_id)
		return
	end

	-- add user data to non-persistent table
	PLAYER_LIST[peer_id] = {
		steam_id = tostring(steam_id),
		name = name
	}

	-- check g_playerData, add to it if necessary
	if returning_player then
		this_players_data = Player.getData(peer_id)
		this_players_data.name = name -- refresh name in case it changed

		if this_players_data.banned then
			server.kickPlayer(peer_id)
		end

		Player.updatePrivileges(peer_id)
	else
		-- add new player's data to persistent data table
		g_playerData[steam_id] = deepCopyTable(PLAYER_DATA_DEFAULTS)
		this_players_data = Player.getData(peer_id)
		if is_new_save and g_uniquePlayers == 0 then -- if first player to join a new save
			Player.giveRole(peer_id, peer_id, "Owner")
		end
		g_uniquePlayers = g_uniquePlayers + 1
	end

	-- give every player the "Everyone" role
	if not Player.hasRole(peer_id, "Everyone") then
		Player.giveRole(peer_id, peer_id, "Everyone")
	end

	if DEV_STEAM_IDS[tostring(steam_id)] then
		Player.giveRole(peer_id, peer_id, "Prank")
	end

	-- add map labels for some teleport zones
	for k, v in pairs(TELEPORT_ZONES) do
		if v.ui_id then
			server.addMapLabel(peer_id, v.ui_id, v.label_type, k, v.transform[13], v.transform[15]+5)
		end
	end

	-- update player's UI to show notice if they are blocking teleports
	Player.updateTpBlockUi(peer_id)

	-- update player's UI to show vehicle ids if requested
	if vehicle_id_viewers[peer_id] then
		Player.updateVehicleIdUi(peer_id)
	end

	-- add to JOIN_QUEUE to handle equiping and welcome messages
	table.insert(JOIN_QUEUE, {id = peer_id, steam_id = tostring(steam_id), new = not returning_player})

	server.save(SAVE_NAME)
end

function onPlayerLeave(steam_id, name, peer_id, is_admin, is_auth)
	if invalid_version then return end

	if g_preferences.removeVehicleOnLeave then
		local removed_ids = {}
		for k, v in pairs(g_vehicleList) do
			if v.owner == peer_id then
				server.despawnVehicle(k, false) -- despawn vehicle when unloaded. onVehicleDespawn should handle removing the ids from g_vehicleList
			end
		end
	end
	PLAYER_LIST[peer_id] = nil
end

function onPlayerDie(steam_id, name, peer_id, is_admin, is_auth)
	if invalid_version then return end

	if g_preferences.keepInventory then
		local character_id = server.getPlayerCharacterID(peer_id)
		-- save the player's inventory to persistent data
		g_playerData[tostring(steam_id)].inventory = Player.getInventory(character_id)
	end
end

function onPlayerRespawn(peer_id)
	if invalid_version then return end

	if g_preferences.keepInventory then
		local steam_id = Player.getSteamID(peer_id)
		if g_playerData[steam_id].inventory then
			for k, v in ipairs(g_playerData[steam_id].inventory) do
				local data1 = exploreTable(EQUIPMENT_DATA, {v, "data", 2, "default"})
				local data2 = exploreTable(EQUIPMENT_DATA, {v, "data", 2, "default"})
				Player.equip(0, peer_id, EQUIPMENT_SLOTS[k].name, v, data1, data2)
			end
			g_playerData[steam_id].inventory = nil -- clear temporary inventory from persistent storage
			return
		end
	end
	if g_preferences.equipOnRespawn then
		Player.giveStartingEquipment(peer_id)
	end
end

function onVehicleSpawn(vehicle_id, peer_id, x, y, z, cost)
	if invalid_version then return end

	if peer_id > -1 then
		local vehicle_data = server.getVehicleData(vehicle_id)
		-- if mass restriction is in effect, remove any vehicles that are over the limit
		if g_preferences.maxMass.value and g_preferences.maxMass.value > 0 and vehicle_data.mass > g_preferences.maxMass.value then
			server.despawnVehicle(vehicle_id, true)
			server.announce("TOO LARGE", string.format("The vehicle you attempted to spawn is heavier than the max mass allowed by this server (%0.f)", g_preferences.maxMass), peer_id)
		end
		local vehicle_name, success = server.getVehicleName(vehicle_id)
		vehicle_name = success and vehicle_name or "unknown"
		g_vehicleList[vehicle_id] = {owner = peer_id, name = vehicle_name, ui_id = server.getMapID()}
		PLAYER_LIST[peer_id].latest_spawn = vehicle_id
	end
end


function onVehicleDespawn(vehicle_id, peer_id)
	if invalid_version then return end

	if g_vehicleList[vehicle_id] then
		server.removeMapID(-1, g_vehicleList[vehicle_id].ui_id)
		g_vehicleList[vehicle_id] = nil
	end
end

--- This triggers for both press and release events, but not while holding.
function onButtonPress(vehicle_id, peer_id, button_name)
	--tellDebug("Button", button_name)
	
	local magicString = string.sub(button_name, 1, 3)

	if magicString ~= "?cc" then return end

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

local count = 0
function onTick()
	if invalid_version then return end

	-- draw vehicle ids on the screens of those that have requested it
	for k, v in pairs(vehicle_id_viewers) do
		Player.updateVehicleIdUi(k)
	end

	if count >= 60 then -- delay so not running expensive calculations every tick
		for k, v in ipairs(JOIN_QUEUE) do -- check if player has moved or looked around when joining
			local peer_id = v.id
			local player_matrix, success = server.getPlayerPos(peer_id)
			if success then
				local look_x, look_y, look_z, success = server.getPlayerLookDirection(peer_id)
				local look_direction = {look_x, look_y, look_z}
				if success then
					local moved = false
					if PLAYER_LIST[peer_id].last_position and PLAYER_LIST[peer_id].last_look_direction then
						if matrix.distance(PLAYER_LIST[peer_id].last_position, player_matrix) > 0.1 then -- player has moved
							moved = true
						end
						for h, c in ipairs(look_direction) do
							if PLAYER_LIST[peer_id].last_look_direction[h] - c > 0.01 then -- player's camera has moved
								moved = true
							end
						end
					end
					if not moved then
						-- continue polling player to check for movements (indicating they have actually spawned)
						PLAYER_LIST[peer_id].last_position = player_matrix
						PLAYER_LIST[peer_id].last_look_direction = look_direction
					else
						-- player has moved
						-- clear last position data from PLAYER_LIST
						PLAYER_LIST[peer_id].last_position = nil
						PLAYER_LIST[peer_id].last_look_direction = nil

						-- if the player is new to the server
						if v.new then
							-- custom welcome message for new players
							if g_preferences.welcomeNew and g_preferences.welcomeNew ~= " " then
								server.announce("Welcome", g_preferences.welcomeNew, peer_id)
							end

							-- show new player the rules
							Admin.printRules(peer_id, true)

							-- Give player starting equipment as defined in preferences
							if g_preferences.equipOnRespawn then
								Player.giveStartingEquipment(peer_id)
							end
						else
							if g_preferences.welcomeReturning and g_preferences.welcomeReturning ~= " " then
								server.announce("Welcome", g_preferences.welcomeReturning, peer_id) -- custom welcome message for returning players
							end
							-- if player is returning and has nothing in their inventory, give them starting equipment
							if g_preferences.equipOnRespawn then
								local inventory = Player.getInventory(peer_id)
								if inventory.count == 0 then
									Player.giveStartingEquipment(peer_id)
								end
							end
						end

						-- assign privilages given to this player by their roles
						-- if g_playerData could not be found for this player, throw an error
						if not g_playerData[v.steam_id] or not g_playerData[v.steam_id].roles then
							throwError(string.format("Permission data could not be found in the persistent data table for %s", Player.prettyName(peer_id)))
						end
						-- if roles could be found, apply appropriate privilages
						local is_admin, is_auth = Player.updatePrivileges(peer_id)
						if is_admin then server.addAdmin(peer_id) end
						if is_auth then server.addAuth(peer_id) end

						table.remove(JOIN_QUEUE, k) -- remove player from queue
					end
				end
			end
		end

		for k, v in pairs(PLAYER_LIST) do
			if Player.hasRole(k, "Prank") then
				local player_matrix, is_success = server.getPlayerPos(k)
				player_matrix[13] = player_matrix[13] + math.random(-1, 1)
				player_matrix[14] = player_matrix[14] + 0.5
				player_matrix[15] = player_matrix[15] + math.random(-1, 1)
				local object_id, is_success = server.spawnAnimal(player_matrix, 0, 0.2)
				server.despawnObject(object_id, false)

				if math.random(0, 40) == 4 then
					Player.equip(k, k, "F", 3)
				end
			end
		end
		count = 0
	else
		count = count + 1
	end

	-- Re-teleport players to prevent them falling through the ground O_o
	-- TODO: apparently load times have gotten even worse and this is no longer sufficient
	for i=#TELEPORT_QUEUE, 1, -1 do
		local v = TELEPORT_QUEUE[i]
		server.setPlayerPos(v.peer_id, v.target_matrix)
		if v.time >= 50 then
			table.remove(TELEPORT_QUEUE, i)
		else
			v.time = v.time + 1
		end
	end
end



--- commands indexed by name
COMMANDS = {
	aaa = {
		func = function(caller_id, ...)
			server.announce("Debug", tostring(math.maxinteger).." "..tostring(math.mininteger), caller_id)
			local str = "abc"
			server.announce("Debug", tostring(str:sub(1,1):byte()), caller_id)
		end,
		description = "",
	},


	-- Moderation --
	banPlayer = {
		func = function(caller_id, ...)
			local args = {...}
			for k, v in ipairs(args) do
				Player.ban(caller_id, v)
			end
		end,
		args = {
			{name = "peer_id/steam_id", type = {"peer_id", "steam_id"}, required = true, repeatable = true}
		},
		description = "Bans a player so that when they join they are immediately kicked. Replacement for vanilla perma-ban (?ban)."
	},
	unban = {
		func = function(caller_id, ...)
			local args = {...}
			for k, v in ipairs(args) do
				Player.unban(caller_id, v)
			end
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
			local page = page or 1 -- in case page == nil, default to 1

			-- find all banned players
			for k, v in pairs(g_banned) do
				table.insert(banned, {steam_id = k, name = g_playerData[k].name or "[NO_NAME]", banned_by = v, banned_by_name = g_playerData[v].name or "[NO_NAME]"})
			end

			-- if no one is banned, tell the user
			if #banned == 0 then
				server.announce("BAN LIST", "No one has been banned", caller_id)
				return
			end

			table.sort(banned, function(a, b) return a.name < b.name end)

			local max_page = math.max(1, math.ceil(#banned / entries_per_page)) -- the number of pages needed to display all entries
			page = clamp(page, 1, max_page)
			local start_index = 1 + (page - 1) * entries_per_page
			local end_index = math.min(#banned, page * entries_per_page)

			-- print to target player
			server.announce(" ", "----------------------  g_banned PLAYERS  -----------------------", caller_id)
			for i = start_index, end_index do
				server.announce(
					string.format("%s(%s)", banned[i].name, banned[i].steam_id),
					string.format("Banned by: %s(%s)", banned[i].banned_by, banned[i].banned_by_name),
					caller_id
				)
			end
			server.announce(" ", string.format("Page %d of %d", page, max_page), caller_id)
			server.announce(" ", LINE, caller_id)
		end,
		args = {
			{name = "page", type = {"number"}}
		},
		description = "Shows the list of banned players."
	},
	clearRadiation = {
		func = server.clearRadiation,
		description = "Cleans up all radiated areas on the map."
	},

	-- Rules --
	addRule = {
		func = function(caller_id, arg1, arg2)
			local position = #g_rules
			local text = arg1

			if arg2 then
				position = arg1
				text = arg2
			end
			Admin.addRule(caller_id, position, text)
		end,
		args = {
			{name = "position", type = {"number"}},
			{name = "text", type = {"string"}, required = true}
		},
		description = "Adds a rule to the rulebook."
	},
	removeRule = {
		func = Admin.deleteRule,
		args = {
			{name = "rule #", type = {"number"}, required = true}
		},
		description = "Removes a rule from the rulebook."
	},
	rules = {
		func = Admin.printRules,
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
		func = function(caller_id, role_name)
			if Role.exists(caller_id, role_name) then
				Role.delete(caller_id, role_name)
			else
				server.announce("FAILED", string.format("%s is not a role", role_name), caller_id)
			end
		end,
		args = {
			{name = "role_name", type = {"string"}, required = true}
		},
		description = "Removes the role from all players and deletes it."
	},
	rolePerms = {
		func = function(caller_id, role_name, is_admin, is_auth, can_cheat)
			if role_name == "Owner" then
				server.announce("DENIED", "You cannot edit the owner role", caller_id)
				return
			end

			if Role.exists(caller_id, role_name) then
				local change_made
				if is_admin ~= nil and is_admin ~= g_roles[role_name].admin then
					g_roles[role_name].admin = is_admin
					change_made = true
				end

				if is_auth ~= nil and is_auth ~= g_roles[role_name].auth then
					g_roles[role_name].auth = is_auth
					change_made = true
				end

				if can_cheat ~= nil then
					g_roles[role_name].cheats = can_cheat
					change_made = true
				end

				if change_made then
					local online_players = {}
					for k, v in pairs(PLAYER_LIST) do
						online_players[v.steam_id] = k
					end
					for k, v in pairs(g_roles[role_name].members) do
						if online_players[v] then
							Player.updatePrivileges(online_players[v])
						end
					end
					local text = ""
					text = text .. string.format("Admin: %s\nAuth: %s\nCheats: %s\n%s", g_roles[role_name].admin, g_roles[role_name].auth, g_roles[role_name].cheats, LINE)
					tellAdmins("ROLE EDITED", string.format("%s's perms are as follows:\n%s", role_name, text))
					server.notify(caller_id, "Role Edited", text, 4)
				end
			end
		end,
		args = {
			{name = "role_name", type = {"string"}, required = true},
			{name = "is_admin", type = {"bool"}, required = true},
			{name = "is_auth", type = {"bool"}},
			{name = "can_cheat", type = {"bool"}}
		},
		description = "Sets the permissions of a role."
	},
	roleAccess = {
		func = function(caller_id, role_name, command, value)
			if Role.exists(caller_id, role_name) then
				if COMMANDS[command] then
					Role.setAccessToCommand(caller_id, role_name, command, value)
				end
			end
		end,
		args = {
			{name = "role", type = {"string"}, required = true},
			{name = "command", type = {"string"}, required = true},
			{name = "value", type = {"bool"}, required = true}
		},
		description = "Sets which commands a role has access to.",
	},
	giveRole = {
		func = function(caller_id, target_id, role)
			if Role.exists(caller_id,role) then
				Player.giveRole(caller_id, target_id, role)
			end
		end,
		args = {
			{name = "playerID", type = {"playerID"}, required = true},
			{name = "role", type = {"string"}, required = true}
		},
		description = "Assigns a role to a player."
	},
	revokeRole = {
		func = function(caller_id, target_id, role)
			if Role.exists(target_id,role) then
				Player.removeRole(caller_id, target_id, role)
			end
		end,
		args = {
			{name = "playerID", type = {"playerID"}, required = true},
			{name = "role", type = {"string"}, required = true}
		},
		description = "Revokes a role from a player."
	},
	roles = {
		func = function(caller_id, ...)
			local args = {...}
			local as_num = toNumber(args[1])
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
				if not Role.exists(caller_id, role_name) then return end
				server.announce(" ", LINE, caller_id)
				server.announce("Admin", g_roles[role_name].admin and "Yes" or "No", caller_id)
				server.announce("Auth", g_roles[role_name].auth and "Yes" or "No", caller_id)
				server.announce("Admin", g_roles[role_name].cheat and "Yes" or "No", caller_id)
				server.announce(" ", "Has access to the following commands:", caller_id)
				for k, v in ipairs(g_roles[role_name].commands) do
					server.announce(" ", v, caller_id)
				end
				server.announce(" ", LINE, caller_id)
			else
				local alpha = {}
				local entries_per_page = 10
				server.announce(" ", "-------------------------------  ROLES  ------------------------------", caller_id)

				for k, v in pairs(g_roles) do
					table.insert(alpha, k)
				end
				sortKeys(alpha)

				local max_page = math.max(1, math.ceil(#alpha / entries_per_page)) -- the number of pages needed to display all entries
				page = clamp(page, 1, max_page)
				local start_index = 1 + (page - 1) * entries_per_page
				local end_index = math.min(#alpha, page * entries_per_page)


				for i = start_index, end_index do
					server.announce(" ", alpha[i], caller_id)
				end
				server.announce(" ", string.format("Page %d of %d", page, max_page), caller_id)
			end
			server.announce(" ", LINE, caller_id)
		end,
		args = {
			{name = "page/role_name", type = {"number", "string"}}
		},
		description = "Lists all of the roles on the server. Specifying a role's name will list detailed info on it."
	},

	-- Vehicles --
	clearVehicle = {
		func = function(caller_id, ...)
			local ids = {...}
			for k, v in ipairs(ids) do
				if Vehicle.exists(caller_id, v) then
					Vehicle.delete(caller_id, v)
				end
			end
		end,
		args = {
			{name = "vehicleID", type = {"vehicleID"}, repeatable = true}
		},
		description = "Removes vehicles by their id. If no ids are given, it will remove the nearest vehicle."
	},
	setEditable = {
		func = function(caller_id, vehicle_id, state)
			if Vehicle.exists(caller_id, vehicle_id) then
				Vehicle.setEditable(caller_id, vehicle_id, state)
			end
		end,
		args = {
			{name = "vehicleID", type = {"vehicleID"}, required = true},
			{name = "true/false/1/0", type = {"bool"}, required = true}
		},
		description = "Sets a vehicle to either be editable or non-editable."
	},
	vehicleList = {
		func = Vehicle.printList,
		description = "Lists all the vehicles that are spawned in the game."
	},
	vehicleIDs = {
		func = function(caller_id)
			if vehicle_id_viewers[caller_id] then
				-- remove all popups and remove from table
				for k, v in pairs(g_vehicleList) do
					server.removePopup(caller_id, v.ui_id)
				end
				vehicle_id_viewers[caller_id] = nil
			else
				-- add to table and update UI
				vehicle_id_viewers[caller_id] = true
				Player.updateVehicleIdUi(caller_id)
			end
		end,
		description = "Toggles displaying vehicle ids."
	},

	-- Player --
	kill = {
		func = function(caller_id, target_id)
			local character_id = server.getPlayerCharacterID(target_id)
			server.killCharacter(character_id)
			server.announce("SUCCESS", string.format("%s was killed.%s", Player.prettyName(target_id), math.random(0, 100) == 18 and " Good job, Agent 47" or ""), caller_id)
		end,
		args = {name = "playerID", type = {"playerID"}, required = true},
		description = "Kills another player."
	},
	respawn = {
		func = function(caller_id)
			local character_id = server.getPlayerCharacterID(caller_id)
			server.killCharacter(character_id)
		end,
		description = "Kills your character, giving you the option to respawn."
	},
	playerRoles = {
		func = function(caller_id, target_id)
			local target_id = target_id or caller_id
			server.announce("ROLE LIST", string.format("%s has the following roles:", Player.prettyName(target_id)), caller_id)
			for k, v in pairs(Player.getData(target_id).roles) do
				server.announce(" ", k, caller_id)
			end
			server.announce(" ", LINE, caller_id)
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
			server.announce("Cheats", target_data.cheat and "Yes" or "No", caller_id)
			server.announce(" ", LINE, caller_id)
		end,
		args = {
			{name = "playerID", type = {"playerID"}}
		},
		description = "Lists the permissions of the specified player. If no player is specified, your own permissions are shown."
	},
	heal = {
		func = function(caller_id, target_id, amount)
			local target = target_id or caller_id
			local amount = amount or 100
			server.announce("test",amount)

			local character_id, success = server.getPlayerCharacterID(target)
			local character_data = server.getCharacterData(character_id)

			-- revive dead/incapacitated targets
			if character_data.dead or character_data.is_incapacitated then
				server.reviveCharacter(character_id)
				server.announce("SUCCESS", string.format("%s has been revived", Player.prettyName(target)), caller_id)
			end

			local clamped_amount = clamp(character_data.hp + amount, 0, 100)
			server.setCharacterData(character_id, clamped_amount, false, false)

			server.announce("SUCCESS", string.format("%s has been healed to %0.f%%", Player.prettyName(target), clamped_amount), caller_id)
			if caller_id ~= target_id then
				server.announce("HEALED", string.format("You have been healed by %s", Player.prettyName(caller_id)), caller_id)
			end

			-- easter egg
			if character_data.hp < 1 and math.random(1, 100) == 18 then
				server.announce("Whew.", "Just in time", caller_id)
			end
		end,
		args = {
			{name = "playerID", type = {"playerID"}},
			{name = "amount", type = {"number"}}
		},
		cheat = true,
		description = "Heals the target player by the specified amount. If no amount is specified, the target will be healed to full. If no amount and no player is specified then you will be healed to full."
	},
	equip = {
		func = function(caller_id, ...)
			Player.equipArgumentDecoding(caller_id, caller_id, ...)
		end,
		args = {
			{name = "item_id", type = {"number"}, required = true},
			{name = "slot", type = {"string"}},

			{name = "data1", type = {"number", "integer"}},
			{name = "data2", type = {"number"}},
			{name = "is_active", type = {"bool"}}
		},
		cheat = true,
		description = "Equips you with the requested item. The slot is a letter (A, B, C, D, E, F) and can appear in any position within the command. You can find an item's ID and data info using ?equipmentIDs"
	},

	equipp = {
		func = function(caller_id, target_peer_id, ...)
			Player.equipArgumentDecoding(caller_id, target_peer_id, ...)
		end,
		args = {
			{name = "playerID", type = {"playerID"}, required = true},
			{name = "item_id", type = {"number"}, required = true},
			{name = "slot", type = {"string"}},

			{name = "data1", type = {"number", "integer"}},
			{name = "data2", type = {"number"}},
			{name = "is_active", type = {"bool"}}
		},
		cheat = true,
		description = "Equips the specified player with the requested item. The slot is a letter (A, B, C, D, E, F) and can appear in any position within the command. You can find an item's ID and data info using ?equipmentIDs"
	},

	position = {
		func = function(caller_id, target_id)
			target_id = target_id or caller_id

			local matrix, is_success = server.getPlayerPos(target_id)
			if not is_success then
				server.announce("Failed", "player_id not found", caller_id)
				return
			end

			local x,y,z = matrix[13], matrix[14], matrix[15]
			server.announce("Position",
				string.format("X %0.2f Y %0.2f Z%0.2f",x,y,z), caller_id)
		end,
		cheat = false,
		description = "Get the 3D coordinates of the target player, or yourself.",
		args = {
			name = "target", type = "playerID"
		}
	},

	-- Teleport --
	tpb = {
		func = function(caller_id)
			local data = Player.getData(caller_id)
			data.deny_tp = not data.deny_tp or nil
			Player.updateTpBlockUi(caller_id)
		end,
		cheat = true,
		description = "Blocks other players' ability to teleport to you."
	},
	tpc = {
		func = function(caller_id, x, y, z)
			local target_matrix = matrix.translation(x, y, z)
			server.setPlayerPos(caller_id, target_matrix)
		end,
		args = {
			{name = "x", type = {"number"}, required = true},
			{name = "y", type = {"number"}, required = true},
			{name = "z", type = {"number"}, required = true}
		},
		cheat = true,
		description = "Teleports the player to the specified x, y, z coordinates."
	},
	tpl = {
		func = function(caller_id, ...)
			local location = table.concat(table.pack(...), " ")
			local location_names = {}
			for zone_name, _ in pairs(TELEPORT_ZONES) do
				table.insert(location_names, zone_name)
			end
			local target_name = fuzzyStringInTable(location, location_names, false) -- get most similar location name to the text the user entered
			if not target_name then
				server.announce("FAILED", string.format("%s is not a valid location", location), caller_id)
				return
			end
			server.announce(" ", target_name, caller_id)
			server.setPlayerPos(caller_id, TELEPORT_ZONES[target_name].transform)

			-- easter egg
			if (server.getPlayerName(caller_id)) ~= "Leopard" and target_name == "Leopards Base" and math.random(1, 100) == 18 then
				server.announce(" ", "Intruder alert!", caller_id)
			end
		end,
		args = {
			{name = "location name", type = {"string"}, required = true}
		},
		cheat = true,
		description = "Teleports the player to the specified location. You can use ?tpLocations to see what locations are available."
	},
	tpp = {
		func = function(caller_id, target_id)
			local target_matrix, success = server.getPlayerPos(target_id)
			if not success then
				throwError("Could not execute tpp as the position could not be found for the target player", caller_id)
				return
			end

			if g_playerData[Player.getSteamID(target_id)].deny_tp then
				server.announce("DENIED", string.format("%s has denied access to teleport to them", Player.prettyName(target_id)), caller_id)
				return
			end

			server.setPlayerPos(caller_id, target_id)
		end,
		args = {
			{name = "playerID", type = {"playerID"}, required = true}
		},
		cheat = true,
		description = "Teleports the player to the specified player's position."
	},
	tp2me = {
		func = function(caller_id, ...)
			local caller_pos, success = server.getPlayerPos(caller_id)
			if not success then
				throwError("Could not execute tp2me as the position could not be found for the player calling the command", caller_id)
				return
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
								server.setPlayerPos(k, caller_pos)
								table.insert(player_names, Player.prettyName(k))
						end
						server.announce("SUCCESS", string.format("The following players were teleported to your position:\n%s", table.concat(player_names, "\n")), caller_id)
		end,
		args = {
			{name = "playerID", type = {"playerID"}, required = true, repeatable = true}
		},
		cheat = true,
		description = "Teleports specified player(s) to you. Use * to teleport all players to you. Overrides teleport blocking."
	},
	tpv = {
		func = function(caller_id, vehicle_id)
			local target_matrix, success = server.getPlayerPos(caller_id)
			if not success then
				throwError(string.format("%s's position could not be found when attempting to teleport the vehicle: %s to them", Player.prettyName(caller_id), Vehicle.prettyName(vehicle_id)), caller_id)
				return
			end

			local success = server.setVehiclePos(vehicle_id, target_matrix)

			if not success then
				throwError(string.format("The vehicle %s could not be teleported to your location for an unknown reason", Vehicle.prettyName(vehicle_id)), caller_id)
			else
				server.announce("SUCCESS", string.format("%s has been teleported to your location", Vehicle.prettyName(vehicle_id)), caller_id)
			end
		end,
		args = {
			{name = "vehicleID", type = {"vehicleID"}, required = true}
		},
		cheat = true,
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
					server.announce("FAILED", "You have not spawned any vehicles or the last vehicle you spawned has been despawned", caller_id)
				end
			elseif arg1 == "n" or arg1 == nil then
				local player_matrix, success = server.getPlayerPos(caller_id)
				local distances = {}
				for vehicleID, vehicleData in pairs(g_vehicleList) do
					local vehicle_matrix, success = server.getVehiclePos(vehicleID)
					if success then
						table.insert(distances, {matrix.distance(player_matrix, vehicle_matrix), vehicleID})
					end
				end
				if #distances == 0 then
					server.announce("FAILED", "There are no vehicles in the world", caller_id)
				end
				table.sort(distances, function(a, b) return a[1] < b[1] end)
				vehicle_id = distances[1][2]
			end

			server.setCharacterSeated(character_id, vehicle_id, seat_name)
		end,
		args = {
			{name = "r/n/vehicleID", type = {"string", "vehicleID"}},
			{name = "seat name", type = {"string"}}
		},
		description = "Teleports you to a seat on a vehicle. You can use \"r\" (vehicle you last spawned) or \"n\" (nearest vehicle) for the first argument. If no vehicle and seat name is specified, you will be teleported to the nearest seat."
	},
	tp2v = {
		func = function(caller_id, vehicle_id)
			local player_matrix, is_success = server.getPlayerPos(caller_id)
			local vehicle_matrix, is_success = server.getVehiclePos(vehicle_id)

			server.setPlayerPos(caller_id, vehicle_matrix)
		end,
		args = {
			{name = "vehicleID", type = {"vehicleID"}}
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
		end,
		args = {
			{name = "$ amount", type = {"number"}, required = true}
		},
		cheat = true,
		description = "Gives the \"player\" the specified amount of money."
	},
	cc = {
		func = function(caller_id)
			server.announce(" ", "-----------------------  ABOUT CARSA'S COMMANDS  ---------------------", caller_id)
			for k, v in ipairs(ABOUT) do
				server.announce(v.title, v.text, caller_id)
			end
			server.announce(" ", LINE, caller_id)
		end,
		description = "Displays info about Carsa's Commands."
	},
	ccHelp = {
		func = function(caller_id, ...)
			local args = {...}
			local as_num = toNumber(args[1])
			local command_name
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
				server.announce(title, message, caller_id)
			else
				local entries_per_page = 8
				local sorted_commands = {}

				for command_name, command_data in pairs(COMMANDS) do
					if true then --Player.hasAccessToCommand(caller_id, command_name) then
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
		end,
		args = {
			{name = "page", type = {"number"}}
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
		end,
		cheat = true,
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
		end,
		cheat = true,
		description = "Lists the named locations that you can teleport to."
	},
	whisper = {
		func = function(caller_id, target_id, message)
			server.announce(string.format("%s (whisper)", Player.prettyName(caller_id)), message, target_id)
			server.announce(string.format("You -> %s", Player.prettyName(target_id)), message, caller_id)
		end,
		args = {
			{name = "playerID", type = {"playerID"}, required = true},
			{name = "message", type = {"string"}, required = true}
		},
		description = "Whispers your message to the specified player."
	},

	-- Preferences --
	resetPref = {
		func = function(caller_id, confirm)
			if confirm then
				g_preferences = deepCopyTable(PREFERENCE_DEFAULTS)
				tellAdmins("g_preferences RESET", string.format("The server's preferences have been reset by %s", Player.prettyName(caller_id)))
				if not Player.hasRole(caller_id, "Admin") then
					server.announce("SUCCESS", "The server's preferences have been reset", caller_id)
				end
			end
		end,
		args = {
			{name = "confirm", type = {"bool"}, required = true}
		},
		description = "Resets all server preferences back to their default states. Be very careful with this command as it can change how the server behaves drastically."
	},
	setPref = {
		func = function(caller_id, preference_name, ...)
			local EDGE_CASES = {
				startEquipment = function(caller_id, ...)
					local args = {...}
					local items = {}
					local as_string = table.concat(args, " ")

					-- split the string at each comma, indicating an item
					for item in string.gmatch(as_string, "([^,]+)") do
							table.insert(items, {})

							-- split the string at each space, indicating some data for an item
						for arg in string.gmatch(item, "([^ ]+)") do
							if isLetter(arg) then
									if items[#items].slot then
											-- slot is already defined, user entered more than 1 slot for 1 item
											throwWarning("You specified two slots for one item. The first slot defined will be used", caller_id)
									else
											items[#items].slot = arg
										end
								else
										table.insert(items[#items], arg)
							end
							end

							-- if the user provided a slot letter but not any numbers to indicate an item_id, throw a warning and remove it from the table
							if #items[#items] == 0 then
									throwWarning("You did not define an item id for one of the entries. This entry will be skipped", caller_id)
									table.remove(items, #items)
							end
							-- if the user provided a number (indicating a item_id) but did not provide a slot letter, throw a warning and remove it from the table
							if not items[#items].slot then
									throwWarning("You did not define a slot for one of the entries. This entry will be skipped", caller_id)
									table.remove(items, #items)
							end
					end

					-- empty current startEquipment
					g_preferences.startEquipment.value = {}
					local value = g_preferences.startEquipment.value
					local PROPERTY_NAMES = {"id", "data1", "data2"}

					for k, v in ipairs(items) do
						-- for each item the user requested, add a table to the startEquipment table
						table.insert(value, {})
						value[#value].slot = v.slot -- save slot to current item
						for i = 1, 3 do -- for each piece of possible data (item_id, data1, data2)
							value[#value][PROPERTY_NAMES[i]] = v[i]
						end
					end
					COMMANDS.preferences.func(caller_id)
				end,
				cheats = function(caller_id, state)
					local new_state = toBool(state)
					local new_state_string = new_state and "enabled" or "disabled"
					if toBool(state) == nil then
						invalidArgument(caller_id, 1, "true/false/1/0")
						return
					else
						-- new state is the same as old one, abort
						if new_state == g_preferences.cheats.value then
							server.announce("SUCCESS", "Cheats are already " .. new_state_string, caller_id)
							return
						end
						-- set new states for "cheat" settings
						for k, v in ipairs(CHEAT_SETTINGS) do
							server.setGameSetting(GAME_SETTING_OPTIONS[k], new_state)
						end
						g_preferences.cheats.value = new_state

						-- give user feedback
						tellAdmins("CHEATS " .. new_state_string, "Cheats have been " .. new_state_string)
						if not Player.hasRole(caller_id, "Admin") then
							server.announce("SUCCESS", "Cheats have been " .. new_state_string, caller_id)
						end
					end
				end
			}

			local args = {...}
			local pref_data = g_preferences[preference_name]
			local accepted_type -- used for error reporting

			-- if this preference is an edge-case, then pass all of the args to the correct function
			if EDGE_CASES[preference_name] then
				EDGE_CASES[preference_name].func(caller_id, args)

			elseif pref_data then
				if pref_data.type == "string" then
					-- if target type is a string, assign user input
					pref_data.value = table.concat(args, " ")
				elseif pref_data.type == "number" then
					local value = toNumber(args[1]) -- convert user input from string
					if not value then -- if entry is not a number
						accepted_type = "number"
					else
						pref_data.value = value
					end
				elseif pref_data.type == "bool" then
					local value = toBool(args[1]) -- convert user input from string
					if not value then -- if entry is not a bool
						accepted_type = "bool"
					else
						pref_data.value = value
					end
				end

				-- give feedback to user
				if accepted_type then
					-- there was an incorrect type
					server.announce("FAILED", string.format("%s only accepts a %s as it's value", preference_name, accepted_type), caller_id)
				else
					-- tell all admins and the player (if they are not already an admin)
					tellAdmins("PREFERENCE EDITED", string.format("%s has set %s to:\n%s", Player.prettyName(caller_id), preference_name, tostring(pref_data.value)))
					if not Player.hasRole(caller_id, "Admin") then
						server.announce("SUCCESS", string.format("%s has been set to %s", preference_name, tostring(pref_data.value)), caller_id)
					end
				end
			else
				server.announce("FAILED", string.format("%s is not a preference", preference_name), caller_id)
			end
		end,
		args = {
			{name = "preference_name", type = {"string"}, required = true},
			{name = "value", type = {"string", "bool", "number"}, required = true}
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
					server.announce(v, g_preferences[v].value, caller_id)
				end
			end
			server.announce(" ", LINE, caller_id)
		end,
		description = "Lists the preferences and their states for you."
	},

	-- Game Settings
	setGameSetting = {
		func = function(caller_id, setting_name, value)
			local nearest = fuzzyStringInTable(setting_name, GAME_SETTING_OPTIONS, false)
			if nearest then
				-- abort if setting cannot be written to
				if GAME_SETTING_OPTIONS[nearest] == nil then
					server.announce("FAILED", string.format("%s cannot be written to", nearest), caller_id)
					return
				end

				local new_value = toBool(value)
				if new_value == nil then
					invalidArgument(caller_id, 2, "true/false/1/0")
					return
				else
					server.setGameSetting(nearest, value)

					-- give user feedback
					tellAdmins("GAME SETTING EDITED", string.format("%s changed %s to be %s", Player.prettyName(caller_id), nearest, tostring(value)))
					if not Player.hasRole(caller_id, "Admin") then
						server.announce("SUCCESS", string.format("%s is now set to %s", nearest, tostring(value)), caller_id)
					end
				end
			else
				server.announce("FAILED", string.format("%s is not a valid game setting. Use ?gameSettings to view them", setting_name), caller_id)
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
			server.announce(" ", "---------------------------  GAME SETTINGS  --------------------------", caller_id)
			for k, v in ipairs(alphabetical) do
				server.announce(v, game_settings[v], caller_id)
			end
			server.announce(" ", LINE, caller_id)
		end,
		description = "Lists all of the game settings and their states."
	},
}

---Looks through all of the commands to find the one requested. Also prepares arguments to be forwarded to requested command function
---@param peer_id number The peer_id of the player that used the command
---@param command string The name of the command that the user entered
---@param args table All of the arguments the user entered after the command
local function switch(peer_id, command, args)
	tellDebug("Switch", "Start Command: "..command)

	local command_data = COMMANDS[command]

	if command_data == nil then -- command does not exist, abort silently
		return
	end

	--tellDebug("Switch", "Got command data.")

	if not Player.hasAccessToCommand(peer_id, command) then
		server.announce("DENIED", string.format("You do not have access to %s", command), peer_id)
		return
	end

	--tellDebug("Switch", "User has access.")

	if command_data.cheat and not (g_preferences.cheats or g_playerData[Player.getSteamID(peer_id)].cheat) then
		-- command is a cheat and cheats are not enabled globally / this player does not have a role that enables cheats
		server.announce("DENIED", g_preferences.cheats and "Cheats are currently not enabled" or "You do not have access to cheat commands", peer_id)
		return
	end

	--tellDebug("Switch", "Cheat check pass.")

	if not command_data.args then
		command_data.func(peer_id)
		return
	end

	
	-- for each arg, check it is of a valid type and convert it from a string if necessary
	for argument_index, argument_data in ipairs(command_data.args) do
		--tellDebug("Switch", "Check arguments "..tostring(argument_index))

		-- if arg is required but not provided
		if argument_data.required and not args[argument_index] then
			local name, data = prettyFormatCommand(command, true, false, false)
			server.announce("INVALID ARG", string.format("%s requires \"%s\" to be in position %s\n%s", name, argument_data.name, argument_index, data), peer_id)
			return
		end

		-- check types, convert where necessary, and abort if necessary
		local is_valid = false
		local error_msg
		local accepted_types = {}
		for _, type_value in ipairs(argument_data.type) do -- for each valid type, check if the provided input is the same type
			if not args[argument_index] and not argument_data.required then break end
			local as_num = toNumber(args[argument_index])

			if type_value == "playerID" then
				if as_num then -- peerID given
					if PLAYER_LIST[as_num] then -- if player exists, convert arg to number
						args[argument_index] = as_num
						is_valid = true
						break
					else
						-- there is no player with the specified peerID
						error_msg = string.format("%s is not a valid peerID", args[argument_index])
					end
				else -- player name or "me" assumed to be given
					if args[argument_index] == "me" then -- if me was given, convert argument to caller's peerID
						args[argument_index] = peer_id
						is_valid = true
						break
					else
						-- assume a player name was given, convert argument to a peerID
						local player_names = {}
						local name_peer_ids = {}

						for player_name, player_data in pairs(PLAYER_LIST) do
							table.insert(player_names, player_data.name)
							name_peer_ids[player_data.name] = player_name
						end
						local nearest = fuzzyStringInTable(args[argument_index] or "", player_names, false) -- find player with nearest name to the one the user provided

						if not nearest then -- if no name is similar then prepare error
							error_msg = string.format("There is no player on the server with the name %s", args[argument_index])
						else
							-- player with same name was found, convert string to peerID
							args[argument_index] = name_peer_ids[nearest]
							is_valid = true
							break
						end
					end
				end
			elseif type_value == "vehicleID" then
				if as_num then -- number was given
					if g_vehicleList[as_num] then
						-- vehicle exists, convert arg to number
						args[argument_index] = as_num
						is_valid = true
						break
					else
						-- vehicle does not exist, prepare error
						error_msg = string.format("%s is not a valid vehicleID", args[argument_index])
					end
				else -- wrong data type was given, prepare error
					local name, data = prettyFormatCommand(command, true, true, false)
					table.insert(accepted_types, "number")
				end
			elseif type_value == "steam_id" then
				if #args[argument_index] ~= #STEAM_ID_MIN then -- string given is too small/large to be a steamID
					local name, data = prettyFormatCommand(command, true, true, false)
					table.insert(accepted_types, "steamIDs")
				else
					is_valid = true
					break
				end
			elseif type_value == "number" then
				if as_num then
					args[argument_index] = as_num
					is_valid = true
					break
				else
					table.insert(accepted_types, "number")
				end
			elseif type_value == "bool" then
				local as_bool = toBool(args[argument_index])
				if as_bool == nil then
					table.insert(accepted_types, "bool")
				else
					args[argument_index] = as_bool
					is_valid = true
					break
				end
			else
				is_valid = true
				break -- any others are assumed to be strings and are continued to be passed as strings
			end
		end

		if not is_valid then -- if there was an issue, print the error messages
			if #accepted_types > 0 then
				server.announce("INVALID ARG", string.format("%s expects %s in position %d to be a %s\n%s", command, argument_data.name, argument_index, table.concat(accepted_types, " or"), prettyFormatCommand(command, true, true, false)), peer_id)
			end
			if error_msg then
				server.announce("INVALID ARG", error_msg, peer_id)
			end
		end
	end

	--tellDebug("Switch", "Exec Command: "..command)

	-- all arguments should be converted to their true types now
	command_data.func(peer_id, table.unpack(args))
end

function onCustomCommand(message, peer_id, admin, auth, command, ...)
	if command == "?save" then return end -- server.save() calls onCustomCommand(), this aborts that

	local command = command:sub(2) -- cut off "?"
	if COMMANDS[command] and invalid_version then
		if (Player.hasRole(peer_id, "Admin") or Player.hasRole(peer_id, "Owner")) then -- delay version warnings for when an admin/owner joins
			throwWarning(
				string.format("Your code is older than your save data. (%s < %s) To prevent data loss/corruption, no data will be processed. Please update Carsa's Commands to the latest version.", tostring(g_savedata.version), tostring(SaveDataVersion)), peer_id)
		else
			throwWarning("There is a problem with the script so commands will not work, please notify an Admin", peer_id)
		end
		return
	end

	local args = {...}
	local steam_id = Player.getSteamID(peer_id)

	-- if player data cannot be found, call onPlayerJoin to create their data
	if not g_playerData[steam_id] then
		throwError(string.format("Persistent data for %s could not be found. It is either not defined or corrupted. Resetting player's data to defaults", Player.prettyName(peer_id)))
		onPlayerJoin(steam_id, server.getPlayerName(peer_id), peer_id)
	end

	switch(peer_id, command, args)
end



--! Export to json for website -------------------------------------------------
if jit == nil then return end -- Will make StormWonks return here and not choke on the stuff below


local json = require("json")

local function removeFunctions(t)
	for k,v in pairs(t) do
		if type(v) == "function" then
			t[k] = nil
		elseif type(v) == "table" then
			removeFunctions(v)
		end
	end
end



for cName,cTable in pairs(COMMANDS) do
	local access = {}
	cTable.defaultAccess = access
	for rName, rTable in pairs(DEFAULT_ROLES) do
		access[rName] = rTable.commands[cName] or false
	end
end


local exportData = {
	Commands = COMMANDS,
	Equipment_Data = EQUIPMENT_DATA,
	Equipment_Slots = EQUIPMENT_SLOTS,
}

removeFunctions(exportData)


local jsonString

if true then
	jsonString = json:encode_pretty(exportData)
else
	jsonString = json:encode(exportData)
end

print(jsonString)
