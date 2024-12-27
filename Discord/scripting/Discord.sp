#pragma semicolon 1

#include <basecomm>
#include <sourcemod>
#include <SteamWorks>
#include <regex>
#include <smjansson>
#include "sdktools_functions.inc"

#include <AntiBhopCheat>
#include <entWatch>

#pragma newdecls required

#include "SteamAPI.secret" // #define STEAM_API_KEY "<key>"
#include "Discord.secret" // #define DISCORD_*

Regex g_Regex_Clyde = null;

ConVar g_Cvar_HostIP = null;
ConVar g_Cvar_HostPort = null;
ConVar g_Cvar_HostName = null;

ArrayList g_arrQueuedMessages = null;

Handle g_hDataTimer = null;
Handle g_hReplaceConfigFile = null;

UserMsg g_umSayText2 = INVALID_MESSAGE_ID;

bool g_bLoadedLate;
bool g_bTimerDone;
bool g_bProcessingData;
bool g_bGotReplaceFile;
bool g_bTeamChat;

char g_sReplacePath[PLATFORM_MAX_PATH];
char g_sAvatarURL[MAXPLAYERS + 1][128];

int g_iPlayersAtPOST = 0;
int g_iRatelimitRemaining = 5;
int g_iRatelimitReset;

float g_fReportCooldown[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name 		= "Discord core",
	author 		= "Obus",
	description = "Implements live chat and map reporting for Discord.",
	version 	= "1.1.0",
	url 		= ""
}

public APLRes AskPluginLoad2(Handle hThis, bool bLate, char[] sError, int err_max)
{
	g_bLoadedLate = bLate;

	return APLRes_Success;
}

public void OnPluginStart()
{
	char sRegexErr[32];
	RegexError RegexErr;

	g_Regex_Clyde = CompileRegex(".*(clyde).*", PCRE_CASELESS, sRegexErr, sizeof(sRegexErr), RegexErr);

	if (RegexErr != REGEX_ERROR_NONE)
		LogError("Could not compile \"Clyde\" regex (err: %s)", sRegexErr);

	g_hReplaceConfigFile = CreateKeyValues("AutoReplace");
	BuildPath(Path_SM, g_sReplacePath, sizeof(g_sReplacePath), "configs/custom-chatcolorsreplace.cfg");

	if (FileToKeyValues(g_hReplaceConfigFile, g_sReplacePath))
		g_bGotReplaceFile = true;

	g_arrQueuedMessages = CreateArray(ByteCountToCells(1024));

	g_hDataTimer = CreateTimer(0.333, Timer_DataProcessor, INVALID_HANDLE, TIMER_REPEAT);

	g_Cvar_HostIP = FindConVar("hostip");
	g_Cvar_HostPort = FindConVar("hostport");
	g_Cvar_HostName = FindConVar("hostname");

	g_umSayText2 = GetUserMessageId("SayText2");

	if (g_umSayText2 == INVALID_MESSAGE_ID)
		SetFailState("This game doesn't support SayText2 user messages.");

	HookUserMessage(g_umSayText2, Hook_UserMessage, false);

	HookEvent("player_say", EventHook_PlayerSay, EventHookMode_Post);

	AddCommandListener(CommandListener_SmChat, "sm_chat");

	RegConsoleCmd("sm_report", Command_Report);

	if (g_bLoadedLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientAuthorized(i))
				continue;

			static char sAuthID32[32];

			GetClientAuthId(i, AuthId_Steam2, sAuthID32, sizeof(sAuthID32));
			OnClientAuthorized(i, sAuthID32);
		}
	}
}

public void OnPluginEnd()
{
	delete g_arrQueuedMessages;
	delete g_hDataTimer;

	UnhookUserMessage(g_umSayText2, Hook_UserMessage, false);
	UnhookEvent("player_say", EventHook_PlayerSay, EventHookMode_Post);
}

