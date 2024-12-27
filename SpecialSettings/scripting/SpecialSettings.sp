#include <cstrike>
#include <multicolors>
#include <sourcemod>
#include <zombiereloaded>

#include "TeamManager.inc"

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name 		= "SpecialSettings",
	author 		= "Neon",
	description = "Special Settings",
	version 	= "1.0",
	url 		= "https://steamcommunity.com/id/n3ontm"
}

Handle g_VoteMenu = INVALID_HANDLE;
Handle g_SettingsList = INVALID_HANDLE;

ConVar g_cvHlxBonus;
ConVar g_cvBhop;
ConVar g_cvAA;

bool g_bIsRevote = false;
bool g_bEnabled = false;

char g_sCurrentSettings[128];

public void OnPluginStart()
{
	RegAdminCmd("sm_special_settings", Command_ForceVote, ADMFLAG_VOTE);
	RegAdminCmd("sm_ss", Command_ForceVote, ADMFLAG_VOTE);
	RegConsoleCmd("sm_currentsettings", Command_CurrentSettings, "Shows the Mode being played currently");

	g_cvHlxBonus = FindConVar("hlx_difficulty_humans");
	g_cvBhop = FindConVar("sv_enablebunnyhopping");
	g_cvAA = FindConVar("sv_airaccelerate");
	HookConVarChange(g_cvBhop, ConVarChanged_Bhop_AA);
	HookConVarChange(g_cvAA, ConVarChanged_Bhop_AA);
}

public void OnMapStart()
{
	g_bEnabled = false;
	g_sCurrentSettings = "";

	GenerateArray();
}

