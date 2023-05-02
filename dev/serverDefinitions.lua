-- Stormworks Addon Lua Definitions
-- Stormworks v1.4.7 64bit

-- Recommended VSCode extension: https://marketplace.visualstudio.com/items?itemName=sumneko.lua

---@diagnostic disable: lowercase-global, unused-local, undefined-global, missing-return

---Persistent data table saved to the world's save file
g_savedata = {}

---@class LibAddonServer
server = {}
---@class LibAddonMatrix
matrix = {}
---@class LibAddonProperty
property = {}

--#region Types and Aliases

---@alias fraction number [0..1] Number between 0 and 1 (inclusive)
---@alias currency number

---@alias Peer_ID integer
---@alias Steam_ID string
---@alias Vehicle_ID integer
---@alias Object_ID integer
---@alias UI_ID integer


---@class Vector3
---@field x number
---@field y number
---@field z number

---@class Transform
---@field [ 1] number|1 Rotation and scale data
---@field [ 2] number   Rotation and scale data
---@field [ 3] number   Rotation and scale data
---@field [ 4] 0
---@field [ 5] number   Rotation and scale data
---@field [ 6] number|1 Rotation and scale data
---@field [ 7] number   Rotation and scale data
---@field [ 8] 0
---@field [ 9] number   Rotation and scale data
---@field [10] number   Rotation and scale data
---@field [11] number|1 Rotation and scale data
---@field [12] 0
---@field [13] number Position X (X on the in-game map)
---@field [14] number Position Y Altitude
---@field [15] number Position Z (Y on the in-game map)
---@field [16] 1


---@alias NOTIFICATION_TYPE
---|0 # new_mission
---|1 # new_mission_critical
---|2 # failed_mission
---|3 # failed_mission_critical
---|4 # complete_mission
---|5 # network_connect
---|6 # network_disconnect
---|7 # network_info
---|8 # chat_message
---|9 # network_info_critical

---@alias TYPE_STRING
---| "zone" # Mission zone type
---| "object" # Object type. Gets object_id
---| "character" # Character type. Gets object_id
---| "vehicle" # Vehicle type. Gets vehicle_id
---| "flare" # Flare type. Gets object_id
---| "fire" # Fire type. Gets object_id
---| "loot" # Loot type. Gets object_id
---| "button" # Button type. Gets object_id
---| "animal" # Animal type. Gets object_id
---| "ice" # Ice type. Gets object_id

---@alias POSITION_TYPE
---|0 # fixed
---|1 # vehicle
---|2 # object

---@alias MARKER_TYPE
---|0 # Delivery_target
---|1 # Survivor
---|2 # Object
---|3 # Waypoint
---|4 # Tutorial
---|5 # Fire
---|6 # Shark
---|7 # Ice
---|8 # Search_radius
---|9 # Flag_1
---|10 # Flag_2
---|11 # House
---|12 # Car
---|13 # Plane
---|14 # Tank
---|15 # Heli
---|16 # Ship
---|17 # Boat
---|18 # Attack
---|19 # Defend

---@alias LABEL_TYPE
---|0 # None
---|1 # Cross
---|2 # Wreckage
---|3 # Terminal
---|4 # Military
---|5 # Heritage
---|6 # Rig
---|7 # Industrial
---|8 # Hospital
---|9 # Science
---|10 # Airport
---|11 # Coastguard
---|12 # Lighthouse
---|13 # Fuel
---|14 # Fuel_sell

---@alias OBJECT_TYPE
---|0 # None
---|1 # Character
---|2 # Crate_small
---|3 # Collectable
---|4 # Basketball
---|5 # Television
---|6 # Barrel
---|7 # Schematic
---|8 # Debris
---|9 # Chair
---|10 # Trolley_food
---|11 # Trolley_med
---|12 # Clothing
---|13 # Office_chair
---|14 # Book
---|15 # Bottle
---|16 # Fryingpan
---|17 # Mug
---|18 # Saucepan
---|19 # Stool
---|20 # Telescope
---|21 # Log
---|22 # Bin
---|23 # Book_2
---|24 # Loot
---|25 # Blue_barrel
---|26 # Buoyancy_ring
---|27 # Container
---|28 # Gas_canister
---|29 # Pallet
---|30 # Storage_bin
---|31 # Fire_extinguisher
---|32 # Trolley_tool
---|33 # Cafetiere
---|34 # Drawers_tools
---|35 # Glass
---|36 # Microwave
---|37 # Plate
---|38 # Box_closed
---|39 # Box_open
---|40 # Desk_lamp
---|41 # Eraser_board
---|42 # Folder
---|43 # Funnel
---|44 # Lamp
---|45 # Microscope
---|46 # Notebook
---|47 # Pen_marker
---|48 # Pencil
---|49 # Scales
---|50 # Science_beaker
---|51 # Science_cylinder
---|52 # Science_flask
---|53 # Tub_1
---|54 # Tub_2
---|55 # Filestack
---|56 # Barrel_toxic
---|57 # Flare
---|58 # Fire
---|59 # Animal
---|60 # Map_label
---|61 # Iceberg
---|62 # Small_flare
---|63 # Big_flare

---@alias OUTFIT_TYPE
---|0 # None
---|1 # Worker
---|2 # Fishing
---|3 # Waiter
---|4 # Swimsuit
---|5 # Military
---|6 # Office
---|7 # Police
---|8 # Science
---|9 # Medical
---|10 # Wetsuit
---|11 # Civilian

---@alias ANIMAL_TYPE
---|0 # Shark
---|1 # Whale
---|2 # Seal
---|3 # Penguin

---@alias EQUIPMENT_ID
---|0 # None
---|1 # Diving
---|2 # Firefighter
---|3 # Scuba
---|4 # Parachute [int = {0 = deployed, 1 = ready}]
---|5 # Arctic
---|6 # Binoculars
---|7 # Cable
---|8 # Compass
---|9 # Defibrillator [int = charges]
---|10 # Fire_extinguisher [float = ammo]
---|11 # First_aid [int = charges]
---|12 # Flare [int = charges]
---|13 # Flaregun [int = ammo]
---|14 # Flaregun_ammo [int = ammo]
---|15 # Flashlight [float = battery]
---|16 # Hose [int = {0 = hose off, 1 = hose on}]
---|17 # Night_vision_binoculars [float = battery]
---|18 # Oxygen_mask [float = oxygen]
---|19 # Radio [int = channel] [float = battery]
---|20 # Radio_signal_locator [float = battery]
---|21 # Remote_control [int = channel] [float = battery]
---|22 # Rope
---|23 # Strobe_light [int = {0 = off, 1 = on}] [float = battery]
---|24 # Strobe_light_infrared [int = {0 = off, 1 = on}] [float = battery]
---|25 # Transponder [int = {0 = off, 1 = on}] [float = battery]
---|26 # Underwater_welding_torch [float = charge]
---|27 # Welding_torch [float = charge]
---|28 # Coal
---|29 # Hazmat
---|30 # Radiation_detector [float = battery]
---|31 # C4 [int = ammo]
---|32 # C4_detonator
---|33 # Speargun [int = ammo]
---|34 # Speargun_ammo
---|35 # Pistol [int = ammo]
---|36 # Pistol_ammo
---|37 # Smg [int = ammo]
---|38 # Smg_ammo
---|39 # Rifle [int = ammo]
---|40 # Rifle_ammo
---|41 # Grenade [int = ammo]
---|42 # Machine_gun_ammo_box_k
---|43 # Machine_gun_ammo_box_he
---|44 # Machine_gun_ammo_box_he_frag
---|45 # Machine_gun_ammo_box_ap
---|46 # Machine_gun_ammo_box_i
---|47 # Light_auto_ammo_box_k
---|48 # Light_auto_ammo_box_he
---|49 # Light_auto_ammo_box_he_frag
---|50 # Light_auto_ammo_box_ap
---|51 # Light_auto_ammo_box_i
---|52 # Rotary_auto_ammo_box_k
---|53 # Rotary_auto_ammo_box_he
---|54 # Rotary_auto_ammo_box_he_frag
---|55 # Rotary_auto_ammo_box_ap
---|56 # Rotary_auto_ammo_box_i
---|57 # Heavy_auto_ammo_box_k
---|58 # Heavy_auto_ammo_box_he
---|59 # Heavy_auto_ammo_box_he_frag
---|60 # Heavy_auto_ammo_box_ap
---|61 # Heavy_auto_ammo_box_i
---|62 # Battle_shell_k
---|63 # Battle_shell_he
---|64 # Battle_shell_he_frag
---|65 # Battle_shell_ap
---|66 # Battle_shell_i
---|67 # Artillery_shell_k
---|68 # Artillery_shell_he
---|69 # Artillery_shell_he_frag
---|70 # Artillery_shell_ap
---|71 # Artillery_shell_i

---@alias SLOT_NUMBER
---|1 # Large Equipment Slot
---|2 # Small Equipment Slot
---|3 # Small Equipment Slot
---|4 # Small Equipment Slot
---|5 # Small Equipment Slot
---|6 # Outfit Slot

