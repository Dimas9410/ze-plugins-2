#pragma semicolon 1

#include <sourcemod>

#include "loghelper.inc"

#pragma newdecls required

int g_iClientConnectionTime[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name         = "Play Time Reward",
	author       = "Obus",
	description  = "Handle ranking rewards",
	version      = "0.0.1"
};

public void OnPluginStart()
{
	CreateTimer(30.0, Timer_CheckConnectionTime, _, TIMER_REPEAT);

	HookEvent("player_disconnect", EventHook_PlayerDisconnect, EventHookMode_Post);
}

public void OnPluginEnd()
{
	UnhookEvent("player_disconnect", EventHook_PlayerDisconnect, EventHookMode_Post);
}

public void OnMapStart()
{
	GetTeams();
}

public void EventHook_PlayerDisconnect(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	bool bIsBot = view_as<bool>(hEvent.GetInt("bot"));

	if (bIsBot)
		return;

	int client = GetClientOfUserId(hEvent.GetInt("userid"));

	g_iClientConnectionTime[client] = 0;
}

public Action Timer_CheckConnectionTime(Handle hThis)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		if ((g_iClientConnectionTime[i] += 30) >= 1200)
		{
			LogPlayerEvent(i, "triggered", "staying_server");
			g_iClientConnectionTime[i] -= 1200;
		}
	}
}

stock bool IsValidClient(int client)
{
	return (client >= 1 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}
