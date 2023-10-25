**Carsa's Commands is officially end of life (EOF)**. The new changes to the addon API from the space update are the final nail in the coffin. Developing an addon of this size and complexity requires lots of work to be done to fix issues in the API and game. Many of these issues have existed since v1 of the game and there are no fixes in sight.

The amount of work required to fix Carsa's Commands and get it back working the way I would like is too great for me to justify. I have not played the game in almost two years now, except to test patches for Carsa's Commands.

Carsa's Commands is licensed under a [MIT license](https://github.com/carsakiller/Carsas-CommandsV2?tab=MIT-1-ov-file#readme), meaning, so long as the license is included, anyone is free to continue enjoying the freedoms that the license grants, including modification and distribution.

I would like to thank everyone for their support over the years.

Cheers,
Carsa

---

# Caras's Commands v2: The Final Hurrah
This version two of Carsa's Commands marks the end of a very long journey.

## Quick Links
[Steam Workshop Page](https://steamcommunity.com/sharedfiles/filedetails/?id=2780335340)\
[Carsa's Commands Website](https://c2.carsakiller.com/cc-website)\
[Carsa's Companion](https://github.com/carsakiller/Carsas-Companion)

## About Carsa's Commands
[Carsa's Commands](https://c2.carsakiller.com/cc-website) is an addon for Stormworks that adds **over 50 commands** that implement everything from a better ban command to a command that teleports you to the nearest seat. To list a few, there is:

- `?equip` - Gives you specific equipment
- `?tpl` - Teleports you to named locations around the map
- `?charge` - Lets you set the charge of a battery on a vehicle
- `?heal` - Heals you or another player by a certain percentage\
*[+53 more!](https://c2.carsakiller.com/cc-website/docs/commands)*

## Install
Carsa's Commands v2 can be subscribed to on the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2780335340). Carsa's Companion can be found on [GitHub](https://github.com/carsakiller/Carsas-Companion/releases).

## Dedicated Server Setup
> **Important Note:** The first player to join the server will be made an owner. To override this, please look at [Setting an Owner](#setting-an-owner)
1. Navigate to `%appdata%\Stormworks\data\missions\` and copy the whole `Carsa's Commands` folder
2. Assuming your dedicated server is installed here: `C:\Server\server64.exe`, paste the mission folder into `C:\Server\`
3. If your dedicated server has not been started before, make sure you start it at least once so it can generate some configuration files
4. Open `%appdata%\Stormworks\server_config.xml` in a text editor
5. Under the `<playlists>` tag, add the following:
```xml
<path path="Carsa's Commands"/>
```
### Setting an Owner
To override the automatic assigning of an owner when the very first unique player joins, you can do the following:
1. Open `script.lua` (can be found in the location from step 2 of [the setup](#dedicated-server-setup))
2. On line 16, you should find the following:
```lua
local OWNER_STEAM_ID = "0"
```
3. Please enter your steamID where the `0` is, leaving the quotes around it.
#### How to Find Your SteamID
Using the Steam desktop client:
1. Select `Steam` in the top right
2. Select `Settings`
3. Select `Interface`
4. Make sure that `Display web address bars when available` is checked.
5. Close the settings window and mouse over your username at the top
6. Select `Profile`
7. You should now see your steamID in the URL bar in between the final two slashes `https://steamcommunity.com/profiles/<steamID>/`
![image](https://user-images.githubusercontent.com/61925890/163575767-d96c416c-39c2-4177-b550-923a5bfeca64.png)

**Note:** If you have set a custom URL, you will not see your steamID in the url but rather your custom URL. To find your steamID, do the following:
1. Copy URL from profile screen
2. Visit [Steam ID Lookup](https://steamid.io/lookup)
3. Paste the link in the search box and submit
4. Copy the `steamID64` value, this is your steamID

## What's New?
[New to v2](https://c2.carsakiller.com/cc-website/#news) is a new [companion webapp](https://github.com/carsakiller/Carsas-Companion) that makes your life much easier by providing a nice graphical interface so you don't have to use the in-game chat to execute `?giveRole Admin Leopard` or `?equipp CrazyFluffyPony 21 4 20`.

There is a lot more that got added and improved, you can read more on [C²'s website](https://c2.carsakiller.com/cc-website/)

## Contributors
Version 2 would have been abandoned a long time ago if it weren't for [CrazyFluffyPony](https://steamcommunity.com/id/CrazyFluffyPony/), [Dargino](https://steamcommunity.com/profiles/76561198081415251), and [Leopard](https://steamcommunity.com/profiles/76561198081580193). They all helped with fixing bugs and adding features but most importantly, helped encourage me to get to the finish line.

A very big thank you to them.

## Reporting Issues / Contributing
Since v2 has consisted of almost an entire rewrite of Carsa's Commands, there are bound to be some issues.

Please report all issues on the [GitHub issues](https://github.com/carsakiller/Carsas-CommandsV2/issues) page as it is a much better place to keep track of everything than the comments or discussions on Steam.

## Discussing
If you would like to discuss adding features, get help, or just float some ideas, there is the [GitHub discussions](https://github.com/carsakiller/Carsas-CommandsV2/discussions) page which is the preferred place for contact.

## There was a v1?
Version 1.03 can still be found on the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2356110139) and on [GitHub](https://github.com/carsakiller/Carsas-Commands) however consider it to be archived as there will be no further action on those pages.

## The Future
I have not played Stormworks in over a year at this point, I have only launched the game to test Carsa's Commands. I do not intend to add much more to Carsa's Commands and the future will likely consist of just bug fixes.
