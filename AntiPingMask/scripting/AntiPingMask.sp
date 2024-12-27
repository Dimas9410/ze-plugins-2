#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define REMIND_INTERVAL 5.0

bool g_IsMasked[MAXPLAYERS + 1] = {false, ...};

public Plugin myinfo =
{
	name 			= "AntiPingMask",
	author 			= "BotoX",
	description 	= "Shows real ping when client tries to mask it.",
	version 		= "1.0",
	url 			= ""
};

public void OnClientDisconnect(int client)
{
	g_IsMasked[client] = false;
}

public void OnMapStart()
{
	CreateTimer(REMIND_INTERVAL, Timer_Remind, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Remind(Handle Timer, any Data)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(g_IsMasked[client] && IsClientInGame(client))
			PrintToChat(client, "[SM] Please turn off your pingmask! (cl_cmdrate 100)");
	}
}

public void OnClientSettingsChanged(int client)
{
	static char sCmdRate[32];
	GetClientInfo(client, "cl_cmdrate", sCmdRate, sizeof(sCmdRate));
	bool bBadCmdRate = !IsNatural(sCmdRate);

	if(bBadCmdRate)
		g_IsMasked[client] = true;
	else
		g_IsMasked[client] = false;
}

public void OnGameFrame()
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(g_IsMasked[client])
			ForcePing(client);
	}
}

public void ForcePing(int client)
{
	int iResEnt = GetPlayerResourceEntity();
	if(iResEnt == -1)
		return;

	int iLatency = RoundToNearest(GetClientAvgLatency(client, NetFlow_Outgoing) * 1000.0);
	SetEntProp(iResEnt, Prop_Send, "m_iPing", iLatency, _, client);
}

stock bool IsNatural(const char[] sString)
{
	for(int i = 0; sString[i]; i++)
	{
		if(!IsCharNumeric(sString[i]))
			return false;
	}

	return true;
}
