
#include "Logging.as";
#include "CTF_SharedClasses.as";
#include "CaptainsCommon.as";

const int TEAM_BLUE = 0;
const int TEAM_RED  = 1;

const SColor COLOR_BLUE(0xff0000ff);
const SColor COLOR_RED(0xffff0000);

void onInit(CRules@ this) {
    CaptainsReset(this);

    this.addCommandID("pick");
    this.addCommandID("show pick menu");

    if (!GUI::isFontLoaded("Bigger Font"))
    {
        GUI::LoadFont("Bigger Font", "GUI/Fonts/AveriaSerif-Bold.ttf", 30, true);
    }
}

void onRestart(CRules@ this)
{
    CaptainsReset(this);
}

void onTick(CRules@ this)
{
    if (isServer() && this.get_u8(state) == State::fight && this.get_s32(timer) != 0)
    {
        s32 time_left = this.get_s32(timer) - getGameTime();
        if (time_left <= 0) {
            this.set_s32(timer, 0);
            this.Sync(timer, true);

            this.SetCurrentState(GAME);
            getNet().server_SendMsg("Fight for first pick!");
        }
    }
}

void onRender(CRules@ this)
{
    if (this.get_u8(state) == State::pick && this.exists(picking))
    {
        // Draw interface
        u8 team_picking = this.get_u8(picking);

        Vec2f top_left(100,200);
        Vec2f padding(4, 4);
        Vec2f end_padding(6, 0);
        string msg = (team_picking == TEAM_BLUE ? "Blue" : "Red") + " team is picking";
        Vec2f textDims;
        GUI::SetFont("menu");
        GUI::GetTextDimensions(msg, textDims);
        GUI::DrawPane(
            top_left,
            top_left + textDims + padding * 2 + end_padding
        );
        GUI::DrawText(
            msg,
            top_left + padding,
            team_picking == TEAM_BLUE ? COLOR_BLUE : COLOR_RED
        );
	}
    else if (this.get_u8(state) == State::fight)
    {
        string msg = this.get_s32(timer) == 0 ? "Fight for first pick!" : ((this.get_s32(timer) - getGameTime()) / 30 + 1) + " seconds until fight!";

        Vec2f Mid(getScreenWidth() / 2, getScreenHeight() * 0.2);
        Vec2f textDims;
        GUI::SetFont("Bigger Font");
        GUI::GetTextDimensions(msg, textDims);
		GUI::DrawTextCentered(msg, Mid, COLOR_RED);
	}
}

bool onServerProcessChat(CRules@ this, const string &in textIn, string &out textOut, CPlayer@ player)
{
    if(!isServer() || player is null) return true;

    string[]@ tokens = textIn.split(" ");
    int tl = tokens.length;
    if (tl > 0) {
        // Waffle: Add team commands
        if (player.isMod() && tl >= 2 && (tokens[0] == "!blue" || tokens[0] == "!red" || tokens[0] == "!spec" || tokens[0] == "!spectator"))
        {
            // Try to get player
            CPlayer@ target = GetPlayerByIdent(tokens[1]);
            if (target is null)
            {
                return true;
            }
            
            // Set player to respective team
            int team = this.getSpectatorTeamNum();
            if (tokens[0] == "!blue")
            {
                team = TEAM_BLUE;
            }
            else if (tokens[0] == "!red")
            {
                team = TEAM_RED;
            }
            ChangePlayerTeam(this, target, team);
        }
        else if (player.isMod() && tokens[0] == "!captains" && tl >= 3)
        {
            CPlayer@ captain_blue = GetPlayerByIdent(tokens[1]);
            CPlayer@ captain_red  = GetPlayerByIdent(tokens[2]);
            if (captain_blue is null || captain_red is null)
            {
                log("onServerProcessChat", "One of the given captain names was invalid.");
                return true;
            }
            this.set_string("captain blue", captain_blue.getUsername());
            this.Sync("captain blue", true);
            this.set_string("captain red", captain_red.getUsername());
            this.Sync("captain red", true);
            if (tl > 3 && (tokens[3] == "blue" || tokens[3] == "red" || tokens[3] == "random"))
            {
                StartPickPhase(this, tokens[3] == "blue" ? TEAM_BLUE : tokens[3] == "red" ? TEAM_RED : XORRandom(2));
            }
            else
            {
                StartFightPhase(this, captain_blue, captain_red);
            }
        }
        else if (tokens[0] == "!pick" && tl >= 2 && this.get_u8(state) == State::pick)
        {
            u8 team_picking = this.get_u8(picking);
            CPlayer@ captain_blue = get_captain(this, TEAM_BLUE);
            CPlayer@ captain_red  = get_captain(this, TEAM_RED);
            if (captain_blue is null || captain_red is null)
            {
                logBroadcast("onServerProcessChat", "ERROR: in pick phase but a captain is null; exiting pick phase.");
                this.set_u8(state, State::none);
            }
            else if (player is captain_blue && team_picking == TEAM_BLUE || player is captain_red && team_picking == TEAM_RED)
            {
                string targetIdent = tokens[1];
                CPlayer@ target = GetPlayerByIdent(targetIdent);
                if (target !is null)
                {
                    TryPickPlayer(this, target, team_picking);
                }
            }
        }
        else if(tokens[0] == "!forfeit" && this.get_u8(state) == State::fight && (player is get_captain(this, TEAM_BLUE) || player is get_captain(this, TEAM_RED)))
        {
            StartPickPhase(this, Maths::Abs(player.getTeamNum() - 1));
        }
    }
    return true;
}	

