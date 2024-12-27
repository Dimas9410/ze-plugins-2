#include <zombiereloaded>
#include <clientprefs>
#include <multicolors>
#include <sourcemod>
#include <sdktools>

#include "loghelper.inc"

#define SPECMODE_NONE           0
#define SPECMODE_FIRSTPERSON    4
#define SPECMODE_THIRDPERSON    5
#define SPECMODE_FREELOOK       6

bool g_bHideCrown[MAXPLAYERS+1];
bool g_bHideDialog[MAXPLAYERS+1];
bool g_bProtection[MAXPLAYERS+1];

Handle g_hCookie_HideCrown;
Handle g_hCookie_HideDialog;
Handle g_hCookie_Protection;

ConVar g_hCVar_Protection;
ConVar g_hCVar_ProtectionMinimal1;
ConVar g_hCVar_ProtectionMinimal2;
ConVar g_hCVar_ProtectionMinimal3;

int g_iCrownEntity = -1;
int g_iDialogLevel = 100000;

int g_iPlayerWinner[3];
int g_iPlayerDamage[MAXPLAYERS+1];
int g_iPlayerDamageFrom1K[MAXPLAYERS+1];

public Plugin myinfo =
{
	name         = "Top Defenders",
	author       = "Neon & zaCade",
	description  = "Show Top Defenders after each round",
	version      = "1.0.0"
};

public void OnPluginStart()
{
	LoadTranslations("plugin.topdefenders.phrases");

	g_hCVar_Protection         = CreateConVar("sm_topdefenders_protection", "1", "", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCVar_ProtectionMinimal1 = CreateConVar("sm_topdefenders_minimal_1", "15", "", FCVAR_NONE, true, 1.0, true, 64.0);
	g_hCVar_ProtectionMinimal2 = CreateConVar("sm_topdefenders_minimal_2", "30", "", FCVAR_NONE, true, 1.0, true, 64.0);
	g_hCVar_ProtectionMinimal3 = CreateConVar("sm_topdefenders_minimal_3", "45", "", FCVAR_NONE, true, 1.0, true, 64.0);

	g_hCookie_HideCrown  = RegClientCookie("topdefenders_hidecrown",  "", CookieAccess_Private);
	g_hCookie_HideDialog = RegClientCookie("topdefenders_hidedialog", "", CookieAccess_Private);
	g_hCookie_Protection = RegClientCookie("topdefenders_protection", "", CookieAccess_Private);

	CreateTimer(0.1, UpdateScoreboard, INVALID_HANDLE, TIMER_REPEAT);
	CreateTimer(0.1, UpdateDialog,     INVALID_HANDLE, TIMER_REPEAT);

	RegConsoleCmd("sm_togglecrown",    OnToggleCrown);
	RegConsoleCmd("sm_toggledialog",   OnToggleDialog);
	RegConsoleCmd("sm_toggleimmunity", OnToggleImmunity);

	HookEvent("round_start",  OnRoundStart);
	HookEvent("round_end",    OnRoundEnding);
	HookEvent("player_hurt",  OnClientHurt);
	HookEvent("player_spawn", OnClientSpawn);
	HookEvent("player_death", OnClientDeath);

	SetCookieMenuItem(MenuHandler_CookieMenu, 0, "Top Defenders");
}

public Action OnToggleCrown(int client, int args)
{
	ToggleCrown(client);
	return Plugin_Handled;
}

public Action OnToggleDialog(int client, int args)
{
	ToggleDialog(client);
	return Plugin_Handled;
}

public Action OnToggleImmunity(int client, int args)
{
	ToggleImmunity(client);
	return Plugin_Handled;
}

public void ToggleCrown(int client)
{
	g_bHideCrown[client] = !g_bHideCrown[client];

	SetClientCookie(client, g_hCookie_HideCrown, g_bHideCrown[client] ? "1" : "");

	CPrintToChat(client, "{cyan}%t {white}%t", "Chat Prefix", g_bHideCrown[client] ? "Crown Disabled" : "Crown Enabled");
}

public void ToggleDialog(int client)
{
	g_bHideDialog[client] = !g_bHideDialog[client];

	SetClientCookie(client, g_hCookie_HideDialog, g_bHideDialog[client] ? "1" : "");

	CPrintToChat(client, "{cyan}%t {white}%t", "Chat Prefix", g_bHideDialog[client] ? "Dialog Disabled" : "Dialog Enabled");
}

public void ToggleImmunity(int client)
{
	g_bProtection[client] = !g_bProtection[client];

	SetClientCookie(client, g_hCookie_Protection, g_bProtection[client] ? "1" : "");

	CPrintToChat(client, "{cyan}%t {white}%t", "Chat Prefix", g_bProtection[client] ? "Immunity Disabled" : "Immunity Enabled");
}

public void ShowSettingsMenu(int client)
{
	Menu menu = new Menu(MenuHandler_MainMenu);

	menu.SetTitle("%T", "Cookie Menu Title", client);

	AddMenuItemTranslated(menu, "0", "%t: %t", "Crown",    g_bHideCrown[client]  ? "Disabled" : "Enabled");
	AddMenuItemTranslated(menu, "1", "%t: %t", "Dialog",   g_bHideDialog[client] ? "Disabled" : "Enabled");
	AddMenuItemTranslated(menu, "2", "%t: %t", "Immunity", g_bProtection[client] ? "Disabled" : "Enabled");

	menu.ExitBackButton = true;

	menu.Display(client, MENU_TIME_FOREVER);
}

public void MenuHandler_CookieMenu(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch(action)
	{
		case(CookieMenuAction_DisplayOption):
		{
			Format(buffer, maxlen, "%T", "Cookie Menu", client);
		}
		case(CookieMenuAction_SelectOption):
		{
			ShowSettingsMenu(client);
		}
	}
}

public int MenuHandler_MainMenu(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case(MenuAction_Select):
		{
			switch(selection)
			{
				case(0): ToggleCrown(client);
				case(1): ToggleDialog(client);
				case(2): ToggleImmunity(client);
			}

			ShowSettingsMenu(client);
		}
		case(MenuAction_Cancel):
		{
			ShowCookieMenu(client);
		}
		case(MenuAction_End):
		{
			delete menu;
		}
	}
}

