#include <sourcemod>
#include <cstrike>

#pragma semicolon 1
#pragma newdecls required

#define MIN_PLAYERS 2

Handle g_hWarmupEndFwd;

int g_iWarmup = 0;
bool g_bWarmup = false;
ConVar g_CVar_sm_warmuptime;
ConVar g_CVar_sm_warmupratio;

bool g_bRoundEnded = false;
bool g_bZombieSpawned = false;
int g_TeamChangeQueue[MAXPLAYERS + 1] = { -1, ... };

public Plugin myinfo =
{
	name = "TeamManager",
	author = "BotoX",
	description = "",
	version = "1.0",
	url = "https://github.com/CSSZombieEscape/sm-plugins/tree/master/TeamManager"
};

public APLRes AskPluginLoad2(Handle hThis, bool bLate, char[] err, int iErrLen)
{
	CreateNative("TeamManager_InWarmup", Native_InWarmup);

	RegPluginLibrary("TeamManager");

	return APLRes_Success;
}

public void OnPluginStart()
{
	if (GetEngineVersion() == Engine_CSGO)
		AddCommandListener(OnJoinTeamCommand, "joingame");

	AddCommandListener(OnJoinTeamCommand, "jointeam");
	HookEvent("round_start", OnRoundStart, EventHookMode_Pre);
	HookEvent("round_end", OnRoundEnd, EventHookMode_PostNoCopy);

	g_CVar_sm_warmuptime = CreateConVar("sm_warmuptime", "10", "Warmup timer.", 0, true, 0.0, true, 60.0);
	g_CVar_sm_warmupratio = CreateConVar("sm_warmupratio", "0.60", "Ratio of connected players that need to be in game to start warmup timer.", 0, true, 0.0, true, 1.0);

	g_hWarmupEndFwd = CreateGlobalForward("TeamManager_WarmupEnd", ET_Ignore);

	AutoExecConfig(true, "plugin.TeamManager");
}

public void OnMapStart()
{
	g_iWarmup = 0;
	g_bWarmup = false;
	g_bRoundEnded = false;
	g_bZombieSpawned = false;

	if(g_CVar_sm_warmuptime.IntValue > 0 || g_CVar_sm_warmupratio.FloatValue > 0.0)
	{
		g_bWarmup = true;
		CreateTimer(1.0, OnWarmupTimer, 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action OnWarmupTimer(Handle timer)
{
	if(g_CVar_sm_warmupratio.FloatValue > 0.0)
	{
		int ClientsConnected = GetClientCount(false);
		int ClientsInGame = GetClientCount(true);
		int ClientsNeeded = RoundToCeil(float(ClientsConnected) * g_CVar_sm_warmupratio.FloatValue);
		ClientsNeeded = ClientsNeeded > MIN_PLAYERS ? ClientsNeeded : MIN_PLAYERS;

		if(ClientsInGame < ClientsNeeded)
		{
			g_iWarmup = 0;
			PrintCenterTextAll("Warmup: Waiting for %d more players to join.", ClientsNeeded - ClientsInGame);
			return Plugin_Continue;
		}
	}

	if(g_iWarmup >= g_CVar_sm_warmuptime.IntValue)
	{
		g_iWarmup = 0;
		g_bWarmup = false;
		float fDelay = 3.0;
		CS_TerminateRound(fDelay, CSRoundEnd_GameStart, false);
		CreateTimer(fDelay, Timer_FireForward, _, TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Stop;
	}

	PrintCenterTextAll("Warmup: %d", g_CVar_sm_warmuptime.IntValue - g_iWarmup);
	g_iWarmup++;

	return Plugin_Continue;
}

public Action Timer_FireForward(Handle hThis)
{
	Call_StartForward(g_hWarmupEndFwd);
	Call_Finish();
	return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
	g_TeamChangeQueue[client] = -1;
}

public Action OnJoinTeamCommand(int client, const char[] command, int argc)
{
	if(client < 1 || client >= MaxClients || !IsClientInGame(client))
		return Plugin_Continue;

	if(StrEqual(command, "joingame", false))
	{
		if(GetClientTeam(client) != CS_TEAM_NONE)
			return Plugin_Continue;

		ShowVGUIPanel(client, "team");
		return Plugin_Handled;
	}

	char sArg[8];
	GetCmdArg(1, sArg, sizeof(sArg));

	int CurrentTeam = GetClientTeam(client);
	int NewTeam = StringToInt(sArg);

	if(NewTeam < CS_TEAM_NONE || NewTeam > CS_TEAM_CT)
		return Plugin_Handled;

	if(g_bRoundEnded)
	{
		if(NewTeam == CS_TEAM_T || NewTeam == CS_TEAM_NONE)
			NewTeam = CS_TEAM_CT;

		if(NewTeam == CurrentTeam)
		{
			if(g_TeamChangeQueue[client] != -1)
			{
				g_TeamChangeQueue[client] = -1;
				PrintCenterText(client, "Team change request canceled.");
			}
			return Plugin_Handled;
		}

		g_TeamChangeQueue[client] = NewTeam;
		PrintCenterText(client, "You will be placed in the selected team shortly.");
		return Plugin_Handled;
	}

	if(!g_bZombieSpawned)
	{
		if(NewTeam == CS_TEAM_T || NewTeam == CS_TEAM_NONE)
			NewTeam = CS_TEAM_CT;
	}
	else if(NewTeam == CS_TEAM_CT || NewTeam == CS_TEAM_NONE)
		NewTeam = CS_TEAM_T;

	if(NewTeam == CurrentTeam)
		return Plugin_Handled;

	ChangeClientTeam(client, NewTeam);
	return Plugin_Handled;
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundEnded = false;
	g_bZombieSpawned = false;

	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client))
			continue;

		int CurrentTeam = GetClientTeam(client);
		int NewTeam = CS_TEAM_CT;

		if(g_TeamChangeQueue[client] != -1)
		{
			NewTeam = g_TeamChangeQueue[client];
			g_TeamChangeQueue[client] = -1;
		}
		else if(CurrentTeam <= CS_TEAM_SPECTATOR)
			continue;

		if(NewTeam == CurrentTeam)
			continue;

		if(NewTeam >= CS_TEAM_T)
			CS_SwitchTeam(client, NewTeam);
		else
			ChangeClientTeam(client, NewTeam);

		if(NewTeam >= CS_TEAM_T && !IsPlayerAlive(client))
			CS_RespawnPlayer(client);
	}
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundEnded = true;
	g_bZombieSpawned = false;
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	if(g_bWarmup)
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action ZR_OnClientInfect(int &client, int &attacker, bool &motherInfect, bool &respawnOverride, bool &respawn)
{
	if(g_bWarmup)
		return Plugin_Handled;

	g_bZombieSpawned = true;

	return Plugin_Continue;
}

public int Native_InWarmup(Handle hPlugin, int numParams)
{
	return g_bWarmup;
}