public void OnClientPutInServer(int client)
{
	g_fReportCooldown[client] = 0.0;

	if (!g_bTimerDone)
		return;

	int iClientCount = GetClientCount(false);

	if (iClientCount >= g_iPlayersAtPOST+10)
		FormatStatusAndPOST(g_iPlayersAtPOST = iClientCount);
}

public void OnClientAuthorized(int client, const char[] sAuthID32)
{
	if (IsFakeClient(client))
		return;

	char sAuthID64[32];

	if (!Steam32IDtoSteam64ID(sAuthID32, sAuthID64, sizeof(sAuthID64)))
		return;

	static char sRequest[256];

	FormatEx(sRequest, sizeof(sRequest), "http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=%s&steamids=%s&format=vdf", STEAM_API_KEY, sAuthID64);

	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, sRequest);

	if (!hRequest ||
		!SteamWorks_SetHTTPRequestContextValue(hRequest, client) ||
		!SteamWorks_SetHTTPCallbacks(hRequest, OnTransferComplete) ||
		!SteamWorks_SendHTTPRequest(hRequest))
	{
		delete hRequest;
	}
}

public void OnMapStart()
{
	g_bTimerDone = false;
	CreateTimer(10.0, Timer_OnMapStart);
}

public Action Timer_OnMapStart(Handle hThis)
{
	g_bTimerDone = true;
	FormatStatusAndPOST(g_iPlayersAtPOST = GetClientCount(false));
}

public Action Timer_DataProcessor(Handle hThis)
{
	if (!g_bProcessingData)
		return;

	if (g_iRatelimitRemaining == 0 && GetTime() < g_iRatelimitReset)
		return;

	//PrintToServer("[Timer_DataProcessor] Array Length #1: %d", g_arrQueuedMessages.Length);

	char sContent[1024];
	g_arrQueuedMessages.GetString(0, sContent, sizeof(sContent));
	g_arrQueuedMessages.Erase(0);

	char sURL[128];
	g_arrQueuedMessages.GetString(0, sURL, sizeof(sURL));
	g_arrQueuedMessages.Erase(0);

	if (g_arrQueuedMessages.Length == 0)
		g_bProcessingData = false;

	//PrintToServer("[Timer_DataProcessor] Array Length #2: %d", g_arrQueuedMessages.Length);

	//PrintToServer("%s | %s", sURL, sContent);

	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, sURL);

	JSONObject RequestJSON = view_as<JSONObject>(json_load(sContent));

	if (!hRequest ||
		!SteamWorks_SetHTTPRequestContextValue(hRequest, RequestJSON) ||
		!SteamWorks_SetHTTPCallbacks(hRequest, OnHTTPRequestCompleted) ||
		!SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/json", sContent, strlen(sContent)) ||
		!SteamWorks_SetHTTPRequestNetworkActivityTimeout(hRequest, 10) ||
		!SteamWorks_SendHTTPRequest(hRequest))
	{
		LogError("Discord SteamWorks_CreateHTTPRequest failed.");

		delete RequestJSON;
		delete hRequest;

		return;
	}
}

public void FormatStatusAndPOST(int iCurrentClients)
{
	char sFinal[512];
	char sCurrentMap[32];
	char sServerName[64];
	int iServerIP = g_Cvar_HostIP.IntValue;
	int iServerPort = g_Cvar_HostPort.IntValue;

	GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));
	g_Cvar_HostName.GetString(sServerName, sizeof(sServerName));

	char sTitle[64];
	char sDescription[256];

	strcopy(sTitle, sizeof(sTitle), sServerName);
	Format(sDescription, sizeof(sDescription), "Current Map: **%s**\nCurrent Players: **%d/%d**\nQuick Join: **steam://connect/%d.%d.%d.%d:%d**",
	sCurrentMap, iCurrentClients, MaxClients, iServerIP >>> 24 & 255, iServerIP >>> 16 & 255, iServerIP >>> 8 & 255, iServerIP & 255, iServerPort);

	JSONRootNode hJSONFinal = new JSONObject();
	JSONObject hEmbeds = new JSONObject();
	JSONArray arrEmbeds = new JSONArray();

	(view_as<JSONObject>(hJSONFinal)).SetString("username", "MapInfo");
	hEmbeds.SetInt("color", 0xFF0000);
	hEmbeds.SetString("title", sTitle);
	hEmbeds.SetString("description", sDescription);
	arrEmbeds.Append(hEmbeds);
	(view_as<JSONObject>(hJSONFinal)).Set("embeds", arrEmbeds);

	//hJSONFinal.DumpToServer();

	hJSONFinal.ToString(sFinal, sizeof(sFinal), 0);

	HTTPPostJSON(DISCORD_MAPWEBHOOK_URL, sFinal);

	delete hJSONFinal;
}

