- TODO: Remove duplicate instance of data with `g_playerData[steam_id].roles[role_name]`. Instead just use `g_roles[role_name].members[steam_id]`

- TODO: Remove duplicate instance of data with `g_banned[steam_id]` and `g_playerData[steam_id].banned`

- TODO: Clean up `onTick()`, move player move detection to functions

- TODO: Fix welcome message preferences

- TODO: Clean up starting equipment preference, it's a mess

- TODO: Make `?tp2v` lead the teleport so the player is teleported in the vehicle rather than behind. This will require monitoring of the target vehicle for at least 2 ticks to average the speed vectors and then teleporting the player ahead of the projected path

- FIXME: equip commands are not giving full equipment by default. When giving a flashlight, it is already nearly dead