void CaptainsReset(CRules@ this)
{
    this.set_u8(state, State::none);
    this.set_bool("can choose team", true);
}

int CountPlayersInTeam(int teamNum)
{
    int count = 0;
    for (int i = 0; i < getPlayerCount(); i++)
    {
        CPlayer@ p = getPlayer(i);
        if (p !is null && p.getTeamNum() == teamNum)
        {
            count++;
        }
    }
    return count;
}

// Adds the player to the given team if they are currently spectating and can be picked
void TryPickPlayer(CRules@ this, CPlayer@ player, u8 team)
{
    if (player.getTeamNum() == this.getSpectatorTeamNum()) // Don't allow picking of players already on teams
    {
        ChangePlayerTeam(this, player, team);

        // End picking phase
        if (getPlayerCount() == 0 || CountPlayersInTeam(this.getSpectatorTeamNum()) == 0)
        {
            this.set_u8(state, State::none);
            this.Sync(state, true);
            return;
        }

        // Set the team that's picking
        u8 first_pick_team = this.get_u8(first_pick);
        u8 current_pick = this.get_u8(picking);
        u8 current_count = CountPlayersInTeam(current_pick);

        sendPickMenu(this, current_count == 2 && current_pick != first_pick_team ? current_pick : Maths::Abs(current_pick - 1));
    }
}

void ChangePlayerTeam(CRules@ this, CPlayer@ player, int team)
{
    RulesCore@ core;
    this.get("core", @core);
    core.ChangePlayerTeam(player, team);
}

void StartFightPhase(CRules@ this, CPlayer@ captain_blue, CPlayer@ captain_red)
{
    getNet().server_SendMsg("Entering fight phase");

    SetTeams(this);

    this.set_u8(state, State::fight);
    this.Sync(state, true);

    this.set_s32(timer, getGameTime() + 3 * getTicksASecond());
    this.Sync(timer, true);

    this.set_bool("can choose team", false);
    getNet().server_SendMsg("Swapping teams is disabled!");
}

void StartPickPhase(CRules@ this, u8 first_pick_team)
{
    getNet().server_SendMsg("Entering pick phase. First pick: " + (first_pick_team == TEAM_BLUE ? "Blue" : "Red"));

    SetTeams(this);

    this.set_u8(state, State::pick);
    this.Sync(state, true);

    this.set_u8(first_pick, first_pick_team);
    this.Sync(first_pick, true);

    sendPickMenu(this, first_pick_team);
}

void SetTeams(CRules@ this)
{
    // Set all relevant teams in one go
    RulesCore@ core;
    this.get("core", @core);
    int specTeam = this.getSpectatorTeamNum();
    CPlayer@ captain_blue = get_captain(this, TEAM_BLUE);
    CPlayer@ captain_red  = get_captain(this, TEAM_RED);

    for(int i = 0; i < getPlayerCount(); i++)
    {
        CPlayer@ player = getPlayer(i);
        if (player !is null)
        {
            core.ChangePlayerTeam(player, player is captain_blue ? TEAM_BLUE : player is captain_red ? TEAM_RED : specTeam);
        }
    }

    // Force drop flags
    CBlob@[] flags;
    getBlobsByName("ctf_flag", flags);
    for (u8 i = 0; i < flags.length; i++)
    {
        CBlob@ flag = flags[i];
        if (flag !is null && flag.isAttachedToPoint("PICKUP"))
        {
            flag.server_DetachFromAll();
        }
    }
}

void onPlayerDie(CRules@ this, CPlayer@ victim, CPlayer@ killer, u8 customData)
{
    if (isServer() && this.get_u8(state) == State::fight && this.get_s32(timer) == 0 && killer !is null)
    {
        u8 winning_team = Maths::Abs(victim.getTeamNum() - 1);
        StartPickPhase(this, winning_team);

        CPlayer@ winner = get_captain(this, winning_team);
        getNet().server_SendMsg((winner !is null ? winner.getUsername() : killer.getUsername()) + " won the fight!");
    }
}

void onCommand(CRules@ this, u8 cmd, CBitStream @params)
{
    if (isServer() && cmd == this.getCommandID("pick"))
    {
        string username = params.read_string();
        CPlayer@ player = getPlayerByUsername(username);
        if (player !is null)
        {
            TryPickPlayer(this, player, this.get_u8(picking));
        }
    }
    else if (isClient() && cmd == this.getCommandID("show pick menu")) // WARNING: only send to individual players
    {
        this.AddScript("PickMenu.as");
    }
}

void sendPickMenu(CRules@ this, u8 team)
{
    CPlayer@ picker = get_captain(this, team);
    if (picker is null)
    {
        return;
    }
    print("picker is: " + picker.getUsername());

    this.set_u8(picking, team);
    this.Sync(picking, true);
    this.SendCommand(this.getCommandID("show pick menu"), CBitStream(), picker);
}
