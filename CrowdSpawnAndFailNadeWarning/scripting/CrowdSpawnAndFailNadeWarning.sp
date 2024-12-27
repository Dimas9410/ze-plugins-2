#include <sourcemod>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

/* CONVARS */
Handle g_cvWeapons;
ConVar g_cvCrowdSpawnWarningEnabled;
ConVar g_cvFailNadeWarningEnabled;
ConVar g_cvFailNadeThreshold;

/* STRINGS */
char sWeaponsPath[PLATFORM_MAX_PATH] = "configs/zr/weapons.txt";

/* BOOLEAN */
bool g_bFailNade;

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin myinfo =
{
	name         = "CrowdSpawn- & FailNade-Warning",
	author       = "Neon",
	description  = "",
	version      = "1.0.0",
	url          = "https://steamcommunity.com/id/n3ontm"
};
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnPluginStart()
{
	g_cvCrowdSpawnWarningEnabled = CreateConVar("sm_crowdspawn_warning", "1", "", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvFailNadeWarningEnabled = CreateConVar("sm_failnade_warning", "1", "", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvFailNadeThreshold = CreateConVar("sm_failnade_threshold", "2", "", FCVAR_NONE, true, 0.0, true, 100.0);

	RegConsoleCmd("sm_failnade", Command_FailNade, "Check whether FailNades are enabled or not.");
	RegConsoleCmd("sm_failnades", Command_FailNade, "Check whether FailNades are enabled or not.");

	HookEvent("round_start", OnRoundStart);

	AutoExecConfig();
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnAllPluginsLoaded()
{
	if((g_cvWeapons = FindConVar("zr_config_path_weapons")) == INVALID_HANDLE)
		SetFailState("Failed to find zr_config_path_weapons cvar.");

	HookConVarChange(g_cvWeapons, OnWeaponsPathChange);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnRoundStart(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	CreateTimer(5.0, OnRoundStartPostCrowdSpawn, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(8.0, OnRoundStartPostFailNade, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action OnRoundStartPostCrowdSpawn(Handle timer)
{
	if (!GetConVarBool(FindConVar("zr_infect_mzombie_respawn")) && GetConVarBool(g_cvCrowdSpawnWarningEnabled))
	{
		CPrintToChatAll("{red}[WARNING] {white}Zombies will be spawning {red}inbetween {white}the humans!!!");
		CPrintToChatAll("{red}[WARNING] {white}Zombies will be spawning {red}inbetween {white}the humans!!!");
		CPrintToChatAll("{red}[WARNING] {white}Zombies will be spawning {red}inbetween {white}the humans!!!");
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action OnRoundStartPostFailNade(Handle timer)
{
	if (g_bFailNade && GetConVarBool(g_cvFailNadeWarningEnabled))
	{
		CPrintToChatAll("{red}[WARNING] {white}FailNades are {red}enabled {white}!!!");
		CPrintToChatAll("{red}[WARNING] {white}FailNades are {red}enabled {white}!!!");
		CPrintToChatAll("{red}[WARNING] {white}FailNades are {red}enabled {white}!!!");
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnWeaponsPathChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	strcopy(sWeaponsPath, sizeof(sWeaponsPath), newValue);
	OnConfigsExecuted();
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
void OnConfigsExecuted()
{
	g_bFailNade = false;

	char sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, sizeof(sFile), "%s", sWeaponsPath);

	if(!FileExists(sFile))
	{
		LogMessage("Could not find file: \"%s\"", sFile);
		return;
	}

	KeyValues Weapons = new KeyValues("weapons");

	if(!Weapons.ImportFromFile(sFile))
	{
		LogMessage("Unable to load file: \"%s\"", sFile);
		delete Weapons;
		return;
	}

	if(!Weapons.GotoFirstSubKey(true))
	{
		LogMessage("Unable to goto first sub key: \"%s\"", sFile);
		delete Weapons;
		return;
	}

	bool bFound = false;
	char sWeapon[64];
	float fKB;
	do
	{
		if(!Weapons.GetSectionName(sWeapon, sizeof(sWeapon)))
		{
			LogMessage("Unable to get section name: \"%s\"", sFile);
			delete Weapons;
			return;
		}

		if (StrEqual(sWeapon, "HEGrenade", false))
		{
			fKB = Weapons.GetFloat("knockback", 0.0);
			bFound = true;
			break;
		}
	} while(Weapons.GotoNextKey(true));

	if ((bFound) && (fKB >= GetConVarFloat(g_cvFailNadeThreshold)))
		g_bFailNade = true;

	delete Weapons;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Command_FailNade(int client, int args)
{
	if (g_bFailNade)
		CPrintToChat(client, "{GREEN}[ZR] {white}FailNades are currently {red}enabled{white}!");
	else
		CPrintToChat(client, "{GREEN}[ZR] {white}FailNades are currently {green}disabled{white}!");
	return Plugin_Handled;
}