public void OnMapStart()
{
	PrecacheSound("unloze/holy.wav");
	PrecacheModel("models/unloze/crown_v2.mdl");

	AddFileToDownloadsTable("sound/unloze/holy.wav");
	AddFileToDownloadsTable("models/unloze/crown_v2.mdl");
	AddFileToDownloadsTable("models/unloze/crown_v2.phy");
	AddFileToDownloadsTable("models/unloze/crown_v2.vvd");
	AddFileToDownloadsTable("models/unloze/crown_v2.sw.vtx");
	AddFileToDownloadsTable("models/unloze/crown_v2.dx80.vtx");
	AddFileToDownloadsTable("models/unloze/crown_v2.dx90.vtx");
	AddFileToDownloadsTable("materials/models/unloze/crown/crown.vmt");
	AddFileToDownloadsTable("materials/models/unloze/crown/crown.vtf");
	AddFileToDownloadsTable("materials/models/unloze/crown/crown_bump.vtf");
	AddFileToDownloadsTable("materials/models/unloze/crown/crown_detail.vtf");
	AddFileToDownloadsTable("materials/models/unloze/crown/crown_lightwarp.vtf");

	GetTeams();
}

public void OnClientCookiesCached(int client)
{
	char sBuffer[4];
	GetClientCookie(client, g_hCookie_HideCrown, sBuffer, sizeof(sBuffer));

	if (sBuffer[0])
		g_bHideCrown[client] = true;
	else
		g_bHideCrown[client] = false;

	GetClientCookie(client, g_hCookie_HideDialog, sBuffer, sizeof(sBuffer));

	if (sBuffer[0])
		g_bHideDialog[client] = true;
	else
		g_bHideDialog[client] = false;

	GetClientCookie(client, g_hCookie_Protection, sBuffer, sizeof(sBuffer));

	if (sBuffer[0])
		g_bProtection[client] = true;
	else
		g_bProtection[client] = false;
}

public void OnClientDisconnect(int client)
{
	g_iPlayerDamage[client] = 0;

	g_bHideCrown[client]  = false;
	g_bHideDialog[client] = false;
	g_bProtection[client] = false;
}

public int SortDefendersList(int[] elem1, int[] elem2, const int[][] array, Handle hndl)
{
	if (elem1[1] > elem2[1]) return -1;
	if (elem1[1] < elem2[1]) return 1;

	return 0;
}