public Action Hook_UserMessage(UserMsg msg_id, Handle bf, const players[], int playersNum, bool reliable, bool init)
{
	char sMessageName[32];
	char sMessageSender[64];
	int iAuthor = BfReadByte(bf);
	bool bIsChat = view_as<bool>(BfReadByte(bf)); if (bIsChat) bIsChat=false; //fucking compiler shut the fuck up REEEEEE
	BfReadString(bf, sMessageName, sizeof(sMessageName), false);
	BfReadString(bf, sMessageSender, sizeof(sMessageSender), false);

	if (iAuthor <= 0 || iAuthor > MaxClients)
		return;

	if (strlen(sMessageName) == 0 || strlen(sMessageSender) == 0)
		return;

	if (strcmp(sMessageName, "#Cstrike_Name_Change") == 0)
		return;

	if (sMessageName[13] == 'C' || sMessageName[13] == 'T' || sMessageName[13] == 'S')
		g_bTeamChat = true;
	else
		g_bTeamChat = false;
}

public void EventHook_PlayerSay(Event hThis, const char[] sName, bool bDontBroadcast)
{
	int iUserID = GetEventInt(hThis, "userid");
	int iClient = GetClientOfUserId(iUserID);
	char sMessageText[192];

	GetEventString(hThis, "text", sMessageText, sizeof(sMessageText));

	//PrintToServer("[EventHook_PlayerSay] Fired for %N: %s", iClient, sMessageText);

	TrimString(sMessageText);

	if (strlen(sMessageText) == 0)
		return;

	char sClientName[64];

	GetClientName(iClient, sClientName, sizeof(sClientName));

	if (g_bGotReplaceFile)
	{
		char sPart[192];
		char sBuff[192];
		int CurrentIndex = 0;
		int NextIndex = 0;

		while(NextIndex != -1 && CurrentIndex < sizeof(sMessageText))
		{
			NextIndex = BreakString(sMessageText[CurrentIndex], sPart, sizeof(sPart));

			KvGetString(g_hReplaceConfigFile, sPart, sBuff, sizeof(sBuff), NULL_STRING);

			if(sBuff[0])
			{
				ReplaceString(sMessageText[CurrentIndex], sizeof(sMessageText) - CurrentIndex, sPart, sBuff);
				CurrentIndex += strlen(sBuff);
			}
			else
				CurrentIndex += NextIndex;
		}
	}

	if (g_bTeamChat)
	{
		if (sMessageText[0] == '@')
			return;

		char sMessageFinal[256];
		char sTeamName[32];

		GetTeamName(GetClientTeam(iClient), sTeamName, sizeof(sTeamName));

		if (sTeamName[0] == 'C')
			Format(sMessageFinal, sizeof(sMessageFinal), "(Counter-Terrorist) %s", sMessageText);
		else if (sTeamName[0] == 'T')
			Format(sMessageFinal, sizeof(sMessageFinal), "(Terrorist) %s", sMessageText);
		else
			Format(sMessageFinal, sizeof(sMessageFinal), "(Spectator) %s", sMessageText);

		if (g_sAvatarURL[iClient][0] != '\0')
			Discord_POST(DISCORD_LIVEWEBHOOK_URL, sMessageFinal, true, sClientName, true, g_sAvatarURL[iClient]);
		else
			Discord_POST(DISCORD_LIVEWEBHOOK_URL, sMessageFinal, true, sClientName);

		return;
	}

	if (g_sAvatarURL[iClient][0] != '\0')
		Discord_POST(DISCORD_LIVEWEBHOOK_URL, sMessageText, true, sClientName, true, g_sAvatarURL[iClient]);
	else
		Discord_POST(DISCORD_LIVEWEBHOOK_URL, sMessageText, true, sClientName);
}