---@alias FLUID_TYPE
---|0 # Water
---|1 # Diesel
---|2 # Jet_fuel
---|3 # Air
---|4 # Exhaust
---|5 # Oil
---|6 # Saltwater

---@alias ORE_TYPE
---|0 Coal
---|1 Iron
---|2 aluminium
---|3 gold
---|4 gold_dirt
---|5 uranium
---|6 ingot_iron
---|7 ingot_steel
---|8 ingot_aluminium
---|9 ingot_gold_impure
---|10 ingot_gold
---|11 ingot_uranium


---@alias GAME_SETTING
---| "third_person"
---| "third_person_vehicle"
---| "vehicle_damage"
---| "player_damage"
---| "npc_damage"
---| "sharks" Allow sharks to spawn.
---| "fast_travel"
---| "teleport_vehicle"
---| "rogue_mode"
---| "auto_refuel"
---| "megalodon" Allow big shark to spawn.
---| "map_show_players"
---| "map_show_vehicles"
---| "show_3d_waypoints"
---| "show_name_plates"
---| "day_night_length" # currently cannot be written to
---| "sunrise" # currently cannot be written to
---| "sunset" # currently cannot be written to
---| "infinite_money"
---| "settings_menu"
---| "unlock_all_islands" # Cannot be unset once activated.
---| "infinite_batteries"
---| "infinite_fuel"
---| "engine_overheating"
---| "no_clip"
---| "map_teleport"
---| "cleanup_vehicle"
---| "clear_fow" # clear fog of war
---| "vehicle_spawning"
---| "photo_mode"
---| "respawning"
---| "settings_menu_lock"
---| "despawn_on_leave" # despawn player characters when they leave a server
---| "unlock_all_components"


---@alias ZONE_TYPE
---|0 Box
---|1 Sphere
---|2 Radius

--#endregion

--#region Callback Functions

---Called every game tick
---@param game_ticks number The number of ticks that have passed this frame. Usually this value is 1 but when the player is sleeping, it is 400
function onTick(game_ticks) end

---Called when world is loaded
---@param is_new_save boolean If the world is new (just created).
function onCreate(is_new_save) end

---Called when the world is exited and the server is closed
---**NOTE:** HTTP requests that are queued in this function, or are already waiting in the queue, will not be sent after this is called as the world instantly closes without waiting.
function onDestroy() end

---Called when a user enters a message prefixed by `?` in the chat
---@param message string The entire message sent by the player
---@param peer_id Peer_ID The peer_id of the player that sent the command
---@param admin boolean If the player executing the command is an admin
---@param auth boolean If the player executing the command is authorized
---@param command string The command entered by the player **including** the `?` prefix
---@vararg string arguments following `command` can be manually defined or you can use the variable parameter (...)
---## Example of manually defining:
---```
---function onCustomCommand(message, peer_id, admin, auth, command, arg1, arg2, arg3)
---end
---```
---## Example of using variable arguments (...):
---```
---function onCustomCommand(message, peer_id, admin, auth, command, ...)
---    local args = {...} -- you now have a table of args
---end
---```
function onCustomCommand(message, peer_id, admin, auth, command, ...) end

---Called when a message is sent to the chat
---@param peer_id Peer_ID The peer_id of the player that sent the message
---@param sender_name string The name of the player that sent the message
---@param message string The message the player sent
function onChatMessage(peer_id, sender_name, message) end

---Called when a player joins the server
---@param steam_id string The steam id of the player. Must be stored as a string because Lua does not have the precision for such a large number
---@param name string The name of the player that joined
---@param peer_id Peer_ID The peer_id of the player that joined
---@param admin boolean If the player is and admin
---@param auth boolean If the player is authorized
function onPlayerJoin(steam_id, name, peer_id, admin, auth) end

---Called whenever a player sits in a seat or gets on a ladder
---@param peer_id Peer_ID The peer_id of the player that has sat down
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the seat is attached to
---@param seat_name string The name of the seat the player sat in
function onPlayerSit(peer_id, vehicle_id, seat_name) end

---Called whenever a player gets out of a seat or gets off a ladder
---@param peer_id Peer_ID The peer_id of the player that has gotten out of the seat
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the seat is attached to
---@param seat_name string The name of the seat the player got out of
function onPlayerUnsit(peer_id, vehicle_id, seat_name) end

---Called whenever a character sits (or is sat) in a seat or gets on a ladder
---@param object_id Object_ID The object_id of the character that has sat down
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the seat is attached to
---@param seat_name string The name of the seat the character sat in
function onCharacterSit(object_id, vehicle_id, seat_name) end

---Called whenever a character gets out of it's seat (or is picked up from their seat) or gets off a ladder
---@param object_id Object_ID The object_id of the character that has gotten out of the seat
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the seat is attached to
---@param seat_name string The name of the seat the character got out of
function onCharacterUnsit(object_id, vehicle_id, seat_name) end

---Called when a player **re**spawns
---@param peer_id Peer_ID The peer_id of the user that has respawned
function onPlayerRespawn(peer_id) end

---Called whenever a player leaves the server
---@param steam_id string The steam_id of the player that has left. Must be stored as a string because Lua does not have the precision for such a large number
---@param name string The name of the player that has left
---@param peer_id Peer_ID The peer_id of the player that has left
---@param admin boolean If the player was an admin
---@param auth boolean If the player was authorized
function onPlayerLeave(steam_id, name, peer_id, admin, auth) end

---Called whenever a player opens/closes their map
---@param peer_id Peer_ID The peer_id of the player
---@param open boolean Wether the map is now open or closed
function onToggleMap(peer_id, open) end

---Called whenever a player dies
---@param steam_id string The steam_id of the player that has died
---@param name string The name of the player that has died
---@param peer_id Peer_ID The peer_id of the player that has died
---@param admin boolean If the player is an admin
---@param auth boolean If the player is authorized
function onPlayerDie(steam_id, name, peer_id, admin, auth) end

---Called whenever a vehicle is spawned (added to the world).
---@param vehicle_id Vehicle_ID The vehicle_id of the new vehicle
---@param peer_id Peer_ID The peer_id of the player that spawned the vehicle. If the vehicle was spawned by the server it will be -1
---@param x number The x position the vehicle was spawned at
---@param y number The y position the vehicle was spawned at
---@param z number The z position the vehicle was spawned at
---@param cost number The cost of the vehicle in Stormworks currency
function onVehicleSpawn(vehicle_id, peer_id, x, y, z, cost) end

---Called whenever a vehicle is despawned (removed from the world).
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle that has been despawned
---@param peer_id Peer_ID The peer_id of the player that despawned the vehicle. If it was despawned by the server then this value will be -1
function onVehicleDespawn(vehicle_id, peer_id) end

---Called whenever a vehicle loads into the world (is visible and has physics)
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle that has loaded
function onVehicleLoad(vehicle_id) end

---Called whenever a vehicle unloads from the world (no longer visible, no physics but still present).
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle that has unloaded
function onVehicleUnload(vehicle_id) end

---Called whenever a vehicle is teleported
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle that has teleported
---@param peer_id Peer_ID The peer_id of the player that teleported the vehicle. If the server teleported it, this values is -1
---@param x number The new x position value
---@param y number The new y position value
---@param z number The new z position value
function onVehicleTeleport(vehicle_id, peer_id, x, y, z) end

---Called whenever an object loads and begins simulating
---@param object_id Object_ID The object_id of the object that has loaded
function onObjectLoad(object_id) end

---Called whenever an object unloads and stops simulating
---@param object_id Object_ID The object_id of the object that has unloaded
function onObjectUnload(object_id) end

---Called whenever a button is pressed/released (but not held) on a vehicle
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the button is a part of
---@param peer_id Peer_ID The peer_id of the player that pressed the button. If the button was pressed by the server this value will be -1
---@param button_name string The name of the button that was pressed
function onButtonPress(vehicle_id, peer_id, button_name) end

---Called whenever an addon's component is spawned
---@param id Vehicle_ID|Object_ID The vehicle_id **or** object_id of the component
---@param component_name string The name of the component
---@param type TYPE_STRING The component type
---@param addon_index number The index of the addon that this component belongs to
function onSpawnAddonComponent(id, component_name, type, addon_index) end

---Called whenever a vehicle receives damage
---@param vehicle_id Vehicle_ID The vehicle_id of the damaged vehicle
---@param damage_amount number The amount of damage the vehicle received
---@param voxel_x number The x position of the voxel that was damaged
---@param voxel_y number The y position of the voxel that was damaged
---@param voxel_z number The z position of the voxel that was damaged
---@param body_index number 0 is the vehicle's main body. Can be used to ignore damage on child bodies
function onVehicleDamaged(vehicle_id, damage_amount, voxel_x, voxel_y, voxel_z, body_index) end

