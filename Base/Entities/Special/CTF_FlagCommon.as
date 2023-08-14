
#include "CaptainsCommon.as"

bool canPickupFlag(CBlob@ blob)
{
	// Waffle: Prevent players from picking up flags during fight/pick phase
	if (getRules().get_u8(STATE) != State::none)
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
	
	
	return pick;
}

bool shouldFastReturn(CBlob@ this)
{
	int team = this.getTeamNum();
		
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
