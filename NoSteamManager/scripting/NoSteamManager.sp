#pragma semicolon 1

#include <sourcemod>
#include <basecomm>
#include <connect>
#include <regex>

#pragma newdecls required

/* CONVARS */
ConVar g_hCvar_BlockAdmin;
ConVar g_hCvar_BlockVoice;
ConVar g_hCvar_BlockSpoof;

/* REGEX */
Regex g_hReg_ValidateSteamID;

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin myinfo =
{
	name         = "NoSteamManager",
	author       = "zaCade",
	description  = "Manage No-Steam clients, denying admin access, ect.",
	version      = "1.0.0"
};

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnPluginStart()
{
	g_hReg_ValidateSteamID = CompileRegex("[^STEAM_[01]:[01]:\\d{1,10}]");

	g_hCvar_BlockAdmin = CreateConVar("sm_nosteam_block_admin", "1", "Should people marked as nosteam be blocked from admin?", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCvar_BlockVoice = CreateConVar("sm_nosteam_block_voice", "1", "Should people marked as nosteam be blocked from voice?", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCvar_BlockSpoof = CreateConVar("sm_nosteam_block_spoof", "1", "Block nosteam people being able to spoof steamids.",     FCVAR_NONE, true, 0.0, true, 1.0);

	AddMultiTargetFilter("@steam", Filter_Steam, "Steam Players", false);
	AddMultiTargetFilter("@nosteam", Filter_NoSteam, "No-Steam Players", false);

	RegConsoleCmd("sm_nosteam", Command_DisplaySteamStats, "Shows the number of Steam and No-Steam players");
	RegConsoleCmd("sm_steam", Command_DisplaySteamStats, "Shows the number of Steam and No-Steam players");

	AutoExecConfig();
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnPluginEnd()
{
	RemoveMultiTargetFilter("@steam", Filter_Steam);
	RemoveMultiTargetFilter("@nosteam", Filter_NoSteam);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Command_DisplaySteamStats(int client, int args)
{
	char aBuf[1024];
	char aBuf2[MAX_NAME_LENGTH];

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			char sSteamID[32];
			GetClientAuthId(i, AuthId_Steam2, sSteamID, sizeof(sSteamID));

			if(!SteamClientAuthenticated(sSteamID))
			{
				GetClientName(i, aBuf2, sizeof(aBuf2));
				StrCat(aBuf, sizeof(aBuf), aBuf2);
				StrCat(aBuf, sizeof(aBuf), ", ");
			}
		}
	}

	if(strlen(aBuf))
	{
		aBuf[strlen(aBuf) - 2] = 0;
		ReplyToCommand(client, "[SM] No-Steam clients online: %s", aBuf);
	}
	else
		ReplyToCommand(client, "[SM] No-Steam clients online: none");

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public bool Filter_Steam(const char[] sPattern, Handle hClients)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			char sSteamID[32];
			GetClientAuthId(i, AuthId_Steam2, sSteamID, sizeof(sSteamID));

			if(SteamClientAuthenticated(sSteamID))
				PushArrayCell(hClients, i);
		}
	}
	return true;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public bool Filter_NoSteam(const char[] sPattern, Handle hClients)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			char sSteamID[32];
			GetClientAuthId(i, AuthId_Steam2, sSteamID, sizeof(sSteamID));

			if(!SteamClientAuthenticated(sSteamID))
				PushArrayCell(hClients, i);
		}
	}
	return true;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action OnClientPreAdminCheck(int client)
{
	if(!g_hCvar_BlockAdmin.BoolValue)
		return Plugin_Continue;

	if(IsFakeClient(client) || IsClientSourceTV(client))
		return Plugin_Continue;

	char sSteamID[32];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));

	if(!SteamClientAuthenticated(sSteamID))
	{
		LogMessage("%L was not authenticated with steam, denying admin.", client);
		NotifyPostAdminCheck(client);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnClientPostAdminCheck(int client)
{
	if(!g_hCvar_BlockVoice.BoolValue)
		return;

	if(IsFakeClient(client) || IsClientSourceTV(client))
		return;

	char sSteamID[32];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));

	if(!SteamClientAuthenticated(sSteamID))
	{
		LogMessage("%L was not authenticated with steam, muting client.", client);
		BaseComm_SetClientMute(client, true);

		return;
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnClientPutInServer(int client)
{
	if(!g_hCvar_BlockSpoof.BoolValue)
		return;

	if(IsFakeClient(client) || IsClientSourceTV(client))
		return;

	char sSteamID[32];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));

	if(MatchRegex(g_hReg_ValidateSteamID, sSteamID) <= 0)
		return;

	for(int player = 1; player <= MaxClients; player++)
	{
		if(client == player || !IsClientConnected(player))
			continue;

		if(IsFakeClient(player) || IsClientSourceTV(player))
			continue;

		char sPlayerSteamID[32];
		GetClientAuthId(player, AuthId_Steam2, sPlayerSteamID, sizeof(sPlayerSteamID));

		if(MatchRegex(g_hReg_ValidateSteamID, sPlayerSteamID) <= 0)
			continue;

		if(StrEqual(sSteamID, sPlayerSteamID, false))
		{
			if(!SteamClientAuthenticated(sSteamID))
			{
				LogMessage("%L was not authenticated with steam, steamid already connected. Kicking connector.", client);
				KickClient(client, "Please come back later.");

				return;
			}

			if(!SteamClientAuthenticated(sPlayerSteamID))
			{
				LogMessage("%L was not authenticated with steam, steamid already connected. Kicking connected.", player);
				KickClient(player, "Please come back later.");

				return;
			}

			break;
		}
	}
}
