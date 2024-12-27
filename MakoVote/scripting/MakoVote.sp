#include <cstrike>
#include <multicolors>
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name        = "MakoVoteSystem",
	author 	    = "Neon",
	description = "MakoVoteSystem",
	version     = "1.1",
	url         = "https://steamcommunity.com/id/n3ontm"
}

#define NUMBEROFSTAGES 6

bool g_bVoteFinished = true;
bool g_bIsRevote = false;
bool bStartVoteNextRound = false;

bool g_bOnCooldown[NUMBEROFSTAGES];
static char g_sStageName[NUMBEROFSTAGES][512] = {"Extreme 2", "Extreme 2 (Heal + Ultima)", "Extreme 3 (ZED)", "Extreme 3 (Hellz)", "Race Mode", "Zombie Mode"};
int g_Winnerstage;

Handle g_VoteMenu = INVALID_HANDLE;
Handle g_StageList = INVALID_HANDLE;
Handle g_CountdownTimer = INVALID_HANDLE;

public void OnPluginStart()
{
	RegServerCmd("sm_makovote", Command_StartVote);
	HookEvent("round_start",  OnRoundStart);
}

public void OnMapStart()
{
	VerifyMap();

	PrecacheSound("#unloze/Pendulum - Witchcraft.mp3", true);
	AddFileToDownloadsTable("sound/unloze/Pendulum - Witchcraft.mp3");

	bStartVoteNextRound = false;

	for (int i = 0; i <= (NUMBEROFSTAGES - 1); i++)
		g_bOnCooldown[i] = false;
}

public Action VerifyMap()
{
	char currentMap[64];
	GetCurrentMap(currentMap, sizeof(currentMap));
	if (!StrEqual(currentMap, "ze_FFVII_Mako_Reactor_v5_3"))
	{
		char sFilename[256];
		GetPluginFilename(INVALID_HANDLE, sFilename, sizeof(sFilename));
		ServerCommand("sm plugins unload %s", sFilename);
	}
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (IsValidEntity(iEntity))
	{
		SDKHook(iEntity, SDKHook_SpawnPost, OnEntitySpawned);
	}
}

public void OnEntitySpawned(int iEntity)
{
	if (g_bVoteFinished)
		return;

	char sTargetname[128];
	GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
	char sClassname[128];
	GetEdictClassname(iEntity, sClassname, sizeof(sClassname));

	if ((strcmp(sTargetname, "espad") != 0) && (strcmp(sTargetname, "ss_slow") != 0) && (strcmp(sClassname, "ambient_generic") == 0))
	{
		AcceptEntityInput(iEntity, "Kill");
	}
}

