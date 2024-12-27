#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

KeyValues g_Config;
bool g_Enabled = false;

public Plugin myinfo =
{
	name 			= "MapAdmin",
	author 			= "BotoX",
	description 	= "Adminroom teleport and changing stages.",
	version 		= "0.1",
	url 			= ""
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	char sConfigFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), "configs/MapAdmin.cfg");

	if(!FileExists(sConfigFile))
	{
		SetFailState("Could not find config: \"%s\"", sConfigFile);
		return;
	}

	g_Config = new KeyValues("maps");
	if(!g_Config.ImportFromFile(sConfigFile))
	{
		delete g_Config;
		SetFailState("ImportFromFile() failed!");
		return;
	}
	g_Config.Rewind();

	RegAdminCmd("sm_adminroom", Command_AdminRoom, ADMFLAG_GENERIC, "sm_adminroom [#userid|name]");
	RegAdminCmd("sm_stage", Command_Stage, ADMFLAG_GENERIC, "sm_stage <stage>");
}

public void OnMapStart()
{
	g_Enabled = false;
	g_Config.Rewind();

	char sMapName[PLATFORM_MAX_PATH];
	GetCurrentMap(sMapName, sizeof(sMapName));

	if(g_Config.JumpToKey(sMapName, false))
		g_Enabled = true;
}