stock bool Steam32IDtoSteam64ID(const char[] sSteam32ID, char[] sSteam64ID, int Size)
{
	if (strlen(sSteam32ID) < 11 || strncmp(sSteam32ID[0], "STEAM_0:", 8) || strcmp(sSteam32ID, "STEAM_ID_PENDING") == 0)
	{
		sSteam64ID[0] = 0;
		return false;
	}

	int iUpper = 765611979;
	int isSteam64ID = StringToInt(sSteam32ID[10]) * 2 + 60265728 + sSteam32ID[8] - 48;

	int iDiv = isSteam64ID / 100000000;
	int iIdx = 9 - (iDiv ? (iDiv / 10 + 1) : 0);
	iUpper += iDiv;

	IntToString(isSteam64ID, sSteam64ID[iIdx], Size - iIdx);
	iIdx = sSteam64ID[9];
	IntToString(iUpper, sSteam64ID, Size);
	sSteam64ID[9] = iIdx;

	return true;
}

stock void Discord_MakeStringSafe(const char[] sOrigin, char[] sOut, int iOutSize)
{
	int iDataLen = strlen(sOrigin);
	int iCurIndex;

	for (int i = 0; i < iDataLen && iCurIndex < iOutSize; i++)
	{
		if (sOrigin[i] < 0x20 && sOrigin[i] != 0x0)
		{
			//sOut[iCurIndex] = 0x20;
			//iCurIndex++;
			continue;
		}

		switch (sOrigin[i])
		{
			// case '"':
			// {
				// strcopy(sOut[iCurIndex], iOutSize, "\\u0022");
				// iCurIndex += 6;

				// continue;
			// }
			// case '\\':
			// {
				// strcopy(sOut[iCurIndex], iOutSize, "\\u005C");
				// iCurIndex += 6;

				// continue;
			// }
			case '@':
			{
				strcopy(sOut[iCurIndex], iOutSize, "@​"); //@ + zero-width space
				iCurIndex += 4;

				continue;
			}
			case '`':
			{
				strcopy(sOut[iCurIndex], iOutSize, "\\`");
				iCurIndex += 2;

				continue;
			}
			case '_':
			{
				strcopy(sOut[iCurIndex], iOutSize, "\\_");
				iCurIndex += 2;

				continue;
			}
			case '~':
			{
				strcopy(sOut[iCurIndex], iOutSize, "\\~");
				iCurIndex += 2;

				continue;
			}
			default:
			{
				sOut[iCurIndex] = sOrigin[i];
				iCurIndex++;
			}
		}
	}
}

stock int OnTransferComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int client)
{
	if (bFailure || !bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		if (eStatusCode != k_EHTTPStatusCode429TooManyRequests)
			LogError("SteamAPI HTTP Response failed: %d", eStatusCode);

		delete hRequest;
		return;
	}

	int iBodyLength;
	SteamWorks_GetHTTPResponseBodySize(hRequest, iBodyLength);

	char[] sData = new char[iBodyLength];
	SteamWorks_GetHTTPResponseBodyData(hRequest, sData, iBodyLength);

	delete hRequest;

	APIWebResponse(sData, client);
}

stock void APIWebResponse(const char[] sData, int client)
{
	KeyValues kvResponse = new KeyValues("SteamAPIResponse");

	if (!kvResponse.ImportFromString(sData, "SteamAPIResponse"))
	{
		LogError("kvResponse.ImportFromString(\"SteamAPIResponse\") in APIWebResponse failed.");

		delete kvResponse;
		return;
	}

	if (!kvResponse.JumpToKey("players"))
	{
		LogError("kvResponse.JumpToKey(\"players\") in APIWebResponse failed.");

		delete kvResponse;
		return;
	}

	if (!kvResponse.GotoFirstSubKey())
	{
		LogError("kvResponse.GotoFirstSubKey() in APIWebResponse failed.");

		delete kvResponse;
		return;
	}

	kvResponse.GetString("avatarfull", g_sAvatarURL[client], sizeof(g_sAvatarURL[]));

	delete kvResponse;
}

