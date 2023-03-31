#define CLIENT_ONLY

#include "KGUI.as";
#include "CaptainsCommon.as";

const int buttonWidth = 100;
const int buttonHeight = 50;
const int gridColumns = 2;
const Vec2f pickWindowPosition = Vec2f(100, 100); // top-left corner position
Window pickWindow = Window(pickWindowPosition, Vec2f(0, 0));
string localUsername;
bool picked;

void onInit(CRules@ this)
{
	localUsername = getLocalPlayer().getUsername();
	picked = false;
	updatePickWindow();
}

void onPlayerChangedTeam(CRules@ this, CPlayer@ player, u8 oldteam, u8 newteam)
{
	updatePickWindow();
}

void onPlayerLeave(CRules@ this, CPlayer@ player)
{
	updatePickWindow();
}

void onTick(CRules@ this)
{
	if (picked || this.get_u8(state) != State::pick || getPlayerByUsername(localUsername) !is get_captain(this, this.get_u8(picking)))
	{
		this.RemoveScript(getCurrentScriptName()); // this just ain't it no more
	}
}

void onRender(CRules@ this)
{
	if (!picked)
	{
		pickWindow.draw();
	}
}

void updatePickWindow()
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

	pickWindow.size = Vec2f(windowWidth, windowHeight);
	pickWindow.clearChildren();

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
		pickWindow.addChild(button);
	}
}

void button_onClick(int x, int y, int mouseButton, IGUIItem@ source)
{
	Button@ button = cast<Button@>(source);

	if(mouseButton == 1 && !picked) // only on left click
	{
		CBitStream params;
		params.write_string(button.desc);

		CRules@ rules = getRules();
		rules.SendCommand(rules.getCommandID('pick'), params);

		// our work here is done
		picked = true;
	}
}
