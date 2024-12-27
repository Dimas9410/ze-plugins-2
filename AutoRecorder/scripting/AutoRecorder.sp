#pragma semicolon 1
#include <sourcemod>

ConVar g_hTvEnabled;
ConVar g_hAutoRecord;
ConVar g_hMinPlayersStart;
ConVar g_hIgnoreBots;
ConVar g_hTimeStart;
ConVar g_hTimeStop;
ConVar g_hFinishMap;
ConVar g_hDemoPath;
ConVar g_hMaxLength;

bool g_bIsRecording = false;
bool g_bIsManual = false;

int g_iStartedRecording;

// Default: o=rx,g=rx,u=rwx | 755
#define DIRECTORY_PERMISSIONS (FPERM_O_READ|FPERM_O_EXEC | FPERM_G_READ|FPERM_G_EXEC | FPERM_U_READ|FPERM_U_WRITE|FPERM_U_EXEC)

public Plugin myinfo =
{
	name = "Auto Recorder",
	author = "Stevo.TVR",
	description = "Automates SourceTV recording based on player count and time of day.",
	version = "1.2.0",
	url = "http://www.theville.org"
}

public void OnPluginStart()
{
	g_hAutoRecord = CreateConVar("sm_autorecord_enable", "1", "Enable automatic recording", _, true, 0.0, true, 1.0);
	g_hMinPlayersStart = CreateConVar("sm_autorecord_minplayers", "4", "Minimum players on server to start recording", _, true, 0.0);
	g_hIgnoreBots = CreateConVar("sm_autorecord_ignorebots", "1", "Ignore bots in the player count", _, true, 0.0, true, 1.0);
	g_hTimeStart = CreateConVar("sm_autorecord_timestart", "-1", "Hour in the day to start recording (0-23, -1 disables)");
	g_hTimeStop = CreateConVar("sm_autorecord_timestop", "-1", "Hour in the day to stop recording (0-23, -1 disables)");
	g_hFinishMap = CreateConVar("sm_autorecord_finishmap", "1", "If 1, continue recording until the map ends", _, true, 0.0, true, 1.0);
	g_hDemoPath = CreateConVar("sm_autorecord_path", "demos/", "Path to store recorded demos");
	g_hMaxLength = CreateConVar("sm_autorecord_maxlength", "0", "Maximum length of demos in seconds, 0 to disable", _, true, 0.0);

	AutoExecConfig(true, "autorecorder");

	RegAdminCmd("sm_record", Command_Record, ADMFLAG_KICK, "Starts a SourceTV demo");
	RegAdminCmd("sm_stoprecord", Command_StopRecord, ADMFLAG_KICK, "Stops the current SourceTV demo");

	HookEvent("round_start", OnRoundStart);

	g_hTvEnabled = FindConVar("tv_enable");

	static char sPath[PLATFORM_MAX_PATH];
	GetConVarString(g_hDemoPath, sPath, sizeof(sPath));

	if(!DirExists(sPath))
		CreateDirectory(sPath, DIRECTORY_PERMISSIONS);

	HookConVarChange(g_hMinPlayersStart, OnConVarChanged);
	HookConVarChange(g_hIgnoreBots, OnConVarChanged);
	HookConVarChange(g_hTimeStart, OnConVarChanged);
	HookConVarChange(g_hTimeStop, OnConVarChanged);
	HookConVarChange(g_hDemoPath, OnConVarChanged);

	CreateTimer(300.0, Timer_CheckStatus, _, TIMER_REPEAT);

	StopRecord();
	CheckStatus();
}

public void OnRoundStart(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	int maxLength = GetConVarInt(g_hMaxLength);
	if(g_bIsRecording && maxLength > 0 && GetTime() >= g_iStartedRecording + maxLength)
	{
		StopRecord();
		CheckStatus();
	}
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar == g_hDemoPath)
	{
		if(!DirExists(newValue))
			CreateDirectory(newValue, DIRECTORY_PERMISSIONS);
	}
	else
		CheckStatus();
}

public void OnMapEnd()
{
	if(g_bIsRecording)
	{
		StopRecord();
		g_bIsManual = false;
	}
}

public void OnClientPutInServer(int client)
{
	CheckStatus();
}

public void OnClientDisconnect_Post(int client)
{
	CheckStatus();
}

public Action Timer_CheckStatus(Handle hTimer)
{
	CheckStatus();
}

public Action Command_Record(int client, int args)
{
	if(g_bIsRecording)
	{
		ReplyToCommand(client, "[SM] SourceTV is already recording!");
		return Plugin_Handled;
	}

	StartRecord();
	g_bIsManual = true;

	ReplyToCommand(client, "[SM] SourceTV is now recording...");

	return Plugin_Handled;
}

public Action Command_StopRecord(int client, int args)
{
	if(!g_bIsRecording)
	{
		ReplyToCommand(client, "[SM] SourceTV is not recording!");
		return Plugin_Handled;
	}

	StopRecord();

	if(g_bIsManual)
	{
		g_bIsManual = false;
		CheckStatus();
	}

	ReplyToCommand(client, "[SM] Stopped recording.");

	return Plugin_Handled;
}

void CheckStatus()
{
	if(GetConVarBool(g_hAutoRecord) && !g_bIsManual)
	{
		int iMinClients = GetConVarInt(g_hMinPlayersStart);

		int iTimeStart = GetConVarInt(g_hTimeStart);
		int iTimeStop = GetConVarInt(g_hTimeStop);
		bool bReverseTimes = (iTimeStart > iTimeStop);

		static char sCurrentTime[4];
		FormatTime(sCurrentTime, sizeof(sCurrentTime), "%H", GetTime());
		int iCurrentTime = StringToInt(sCurrentTime);

		if(GetPlayerCount() >= iMinClients+1 && (iTimeStart < 0 || (iCurrentTime >= iTimeStart && (bReverseTimes || iCurrentTime < iTimeStop))))
		{
			StartRecord();
		}
		else if(g_bIsRecording && !GetConVarBool(g_hFinishMap) && (iTimeStop < 0 || iCurrentTime >= iTimeStop))
		{
			StopRecord();
		}
	}
}

int GetPlayerCount()
{
	if(!GetConVarBool(g_hIgnoreBots))
		return GetClientCount(false) - 1;

	int iNumPlayers = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && !IsFakeClient(i))
			iNumPlayers++;
	}

	return iNumPlayers;
}

void StartRecord()
{
	if(GetConVarBool(g_hTvEnabled) && !g_bIsRecording)
	{
		static char sPath[PLATFORM_MAX_PATH];
		static char sMap[PLATFORM_MAX_PATH];
		static char sTime[16];

		GetConVarString(g_hDemoPath, sPath, sizeof(sPath));
		FormatTime(sTime, sizeof(sTime), "%Y%m%d-%H%M%S", GetTime());
		GetCurrentMap(sMap, sizeof(sMap));

		// replace slashes in map path name with dashes, to prevent fail on workshop maps
		ReplaceString(sMap, sizeof(sMap), "/", "-", false);

		ServerCommand("tv_record \"%s/auto-%s-%s\"", sPath, sTime, sMap);
		g_bIsRecording = true;
		g_iStartedRecording = GetTime();

		LogMessage("Recording to auto-%s-%s.dem", sTime, sMap);
	}
}

void StopRecord()
{
	if(GetConVarBool(g_hTvEnabled))
	{
		ServerCommand("tv_stoprecord");
		g_bIsRecording = false;
	}
}