stock void HTTPPostJSON(const char[] sURL, const char[] sText)
{
	// if (g_iRatelimitRemaining > 0 && !g_bProcessingData && GetTime() < g_iRatelimitReset)
	// {
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, sURL);

	JSONObject RequestJSON = view_as<JSONObject>(json_load(sText));

	if (!hRequest ||
		!SteamWorks_SetHTTPRequestContextValue(hRequest, RequestJSON) ||
		!SteamWorks_SetHTTPCallbacks(hRequest, OnHTTPRequestCompleted) ||
		!SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/json", sText, strlen(sText)) ||
		!SteamWorks_SetHTTPRequestNetworkActivityTimeout(hRequest, 15) ||
		!SteamWorks_SendHTTPRequest(hRequest))
	{
		LogError("Discord SteamWorks_CreateHTTPRequest failed.");

		delete RequestJSON;
		delete hRequest;

		return;
	}
	// }
	// else
	// {
		// g_arrQueuedMessages.PushString(sText);
		// g_arrQueuedMessages.PushString(sURL);
		// g_bProcessingData = true;
	// }

	//delete hRequest;
}

stock void Discord_POST(const char[] sURL, char[] sText, bool bUsingUsername=false, char[] sUsername=NULL_STRING, bool bUsingAvatar=false, char[] sAvatarURL=NULL_STRING, bool bSafe=true, bool bTimestamp=true)
{
	//PrintToServer("[Discord_POST] Called with text: %s", sText);

	if (bTimestamp)
	{
		int iTime = GetTime();
		char sTime[32];
		FormatTime(sTime, sizeof(sTime), "%r", iTime);
		Format(sText, 2048, "[%s] %s", sTime, sText);
	}

	JSONRootNode hJSONRoot = new JSONObject();
	char sSafeText[4096];
	char sFinal[4096];

	if (bUsingUsername)
	{
		TrimString(sUsername);

		if (g_Regex_Clyde.Match(sUsername) > 0 || strlen(sUsername) < 2)
			(view_as<JSONObject>(hJSONRoot)).SetString("username", "Invalid Name");
		else
			(view_as<JSONObject>(hJSONRoot)).SetString("username", sUsername);
	}

	if (bUsingAvatar)
		(view_as<JSONObject>(hJSONRoot)).SetString("avatar_url", sAvatarURL);

	if (bSafe)
	{
		Discord_MakeStringSafe(sText, sSafeText, sizeof(sSafeText));
	}
	else
	{
		Format(sSafeText, sizeof(sSafeText), "%s", sText);
	}

	(view_as<JSONObject>(hJSONRoot)).SetString("content", sSafeText);
	(view_as<JSONObject>(hJSONRoot)).ToString(sFinal, sizeof(sFinal), 0);

	//hJSONRoot.DumpToServer();

	delete hJSONRoot;

	if ((g_iRatelimitRemaining > 0 || GetTime() >= g_iRatelimitReset) && !g_bProcessingData)
	{
		//PrintToServer("[Discord_POST] Have allowances and not processing data");

		Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, sURL);

		JSONObject RequestJSON = view_as<JSONObject>(json_load(sFinal));

		if (!hRequest ||
			!SteamWorks_SetHTTPRequestContextValue(hRequest, RequestJSON) ||
			!SteamWorks_SetHTTPCallbacks(hRequest, OnHTTPRequestCompleted) ||
			!SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/json", sFinal, strlen(sFinal)) ||
			!SteamWorks_SetHTTPRequestNetworkActivityTimeout(hRequest, 10) ||
			!SteamWorks_SendHTTPRequest(hRequest))
		{
			LogError("Discord SteamWorks_CreateHTTPRequest failed.");

			delete RequestJSON;
			delete hRequest;

			return;
		}
	}
	else
	{
		//PrintToServer("[Discord_POST] Have allowances? [%s] | Is processing data? [%s]", g_iRatelimitRemaining > 0 ? "YES":"NO", g_bProcessingData?"YES":"NO");
		g_arrQueuedMessages.PushString(sFinal);
		g_arrQueuedMessages.PushString(sURL);
		g_bProcessingData = true;
	}

	//delete hRequest; //nonono
}

