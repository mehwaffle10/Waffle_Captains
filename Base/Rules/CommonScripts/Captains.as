#include "Logging.as";
#include "CTF_SharedClasses.as";
#include "SpareCode.as";

const int TEAM_BLUE = 0;
const int TEAM_RED  = 1;

const SColor COLOR_BLUE(0xff0000ff);
const SColor COLOR_RED(0xffff0000);


void onInit(CRules@ this) {
    CaptainsReset(this);

    this.addCommandID("show pick menu");
    this.addCommandID("pick");

    if (!GUI::isFontLoaded("Bigger Font")){
        GUI::LoadFont("Bigger Font", "GUI/Fonts/AveriaSerif-Bold.ttf", 30, true);
    }

}

void onRestart(CRules@ this) {
    CaptainsReset(this);
}

void onTick(CRules@ this) {

    if (getNet().isServer() && this.get_bool("fight for first pick") && this.get_s32("timer") != 0) {
        s32 TimeLeft = this.get_s32("timer") - getGameTime();
        if (TimeLeft <= 0) {
            this.set_s32("timer", 0);
            this.Sync("timer", true);

            this.SetCurrentState(GAME);
            getNet().server_SendMsg("Fight for first pick!");
        }
    }
}

void onRender(CRules@ this) {
    if (this.get_bool("pick phase") && this.exists("team picking")) {
        // Draw interface
        u8 teamPicking = this.get_u8("team picking");

        Vec2f topLeft(100,200);
        Vec2f padding(4, 4);
        Vec2f endPadding(6, 0);
        string msg = (teamPicking == TEAM_BLUE ? "Blue" : "Red") + " team is picking";
        Vec2f textDims;
        GUI::SetFont("menu");
        GUI::GetTextDimensions(msg, textDims);
        GUI::DrawPane(topLeft, topLeft + textDims + padding*2 + endPadding);
        GUI::DrawText(msg, topLeft+padding, teamPicking == TEAM_BLUE ? COLOR_BLUE : COLOR_RED);
	}

    if (this.get_bool("fight for first pick"))
    {
        string msg = this.get_s32("timer") == 0 ? "Fight for first pick!" : ((this.get_s32("timer") - getGameTime()) / 30 + 1) + " seconds until fight!";

        Vec2f Mid(getScreenWidth() / 2, getScreenHeight() * 0.2);
        Vec2f textDims;
        GUI::SetFont("Bigger Font");
        GUI::GetTextDimensions(msg, textDims);
		GUI::DrawTextCentered(msg, Mid, COLOR_RED);
	}
}


bool onServerProcessChat(CRules@ this, const string &in textIn, string &out textOut, CPlayer@ player) {
    // Handle !captains and !pick commands
    
    if(!getNet().isServer()) return true;

    string[]@ tokens = textIn.split(" ");
    int tl = tokens.length;
    if (tl > 0) {
        if ( player.isMod() && tokens[0] == "!captains" && tl >= 3) {
            CPlayer@ captain_blue = GetPlayerByIdent(tokens[1]);
            CPlayer@ captain_red  = GetPlayerByIdent(tokens[2]);
            if (captain_blue is null || captain_red is null) {
                log("onServerProcessChat", "One of the given captain names was invalid.");
            }
            else
            {
                // Set all relevant teams in one go
                RulesCore@ core;
                this.get("core", @core);

                int specTeam = this.getSpectatorTeamNum();

                for(int i = 0; i < getPlayerCount(); i++)
                {
                    CPlayer@ player = getPlayer(i);
                    if(player is captain_blue){
                        core.ChangePlayerTeam(player, TEAM_BLUE);
                        this.set_string("captain blue", player.getUsername());
			this.Sync("captain blue", true);
                    }
                    else if(player is captain_red){
                        core.ChangePlayerTeam(player, TEAM_RED);
                        this.set_string("captain red", player.getUsername());
			this.Sync("captain red", true);

                    }
                    else{
                        core.ChangePlayerTeam(player, specTeam);
                    }
                }
                
                ExitPickPhase(this);
                StartFightPhase(this);
                if (this.get_bool("can choose team")){
                    lockteams(this);
                }
            }
        }
        else if (tokens[0] == "!pick" && tl >= 2) {
        	if (this.get_bool("pick phase")) {
	            u8 teamPicking = this.get_u8("team picking");
	            CPlayer@ captain_blue = getPlayerByUsername(this.get_string("captain blue"));
	            CPlayer@ captain_red  = getPlayerByUsername(this.get_string("captain red"));
	            if (captain_blue is null || captain_red is null) {
	                logBroadcast("onServerProcessChat", 
	                        "ERROR: in pick phase but a captain is null; exiting pick phase.");
	                ExitPickPhase(this);
	            }
	            else if (player is captain_blue && teamPicking == TEAM_BLUE ||
	                        player is captain_red && teamPicking == TEAM_RED) {
	                string targetIdent = tokens[1];
	                CPlayer@ target = GetPlayerByIdent(targetIdent);
	                if (target !is null) {
	                    TryPickPlayer(this, target);
	                }
	            }
	        }
	        /*if (player is getPlayerByUsername(this.get_string("captain blue"))|| player is getPlayerByUsername(this.get_string("captain red"))) {
	        	if (!this.get_bool("pick phase") && !this.get_bool("fight for first pick")) {
		            string targetIdent = tokens[1];
		            CPlayer@ target = GetPlayerByIdent(targetIdent);
		            if (target !is null) {
		                TryPickPlayer(this, target);
		            }
		        }
	        }*/
        }

        else if(tokens[0] == "!forfeit" || tokens[0] == "!randompick" && player.isMod()){
            if(player.getUsername() == this.get_string("captain blue") || player.getUsername() == this.get_string("captain red")){
                u8 firstPick = (tokens[0] == "!forfeit" ? (player.getTeamNum() == 0 ? TEAM_RED : TEAM_BLUE) : (XORRandom(2) == 0 ? TEAM_BLUE : TEAM_RED));
                this.set_u8("first pick", firstPick);
                this.Sync("first pick", true);

                ExitFightPhase(this);
                StartPickPhase(this);

                getNet().server_SendMsg("Entering pick phase. First pick: " + (firstPick == TEAM_BLUE ? "Blue" : "Red"));
            }
        }
    }

    return true;
}	


