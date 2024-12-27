#include <sourcemod>
#include <cstrike>
#include <zombiereloaded>

new bool:G_bIsHuman[MAXPLAYERS+1];
new bool:G_bIsZombie[MAXPLAYERS+1];

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin myinfo =
{
	name        = "MVP Stars",
	author      = "zaCade",
	description = "",
	version     = "1.0",
	url         = ""
};

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public ZR_OnClientInfected(client, attacker, bool:motherinfect, bool:respawnoverride, bool:respawn)
{
	G_bIsHuman[client] = false;
	G_bIsZombie[client] = true;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public ZR_OnClientHumanPost(client, bool:respawn, bool:protect)
{
	G_bIsHuman[client] = true;
	G_bIsZombie[client] = false;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		G_bIsHuman[client] = true;
		G_bIsZombie[client] = false;
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	switch(GetEventInt(event, "winner"))
	{
		case(CS_TEAM_CT): CreateTimer(0.2, OnHumansWin, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:OnHumansWin(Handle:timer)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && !IsClientObserver(client) && !IsFakeClient(client))
		{
			if (G_bIsHuman[client] && !G_bIsZombie[client])
			{
				CS_SetMVPCount(client, CS_GetMVPCount(client) + 1);
			}
		}
	}
}