---Called whenever the server receives a http reply
---@param port number The port the reply came in on
---@param url string The url the reply is coming from
---@param response_body string The response body of the reply
function httpReply(port, url, response_body) end

---Called whenever a fire is extinguished
---@param x number The x position of the now extinguished fire
---@param y number The y position of the now extinguished fire
---@param z number The z position of the now extinguished fire
function onFireExtinguished(x, y, z) end

---Called whenever a forest fire is spawned. A forest fire is defined as a fire that spreads to 5 or more trees.
---@param objective_id number The id of the objective to extinguish the fire
---@param x number The x position of the new fire
---@param y number The y position of the new fire
---@param z number The z position of the new fire
function onForestFireSpawned(objective_id, x, y, z) end

---Called whenever a fire is extinguished
---@param objective_id number The id of the objective to extinguish the fire
---@param x number The x position of the now extinguished fire
---@param y number The y position of the now extinguished fire
---@param z number The z position of the now extinguished fire
function onForestFireExtinguished(objective_id, x, y, z) end

--#endregion

--#region UI

---Prints a message in the chat for players
---@param title string The title of message. Appears in orange on the left side of the chat like a player's name
---@param message string|number The content of the message
---@param peer_id? Peer_ID The peer_id of the player to send the message to. -1 (default) will send to all players
function server.announce(title, message, peer_id) end

---Will display a card/toast on the right side of the screen containing the title, message, and an icon based on the NOTIFICATION_TYPE
---@param peer_id Peer_ID The peer_id of the player to send the message to
---@param title string|number The title of the message. Appears above the message
---@param message string|number The content of the message
---@param NOTIFICATION_TYPE NOTIFICATION_TYPE The type of notification. Dictates the icon displayed and color of the title
function server.notify(peer_id, title, message, NOTIFICATION_TYPE) end

---Returns a unique ID to be used with all other UI functions. Removing a mapID will remove all of it's associated UI elements
---@return UI_ID ui_id The id to be used with other UI functions. UI elements that contain unique data MUST have their own ui_id. However, if you want to display the same label or popup for all players, you can re-use the same ui_id
function server.getMapID() end

---Removes all UI that uses the provided ui_id for the provided player
---@param peer_id Peer_ID The peer_id of the player who's UI you want to change
---@param ui_id UI_ID The ui_id of the UI elements you want to remove
function server.removeMapID(peer_id, ui_id) end

---Add a map marker for the specified player
---@param peer_id Peer_ID The peer_id of the player you want to add a map object for
---@param ui_id UI_ID The ui_id you want to use for this object
---@param position_type POSITION_TYPE The type of position this object will use. If set to 1 (vehicle) or 2 (object), the marker will track the vehicle/object using it's ID, if provided
---@param marker_type MARKER_TYPE The type of marker this object will use (visual appearance)
---@param x number The x position of the marker
---@param z number The z position of the marker
---@param parent_local_x number The x position offset value for when the marker is tracking a vehicle/object
---@param parent_local_z number The y position offset value for when the marker is tracking a vehicle/object
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle to track if `position_type = 1`
---@param object_id Object_ID The object_id of the object to track if `position_type = 2`
---@param label string The label that appears next to the object on the map
---@param radius number The radius of the marker area, not the marker icon size.
---@param hover_label string The text that appears when hovering the map marker
---@param r number The red value of the marker
---@param g number The green value of the marker
---@param b number The blue value of the marker
---@param a number The alpha value of the marker
function server.addMapObject(peer_id, ui_id, position_type, marker_type, x, z, parent_local_x, parent_local_z, vehicle_id, object_id, label, radius, hover_label, r, g, b, a) end

---Removes a map object with the specified ui_id for the specified player
---@param peer_id Peer_ID The peer_id of the player to remove the map object for
---@param ui_id UI_ID The ui_id of the map object to remove
function server.removeMapObject(peer_id, ui_id) end

---Add a label to the map, like those that appear at named locations on the map. Labels will appear under the fog of war, meaning they are hidden until discovered.
---@param peer_id Peer_ID The peer_id of the player to add the label for
---@param ui_id UI_ID The ui_id to use for this label
---@param label_type LABEL_TYPE The type of icon to use for this label
---@param name string The text that should appear on this label
---@param x number The x position of this label in world space
---@param z number The z position of this label in world space
function server.addMapLabel(peer_id, ui_id, label_type, name, x, z) end

---Remove a map label for a player
---@param peer_id Peer_ID The peer_id of the player you want to remove this label for
---@param ui_id UI_ID The ui_id of this label
function server.removeMapLabel(peer_id, ui_id) end

---Draw a line on the map for a player
---@param peer_id Peer_ID The peer_id of the player to draw the line for
---@param ui_id UI_ID The ui_id to use for this line
---@param start_matrix Transform The starting matrix for the line
---@param end_matrix Transform The end matrix for the line
---@param width number The width of the line
---@param r number? The red colour value of the line
---@param g number? The green colour value of the line
---@param b number? The blue colour value of the line
---@param a number? The alpha colour value of the line
function server.addMapLine(peer_id, ui_id, start_matrix, end_matrix, width, r, g, b, a) end

---Remove a line from the map for a player
---@param peer_id Peer_ID The peer_id of the player to remove the line for
---@param ui_id UI_ID The ui_id of this line
function server.removeMapLine(peer_id, ui_id) end

---Creates or overwrites an in-world popup for the player
---@param peer_id Peer_ID The peer_id of the player to set the popup for
---@param ui_id UI_ID The ui_id to use for this popup
---@param name string The name of the popup. Seems to have no effect
---@param is_shown boolean If the popup is visible or not
---@param text string The text that should appear within the popup
---@param x number The x position value of the popup in world space. Serves as a relative offset if a parent vehicle/object is provided
---@param y number The y position value of the popup in world space. Serves as a relative offset if a parent vehicle/object is provided
---@param z number The z position value of the popup in world space. Serves as a relative offset if a parent vehicle/object is provided
---@param render_distance number The distance in meters that the player should be able to see the popup. If the user is father than this amount away, the popup will no longer show. Setting this value to 0 means it will always be visible
---@param parent_vehicle_id? Vehicle_ID The vehicle_id of the parent vehicle to follow. Optional
---@param parent_object_id? Object_ID The object_id of the parent object to follow. Optional
function server.setPopup(peer_id, ui_id, name, is_shown, text, x, y, z, render_distance, parent_vehicle_id, parent_object_id) end

---Creates or overwrites an on-screen popup for the player, like a UI element
---@param peer_id Peer_ID The peer_id of the player to set the popup for
---@param ui_id UI_ID The ui_id to use for this popup
---@param name string The name of the popup. Seems to have no effect
---@param is_shown boolean If the popup is visible or not
---@param text string The text that should appear within the popup
---@param horizontal_offset number The horizontal position of the popup. -1 is the left screen edge, 1 is the right screen edge
---@param vertical_offset number The vertical position of the popup. -1 is the bottom screen edge, 1 is the top screen edge
function server.setPopupScreen(peer_id, ui_id, name, is_shown, text, horizontal_offset, vertical_offset) end

---Remove a popup for a player. Works on screen popups as well
---@param peer_id Peer_ID The peer_id of the player to remove the popup for
---@param ui_id UI_ID The ui_id of the popup
function server.removePopup(peer_id, ui_id) end

--#endregion

--#region Administrative

---Bans a player from this save. Cannot be reversed unless you create a new save.
---@param peer_id Peer_ID The peer_id of the player to ban
function server.banPlayer(peer_id) end

---Kicks a player from the server
---@param peer_id Peer_ID The peer_id of the player to kick
function server.kickPlayer(peer_id) end

---Makes the target player an admin. Gives them access to admin commands such as ?kick and ?ban
---@param peer_id Peer_ID The peer_id of the player to give admin permissions to
function server.addAdmin(peer_id) end

---Removes admin privileges from a player
---@param peer_id Peer_ID The peer_id of the player to remove admin permissions from
function server.removeAdmin(peer_id) end

---Authorizes the target player. Gives them access to spawn vehicles
---@param peer_id Peer_ID The peer_id of the player to authorize
function server.addAuth(peer_id) end

---Removes auth permissions from a player. This disables their ability to spawn vehicles
---@param peer_id Peer_ID The peer_id of the player to remove authorization from
function server.removeAuth(peer_id) end

---Saves the game. Only works on dedicated servers
---@param save_name? string the name of the save to use. If omitted, the currently loaded save will be overwritten
function server.save(save_name) end

--#endregion

--#region Addon

---Get the index of this addon
---@param name? string The name of the index you want to get the index of. If omitted, this function will get the current addon's index
---@return number addon_index The index of this addon. This value can not be guaranteed to be the same between loads
---@return boolean is_success If the function succeeded
function server.getAddonIndex(name) return addon_index, is_success end

---Get the index of a location by it's name
---@param addon_index number The index of the addon that the location belongs to
---@param name string The name of the location to get the index of
---@return number location_index The index of the location
---@return boolean is_success If the function succeeded
function server.getLocationIndex(addon_index, name) return location_index, is_success end

