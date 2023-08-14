#include "Logging.as";

namespace State
{
	enum state_type
	{
		none = 0,
		fight,
		pick
	};
};

const string STATE = "captains state";
const string FIRST_PICK = "captains first pick";
const string PICKING = "captains currently picking";
const string TIMER = "captains timer";
const string NOPICK_TAG = "nopick";
const string NOPICK_COMMAND = "nopick command";
const SColor NOPICK_COLOR = SColor(255, 150, 150, 150);

CPlayer@ get_captain(CRules@ this, int team)
{
	return getPlayerByUsername(this.get_string(team == 0 ? "captain blue" : "captain red"));
}

CPlayer@ GetPlayerByIdent(string ident)
{
    // Takes an identifier, which is a prefix of the player's character name
    // or username. If there is 1 matching player then they are returned.
    // If 0 or 2+ then a warning is logged.
    ident = ident.toLower();
    log("GetPlayerByIdent", "ident = " + ident);
    CPlayer@[] matches; // players matching ident

    for (int i=0; i < getPlayerCount(); i++)
    {
        CPlayer@ p = getPlayer(i);
        if (p is null) continue;

        string username = p.getUsername().toLower();
        string charname = p.getCharacterName().toLower();

        if (username == ident || charname == ident)
        {
            log("GetPlayerByIdent", "exact match found: " + p.getUsername());
            return p;
        }
        else if (username.find(ident) >= 0 || charname.find(ident) >= 0)
        {
            matches.push_back(p);
        }
    }

    if (matches.length == 1)
    {
        log("GetPlayerByIdent", "1 match found: " + matches[0].getUsername());
        return matches[0];
    }
    else if (matches.length == 0)
    {
        logBroadcast("GetPlayerByIdent", "Couldn't find anyone called " + ident);
    }
    else
    {
        logBroadcast("GetPlayerByIdent", "Multiple people are called " + ident + ", be more specific.");
    }

    return null;
}

