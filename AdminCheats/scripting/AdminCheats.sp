#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"
public Plugin myinfo =
{
	name 			= "AdminCheats",
	author 			= "BotoX",
	description 	= "Allows usage of (most) cheat commands for admins.",
	version 		= PLUGIN_VERSION,
	url 			= ""
};

ConVar g_CVar_sv_cheats;

public void OnPluginStart()
{
	g_CVar_sv_cheats = FindConVar("sv_cheats");
	g_CVar_sv_cheats.Flags &= ~FCVAR_NOTIFY;
	g_CVar_sv_cheats.Flags &= ~FCVAR_REPLICATED;
	g_CVar_sv_cheats.AddChangeHook(OnConVarChanged);
	g_CVar_sv_cheats.SetInt(1);

	MakeCheatCommand("give");

	int NumHooks = 0;
	char sConCommand[128];
	bool IsCommand;
	int Flags;
	Handle hSearch = FindFirstConCommand(sConCommand, sizeof(sConCommand), IsCommand, Flags);
	do
	{
		if(IsCommand && Flags & FCVAR_CHEAT)
		{
			AddCommandListener(OnCheatCommand, sConCommand);
			NumHooks++;
		}
	}
	while(FindNextConCommand(hSearch, sConCommand, sizeof(sConCommand), IsCommand, Flags));

	AddCommandListener(OnCheatCommand, "kill"); NumHooks++;
	AddCommandListener(OnCheatCommand, "explode"); NumHooks++;

	PrintToServer("Hooked %d cheat commands.", NumHooks);

	UpdateClients();
}

public void OnPluginEnd()
{
	g_CVar_sv_cheats.SetInt(0);
	g_CVar_sv_cheats.Flags |= FCVAR_NOTIFY;
	g_CVar_sv_cheats.Flags |= FCVAR_REPLICATED;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_CVar_sv_cheats.SetInt(1);
	CreateTimer(0.1, Timer_UpdateClients);
}

public Action Timer_UpdateClients(Handle timer, Handle hndl)
{
	UpdateClients();
}

public void UpdateClients()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && IsClientAuthorized(i))
			OnClientPostAdminCheck(i);
	}
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
		return;

	SendConVarValue(client, g_CVar_sv_cheats, "0");
}

public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client))
		return;

	if(g_CVar_sv_cheats.BoolValue && CheckCommandAccess(client, "", ADMFLAG_CHEATS))
		SendConVarValue(client, g_CVar_sv_cheats, "1");
	else
		SendConVarValue(client, g_CVar_sv_cheats, "0");
}

public Action OnCheatCommand(int client, const char[] command, int argc)
{
	if(client == 0)
		return Plugin_Continue;

	if(IsClientAuthorized(client) && CheckCommandAccess(client, "", ADMFLAG_CHEATS))
		return Plugin_Continue;

	if(!argc && (StrEqual(command, "kill") || StrEqual(command, "explode")))
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!impulse)
		return Plugin_Continue;

	if(impulse == 100 || impulse == 201)
		return Plugin_Continue;

	if(IsClientAuthorized(client) && CheckCommandAccess(client, "", ADMFLAG_CHEATS))
		return Plugin_Continue;

	return Plugin_Handled;
}

stock void MakeCheatCommand(const char[] name)
{
	int Flags = GetCommandFlags(name);
	if(Flags != INVALID_FCVAR_FLAGS)
		SetCommandFlags(name, FCVAR_CHEAT | Flags);
}
