#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <zombiereloaded>
#include <multicolors.inc>
#include "loghelper.inc"

#pragma semicolon 1
#pragma newdecls required

bool g_bDisabled[2048];
bool g_bOnCD = false;

ConVar g_cCD;

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin myinfo =
{
	name        = "Trigger Rewards",
	author      = "Neon",
	description = "HLSTATS Trigger Rewards",
	version     = "1.0",
	url         = "https://steamcommunity.com/id/n3ontm"
};

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnPluginStart()
{
	g_cCD = CreateConVar("sm_trigger_reward_cd", "10.0", "Cooldown between HLSTATS Trigger rewards", 0, true, 0.1);
	AutoExecConfig(true, "plugin.TriggerRewards");

	HookEvent("round_start", OnRoundStart);
	HookEntityOutput("trigger_once", "OnStartTouch", OnStartTouch);
	HookEntityOutput("func_button", "OnPressed", OnPressed);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnMapStart()
{
	GetTeams();
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action OnRoundStart(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	for(int i = 0; i < 2048; i++)
		g_bDisabled[i] = false;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnStartTouch(const char[] sOutput, int iCaller, int iActivator, float fDelay)
{
	if (!IsValidClient(iActivator))
		return;

	if (g_bDisabled[iCaller] || g_bOnCD)
		return;

	if (!(ZR_IsClientHuman(iActivator)))
		return;

	g_bDisabled[iCaller] = true;
	g_bOnCD = true;

	CreateTimer(g_cCD.FloatValue, ResetCD);

	LogPlayerEvent(iActivator, "triggered", "trigger");
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnPressed(const char[] sOutput, int iCaller, int iActivator, float fDelay)
{
	if(!IsValidClient(iActivator))
		return;

	if (g_bDisabled[iCaller] || g_bOnCD)
		return;

	if (!(ZR_IsClientHuman(iActivator)))
		return;

	int iParent = INVALID_ENT_REFERENCE;
	if ((iParent = GetEntPropEnt(iCaller, Prop_Data, "m_hMoveParent")) != INVALID_ENT_REFERENCE)
	{
		char sClassname[64];
		GetEdictClassname(iParent, sClassname, sizeof(sClassname));

		if (strncmp(sClassname, "weapon_", 7, false) == 0)
			return;
	}

	g_bDisabled[iCaller] = true;
	g_bOnCD = true;

	CreateTimer(g_cCD.FloatValue, ResetCD);

	LogPlayerEvent(iActivator, "triggered", "trigger");
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action ResetCD(Handle timer)
{
	g_bOnCD = false;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public bool IsValidClient(int iClient)
{
	if ( !( 1 <= iClient <= MaxClients ) || !IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return false;

	return true;
}
