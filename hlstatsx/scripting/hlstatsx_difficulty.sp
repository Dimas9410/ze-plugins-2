#include <sourcemod>
#include <cstrike>
#include <zombiereloaded>

bool G_bIsHuman[MAXPLAYERS+1];
bool G_bIsZombie[MAXPLAYERS+1];

ConVar G_hCvar_Difficulty_Humans;
ConVar G_hCvar_Difficulty_Zombies;
ConVar G_hCvar_Difficulty_Humans_BlockTime;

Handle g_hHumanPointsTimer;

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin:myinfo =
{
	name        = "HLstatsX CE Difficulty",
	author      = "zaCade + Neon",
	description = "Grant points to the winning team. (zombies/humans)",
	version     = "1.2",
	url         = ""
};

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public OnPluginStart()
{
	G_hCvar_Difficulty_Humans = CreateConVar("hlx_difficulty_humans", "0", "", 0, true, 0.0, true, 3.0);
	G_hCvar_Difficulty_Zombies = CreateConVar("hlx_difficulty_zombies", "0", "", 0, true, 0.0, true, 3.0);
	G_hCvar_Difficulty_Humans_BlockTime = CreateConVar("hlx_difficulty_humans_blocktime", "60", "", 0, true, 0.0, true, 180.0);

	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);

	AutoExecConfig(true, "plugin.hlstatsx_difficulty");
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
	if (g_hHumanPointsTimer != INVALID_HANDLE && KillTimer(g_hHumanPointsTimer))
		g_hHumanPointsTimer = INVALID_HANDLE;

	g_hHumanPointsTimer = CreateTimer(G_hCvar_Difficulty_Humans_BlockTime.FloatValue, OnHumanPointsTimer);

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
		case(CS_TEAM_T): CreateTimer(0.2, OnZombiesWin, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action OnHumanPointsTimer(Handle timer)
{
	g_hHumanPointsTimer = INVALID_HANDLE;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:OnHumansWin(Handle:timer)
{
	if (g_hHumanPointsTimer != INVALID_HANDLE)
	{
		PrintToChatAll("[SM] Round ended too fast. Humans will not be rewarded for the Win.");
		return;
	}

	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && !IsClientObserver(client) && !IsFakeClient(client))
		{
			if (G_bIsHuman[client] && !G_bIsZombie[client])
			{
				new String:sAuthid[64];
				if (!GetClientAuthString(client, sAuthid, sizeof(sAuthid)))
					Format(sAuthid, sizeof(sAuthid), "UNKNOWN");

				LogToGame("\"%N<%d><%s><%s>\" triggered \"human_win_%i\"", client, GetClientUserId(client), sAuthid, "CT", G_hCvar_Difficulty_Humans.IntValue);
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:OnZombiesWin(Handle:timer)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && !IsClientObserver(client) && !IsFakeClient(client))
		{
			if (G_bIsZombie[client] && !G_bIsHuman[client])
			{
				new String:sAuthid[64];
				if (!GetClientAuthString(client, sAuthid, sizeof(sAuthid)))
					Format(sAuthid, sizeof(sAuthid), "UNKNOWN");

				LogToGame("\"%N<%d><%s><%s>\" triggered \"zombie_win_%i\"", client, GetClientUserId(client), sAuthid, "TERRORIST", G_hCvar_Difficulty_Zombies.IntValue);
			}
		}
	}
}