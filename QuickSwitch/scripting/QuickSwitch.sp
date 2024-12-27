#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <zombiereloaded>

ConVar g_Cvar_QuickSwitch_Knife;
float g_flNextAttack[MAXPLAYERS + 1] = {0.0, ...};
bool g_bSetNextAttack[MAXPLAYERS + 1] = false;

public Plugin myinfo =
{
	name 			= "Knife QuickSwitch",
	author 			= "BotoX",
	description 	= "Switching to knife without delay.",
	version 		= "1.0",
	url 			= ""
};

public void OnPluginStart()
{
	g_Cvar_QuickSwitch_Knife = CreateConVar("sm_quickswitch_knife", "1", "Enable Knife QuickSwitch.", 0, true, 0.0, true, 1.0);

	AutoExecConfig(true, "plugin.QuickSwitch");

	/* Handle late load */
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
			OnClientPutInServer(client);
	}
}

public void OnClientPutInServer(int client)
{
	g_flNextAttack[client] = 0.0;
	g_bSetNextAttack[client] = false;
	SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
}

public void OnWeaponSwitch(int client, int weapon)
{
	if(!g_Cvar_QuickSwitch_Knife.BoolValue || !IsPlayerAlive(client) || ZR_IsClientZombie(client))
		return;

	char sWeaponName[32];
	GetEdictClassname(weapon, sWeaponName, sizeof(sWeaponName));

	if(!StrEqual(sWeaponName, "weapon_knife"))
		return;

	float flNextPrimaryAttack = GetEntPropFloat(weapon, Prop_Data, "m_flNextPrimaryAttack");
	float flNextSecondaryAttack = GetEntPropFloat(weapon, Prop_Data, "m_flNextSecondaryAttack");

	if(flNextPrimaryAttack > g_flNextAttack[client])
		g_flNextAttack[client] = flNextPrimaryAttack;

	if(flNextSecondaryAttack > g_flNextAttack[client])
		g_flNextAttack[client] = flNextSecondaryAttack;

	g_bSetNextAttack[client] = true;
}

public void OnWeaponSwitchPost(int client, int weapon)
{
	if(g_bSetNextAttack[client])
	{
		SetEntPropFloat(client, Prop_Send, "m_flNextAttack", g_flNextAttack[client]);
		g_bSetNextAttack[client] = false;
	}
}
