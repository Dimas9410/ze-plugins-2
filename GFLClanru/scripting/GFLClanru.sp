#pragma semicolon 1
#include <sourcemod>
#include <SteamWorks>

#pragma newdecls required
#include <GFLClanru>

//#define GFL_API_KEY "secret"
#include "GFLClanruAPI.secret"

bool g_bLateLoad = false;
float g_fMonthlyCosts = 45.0;
KeyValues g_Response[MAXPLAYERS + 1];
bool g_bResponseFailed[MAXPLAYERS + 1];
bool g_bClientPreAdminChecked[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "GFLCLan.ru API Integration",
	author = "BotoX",
	description = "Handles donators.",
	version = "0.1",
	url = ""
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_tier", Command_Tier, "[GFLClan.ru] Displays donator info.");
	RegConsoleCmd("sm_vip", Command_Tier, "[GFLClan.ru] Displays donator info.");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("AsyncHasSteamIDReservedSlot", Native_AsyncHasSteamIDReservedSlot);
	RegPluginLibrary("GFLClanru");

	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnRebuildAdminCache(AdminCachePart part)
{
	if(part != AdminCache_Admins)
		return;

	CreateTimer(1.0, OnRebuildAdminCachePost, 0, TIMER_FLAG_NO_MAPCHANGE);
}

public Action OnRebuildAdminCachePost(Handle timer)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(g_bClientPreAdminChecked[client] && g_Response[client])
			OnReceiveUser(client);
	}

	return Plugin_Stop;
}

public void OnClientConnected(int client)
{
	g_bClientPreAdminChecked[client] = false;
	g_bResponseFailed[client] = false;
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if(IsFakeClient(client))
		return;

	char sSteam64ID[32];
	Steam32IDtoSteam64ID(auth, sSteam64ID, sizeof(sSteam64ID));

	int UserSerial = GetClientSerial(client);

	static char sRequest[256];
	FormatEx(sRequest, sizeof(sRequest), "http://direct.gflclan.ru/api/self/Server/OnClientAuthorized?key=%s&steamid=%s", GFL_API_KEY, sSteam64ID);

	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, sRequest);
	if (!hRequest ||
		!SteamWorks_SetHTTPRequestContextValue(hRequest, UserSerial) ||
		!SteamWorks_SetHTTPCallbacks(hRequest, OnClientAuthorized_OnTransferComplete) ||
		!SteamWorks_SetHTTPRequestHeaderValue(hRequest, "Accept", "application/vdf") ||
		!SteamWorks_SendHTTPRequest(hRequest))
	{
		LogError("%L SteamWorks_CreateHTTPRequest failed.", client);
		CloseHandle(hRequest);
		g_bResponseFailed[client] = true;
	}

	return;
}

public int OnClientAuthorized_OnTransferComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int UserSerial)
{
	int client = GetClientFromSerial(UserSerial);
	if(!client) // Player disconnected
	{
		CloseHandle(hRequest);
		return;
	}

	if(bFailure || !bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		LogError("%L OnClientAuthorized HTTP Response failed: %d", client, eStatusCode);
		CloseHandle(hRequest);
		g_bResponseFailed[client] = true;

		if(g_bClientPreAdminChecked[client])
			NotifyPostAdminCheck(client);

		return;
	}

	SteamWorks_GetHTTPResponseBodyCallback(hRequest, OnClientAuthorized_APIWebResponse, UserSerial);
	CloseHandle(hRequest);
}

public int OnClientAuthorized_APIWebResponse(const char[] sData, int UserSerial)
{
	int client = GetClientFromSerial(UserSerial);
	if(!client) // Player disconnected
		return;

	KeyValues Response = new KeyValues("OnClientAuthorized_APIWebResponse");
	if(!Response.ImportFromString(sData, "OnClientAuthorized_APIWebResponse"))
	{
		LogError("%L ImportFromString(sData, \"OnClientAuthorized_APIWebResponse\") failed.", client);
		delete Response;

		if(g_bClientPreAdminChecked[client])
			NotifyPostAdminCheck(client);

		return;
	}
	g_Response[client] = Response;

	if(g_bClientPreAdminChecked[client])
	{
		LogMessage("%L APIWebResponse late.", client);
		NotifyPostAdminCheck(client);
	}
}