public void OnRoundStart(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	if (bStartVoteNextRound)
	{
		g_CountdownTimer = CreateTimer(1.0, StartVote, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		bStartVoteNextRound = false;
	}

	if (!(g_bVoteFinished))
	{
		int iStrip = FindEntityByTargetname(INVALID_ENT_REFERENCE, "race_game_zone", "game_zone_player");
		if (iStrip != INVALID_ENT_REFERENCE)
			AcceptEntityInput(iStrip, "FireUser1");

		int iCounter = FindEntityByTargetname(INVALID_ENT_REFERENCE, "Level_Counter", "math_counter");
		if (iCounter != INVALID_ENT_REFERENCE)
			AcceptEntityInput(iCounter, "Kill");

		int iDestination = FindEntityByTargetname(INVALID_ENT_REFERENCE, "arriba2ex", "info_teleport_destination");
		if (iDestination != INVALID_ENT_REFERENCE)
		{

			SetVariantString("origin -9350 4550 100");
			AcceptEntityInput(iDestination, "AddOutput");

			SetVariantString("angles 0 -90 0");
			AcceptEntityInput(iDestination, "AddOutput");
		}

		int iTeleport = FindEntityByTargetname(INVALID_ENT_REFERENCE, "teleporte_extreme", "trigger_teleport");
		if (iTeleport != INVALID_ENT_REFERENCE)
			AcceptEntityInput(iTeleport, "Enable");

		int iBarrerasfinal2 = FindEntityByTargetname(INVALID_ENT_REFERENCE, "barrerasfinal2", "func_breakable");
		if (iBarrerasfinal2 != INVALID_ENT_REFERENCE)
			AcceptEntityInput(iBarrerasfinal2, "Break");

		int iBarrerasfinal = FindEntityByTargetname(INVALID_ENT_REFERENCE, "barrerasfinal", "prop_dynamic");
		if (iBarrerasfinal != INVALID_ENT_REFERENCE)
				AcceptEntityInput(iBarrerasfinal, "Kill");

		int iPush = FindEntityByTargetname(INVALID_ENT_REFERENCE, "race_push", "trigger_push");
		if (iPush != INVALID_ENT_REFERENCE)
				AcceptEntityInput(iPush, "Kill");

		int iFilter = FindEntityByTargetname(INVALID_ENT_REFERENCE, "humanos", "filter_activator_team");
		if (iFilter != INVALID_ENT_REFERENCE)
				AcceptEntityInput(iFilter, "Kill");

		int iTemp1 = FindEntityByTargetname(INVALID_ENT_REFERENCE, "ex2_laser_1_temp", "point_template");
		if (iTemp1 != INVALID_ENT_REFERENCE)
		{
				DispatchKeyValue(iTemp1, "OnEntitySpawned", "ex2_laser_1_hurt,SetDamage,0,0,-1");
				DispatchKeyValue(iTemp1, "OnEntitySpawned", "ex2_laser_1_hurt,AddOutput,OnStartTouch !activator:AddOutput:origin -7000 -1000 100:0:-1,0,-1");
		}

		int iTemp2 = FindEntityByTargetname(INVALID_ENT_REFERENCE, "ex2_laser_2_temp", "point_template");
		if (iTemp2 != INVALID_ENT_REFERENCE)
		{
				DispatchKeyValue(iTemp2, "OnEntitySpawned", "ex2_laser_2_hurt,SetDamage,0,0,-1");
				DispatchKeyValue(iTemp2, "OnEntitySpawned", "ex2_laser_2_hurt,AddOutput,OnStartTouch !activator:AddOutput:origin -7000 -1000 100:0:-1,0,-1");
		}

		int iTemp3 = FindEntityByTargetname(INVALID_ENT_REFERENCE, "ex2_laser_3_temp", "point_template");
		if (iTemp3 != INVALID_ENT_REFERENCE)
		{
				DispatchKeyValue(iTemp3, "OnEntitySpawned", "ex2_laser_3_hurt,SetDamage,0,0,-1");
				DispatchKeyValue(iTemp3, "OnEntitySpawned", "ex2_laser_3_hurt,AddOutput,OnStartTouch !activator:AddOutput:origin -7000 -1000 100:0:-1,0,-1");
		}

		int iTemp4 = FindEntityByTargetname(INVALID_ENT_REFERENCE, "ex2_laser_4_temp", "point_template");
		if (iTemp4 != INVALID_ENT_REFERENCE)
		{
				DispatchKeyValue(iTemp4, "OnEntitySpawned", "ex2_laser_4_hurt,SetDamage,0,0,-1");
				DispatchKeyValue(iTemp4, "OnEntitySpawned", "ex2_laser_4_hurt,AddOutput,OnStartTouch !activator:AddOutput:origin -7000 -1000 100:0:-1,0,-1");

		}

		int iLaserTimer = FindEntityByTargetname(INVALID_ENT_REFERENCE, "cortes2", "logic_timer");
		if (iLaserTimer != INVALID_ENT_REFERENCE)
			AcceptEntityInput(iLaserTimer, "Enable");

		int iGameText = FindEntityByTargetname(INVALID_ENT_REFERENCE, "Level_Text", "game_text");
		if (iGameText != INVALID_ENT_REFERENCE)
			AcceptEntityInput(iGameText, "Kill");

		int iNewGameText;
		iNewGameText = CreateEntityByName("game_text");
		DispatchKeyValue(iNewGameText, "targetname", "intermission_game_text");
		DispatchKeyValue(iNewGameText, "channel", "4");
		DispatchKeyValue(iNewGameText, "spawnflags", "1");
		DispatchKeyValue(iNewGameText, "color", "255 128 0");
		DispatchKeyValue(iNewGameText, "color2", "255 255 0");
		DispatchKeyValue(iNewGameText, "fadein", "1");
		DispatchKeyValue(iNewGameText, "fadeout", "1");
		DispatchKeyValue(iNewGameText, "holdtime", "10");
		DispatchKeyValue(iNewGameText, "message", "Intermission Round");
		DispatchKeyValue(iNewGameText, "x", "-1");
		DispatchKeyValue(iNewGameText, "y", ".01");
		DispatchKeyValue(iNewGameText, "OnUser1", "!self,Display,,0,-1");
		DispatchKeyValue(iNewGameText, "OnUser1", "!self,FireUser1,,5,-1");
		DispatchSpawn(iNewGameText);
		SetVariantString("!activator");
		AcceptEntityInput(iNewGameText, "FireUser1");

		int iMusic = FindEntityByTargetname(INVALID_ENT_REFERENCE, "ss_slow", "ambient_generic");
		if (iMusic != INVALID_ENT_REFERENCE)
		{
			SetVariantString("message #unloze/Pendulum - Witchcraft.mp3");
			AcceptEntityInput(iMusic, "AddOutput");
			AcceptEntityInput(iMusic, "PlaySound");
		}
	}
}

public void GenerateArray()
{
	int iBlockSize = ByteCountToCells(PLATFORM_MAX_PATH);
	g_StageList = CreateArray(iBlockSize);

	for (int i = 0; i <= (NUMBEROFSTAGES - 1); i++)
		PushArrayString(g_StageList, g_sStageName[i]);

	int iArraySize = GetArraySize(g_StageList);

	for (int i = 0; i <= (iArraySize - 1); i++)
	{
		int iRandom = GetRandomInt(0, iArraySize - 1);
		char sTemp1[128];
		GetArrayString(g_StageList, iRandom, sTemp1, sizeof(sTemp1));
		char sTemp2[128];
		GetArrayString(g_StageList, i, sTemp2, sizeof(sTemp2));
		SetArrayString(g_StageList, i, sTemp1);
		SetArrayString(g_StageList, iRandom, sTemp2);
	}
}

public Action Command_StartVote(int args)
{
	int iCurrentStage = GetCurrentStage();

	if (iCurrentStage > -1)
		g_bOnCooldown[iCurrentStage] = true;

	int iOnCD = 0;
	for (int i = 0; i <= (NUMBEROFSTAGES - 1); i++)
	{
		if (g_bOnCooldown[i])
			iOnCD += 1;
	}

	if (iOnCD >= 3)
	{
		for (int i = 0; i <= (NUMBEROFSTAGES - 1); i++)
			g_bOnCooldown[i] = false;
	}

	g_bVoteFinished = false;
	GenerateArray();
	bStartVoteNextRound = true;

	return Plugin_Handled;
}

public Action StartVote(Handle timer)
{
	static int iCountDown = 5;
	PrintCenterTextAll("[MakoVote] Starting Vote in %ds", iCountDown);

	if (iCountDown-- <= 0)
	{
		iCountDown = 5;
		KillTimer(g_CountdownTimer);
		g_CountdownTimer = INVALID_HANDLE;
		InitiateVote();
	}
}

public void InitiateVote()
{
	if(IsVoteInProgress())
	{
		CPrintToChatAll("{green}[Mako Vote] {white}Another vote is currently in progress, retrying again in 5s.");
		g_CountdownTimer = CreateTimer(1.0, StartVote, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	Handle menuStyle = GetMenuStyleHandle(view_as<MenuStyle>(0));
	g_VoteMenu = CreateMenuEx(menuStyle, Handler_MakoVoteMenu, MenuAction_End | MenuAction_Display | MenuAction_DisplayItem | MenuAction_VoteCancel);

	int iArraySize = GetArraySize(g_StageList);
	for (int i = 0; i <= (iArraySize - 1); i++)
	{
		char sBuffer[128];
		GetArrayString(g_StageList, i, sBuffer, sizeof(sBuffer));

		for (int j = 0; j <= (NUMBEROFSTAGES - 1); j++)
		{
			if (strcmp(sBuffer, g_sStageName[j]) == 0)
			{
				if (g_bOnCooldown[j])
					AddMenuItem(g_VoteMenu, sBuffer, sBuffer, ITEMDRAW_DISABLED);
				else
					AddMenuItem(g_VoteMenu, sBuffer, sBuffer);
			}
		}
	}

	SetMenuOptionFlags(g_VoteMenu, MENUFLAG_BUTTON_NOVOTE);
	SetMenuTitle(g_VoteMenu, "What stage to play next?");
	SetVoteResultCallback(g_VoteMenu, Handler_SettingsVoteFinished);
	VoteMenuToAll(g_VoteMenu, 20);
}

public int Handler_MakoVoteMenu(Handle menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			CloseHandle(menu);

			if (param1 != -1)
			{
				g_bVoteFinished = true;
				float fDelay = 3.0;
				CS_TerminateRound(fDelay, CSRoundEnd_GameStart, false);
			}
		}
	}
	return 0;
}

public int MenuHandler_NotifyPanel(Menu hMenu, MenuAction iAction, int iParam1, int iParam2)
{
	switch (iAction)
	{
		case MenuAction_Select, MenuAction_Cancel:
			delete hMenu;
	}
}

public void Handler_SettingsVoteFinished(Handle menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	int highest_votes = item_info[0][VOTEINFO_ITEM_VOTES];
	int required_percent = 60;
	int required_votes = RoundToCeil(float(num_votes) * float(required_percent) / 100);

	if ((highest_votes < required_votes) && (!g_bIsRevote))
	{
		CPrintToChatAll("{green}[MakoVote] {white}A revote is needed!");
		char sFirst[128];
		char sSecond[128];
		GetMenuItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], sFirst, sizeof(sFirst));
		GetMenuItem(menu, item_info[1][VOTEINFO_ITEM_INDEX], sSecond, sizeof(sSecond));
		ClearArray(g_StageList);
		PushArrayString(g_StageList, sFirst);
		PushArrayString(g_StageList, sSecond);
		g_bIsRevote = true;
		g_CountdownTimer = CreateTimer(1.0, StartVote, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

		return;
	}

	// No revote needed, continue as normal.
	g_bIsRevote = false;
	Handler_VoteFinishedGeneric(menu, num_votes, num_clients, client_info, num_items, item_info);
}

