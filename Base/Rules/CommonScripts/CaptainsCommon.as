
#include "KGUI.as"
#include "CTF_SharedClasses.as"
#include "ApocalypseCommon.as"

const u8 FIGHT_SECONDS = 90;  // Waffle: How long until sudden death triggers after fight phase
const u8 COUNTDOWN_SECONDS = 3;  // Waffle: How long to countdown before fight phase

const int TEAM_BLUE = 0;
const int TEAM_RED  = 1;

const SColor COLOR_BLUE(0xff0000ff);
const SColor COLOR_RED(0xffff0000);
const SColor CHAT_COLOR = ConsoleColour::PRIVCHAT;

const string CAPTAINS_CORE = "captains core";
const string CAPTAINS_CORE_SYNC_COMMAND = "captains core sync";
const string PICK_COMMAND = "pick";
const SColor NOPICK_COLOR = SColor(255, 150, 150, 150);
const SColor CAPTAIN_COLOR = SColor(255, 150, 0, 150);

const int BUTTON_WIDTH = 100;
const int BUTTON_HEIGHT = 50;
const int GRID_COLUMNS = 2;
Window pick_window = Window(Vec2f(100, 100), Vec2f(0, 0));

namespace State
{
	enum state_type
	{
		none = 0,
        countdown,
		fight,
		win,
		pick
	};
};

class CaptainsCore
{
    u8 state;
    u8 picking;
    u8 pick_count;
    s32 timer;
    string blue_captain_name;
    string red_captain_name;
    bool can_swap_teams;
    dictionary no_pick;
    dictionary player_teams;

    CaptainsCore()
    {
        can_swap_teams = true;
    }

    void Reset()
    {
        state = State::none;
        UpdatePickWindow(null);
    }

    void onTick(CRules@ rules)
    {
        if (timer != 0)
        {   
            if (state == State::countdown)  // Check to start fight
            {
                s32 time_left = timer - getGameTime();
                if (time_left <= 0)
                {
                    state = State::fight;
                    rules.SetCurrentState(GAME);
                    timer = getGameTime() + FIGHT_SECONDS * getTicksASecond();
                    client_AddToChat("Fight to decide who picks first!", CHAT_COLOR);
                }
            }
            else if (state == State::fight)  // Check to start sudden death
            {
                s32 time_left = timer - getGameTime();
                if (time_left <= 0)
                {
                    timer = 0;
                    StartApocalypse(rules);
                    client_AddToChat("Sudden death!", CHAT_COLOR);
                }
            }
        }
    }

    void onRender(CRules@ rules)
    {
        if (state == State::pick || state == State::win)
        {
            CPlayer@ captain = getCaptain(picking);
            if (captain !is null && getLocalPlayer() is captain)
            {
				// Draw info card
                string msg = state == State::pick ? "Pick a player" : "Do you want first pick?";
                Vec2f text_dims;
                GUI::SetFont("menu");
                GUI::GetTextDimensions(msg, text_dims);
				u16 width = GRID_COLUMNS * BUTTON_WIDTH;
				u8 padding = 6;
				u8 height = text_dims.y + padding * 2;
				Vec2f top_left = pick_window.position - Vec2f(0, height);
				Vec2f bottom_right = top_left + Vec2f(width, height);
                GUI::DrawPane(
                    top_left,
                    bottom_right
                );
                GUI::DrawTextCentered(
                    msg,
                    top_left + (bottom_right - top_left) / 2,
                    picking == TEAM_BLUE ? COLOR_BLUE : COLOR_RED
                );

                // Draw pick menu
                pick_window.draw();
            }
            else
            {
                // Draw info card
                Vec2f top_left(100,200);
                Vec2f padding(6, 6);
                Vec2f end_padding(6, 0);
                string msg = (captain !is null ? captain.getUsername() : "Captain") + " is picking " + (state == State::pick ? "for " + (picking == TEAM_BLUE ? "blue" : "red") + " team" : "which team picks first");
                Vec2f text_dims;
                GUI::SetFont("menu");
                GUI::GetTextDimensions(msg, text_dims);
                GUI::DrawPane(
                    top_left,
                    top_left + text_dims + padding * 2 + end_padding
                );
                GUI::DrawText(
                    msg,
                    top_left + padding,
                    picking == TEAM_BLUE ? COLOR_BLUE : COLOR_RED
                );   
            }
        }
        else if (state == State::countdown || state == State::fight)
        {
            s32 time_left = ((timer - getGameTime()) / getTicksASecond() + 1);
            string msg = state == State::countdown ? time_left + " seconds until fight!" : time_left <= 0 ? "Sudden death!" : time_left <= 10 ? "Sudden death in " + time_left + " seconds!" : "Fight to decide who picks first!";

            Vec2f Mid(getScreenWidth() / 2, getScreenHeight() * 0.2);
            Vec2f text_dims;
            GUI::SetFont("Bigger Font");
            GUI::GetTextDimensions(msg, text_dims);
            GUI::DrawTextCentered(msg, Mid, COLOR_RED);
        }
    }

