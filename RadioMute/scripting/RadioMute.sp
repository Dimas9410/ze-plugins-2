#pragma semicolon 1

#include <sourcemod>

#pragma newdecls required

bool g_bProtoBuf;
bool g_bBlocked[MAXPLAYERS + 1];

int g_iMessageClient = -1;

public Plugin myinfo =
{
	name		= "RadioMute",
	description	= "Very simple plugin to block players from using the in-game radio in supported games.",
	author		= "Obus",
	version		= "1.0.1",
	url			= ""
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf)
		g_bProtoBuf = true;

	UserMsg RadioText = GetUserMessageId("RadioText");

	if (RadioText == INVALID_MESSAGE_ID)
		SetFailState("This game does not support the \"RadioText\" UserMessage.");

	UserMsg SendAudio = GetUserMessageId("SendAudio");

	if (SendAudio == INVALID_MESSAGE_ID)
		SetFailState("This game does not support the \"SendAudio\" UserMessage.");

	RegAdminCmd("sm_radiomute", Command_RadioMute, ADMFLAG_BAN, "Block a client from using the in-game radio.");
	RegAdminCmd("sm_radiounmute", Command_RadioUnmute, ADMFLAG_BAN, "Unblock a client from using the in-game radio.");

	HookUserMessage(RadioText, _hkRadioText, true);
	HookUserMessage(SendAudio, _hkSendAudio, true);
}

public void OnClientDisconnect(int client)
{
	g_bBlocked[client] = false;
}

public Action Command_RadioMute(int client, int argc)
{
	if (argc < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_radiomute <target>");

		return Plugin_Handled;
	}

	char sArgs[64];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;

	GetCmdArg(1, sArgs, sizeof(sArgs));

	if ((iTargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS, COMMAND_FILTER_CONNECTED, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);

		return Plugin_Handled;
	}

	for (int i = 0; i < iTargetCount; i++)
	{
		g_bBlocked[iTargets[i]] = true;
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Radio muted \x04%s\x01", sTargetName);
	LogAction(client, -1, "\"%L\" radio muted \"%s\"", client, sTargetName);

	return Plugin_Handled;
}

public Action Command_RadioUnmute(int client, int argc)
{
	if (argc < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_radiounmute <target>");

		return Plugin_Handled;
	}

	char sArgs[64];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;

	GetCmdArg(1, sArgs, sizeof(sArgs));

	if ((iTargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS, COMMAND_FILTER_CONNECTED, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);

		return Plugin_Handled;
	}

	for (int i = 0; i < iTargetCount; i++)
	{
		g_bBlocked[iTargets[i]] = false;
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Radio unmuted \x04%s\x01", sTargetName);
	LogAction(client, -1, "\"%L\" radio unmuted \"%s\"", client, sTargetName);

	return Plugin_Handled;
}

public Action _hkRadioText(UserMsg msg_id, Handle bf, const int[] players, int playersNum, bool reliable, bool init)
{
	if (g_bProtoBuf)
	{
		g_iMessageClient = PbReadInt(bf, "client");
	}
	else
	{
		BfReadByte(bf);
		g_iMessageClient = BfReadByte(bf);
	}

	if (g_bBlocked[g_iMessageClient])
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action _hkSendAudio(UserMsg msg_id, Handle bf, const int[] players, int playersNum, bool reliable, bool init)
{
	if (g_iMessageClient == -1)
		return Plugin_Continue;

	char sSound[128];

	if(g_bProtoBuf)
		PbReadString(bf, "radio_sound", sSound, sizeof(sSound));
	else
		BfReadString(bf, sSound, sizeof(sSound), false);

	if (strncmp(sSound[6], "lock", 4, false) == 0)
		return Plugin_Continue;

	if (g_bBlocked[g_iMessageClient])
	{
		g_iMessageClient = -1;

		return Plugin_Handled;
	}

	g_iMessageClient = -1;

	return Plugin_Continue;
}
