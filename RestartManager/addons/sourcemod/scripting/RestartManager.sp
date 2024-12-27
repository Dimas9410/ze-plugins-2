#include <sourcemod>
#include <files>
#include <mapchooser_extended>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

float g_fCumulativeUptime;

bool g_bRestart;

ConVar g_cvarDefaultMap;
ConVar g_cvarMaxUptime;

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin myinfo =
{
	name        = "RestartManager",
	author      = "Dogan + Neon",
	description = "Display Server Uptime and do controlled Restarts",
	version     = "2.0.0",
	url         = ""
};

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnPluginStart()
{
	RegAdminCmd("uptime", Command_Uptime, ADMFLAG_GENERIC, "Displays server Uptime");
	RegAdminCmd("sm_uptime", Command_Uptime, ADMFLAG_GENERIC, "Displays server Uptime");
	RegAdminCmd("sm_forcerestart", Command_ForceRestart, ADMFLAG_RCON, "Force-restarts the server");

	g_cvarDefaultMap = CreateConVar("sm_defaultmap", "ze_atix_panic_b3t", "default map of the server");
	g_cvarMaxUptime = CreateConVar("sm_maxuptime", "68", "Uptime in hours after which the server should be restarted", FCVAR_NONE);
	AutoExecConfig(true);

	GetUptimeIfControlledRestart();


	RegServerCmd("changelevel", BlockMapSwitch);

	CreateTimer(60.0, CheckForRestart, _, TIMER_REPEAT);
	CreateTimer(60.0, ForceRestartMessage, _, TIMER_REPEAT);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnConfigsExecuted()
{
	char sDefaultMap[64];
	g_cvarDefaultMap.GetString(sDefaultMap, sizeof(sDefaultMap));
	SetStartMap(sDefaultMap);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Command_ForceRestart(int client, int args)
{
	if(client == 0)
	{
		char sMap[64];
		GetCurrentMap(sMap, sizeof(sMap));

		PrepareRestart(sMap, client, true);
		return Plugin_Handled;
	}

	ReplyToCommand(client, "[SM] Confirm the force-restart please!");
	OpenAdminPanel(client);

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Command_Uptime(int client, int args)
{
	float fUptime = GetEngineTime();
	char sUptime[64];
	int iUptime = RoundFloat(fUptime);

	int iDays    	= (iUptime / 86400);
	int iHours   	= (iUptime / 3600) % 24;
	int iMinutes	= (iUptime / 60) % 60;
	int iSeconds	= (iUptime % 60);

	if (iDays)
		Format(sUptime, sizeof(sUptime), "%d Days %d Hours %d Minutes %d Seconds.", iDays, iHours, iMinutes, iSeconds);
	else if (iHours)
		Format(sUptime, sizeof(sUptime), "%d Hours %d Minutes %d Seconds.", iHours, iMinutes, iSeconds);
	else if (iMinutes)
		Format(sUptime, sizeof(sUptime), "%d Minutes %d Seconds.", iMinutes, iSeconds);
	else
		Format(sUptime, sizeof(sUptime), "%d Seconds.", iSeconds);

	ReplyToCommand(client, "[SM] Real Server Uptime: %s", sUptime);

	fUptime = GetEngineTime() + g_fCumulativeUptime;
	iUptime = RoundFloat(fUptime);

	iDays    = (iUptime / 86400);
	iHours   = (iUptime / 3600) % 24;
	iMinutes = (iUptime / 60) % 60;
	iSeconds = (iUptime % 60);

	if (iDays)
		Format(sUptime, sizeof(sUptime), "%d Days %d Hours %d Minutes %d Seconds.", iDays, iHours, iMinutes, iSeconds);
	else if (iHours)
		Format(sUptime, sizeof(sUptime), "%d Hours %d Minutes %d Seconds.", iHours, iMinutes, iSeconds);
	else if (iMinutes)
		Format(sUptime, sizeof(sUptime), "%d Minutes %d Seconds.", iMinutes, iSeconds);
	else
		Format(sUptime, sizeof(sUptime), "%d Seconds.", iSeconds);

	ReplyToCommand(client, "[SM] Cumulative Server Uptime: %s", sUptime);

	IsItTimeToRestartForced();
	if (g_bRestart)
		ReplyToCommand(client, "[SM] Server is going to restart on next mapswitch.");
	else
		ReplyToCommand(client, "[SM] Time until next force-restart: %.2fh.", ((g_cvarMaxUptime.FloatValue * 3600.0) - GetEngineTime()) / 3600.0);

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OpenAdminPanel(int client)
{
	Menu menu = new Menu(MenuHandler_MainMenu);

	menu.SetTitle("Are you sure you want to force-restart the server?", client);

	char sBuffer[32];

	Format(sBuffer, sizeof(sBuffer), "Yes.");
	menu.AddItem("0", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "No.");
	menu.AddItem("1", sBuffer);

	menu.Display(client, MENU_TIME_FOREVER);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int MenuHandler_MainMenu(Menu menu, MenuAction action, int client, int selection)
{
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	switch(action)
	{
		case(MenuAction_Select):
		{
			switch(selection)
			{
				case(0): PrepareRestart(sMap, client, true);
				case(1): PrintToChat(client, "[SM] You declined the force-restart.");
			}
		}
		case(MenuAction_Cancel):
		{
			PrintToChat(client, "[SM] You declined the force-restart.");
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action CheckForRestart(Handle timer)
{
	int iPlayers = GetClientCount(false);
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsFakeClient(i))
			iPlayers--;
	}

	if((iPlayers <= 1) && IsItTimeToRestartNight())
	{
		PrepareRestartNight();
		return Plugin_Stop;
	}

	if(IsItTimeToRestartForced())
		return Plugin_Stop;

	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock bool IsItTimeToRestartNight()
{
	if (GetEngineTime() < (3600 * 12))
		return false;

	int iTime = GetTime();
	int iHour;
	char sTime[32];

	FormatTime(sTime, sizeof(sTime), "%H", iTime);

	iHour = StringToInt(sTime[0]);

	if (iHour >= 3 && iHour < 8)
		return true;

	return false;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public bool IsItTimeToRestartForced()
{
	if(g_bRestart)
		return true;

	if(GetEngineTime() < (g_cvarMaxUptime.FloatValue * 3600.0))
		return false;

	g_bRestart = true;
	return true;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void PrepareRestart(char[] sMap, int client, bool bAdmin)
{
	g_fCumulativeUptime += GetEngineTime();

	char sUptime[64];
	FloatToString(g_fCumulativeUptime, sUptime, sizeof(sUptime));
	File UptimeFile = OpenFile("uptime.txt", "w");
	UptimeFile.WriteLine(sUptime);
	delete UptimeFile;

	if(sMap[0])
	{
		char sMapFile[68];
		Format(sMapFile, sizeof(sMapFile), "map %s", sMap);
		DeleteFile("cfg/defaultmap.cfg");
		File NextmapFile = OpenFile("cfg/defaultmap.cfg", "w");
		NextmapFile.WriteLine(sMapFile);
		delete NextmapFile;
	}

	if(bAdmin)
	{
		LogToFile("addons/sourcemod/logs/restarts.log", "%N successfully force-restarted the Server.", client);
		PrintToChat(client, "[SM] You confirmed the force-restart.");

		CPrintToChatAll("{red}WARNING:{white} Restarting Server in 8 Seconds!");
		CPrintToChatAll("{red}WARNING:{white} Restarting Server in 8 Seconds");
		CPrintToChatAll("{red}WARNING:{white} You may disconnect, reconnect if necessary!");
		PrintCenterTextAll("WARNING: Restarting Server in 8 Seconds.");

		Panel hNotifyPanel = new Panel(GetMenuStyleHandle(MenuStyle_Radio));
		hNotifyPanel.DrawItem("WARNING: Restarting Server in 8 Seconds.", ITEMDRAW_RAWLINE);
		hNotifyPanel.DrawItem("", ITEMDRAW_SPACER);
		hNotifyPanel.DrawItem("IMPORTANT: You may disconnect, reconnect if necessary!", ITEMDRAW_RAWLINE);
		for(int i = 1; i <= MaxClients; i++)
		{
			hNotifyPanel.Send(client, MenuHandler_NotifyPanel, 8);
		}
		delete hNotifyPanel;

		CreateTimer(8.0, AdminForceRestart);
	}
	else
	{
		SimulateMapEnd();
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientConnected(i) && !IsFakeClient(i))
				ClientCommand(i, "retry");
		}

		LogToFile("addons/sourcemod/logs/restarts.log", "Successfully force-restarted the Server.");
		RequestFrame(Restart);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
int MenuHandler_NotifyPanel(Menu hMenu, MenuAction iAction, int iParam1, int iParam2)
{
	switch (iAction)
	{
		case MenuAction_Select, MenuAction_Cancel:
			delete hMenu;
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void PrepareRestartNight()
{
	g_fCumulativeUptime += GetEngineTime();

	char sUptime[64];
	FloatToString(g_fCumulativeUptime, sUptime, sizeof(sUptime));
	File UptimeFile = OpenFile("uptime.txt", "w");
	UptimeFile.WriteLine(sUptime);
	delete UptimeFile;

	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	char sMapFile[68];
	Format(sMapFile, sizeof(sMapFile), "map %s", sMap);
	DeleteFile("cfg/defaultmap.cfg");
	File NextmapFile = OpenFile("cfg/defaultmap.cfg", "w");
	NextmapFile.WriteLine(sMapFile);
	delete NextmapFile;

	SimulateMapEnd();
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && !IsFakeClient(i))
			ClientCommand(i, "retry");
	}
	LogToFile("addons/sourcemod/logs/restarts.log", "Successfully night-restarted the Server.");
	RequestFrame(Restart);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void Restart()
{
	ServerCommand("_restart");
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action BlockMapSwitch(int args)
{
	if (!g_bRestart)
		return Plugin_Continue;

	char sMap[64];
	GetCmdArg(1, sMap, sizeof(sMap));
	PrepareRestart(sMap, 0, false);
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void GetUptimeIfControlledRestart()
{
	File UptimeFile = OpenFile("uptime.txt", "r");

	if(UptimeFile != null)//Server was restarted automatically by this plugin or an admin
	{
		char sUptime[64];
		UptimeFile.ReadLine(sUptime, sizeof(sUptime));
		g_fCumulativeUptime = StringToFloat(sUptime);
		delete UptimeFile;
		DeleteFile("uptime.txt");
	}
	else//Server crashed or restarted manually
		LogToFile("addons/sourcemod/logs/restarts.log", "Server crashed.");
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void SetStartMap(char[] sMap)
{
	DeleteFile("cfg/defaultmap.cfg");
	char sMapFile[64];
	Format(sMapFile, sizeof(sMapFile), "map %s", sMap);
	File NextmapFile = OpenFile("cfg/defaultmap.cfg", "w");
	NextmapFile.WriteLine(sMapFile);
	delete NextmapFile;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action ForceRestartMessage(Handle timer)
{
	if(!g_bRestart)
		return Plugin_Continue;

	CPrintToChatAll("{red}WARNING:{white} Restarting Server when this Map ends!");
	CPrintToChatAll("{red}WARNING:{white} Restarting Server when this Map ends!");
	CPrintToChatAll("{red}WARNING:{white} You may disconnect, reconnect if necessary!");

	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action AdminForceRestart(Handle timer)
{
	SimulateMapEnd();
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && !IsFakeClient(i))
			ClientCommand(i, "retry");
	}

	RequestFrame(Restart);

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock int IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
		return false;

	return IsClientInGame(client);
}