void CaptainsReset(CRules@ this) {
    this.set_bool("can choose team", true);
    this.set_bool("pick phase", false);
    this.set_bool("fight for first pick", false);
    this.set_u8("team picking", TEAM_BLUE);
    this.set_u8("first pick", TEAM_BLUE);
    //this.set_string("captain blue", "");
    //this.set_string("captain red", "");
    this.set_s32("timer", 0);
}

int CountPlayersInTeam(int teamNum) {
    int count = 0;

    for (int i=0; i < getPlayerCount(); i++) {
        CPlayer@ p = getPlayer(i);
        if (p is null) continue;

        if (p.getTeamNum() == teamNum)
            count++;
    }

    return count;
}

// Adds the player to the given team if they are currently spectating and can be picked
void TryPickPlayer(CRules@ this, CPlayer@ player)
{
    if (player.getTeamNum() == this.getSpectatorTeamNum()) // Don't allow picking of players already on teams
    {
        u8 teamPicking = this.get_u8("team picking");
        ChangePlayerTeam(this, player, teamPicking);

        string msg = (teamPicking == TEAM_BLUE ? "Blue" : "Red") + " team picked " + player.getUsername();
        logBroadcast("TryPickPlayer", msg);
    }
}


void ChangePlayerTeam(CRules@ this, CPlayer@ player, int teamNum) {
    RulesCore@ core;
    this.get("core", @core);
    core.ChangePlayerTeam(player, teamNum);
}


void StartPickPhase(CRules@ this) {
//    log("StartPickPhase", "Starting pick phase!");
	this.set_u8("team picking", this.get_u8("first pick"));
	this.Sync("team picking", true);
    this.set_bool("pick phase", true);
    this.Sync("pick phase", true);

    sendPickMenu(this);
}
void StartFightPhase(CRules@ this) {
    this.set_bool("fight for first pick", true);
    this.set_s32("timer", getGameTime() + 360);
    this.Sync("timer", true);
    this.Sync("fight for first pick", true);
    

}
void ExitPickPhase(CRules@ this) {
//    log("StartPickPhase", "Starting pick phase!");
    this.set_bool("pick phase", false);
    this.Sync("pick phase", true);
}

void ExitFightPhase(CRules@ this){
    this.set_bool("fight for first pick", false);
    this.Sync("fight for first pick", true);
}



void onPlayerDie(CRules@ this, CPlayer@ victim, CPlayer@ killer, u8 customData){
    if (this.get_bool("fight for first pick") && this.get_s32("timer") == 0 && killer !is null)
    {
        if(getNet().isServer()){
            this.set_u8("first pick", Maths::Abs(victim.getTeamNum() - 1));
            this.Sync("first pick", true);
            ExitFightPhase(this);
            StartPickPhase(this);
            getNet().server_SendMsg(killer.getUsername() + " won the fight!");
        }
    }
}

void onPlayerChangedTeam( CRules@ this, CPlayer@ player, u8 oldteam, u8 newteam ){

    if(this.get_bool("pick phase")) // changed from Ontick to changeteam hook
    {

        if (getPlayerCount() == 0 || CountPlayersInTeam(this.getSpectatorTeamNum()) == 0) {
            ExitPickPhase(this);
        }
        else{
                // Set the team that's picking
            int teamPicking;
            int blueCount = CountPlayersInTeam(TEAM_BLUE);
            int redCount = CountPlayersInTeam(TEAM_RED);
            int firstPick = this.get_u8("first pick");
            if (blueCount == redCount) {
                if (blueCount == 2){ 
                    teamPicking = Maths::Abs(firstPick - 1);
                }
                else{
                    teamPicking = firstPick;
                }
            }
            else {
                teamPicking = blueCount < redCount ? TEAM_BLUE : TEAM_RED;
            }

            //log("onTick", "Set team picking to " + teamPicking);
            this.set_u8("team picking", teamPicking);
            //this.Sync("team picking", true);

            sendPickMenu(this);
        }
    }
}

void onCommand(CRules@ this, u8 cmd, CBitStream @params)
{
    if (cmd == this.getCommandID("pick"))
    {
        if (getNet().isServer())
        {
            string username = params.read_string();
            CPlayer@ player = getPlayerByUsername(username);
            if (player !is null)
            {
                TryPickPlayer(this, player);
            }
        }
    }
    else if (cmd == this.getCommandID("show pick menu")) // WARNING: only send to individual players
    {
	print("create pick menu");
        this.AddScript("PickMenu");
    }
}

void sendPickMenu(CRules@ this)
{
    CPlayer@ pickingPlayer = getPlayerByUsername(captGrab(this, this.get_u8("team picking")));
    print("picker is: " + pickingPlayer.getUsername());
    this.SendCommand(this.getCommandID("show pick menu"), CBitStream(), pickingPlayer);
    print("here");
}
