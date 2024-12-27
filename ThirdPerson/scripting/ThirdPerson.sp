#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <FullUpdate>
#include <multicolors>

bool g_bThirdPerson[MAXPLAYERS + 1] = { false, ... };

// Spectator Movement modes (from smlib)
enum Obs_Mode
{
	OBS_MODE_NONE = 0,	// not in spectator mode
	OBS_MODE_DEATHCAM,	// special mode for death cam animation
	OBS_MODE_FREEZECAM,	// zooms to a target, and freeze-frames on them
	OBS_MODE_FIXED,		// view from a fixed camera position
	OBS_MODE_IN_EYE,	// follow a player in first person view
	OBS_MODE_CHASE,		// follow a player in third person view
	OBS_MODE_POI,		// PASSTIME point of interest - game objective, big fight, anything interesting; added in the middle of the enum due to tons of hard-coded "<ROAMING" enum compares
	OBS_MODE_ROAMING,	// free roaming

	NUM_OBSERVER_MODES
};

public Plugin myinfo =
{
	name = "ThirdPerson",
	author = "BotoX",
	description = "Shitty thirdperson.",
	version = "1.0"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_tp", Command_ThirdPerson, "Toggle thirdperson");

	HookEvent("player_death", Event_PlayerDeathPost, EventHookMode_Post);
	HookEvent("player_spawn", Event_PlayerSpawnPost, EventHookMode_Post);
}

public void OnClientConnected(int client)
{
	g_bThirdPerson[client] = false;
}

public Action Command_ThirdPerson(int client, int args)
{
	if(g_bThirdPerson[client])
		ThirdPersonOff(client);
	else
		ThirdPersonOn(client);
}

public void Event_PlayerDeathPost(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	ThirdPersonOff(client);
}

public void Event_PlayerSpawnPost(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	ThirdPersonOff(client);
}

void ThirdPersonOn(int client)
{
	if(g_bThirdPerson[client])
		return;

	if(!IsPlayerAlive(client))
		return;

	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
	SetEntProp(client, Prop_Send, "m_iObserverMode", OBS_MODE_DEATHCAM);
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
	SetEntProp(client, Prop_Send, "m_iFOV", 120);

	g_bThirdPerson[client] = true;
	CPrintToChat(client, "\x03[ThirdPerson]\x01 is {green}ON{default}.");
}

void ThirdPersonOff(int client)
{
	if(!g_bThirdPerson[client])
		return;

	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
	SetEntProp(client, Prop_Send, "m_iFOV", 90);

	ClientFullUpdate(client);

	g_bThirdPerson[client] = false;
	CPrintToChat(client, "\x03[ThirdPerson]\x01 is {red}OFF{default}.");
}
