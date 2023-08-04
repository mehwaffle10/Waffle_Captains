### Waffle_Captains
A mod for orchestrating captains matches that is designed to be run with Waffle_Balance and Waffle_Apocalypse. Adapted from PUNK123's version that was adapted from other sources. Only gameplay changes come from `gamemode.cfg`

## Features:
- Players default to spectator when joining
- Disable team autobalance
- User commands for quick swapping teams
- Logic/UI for picking teams
- Admin commands for orchestration
- Player names find closest best match
- Flag locking during selection

# Game Flow
An admin uses the `!captain` command to pick players as captains for both red and blue team, starting fight phase. Players drop and can no longer pick up flags. The captains fight, entering pick phase when the first player dies. The winner gets first pick. The loser then gets two picks. Each captain then takes turns picking players until none remain (snake draft), ending pick phase and returning to normal play. Next mapping will reset to normal play

# User Commands
- `!r`, `!red` - Swap yourself to red team
- `!b`, `!blue` - Swap yourself to blue team
- `!s`, `!spec`, `!spectator` - Swap yourself to spectator
- `!nopick` - Swap yourself to spectator and prevent yourself from being picked by captains (your name will be greyed out). Use again or swap teams to toggle off

# Captain Commands
- `!pick <player>` - Alternative to using the UI when picking players for your team
- `!forfeit` - Forfeit during fight phase, giving the other captain first pick

# Admin Commands
- `!captains <blue_captain> <red_captain> [b|blue|r|red|random]` - Most important command. Sets everyone to spectator except for the two captains, who will fight for first pick after three seconds. Can specify first pick team after captain names to skip the fight and give the first pick to the specified team. Can be run again at any point to restart the game flow
- `!r <player>`, `!red <player>` - Swap target player to red team
- `!b <player>`, `!blue <player>` - Swap target player to blue team
- `!s <player>`, `!spec <player>`, `!spectator <player>` - Swap target player to spectator
- `!nopick <player>` - Swap target player to spectator and prevent them from being picked by captains (name will be greyed out). Use again or swap player team to toggle off

# Fixing
The mod is mostly stable. I've only ever had one script crash on a player joining in a buggy way that was fixed by an `/rcon rebuild` and `/rcon /nextmap`