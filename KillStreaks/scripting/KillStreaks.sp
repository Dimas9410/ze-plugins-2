#include <cstrike>
#include <sourcemod>
#include <zombiereloaded>
#include "loghelper.inc"

#pragma semicolon 1
#pragma newdecls required

ConVar g_cvarMinimumStreak = null;
ConVar g_cvarMaximumStreak = null;

bool g_bIsMotherZM[MAXPLAYERS+1] = false;
int g_iKillStreak[MAXPLAYERS+1] = 0;

public Plugin myinfo =
{
	name 		= "KillStreaks",
	author 		= "Neon",
	description = "Recreation of the original HLSTATS Killstreaks for Zombies only + new MotherZM-Win event",
	version 	= "1.1",
	url 		= "https://steamcommunity.com/id/n3ontm"
};

public void OnPluginStart()
{
	g_cvarMinimumStreak = CreateConVar("sm_killstreaks_min", "2", "amount of kills required for the lowest killstreak", 0, true, 0.0);
	g_cvarMaximumStreak = CreateConVar("sm_killstreaks_max", "12", "amount of kills required for the highest killstreak", 0, true, 0.0);

	HookEvent("round_end",    OnRoundEnding, EventHookMode_Pre);
	HookEvent("player_spawn", OnClientSpawn);
	HookEvent("player_death", OnClientDeath, EventHookMode_Pre);
}

public void OnMapStart()
{
	GetTeams();
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	if (motherInfect)
		 g_bIsMotherZM[client] = true;

	if (attacker > -1)
		g_iKillStreak[attacker] += 1;
}

public void OnClientDisconnect(int client)
{
	ResetClient(client);
}

public void OnClientSpawn(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	ResetClient(client);
}

public void OnClientDeath(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	EndKillStreak(client);
}

public void OnRoundEnding(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	int iReason = hEvent.GetInt("reason");

	if (iReason != view_as<int>(CSRoundEnd_GameStart))
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsValidClient(client))
			{
				if ((ZR_IsClientZombie(client)) && (g_bIsMotherZM[client]))
					LogPlayerEvent(client, "triggered", "ze_m_zombies_win");

				EndKillStreak(client);
			}
		}
	}
}

public void EndKillStreak(int client)
{
	if (g_iKillStreak[client] >= g_cvarMinimumStreak.IntValue)
	{
		if (g_iKillStreak[client] > g_cvarMaximumStreak.IntValue)
			g_iKillStreak[client] = g_cvarMaximumStreak.IntValue;

		char StrEventName[32];
		if(g_bIsMotherZM[client])
		{
			Format(StrEventName, sizeof(StrEventName), "ze_m_kill_streak_%d", g_iKillStreak[client]);
			LogPlayerEvent(client, "triggered", StrEventName);
		}
		else
		{
			Format(StrEventName, sizeof(StrEventName), "ze_kill_streak_%d", g_iKillStreak[client]);
			LogPlayerEvent(client, "triggered", StrEventName);
		}
		ResetClient(client);
	}
}

public void ResetClient(int client)
{
	g_bIsMotherZM[client] = false;
	g_iKillStreak[client] = 0;
}

stock bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client));
}
