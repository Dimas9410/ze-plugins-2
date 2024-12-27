#include <clientprefs>
#include <multicolors>
#include <sourcemod>
#include <sdktools>
#include <zombiereloaded>

/* BOOLS */
bool g_bHideProp[MAXPLAYERS+1];
bool g_bProtection[MAXPLAYERS+1];

/* COOKIES */
Handle g_hCookie_HideProp;
Handle g_hCookie_Protection;

/* CONVARS */
ConVar g_hCVar_Protection;
ConVar g_hCVar_ProtectionMinimal;

/* INTERGERS */
int g_iPropEntity = -1;
int g_iRotatingEntity = -1;

/* STRINGS */
char g_sSTEAM_ID_Winner[64];

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin myinfo =
{
	name         = "Ranking",
	author       = "Neon",
	description  = "",
	version      = "1.0.0",
	url 		 = "https://steamcommunity.com/id/n3ontm"
};

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnPluginStart()
{
	g_hCookie_HideProp  = RegClientCookie("ranking_hideprop",  "", CookieAccess_Private);
	g_hCookie_Protection = RegClientCookie("ranking_protection", "", CookieAccess_Private);

	g_hCVar_Protection         = CreateConVar("sm_ranking_protection_enabled", "1", "", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCVar_ProtectionMinimal = CreateConVar("sm_ranking_protection_minimal", "15", "", FCVAR_NONE, true, 1.0, true, 64.0);

	RegConsoleCmd("sm_toggleprop", OnToggleProp);
	RegConsoleCmd("sm_top1", OnToggleImmunity);

	HookEvent("player_spawn", OnClientSpawn);
	HookEvent("player_death", OnClientDeath);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action OnToggleProp(int client, int args)
{
	g_bHideProp[client] = !g_bHideProp[client];

	SetClientCookie(client, g_hCookie_HideProp, g_bHideProp[client] ? "1" : "");

	CPrintToChat(client, "{cyan}[Ranking] {white}%s", g_bHideProp[client] ? "Prop Disabled" : "Prop Enabled");

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action OnToggleImmunity(int client, int args)
{
	g_bProtection[client] = !g_bProtection[client];

	SetClientCookie(client, g_hCookie_Protection, g_bProtection[client] ? "1" : "");

	CPrintToChat(client, "{cyan}[Ranking] {white}%s", g_bProtection[client] ? "Immunity Disabled" : "Immunity Enabled");

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnMapStart()
{
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

	PrecacheModel("models/unloze/crown_v2.mdl");

	AddFileToDownloadsTable("sound/unloze/holy.wav");
	PrecacheSound("unloze/holy.wav");

	GetSteamID();
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void GetSteamID()
{
	char sFile[PLATFORM_MAX_PATH];
	char sLine[192];

	BuildPath(Path_SM, sFile, sizeof(sFile), "configs/ranking/winner.cfg");
	Handle hFile = OpenFile(sFile, "r");

	if(hFile != INVALID_HANDLE)
	{
		while (!IsEndOfFile(hFile))
		{
			if (!ReadFileLine(hFile, sLine, sizeof(sLine)))
				break;

			TrimString(sLine);
			if(strlen(sLine) > 0 && (StrContains(sLine, "STEAM") != -1))
			{
				Format(g_sSTEAM_ID_Winner, sizeof(g_sSTEAM_ID_Winner), "%s", sLine);
				//PrintToChatAll("%s", g_sSTEAM_ID_Winner);
				break;
			}
		}
		CloseHandle(hFile);
	}
	else
	{
		LogError("[SM] File not found! (configs/ranking/winner.cfg)");
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnClientCookiesCached(int client)
{
	char sBuffer[4];
	GetClientCookie(client, g_hCookie_HideProp, sBuffer, sizeof(sBuffer));

	if (sBuffer[0])
		g_bHideProp[client] = true;
	else
		g_bHideProp[client] = false;

}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnClientDisconnect(int client)
{
	g_bHideProp[client]  = false;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnClientSpawn(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));

	char sSID[64];
	GetClientAuthId(client, AuthId_Steam2, sSID, sizeof(sSID));

	if (StrEqual(sSID, g_sSTEAM_ID_Winner) && !g_bHideProp[client])
	{
		CreateTimer(1.0, OnClientSpawnPost, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action OnClientSpawnPost(Handle timer, int client)
{
	if (!IsClientInGame(client) || IsFakeClient(client) || !IsPlayerAlive(client))
		return;

	if ((g_iPropEntity = CreateEntityByName("prop_dynamic")) == INVALID_ENT_REFERENCE)
		return;

	SetEntityModel(g_iPropEntity, "models/unloze/crown_v2.mdl");

	DispatchKeyValue(g_iPropEntity, "solid",                 "0");
	DispatchKeyValue(g_iPropEntity, "modelscale",            "1.5");
	DispatchKeyValue(g_iPropEntity, "disableshadows",        "1");
	DispatchKeyValue(g_iPropEntity, "disablereceiveshadows", "1");
	DispatchKeyValue(g_iPropEntity, "disablebonefollowers",  "1");

	float fVector[3];
	float fAngles[3];
	GetClientAbsOrigin(client, fVector);
	GetClientAbsAngles(client, fAngles);

	fVector[2] += 80.0;
	fAngles[0] = 8.0;
	fAngles[2] = 5.5;

	TeleportEntity(g_iPropEntity, fVector, fAngles, NULL_VECTOR);

	float fDirection[3];
	fDirection[0] = 0.0;
	fDirection[1] = 0.0;
	fDirection[2] = 1.0;

	TE_SetupSparks(fVector, fDirection, 1000, 200);
	TE_SendToAll();

	SetVariantString("!activator");
	AcceptEntityInput(g_iPropEntity, "SetParent", client);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnClientDeath(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));

	char sSID[64];
	GetClientAuthId(client, AuthId_Steam2, sSID, sizeof(sSID));

	if (StrEqual(sSID, g_sSTEAM_ID_Winner) && !IsPlayerAlive(client))
	{
		if (g_iPropEntity != INVALID_ENT_REFERENCE && AcceptEntityInput(g_iPropEntity, "Kill"))
		{
			g_iPropEntity = INVALID_ENT_REFERENCE;
		}

		if (g_iRotatingEntity != INVALID_ENT_REFERENCE && AcceptEntityInput(g_iRotatingEntity, "Kill"))
		{
			g_iRotatingEntity = INVALID_ENT_REFERENCE;
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action ZR_OnClientInfect(&client, &attacker, &bool:motherInfect, &bool:respawnOverride, &bool:respawn)
{
	if (g_hCVar_Protection.BoolValue && motherInfect && !g_bProtection[client])
	{
		char sSID[64];
		GetClientAuthId(client, AuthId_Steam2, sSID, sizeof(sSID));

		if ((GetClientCount() >= g_hCVar_ProtectionMinimal.IntValue) && StrEqual(sSID, g_sSTEAM_ID_Winner))
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
					PbSetString(hMessageInfection, "text", "You have been protected from being Mother Zombie\nsince you were the Rank #1 Player last Month!");
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
					BfWriteString(hMessageInfection, "You have been protected from being Mother Zombie\nsince you were the Rank #1 Player last Month!");
					EndMessage();
				}
			}

			CPrintToChat(client, "{cyan}[Ranking] {white}You have been protected from being Mother Zombie since he was the Rank #1 Player last Month!");

			EmitSoundToClient(client, "unloze/holy.wav", .volume=1.0);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}