public void OnClientPutInServer(int client)
{
	if (!g_bEnabled)
		return;

	char sBuffer[512];
	Format(sBuffer, sizeof(sBuffer), "Current Settings: %s", g_sCurrentSettings);

	Panel hNotifyPanel = new Panel(GetMenuStyleHandle(MenuStyle_Radio));
	hNotifyPanel.SetTitle("*** Special Settings have been enabled for this map! Check them below. ***");
	hNotifyPanel.DrawItem("", ITEMDRAW_SPACER);
	hNotifyPanel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
	hNotifyPanel.DrawItem("", ITEMDRAW_SPACER);

	if (strcmp(g_sCurrentSettings, "Sonaki") == 0)
	{
		hNotifyPanel.DrawItem("Falldamage", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Pushnades instead of Firenades", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Pushnades cost 6k with Infinite Amount to Rebuy", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("No Rebuy for all other Weapons", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Less Ammo", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Jump Height 1.0", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Lower General Knockback", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Knifing Zombies deals a lot of Damage", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Higher Air Accelerate", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("No Bhop", ITEMDRAW_RAWLINE);

	}
	else if (strcmp(g_sCurrentSettings, "I3D") == 0)
	{
		hNotifyPanel.DrawItem("Falldamage", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("No Rebuys at all", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Less Ammo", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Jump Height 1.0", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("No Burn-Time from Firenades", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Higher Nade Knockback", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Higher General Knockback", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Default Knife Knockback", ITEMDRAW_RAWLINE);
	}
	else if (strcmp(g_sCurrentSettings, "Hellz") == 0)
	{
  		hNotifyPanel.DrawItem("Unlimited Ammo", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("No Kevlar and Nade Rebuy", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("All other Weapons for Free and Infinite Amount to Rebuy", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Humans have 1 Freezenade", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Jump Height 1.0", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("A lot Shorter Burn-Time from Firenades", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Very Low General Knockback", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Default Knife Knockback", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Way Stronger Zombies (more Speed, HP and HP Regen)", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("No Tossing", ITEMDRAW_RAWLINE);
	}
	else if (strcmp(g_sCurrentSettings, "Plaguefest") == 0)
	{
		hNotifyPanel.DrawItem("Falldamage", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("No Rebuys at all", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Less Ammo", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Jump Height 1.0", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Shorter Burn-Time from Firenades", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Slightly Higher General Knockback", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("Default Knife Knockback", ITEMDRAW_RAWLINE);
	}
	else if (strcmp(g_sCurrentSettings, "GFLClan [default]") == 0)
	{
		hNotifyPanel.DrawItem("Normal GFL Settings", ITEMDRAW_RAWLINE);
	}
	hNotifyPanel.DrawItem("", ITEMDRAW_SPACER);
	hNotifyPanel.DrawItem("You can check these settings by typing: /currentsettings", ITEMDRAW_RAWLINE);
	hNotifyPanel.DrawItem("", ITEMDRAW_SPACER);
	hNotifyPanel.DrawItem("", ITEMDRAW_SPACER);
	hNotifyPanel.DrawItem("1. Got it!", ITEMDRAW_RAWLINE);
	hNotifyPanel.SetKeys(1023);
	hNotifyPanel.Send(client, MenuHandler_NotifyPanel, 0);

	delete hNotifyPanel;
}

public void ConVarChanged_Bhop_AA(ConVar convar, char[] oldValue, const char[] newValue)
{
	if ((g_cvBhop.BoolValue) && (strcmp(g_sCurrentSettings, "Sonaki") == 0))
	{
		ServerCommand("sv_enablebunnyhopping 0");
	}

	if ((g_cvAA.IntValue != 1337) && (strcmp(g_sCurrentSettings, "Sonaki") == 0))
	{
		ServerCommand("sv_airaccelerate 1337");
	}
}

public Action Command_ForceVote(int client, int args)
{
	if (g_bEnabled)
	{
		ReplyToCommand(client, "[Special Settings] Special Settings is already enabled for the duration of this map!");
		return Plugin_Handled;
	}

	GenerateArray();
	CreateTimer(1.0, StartVote, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.1, DisableFunMode, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);

	ShowActivity2(client, "\x01[Special Settings] \x04", "\x01Initiated a Special Settings vote.");
	LogAction(client, -1, "\"%L\" initiated a Special Settings vote.", client);

	return Plugin_Handled;
}

public Action Command_CurrentSettings(int client, int args)
{
	if (g_bEnabled)
	{
		OnClientPutInServer(client);
	}
	else
	{
		CPrintToChat(client, "{green}[Special Settings] {white}is currently not active!");
	}
	return Plugin_Handled;
}

public Action DisableFunMode(Handle timer)
{
	ServerCommand("sm plugins unload disabled/FunMode");
}

public void GenerateArray()
{
	int iBlockSize = ByteCountToCells(PLATFORM_MAX_PATH);
	g_SettingsList = CreateArray(iBlockSize);

	PushArrayString(g_SettingsList, "Sonaki");
	PushArrayString(g_SettingsList, "I3D");
	PushArrayString(g_SettingsList, "Hellz");
	PushArrayString(g_SettingsList, "Plaguefest");

	int iArraySize = GetArraySize(g_SettingsList);

	for (int i = 0; i <= (iArraySize - 1); i++)
	{
		int iRandom = GetRandomInt(0, iArraySize - 1);
		char sTemp1[128];
		GetArrayString(g_SettingsList, iRandom, sTemp1, sizeof(sTemp1));
		char sTemp2[128];
		GetArrayString(g_SettingsList, i, sTemp2, sizeof(sTemp2));
		SetArrayString(g_SettingsList, i, sTemp1);
		SetArrayString(g_SettingsList, iRandom, sTemp2);
	}
	ShiftArrayUp(g_SettingsList, 0);
	SetArrayString(g_SettingsList, 0, "GFLClan [default]");
}

public Action StartVote(Handle timer)
{
	static int iCountDown = 5;
	PrintCenterTextAll("[Special Settings] Starting Vote in %ds", iCountDown);

	if (iCountDown-- <= 0)
	{
		iCountDown = 5;
		InitiateVote();
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public void InitiateVote()
{
	if(IsVoteInProgress())
	{
		CPrintToChatAll("{green}[Special Settings] {white}Another vote is currently in progress, retrying again in 5s.");
		CreateTimer(1.0, StartVote, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	Handle menuStyle = GetMenuStyleHandle(MenuStyle_Default);
	g_VoteMenu = CreateMenuEx(menuStyle, Handler_SettingsVoteMenu, MenuAction_End | MenuAction_Display | MenuAction_DisplayItem | MenuAction_VoteCancel);

	int iArraySize = GetArraySize(g_SettingsList);
	for (int i = 0; i <= (iArraySize - 1); i++)
	{
		char sBuffer[128];
		GetArrayString(g_SettingsList, i, sBuffer, sizeof(sBuffer));
		AddMenuItem(g_VoteMenu, sBuffer, sBuffer);
	}

	SetMenuOptionFlags(g_VoteMenu, MENUFLAG_BUTTON_NOVOTE);
	SetMenuTitle(g_VoteMenu, "Server Setings for the current Map?");
	SetVoteResultCallback(g_VoteMenu, Handler_SettingsVoteFinished);
	VoteMenuToAll(g_VoteMenu, 20);
}

public int Handler_SettingsVoteMenu(Handle menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_NotifyPanel(Handle menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select, MenuAction_Cancel:
			delete menu;
	}
}

public void Handler_SettingsVoteFinished(Handle menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	int highest_votes = item_info[0][VOTEINFO_ITEM_VOTES];
	int required_percent = 60;
	int required_votes = RoundToCeil(float(num_votes) * float(required_percent) / 100);

	if ((highest_votes < required_votes) && (!g_bIsRevote))
	{
		CPrintToChatAll("{green}[Special Settings] {white}A revote is needed!");
		char sFirst[128];
		char sSecond[128];
		GetMenuItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], sFirst, sizeof(sFirst));
		GetMenuItem(menu, item_info[1][VOTEINFO_ITEM_INDEX], sSecond, sizeof(sSecond));
		ClearArray(g_SettingsList);
		PushArrayString(g_SettingsList, sFirst);
		PushArrayString(g_SettingsList, sSecond);
		g_bIsRevote = true;
		CreateTimer(1.0, StartVote, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

		return;
	}

	// No revote needed, continue as normal.
	g_bIsRevote = false;
	Handler_VoteFinishedGeneric(menu, num_votes, num_clients, client_info, num_items, item_info);
}

public void Handler_VoteFinishedGeneric(Handle menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	char sWinner[128];
	GetMenuItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], sWinner, sizeof(sWinner));
	float fPercentage = float(item_info[0][VOTEINFO_ITEM_VOTES] * 100) / float(num_votes);

	CPrintToChatAll("{green}[Special Settings] {white}Vote Finished! Winner: {red}%s{white} with %d%% of %d votes!", sWinner, RoundToFloor(fPercentage), num_votes);

	bool bNeedRestart = false;
	if (strcmp(sWinner, "Sonaki") == 0)
	{
		ServerCommand("exec sonaki");
		bNeedRestart = true;
	}
	else if (strcmp(sWinner, "I3D") == 0)
	{
		ServerCommand("exec i3d");
		bNeedRestart = true;
	}
	else if (strcmp(sWinner, "Hellz") == 0)
	{
		ServerCommand("exec hellz");
		bNeedRestart = true;
	}
	else if (strcmp(sWinner, "Plaguefest") == 0)
	{
		ServerCommand("exec plaguefest");
		bNeedRestart = true;
	}
	else if ((strcmp(sWinner, "GFLClan [default]") == 0) && (strcmp(g_sCurrentSettings, "") != 0))
	{
		ServerCommand("exec gfl");
		bNeedRestart = true;
	}

	float fDelay = 3.0;
	if (bNeedRestart)
	{
		CS_TerminateRound(fDelay, CSRoundEnd_GameStart, false);
		CreateTimer(fDelay, Timer_IncreaseKB, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	CreateTimer(fDelay, Timer_FireOnClientPutInServer, _, TIMER_FLAG_NO_MAPCHANGE);
	g_sCurrentSettings = sWinner;
	g_bEnabled = true;
}

public Action Timer_IncreaseKB(Handle timer)
{
	if (g_cvHlxBonus.IntValue == 1)
	{
		ServerCommand("zr_class_set_multiplier zombies knockback 1.05");
	}
	else if (g_cvHlxBonus.IntValue == 2)
	{
		ServerCommand("zr_class_set_multiplier zombies knockback 1.1");
	}
	else if (g_cvHlxBonus.IntValue == 3)
	{
		ServerCommand("zr_class_set_multiplier zombies knockback 1.15");
	}
	return Plugin_Handled;
}

public Action Timer_FireOnClientPutInServer(Handle hThis)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		OnClientPutInServer(i);
	}

	return Plugin_Handled;
}