public void Handler_VoteFinishedGeneric(Handle menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	g_bVoteFinished = true;
	char sWinner[128];
	GetMenuItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], sWinner, sizeof(sWinner));
	float fPercentage = float(item_info[0][VOTEINFO_ITEM_VOTES] * 100) / float(num_votes);

	CPrintToChatAll("{green}[MakoVote] {white}Vote Finished! Winner: {red}%s{white} with %d%% of %d votes!", sWinner, RoundToFloor(fPercentage), num_votes);

	for (int i = 0; i <= (NUMBEROFSTAGES - 1); i++)
	{
		if (strcmp(sWinner, g_sStageName[i]) == 0)
			g_Winnerstage = i;
	}

	ServerCommand("sm_stage %d", (g_Winnerstage + 4));

	float fDelay = 3.0;
	CS_TerminateRound(fDelay, CSRoundEnd_GameStart, false);
}

public int GetCurrentStage()
{
	int iLevelCounterEnt = FindEntityByTargetname(INVALID_ENT_REFERENCE, "Level_Counter", "math_counter");

	int offset = FindDataMapInfo(iLevelCounterEnt, "m_OutValue");
	int iCounterVal = RoundFloat(GetEntDataFloat(iLevelCounterEnt, offset));

	int iCurrentStage;
	if (iCounterVal == 5)
		iCurrentStage = 0;
	else if (iCounterVal == 6)
		iCurrentStage = 5;
	else if (iCounterVal == 7)
		iCurrentStage = 1;
	else if (iCounterVal == 9)
		iCurrentStage = 3;
	else if (iCounterVal == 10)
		iCurrentStage = 2;
	else if (iCounterVal == 11)
		iCurrentStage = 4;
	else
		iCurrentStage = 0;

	return iCurrentStage;
}

public int FindEntityByTargetname(int entity, const char[] sTargetname, const char[] sClassname)
{
	if(sTargetname[0] == '#') // HammerID
	{
		int HammerID = StringToInt(sTargetname[1]);

		while((entity = FindEntityByClassname(entity, sClassname)) != INVALID_ENT_REFERENCE)
		{
			if(GetEntProp(entity, Prop_Data, "m_iHammerID") == HammerID)
				return entity;
		}
	}
	else // Targetname
	{
		int Wildcard = FindCharInString(sTargetname, '*');
		char sTargetnameBuf[64];

		while((entity = FindEntityByClassname(entity, sClassname)) != INVALID_ENT_REFERENCE)
		{
			if(GetEntPropString(entity, Prop_Data, "m_iName", sTargetnameBuf, sizeof(sTargetnameBuf)) <= 0)
				continue;

			if(strncmp(sTargetnameBuf, sTargetname, Wildcard) == 0)
				return entity;
		}
	}
	return INVALID_ENT_REFERENCE;
}
