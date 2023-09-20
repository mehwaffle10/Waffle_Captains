#include "KGUI.as"
#include "CTF_SharedClasses.as"

const int TEAM_BLUE = 0;
const int TEAM_RED  = 1;

const SColor COLOR_BLUE(0xff0000ff);
const SColor COLOR_RED(0xffff0000);
const SColor CHAT_COLOR = ConsoleColour::PRIVCHAT;

const string CAPTAINS_CORE = "captains core";
const string CAPTAINS_CORE_SYNC_COMMAND = "captains core sync";
const string PICK_COMMAND = "pick";
const SColor NOPICK_COLOR = SColor(255, 150, 150, 150);

const int BUTTON_WIDTH = 100;
const int BUTTON_HEIGHT = 50;
const int GRID_COLUMNS = 2;
Window pick_window = Window(Vec2f(100, 100), Vec2f(0, 0));

namespace State
{
	enum state_type
	{
		none = 0,
		fight,
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
        if (state == State::fight && timer != 0)
        {
            s32 time_left = timer - getGameTime();
            if (time_left <= 0)
            {
                timer = 0;

                rules.SetCurrentState(GAME);
                client_AddToChat("Fight for first pick!", CHAT_COLOR);
            }
        }
    }

    void onRender(CRules@ rules)
    {
        if (state == State::pick)
        {
            CPlayer@ captain = getCaptain(picking);
            if (captain !is null && getLocalPlayer() is captain)
            {
                // Draw pick menu
                pick_window.draw();
            }
            else
            {
                // Draw info card
                Vec2f top_left(100,200);
                Vec2f padding(6, 6);
                Vec2f end_padding(6, 0);
                string msg = (captain !is null ? captain.getUsername() : "Captain") + " is picking for " + (picking == TEAM_BLUE ? "blue" : "red") + " team";
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
        else if (state == State::fight)
        {
            string msg = timer == 0 ? "Fight for first pick!" : ((timer - getGameTime()) / getTicksASecond() + 1) + " seconds until fight!";

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
        if (state == State::fight && timer == 0)
        {
            /*
                ConsoleColour::CHATSPEC
                ConsoleColour::CRAZY
                ConsoleColour::ERROR
                ConsoleColour::GAME
                ConsoleColour::GENERIC
                ConsoleColour::INFO
                ConsoleColour::PRIVCHAT
                ConsoleColour::RCON
                CHAT_COLOR
                ConsoleColour::WARNING
            */
            u8 winning_team = Maths::Abs(victim.getTeamNum() - 1);
            client_AddToChat((winning_team == TEAM_BLUE ? blue_captain_name : red_captain_name) + " won the fight!", CHAT_COLOR);
            StartPickPhase(rules, winning_team);
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
        state = State::fight;
        timer = getGameTime() + 3 * getTicksASecond();
        can_swap_teams = false;
        client_AddToChat("Swapping teams is disabled", CHAT_COLOR);
    }

    void StartPickPhase(CRules@ rules, u8 first_pick_team)
    {
        client_AddToChat("Entering pick phase. First pick: " + (first_pick_team == TEAM_BLUE ? "Blue" : "Red"), CHAT_COLOR);
        // End immediately if there are no players to pick from
        state = State::pick;
        picking = first_pick_team;
        CheckEndPickPhase(rules, null);
    }

    void CheckEndPickPhase(CRules@ rules, CPlayer@ picked_player)
    {
        // Check how many people are left in spec
        int count = 0;
        CPlayer@ last_pick;
        for (int i = 0; i < getPlayerCount(); i++)
        {
            CPlayer@ player = getPlayer(i);
            if (player !is null && player !is picked_player && player.getTeamNum() == rules.getSpectatorTeamNum() && !no_pick.exists(player.getUsername()))
            {
                count++;
                @last_pick = @player;
            }
        }
        if (count > 1)
        {
            return;
        }

        if (isServer() && last_pick !is null)
        {
            ChangePlayerTeam(rules, last_pick, picking);
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
        string[] player_names;
        for (int i = 0; i < getPlayerCount(); i++)
        {
            CPlayer@ player = getPlayer(i);
            if (player !is null && player !is lost_player && player.getTeamNum() == rules.getSpectatorTeamNum() && !no_pick.exists(player.getUsername()))
            {
                player_names.push_back(player.getUsername());
            }
        }

        int button_count = player_names.size();
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
                player_names[i],
                SColor(255, 255, 255, 255)
            );
            
            button.addClickListener(button_onClick);
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
	if(mouse_button == 1) // only on left click
	{
        client_SendChat("/pick " + button.desc, 0);
	}
}