public int OnHTTPRequestCompleted(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, JSONObject RequestJSON)
{
	if (bFailure || !bRequestSuccessful || (eStatusCode != k_EHTTPStatusCode200OK && eStatusCode != k_EHTTPStatusCode204NoContent))
	{
		LogError("Discord HTTP request failed: %d", eStatusCode);

		if (eStatusCode == k_EHTTPStatusCode400BadRequest)
		{
			char sData[2048];

			(view_as<JSONRootNode>(RequestJSON)).ToString(sData, sizeof(sData), 0);

			LogError("Malformed request? Dumping request data:\n%s", sData);
		}
		else if (eStatusCode == k_EHTTPStatusCode429TooManyRequests)
		{
			g_iRatelimitRemaining = 0;
			g_iRatelimitReset = GetTime() + 5;
		}

		delete RequestJSON;
		delete hRequest;

		return;
	}

	static int iLastRatelimitRemaining = 0;
	static int iLastRatelimitReset = 0;
	char sTmp[32];
	bool bHeaderExists = SteamWorks_GetHTTPResponseHeaderValue(hRequest, "x-ratelimit-remaining", sTmp, sizeof(sTmp));

	if (!bHeaderExists)
		LogError("x-ratelimit-remaining header value could not be retrieved");

	int iRatelimitRemaining = StringToInt(sTmp);

	bHeaderExists = SteamWorks_GetHTTPResponseHeaderValue(hRequest, "x-ratelimit-reset", sTmp, sizeof(sTmp));

	if (!bHeaderExists)
		LogError("x-ratelimit-reset header value could not be retrieved");

	int iRatelimitReset = StringToInt(sTmp);

	if (iRatelimitRemaining < iLastRatelimitRemaining || iRatelimitReset >= iLastRatelimitReset) //don't be fooled by different completion times
	{
		g_iRatelimitRemaining = iRatelimitRemaining;
		g_iRatelimitReset = iRatelimitReset;
	}

	//PrintToServer("limit: %d | remaining: %d || reset %d - now %d", g_iRatelimitLimit, g_iRatelimitRemaining, g_iRatelimitReset, GetTime());

	delete RequestJSON;
	delete hRequest;
}

stock bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

public Action CommandListener_SmChat(int client, const char[] sCommand, int argc)
{
	if (client <= 0)
		return Plugin_Continue;

	char sText[256];
	char sUsername[32];

	GetCmdArgString(sText, sizeof(sText));
	GetClientName(client, sUsername, sizeof(sUsername));

	if (g_sAvatarURL[client][0] != '\0')
		Discord_POST(DISCORD_ADMINCHAT_WEBHOOKURL, sText, true, sUsername, true, g_sAvatarURL[client]);
	else
		Discord_POST(DISCORD_ADMINCHAT_WEBHOOKURL, sText, true, sUsername);

	return Plugin_Continue;
}