public Action UpdateScoreboard(Handle timer)
{
	int iSortedList[MAXPLAYERS+1][2];
	int iSortedCount;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;

		SetEntProp(client, Prop_Data, "m_iDeaths", 0);

		if (!g_iPlayerDamage[client])
			continue;

		iSortedList[iSortedCount][0] = client;
		iSortedList[iSortedCount][1] = g_iPlayerDamage[client];
		iSortedCount++;
	}

	SortCustom2D(iSortedList, iSortedCount, SortDefendersList);

	for (int rank = 0; rank < iSortedCount; rank++)
	{
		SetEntProp(iSortedList[rank][0], Prop_Data, "m_iDeaths", rank + 1);
	}
}

public Action UpdateDialog(Handle timer)
{
	if (g_iDialogLevel <= 0)
		return;

	int iSortedList[MAXPLAYERS+1][2];
	int iSortedCount;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !g_iPlayerDamage[client])
			continue;

		iSortedList[iSortedCount][0] = client;
		iSortedList[iSortedCount][1] = g_iPlayerDamage[client];
		iSortedCount++;
	}

	SortCustom2D(iSortedList, iSortedCount, SortDefendersList);

	for (int rank = 0; rank < iSortedCount; rank++)
	{
		switch(rank)
		{
			case(0): SendDialog(iSortedList[rank][0], "#%d (D: %d | P: -%d)",          g_iDialogLevel, 1, rank + 1, iSortedList[rank][1], iSortedList[rank][1] - iSortedList[rank + 1][1]);
			case(1): SendDialog(iSortedList[rank][0], "#%d (D: %d | N: +%d)",          g_iDialogLevel, 1, rank + 1, iSortedList[rank][1], iSortedList[rank - 1][1] - iSortedList[rank][1]);
			default: SendDialog(iSortedList[rank][0], "#%d (D: %d | N: +%d | F: +%d)", g_iDialogLevel, 1, rank + 1, iSortedList[rank][1], iSortedList[rank - 1][1] - iSortedList[rank][1], iSortedList[0][1] - iSortedList[rank][1]);
		}
	}

	g_iDialogLevel--;
}

public void OnRoundStart(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	g_iDialogLevel = 100000;

	for (int client = 1; client <= MaxClients; client++)
	{
		g_iPlayerDamage[client] = 0;
		g_iPlayerDamageFrom1K[client] = 0;
	}
}

public void OnRoundEnding(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	g_iPlayerWinner = {-1, -1, -1};

	int iSortedList[MAXPLAYERS+1][2];
	int iSortedCount;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !g_iPlayerDamage[client])
			continue;

		iSortedList[iSortedCount][0] = client;
		iSortedList[iSortedCount][1] = g_iPlayerDamage[client];
		iSortedCount++;
	}

	SortCustom2D(iSortedList, iSortedCount, SortDefendersList);

	for (int rank = 0; rank < iSortedCount; rank++)
	{
		LogMessage("%d - %L (%d)", rank + 1, iSortedList[rank][0], iSortedList[rank][1])
	}

	if (iSortedCount)
	{
		char sBuffer[512];
		Format(sBuffer, sizeof(sBuffer), "TOP DEFENDERS:");
		Format(sBuffer, sizeof(sBuffer), "%s\n*************************", sBuffer);

		if (iSortedList[0][0])
		{
			Format(sBuffer, sizeof(sBuffer), "%s\n1. %N - %d DMG", sBuffer, iSortedList[0][0], iSortedList[0][1]);
			LogPlayerEvent(iSortedList[0][0], "triggered", "top_defender");

			g_iPlayerWinner[0] = GetSteamAccountID(iSortedList[0][0]);
		}

		if (iSortedList[1][0])
		{
			Format(sBuffer, sizeof(sBuffer), "%s\n2. %N - %d DMG", sBuffer, iSortedList[1][0], iSortedList[1][1]);
			LogPlayerEvent(iSortedList[1][0], "triggered", "second_defender");

			g_iPlayerWinner[1] = GetSteamAccountID(iSortedList[1][0]);
		}

		if (iSortedList[2][0])
		{
			Format(sBuffer, sizeof(sBuffer), "%s\n3. %N - %d DMG", sBuffer, iSortedList[2][0], iSortedList[2][1]);
			LogPlayerEvent(iSortedList[2][0], "triggered", "third_defender");

			g_iPlayerWinner[2] = GetSteamAccountID(iSortedList[2][0]);
		}

		Format(sBuffer, sizeof(sBuffer), "%s\n*************************", sBuffer);

		Handle hMessage = StartMessageAll("HudMsg");
		if (hMessage)
		{
			if (GetUserMessageType() == UM_Protobuf)
			{
				PbSetInt(hMessage, "channel", 50);
				PbSetInt(hMessage, "effect", 0);
				PbSetColor(hMessage, "clr1", {255, 255, 255, 255});
				PbSetColor(hMessage, "clr2", {255, 255, 255, 255});
				PbSetVector2D(hMessage, "pos", Float:{0.02, 0.45});
				PbSetFloat(hMessage, "fade_in_time", 0.1);
				PbSetFloat(hMessage, "fade_out_time", 0.1);
				PbSetFloat(hMessage, "hold_time", 5.0);
				PbSetFloat(hMessage, "fx_time", 0.0);
				PbSetString(hMessage, "text", sBuffer);
				EndMessage();
			}
			else
			{
				BfWriteByte(hMessage, 50);
				BfWriteFloat(hMessage, 0.02);
				BfWriteFloat(hMessage, 0.25);
				BfWriteByte(hMessage, 0);
				BfWriteByte(hMessage, 128);
				BfWriteByte(hMessage, 255);
				BfWriteByte(hMessage, 255);
				BfWriteByte(hMessage, 255);
				BfWriteByte(hMessage, 255);
				BfWriteByte(hMessage, 255);
				BfWriteByte(hMessage, 255);
				BfWriteByte(hMessage, 0);
				BfWriteFloat(hMessage, 0.1);
				BfWriteFloat(hMessage, 0.1);
				BfWriteFloat(hMessage, 5.0);
				BfWriteFloat(hMessage, 0.0);
				BfWriteString(hMessage, sBuffer);
				EndMessage();
			}
		}

		PrintToChatAll(sBuffer);
	}
}