---Spawn an addon location by it's name
---@param name string The name of the addon location to spawn
---@return boolean is_success If the function succeeded
function server.spawnThisAddonLocation(name) return is_success end

---Spawns an addon location using indexes
---@param matrix Transform The matrix to spawn the location at. If the x, y, z of the matrix are 0, 0, 0, the location will be spawned at a random position in a random tile of the same type as this location's
---@param addon_index number The index of the addon this location belongs to
---@param location_index number The index of the location
---@return Transform matrix The spawn location matrix
---@return boolean is_success If the function succeeded
function server.spawnAddonLocation(matrix, addon_index, location_index) return matrix, is_success end

---Get the filepath of the addon
---@param name string The name of the addon to get the path of
---@param is_rom boolean If true, this function will look in the directory for dev-made addons
---@return string path The filepath to this addon
---@return boolean is_success If the function succeeded
function server.getAddonPath(name, is_rom) return path, is_success end


---@class GetZonesResult : GetAddonDataResult
---@field size { x: number, y: number, z: number } The size of the zone.
---@field radius number The radius of the zone if the type is sphere.
---@field type ZONE_TYPE The type (shape) of the zone.
---@field tags string[] The tags of the zone.
---@field tags_full string
---@field transform Transform the position, rotation and scale information.

---Get a table of all active ENV mod zones. You can provide tags seperated by commas to only return zones with matching tags.
---@vararg string Tags you want to use to filter
---@return GetZonesResult[] zone_list The table of active zones
---## Example zone_list:
---```
---{
---    [zone_index] = {
---        ["tags_full"] = tags,
---        ["tags"] = { [i] = tag },
---        ["name"] = name,
---        ["transform"] = transform_matrix,
---        ["size"] = {x, y, z},
---        ["radius"] = radius,
---        ["type"] = ZONE_TYPE
---    }
---}
---```
function server.getZones(...) return zone_list end

---Check if a matrix is in an ENV mod zone
---@param matrix Transform The matrix to check
---@param zone_display_name string The name of the ENV mod zone to check against
---@return boolean in_zone If the matrix is within the zone
---@return boolean is_success If the function succeeded
function server.isInZone(matrix, zone_display_name) return in_zone, is_success end

---Get the amount of addons currently active on this save
---@return number count The number of addons currently active
function server.getAddonCount() return count end

---@class GetAddonDataResult
---@field name string Name of the addon.
---@field path_id string Path of the addon.
---@field file_store boolean is_app_data
---@field location_count integer The number of locations in the addon.

---Get an addon's data
---@param addon_index number The index of the addon
---@return GetAddonDataResult? addon_data The data of the addon
--- ## Example Addon Data
---```
---{
---    ["name"] = name,
---    ["path_id"] = folder_path,
---    ["file_store"] = is_app_data,
---    ["location_count"] = location_count
---}
---```
function server.getAddonData(addon_index) return addon_data end

---@class GetLocationDataResult
---@field name string Name of the location.
---@field tile string Name of the Tile the location is on.
---@field env_spawn_count? integer How many times the location will spawn, 0 for unlimited. This only matters if the location is on a non-unique tile.
---@field env_mod boolean Is this location an env_mod (env_mods are always active, mission_locations must be spawned by script).
---@field component_count integer The number of components in the location.

---Get data on a location
---@param addon_index number The index of the addon that the location is a part of
---@param location_index number The index of the location
---@return GetLocationDataResult location_data The data on the location
---@return boolean is_success If the function succeeded
---## Example Location Data
---```
---LOCATION_DATA = {
---    ["name"] = name,
---    ["tile"] = tile_filename,
---    ["env_spawn_count"] = spawn_count,
---    ["env_mod"] = is_env_mod,
---    ["component_count"] = component_count
---}
---```
function server.getLocationData(addon_index, location_index) return location_data, is_success end

---Get data on a component in a location
---@param addon_index number The index of the addon that the location is a part of
---@param location_index number The index of the location that the component is a part of
---@param component_index number The index of the component
---@return GetLocationComponentDataResult component_data The data on the component
---@return boolean is_success If the function succeeded
---## Example Component Data
---```
---COMPONENT_DATA = {
---    ["tags_full"] = tags,
---    ["tags"] = { [i] = tag },
---    ["display_name"] = display_name,
---    ["type"] = TYPE_STRING,
---    ["id"] = component_id,
---    ["dynamic_object_type"] = OBJECT_TYPE,
---    ["transform"] = transform_matrix,
---    ["vehicle_parent_component_id"] = vehicle parent component id ,
---    ["character_outfit_type"] = OUTFIT_TYPE
---}
---```
function server.getLocationComponentData(addon_index, location_index, component_index) return component_data, is_success end

---@class AddonComponentBase
---@field tags_full string
---@field tags string[]
---@field display_name string
---@field type TYPE_STRING
---@field transform Transform
---@field id Object_ID|Vehicle_ID

---@class GetLocationComponentDataResult : AddonComponentBase
---@field dynamic_object_type OBJECT_TYPE
---@field vehicle_parent_component_id Vehicle_ID
---@field character_outfit_type OUTFIT_TYPE

---@class SpawnAddonComponentResult : AddonComponentBase

---Spawn an addon's component
---@param matrix Transform The matrix to spawn the component at
---@param addon_index number The index of the addon that the location is a part of
---@param location_index number The index of the location that the component is a part of
---@param component_index number The index of the component
---@param parent_vehicle_id? Vehicle_ID The parent vehicle for a zone or fire
---@return SpawnAddonComponentResult component Data on the component
---@return boolean is_success If the function succeeded
---## Example Component Data
---```
---COMPONENT = {
---    ["tags_full"] = tags,
---    ["tags"] = { [i] = tag },
---    ["display_name"] = display_name,
---    ["type"] = TYPE_STRING,
---    ["transform"] = transform_matrix,
---    ["id"] = object_id/vehicle_id
---}
---```
function server.spawnAddonComponent(matrix, addon_index, location_index, component_index, parent_vehicle_id) return component, is_success end

---Spawn a vehicle from an addon
---@param matrix Transform The matrix position to spawn the vehicle at
---@param addon_index number The index of the addon that the vehicle belongs to
---@param component_id number The id of the component
---@return Vehicle_ID|nil vehicle_id The vehicle_id of the vehicle that has spawned
---@return boolean is_success If the function succeeded
---@see server.getLocationComponentData to get component_id
function server.spawnAddonVehicle(matrix, addon_index, component_id) return vehicle_id, is_success end

--#endregion

--#region Player

---@class PlayerListItem
---@field id Peer_ID
---@field name string
---@field admin boolean
---@field auth boolean
---@field steam_id Steam_ID

---Get a table that lists data on all players connected to the server
---@return PlayerListItem[] player_list The table of player data
---## Example Player Data
---```
--- {
---     [3] = {
---         ["id"] = 1,
---         ["name"] = carsakiller,
---         ["admin"] = false,
---         ["auth"] = true,
---         ["steam_id"] = "76561198048154493"
---     }
---}
---```
--- **NOTE:** The index at which entries appear **WILL LIKELY NOT** be the same value as the player's peer_id
function server.getPlayers() return player_list end

---Get the name of the player as it appears to the server
---@param peer_id Peer_ID The peer_id of the player who's name will be found
---@return string name The name of the player
---@return boolean is_success If the function succeeded and a name was returned
function server.getPlayerName(peer_id) return name, is_success end

---Get the position of a player. This matrix does not contain any rotation data
---@param peer_id Peer_ID The peer_id of the player to get the position of
---@return Transform player_matrix The position of the player as a matrix
---@return boolean is_success If the function succeeded
function server.getPlayerPos(peer_id) return player_matrix, is_success end

---Set the position of a player
---@param peer_id Peer_ID The peer_id of the player to teleport
---@param matrix Transform The new position of the player
---@return boolean is_success If the function succeeded
function server.setPlayerPos(peer_id, matrix) return is_success end

---Get the player's look direction vector
---@param peer_id Peer_ID The peer_id of the player to get the look direction of
---@return number x Look direction vector on the x axis
---@return number y Look direction vector on the y axis
---@return number z Look direction vector on the z axis
function server.getPlayerLookDirection(peer_id) return x, y, z end

---Get the id of the character object that represents that player.
---@param peer_id Peer_ID The peer_id of the player to get the object_id of
---@return Object_ID object_id The object_id of the player's character
---@return boolean is_success If the function succeeded
function server.getPlayerCharacterID(peer_id) return object_id, is_success end

--#endregion

--#region Vehicle

---Spawns a vehicle from the host's vehicle save directory
---@param matrix Transform The matrix position to spawn the vehicle at
---@param save_name string The name of the vehicle save to spawn
---@return Vehicle_ID|nil vehicle_id The vehicle_id of the vehicle that has been spawned
---@return boolean is_success If the function succeeded
function server.spawnVehicle(matrix, save_name) return vehicle_id, is_success end