    void onPlayerChangedTeam(CRules@ rules, CPlayer@ player, u8 oldteam, u8 newteam)
    {
        if (newteam != rules.getSpectatorTeamNum() && player !is null)
        {
            string username = player.getUsername();
            if (no_pick.exists(username))
            {
                no_pick.delete(username);
            }
        }
        UpdatePickWindow(null);
    }

    void onPlayerDie(CRules@ rules, CPlayer@ victim, CPlayer@ killer, u8 customData)
    {
        if (state == State::fight)
        {
            timer = 0;
            if (isServer())
            {
                // Stop sudden death
                rules.set_bool(APOCALYPSE_TOGGLE_STRING, false);

                // Try to avoid people falling into the void constantly
                CMap@ map = getMap();
                CBlob@[] tents;
                getBlobsByName("tent", @tents);
                for (u8 i = 0; i < tents.length; i++)
                {
                    CBlob@ tent = tents[i];
                    if (tent is null || map is null)
                    {
                        continue;
                    }
                    Vec2f pos = tent.getPosition();
                    map.server_SetTile(pos, CMap::tile_ground_back);
                    CBlob@ ladder = server_CreateBlob("ladder", -1, pos + Vec2f(0, -map.tilesize));
                    if (ladder !is null)
                    {
                        ladder.Tag("invincible");
                    }
                    Vec2f mid = pos + Vec2f(0, tent.getHeight() / 2);
                    for (s8 x = -2; x <= 2; x++)
                    {
                        Vec2f target = mid + Vec2f(x * map.tilesize, 0);
                        if (!map.isTileSolid(target))
                        {
                            map.server_SetTile(target, CMap::tile_bedrock);
                        }
                    }
                }
            }
            u8 winning_team = Maths::Abs(victim.getTeamNum() - 1);
            client_AddToChat((winning_team == TEAM_BLUE ? blue_captain_name : red_captain_name) + " won the fight!", CHAT_COLOR);
            StartWinPhase(rules, winning_team);
        }
    }

    void onNewPlayerJoin(CRules@ rules, CPlayer@ player)
    {
        UpdatePickWindow(null);
        if (isServer() && rules !is null && player !is null)
        {
            Sync(rules, player);
            string username = player.getUsername();
            u8 team = rules.getSpectatorTeamNum();
            if (player_teams.exists(username))
            {
                player_teams.get(username, team);
            }
            ChangePlayerTeam(rules, player, team);
        }
    }

    void onPlayerLeave(CRules@ rules, CPlayer@ player)
    {
        UpdatePickWindow(player);
    }

    void StartFightPhase(CRules@ rules, CPlayer@ captain_blue, CPlayer@ captain_red)
    {
        client_AddToChat("Entering fight phase", CHAT_COLOR);
        SetTeams(rules);
        state = State::countdown;
        timer = getGameTime() + COUNTDOWN_SECONDS * getTicksASecond();
        can_swap_teams = false;
        client_AddToChat("Swapping teams is disabled", CHAT_COLOR);
    }

	void StartWinPhase(CRules@ rules, u8 first_pick_team)
    {
        rules.set_bool(APOCALYPSE_TOGGLE_STRING, false);
        client_AddToChat("Entering win phase. " + (first_pick_team == TEAM_BLUE ? "Blue" : "Red") + " captain will pick which team picks first", CHAT_COLOR);
        SetTeams(rules);
        state = State::win;
        picking = first_pick_team;
		UpdatePickWindow(null);
    }

    void StartPickPhase(CRules@ rules, u8 first_pick_team)
    {
        rules.set_bool(APOCALYPSE_TOGGLE_STRING, false);
        client_AddToChat("Entering pick phase. First pick: " + (first_pick_team == TEAM_BLUE ? "Blue" : "Red"), CHAT_COLOR);
        SetTeams(rules);
        // End immediately if there are no players to pick from
        state = State::pick;
        picking = first_pick_team;
		UpdatePickWindow(null);
        CheckEndPickPhase(rules, null, true);
    }

    void CheckEndPickPhase(CRules@ rules, CPlayer@ picked_player, bool first_tick_check = false)
    {
        // Check how many people are left in spec
        CPlayer@ blue_captain = getCaptain(0);
        CPlayer@ red_captain = getCaptain(1);

        CPlayer@[] remaining;
        for (int i = 0; i < getPlayerCount(); i++)
        {
            CPlayer@ player = getPlayer(i);
            if (player !is null && player !is picked_player && (first_tick_check ? player !is blue_captain && player !is red_captain : player.getTeamNum() == rules.getSpectatorTeamNum()) && !no_pick.exists(player.getUsername()))
            {
                remaining.push_back(player);
            }
        }
        
        if (!(remaining.length <= 1 || remaining.length == 2 && (pick_count == 1 || pick_count == 3)))
        {
            return;
        }

        if (isServer())
        {
            for (u8 i = 0; i < remaining.length; i++)
            {
                ChangePlayerTeam(rules, remaining[i], picking);
            }
        }
        client_AddToChat("Exiting pick phase.", CHAT_COLOR);
        state = State::none;
    }