public void OnClientHurt(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("attacker"));
	int victim = GetClientOfUserId(hEvent.GetInt("userid"));

	if (client < 1 || client > MaxClients || victim < 1 || victim > MaxClients)
		return;

	if (client == victim || (IsPlayerAlive(client) && ZR_IsClientZombie(client)))
		return;

	int iDamage = hEvent.GetInt("dmg_health");

	g_iPlayerDamage[client] += iDamage;
	g_iPlayerDamageFrom1K[client] += iDamage;

	if (g_iPlayerDamageFrom1K[client] >= 1000)
	{
		g_iPlayerDamageFrom1K[client] -= 1000;
		LogPlayerEvent(client, "triggered", "damage_zombie");
	}
}

public void OnClientSpawn(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));

	if (g_iPlayerWinner[0] == GetSteamAccountID(client) && !g_bHideCrown[client])
	{
		CreateTimer(7.0, OnClientSpawnPost, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action OnClientSpawnPost(Handle timer, int client)
{
	if (!IsClientInGame(client) || IsFakeClient(client) || !IsPlayerAlive(client))
		return;

	if ((g_iCrownEntity = CreateEntityByName("prop_dynamic")) == INVALID_ENT_REFERENCE)
		return;

	SetEntityModel(g_iCrownEntity, "models/unloze/crown_v2.mdl");

	DispatchKeyValue(g_iCrownEntity, "solid",                 "0");
	DispatchKeyValue(g_iCrownEntity, "modelscale",            "1.5");
	DispatchKeyValue(g_iCrownEntity, "disableshadows",        "1");
	DispatchKeyValue(g_iCrownEntity, "disablereceiveshadows", "1");
	DispatchKeyValue(g_iCrownEntity, "disablebonefollowers",  "1");

	float fVector[3];
	float fAngles[3];
	GetClientAbsOrigin(client, fVector);
	GetClientAbsAngles(client, fAngles);

	fVector[2] += 80.0;
	fAngles[0] = 8.0;
	fAngles[2] = 5.5;

	TeleportEntity(g_iCrownEntity, fVector, fAngles, NULL_VECTOR);

	float fDirection[3];
	fDirection[0] = 0.0;
	fDirection[1] = 0.0;
	fDirection[2] = 1.0;

	TE_SetupSparks(fVector, fDirection, 1000, 200);
	TE_SendToAll();

	SetVariantString("!activator");
	AcceptEntityInput(g_iCrownEntity, "SetParent", client);
}

public void OnClientDeath(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));

	if (g_iPlayerWinner[0] == GetSteamAccountID(client) && !IsPlayerAlive(client))
	{
		if (g_iCrownEntity != INVALID_ENT_REFERENCE && AcceptEntityInput(g_iCrownEntity, "Kill"))
		{
			g_iCrownEntity = INVALID_ENT_REFERENCE;
		}
	}
}

