# Waffle_Captains
A mod for orchestrating captains matches that is designed to be run with [Waffle_Balance](https://github.com/mehwaffle10/Waffle_Balance) and [Waffle_Apocalypse](https://github.com/mehwaffle10/Waffle_Apocalypse). Adapted from PUNK123's version that was adapted from other sources. Only gameplay changes come from `gamemode.cfg`

## Features:
- Players default to their last joined team when joining (spec for first join)
- Toggle to disable swapping teams
- Disable team autobalance
- Disable AFK kick/force spec
- User commands for quick swapping teams
- Logic/UI for picking teams
- Admin commands for orchestration
- Player names find closest best match
- Unable to capture flag during fight and pick phases
- Scoreboard resets each match. Hold `shift` to see stats from previous match
- Specators render as another team in scoreboard

## Game Flow
An admin uses the `!captain` command to pick players as captains for both red and blue team, starting fight phase. Non-admin players are no longer allowed to swap teams. Players drop and can no longer pick up flags. The captains fight, entering pick phase when the first player dies. When it is a captain's turn to pick, a GUI with player names will show in the upper left. All other players will see a title card showing whos turn it is to pick. The winner gets first pick. The loser then gets two picks. The winner then gets two picks. Each captain then takes turns picking players until none remain (snake draft), ending pick phase and returning to normal play. Next mapping will reset to normal play. Teams will continue to be locked forever, use the `!lockteams` command to unlock teams.

# Commands
## User Commands
Note: None of these will work if you are not an admin and team swapping is disabled
- `!r`, `!red` - Swap yourself to red team
- `!b`, `!blue` - Swap yourself to blue team
- `!s`, `!spec`, `!spectator` - Swap yourself to spectator
- `!nopick` - Swap yourself to spectator and prevent yourself from being picked by captains (your name will be greyed out). Use again or swap teams to toggle off

## Captain Commands
- `!pick <player>` - Alternative to using the UI when picking players for your team. Only usable in pick phase
- `!forfeit` - Forfeit during fight phase, giving the other captain first pick. Only usable during fight phase

## Admin Commands
Note: You can always execute these commands even if teams are locked or normal gameplay has not been reestablished
- `!captains <blue_captain> <red_captain> [b|blue|r|red|random]` - Most important command. Sets everyone to spectator except for the two captains, who will fight for first pick after three seconds. Can specify first pick team after captain names to skip the fight and give the first pick to the specified team. Can be run again at any point to restart the game flow. Will disable team swapping until `!lockteams` is used
- `!lockteams` - Toggle whether non-admin players are allowed to swap teams
- `!r <player>`, `!red <player>` - Swap target player to red team.
- `!b <player>`, `!blue <player>` - Swap target player to blue team
- `!s <player>`, `!spec <player>`, `!spectator <player>` - Swap target player to spectator
- `!nopick <player>` - Swap target player to spectator and prevent them from being picked by captains (name will be greyed out). Use again or swap player team to toggle off

## Fixing
The mod is mostly stable. I've only ever had one script crash on a player joining in a buggy way that was fixed by an `/rcon rebuild` and `/rcon /nextmap`