public Action OnClientPreAdminCheck(int client)
{
	g_bClientPreAdminChecked[client] = true;
	if(g_Response[client] || g_bResponseFailed[client])
		return Plugin_Continue;

	RunAdminCacheChecks(client);

	return Plugin_Handled;
}

public void OnClientPostAdminFilter(int client)
{
	OnReceiveUser(client);
}

public void OnClientDisconnect(int client)
{
	g_bClientPreAdminChecked[client] = false;
	g_bResponseFailed[client] = false;
	delete g_Response[client];
}

void OnReceiveUser(int client)
{
	KeyValues Response = g_Response[client];
	if(!Response)
		return;

	ArrayList Groups = new ArrayList(ByteCountToCells(32));

	if(Response.JumpToKey("forum"))
	{
		int Member = Response.GetNum("member");
		if(Member)
		{
			int LastSeen = Response.GetNum("last_seen");
			int Expires = RoundFloat(LastSeen + 86400.0 * 7.0);
			int Now = GetTime();

			if(Now < Expires)
			{
				Groups.PushString("Member");
			}
		}
	}
	Response.Rewind();

	if(Response.JumpToKey("donations") && Response.GotoFirstSubKey())
	{
		do
		{
			char sGroup[32];
			Response.GetString("group", sGroup, sizeof(sGroup));
			char sState[32];
			Response.GetString("state", sState, sizeof(sState));
			int Tier = Response.GetNum("tier");
			int Deactivate = Response.GetNum("deactivate", 0);

			if(StrEqual(sState, "active"))
			{
				Groups.PushString(sGroup);
			}
			else if(Deactivate && (StrEqual(sState, "expired") || StrEqual(sState, "refunded") || StrEqual(sState, "reversed")))
			{
				0;
			}
		}
		while(Response.GotoNextKey());
	}
	Response.Rewind();

	if(!Groups.Length)
	{
		delete Groups;
		return;
	}

	AdminId adm;
	// Use a pre-existing admin if we can
	if((adm = GetUserAdmin(client)) == INVALID_ADMIN_ID)
	{
		LogMessage("Creating new admin for %L", client);
		adm = CreateAdmin("");
		SetUserAdmin(client, adm, true);
	}

	for(int i = 0; i < Groups.Length; i++)
	{
		char sGroup[32];
		Groups.GetString(i, sGroup, sizeof(sGroup));

		GroupId grp;
		if((grp = FindAdmGroup(sGroup)) != INVALID_GROUP_ID)
		{
			LogMessage("Adding %L to group %s", client, sGroup);
			AdminInheritGroup(adm, grp);
		}
		else
			LogError("%L Group %s not found!", client, sGroup);
	}

	delete Groups;
}

