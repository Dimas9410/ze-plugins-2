#pragma semicolon 1

#include <sourcemod>
#include <connect>
#include <geoip>
#include <multicolors>

#pragma newdecls required

char g_sDataFile[128];
char g_sCustomMessageFile[128];

Database g_hDatabase;

Handle g_hCustomMessageFile;
Handle g_hCustomMessageFile2;


#define MSGLENGTH 100

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin myinfo = {
	name = "Connect Announce",
	author = "Neon + Botox",
	description = "Connect Announcer",
	version = "2.0",
	url = ""
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnPluginStart()
{
	BuildPath(Path_SM, g_sCustomMessageFile, sizeof(g_sCustomMessageFile), "configs/connect_announce/custom-messages.cfg");
	BuildPath(Path_SM, g_sDataFile, sizeof(g_sDataFile), "configs/connect_announce/settings.cfg");

	char error[255];

	if (SQL_CheckConfig("hlstatsx"))
	{
		g_hDatabase = SQL_Connect("hlstatsx", true, error, sizeof(error));
	}

	if (g_hDatabase == null)
	{
		LogError("Could not connect to database: %s", error);
	}

	RegAdminCmd("sm_joinmsg", Command_JoinMsg, ADMFLAG_CUSTOM1, "Sets a custom message which will be shown upon connecting to the server");
	RegAdminCmd("sm_resetjoinmsg", Command_ResetJoinMsg, ADMFLAG_CUSTOM1, "Resets your custom connect message");
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Command_JoinMsg(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "[ConnectAnnounce] Cannot use command from server console");
		return Plugin_Handled;
	}

	char sAuth[32];
	GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));

	if (g_hCustomMessageFile != null)
			CloseHandle(g_hCustomMessageFile);

	g_hCustomMessageFile = CreateKeyValues("custom_messages");

	if (!FileToKeyValues(g_hCustomMessageFile, g_sCustomMessageFile))
	{
		SetFailState("[ConnectAnnounce] Config file missing!");
		return Plugin_Handled;
	}

	KvRewind(g_hCustomMessageFile);

	if (args < 1)
	{
		if (KvJumpToKey(g_hCustomMessageFile, sAuth))
		{
			char sCustomMessage[256];
			KvGetString(g_hCustomMessageFile, "message", sCustomMessage, sizeof(sCustomMessage), "");
			if (StrEqual(sCustomMessage, "reset"))
			{
				CPrintToChat(client, "[ConnectAnnounce] No Join Message set! Use sm_joinmsg <your message here> to set one.");
				return Plugin_Handled;
			}
			CPrintToChat(client, "[ConnectAnnounce] Your Join Message is: %s", sCustomMessage);
		}
		else
			CPrintToChat(client, "[ConnectAnnounce] No Join Message set! Use sm_joinmsg <your message here> to set one.");
	}
	else
	{
		char sArg[512];
		int iLength;
		iLength = GetCmdArgString(sArg, sizeof(sArg));

		if(iLength > MSGLENGTH)
		{
			ReplyToCommand(client, "[ConnectAnnounce] Maximum message length is %d characters!", MSGLENGTH);
			return Plugin_Handled;
		}


		if (KvJumpToKey(g_hCustomMessageFile, sAuth, true))
			KvSetString(g_hCustomMessageFile, "message", sArg);
		else
		{
			SetFailState("[ConnectAnnounce] Could not find/create Key Value!");
			return Plugin_Handled;
		}

		KvRewind(g_hCustomMessageFile);
		KeyValuesToFile(g_hCustomMessageFile, g_sCustomMessageFile);
		CPrintToChat(client, "[ConnectAnnounce] Your Join Message is: %s", sArg);

	}
	KvRewind(g_hCustomMessageFile);
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Command_ResetJoinMsg(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "[ConnectAnnounce] Cannot use command from server console");
		return Plugin_Handled;
	}

	char sAuth[32];
	GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));

	if (g_hCustomMessageFile != null)
			CloseHandle(g_hCustomMessageFile);

	g_hCustomMessageFile = CreateKeyValues("custom_messages");

	if (!FileToKeyValues(g_hCustomMessageFile, g_sCustomMessageFile))
	{
		SetFailState("[ConnectAnnounce] Config file missing!");
		return Plugin_Handled;
	}

	KvRewind(g_hCustomMessageFile);

	if (KvJumpToKey(g_hCustomMessageFile, sAuth, true))
			KvSetString(g_hCustomMessageFile, "message", "reset");

	KvRewind(g_hCustomMessageFile);

	KeyValuesToFile(g_hCustomMessageFile, g_sCustomMessageFile);

	CPrintToChat(client, "[ConnectAnnounce] Your Join Message got reset.");
	return Plugin_Handled;

}
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void TQueryCB2(Handle owner, Handle rs, const char[] error, any data)
{
	int client = 0;

	if ((client = GetClientOfUserId(data)) == 0)
	{
		return;
	}

	int iRank = -1;
	if (SQL_GetRowCount(rs) > 0)
	{
		int iField;

		SQL_FetchRow(rs);
		SQL_FieldNameToNum(rs, "rank", iField);
		iRank = SQL_FetchInt(rs, iField);
	}

	Handle hFile = OpenFile(g_sDataFile, "r");
	static char sRawMsg[301];

	if(hFile != INVALID_HANDLE)
	{
		ReadFileLine(hFile, sRawMsg, sizeof(sRawMsg));
		TrimString(sRawMsg);
		CloseHandle(hFile);
	}
	else
	{
		LogError("[SM] File not found! (configs/ConnectAnnounce/settings.txt)");
		return;
	}

	static char sIP[16];
	static char sAuth[32];
	static char sCountry[32];
	static char sName[128];

	GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));
	GetClientName(client, sName, sizeof(sName));
	AdminId aid;

	if(StrContains(sRawMsg, "{PLAYERTYPE}"))
	{

		aid = GetUserAdmin(client);

		if(GetAdminFlag(aid, Admin_Generic))
		{
			ReplaceString(sRawMsg, sizeof(sRawMsg), "{PLAYERTYPE}", "Admin");
		}
		else if(GetAdminFlag(aid, Admin_Custom4))
		{
			ReplaceString(sRawMsg, sizeof(sRawMsg), "{PLAYERTYPE}", "Top25");
		}
		else if(GetAdminFlag(aid, Admin_Custom1))
		{
			ReplaceString(sRawMsg, sizeof(sRawMsg), "{PLAYERTYPE}", "VIP");
		}
		else if(GetAdminFlag(aid, Admin_Custom3))
		{
			ReplaceString(sRawMsg, sizeof(sRawMsg), "{PLAYERTYPE}", "Top50");
		}
		else if(GetAdminFlag(aid, Admin_Custom5))
		{
			ReplaceString(sRawMsg, sizeof(sRawMsg), "{PLAYERTYPE}", "Supporter");
		}
		else if(GetAdminFlag(aid, Admin_Custom6))
		{
			ReplaceString(sRawMsg, sizeof(sRawMsg), "{PLAYERTYPE}", "Member");
		}
		else
		{
			ReplaceString(sRawMsg, sizeof(sRawMsg), "{PLAYERTYPE}", "Player");
		}
	}

	if(StrContains(sRawMsg, "{RANK}"))
	{
		if (iRank != -1)
		{
			char sBuffer[16];
			Format(sBuffer, sizeof(sBuffer), "[#%d] ", iRank);
			ReplaceString(sRawMsg, sizeof(sRawMsg), "{RANK}", sBuffer);
		}
	}

	if(StrContains(sRawMsg, "{NOSTEAM}"))
	{
		if(!SteamClientAuthenticated(sAuth))
			ReplaceString(sRawMsg, sizeof(sRawMsg), "{NOSTEAM}", " <NoSteam>");
		else
			ReplaceString(sRawMsg, sizeof(sRawMsg), "{NOSTEAM}", "");
	}

	if(StrContains(sRawMsg, "{STEAMID}"))
	{
		ReplaceString(sRawMsg, sizeof(sRawMsg), "{STEAMID}", sAuth);
	}

	if(StrContains(sRawMsg, "{NAME}"))
	{
		ReplaceString(sRawMsg, sizeof(sRawMsg), "{NAME}", sName);
	}

	if(StrContains(sRawMsg, "{COUNTRY}"))
	{
		if(GetClientIP(client, sIP, sizeof(sIP)) && GeoipCountry(sIP, sCountry, sizeof(sCountry)))
		{
			char sBuffer[128];
			Format(sBuffer, sizeof(sBuffer), " from %s", sCountry);
			ReplaceString(sRawMsg, sizeof(sRawMsg), "{COUNTRY}", sBuffer);
		}
		else
			ReplaceString(sRawMsg, sizeof(sRawMsg), "{COUNTRY}", "");
	}

	////////////////////////////////////////////////////////////////////////////////////////////////////////////

	if (!CheckCommandAccess(client, "sm_joinmsg", ADMFLAG_CUSTOM1))
	{
		CPrintToChatAll(sRawMsg);
		return;
	}

	if (g_hCustomMessageFile2 != null)
			CloseHandle(g_hCustomMessageFile2);

	g_hCustomMessageFile2 = CreateKeyValues("custom_messages");

	if (!FileToKeyValues(g_hCustomMessageFile2, g_sCustomMessageFile))
	{
		SetFailState("[ConnectAnnounce] Config file missing!");
		return;
	}

	KvRewind(g_hCustomMessageFile2);

	char sBanned[16];
	char sFinalMessage[512];
	char sCustomMessage[256];



	if (KvJumpToKey(g_hCustomMessageFile2, sAuth))
	{
		KvGetString(g_hCustomMessageFile2, "banned", sBanned, sizeof(sBanned), "");


		KvGetString(g_hCustomMessageFile2, "message", sCustomMessage, sizeof(sCustomMessage), "");
		if (StrEqual(sCustomMessage, "reset") || StrEqual(sBanned, "true"))
			CPrintToChatAll(sRawMsg);
		else
		{
			Format(sFinalMessage, sizeof(sFinalMessage), "%s %s", sRawMsg, sCustomMessage);
			CPrintToChatAll(sFinalMessage);
		}
	}
	else
		CPrintToChatAll(sRawMsg);

}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void TQueryCB(Handle owner, Handle rs, const char[] error, any data)
{
	int client = 0;

	if ((client = GetClientOfUserId(data)) == 0)
	{
		return;
	}

	if (rs == null)
	{
		LogError("Database Error: null result");
		return;
	}

	int iPlayerId = -1;
	if (SQL_GetRowCount(rs) > 0)
	{
		int iField;
		SQL_FetchRow(rs);
		SQL_FieldNameToNum(rs, "playerId", iField);
		iPlayerId = SQL_FetchInt(rs, iField);

	}
	char sQuery[1024];
	Format(sQuery, sizeof(sQuery), "SELECT T1.playerid, T1.skill, T2.rank FROM hlstats_Players T1 LEFT JOIN (SELECT skill, (@v_id := @v_Id + 1) AS rank	FROM (SELECT DISTINCT skill FROM hlstats_Players WHERE game = 'css-ze' ORDER BY skill DESC) t, (SELECT @v_id := 0) r) T2 ON T1.skill = T2.skill	WHERE game = 'css-ze' AND playerId = %d	ORDER BY skill DESC" ,iPlayerId);
	SQL_TQuery(g_hDatabase, TQueryCB2, sQuery, GetClientUserId(client));

}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client))
		return;

	char error[255];
	static char sAuth[32];

	GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));
	strcopy(sAuth, sizeof(sAuth), sAuth[8]);


	char sQuery[255];
	Format(sQuery, sizeof(sQuery), "SELECT * FROM hlstats_PlayerUniqueIds WHERE uniqueId = '%s' AND game = 'css-ze'", sAuth);
	//PrintToChatAll(sQuery);
	SQL_TQuery(g_hDatabase, TQueryCB, sQuery, GetClientUserId(client));
}