public Action Command_AdminRoom(int client, int argc)
{
	if(!g_Enabled)
	{
		ReplyToCommand(client, "[SM] The current map is not supported.");
		return Plugin_Handled;
	}

	char sAdminRoom[64];
	g_Config.GetString("adminroom", sAdminRoom, sizeof(sAdminRoom), "");

	if(!sAdminRoom[0])
	{
		ReplyToCommand(client, "[SM] The current map does not have an adminroom (configured).");
		return Plugin_Handled;
	}

	if(argc > 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_adminroom [#userid|name]");
		return Plugin_Handled;
	}

	char sOrigins[3][16];
	ExplodeString(sAdminRoom, " ", sOrigins, sizeof(sOrigins), sizeof(sOrigins[]));

	float fOrigin[3];
	fOrigin[0] = StringToFloat(sOrigins[0]);
	fOrigin[1] = StringToFloat(sOrigins[1]);
	fOrigin[2] = StringToFloat(sOrigins[2]);

	char sArgs[64];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;

	if(argc == 1)
		GetCmdArg(1, sArgs, sizeof(sArgs));
	else
		strcopy(sArgs, sizeof(sArgs), "@me");

	if((iTargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS, COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	for(int i = 0; i < iTargetCount; i++)
	{
		TeleportEntity(iTargets[i], fOrigin, NULL_VECTOR, NULL_VECTOR);
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Teleported \x04%s\x01 to the adminroom.", sTargetName);
	if(iTargetCount > 1)
		LogAction(client, -1, "\"%L\" teleported \"%s\" to the adminroom.", client, sTargetName);
	else
		LogAction(client, iTargets[0], "\"%L\" teleported \"%L\" to the adminroom.", client, iTargets[0]);

	return Plugin_Handled;
}

public Action Command_Stage(int client, int argc)
{
	if(!g_Enabled)
	{
		ReplyToCommand(client, "[SM] The current map is not supported.");
		return Plugin_Handled;
	}

	if(!g_Config.JumpToKey("stages", false))
	{
		ReplyToCommand(client, "[SM] The current map does not have stages (configured).");
		return Plugin_Handled;
	}

	if(!g_Config.GotoFirstSubKey(false))
	{
		ReplyToCommand(client, "[SM] The current map does not have any stages configured.");
		g_Config.GoBack(); // "stages"
		return Plugin_Handled;
	}

	if(argc < 1)
	{
		ReplyToCommand(client, "[SM] Available stages:");

		do
		{
			char sSection[32];
			g_Config.GetSectionName(sSection, sizeof(sSection));

			char sName[64];
			g_Config.GetString("name", sName, sizeof(sName), "MISSING_NAME");

			if(!g_Config.JumpToKey("triggers", false))
			{
				g_Config.GoBack(); // "stages"
				g_Config.GoBack(); // "GotoFirstSubKey"

				ReplyToCommand(client, "Config error in stage \"%s\"(\"%s\"), missing \"triggers\" block.", sSection, sName);
				return Plugin_Handled;
			}

			if(!g_Config.GotoFirstSubKey(false))
			{
				g_Config.GoBack(); // "stages"
				g_Config.GoBack(); // "GotoFirstSubKey"
				g_Config.GoBack(); // "triggers"

				ReplyToCommand(client, "Config error in stage \"%s\"(\"%s\"), empty \"triggers\" block.", sSection, sName);
				return Plugin_Handled;
			}

			char sTriggers[128];
			do
			{
				char sTrigger[32];
				g_Config.GetString(NULL_STRING, sTrigger, sizeof(sTrigger));

				StrCat(sTrigger, sizeof(sTrigger), ", ");
				StrCat(sTriggers, sizeof(sTriggers), sTrigger);
			} while(g_Config.GotoNextKey(false));

			g_Config.GoBack(); // "triggers"
			g_Config.GoBack(); // "GotoFirstSubKey"

			// Remove last ", "
			sTriggers[strlen(sTriggers) - 2] = 0;

			ReplyToCommand(client, "%s: %s", sName, sTriggers);

		} while(g_Config.GotoNextKey(false));

		g_Config.GoBack(); // "stages"
		g_Config.GoBack(); // "GotoFirstSubKey"

		return Plugin_Handled;
	}

	char sArg[64];
	GetCmdArgString(sArg, sizeof(sArg));

	do
	{
		char sSection[32];
		g_Config.GetSectionName(sSection, sizeof(sSection));

		char sName[64];
		g_Config.GetString("name", sName, sizeof(sName), "MISSING_NAME");

		if(!g_Config.JumpToKey("triggers", false))
		{
			g_Config.GoBack(); // "stages"
			g_Config.GoBack(); // "GotoFirstSubKey"

			ReplyToCommand(client, "Config error in stage \"%s\"(\"%s\"), missing \"triggers\" block.", sSection, sName);
			return Plugin_Handled;
		}

		if(!g_Config.GotoFirstSubKey(false))
		{
			g_Config.GoBack(); // "stages"
			g_Config.GoBack(); // "GotoFirstSubKey"
			g_Config.GoBack(); // "triggers"

			ReplyToCommand(client, "Config error in stage \"%s\"(\"%s\"), empty \"triggers\" block.", sSection, sName);
			return Plugin_Handled;
		}

		bool bFound = false;
		do
		{
			char sTrigger[32];
			g_Config.GetString(NULL_STRING, sTrigger, sizeof(sTrigger));

			if(StrEqual(sArg, sTrigger, true))
			{
				bFound = true;
				break;
			}

		} while(g_Config.GotoNextKey(false));

		g_Config.GoBack(); // "triggers"
		g_Config.GoBack(); // "GotoFirstSubKey"

		if(!bFound)
			continue;

		ReplyToCommand(client, "Triggering \"%s\"", sName);

		if(!g_Config.JumpToKey("actions", false))
		{
			g_Config.GoBack(); // "stages"
			g_Config.GoBack(); // "GotoFirstSubKey"

			ReplyToCommand(client, "Config error in stage \"%s\"(\"%s\"), missing \"actions\" block.", sSection, sName);
			return Plugin_Handled;
		}

		if(!g_Config.GotoFirstSubKey(false))
		{
			g_Config.GoBack(); // "stages"
			g_Config.GoBack(); // "GotoFirstSubKey"
			g_Config.GoBack(); // "actions"

			ReplyToCommand(client, "Config error in stage \"%s\"(\"%s\"), empty \"actions\" block.", sSection, sName);
			return Plugin_Handled;
		}

		do
		{
			char sAction[256];
			g_Config.GetString(NULL_STRING, sAction, sizeof(sAction));

			int iDelim = FindCharInString(sAction, ':');
			if(iDelim == -1)
			{
				char sActionSection[32];
				g_Config.GetSectionName(sActionSection, sizeof(sActionSection));

				g_Config.GoBack(); // "actions"
				g_Config.GoBack(); // "GotoFirstSubKey"
				g_Config.GoBack(); // "stages"
				g_Config.GoBack(); // "GotoFirstSubKey"

				ReplyToCommand(client, "Config error in stage \"%s\"(\"%s\"), action \"%s\" missing delim ':'.", sSection, sName, sActionSection);
				return Plugin_Handled;
			}

			ReplyToCommand(client, "Firing \"%s\"", sAction);
			sAction[iDelim++] = 0;

			int entity = INVALID_ENT_REFERENCE;
			while((entity = FindEntityByTargetname(entity, sAction, "*")) != INVALID_ENT_REFERENCE)
			{
				AcceptEntityInput(entity, sAction[iDelim], client, client);
			}

		} while(g_Config.GotoNextKey(false));

		g_Config.GoBack(); // "actions"
		g_Config.GoBack(); // "GotoFirstSubKey"

		ShowActivity2(client, "\x01[SM] \x04", "\x01Changed the stage to \x04%s\x01.", sName);
		LogAction(client, -1, "\"%L\" changed the stage to \"%s\".", client, sName);

		break;
	} while(g_Config.GotoNextKey(false));

	g_Config.GoBack(); // "stages"
	g_Config.GoBack(); // "GotoFirstSubKey"

	return Plugin_Handled;
}

int FindEntityByTargetname(int entity, const char[] sTargetname, const char[] sClassname="*")
{
	if(sTargetname[0] == '#') // HammerID
	{
		int HammerID = StringToInt(sTargetname[1]);

		while((entity = FindEntityByClassname(entity, sClassname)) != INVALID_ENT_REFERENCE)
		{
			if(GetEntProp(entity, Prop_Data, "m_iHammerID") == HammerID)
				return entity;
		}
	}
	else // Targetname
	{
		int Wildcard = FindCharInString(sTargetname, '*');
		char sTargetnameBuf[64];

		while((entity = FindEntityByClassname(entity, sClassname)) != INVALID_ENT_REFERENCE)
		{
			if(GetEntPropString(entity, Prop_Data, "m_iName", sTargetnameBuf, sizeof(sTargetnameBuf)) <= 0)
				continue;

			if(strncmp(sTargetnameBuf, sTargetname, Wildcard) == 0)
				return entity;
		}
	}

	return INVALID_ENT_REFERENCE;
}
