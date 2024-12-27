#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

public Plugin myinfo =
{
	name = "sv_gravity fix",
	author = "BotoX",
	description = "Resets sv_gravity at game_end and prevents stupid admins from crashing your server.",
	version = "1.1",
	url = ""
};

ConVar g_ConVar_SvGravity;

public void OnPluginStart()
{
	g_ConVar_SvGravity = FindConVar("sv_gravity");
	g_ConVar_SvGravity.AddChangeHook(OnConVarChanged);
}

public void OnMapEnd()
{
	g_ConVar_SvGravity.IntValue = 800;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar.IntValue < 1)
	{
		convar.IntValue = 800;
		for(int i = 0; i < 10; i++)
			PrintToChatAll("Setting sv_gravity to values less than 1 will crash the server!!!");
	}
}
