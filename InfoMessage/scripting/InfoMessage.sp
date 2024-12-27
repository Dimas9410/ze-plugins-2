#include <sourcemod>

#define MAXLINES 20

#pragma newdecls required

/* CONVARS */
ConVar g_cvInfoMessageFile;

/* STRINGS */
char g_sBuffer[MAXLINES][192];

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin myinfo =
{
	name         = "InfoMessage",
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
	g_cvInfoMessageFile = CreateConVar("sm_info_message_file", "null", "", FCVAR_NONE);
	HookConVarChange(g_cvInfoMessageFile, Cvar_FileChanged);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void Cvar_FileChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int i = 0; i <= (MAXLINES - 1); i++)
		g_sBuffer[i] = "";

	char sFile[PLATFORM_MAX_PATH];
	char sLine[192];
	char sFilename[192];
	GetConVarString(g_cvInfoMessageFile, sFilename, sizeof(sFilename))

	if (StrEqual(sFilename, "null"))
		return;

	BuildPath(Path_SM, sFile, sizeof(sFile), "configs/info_messages/%s.txt", sFilename);

	Handle hFile = OpenFile(sFile, "r");

	if(hFile != INVALID_HANDLE)
	{
		int iLine = 0;
		while (!IsEndOfFile(hFile))
		{
			if (!ReadFileLine(hFile, sLine, sizeof(sLine)))
				break;

			TrimString(sLine);
			g_sBuffer[iLine] = sLine;
			iLine++;
		}

	CloseHandle(hFile);

	}
	else
	{
		LogError("[SM] File not found! (configs/info_messages/%s.txt)", sFilename);
	}


	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

	OnClientPutInServer(i);
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
public void OnClientPutInServer(int client)
{
	char sFilename[192];
	GetConVarString(g_cvInfoMessageFile, sFilename, sizeof(sFilename))

	if (StrEqual(sFilename, "null"))
		return;

	Panel hNotifyPanel = new Panel(GetMenuStyleHandle(MenuStyle_Radio));

	for (int i = 0; i <= (MAXLINES - 1); i++)
	{
		if (StrEqual(g_sBuffer[i], ""))
			break;

		if (StrEqual(g_sBuffer[i], "/n"))
		{
			hNotifyPanel.DrawItem("", ITEMDRAW_SPACER);
		}
		else
			hNotifyPanel.DrawItem(g_sBuffer[i], ITEMDRAW_RAWLINE);
	}

	hNotifyPanel.SetKeys(1023);
	hNotifyPanel.Send(client, MenuHandler_NotifyPanel, 0);
	delete hNotifyPanel;
}