public Action OnClientSayCommand(int client, const char[] sCommand, const char[] sArgs)
{
	if (client <= 0 || !IsClientInGame(client) || BaseComm_IsClientGagged(client))
		return Plugin_Continue;

	char sFinal[256];
	char sUsername[MAX_NAME_LENGTH];

	GetClientName(client, sUsername, sizeof(sUsername));

	if (strcmp(sCommand, "say_team") == 0)
	{
		if (sArgs[0] == '@')
		{
			bool bAdmin = CheckCommandAccess(client, "", ADMFLAG_GENERIC, true);
			Format(sFinal, sizeof(sFinal), "%s%s", bAdmin ? "" : "To Admins: ", sArgs[1]);
			if (g_sAvatarURL[client][0] != '\0')
				Discord_POST(DISCORD_ADMINCHAT_WEBHOOKURL, sFinal, true, sUsername, true, g_sAvatarURL[client]);
			else
				Discord_POST(DISCORD_ADMINCHAT_WEBHOOKURL, sFinal, true, sUsername);

			if (!bAdmin)
			{
				//g_iReplyTargetSerial = GetClientSerial(client);
				//g_iReplyType = REPLYTYPE_CHAT;
			}

			return Plugin_Continue;
		}

		char sTeamName[32];

		GetTeamName(GetClientTeam(client), sTeamName, sizeof(sTeamName));
		Format(sFinal, sizeof(sFinal), "(%s) ", sTeamName);
	}

	return Plugin_Continue;
}

public Action OnLogAction(Handle hSource, Identity ident, int client, int target, const char[] sMsg)
{
	if (client <= 0)
		return;

	if ((StrContains(sMsg, "sm_psay", false)!= -1) || (StrContains(sMsg, "sm_chat", false)!= -1))
		return;// dont log sm_psay and sm_chat

	char sFinal[256];
	char sCurrentMap[32];
	char sClientName[64];

	GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));
	Format(sFinal, sizeof(sFinal), "[ %s ]```%s```", sCurrentMap, sMsg);

	GetClientName(client, sClientName, sizeof(sClientName));

	if (g_sAvatarURL[client][0] != '\0')
		Discord_POST(DISCORD_ADMINLOGS_WEBHOOKURL, sFinal, true, sClientName, true, g_sAvatarURL[client], false);
	else
		Discord_POST(DISCORD_ADMINLOGS_WEBHOOKURL, sFinal, true, sClientName, false, "", false);

	return;
}


public void AntiBhopCheat_OnClientDetected(int client, char[] sReason, char[] sStats)
{
	char sUsername[MAX_NAME_LENGTH];
	GetClientName(client, sUsername, sizeof(sUsername));

	char currentMap[64];
	GetCurrentMap(currentMap, sizeof(currentMap));

	char sMessage[4096];
	Format(sMessage, sizeof(sMessage), "```%s - Tick: %d``````%s\n%s```", currentMap, GetGameTickCount(), sReason, sStats);

	if (g_sAvatarURL[client][0] != '\0')
		Discord_POST(DISCORD_ANTIBHOPCHEAT_WEBHOOKURL, sMessage, true, sUsername, true, g_sAvatarURL[client], false);
	else
		Discord_POST(DISCORD_ANTIBHOPCHEAT_WEBHOOKURL, sMessage, true, sUsername, false, "", false);
}

public int entWatch_OnClientBanned(int admin, int iLenght, int client)
{
	char sUsername[MAX_NAME_LENGTH];
	GetClientName(client, sUsername, sizeof(sUsername));

	char currentMap[64];
	GetCurrentMap(currentMap, sizeof(currentMap));

	char sMessageTmp[4096];

	if (iLenght == 0)
	{
		Format(sMessageTmp, sizeof(sMessageTmp), "%L got temporarily restricted by %L", client, admin);
	}
	else if (iLenght == -1)
	{
		Format(sMessageTmp, sizeof(sMessageTmp), "%L got PERMANENTLY restricted by %L", client, admin);
	}
	else
	{
		Format(sMessageTmp, sizeof(sMessageTmp), "%L got restricted by %L for %d minutes", client, admin, iLenght);
	}


	char sMessage[4096];
	Format(sMessage, sizeof(sMessage), "```%s - Tick: %d``````%s```", currentMap, GetGameTickCount(), sMessageTmp);

	if (g_sAvatarURL[client][0] != '\0')
		Discord_POST(DISCORD_ENTWATCH_WEBHOOKURL, sMessage, true, sUsername, true, g_sAvatarURL[client], false);
	else
		Discord_POST(DISCORD_ENTWATCH_WEBHOOKURL, sMessage, true, sUsername, false, "", false);
}

