#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

int g_Client_CommandCount[MAXPLAYERS + 1];
float g_Client_LastFlood[MAXPLAYERS + 1];

#define MAX_COMMANDS 100
#define INTERVAL 1.0

public Plugin myinfo =
{
	name = "AntiFlood",
	author = "BotoX",
	description = "",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	/* Late load */
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
			OnClientConnected(client);
	}

	AddCommandListener(OnAnyCommand, "");
}

public void OnClientConnected(int client)
{
	g_Client_CommandCount[client] = 0;
	g_Client_LastFlood[client] = 0.0;
}

//public Action OnClientCommand(int client, int args)
public Action OnAnyCommand(int client, const char[] command, int argc)
{
	if(FloodCheck(client))
		return Plugin_Handled;

	return Plugin_Continue;
}

public void OnClientSettingsChanged(int client)
{
	FloodCheck(client);
}

bool FloodCheck(int client)
{
	if(client <= 0 || client > MaxClients)
		return false;

	if(++g_Client_CommandCount[client] <= MAX_COMMANDS)
		return false;

	float Time = GetGameTime();
	if(Time >= g_Client_LastFlood[client] + INTERVAL)
	{
		g_Client_LastFlood[client] = Time;
		g_Client_CommandCount[client] = 0;
		return false;
	}

	KickClientEx(client, "STOP FLOODING THE SERVER!!!");
	return true;
}
