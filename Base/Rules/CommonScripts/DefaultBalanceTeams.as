
/*
 * Auto balance teams inside a RulesCore
 * 		does a conservative job to avoid pissing off players
 * 		and to avoid forcing many implementation limitations
 * 		onto rulescore extensions so it can be used out of
 * 		the box for most gamemodes.
 */

 //modified to remove scramble teams on new map, team auto balance and put players in spec when they join

#include "PlayerInfo.as";
#include "BaseTeamInfo.as";
#include "RulesCore.as";

#define SERVER_ONLY
 
const int sendNewPlayersToSpec = 1;

/**
 * BalanceInfo class
 * simply holds the last time we balanced someone, so we
 * don't make some poor guy angry if he's always balanced
 * 
 * we reset this time when you swap team, so that if you
 * imbalance the game, you can be swapped back swiftly
 */
 
shared class BalanceInfo {
	string username;
	u32 lastBalancedTime;
	
	BalanceInfo() { /*dont use this manually*/ }
	
	BalanceInfo(string _username)
	{ 
		username = _username;
		lastBalancedTime = getGameTime();
	}
};

/*
 * Methods on a global array of balance infos to make the
 * actual hooks much cleaner.
 */

// add a balance info from username
void addBalanceInfo(string username, BalanceInfo[]@ _b_infos)
{
	//check if it's already added
	BalanceInfo@ b = getBalanceInfo(username, _b_infos);
	if (b is null)
		_b_infos.push_back(BalanceInfo(username));
	else 
		b.lastBalancedTime = getGameTime();
}

// get a balanceinfo from a username
BalanceInfo@ getBalanceInfo(string username, BalanceInfo[]@ _b_infos)
{
	for (uint i = 0; i < _b_infos.length; i++)
	{
		BalanceInfo@ b = _b_infos[i];
		if (b.username == username)
			return b;
	}
	return null;
}

// remove a balanceinfo by username
void removeBalanceInfo(string username, BalanceInfo[]@ _b_infos)
{
	for (uint i = 0; i < _b_infos.length; i++)
	{
		if (_b_infos[i].username == username)
		{
			_b_infos.erase(i);
			return;
		}
	}
}

// get the earliest balance time
u32 getEarliestBalance(BalanceInfo[]@ _b_infos)
{
	u32 min = getGameTime(); //not likely to be earlier ;)
	for (uint i = 0; i < _b_infos.length; i++)
	{
		u32 t = _b_infos[i].lastBalancedTime;
		if (t < min)
			min = t;
	}
	
	return min;
}

u32 getAverageBalance(BalanceInfo[]@ _b_infos)
{
	u32 total = 0;
	for (uint i = 0; i < _b_infos.length; i++)
		total += _b_infos[i].lastBalancedTime;
	
	return total / _b_infos.length;
}

s32 getAverageScore(int team)
{
	u32 total = 0;
	u32 count = 0;
	u32 len = getPlayerCount();
	for (uint i = 0; i < len; i++)
	{
		CPlayer@ p = getPlayer(i);
		if(p.getTeamNum() == team)
		{
			count++;
			total += p.getScore();
		}
	}
	
	return (count == 0 ? 0 : total / count);
}


enum BalanceType {
	NOTHING = 0,
	SWAP_BALANCE,
	SCRAMBLE,
	SCORE_SORT,
	KILLS_SORT
};

bool MoreKills(BalanceInfo@ a, BalanceInfo@ b)
{
	CPlayer@ first = getPlayerByUsername(a.username);
	CPlayer@ second = getPlayerByUsername(a.username);
	if (first is null || second is null) return false;
	return first.getKills() > second.getKills();
}

bool MorePoints(BalanceInfo@ a, BalanceInfo@ b)
{
	CPlayer@ first = getPlayerByUsername(a.username);
	CPlayer@ second = getPlayerByUsername(a.username);
	if (first is null || second is null) return false;
	return first.getScore() > second.getScore();
}

////////////////////////////////
// force balance all teams

