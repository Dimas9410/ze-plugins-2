//====================================================================================================
//
// Name: [entWatch] Restrictions
// Author: zaCade & Prometheum
// Description: Handle the restrictions of [entWatch]
//
//====================================================================================================
#include <smlib>
#include <multicolors>

#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <entWatch4>
#include <entWatch_core>

/* FORWARDS */
Handle g_hFwd_OnClientRestricted;
Handle g_hFwd_OnClientUnrestricted;

/* COOKIES */
Handle g_hCookie_RestrictIssued;
Handle g_hCookie_RestrictLength;
Handle g_hCookie_RestrictExpire;

/* INTERGERS */
int g_iRestrictIssued[MAXPLAYERS+1];
int g_iRestrictLength[MAXPLAYERS+1];
int g_iRestrictExpire[MAXPLAYERS+1];

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin myinfo =
{
	name         = "[entWatch] Restrictions",
	author       = "zaCade & Prometheum",
	description  = "Handle the restrictions of [entWatch]",
	version      = "4.0.0"
};

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int errorSize)
{
	CreateNative("EW_ClientRestrict",   Native_ClientRestrict);
	CreateNative("EW_ClientUnrestrict", Native_ClientUnrestrict);
	CreateNative("EW_ClientRestricted", Native_ClientRestricted);

	RegPluginLibrary("entWatch-restrictions");
	return APLRes_Success;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("entWatch.restrictions.phrases");

	g_hFwd_OnClientRestricted   = CreateGlobalForward("EW_OnClientRestricted",   ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hFwd_OnClientUnrestricted = CreateGlobalForward("EW_OnClientUnrestricted", ET_Ignore, Param_Cell, Param_Cell);

	g_hCookie_RestrictIssued = RegClientCookie("EW_RestrictIssued", "", CookieAccess_Private);
	g_hCookie_RestrictLength = RegClientCookie("EW_RestrictLength", "", CookieAccess_Private);
	g_hCookie_RestrictExpire = RegClientCookie("EW_RestrictExpire", "", CookieAccess_Private);

	RegAdminCmd("sm_eban",   Command_ClientRestrict,   ADMFLAG_BAN);
	RegAdminCmd("sm_eunban", Command_ClientUnrestrict, ADMFLAG_UNBAN);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnClientCookiesCached(int client)
{
	g_iRestrictIssued[client] = GetClientCookieInt(client, g_hCookie_RestrictIssued);
	g_iRestrictLength[client] = GetClientCookieInt(client, g_hCookie_RestrictLength);
	g_iRestrictExpire[client] = GetClientCookieInt(client, g_hCookie_RestrictExpire);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnClientDisconnect(int client)
{
	g_iRestrictIssued[client] = 0;
	g_iRestrictLength[client] = 0;
	g_iRestrictExpire[client] = 0;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Command_ClientRestrict(int client, int args)
{
	if (!GetCmdArgs())
	{
		CReplyToCommand(client, "\x07%s[entWatch] \x07%sUsage: sm_eban <#userid/name> [duration]", "E01B5D", "F16767");
		return Plugin_Handled;
	}

	char sTarget[32];
	char sLength[32];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	GetCmdArg(2, sLength, sizeof(sLength));

	int target;
	if ((target = FindTarget(client, sTarget, true)) == -1)
		return Plugin_Handled;

	int length = StringToInt(sLength);

	if (ClientRestrict(client, target, length))
	{
		if (length)
		{
			CPrintToChatAll("\x07%s[entWatch] \x07%s%N\x07%s restricted \x07%s%N\x07%s for \x07%s%d\x07%s minutes.", "E01B5D", "EDEDED", client, "F16767", "EDEDED", target, "F16767", "EDEDED", length, "F16767");
			LogAction(client, target, "%L restricted %L for %d minutes.", client, target, length);
		}
		else
		{
			CPrintToChatAll("\x07%s[entWatch] \x07%s%N\x07%s restricted \x07%s%N\x07%s permanently.", "E01B5D", "EDEDED", client, "F16767", "EDEDED", target, "F16767");
			LogAction(client, target, "%L restricted %L permanently.", client, target);
		}
	}

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Command_ClientUnrestrict(int client, int args)
{
	if (!GetCmdArgs())
	{
		CReplyToCommand(client, "\x07%s[entWatch] \x07%sUsage: sm_eunban <#userid/name>", "E01B5D", "F16767");
		return Plugin_Handled;
	}

	char sTarget[32];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int target;
	if ((target = FindTarget(client, sTarget, true)) == -1)
		return Plugin_Handled;

	if (ClientUnrestrict(client, target))
	{
		CPrintToChatAll("\x07%s[entWatch] \x07%s%N\x07%s unrestricted \x07%s%N\x07%s.", "E01B5D", "EDEDED", client, "F16767", "EDEDED", target, "F16767");
		LogAction(client, target, "%L unrestricted %L.", client, target);
	}

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action EW_OnClientItemCanPickup(any[] itemArray, int client, int index)
{
	return ClientRestricted(client)?Plugin_Handled:Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action EW_OnClientItemCanActivate(any[] itemArray, int client, int index)
{
	return ClientRestricted(client)?Plugin_Handled:Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock bool ClientRestrict(int client, int target, int length)
{
	if (!Client_IsValid(client) || !Client_IsValid(target) || !AreClientCookiesCached(target) || ClientRestricted(target))
		return false;

	int issued = GetTime();
	int second = length * 60;
	int expire = issued + second;

	g_iRestrictIssued[target] = issued;
	g_iRestrictLength[target] = length;
	g_iRestrictExpire[target] = expire;

	SetClientCookieInt(target, g_hCookie_RestrictIssued, issued);
	SetClientCookieInt(target, g_hCookie_RestrictLength, length);
	SetClientCookieInt(target, g_hCookie_RestrictExpire, expire);

	Call_StartForward(g_hFwd_OnClientRestricted);
	Call_PushCell(client);
	Call_PushCell(target);
	Call_PushCell(length);
	Call_Finish();

	return true;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock bool ClientUnrestrict(int client, int target)
{
	if (!Client_IsValid(client) || !Client_IsValid(target) || !AreClientCookiesCached(target) || !ClientRestricted(target))
		return false;

	g_iRestrictIssued[target] = 0;
	g_iRestrictLength[target] = 0;
	g_iRestrictExpire[target] = 0;

	SetClientCookieInt(target, g_hCookie_RestrictIssued, 0);
	SetClientCookieInt(target, g_hCookie_RestrictLength, 0);
	SetClientCookieInt(target, g_hCookie_RestrictExpire, 0);

	Call_StartForward(g_hFwd_OnClientUnrestricted);
	Call_PushCell(client);
	Call_PushCell(target);
	Call_Finish();

	return true;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock bool ClientRestricted(int client)
{
	if (!Client_IsValid(client))
		return false;

	//Block them when loading cookies..
	if (!AreClientCookiesCached(client))
		return true;

	//Permanent restriction..
	if (g_iRestrictExpire[client] && g_iRestrictLength[client] == 0)
		return true;

	//Limited restriction..
	if (g_iRestrictExpire[client] && g_iRestrictExpire[client] >= GetTime())
		return true;

	return false;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int Native_ClientRestrict(Handle hPlugin, int numParams)
{
	return ClientRestrict(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3));
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int Native_ClientUnrestrict(Handle hPlugin, int numParams)
{
	return ClientUnrestrict(GetNativeCell(1), GetNativeCell(2));
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int Native_ClientRestricted(Handle hPlugin, int numParams)
{
	return ClientRestricted(GetNativeCell(1));
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void SetClientCookieInt(int client, Handle hCookie, int value)
{
	char sValue[32];
	IntToString(value, sValue, sizeof(sValue));

	SetClientCookie(client, hCookie, sValue);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock int GetClientCookieInt(int client, Handle hCookie)
{
	char sValue[32];
	GetClientCookie(client, hCookie, sValue, sizeof(sValue));

	return StringToInt(sValue);
}