public void OnClientPostAdminCheck(int client)
{
	KeyValues Response = g_Response[client];
	if(!Response)
		return;

	Response.JumpToKey("donations");
	Response.GotoFirstSubKey();
	do
	{
		int Created = Response.GetNum("created");
		int Activated = Response.GetNum("activated");
		int Expires = Response.GetNum("expires");
		int Length = Response.GetNum("length");
		char sGroup[32];
		Response.GetString("group", sGroup, sizeof(sGroup));
		char sState[32];
		Response.GetString("state", sState, sizeof(sState));
		int Tier = Response.GetNum("tier");
		int Anonymous = Response.GetNum("anonymous");
		int New = Response.GetNum("new");
		int Deactivate = Response.GetNum("deactivate", 0);
		float fNetAmount = Response.GetFloat("net_amount", 0.0);

		if(StrEqual(sState, "active"))
		{
			static char sExpireDate[32];
			FormatTime(sExpireDate, sizeof(sExpireDate), "%a, %d %b %Y %H:%M:%S +00", Expires);

			int Remaining = Expires - Created;
			float RemainingDays = Remaining / 3600.0 / 24.0;

			PrintToChat(client, "\x04[GFLClan.ru]\x01 Donator \x03Tier %d\x01 enabled. Valid until %s (%.1f days)",
				Tier, sExpireDate, RemainingDays);

			if(New)
			{
				float fDays = fNetAmount * (30.5 / g_fMonthlyCosts);
				PrintCenterText(client, "Your Tier %d donation has been activated! Thank you <3", Tier);
				if(fNetAmount && !Anonymous)
					PrintToChatAll("\x04[GFLClan.ru]\x01 \x03%N\x01's donation paid for %.1f days of server uptime, thanks!", client, fDays);
			}
			else if(Remaining < 86400) // less than 24 hours
			{
				int Hours = RoundToFloor(Remaining / 3600.0);
				int Minutes = Remaining % 60;
				PrintCenterText(client, "Oy vey goyim! Your tier %d donation will expire in %d hours and %d minutes.", Tier, Hours, Minutes);
			}
		}
		else if(StrEqual(sState, "queued"))
		{
			float Days = Length / 3600.0 / 24.0;
			PrintToChat(client, "\x04[GFLClan.ru]\x01 Donator \x03Tier %d\x01 queued. Length: %.1f days",
				Tier, Days);
		}
		else if(StrEqual(sState, "expired"))
		{
			PrintCenterText(client, "Oy gevalt goyim! Your tier %d donation has expired.", Tier);
		}
		else if(StrEqual(sState, "refunded"))
		{
			PrintCenterText(client, "OY GEVALT GOYIM YOUR DONATION HAS BEEN REFUNDED!");
		}
		else if(StrEqual(sState, "reversed"))
		{
			PrintCenterText(client, "OY GEVALT GOYIM YOUR DONATION HAS BEEN REVERSED!");
		}
	}
	while(Response.GotoNextKey());
	Response.Rewind();

	Response.JumpToKey("forum");
	Response.GotoFirstSubKey();
	int Member = Response.GetNum("member");
	if(Member)
	{
		int LastSeen = Response.GetNum("last_seen");
		int Expires = RoundFloat(LastSeen + 86400.0 * 7.0);
		int Now = GetTime();

		if(Now < Expires)
		{
			static char sExpireDate[32];
			FormatTime(sExpireDate, sizeof(sExpireDate), "%a, %d %b %Y %H:%M:%S +00", Expires);

			PrintToChat(client, "\x04[GFLClan.ru]\x01 \x03Member\x01 enabled. Remember to log in until %s (%.1f days)",
				sExpireDate, (Expires - Now) / 3600.0 / 24.0);
		}
	}
}

public Action Command_Tier(int client, int args)
{
	KeyValues Response = g_Response[client];
	if(!Response)
	{
		ReplyToCommand(client, "\x04[GFLClan.ru]\x01 No donator info available!");
		return Plugin_Handled;
	}

	Response.JumpToKey("donations");
	Response.GotoFirstSubKey();
	do
	{
		int Created = Response.GetNum("created");
		int Expires = Response.GetNum("expires");
		int Length = Response.GetNum("length");
		char sState[32];
		Response.GetString("state", sState, sizeof(sState));
		int Tier = Response.GetNum("tier");

		if(StrEqual(sState, "active"))
		{
			static char sExpireDate[32];
			FormatTime(sExpireDate, sizeof(sExpireDate), "%a, %d %b %Y %H:%M:%S +00", Expires);

			int Remaining = Expires - Created;
			float RemainingDays = Remaining / 3600.0 / 24.0;

			PrintToChat(client, "\x04[GFLClan.ru]\x01 Donator \x03Tier %d\x01 active. Valid until %s (%.1f days)",
				Tier, sExpireDate, RemainingDays);
		}
		else if(StrEqual(sState, "queued"))
		{
			float Days = Length / 3600.0 / 24.0;
			PrintToChat(client, "\x04[GFLClan.ru]\x01 Donator \x03Tier %d\x01 queued. Length: %.1f days",
				Tier, Days);
		}
	}
	while(Response.GotoNextKey());
	Response.Rewind();

	Response.JumpToKey("forum");
	Response.GotoFirstSubKey();
	int Member = Response.GetNum("member");
	if(Member)
	{
		int LastSeen = Response.GetNum("last_seen");
		int Expires = RoundFloat(LastSeen + 86400.0 * 7.0);
		int Now = GetTime();

		if(Now < Expires)
		{
			static char sExpireDate[32];
			FormatTime(sExpireDate, sizeof(sExpireDate), "%a, %d %b %Y %H:%M:%S +00", Expires);

			PrintToChat(client, "\x04[GFLClan.ru]\x01 \x03Member\x01 active. Remember to log in until %s (%.1f days)",
				sExpireDate, (Expires - Now) / 3600.0 / 24.0);
		}
	}

	return Plugin_Handled;
}