void BalanceAll(CRules@ this, RulesCore@ core, BalanceInfo[]@ _b_infos)
{
	u32 len = _b_infos.length;
	
	int type = SCRAMBLE;
	
	switch (type)
	{
		case NOTHING: return;
		
		case SWAP_BALANCE:
			
			getNet().server_SendMsg( "This balance mode isn't programmed yet!" );
			//TODO: swap balance code
			
			break;
		
		case SCRAMBLE:
			//remove scramble teams
			/*getNet().server_SendMsg( "Scrambling the teams..." );
			
			for (u32 i = 0; i < len; i++)
			{
				uint index = XORRandom(len);
				BalanceInfo b = _b_infos[index];
				
				_b_infos[index] = _b_infos[i];
				_b_infos[i] = b;
			}*/
			break;
		
		case SCORE_SORT:
		case KILLS_SORT:
			//remove team auto balance
			//will also try to remove all calls to each of these functions
			/*getNet().server_SendMsg( "Balancing the teams..." );
			
			{
				bool toggle = (type == KILLS_SORT);
				u32 sortedsect = 0;
				u32 j;
				for (u32 i = 1; i < len; i++)
				{
					j = i;
					BalanceInfo a = _b_infos[i];
					while( (toggle ? MoreKills(_b_infos[j-1], a) : MorePoints(_b_infos[j-1], a)) 
							&& j > 0 )
					{
						_b_infos[j] = _b_infos[j-1];
						j--;
					}
					_b_infos[j] = a;
				}
			}
			
			*/
			break;
	}
	
	int numTeams = this.getTeamsCount();
	int team = XORRandom(128) % numTeams;
	
	for (u32 i = 0; i < len; i++)
	{
		BalanceInfo@ b = _b_infos[i];
		CPlayer@ p = getPlayerByUsername(b.username);
		
		if (p.getTeamNum() != this.getSpectatorTeamNum())
		{		
			b.lastBalancedTime = getGameTime();
			int tempteam = team++ % numTeams;
			core.ChangePlayerTeam(p, tempteam);
		}
	}
}

///////////////////////////////////////////////////
//pass stuff to the core from each of the hooks

bool haveRestarted = false;

void onRestart( CRules@ this )
{
	this.set_bool("managed teams", true); //core shouldn't try to manage the teams
	this.set_bool("can choose team", true);
	this.set_bool("lockclasses", false);
	//set this here, we need to wait
    //for the other rules script to set up the core
    
    BalanceInfo[]@ _b_infos;
    if (!this.get("autobalance infos", @_b_infos) || _b_infos is null)
    {
		BuildBalanceArray(this);
	}
    
    haveRestarted = true;
}

/*
 * build the balance array and store it inside the rules so it can persist
 */

void BuildBalanceArray(CRules@ this)
{
	BalanceInfo[] temp;
	
	for (int player_step = 0; player_step < getPlayersCount(); ++player_step)
	{
		addBalanceInfo(getPlayer(player_step).getUsername(), temp);
	}
	
	this.set("autobalance infos", temp);
}

/*
 * Add a player to the balance list and set its team number
 */

void onNewPlayerJoin( CRules@ this, CPlayer@ player )
{
	RulesCore@ core;
    this.get("core", @core);

	BalanceInfo[]@ _b_infos;
    this.get("autobalance infos", @_b_infos);

	if (core is null || _b_infos is null) return;
	
	addBalanceInfo(player.getUsername(), _b_infos);
	
	//send players to spectator when they join
	if (sendNewPlayersToSpec==1)
	{
		player.server_setTeamNum( this.getSpectatorTeamNum() );
	} else{
		player.server_setTeamNum(getSmallestTeam( core.teams ));
	}
}

void onPlayerLeave( CRules@ this, CPlayer@ player )
{
	BalanceInfo[]@ _b_infos;
    this.get("autobalance infos", @_b_infos);

	if (_b_infos is null) return;
	
	removeBalanceInfo(player.getUsername(), _b_infos);
	
}

void onTick(CRules@ this)
{	

if(haveRestarted) //not sure if still need this, kept just in case
{
	haveRestarted = false;
}
/*
    if (haveRestarted || (getGameTime() % 150 == 0) )
	{	
		//get the core and balance infos
		RulesCore@ core;
		this.get("core", @core);

		BalanceInfo[]@ _b_infos;
		this.get("autobalance infos", @_b_infos);

		if (core is null || _b_infos is null) return;
			
		if(haveRestarted) //balance all on start
		{
			haveRestarted = false;
			//force all teams balanced
			//BalanceAll(this, core, _b_infos);
		}
		
		if (getTeamDifference(core.teams) > 2)
		{
			//getNet().server_SendMsg( "Teams are way imbalanced due to players leaving..." );
			//getNet().server_SendMsg( "Remember, swapping to the smaller team makes you a better person!" );
		}
	}  
*/
}