    void SetTeams(CRules@ rules)
    {
        // Set all relevant teams in one go
        int specTeam = rules.getSpectatorTeamNum();

        CPlayer@ blue_captain = getCaptain(0);
        CPlayer@ red_captain = getCaptain(1);
        for(int i = 0; i < getPlayerCount(); i++)
        {
            CPlayer@ player = getPlayer(i);
            if (player !is null)
            {
                ChangePlayerTeam(rules, player, player is blue_captain ? TEAM_BLUE : player is red_captain ? TEAM_RED : specTeam);
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

    void ChangePlayerTeam(CRules@ rules, CPlayer@ player, int team)
    {
        if (player !is null)
        {
            CBlob@ blob = player.getBlob();
            if (blob !is null)
            {
                blob.ClearMenus();
            }
        }

        if (!isServer() || rules is null || player is null)
        {
            return;
        }

        RulesCore@ core;
        rules.get("core", @core);
        if (core !is null)
        {
            core.ChangePlayerTeam(player, team);
            player_teams.set(player.getUsername(), team);
        }
    }

    // Adds the player to the given team if they are currently spectating and can be picked
    void TryPickPlayer(CRules@ rules, CPlayer@ player, u8 team)
    {
        if (rules !is null && player.getTeamNum() == rules.getSpectatorTeamNum() && !no_pick.exists(player.getUsername())) // Don't allow picking of players already on teams or nopick players
        {
            ChangePlayerTeam(rules, player, team);

            // Set the team that's picking
            pick_count++;
            picking = pick_count == 2 || pick_count == 4 ? team : Maths::Abs(team - 1);
            CheckEndPickPhase(rules, player);
        }
    }

    CPlayer@ getCaptain(int team)
    {
        return getPlayerByUsername(team == 0 ? blue_captain_name : red_captain_name);
    }

    void UpdatePickWindow(CPlayer@ lost_player)
    {
        CRules@ rules = getRules();
        string[] button_names;
		if (state == State::pick)
		{
			for (int i = 0; i < getPlayerCount(); i++)
			{
				CPlayer@ player = getPlayer(i);
				if (player !is null && player !is lost_player && player.getTeamNum() == rules.getSpectatorTeamNum() && !no_pick.exists(player.getUsername()))
				{
					button_names.push_back(player.getUsername());
				}
			}
		}
		else
		{
			button_names.push_back("Yes");
			button_names.push_back("No");
		}

        int button_count = button_names.size();
        int grid_rows = (button_count - 1) / 2 + 1;
        int window_width = GRID_COLUMNS * BUTTON_WIDTH;
        int window_height = grid_rows * BUTTON_HEIGHT;

        pick_window.size = Vec2f(window_width, window_height);
        pick_window.clearChildren();

        for (int i = 0; i < button_count; i++)
        {
            int button_x = (i % GRID_COLUMNS) * BUTTON_WIDTH;
            int button_y = (i / GRID_COLUMNS) * BUTTON_HEIGHT;

            Button button = Button(
                Vec2f(button_x, button_y),
                Vec2f(BUTTON_WIDTH, BUTTON_HEIGHT),
                button_names[i],
                SColor(255, 255, 255, 255)
            );
            
            button.addClickListener(button_onClick);
			button.addHoverStateListener(button_onHover);
            pick_window.addChild(button);
        }
    }

    void Sync(CRules@ rules, CPlayer@ player)
    {
        if (rules is null || player is null)
        {
            return;
        }

        CBitStream params;
        params.write_u8(state);
        params.write_u8(picking);
        params.write_u8(pick_count);
        params.write_s32(timer);
        params.write_string(blue_captain_name);
        params.write_string(red_captain_name);
        params.write_bool(can_swap_teams);

        string[]@ no_pick_players = no_pick.getKeys();
        params.write_u8(no_pick_players.length);
        for (u8 i = 0; i < no_pick_players.length; i++)
        {
            params.write_string(no_pick_players[i]);
            params.write_bool(no_pick.exists(no_pick_players[i]));
        }

        rules.SendCommand(rules.getCommandID(CAPTAINS_CORE_SYNC_COMMAND), params, player);
    }
};

void button_onClick(int x, int y, int mouse_button, IGUIItem@ source)
{
	Button@ button = cast<Button@>(source);
	if (mouse_button == 1) // only on left click
	{
		Sound::Play("buttonclick.ogg");
        client_SendChat("/pick " + button.desc, 0);
	}
}

void button_onHover(bool isHovered, IGUIItem@ source)
{
	Sound::Play("select.ogg");
}