public int entWatch_OnClientUnbanned(int admin, int client)
{
	char sUsername[MAX_NAME_LENGTH];
	GetClientName(client, sUsername, sizeof(sUsername));

	char currentMap[64];
	GetCurrentMap(currentMap, sizeof(currentMap));

	char sMessageTmp[4096];
	Format(sMessageTmp, sizeof(sMessageTmp), "%L got unrestricted by %L", client, admin);

	char sMessage[4096];
	Format(sMessage, sizeof(sMessage), "```%s - Tick: %d``````%s```", currentMap, GetGameTickCount(), sMessageTmp);

	if (g_sAvatarURL[client][0] != '\0')
		Discord_POST(DISCORD_ENTWATCH_WEBHOOKURL, sMessage, true, sUsername, true, g_sAvatarURL[client], false);
	else
		Discord_POST(DISCORD_ENTWATCH_WEBHOOKURL, sMessage, true, sUsername, false, "", false);
}

public Action Command_Report(int client, int argc)
{
	if (BaseComm_IsClientGagged(client))
		return Plugin_Handled;

	if (argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_report <name|#userid> <reason>");
		return Plugin_Handled;
	}

	if (g_fReportCooldown[client] > GetGameTime())
	{
		ReplyToCommand(client, "[SM] Please wait another %d seconds before sending another report.", RoundToNearest(g_fReportCooldown[client] - GetGameTime()));
		return Plugin_Handled;
	}

	int iTarget;
	char sTarget[32];

	GetCmdArg(1, sTarget, sizeof(sTarget));

	if ((iTarget = FindTarget(client, sTarget, true, false)) <= 0)
		return Plugin_Handled;

	char sFormatted[4096];
	char sReportText[128];
	char sClientAuthID32[32];
	char sTargetAuthID32[32];
	char sCurrentMap[32];
	int iClientUID = GetClientUserId(client);
	int iTargetUID = GetClientUserId(iTarget);

	GetCmdArgString(sReportText, sizeof(sReportText));
	Format(sReportText, sizeof(sReportText) - strlen(sTarget) + 1, sReportText[strlen(sTarget) + 1]);

	if (sReportText[0] == '"')
		StripQuotes(sReportText);

	GetClientAuthId(client, AuthId_Steam3, sClientAuthID32, sizeof(sClientAuthID32));
	GetClientAuthId(iTarget, AuthId_Steam3, sTargetAuthID32, sizeof(sTargetAuthID32));

	GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));

	Format(sFormatted, sizeof(sFormatted),
		"@here\n```%s - Tick: %d``````Reporter: %N (#%d)\nTarget: %N (#%d)\nReason: %s\n```",
		sCurrentMap, GetGameTickCount(), client, iClientUID, iTarget, iTargetUID, sReportText);

	char sUsername[MAX_NAME_LENGTH];
	GetClientName(client, sUsername, sizeof(sUsername));

	if (g_sAvatarURL[client][0] != '\0')
		Discord_POST(DISCORD_REPORT_WEBHOOKURL, sFormatted, true, sUsername, true, g_sAvatarURL[client], false);
	else
		Discord_POST(DISCORD_REPORT_WEBHOOKURL, sFormatted, true, sUsername, false, "", false);

	Format(sFormatted, sizeof(sFormatted), "#%d \"%N\" reported #%d \"%N\" for:\n\x04[Reports]\x01 %s", iClientUID, client, iTargetUID, iTarget, sReportText);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsClientAuthorized(i))
			continue;

		if (!CheckCommandAccess(i, "", ADMFLAG_GENERIC, true))
			continue;

		PrintToChat(i, "\x01\x04[Reports]\x01 %s", sFormatted);
	}

	g_fReportCooldown[client] = GetGameTime() + 30.0;

	ReplyToCommand(client, "\x01\x04[Reports]\x01 Your report was successfully submitted!");

	return Plugin_Handled;
}