---Despawns a vehicle
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle to despawn
---@param instant boolean If the vehicle should be despawned immediately or when it unloads from the world
---@return boolean is_success If the function succeeded
function server.despawnVehicle(vehicle_id, instant) return is_success end

---Get the position of a vehicle. A specific voxel of the vehicle can be specified
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle to get the position of
---@param voxel_x? number The x position of the voxel offset
---@param voxel_y? number The y position of the voxel offset
---@param voxel_z? number The z position of the voxel offset
---@return Transform matrix The position matrix
---@return boolean is_success If the function succeeded
function server.getVehiclePos(vehicle_id, voxel_x, voxel_y, voxel_z) return matrix, is_success end

---Set the position of a vehicle
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle to teleport
---@param matrix Transform The matrix position the vehicle should be teleported to
---@return boolean is_success If the function succeeded
function server.setVehiclePos(vehicle_id, matrix) return is_success end

---Set the position of a vehicle. The target vehicle will be teleported to the target matrix and will be displaced by
---any other vehicles that are in the way. This prevents the target vehicle from being teleported inside another.
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle to teleport
---@param matrix Transform The matrix position the vehicle should be teleported to
---@return boolean is_success If the function succeeded
function server.setVehiclePosSafe(vehicle_id, matrix) return is_success end

---Get a vehicle's file name. If the vehicle has not been saved, the name will be "Error"
---@param vehicle_id Vehicle_ID The id of the vehicle
---@return string name The name of the vehicle
---@return boolean is_success If the function succeeded and a name was returned
function server.getVehicleName(vehicle_id) return name, is_success end

---@class VehicleComponentData
---@field name string
---@field pos Vector3

---@class ButtonData: VehicleComponentData
---@field on boolean

---@class SeatData: VehicleComponentData
---@field seated_id integer the id of the seated character

---@class SignData: VehicleComponentData

---@class DialData: VehicleComponentData
---@field value number
---@field value2 number? The secondary value if the dial has one.

---@class HopperData: VehicleComponentData
---@field values table<ORE_TYPE, number>
---@field capacity number

---@class BatteryData: VehicleComponentData
---@field charge number [0..1]

---@class WeaponData: VehicleComponentData
---@field ammo integer
---@field capacity integer

---@class RopeHookData: VehicleComponentData


---@class TankData: VehicleComponentData
---@field value number current total content
---@field values table<FLUID_TYPE, number> mapping from FLUID_TYPE to amount.
---@field capacity number
---@field fluid_type FLUID_TYPE The fluid type that was set in the vehicle designer.

---@class VehicleComponents
---@field signs SignData[]
---@field seats SeatData[]
---@field buttons ButtonData[]
---@field dials DialData[]
---@field tanks TankData[]
---@field batteries BatteryData[]
---@field hoppers HopperData[]
---@field guns WeaponData[]
---@field rope_hooks RopeHookData[]

---@class VehicleData
---@field tags_full string Raw tags string
---@field tags string[] Parsed tags
---@field filename string?
---@field transform Transform
---@field simulating boolean
---@field mass number
---@field characters Object_ID[]
---@field voxels integer Voxel count
---@field editable boolean
---@field invulnerable boolean
---@field static boolean Static vehicles do not move, and do not check for collision with the ground, or other static vehicles.
---@field components VehicleComponents

---Get data on a vehicle
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle to get data on
---@return VehicleData vehicle_data The data of the vehicle
---@return boolean is_success If the function succeeded
---## Example Vehicle Data
---```
---{
---    ["tags_full"] = "foo=1,bar",
---    ["tags"] = { [1] = "foo=1" [2] = "bar" },
---    ["filename"] = "vehicle_file_name.xml",
---    ["transform"] = { [1] = 1, [2] = 0, ...},
---    ["simulating"] = true,
---    ["mass"] = 1234.125,
---    ["characters"] = { 42, 69, ... }
---    ["voxels"] = 512
---}
---```
function server.getVehicleData(vehicle_id) return vehicle_data, is_success end

---Removes all player spawned vehicle from the world
function server.cleanVehicles() end

---Override the controls of a seat on a vehicle
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the seat is a part of
---@param seat_name string The name of the seat to control. The first seat found with a matching name is selected
---@param w_axis number The w/s axis value from -1 to 1
---@param d_axis number The a/d axis value from -1 to 1
---@param up_axis number The up/down axis value from -1 to 1
---@param right_axis number the right/left axis value from -1 to 1
---@param button_1 boolean The button_1 value of the seat
---@param button_2 boolean The button_2 value of the seat
---@param button_3 boolean The button_3 value of the seat
---@param button_4 boolean The button_4 value of the seat
---@param button_5 boolean The button_5 value of the seat
---@param button_6 boolean The button_6 value of the seat
---@param trigger boolean The trigger value of the seat
function server.setVehicleSeat(vehicle_id, seat_name, w_axis, d_axis, up_axis, right_axis, button_1, button_2, button_3, button_4, button_5, button_6, trigger) end

---Presses the first button found a the specified vehicle with a matching name
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the button is a part of
---@param button_name string The name of the button to press
function server.pressVehicleButton(vehicle_id, button_name) end


---@class GetVehicleButtonResult
---@field name string
---@field pos Vector3
---@field on boolean is_pressed

---Get the state of a button on a vehicle
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the button is a part of
---@param button_name string The name of the button to get the state of
---@return GetVehicleButtonResult button_data The data of the button
---@return boolean is_success If the function succeeded
---## Example Button Data
---```
---{
---    ["on"] = is_on
---}
---```
function server.getVehicleButton(vehicle_id, button_name) return button_data, is_success end

---Get the position of a sign block on a vehicle
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the sign is a part of
---@param sign_name string The name of the sign
---@return { pos: { x: integer, y: integer, z: integer }} sign_data The position of the sign as a table
---@return boolean is_success If the function succeeded
---## Example Sign Data
---```
---{
---    ["pos"] = {
---        x = voxel_x,
---        y = voxel_y,
---        z = voxel_z
---    }
---}
---```
function server.getVehicleSign(vehicle_id, sign_name) return sign_data, is_success end

---Set the value of a vehicle's keypad
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the keypad is a part of
---@param keypad_name string The name of the keypad
---@param value number The value to set the keypad to
---@param value2? number The second value to set the keypad to, if it has one.
function server.setVehicleKeypad(vehicle_id, keypad_name, value, value2) end

---@class GetVehicleDialResult
---@field value number the value displayed on the dial.
---@field value2? number If the dial can display two values: that second value.

---Get the number value from a vehicle's dial
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the dial is a part of
---@param dial_name string The name of the dial
---@return GetVehicleDialResult dial_data The data of the dial
---@return boolean is_success If the function succeeded
---## Example Dial Data
---```
---{
---    ["value"] = primary_value,
---    ["value2"] = secondary_value
---}
---```
function server.getVehicleDial(vehicle_id, dial_name) return dial_data, is_success end

---Sets the fluid type and fill level of a fluid tank on a vehicle
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the tank is a part of
---@param tank_name string The name of the tank to edit
---@param amount number The fill amount (0 - 1)
---@param fluid_type FLUID_TYPE The type of fluid to fill with
function server.setVehicleTank(vehicle_id, tank_name, amount, fluid_type) end

---@class GetVehicleTankResult
---@field value number Amount of fluid in the tank.
---@field capacity number Amount of fluid the tank can contain.
---@field fluid_type FLUID_TYPE The fluid in the tank.

---Get data on a vehicle's fluid tank
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the tank is a part of
---@param tank_name string The name of the tank
---@return GetVehicleTankResult tank_data The data of the tank
---@return boolean is_success If the function succeeded
---## Example Tank Data
---```
---{
---    ["value"] = current_level,
---    ["capacity"] = total_capacity,
---    ["fluid_type"] = FLUID_TYPE
---}
---```
function server.getVehicleTank(vehicle_id, tank_name) return tank_data, is_success end

---Sets the amount of coal in a hopper
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the hopper is a part of
---@param hopper_name string The name of the hopper
---@param amount number The amount of coal to set in the hopper
function server.setVehicleHopper(vehicle_id, hopper_name, amount) end

---Get data on a vehicle's hopper
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the hopper is a part of
---@param hopper_name string The name of the hopper
---@return { value: number, capacity: number } hopper_data The data of the hopper
---@return boolean is_success If the function succeeded
---## Example Hopper Data
---```
---{
---    ["value"] = current_level,
---    ["capacity"] = total_capacity
---}
---```
function server.getVehicleHopper(vehicle_id, hopper_name) return hopper_data, is_success end

---Sets the charge of a battery
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the battery is a part of
---@param battery_name string The name of the battery
---@param amount number The new charge of the battery
function server.setVehicleBattery(vehicle_id, battery_name, amount) end