public int Native_AsyncHasSteamIDReservedSlot(Handle plugin, int numParams)
{
	char sSteam32ID[32];
	GetNativeString(1, sSteam32ID, sizeof(sSteam32ID));

	AsyncHasSteamIDReservedSlotCallbackFunc Callback;
	Callback = GetNativeCell(2);

	any Data;
	Data = GetNativeCell(3);

	char sSteam64ID[32];
	Steam32IDtoSteam64ID(sSteam32ID, sSteam64ID, sizeof(sSteam64ID));

	static char sRequest[256];
	FormatEx(sRequest, sizeof(sRequest), "http://direct.gflclan.ru/api/self/Server/HasSteamIDReservedSlot?key=%s&steamid=%s", GFL_API_KEY, sSteam64ID);

	DataPack Pack = new DataPack();
	Pack.WriteString(sSteam32ID);
	Pack.WriteCell(plugin);
	Pack.WriteFunction(Callback);
	Pack.WriteCell(Data);

	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, sRequest);
	if (!hRequest ||
		!SteamWorks_SetHTTPRequestNetworkActivityTimeout(hRequest, 3) ||
		!SteamWorks_SetHTTPRequestContextValue(hRequest, Pack) ||
		!SteamWorks_SetHTTPCallbacks(hRequest, Native_AsyncHasSteamIDReservedSlot_OnTransferComplete) ||
		!SteamWorks_SendHTTPRequest(hRequest))
	{
		CloseHandle(hRequest);
	}
}

public int Native_AsyncHasSteamIDReservedSlot_OnTransferComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, DataPack Pack)
{
	if(bFailure || !bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		LogError("Native_AsyncHasSteamIDReservedSlot HTTP Response failed: %d", eStatusCode);
		CloseHandle(hRequest);
		// Simulate false response
		char sData[2] = "0";
		Native_AsyncHasSteamIDReservedSlot_APIWebResponse(sData, Pack);
		return;
	}

	SteamWorks_GetHTTPResponseBodyCallback(hRequest, Native_AsyncHasSteamIDReservedSlot_APIWebResponse, Pack);
	CloseHandle(hRequest);
}

public int Native_AsyncHasSteamIDReservedSlot_APIWebResponse(char[] sData, DataPack Pack)
{
	Pack.Reset();
	char sSteam32ID[32];
	Pack.ReadString(sSteam32ID, sizeof(sSteam32ID));

	Handle plugin;
	plugin = Pack.ReadCell();

	AsyncHasSteamIDReservedSlotCallbackFunc Callback;
	Callback = view_as<AsyncHasSteamIDReservedSlotCallbackFunc>(Pack.ReadFunction());

	any Data;
	Data = Pack.ReadCell();

	delete Pack;

	TrimString(sData);
	int Result = StringToInt(sData);

	Call_StartFunction(plugin, Callback);
	Call_PushString(sSteam32ID);
	Call_PushCell(Result);
	Call_PushCell(Data);
	Call_Finish();

	return 0;
}


stock bool Steam32IDtoSteam64ID(const char[] sSteam32ID, char[] sSteam64ID, int Size)
{
	if(strlen(sSteam32ID) < 11 || strncmp(sSteam32ID[0], "STEAM_", 6))
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