public Action ZR_OnClientInfect(&client, &attacker, &bool:motherInfect, &bool:respawnOverride, &bool:respawn)
{
	if (g_hCVar_Protection.BoolValue && motherInfect && !g_bProtection[client])
	{
		if ((g_iPlayerWinner[0] == GetSteamAccountID(client) && GetClientCount() >= g_hCVar_ProtectionMinimal1.IntValue) ||
			(g_iPlayerWinner[1] == GetSteamAccountID(client) && GetClientCount() >= g_hCVar_ProtectionMinimal2.IntValue) ||
			(g_iPlayerWinner[2] == GetSteamAccountID(client) && GetClientCount() >= g_hCVar_ProtectionMinimal3.IntValue))
		{
			Handle hMessageInfection = StartMessageOne("HudMsg", client);
			if (hMessageInfection)
			{
				if (GetUserMessageType() == UM_Protobuf)
				{
					PbSetInt(hMessageInfection, "channel", 50);
					PbSetInt(hMessageInfection, "effect", 0);
					PbSetColor(hMessageInfection, "clr1", {255, 255, 255, 255});
					PbSetColor(hMessageInfection, "clr2", {255, 255, 255, 255});
					PbSetVector2D(hMessageInfection, "pos", Float:{-1.0, 0.3});
					PbSetFloat(hMessageInfection, "fade_in_time", 0.1);
					PbSetFloat(hMessageInfection, "fade_out_time", 0.1);
					PbSetFloat(hMessageInfection, "hold_time", 5.0);
					PbSetFloat(hMessageInfection, "fx_time", 0.0);
					PbSetString(hMessageInfection, "text", "You have been protected from being Mother Zombie\nsince you were the Top Defender last round!");
					EndMessage();
				}
				else
				{
					BfWriteByte(hMessageInfection, 50);
					BfWriteFloat(hMessageInfection, -1.0);
					BfWriteFloat(hMessageInfection, 0.3);
					BfWriteByte(hMessageInfection, 0);
					BfWriteByte(hMessageInfection, 255);
					BfWriteByte(hMessageInfection, 255);
					BfWriteByte(hMessageInfection, 255);
					BfWriteByte(hMessageInfection, 255);
					BfWriteByte(hMessageInfection, 255);
					BfWriteByte(hMessageInfection, 255);
					BfWriteByte(hMessageInfection, 255);
					BfWriteByte(hMessageInfection, 0);
					BfWriteFloat(hMessageInfection, 0.1);
					BfWriteFloat(hMessageInfection, 0.1);
					BfWriteFloat(hMessageInfection, 5.0);
					BfWriteFloat(hMessageInfection, 0.0);
					BfWriteString(hMessageInfection, "You have been protected from being Mother Zombie\nsince you were the Top Defender last round!");
					EndMessage();
				}
			}

			CPrintToChat(client, "{cyan}%t {white}%s", "Chat Prefix", "You have been protected from being Mother Zombie since you were the Top Defender last round!");

			EmitSoundToClient(client, "unloze/holy.wav", .volume=1.0);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

void AddMenuItemTranslated(Menu menu, const char[] info, const char[] display, any ...)
{
	char buffer[128];
	VFormat(buffer, sizeof(buffer), display, 4);

	menu.AddItem(info, buffer);
}

void SendDialog(int client, const char[] display, const int level, const int time, any ...)
{
	char buffer[128];
	VFormat(buffer, sizeof(buffer), display, 5);

	KeyValues kv = new KeyValues("dialog", "title", buffer);
	kv.SetColor("color", 255, 255, 255, 255);
	kv.SetNum("level", level);
	kv.SetNum("time", time);

	if (!g_bHideDialog[client])
	{
		CreateDialog(client, kv, DialogType_Msg);
	}

	for (int spec = 1; spec <= MaxClients; spec++)
	{
		if (!IsClientInGame(spec) || !IsClientObserver(spec) || g_bHideDialog[spec])
			continue;

		int specMode   = GetClientSpectatorMode(spec);
		int specTarget = GetClientSpectatorTarget(spec);

		if ((specMode == SPECMODE_FIRSTPERSON || specMode == SPECMODE_THIRDPERSON) && specTarget == client)
		{
			CreateDialog(spec, kv, DialogType_Msg);
		}
	}

	delete kv;
}

int GetClientSpectatorMode(int client)
{
	return GetEntProp(client, Prop_Send, "m_iObserverMode");
}

int GetClientSpectatorTarget(int client)
{
	return GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
}
