
#include "WaffleUtilities"
#include "ChatCommand.as"
#include "CaptainsCommon.as"

void onInit(CRules@ this)
{
	ChatCommands::RegisterCommand(CaptainsCommand());
    ChatCommands::RegisterCommand(LockTeamsCommand());
	ChatCommands::RegisterCommand(PickCommand());
	ChatCommands::RegisterCommand(ForfeitCommand());
    ChatCommands::RegisterCommand(NoPickCommand());
}

class CaptainsCommand : ChatCommand
{
	CaptainsCommand()
	{
		super("captains", "Start a captains fight. Places each captain on their team, forces all other players to spec, and prevents non-admin players from swapping teams");
        SetUsage("<blue captain name> <red captain name> [b|blue|0|r|red|1|random]");
	}

	void Execute(string[] args, CPlayer@ player)
	{
        if (player is null || !player.isMod() || args.length < 2)
        {
            return;
        }

		CPlayer@ captain_blue = GetPlayerByIdent(args[0], player);
        CPlayer@ captain_red  = GetPlayerByIdent(args[1], player);
        if (captain_blue is null || captain_red is null)
        {
            return;
        }
        if (captain_blue is captain_red)
        {
            LocalError("Blue captain can't also be red captain!", player);
            return;
        }

        CRules@ rules = getRules();
        CaptainsCore@ captains_core;
        rules.get(CAPTAINS_CORE, @captains_core);
        if (captains_core is null)
        {
            return;
        }

        captains_core.player_teams.deleteAll();
        captains_core.blue_captain_name = captain_blue.getUsername();
        captains_core.red_captain_name = captain_red.getUsername();
        captains_core.pick_count = 0;

        if (args.length >= 3 && (args[2] == "b" || args[2] == "blue" || args[2] == "0" || args[2] == "r" || args[2] == "red" || args[2] == "random"))
        {
            captains_core.StartPickPhase(rules, (args[2] == "b" || args[2] == "blue" || args[2] == "0") ? TEAM_BLUE : (args[2] == "r" || args[2] == "red" || args[2] == "1") ? TEAM_RED : XORRandom(2));
        }
        else
        {
            captains_core.StartFightPhase(rules, captain_blue, captain_red);
        }
	}
}

class LockTeamsCommand : ChatCommand
{
	LockTeamsCommand()
	{
		super("lockteams", "Toggle whether non-admin players can swap teams");
	}

	void Execute(string[] args, CPlayer@ player)
	{
        if (player is null || !player.isMod())
        {
            return;
        }
        CRules@ rules = getRules();
        CaptainsCore@ captains_core;
        rules.get(CAPTAINS_CORE, @captains_core);
		if (captains_core !is null)
        {
            captains_core.can_swap_teams = !captains_core.can_swap_teams;
            getNet().server_SendMsg("Swapping teams is " + (captains_core.can_swap_teams ? "enabled!" : "disabled!"));
        }
	}
}

class PickCommand : ChatCommand
{
	PickCommand()
	{
		super("pick", "Pick a player as captain");
        SetUsage("<player>");
	}

	void Execute(string[] args, CPlayer@ player)
	{
        CRules@ rules = getRules();
        CaptainsCore@ captains_core;
        rules.get(CAPTAINS_CORE, @captains_core);
        if (captains_core is null || player is null)
        {
            return;
        }

        CPlayer@ blue_captain = captains_core.getCaptain(0);
        CPlayer@ red_captain = captains_core.getCaptain(1);
        if (player !is blue_captain && player !is red_captain)
        {
            LocalError("You can only pick as a captain!", player);
            return;
        }
        if (args.length < 1)
        {
            LocalError("You must specify a player!", player);
            return;
        }
        if (captains_core.state != State::pick)
        {
            LocalError("You can only pick during pick phase!", player);
            return;
        }
        if (player is blue_captain && captains_core.picking == TEAM_BLUE || player is red_captain && captains_core.picking == TEAM_RED)
        {
            CPlayer@ target = GetPlayerByIdent(args[0], player);
            if (target !is null)
            {
                if (captains_core.no_pick.exists(target.getUsername()))
                {
                    LocalError("You can't pick this player!", player);
                }
                else
                {
                    captains_core.TryPickPlayer(rules, target, captains_core.picking);
                }
            }
        }
        else
        {
            LocalError("It is not your turn to pick!", player);
        }
	}
}

class ForfeitCommand : ChatCommand
{
	ForfeitCommand()
	{
		super("forfeit", "Forfeit first pick as captain instead of fighting");
	}

	void Execute(string[] args, CPlayer@ player)
	{
        CRules@ rules = getRules();
        CaptainsCore@ captains_core;
        rules.get(CAPTAINS_CORE, @captains_core);
        if (captains_core is null || player is null)
        {
            return;
        }
        string username = player.getUsername();
        if (username != captains_core.blue_captain_name && username != captains_core.red_captain_name)
        {
            LocalError("You can only forfeit as a captain!", player);
            return;
        }
        if (captains_core.state != State::fight)
        {
            LocalError("You can only forfeit during fight phase!", player);
            return;
        }
		captains_core.StartPickPhase(getRules(), Maths::Abs(player.getTeamNum() - 1));
	}
}

class NoPickCommand : ChatCommand
{
	NoPickCommand()
	{
		super("nopick", "Swap yourself or another player to spectator and prevent them from being picked by captains (name will be greyed out). Use again or swap teams to toggle off");
        SetUsage("[player]");
	}

	void Execute(string[] args, CPlayer@ player)
	{
        if (player is null)
        {
            return;
        }
        CPlayer@ target = player.isMod() && args.length > 0 ? GetPlayerByIdent(args[0], player) : player;
        if (target is null)
        {
            return;
        }
        CRules@ rules = getRules();
        CaptainsCore@ captains_core;
        rules.get(CAPTAINS_CORE, @captains_core);
		if (captains_core !is null && (captains_core.can_swap_teams || player.isMod()))
        {
            string username = target.getUsername();
            if (captains_core.no_pick.exists(username))
            {
                captains_core.no_pick.delete(username);
            }
            else
            {
                captains_core.no_pick.set(username, true);
            }
            captains_core.ChangePlayerTeam(rules, target, rules.getSpectatorTeamNum());
            captains_core.UpdatePickWindow(null);
        }
        else
        {
            LocalError("Swapping teams is disabled!", player);
        }
	}
}
