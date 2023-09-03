
#include "WaffleUtilities"
#include "ChatCommand.as"
#include "CaptainsCommon.as"

void onInit(CRules@ this)
{
	ChatCommands::RegisterCommand(CaptainsCommand());
	ChatCommands::RegisterCommand(PickCommand());
	ChatCommands::RegisterCommand(ForfeitCommand());
    ChatCommands::RegisterCommand(NoPickCommand());
}

class CaptainsCommand : ChatCommand
{
	CaptainsCommand()
	{
		super("captains", "Start a captains fight");
        SetUsage("<blue captain name> <red captain name> [b|blue|0|r|red|1|random]");
	}

	void Execute(string[] args, CPlayer@ player)
	{
        if (args.length < 2)
        {
            return;
        }

		CPlayer@ captain_blue = GetPlayerByIdent(args[0]);
        CPlayer@ captain_red  = GetPlayerByIdent(args[1]);
        if (captain_blue is null || captain_red is null)
        {
            log("onServerProcessChat", "One of the given captain names was invalid.");
            return;
        }

        CRules@ rules = getRules();
        CaptainsCore@ captains_core;
        rules.get(CAPTAINS_CORE, @captains_core);
        if (captains_core is null)
        {
            return;
        }

        captains_core.blue_captain_name = captain_blue.getUsername();
        captains_core.red_captain_name = captain_red.getUsername();


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
        if (captains_core is null || player is null || args.length < 1)
        {
            return;
        }

        CPlayer@ blue_captain = captains_core.getCaptain(0);
        CPlayer@ red_captain = captains_core.getCaptain(1);
        if (player is blue_captain && captains_core.picking == TEAM_BLUE || player is red_captain && captains_core.picking == TEAM_RED)
        {
            CPlayer@ target = GetPlayerByIdent(args[0]);
            if (target !is null)
            {
                captains_core.TryPickPlayer(rules, target, captains_core.picking);
            }
        }
	}
}

class ForfeitCommand : ChatCommand
{
	ForfeitCommand()
	{
		super("forfeit", "Forfeit first pick as captain");
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
        CPlayer@ target = player.isMod() && args.length > 0 ? GetPlayerByIdent(args[0]) : player;
        if (!isServer() || target is null)
        {
            return;
        }
        CRules@ rules = getRules();
        CaptainsCore@ captains_core;
        rules.get(CAPTAINS_CORE, @captains_core);
        if (captains_core is null || player is null)
        {
            return;
        }
		if (captains_core !is null && (captains_core.can_swap_teams || player.isMod()))
        {
            captains_core.no_pick.set(target.getUsername(), true);
            captains_core.ChangePlayerTeam(rules, target, rules.getSpectatorTeamNum());
        }
	}
}