---Get data on a vehicle's battery
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the battery is a part of
---@param battery_name string The name of the battery
---@return { charge: number } battery_data The data of the battery
---@return boolean is_success If the function succeeded
---## Example Battery Data
---```
---{
---    ["charge"] = current_charge
---}
---```
function server.getVehicleBattery(vehicle_id, battery_name) return battery_data, is_success end

---Set the ammo in a vehicle's weapon
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the weapon is a part of
---@param weapon_name string The name of the weapon
---@param amount number The ammo amount
function server.setVehicleWeapon(vehicle_id, weapon_name, amount) end

---Get data on a vehicle's weapon
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle the weapon is a part of
---@param weapon_name string The name of the weapon
---@return { ammo: integer, capacity: integer } weapon_data The data of the weapon
---@return boolean is_success If the function succeeded
---## Example Weapon Data
---```
---{
---    ["ammo"] = current_ammo,
---    ["capacity"] = total_ammo_capacity
---}
---```
function server.getVehicleWeapon(vehicle_id, weapon_name) return weapon_data, is_success end

---Get the number of burning surfaces on a vehicle
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle to check for fires
---@return number surface_count The number of surfaces that are on fire
---@return boolean is_success If the function succeeded
function server.getVehicleFireCount(vehicle_id) return surface_count, is_success end

---Set the text of the default tooltip that appears when looking at a vehicle. Blocks with their own tooltip, like buttons, will override this tooltip
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle to edit
---@param text string The text to display on the tooltip
---@return boolean is_success If the function succeeded
function server.setVehicleTooltip(vehicle_id, text) return is_success end

---Adds damage to a vehicle
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle to damage
---@param amount number The amount of damage to add (0 - 100)
---@param voxel_x number The x position for the center of the damage
---@param voxel_y number The y position for the center of the damage
---@param voxel_z number The y position for the center of the damage
---@return boolean is_success If the function succeeded
function server.addDamage(vehicle_id, amount, voxel_x, voxel_y, voxel_z) return is_success end

---Get wether a vehicle is simulating
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle to check
---@return boolean is_simulating If the vehicle is being simulated
---@return boolean is_success If the function succeeded
function server.getVehicleSimulating(vehicle_id) return is_simulating, is_success end

--- I have no idea
---@param vehicle_id any
---@return any is_local
---@return boolean is_success If the function succeeded
function server.getVehicleLocal(vehicle_id) return is_local, is_success end

---Set the state of this vehicle's global transponder. All vehicles have a "transponder" that can be seen even if the vehicle is not loaded
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle to set the transponder state for
---@param is_active boolean The state of the transponder
---@return boolean is_success If the function succeeded
function server.setVehicleTransponder(vehicle_id, is_active) return is_success end

---Set a vehicle to be editable by players
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle to edit
---@param is_editable boolean If the vehicle can be edited or not
---@return boolean is_success If the function succeeded
function server.setVehicleEditable(vehicle_id, is_editable) return is_success end

---Sets whether a specific vehicle should be visible on the player's map
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle to edit
---@param show_on_map boolean If the vehicle's icon is shown on the map
---@return boolean is_success If the function succeeded
function server.setVehicleShownOnMap(vehicle_id, show_on_map) return is_success end

---Sets a vehicle to be invulnerable to damage. Makes a vehicle unbreakable.
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle to edit
---@param is_invulnerable boolean If the vehicle is invulnerable
---@return boolean is_success If the function succeeded
function server.setVehicleInvulnerable(vehicle_id, is_invulnerable) return is_success end

---Undocumented by the devs. It can be assumed that this function resets a vehicle to the state it was in when it was spawned.
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle to reset
function server.resetVehicleState(vehicle_id) end

--#endregion

--#region Object

---Spawn an object at the specified matrix position
---@param matrix Transform The matrix to spawn the object at
---@param object_type OBJECT_TYPE The type of object to spawn
---@return Object_ID object_id The object_id of the newly spawned object
---@return boolean is_success If the function succeeded
function server.spawnObject(matrix, object_type) return object_id, is_success end

---Spawns a fire and/or explosion at the specified matrix position
---@param matrix Transform The matrix position to spawn the fire at
---@param size number The size of the fire to spawn
---@param magnitude number The ferocity of the fire. The higher the number, the harder it is to extinguish
---@param is_lit boolean If the fire is currently lit or not
---@param is_explosive boolean If the fire should explode upon ignition
---@param parent_vehicle_id Vehicle_ID The vehicle_id of the parent vehicle. If set to 0 the fire will not follow a vehicle
---@param explosion_magnitude number The magnitude of the explosion
---@return Object_ID object_id The object_id of the fire object
---@return boolean is_success If the function succeeded
function server.spawnFire(matrix, size, magnitude, is_lit, is_explosive, parent_vehicle_id, explosion_magnitude) return object_id, is_success end

---Spawns an explosion at the specified position
---**Requires Weapons DLC to be enabled**
---@param matrix Transform The matrix to spawn the explosion at
---@param magnitude number The size of the explosion
function server.spawnExplosion(matrix, magnitude) end

---Spawn a character object
---@param matrix Transform The matrix position to spawn the character at
---@param outfit_type OUTFIT_TYPE The type of outfit the character should be wearing
---@return Object_ID object_id The object_id of the character
---@return boolean is_success If the function succeeded
function server.spawnCharacter(matrix, outfit_type) return object_id, is_success end

---Spawns an animal object
---@param matrix Transform The matrix to spawn the animal at
---@param animal_type number The type of animal to spawn
---@param size number The size multiplier to apply to the animal
---@return Object_ID object_id The object_id of the animal that spawned
---@return boolean is_success If the function succeeded
function server.spawnAnimal(matrix, animal_type, size) return object_id, is_success end

---Despawn an object
---@param object_id Object_ID The object_id of the object you want to despawn
---@param instant boolean If the object should be despawned immediately or when it unloads from the world
---@return boolean is_success If the function succeeded
function server.despawnObject(object_id, instant) return is_success end

---Get the position of an object
---@param object_id Object_ID The object_id of the object to get the position of
---@return Transform matrix The matrix of the object, includes rotation data
---@return boolean is_success If the function succeeded
function server.getObjectPos(object_id) return matrix, is_success end

---Get wether an object is being simulated
---@param object_id Object_ID The object_id of the object to check
---@return boolean is_simulating If the object is being simulated
---@return boolean is_success If the function succeeded
function server.getObjectSimulating(object_id) return is_simulating, is_success end

---Set the position of an object
---@param object_id Object_ID The object_id of the object to set the position of
---@param matrix Transform The matrix to apply to the object, includes rotation data
---@return boolean is_success If the function succeeded
function server.setObjectPos(object_id, matrix) return is_success end

---Set data for a fire object
---@param object_id Object_ID The object_id of the fire object to edit
---@param is_lit boolean If the fire is ignited
---@param is_explosive boolean If the fire is explosive
function server.setFireData(object_id, is_lit, is_explosive) end

---Get data of a fire object
---@param object_id Object_ID The object_id of the fire object to get data on
---@return boolean is_lit If the fire is ignited or not
---@return boolean is_success If the function succeeded
function server.getFireData(object_id) return is_lit, is_success end

---Kills the target character
---@param object_id Object_ID The object_id of the character to kill
function server.killCharacter(object_id) end

---Revive the target character
---@param object_id Object_ID The object_id of the character to revive
function server.reviveCharacter(object_id) end

---Teleport a character object to a seat on a vehicle
---@param object_id Object_ID The object_id of the character to teleport
---@param vehicle_id Vehicle_ID The vehicle_id of the vehicle that the seat is a part of
---@param seat_name? string The name of the seat to teleport the character to. If an empty string, the character will be teleported to the first seat found.
function server.setCharacterSeated(object_id, vehicle_id, seat_name) end

---@class GetCharacterDataResult
---@field hp number health points.
---@field incapacitated boolean Is the character incapacitated (seriously injured and unable to move).
---@field dead boolean Is the character dead.
---@field ai boolean Is the character controlled by AI.
---@field name string

---Get data on a character object
---@param object_id Object_ID The object_id of the target character
---@return GetCharacterDataResult character_data The data of this character
---## Example Character Data
---```
---{
---    ["hp"] = hp,
---    ["incapacitated"] = is_incapacitated,
---    ["dead"] = is_dead,
---    ["interactable"] = is_interactable,
---    ["ai"] = is_ai,
---    ["name"] = name
---}
---```
function server.getCharacterData(object_id) return character_data end

---Get the vehicle_id that a character is sitting in
---@param object_id Object_ID The object_id of the target character
---@return Vehicle_ID vehicle_id The vehicle_id of the vehicle the character is in
---@return boolean is_success If the function succeeded
function server.getCharacterVehicle(object_id) return vehicle_id, is_success end

---Sets data values for a character
---@param object_id Object_ID The object_id of the character
---@param hp number The health of the character
---@param is_interactable boolean If the character can be interacted with (carried, asked to follow)
---@param is_ai boolean If the character has ai enabled
function server.setCharacterData(object_id, hp, is_interactable, is_ai) end

