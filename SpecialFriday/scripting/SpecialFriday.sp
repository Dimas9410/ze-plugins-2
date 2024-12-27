#pragma semicolon 1

#include <sourcemod>

#include "nominations_extended.inc"

#pragma newdecls required

char g_sExtraMapsPath[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = "Special Friday",
	author = "Obus",
	description = "",
	version = "",
	url = ""
};

public void OnPluginStart()
{
	BuildPath(Path_SM, g_sExtraMapsPath, sizeof(g_sExtraMapsPath), "configs/specialfriday.cfg");

	if (!FileExists(g_sExtraMapsPath))
		LogMessage("configs/specialfriday.cfg missing, is this intended?");
}

public void OnConfigsExecuted()
{
	CreateTimer(5.0, Timer_PostOnConfigsExecuted, TIMER_FLAG_NO_MAPCHANGE, _);
}

public Action Timer_PostOnConfigsExecuted(Handle hThis)
{
	if (!FileExists(g_sExtraMapsPath))
		SetFailState("configs/specialfriday.cfg missing!");

	if (IsItFridayTime())
	{
		ArrayList hExtraMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
		File hExtraMapsConfig = OpenFile(g_sExtraMapsPath, "r");

		while (!hExtraMapsConfig.EndOfFile())
		{
			char sLine[128];

			if (!hExtraMapsConfig.ReadLine(sLine, sizeof(sLine)))
				break;

			if (strncmp(sLine, "//", 2) == 0)
				continue;

			int iCurIndex=0;
			while (sLine[iCurIndex] != '\0')
			{
				if (sLine[iCurIndex] < 0x20 || sLine[iCurIndex] > 0x7F) sLine[iCurIndex] = '\0';
				iCurIndex++;
			}

			sLine[iCurIndex-1]='\0';

			if (IsMapValid(sLine))
				hExtraMaps.PushString(sLine);
		}

		SortADTArrayCustom(view_as<Handle>(hExtraMaps), SortFuncADTArray_SortAlphabetical);

		PushMapsIntoNominationPool(hExtraMaps);

		delete hExtraMapsConfig;
		delete hExtraMaps;

		CreateTimer(3.0, Timer_LoadConfig, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

int SortFuncADTArray_SortAlphabetical(int idx1, int idx2, Handle hExtraMaps, Handle unk)
{
	char sStr1[PLATFORM_MAX_PATH];
	char sStr2[PLATFORM_MAX_PATH];

	view_as<ArrayList>(hExtraMaps).GetString(idx1, sStr1, sizeof(sStr1));
	view_as<ArrayList>(hExtraMaps).GetString(idx2, sStr2, sizeof(sStr2));

	return strcmp(sStr2, sStr1, false);
}

public Action Timer_LoadConfig(Handle hThis)
{
	ServerCommand("exec specialfriday");
}

stock bool IsItFridayTime()
{
	int iTime = GetTime();
	int iHour;
	char sTime[32];

	FormatTime(sTime, sizeof(sTime), "%w %H", iTime);

	iHour = StringToInt(sTime[2]);

	if ((sTime[0] == '5' && iHour >= 6) || (sTime[0] == '6' && iHour < 6))
		return true;

	return false;
}
