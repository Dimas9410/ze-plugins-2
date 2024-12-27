#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

bool g_bIsAdmin[MAXPLAYERS + 1] = {false, ...};

public Plugin myinfo =
{
	name 			= "AdminIcon",
	author 			= "BotoX",
	description 	= "Gives admins a defuser.",
	version 		= "1.0",
	url 			= ""
};

public void OnPluginStart()
{
	for(int client = 1; client <= MaxClients; client++)
	{
		g_bIsAdmin[client] = false;
		if(IsClientInGame(client) && !IsFakeClient(client) && IsClientAuthorized(client))
			OnClientPostAdminCheck(client);
	}
}

public void OnClientConnected(int client)
{
	g_bIsAdmin[client] = false;
}

public void OnClientDisconnect(int client)
{
	g_bIsAdmin[client] = false;
}

public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client))
		return;

	if(GetAdminFlag(GetUserAdmin(client), Admin_Generic))
		g_bIsAdmin[client] = true;
}

public void OnGameFrame()
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(g_bIsAdmin[client])
		{
			if(IsClientObserver(client))
				SetEntProp(client, Prop_Send, "m_bHasDefuser", 0);
			else
				SetEntProp(client, Prop_Send, "m_bHasDefuser", 1);
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(IsValidEntity(entity) && StrEqual(classname, "item_defuser"))
	{
		SDKHook(entity, SDKHook_Spawn, OnWeaponSpawned);
	}
}

public void OnWeaponSpawned(int entity)
{
	AcceptEntityInput(entity, "Kill");
}