---Sets what item is in a given slot for a character
---@param object_id Object_ID The object_id of the character to equip
---@param slot SLOT_NUMBER The slot to put the item in
---@param equipment_id EQUIPMENT_ID The equipment_id of the equipment to put in the slot
---@param is_active boolean If the equipment is active, such as if a transponder is currently on
---@param meta1? number The first metadata value for the item. Defaults to 0
---@param meta2? number The second metadata value for the item. Defaults to 0
---@return boolean is_success
function server.setCharacterItem(object_id, slot, equipment_id, is_active, meta1, meta2) end

---Get the id of the object in the specified slot of a character
---@param object_id Object_ID The object_id of the character whose inventory will be checked
---@param slot SLOT_NUMBER The slot to check
---@return EQUIPMENT_ID equipment_id The id of the equipment in the slot
---@return boolean is_success If the function succeeded
function server.getCharacterItem(object_id, slot) return equipment_id, is_success end

--#endregion

--#region Game Data

---Set one of this save's game settings
---@param game_setting GAME_SETTING The name of the setting to set
---@param value boolean The new value of the setting
function server.setGameSetting(game_setting, value) end

---Get the game's settings
---@return table<GAME_SETTING, boolean>
function server.getGameSettings() return game_settings end

---Set the server's money and research points amounts
---@param money currency The new amount of money
---@param research_points number The new amount of research points
function server.setCurrency(money, research_points) end

---Get the amount of money the server has
---@return currency
function server.getCurrency() return money end

---Get the number of research points the server has
---@return number research_points The number of research points the server has
function server.getResearchPoints() return research_points end

---Get the number of days the player has survived
---@return number days_survived The number of days survived since this save started
function server.getDateValue() return days_survived end

---Get the current in-game date
---@return number day The current day
---@return number month The current month
---@return number year The current year
function server.getDate() return day, month, year end

---@class GetTimeResult
---@field hour number Clock hour [0..23]
---@field minute number Clock minute [0..59]
---@field daylight_factor number Fraction of light intensity [0..1] where 0 night, 1 midday.
---@field percent number Fraction of progress through the day [0..1]

---Get the current in-game time
---@return GetTimeResult time The current time in-game
---## Example Time Data
---```
---{
---    ["hour"] = 13,
---    ["minute"] = 55,
---    ["daylight_factor"] = 0.99,
---    ["percent"] = 0.55
---}
---```
function server.getTime() return time end



---@class GetWeatherResult
---@field fog fraction
---@field rain fraction
---@field snow fraction

---Get the current weather at the specified location
---@param matrix Transform The location to get the weather at
---@return GetWeatherResult weather The weather at the location
---## Example Weather Data
---```
---{
---    ["fog"] = fog (0 - 1)
---    ["rain"] = rain (0 - 1)
---    ["snow"] snow (0 - 1)
---}
---```
function server.getWeather(matrix) return weather end

--#endregion

--#region Tiles

---Get the location of a random ocean tile within a certain range
---@param matrix Transform The start position to perform the search from
---@param min_search_range number The minimum number of meters to search in
---@param max_search_range number the maximum number of meters to search in
---@return Transform|nil matrix The position matrix of the tile
---@return boolean is_success If the function succeeded
function server.getOceanTransform(matrix, min_search_range, max_search_range) return matrix, is_success end

---Get the location of a random tile with a matching name within the search radius
---@param matrix Transform The position matrix to perform the search from
---@param tile_name string The name of the tile to search for
---@param search_radius? number The radius to search in, in meters. Defaults to 50000m
---@return Transform|nil matrix The position matrix of the tile
---@return boolean is_success If the function succeeded
function server.getTileTransform(matrix, tile_name, search_radius) return matrix, is_success end


---@class GetTileResult
---@field name string
---@field sea_floor number Sea floor height relative to sea level.
---@field cost? currency Purchase cost of the tile
---@field purchased boolean

---Get data on the tile at the specified location
---@param matrix Transform The location of the tile to get info on
---@return GetTileResult tile_data The data on the tile
---@return boolean is_success If the function succeeded
---## Example Tile Data
---```
---{
---    ["name"] = "tile_name",
---    ["sea_floor"] = -50,
---    ["cost"] = 50000,
---    ["purchased"] = false
---}
---```
function server.getTile(matrix) return tile_data, is_success end

---@class GetStartTileResult
---@field name string
---@field x number Position X
---@field y number Position Y
---@field z number Position Z

---Get data on the starting tile.
---Has the alias `getStartIsland()`
---@return GetStartTileResult tile_data Data on the starting tile
---## Example Tile Data
---```
---{
---    ["name"] = tile_name,
---    ["x"] = x_position,
---    ["y"] = y_position,
---    ["z"] = z_position
---}
---```
function server.getStartTile() return tile_data end


---Get data on the starting tile.
---Has the alias `getStartTile()`
---@return GetStartTileResult tile_data Data on the starting tile
---## Example Tile Data
---```
---{
---    ["name"] = tile_name,
---    ["x"] = x_position,
---    ["y"] = y_position,
---    ["z"] = z_position
---}
---```
function server.getStartIsland() return server.getStartTile() end

---Get wether a tile has been purchased
---@param matrix Transform The position matrix of the tile in question
---@return boolean is_purchased If the tile has been purchased
function server.getTilePurchased(matrix) return is_purchased end

---Get wether a matrix is inside a zone
---@param needle_matrix Transform The matrix to check wether it is in the zone
---@param zone_matrix Transform The zone to check against
---@param zone_size_x number The size of the zone on the x axis
---@param zone_size_y number The size of the zone on the y axis
---@param zone_size_z number The size of the zone on the z axis
---@return boolean is_in_area If needle_matrix is within the zone
function server.isInTransformArea(needle_matrix, zone_matrix, zone_size_x, zone_size_y, zone_size_z) return is_in_area end

---Pathfind through the ocean from the start matrix to the end matrix
---@param start_matrix Transform The matrix to start from
---@param end_matrix Transform The matrix to end at
---@return {x: number, z: number}[] path The path to get from start to finish
---## Example Path Data
---```
---{
---    [i] = {
---        x = 12560,
---        z = -55
---    }
---}
---```
function server.pathfindOcean(start_matrix, end_matrix) return path end

--#endregion

--#region Properties (Settings)

---Create a checkbox UI element on the main menu and get it's state
---@param text string The text to display along with the checkbox
---@param default_value string The default value of the checkbox ("true" or "false")
---@return boolean checked Wether the checkbox is checked
function property.checkbox(text, default_value) return checked end

---Create a slider UI element on the main menu and get it's value
---@param text string The text to display along with the slider
---@param min number The minimum value the slider can be
---@param max number The maximum value the slider can be
---@param increment number The increment value used for the slider
---@param default_value number The default value of the slider
---@return number value The value of the slider
function property.slider(text, min, max, increment, default_value) return value end

--#endregion

--#region AI

---Set the AI state of a character
---@param object_id Object_ID The object_id of the character to set the AI state of
---@param ai_state number The new state of the character's AI
---___
---## AI States
---### SEAT TYPE = Ship Pilot
---0 = none,
---1 = path to destination,
---### SEAT TYPE = Helicopter Pilot
---0 = none,
---1 = path to destination,
---2 = path to destination accurate (smaller increments for landing/takeoff),
---3 = gun run (Fly at target and press the trigger hotkey when locked on),
---### SEAT TYPE = Plane Pilot
---0 = none,
---1 = path to destination,
---2 = gun run (Fly at target and press the trigger hotkey when locked on),
---### SEAT TYPE = Gunner
---0 = none,
---1 = fire at target (Accounts for bullet drop / effective range when pulling the trigger),
---### SEAT TYPE = Designator
---0 = none,
---1 = aim at target (Pulls the trigger when looking directly at target),
--- ___
---## Seat Controls
---### SEAT TYPE = Ship Pilot
---Hotkey 1 = Engine On
---Hotkey 2 = Engine Off
---Axis W = Throttle
---Axis D = Steering
---
---### SEAT TYPE = Helicopter Pilot
---Hotkey 1 = Engine On
---Hotkey 2 = Engine Off
---Axis W = Pitch
---Axis D = Roll
---Axis Up = Collective
---Axis Right = Yaw
---Trigger = Shoot
---
---### SEAT TYPE = Plane Pilot
---Hotkey 1 = Engine On
---Hotkey 2 = Engine Off
---Axis W = Pitch
---Axis D = Roll
---Axis Up = Throttle
---Axis Right = Yaw
---Trigger = Shoot
---
---### SEAT TYPE = Gunner
---Axis W = Pitch
---Axis D = Yaw
---Trigger = Shoot
---
---### SEAT TYPE = Designator
---Axis W = Pitch
---Axis D = Yaw
---Trigger = Designate
function server.setAIState(object_id, ai_state) end


---@class GetAITargetResult
---@field character? Object_ID
---@field vehicle? Vehicle_ID
---@field x number X Position (X on in-game map)
---@field y number Y Position altitude
---@field z number Z Position (Y on in-game map)

