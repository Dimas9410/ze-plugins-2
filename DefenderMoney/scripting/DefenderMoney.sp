#pragma semicolon 1

#include <sourcemod>
#include <cstrike>

#undef REQUIRE_PLUGIN
#tryinclude <zombiereloaded>
#define REQUIRE_PLUGIN

#pragma newdecls required

#define DMGINSTEADOFHITS
#define CASHPERHIT 4

#if defined DMGINSTEADOFHITS
ConVar g_cvarDamageMultiplier = null;
#endif

bool g_bZRLoaded;

public Plugin myinfo =
{
	name = "Defender Money",
	author = "Obus",
	description = "",
	version = "0.0.1",
	url = ""
};

public void OnPluginStart()
{
#if defined DMGINSTEADOFHITS
	g_cvarDamageMultiplier = CreateConVar("sm_damagecashmultiplier", "1.0", "Multiplier that decides how much cash a client shall receive upon dealing damage");

	AutoExecConfig(true, "plugin.DefenderMoney");
#endif

	HookEvent("player_hurt", EventHook_PlayerHurt, EventHookMode_Pre);
	HookEvent("player_death", EventHook_PlayerDeath, EventHookMode_Pre);
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

public Action EventHook_PlayerHurt(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_bZRLoaded)
		return Plugin_Continue;

	int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));

	if (!IsValidClient(iAttacker) || !ZR_IsClientHuman(iAttacker))
		return Plugin_Continue;

	int iVictim = GetClientOfUserId(hEvent.GetInt("userid"));

	if (!IsValidClient(iVictim) || !ZR_IsClientZombie(iVictim))
		return Plugin_Continue;

	char sWeapon[16];

	hEvent.GetString("weapon", sWeapon, sizeof(sWeapon));

	if (!strncmp(sWeapon, "knife", 5))
		return Plugin_Continue;

#if defined DMGINSTEADOFHITS
	float fDamage = float(hEvent.GetInt("dmg_health"));

	SetEntProp(iAttacker, Prop_Send, "m_iAccount", GetEntProp(iAttacker, Prop_Send, "m_iAccount") + RoundToNearest(fDamage > 0.0 ? fDamage * g_cvarDamageMultiplier.FloatValue : 1.0));
#else
	SetEntProp(iAttacker, Prop_Send, "m_iAccount", GetEntProp(iAttacker, Prop_Send, "m_iAccount") + CASHPERHIT);
#endif

	return Plugin_Continue;
}

public Action EventHook_PlayerDeath(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_bZRLoaded)
		return Plugin_Continue;

	int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));

	if (!IsValidClient(iAttacker) || !ZR_IsClientHuman(iAttacker))
		return Plugin_Continue;

	int iPacked = (iAttacker<<16) | (GetEntProp(iAttacker, Prop_Send, "m_iAccount")&0xFFFF);

	RequestFrame(RequestFrame_Callback, iPacked);

	return Plugin_Continue;
}

void RequestFrame_Callback(int iPacked)
{
	int iOldCash = iPacked&0xFFFF;
	int iAttacker = iPacked>>16;

	SetEntProp(iAttacker, Prop_Send, "m_iAccount", iOldCash);
}

stock bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client));
}
