
#include "CaptainsCommon.as"

const string return_prop = "return time";
const u16 return_time = 10 * getTicksASecond();  // Waffle: Flag returns in 10 seconds instead of 20

bool canPickupFlag(CBlob@ blob)
{
    // Waffle: Prevent players from picking up flags during fight/pick phase
    CaptainsCore@ captains_core;
    getRules().get(CAPTAINS_CORE, @captains_core);
	if (captains_core !is null && captains_core.state != State::none)
	{
		return false;
	}

	bool pick = !blob.hasAttached();

	if (!pick)
	{
		CBlob@ carried = blob.getCarriedBlob();
		if (carried !is null)
		{
			pick = carried.hasTag("temp blob");
		}
		else
		{
			pick = true;
		}
	}

	// Waffle: Prevent pickup if travelling through a tunnel
	return pick && blob.get_u32("TUNNEL_TRAVEL_PICKUP_DELAY") + 1 * getTicksASecond() < getGameTime();
}

bool shouldFastReturn(CBlob@ this)
{
	const int team = this.getTeamNum();

	bool fast_return = false;
	CBlob@[] overlapping;
	if (this.getOverlapping(overlapping))
	{
		for(uint i = 0; i < overlapping.length; i++)
		{
			if (overlapping[i].getTeamNum() == team && overlapping[i].hasTag("player"))
			{
				fast_return = true;
				break;
			}
		}
	}
	
	return fast_return;
}