---Get a character's target data
---@param object_id Object_ID The object_id of the character to get the data from
---@return GetAITargetResult target_data The character's target data
---## Example Target Data
---```
---{
---    ["character"] = target_character_object_id,
---    ["vehicle"] = target_vehicle_id,
---    ["x"] = target_x,
---    ["y"] = target_y,
---    ["z"] = target_z
---}
---```
function server.getAITarget(object_id) return target_data end

---Set the target destination for the AI
---@param object_id Object_ID The object_id of the character to set the target for
---@param matrix Transform The destination matrix the character AI should be aiming for
function server.setAITarget(object_id, matrix) end

---Set the target character for a character's AI
---@param object_id Object_ID The object_id of the character to set target data for
---@param target_object_id Object_ID The object_id of the character to target
function server.setAITargetCharacter(object_id, target_object_id) end

---Set the target for vehicle for a character's AI
---@param object_id Object_ID The object_id of the character to set target data for
---@param target_vehicle_id Vehicle_ID The vehicle_id of the vehicle to target
function server.setAITargetVehicle(object_id, target_vehicle_id) end

--#endregion

--#region Natural Disasters

---Spawns a tsunami with it's epicenter at `matrix`. Only one event (tsunami/whirlpool) can be active at once. A stronger event overrides a weaker one.
---@param matrix Transform The target position for the epicenter of the tsunami
---@param magnitude number The intensity of the tsunami
---@return boolean is_success If the tsunami was successfully started
function server.spawnTsunami(matrix, magnitude) return is_success end

---Spawns a whirpool at the target position. If the ocean is too shallow at the target location, spawning will fail. Only one event (tsunami/whirlpool) can be active at once. A stronger event overrides a weaker one.
---@param matrix Transform The target position for the epicenter of the whirlpool
---@param magnitude number The intensity of the whirlpool
---@return boolean is_success If the whirlpool was successfully started
function server.spawnWhirlpool(matrix, magnitude) return is_success end

---Cancels a tsunami/whirpool event
function server.cancelGerstner() end

---Spawns a tornado at the target position
---@param matrix Transform The target spawn location for the tornado
---@return boolean is_success If the tornado was successfully started
function server.spawnTornado(matrix) return is_success end

---Spawns a meteor that strikes the target position
---@param matrix Transform The target location for the meteor
---@param magnitude number The size of the meteor. Accepts values 0 - 1. Scales at a factor of `magnitude` * 20
---@param spawns_tsunami boolean If the meteor should spawn a tsunami upon impact
---@return boolean is_success If the meteor was successfully spawned
function server.spawnMeteor(matrix, magnitude, spawns_tsunami) return is_success end

---Spawns a meteor shower that aims for the target position
---@param matrix Transform The target location for the shower
---@param magnitude number The size of the main meteor. Larger values also increase the number of secondary meteors. Accepts values 0 - 1.
---@param spawns_tsunami boolean If the main meteor should spawn a tsunami upon impact
---@return boolean is_success If the shower was successfully started
function server.spawnMeteorShower(matrix, magnitude, spawns_tsunami) return is_success end

---Activates the closest volcano **if that tile is being simulated**. Unloaded tiles will not activate.
---@param matrix Transform The target position for starting a volcanic event. Does not need to be exact
---@return boolean is_success
function server.spawnVolcano(matrix) return is_success end

---@class GetVolcanosResult
---@field x number X Position
---@field y number Y Position (height)
---@field z number Z Position (Y on the in-game map)
---@field tile_x integer Index in tile grid on x axis
---@field tile_y integer Index in tile grid in z axis

---Gets a table of all volcanos in the world
---@return GetVolcanosResult[] volcanos A list of all volcanos
---## Example of volcanos table:
---```
---{
--- x = 120,
--- y = 30,
--- z = -50,
--- tile_x = 22,
--- tile_y = -5
---}
---```
function server.getVolcanos() return volcanos end

--#endregion

--#region Matrices

---Multiply two matrices together
---@param matrix1 Transform The matrix to multiply
---@param matrix2 Transform The matrix to multiply by
---@return Transform multiplied_matrix The result of multiplying the matrices
---@nodiscard
function matrix.multiply(matrix1, matrix2) return multiplied_matrix end

---Inverts a matrix. Used in multiplication to divide.
---@param matrix Transform The matrix to invert
---@return Transform inverted_matrix The matrix, now inverted
---@nodiscard
---@see https://www.mathsisfun.com/algebra/matrix-inverse.html
function matrix.invert(matrix) return inverted_matrix end

---Transposes a matrix. This flips a matrix, switching row and column indices
---@param matrix Transform The matrix to transpose
---@return Transform transposed_matrix The matrix, now transposed
---@nodiscard
---@see https://en.wikipedia.org/wiki/Transpose
function matrix.transpose(matrix) return transposed_matrix end

---Get an identity matrix
---@return Transform identity_matrix The identity matrix
---@nodiscard
---@see https://en.wikipedia.org/wiki/Identity_matrix
function matrix.identity() return identity_matrix end

---Get a new matrix, rotated the requested number of radians on the X axis
---@param radians number The number of radians to rotate by on the X axis
---@return Transform rotation_matrix A new matrix, rotated by the requested number of radians on the X axis
---@nodiscard
function matrix.rotationX(radians) return rotation_matrix end

---Get a new matrix, rotated the requested number of radians on the Y axis
---@param radians number The number of radians to rotate by on the Y axis
---@return Transform rotation_matrix A new matrix, rotated by the requested number of radians on the Y axis
---@nodiscard
function matrix.rotationY(radians) return rotation_matrix end

---Get a new matrix, rotated the requested number of radians on the Z axis
---@param radians number The number of radians to rotate by on the Z axis
---@return Transform rotation_matrix A new matrix, rotated by the requested number of radians on the Z axis
---@nodiscard
function matrix.rotationZ(radians) return rotation_matrix end

---Returns a new matrix, translated by the specified x, y, z
---@param x number The x value to translate by. This is the same x value that is seen on the in-game map
---@param y number The y value to translate by. This is the vertical axis in the game
---@param z number The z value to translate by. This is the y axis on the map in the game
---@return Transform translated_matrix The new translated matrix
---@nodiscard
function matrix.translation(x, y, z) return translated_matrix end

---Get the x, y, z position from a matrix
---@param matrix Transform The matrix to extract the position values from
---@return number x The x position of the matrix. This is the same x value that is seen on the in-game map
---@return number y The y position of the matrix. This is the vertical axis in the game
---@return number z The z position of the matrix. This is the y axis on the map in the game
---@nodiscard
function matrix.position(matrix) return x, y, z end

---Get the distance in meters between two matrices
---@param matrix1 Transform The first matrix
---@param matrix2 Transform The second matrix
---@return number distance The distance between the two matrices in meters
---@nodiscard
function matrix.distance(matrix1, matrix2) return distance end

---Multiply a matrix by a vec4
---@param matrix1 Transform The matrix to multiply
---@param x number The vector x value
---@param y number The vector y value
---@param z number The vector z value
---@param w number The vector w value
---@return number x The x value
---@return number y The y value
---@return number z The z value
---@return number w The w value
---@nodiscard
---@see https://stackoverflow.com/a/2423060
function matrix.multiplyXYZW(matrix1, x, y, z, w) return x, y, z, w end

---Returns the rotation matrix required to face the supplied vector
---@param x number The x value of the vector
---@param z number The z value of the vector
---@return Transform rotation The rotation matrix
function matrix.rotationToFaceXZ(x, z) return rotation end

--#endregion

--#region Misc

---Get if the tutorial is currently active
---@return boolean tutorial_completed The tutorial has been completed and is not currently running
function server.getTutorial() return tutorial_completed end

---Sets if a game tutorial is running. Can be used to make your own tutorial. Official addons will not spawn when a tutorial is active
---@param active boolean Sets whether a tutorial is active or not
function server.setTutorial(active) end

---Get whether the player has dismissed the video tutorials notification
---@return boolean video_tutorial_viewed If the video tutorials notification has been dismissed
function server.getVideoTutorial() return video_tutorial_viewed end

---Get if the host of the current game is a developer
---@return boolean is_dev If the host of the game is a developer
function server.isDev() return is_dev end

---Removes all radioactive zones from the map
function server.clearRadiation() end

---Make a http request
---@param port number The port to make the request on
---@param request string The request string
function server.httpGet(port, request) end

---@alias milliseconds integer

---Get the number of milliseconds that have passed since the world was loaded
---@return milliseconds time_since_load The number of ms since the world was loaded
function server.getTimeMillisec() end

---Get whether or not the weapons DLC is enabled on this save
---@return boolean dlc_enabled If the dlc is enabled or not
function server.dlcWeapons() return dlc_enabled end

---Get whether or not the Arid Island DLC is enabled on this save
---@return boolean dlc_enabled If the dlc is enabled or not
function server.dlcArid() return dlc_enabled end

--#endregion
