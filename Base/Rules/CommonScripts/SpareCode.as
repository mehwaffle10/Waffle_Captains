#include "Logging.as";

int[] playerNumlist( CRules@ this){

    int[] orders;
    int team;
    for(int i=0; i < getPlayersCount(); i++)
    {
        orders.push_back(i);
    }
    return orders;
}

void lockteams( CRules@ this )
{
	if (isServer()){	
		if (this.get_bool("can choose team"))
		{
			this.set_bool("can choose team", false);
			this.Sync("can choose team", true);
			getNet().server_SendMsg( "swapping teams is disabled!" );
		}
		else
		{
			this.set_bool("can choose team", true);
			this.Sync("can choose team", true);
			getNet().server_SendMsg( "swapping teams is enabled!" );
		}
	}
}

shared string captGrab(CRules@ this, int team){
	string stringName = "captain " + (team == 0 ? "blue" : "red");
	return this.get_string(stringName);
}

shared string[] teamGrab(CRules@ this, int team){
string[] Team;

for (u32 i=0; i < getPlayersCount(); i++)
	{	

		CPlayer@ myplayer = getPlayer(i);
		if(myplayer != null)
		{	
			if(myplayer.getTeamNum() == team)
			{
				Team.push_back(myplayer.getUsername());
			}
		}      
	}
    return Team;
}

CPlayer@ GetPlayerByIdent(string ident) {
    // Takes an identifier, which is a prefix of the player's character name
    // or username. If there is 1 matching player then they are returned.
    // If 0 or 2+ then a warning is logged.
    ident = ident.toLower();
    log("GetPlayerByIdent", "ident = " + ident);
    CPlayer@[] matches; // players matching ident

    for (int i=0; i < getPlayerCount(); i++) {
        CPlayer@ p = getPlayer(i);
        if (p is null) continue;

        string username = p.getUsername().toLower();
        string charname = p.getCharacterName().toLower();

        if (username == ident || charname == ident) {
            log("GetPlayerByIdent", "exact match found: " + p.getUsername());
            return p;
        }
        else if (username.find(ident) >= 0 || charname.find(ident) >= 0) {
            matches.push_back(p);
        }
    }

    if (matches.length == 1) {
        log("GetPlayerByIdent", "1 match found: " + matches[0].getUsername());
        return matches[0];
    }
    else if (matches.length == 0) {
        logBroadcast("GetPlayerByIdent", "Couldn't find anyone called " + ident);
    }
    else {
        logBroadcast("GetPlayerByIdent", "Multiple people are called " + ident + ", be more specific.");
    }

    return null;
}

