#pragma semicolon 1

#include <sourcemod>
#include <cstrike>

#undef REQUIRE_PLUGIN
#tryinclude <zombiereloaded>
#define REQUIRE_PLUGIN

#pragma newdecls required

bool g_bZRLoaded;

ConVar g_cvarJumpsUntilBlock = null;
ConVar g_cvarIntervalBetweenJumps = null;
ConVar g_cvarCooldownInterval = null;

float g_fLastJumpTime[MAXPLAYERS + 1];

int g_iFastJumpCount[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Anti Jump Spam",
	author = "Obus",
	description = "Prevents clients from spamming jump to avoid knockback in crawl spaces.",
	version = "1.0.0",
	url = ""
}

public void OnPluginStart()
{
	g_cvarJumpsUntilBlock = CreateConVar("sm_ajs_jumpsuntilblock", "5", "Successive jumps until anti jump-spam kicks in.");
	g_cvarIntervalBetweenJumps = CreateConVar("sm_ajs_jumpinterval", "0.2", "If a client jumps faster than this their jumps will be blocked after the amount of jumps specified in \"sm_ajs_jumpsuntilblock\" is reached.");
	g_cvarCooldownInterval = CreateConVar("sm_ajs_cooldowninterval", "0.0", "Changes the amount of time required for a jump to not be considered spam anymore. (Setting this to 0 makes the interval sm_ajs_jumpinterval * 2)");

	AutoExecConfig(true, "plugin.antijumpspam");
}

public void OnAllPluginsLoaded()
{
	g_bZRLoaded = LibraryExists("zombiereloaded");
}

public void OnLibraryAdded(const char[] sName)
{
	if (strcmp(sName, "zombiereloaded", false) == 0)
		g_bZRLoaded = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if (strcmp(sName, "zombiereloaded", false) == 0)
		g_bZRLoaded = false;
}

public void OnClientDisconnect(int client)
{
	g_fLastJumpTime[client] = 0.0;
	g_iFastJumpCount[client] = 0;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	static bool bHoldingJump[MAXPLAYERS + 1];

#if defined _zr_included
	if (!IsPlayerAlive(client) || (g_bZRLoaded && !ZR_IsClientZombie(client)) || (!g_bZRLoaded && GetClientTeam(client) != CS_TEAM_T))
		return Plugin_Continue;
#else
	if (!IsPlayerAlive(client) || GetClientTeam(client) != CS_TEAM_T)
		return Plugin_Continue;
#endif

	if (buttons & IN_JUMP && GetEntityFlags(client) & FL_ONGROUND)
	{
		float fCurTime = GetEngineTime();
		float fTimeSinceLastJump = fCurTime - g_fLastJumpTime[client];

		if (!bHoldingJump[client])
		{
			if (fTimeSinceLastJump > (g_cvarCooldownInterval.FloatValue > 0.0 ? g_cvarCooldownInterval.FloatValue : g_cvarIntervalBetweenJumps.FloatValue * 2.0) && g_iFastJumpCount[client] > 0)
			{
				int iJumpsToDeduct = RoundToFloor(fTimeSinceLastJump / (g_cvarCooldownInterval.FloatValue > 0.0 ? g_cvarCooldownInterval.FloatValue : g_cvarIntervalBetweenJumps.FloatValue * 2));

				iJumpsToDeduct = iJumpsToDeduct <= g_iFastJumpCount[client] ? iJumpsToDeduct : g_iFastJumpCount[client];

				g_iFastJumpCount[client] -= iJumpsToDeduct;
			}
		}

		if (g_iFastJumpCount[client] >= g_cvarJumpsUntilBlock.IntValue)
		{
			buttons &= ~IN_JUMP;

			return Plugin_Continue;
		}

		if (!bHoldingJump[client])
		{
			bHoldingJump[client] = true;

			if (fTimeSinceLastJump < g_cvarIntervalBetweenJumps.FloatValue)
				g_iFastJumpCount[client]++;

			g_fLastJumpTime[client] = fCurTime;
		}
	}
	else if (bHoldingJump[client])
	{
		bHoldingJump[client] = false;
	}

	return Plugin_Continue;
}
