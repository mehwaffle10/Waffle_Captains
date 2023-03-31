#define CLIENT_ONLY

#include "KGUI.as";
#include "CaptainsCommon.as";

const Vec2f modWindowPosition = Vec2f(100, 100); // top-left corner position
Window modWindow = Window(pickWindowPosition, Vec2f(0, 0));

bool localPlayerMod;
bool openMenu;

void onInit(CRules@ this)
{
	localPlayerMod = getlocalPlayer().isMod()
}

void onPlayerChangedTeam(CRules@ this, CPlayer@ player, u8 oldteam, u8 newteam)
{
	;
}

void onPlayerLeave(CRules@ this, CPlayer@ player)
{
	;
}

void onTick(CRules@ this)
{
	
	if (!openMenu)
	{
		this.RemoveScript(getCurrentScriptName()); // this just ain't it no more
	}
}

void onRender(CRules@ this)
{
	if (openMenu)
	{
		ModWindow.draw();
}


void updateModWindow()
{
	string[] playerNames;
	for (int i = 0; i < getPlayerCount(); i++)
	{
		CPlayer@ player = getPlayer(i);
		if (player.getTeamNum() == getRules().getSpectatorTeamNum())
		{
			playerNames.push_back(player.getUsername());
		}
	}

	int buttonCount = playerNames.size();
	int gridRows = (buttonCount - 1) / 2 + 1;
	int windowWidth = gridColumns * buttonWidth;
	int windowHeight = gridRows * buttonHeight;

	modWindow.size = Vec2f(windowWidth, windowHeight);
	modWindow.clearChildren();

	for (int i = 0; i < buttonCount; i++)
	{
		int buttonX = (i % gridColumns) * buttonWidth;
		int buttonY = (i / gridColumns) * buttonHeight;

		Button button = Button(
			Vec2f(buttonX, buttonY),
			Vec2f(buttonWidth, buttonHeight),
			playerNames[i],
			SColor(255, 255, 255, 255)
		);
		
		button.addClickListener(button_onClick);
		button.addHoverStateListener(button_onHover);
		modWindow.addChild(button);
	}
}

void button_onClick(int x, int y, int mouseButton, IGUIItem@ source)
{
	Button@ button = cast<Button@>(source);

	/*if(mouseButton == 1 && !picked) // only on left click
	{
		CBitStream params;
		params.write_string(button.desc);

		CRules@ rules = getRules();
		rules.SendCommand(rules.getCommandID('pick'), params);

		// our work here is done
		picked = true;
	}*/
}

void button_onHover(bool isHovered, IGUIItem@ source)
{
    /* Cast this back into a label (since it inherits from IGuitItem)
    Button@ button = cast<Button@>(source);

    if (isHovered)
    {
    	print(isHovered + "" + playerHovered + "" + button.desc + "0");
        playerButton = button;
        playerHovered = true;
        print(isHovered + "" + playerHovered + "" + button.desc + "1");


    }
    else{
    	if (button.desc == playerButton.desc){
    		playerHovered = false;
    		print(isHovered + "" + playerHovered + "" + button.desc + "2");
    	}
    }*/
}