bool CanChangeToTeam(CRules@ this, CPlayer@ player, int team)
{
//always let players change team

	/*RulesCore@ core;
    this.get("core", @core);

	BalanceInfo[]@ _b_infos;
    this.get("autobalance infos", @_b_infos);
	
	//print("CAN CHANGE TEAM");
	
	//we cant tell, benefit of doubt
	if (core is null || _b_infos is null) return true;
	
	if(getSecurity().checkAccess_Feature(player, "always_change_team"))
		return true;

	//moving to spec always allowed
	if (team == this.getSpectatorTeamNum())
		return true;
	
	//target is smaller //TODO: tolerance
	//print("target smaller? "+getTeamSize(core.teams, team)+" < "+getTeamSize( core.teams, player.getTeamNum() ));
	if (getTeamSize(core.teams, team) < getTeamSize( core.teams, player.getTeamNum() ))
		return true;
	*/
	return true;
}

//global for passing an extra parameter out without breaking anything
//use immediately as it will be polluted fast :)
string _balancereason = "";

/**
 * Check if we should balance this player
 * 		pass force is true if you want to force a
 * 		balance in almost all cases (except player,
 * 		rulescore, etc dont exist)
 */

bool ShouldBalance(CRules@ this, CPlayer@ player, bool force = false)
{
//always return false

	/*//print("BALANCE CHECK");
	
	RulesCore@ core;
    this.get("core", @core);

	BalanceInfo[]@ _b_infos;
    this.get("autobalance infos", @_b_infos);
	
	if (core is null || _b_infos is null) return false;
	
	BalanceInfo@ b = getBalanceInfo(player.getUsername(), _b_infos);
	if (b is null) return false;
    
    if (force)
		return true;
    
    //player swapped/joined team ages ago -> no balance
    if (b.lastBalancedTime < getAverageBalance(_b_infos))
		return false;
    
    //player is already in smallest team -> no balance
    if (player.getTeamNum() == getSmallestTeam( core.teams ))
		return false;
    
    //difference is worth swapping for
    if (getTeamDifference(core.teams) < 2)
		return false;
    
    //check if the player doesn't suck - dont swap top half of the team
    u32 average = getAverageScore(player.getTeamNum());
    if (player.getScore() > average)
		return false;*/
		
	return false;
}

int Balance(CRules@ this, CPlayer@ player)
{
	//print("BALANCE");
	
	RulesCore@ core;
    this.get("core", @core);

	BalanceInfo[]@ _b_infos;
    this.get("autobalance infos", @_b_infos);
	
	if (core is null || _b_infos is null) return player.getTeamNum();
	
	BalanceInfo@ b = getBalanceInfo(player.getUsername(), _b_infos);
	
	if (b is null)
		return player.getTeamNum();
	
	b.lastBalancedTime = getGameTime();
	
	int teamNum = getSmallestTeam( core.teams );
	
	if (!CanChangeToTeam(this, player, teamNum))
		return player.getTeamNum();
	
	getNet().server_SendMsg( "Balancing "+b.username+" to "+core.teams[teamNum].name );
	return teamNum;
}

void PerformBalanceAndSetTeam(CRules@ this, CPlayer@ player, u8 newteam)
{
	RulesCore@ core;
    this.get("core", @core);
    if (core is null) return;
    
	core.ChangePlayerTeam(player, newteam);
	return;
	//always change team when the player wants
/*
	if ( int(newteam) == this.getSpectatorTeamNum() )  // dont do anything for specs
	{
		core.ChangePlayerTeam(player, newteam);
		return;
	}
	
	int team = newteam;
	if (ShouldBalance(this, player, (newteam == 255)))
	{
		team = Balance(this, player);
		print("DOING BALANCE AND SETTING TEAM - requested "+newteam + " set " + team);
	}

	core.ChangePlayerTeam(player, team);*/
}

//void onPlayerDie( CRules@ this, CPlayer@ victim, CPlayer@ killer, u8 customData )
//{
//	if (victim is null) return;
//	
//	//PerformBalanceAndSetTeam(this, victim, victim.getTeamNum());
//}

void onPlayerRequestTeamChange( CRules@ this, CPlayer@ player, u8 newteam )
{
	if (this.get_bool("can choose team"))
	{
		print("---request team change--- " + player.getTeamNum() + " -> " + newteam);
		PerformBalanceAndSetTeam(this, player, newteam);
	}
	else
	{
		return;	
	}
}
/*
 * if a player wants to spawn and they have
 * team 255 (-1), auto-assign
 */

void onPlayerRequestSpawn( CRules@ this, CPlayer@ player )
{
	RulesCore@ core;
    this.get("core", @core);
    if (core is null) return;
	
	if (core.getInfoFromPlayer(player) !is null)
		PerformBalanceAndSetTeam(this, player, player.getTeamNum());
	if (player.getTeamNum() == 255)
		core.ChangePlayerTeam(player, this.getSpectatorTeamNum());
}

