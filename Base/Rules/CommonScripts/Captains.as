
#include "CaptainsCommon.as"

void onInit(CRules@ this)
{
    CaptainsReset(this);

    this.addCommandID(CAPTAINS_CORE_SYNC_COMMAND);

    if (!GUI::isFontLoaded("Bigger Font"))
    {
        GUI::LoadFont("Bigger Font", "GUI/Fonts/AveriaSerif-Bold.ttf", 30, true);
    }
}

void onRestart(CRules@ this)
{
    CaptainsReset(this);
}

void CaptainsReset(CRules@ this)
{
    CaptainsCore@ captains_core;
    this.get(CAPTAINS_CORE, @captains_core);
    if (captains_core is null)
    {
        @captains_core = CaptainsCore();
        this.set(CAPTAINS_CORE, @captains_core);
    }
    captains_core.Reset();
}

void onTick(CRules@ this)
{
    CaptainsCore@ captains_core;
    this.get(CAPTAINS_CORE, @captains_core);
    if (captains_core !is null)
    {
        captains_core.onTick(this);
    }
}

void onPlayerChangedTeam(CRules@ this, CPlayer@ player, u8 oldteam, u8 newteam)
{
    CaptainsCore@ captains_core;
    this.get(CAPTAINS_CORE, @captains_core);
    if (captains_core !is null)
    {
        captains_core.onPlayerChangedTeam(this, player, oldteam, newteam);
    }
}

void onNewPlayerJoin(CRules@ this, CPlayer@ player)
{
    CaptainsCore@ captains_core;
    this.get(CAPTAINS_CORE, @captains_core);
    if (captains_core !is null)
    {
        captains_core.onNewPlayerJoin(this, player);
    }
}

void onPlayerLeave(CRules@ this, CPlayer@ player)
{
    CaptainsCore@ captains_core;
    this.get(CAPTAINS_CORE, @captains_core);
    if (captains_core !is null)
    {
        captains_core.onPlayerLeave(this, player);
    }
}

void onRender(CRules@ this)
{
    CaptainsCore@ captains_core;
    this.get(CAPTAINS_CORE, @captains_core);
    if (captains_core !is null)
    {
        captains_core.onRender(this);
    }
}

void onPlayerDie(CRules@ this, CPlayer@ victim, CPlayer@ killer, u8 customData)
{
    CaptainsCore@ captains_core;
    this.get(CAPTAINS_CORE, @captains_core);
    if (captains_core !is null)
    {
        captains_core.onPlayerDie(this, victim, killer, customData);
    }
}

void onCommand(CRules@ this, u8 cmd, CBitStream @params)
{
    CaptainsCore@ captains_core;
    this.get(CAPTAINS_CORE, @captains_core);
    if (captains_core is null)
    {
        return;
    }
    if (cmd == this.getCommandID(CAPTAINS_CORE_SYNC_COMMAND))
    {
        // Sync normal variables
        if (!params.saferead_u8(captains_core.state))
        {
            return;
        }
        if (!params.saferead_u8(captains_core.picking))
        {
            return;
        }
        if (!params.saferead_u8(captains_core.pick_count))
        {
            return;
        }
        if (!params.saferead_s32(captains_core.timer))
        {
            return;
        }
        if (!params.saferead_string(captains_core.blue_captain_name))
        {
            return;
        }
        if (!params.saferead_string(captains_core.red_captain_name))
        {
            return;
        }
        if (!params.saferead_bool(captains_core.can_swap_teams))
        {
            return;
        }

        // Sync no_pick dictionary
        u8 length;
        if (!params.saferead_u8(length))
        {
            return;
        }
        for (u8 i = 0; i < length; i++)
        {
            string username;
            bool nopick;
            if (!params.saferead_string(username))
            {
                return;
            }
            if (!params.saferead_bool(nopick))
            {
                return;
            }
            captains_core.no_pick.set(username, nopick);
        }
    }
}

void onPlayerRequestTeamChange(CRules@ this, CPlayer@ player, u8 newteam)
{
    CaptainsCore@ captains_core;
    this.get(CAPTAINS_CORE, @captains_core);
    if (captains_core !is null && captains_core.can_swap_teams)
    {
        captains_core.ChangePlayerTeam(this, player, newteam);
    }
}
