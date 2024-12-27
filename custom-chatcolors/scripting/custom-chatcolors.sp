#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <regex>
#include <multicolors>
//#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <ccc>

#define PLUGIN_VERSION		"6.1.4"
#define MAX_CHAT_LENGTH		192

public Plugin myinfo =
{
	name        = "Custom Chat Colors & Tags & Allchat",
	author      = "Dr. McKay, edit by id/Obus, BotoX",
	description = "Processes chat and provides colors & custom tags & allchat & chat ignoring",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

//Handle colorForward;
//Handle nameForward;
//Handle tagForward;
//Handle applicationForward;
Handle messageForward;
Handle preLoadedForward;
Handle loadedForward;
Handle configReloadedForward;
Handle g_hGreenText = null;
Handle g_hReplaceText = null;
//Handle g_hAdminMenu = null;

char g_sTag[MAXPLAYERS + 1][64];
char g_sTagColor[MAXPLAYERS + 1][12];
char g_sUsernameColor[MAXPLAYERS + 1][12];
char g_sChatColor[MAXPLAYERS + 1][12];

char g_sDefaultTag[MAXPLAYERS + 1][32];
char g_sDefaultTagColor[MAXPLAYERS + 1][12];
char g_sDefaultUsernameColor[MAXPLAYERS + 1][12];
char g_sDefaultChatColor[MAXPLAYERS + 1][12];
char g_sColorsArray[120][2][32] = { {"aliceblue", "F0F8FF" }, { "aqua", "00FFFF" }, { "aquamarine", "7FFFD4" }, { "azure", "007FFF" }, { "beige", "F5F5DC" }, { "black", "000000" }, { "blue", "99CCFF" }, { "blueviolet", "8A2BE2" }, { "brown", "A52A2A" }, { "burlywood", "DEB887" }, { "cadetblue", "5F9EA0" }, { "chocolate", "D2691E" }, { "corrupted", "A32C2E" }, { "crimson", "DC143C" }, { "cyan", "00FFFF" }, { "darkblue", "00008B" }, { "darkcyan", "008B8B" }, { "darkgoldenrod", "B8860B" }, { "darkgray", "A9A9A9" }, { "darkgrey", "A9A9A9" }, { "darkgreen", "006400" }, { "darkkhaki", "BDB76B" }, { "darkmagenta", "8B008B" }, { "darkolivegreen", "556B2F" }, { "darkorange", "FF8C00" }, { "darkorchid", "9932CC" }, { "darkred", "8B0000" }, { "darksalmon", "E9967A" }, { "darkseagreen", "8FBC8F" }, { "darkslateblue", "483D8B" }, { "darkturquoise", "00CED1" }, { "darkviolet", "9400D3" }, { "deeppink", "FF1493" }, { "deepskyblue", "00BFFF" }, { "dimgray", "696969" }, { "dodgerblue", "1E90FF" }, { "firebrick", "B22222" }, { "floralwhite", "FFFAF0" }, { "forestgreen", "228B22" }, { "frozen", "4983B3" }, { "fuchsia", "FF00FF" }, { "fullblue", "0000FF" }, { "fullred", "FF0000" }, { "ghostwhite", "F8F8FF" }, { "gold", "FFD700" }, { "gray", "CCCCCC" }, { "green", "3EFF3E" }, { "greenyellow", "ADFF2F" }, { "hotpink", "FF69B4" }, { "indianred", "CD5C5C" }, { "indigo", "4B0082" }, { "ivory", "FFFFF0" }, { "khaki", "F0E68C" }, { "lightblue", "ADD8E6" }, { "lightcoral", "F08080" }, { "lightcyan", "E0FFFF" }, { "lightgoldenrodyellow", "FAFAD2" }, { "lightgray", "D3D3D3" }, { "lightgrey", "D3D3D3" }, { "lightgreen", "99FF99" }, { "lightpink", "FFB6C1" }, { "lightsalmon", "FFA07A" }, { "lightseagreen", "20B2AA" }, { "lightskyblue", "87CEFA" }, { "lightslategray", "778899" }, { "lightslategrey", "778899" }, { "lightsteelblue", "B0C4DE" }, { "lightyellow", "FFFFE0" }, { "lime", "00FF00" }, { "limegreen", "32CD32" }, { "magenta", "FF00FF" }, { "maroon", "800000" }, { "mediumaquamarine", "66CDAA" }, { "mediumblue", "0000CD" }, { "mediumorchid", "BA55D3" }, { "mediumturquoise", "48D1CC" }, { "mediumvioletred", "C71585" }, { "midnightblue", "191970" }, { "mintcream", "F5FFFA" }, { "mistyrose", "FFE4E1" }, { "moccasin", "FFE4B5" }, { "navajowhite", "FFDEAD" }, { "navy", "000080" }, { "oldlace", "FDF5E6" }, { "olive", "9EC34F" }, { "olivedrab", "6B8E23" }, { "orange", "FFA500" }, { "orangered", "FF4500" }, { "orchid", "DA70D6" }, { "palegoldenrod", "EEE8AA" }, { "palegreen", "98FB98" }, { "palevioletred", "D87093" }, { "pink", "FFC0CB" }, { "plum", "DDA0DD" }, { "powderblue", "B0E0E6" }, { "purple", "800080" }, { "red", "FF4040" }, { "rosybrown", "BC8F8F" }, { "royalblue", "4169E1" }, { "saddlebrown", "8B4513" }, { "salmon", "FA8072" }, { "sandybrown", "F4A460" }, { "seagreen", "2E8B57" }, { "seashell", "FFF5EE" }, { "silver", "C0C0C0" }, { "skyblue", "87CEEB" }, { "slateblue", "6A5ACD" }, { "slategray", "708090" }, { "slategrey", "708090" }, { "snow", "FFFAFA" }, { "springgreen", "00FF7F" }, { "steelblue", "4682B4" }, { "tan", "D2B48C" }, { "teal", "008080" }, { "tomato", "FF6347" }, { "turquoise", "40E0D0" }, { "violet", "EE82EE" }, { "white", "FFFFFF" }, { "yellow", "FFFF00" }, { "yellowgreen", "9ACD32" } }; //you want colors? here bomb array fak u

char g_sPath[PLATFORM_MAX_PATH];
char g_sReplacePath[PLATFORM_MAX_PATH];
char g_sBanPath[PLATFORM_MAX_PATH];

bool g_bWaitingForChatInput[MAXPLAYERS + 1];
bool g_bTagToggled[MAXPLAYERS + 1];
char g_sReceivedChatInput[MAXPLAYERS + 1][64];
char g_sInputType[MAXPLAYERS + 1][32];
char g_sATargetSID[MAXPLAYERS + 1][64];
int g_iATarget[MAXPLAYERS + 1];

Handle g_hConfigFile;
Handle g_hReplaceConfigFile;
Handle g_hBanFile;

int g_msgAuthor;
bool g_msgIsChat;
char g_msgName[128];
char g_msgSender[128];
char g_msgText[MAX_CHAT_LENGTH];
char g_msgFinal[255];
bool g_msgIsTeammate;

bool g_Ignored[(MAXPLAYERS + 1) * (MAXPLAYERS + 1)] = {false, ...};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("Updater_AddPlugin");

	CreateNative("CCC_GetColor", Native_GetColor);
	CreateNative("CCC_SetColor", Native_SetColor);
	CreateNative("CCC_GetTag", Native_GetTag);
	CreateNative("CCC_SetTag", Native_SetTag);
	CreateNative("CCC_ResetColor", Native_ResetColor);
	CreateNative("CCC_ResetTag", Native_ResetTag);

	CreateNative("CCC_UpdateIgnoredArray", Native_UpdateIgnoredArray);

	RegPluginLibrary("ccc");

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("allchat.phrases");

	//new Handle g_hTemporary = null;
	//if(LibraryExists("adminmenu") && ((g_hTemporary = GetAdminTopMenu()) != null))
	//{
	//	OnAdminMenuReady(g_hTemporary);
	//}

	UserMsg SayText2 = GetUserMessageId("SayText2");

	if (SayText2 == INVALID_MESSAGE_ID)
	{
		SetFailState("This game doesn't support SayText2 user messages.");
	}

	HookUserMessage(SayText2, Hook_UserMessage, true);
	HookEvent("player_say", Event_PlayerSay);

	RegAdminCmd("sm_reloadccc", Command_ReloadConfig, ADMFLAG_CONFIG, "Reloads Custom Chat Colors config file");
	RegAdminCmd("sm_forcetag", Command_ForceTag, ADMFLAG_CHEATS, "Forcefully changes a clients custom tag");
	RegAdminCmd("sm_forcetagcolor", Command_ForceTagColor, ADMFLAG_CHEATS, "Forcefully changes a clients custom tag color");
	RegAdminCmd("sm_forcenamecolor", Command_ForceNameColor, ADMFLAG_CHEATS, "Forcefully changes a clients name color");
	RegAdminCmd("sm_forcetextcolor", Command_ForceTextColor, ADMFLAG_CHEATS, "Forcefully changes a clients chat text color");
	RegAdminCmd("sm_cccreset", Command_CCCReset, ADMFLAG_SLAY, "Resets a users custom tag, tag color, name color and chat text color");
	RegAdminCmd("sm_cccban", Command_CCCBan, ADMFLAG_SLAY, "Bans a user from changing his custom tag, tag color, name color and chat text color");
	RegAdminCmd("sm_cccunban", Command_CCCUnban, ADMFLAG_SLAY, "Unbans a user and allows for change of his tag, tag color, name color and chat text color");
	RegAdminCmd("sm_tagmenu", Command_TagMenu, ADMFLAG_CUSTOM1, "Shows the main \"tag & colors\" menu");
	RegAdminCmd("sm_tag", Command_SetTag, ADMFLAG_CUSTOM1, "Changes your custom tag");
	RegAdminCmd("sm_tags", Command_TagMenu, ADMFLAG_CUSTOM1, "Shows the main \"tag & colors\" menu");
	RegAdminCmd("sm_cleartag", Command_ClearTag, ADMFLAG_CUSTOM1, "Clears your custom tag");
	RegAdminCmd("sm_tagcolor", Command_SetTagColor, ADMFLAG_CUSTOM1, "Changes the color of your custom tag");
	RegAdminCmd("sm_cleartagcolor", Command_ClearTagColor, ADMFLAG_CUSTOM1, "Clears the color from your custom tag");
	RegAdminCmd("sm_namecolor", Command_SetNameColor, ADMFLAG_CUSTOM1, "Changes the color of your name");
	RegAdminCmd("sm_clearnamecolor", Command_ClearNameColor, ADMFLAG_CUSTOM1, "Clears the color from your name");
	RegAdminCmd("sm_textcolor", Command_SetTextColor, ADMFLAG_CUSTOM1, "Changes the color of your chat text");
	RegAdminCmd("sm_chatcolor", Command_SetTextColor, ADMFLAG_CUSTOM1, "Changes the color of your chat text");
	RegAdminCmd("sm_cleartextcolor", Command_ClearTextColor, ADMFLAG_CUSTOM1, "Clears the color from your chat text");
	RegAdminCmd("sm_clearchatcolor", Command_ClearTextColor, ADMFLAG_CUSTOM1, "Clears the color from your chat text");
	RegAdminCmd("sm_toggletag", Command_ToggleTag, ADMFLAG_CUSTOM1, "Toggles whether or not your tag and colors show in the chat");

	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");

	if (g_hGreenText != null)
		CloseHandle(g_hGreenText);

	if (g_hReplaceText != null)
		CloseHandle(g_hReplaceText);

	g_hGreenText = CreateConVar("sm_cccgreentext", "1", "Enables greentexting (First chat character must be \">\")", FCVAR_REPLICATED);
	g_hReplaceText = CreateConVar("sm_cccreplacetext", "1", "Enables text replacing as defined in configs/custom-chatcolorsreplace.cfg", FCVAR_REPLICATED);

	//colorForward = CreateGlobalForward("CCC_OnChatColor", ET_Event, Param_Cell);
	//nameForward = CreateGlobalForward("CCC_OnNameColor", ET_Event, Param_Cell);
	//tagForward = CreateGlobalForward("CCC_OnTagApplied", ET_Event, Param_Cell);
	//applicationForward = CreateGlobalForward("CCC_OnColor", ET_Event, Param_Cell, Param_String, Param_Cell);
	messageForward = CreateGlobalForward("CCC_OnChatMessage", ET_Event, Param_Cell, Param_Cell, Param_String);
	preLoadedForward = CreateGlobalForward("CCC_OnUserConfigPreLoaded", ET_Event, Param_Cell);
	loadedForward = CreateGlobalForward("CCC_OnUserConfigLoaded", ET_Ignore, Param_Cell);
	configReloadedForward = CreateGlobalForward("CCC_OnConfigReloaded", ET_Ignore);

	LoadConfig();
}

void LoadConfig()
{
	if (g_hConfigFile != null)
		CloseHandle(g_hConfigFile);

	if (g_hReplaceConfigFile != null)
		CloseHandle(g_hReplaceConfigFile);

	if (g_hBanFile != null)
		CloseHandle(g_hBanFile);

	g_hConfigFile = CreateKeyValues("admin_colors");
	g_hReplaceConfigFile = CreateKeyValues("AutoReplace");
	g_hBanFile = CreateKeyValues("restricted_users");

	BuildPath(Path_SM, g_sPath, sizeof(g_sPath), "configs/custom-chatcolors.cfg");
	BuildPath(Path_SM, g_sReplacePath, sizeof(g_sReplacePath), "configs/custom-chatcolorsreplace.cfg");
	BuildPath(Path_SM, g_sBanPath, sizeof(g_sBanPath), "configs/custom-chatcolorsbans.cfg");

	if (!FileToKeyValues(g_hConfigFile, g_sPath))
		SetFailState("[CCC] Config file missing, please make sure \"custom-chatcolors.cfg\" is in the \"sourcemod/configs\" folder.");

	if (!FileToKeyValues(g_hReplaceConfigFile, g_sReplacePath))
		SetFailState("[CCC] Replace file missing, please make sure \"custom-chatcolorsreplace.cfg\" is in the \"sourcemod/configs\" folder.");

	if (!FileToKeyValues(g_hBanFile, g_sBanPath))
		SetFailState("[CCC] Ban file missing, please make sure \"custom-chatcolorsbans.cfg\" is in the \"sourcemod/configs\" folder.");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		ClearValues(i);
		OnClientPostAdminCheck(i);
	}
}

/* public OnLibraryRemoved(const char name[])
{
	if (StrEqual(name, "adminmenu"))
	{
		g_hAdminMenu = null;
	}
}

public OnAdminMenuReady(Handle CCCAMenu)
{
	if (CCCAMenu == g_hAdminMenu)
	{
		return;
	}

	g_hAdminMenu = CCCAMenu;
	new TopMenuObject:MenuObject = AddToTopMenu(g_hAdminMenu, "CCCCmds", TopMenuObject_Category, Handle_Commands, INVALID_TOPMENUOBJECT);

	if (MenuObject == INVALID_TOPMENUOBJECT)
	{
		return;
	}

	AddToTopMenu(g_hAdminMenu, "CCCReset", TopMenuObject_Item, Handle_AMenuReset, MenuObject, "sm_cccreset", ADMFLAG_SLAY);
	AddToTopMenu(g_hAdminMenu, "CCCBan", TopMenuObject_Item, Handle_AMenuBan, MenuObject, "sm_cccban", ADMFLAG_SLAY);
	AddToTopMenu(g_hAdminMenu, "CCCUnBan", TopMenuObject_Item, Handle_AMenuUnBan, MenuObject, "sm_cccunban", ADMFLAG_SLAY);
} */

bool MakeStringPrintable(char[] str, int str_len_max, const char[] empty) //function taken from Forlix FloodCheck (http://forlix.org/gameaddons/floodcheck.shtml)
{
	int r = 0;
	int w = 0;
	bool modified = false;
	bool nonspace = false;
	bool addspace = false;

	if (str[0])
	{
		do
		{
			if (str[r] < '\x20')
			{
			  modified = true;

			  if((str[r] == '\n' || str[r] == '\t') && w > 0 && str[w-1] != '\x20')
				addspace = true;
			}
			else
			{
			  if (str[r] != '\x20')
			  {
				nonspace = true;

				if (addspace)
				  str[w++] = '\x20';
			  }

			  addspace = false;
			  str[w++] = str[r];
			}
		}
		while(str[++r]);
	}

	str[w] = '\0';

	if (!nonspace)
	{
		modified = true;
		strcopy(str, str_len_max, empty);
	}

	return (modified);
}

bool SingularOrMultiple(int num)
{
	if (num > 1 || num == 0)
	{
		return true;
	}

	return false;
}

bool HasFlag(int client, AdminFlag ADMFLAG)
{
	AdminId Admin = GetUserAdmin(client);

	if (Admin != INVALID_ADMIN_ID && GetAdminFlag(Admin, ADMFLAG, Access_Effective))
		return true;

	return false;
}

bool ForceColor(int client, char Key[64])
{
	int iTarget;
	char sTarget[64];
	char sCol[64];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	GetCmdArg(2, sCol, sizeof(sCol));

	if (IsValidRGBNum(sCol))
	{
		char g[8];
		char b[8];
		GetCmdArg(3, g, sizeof(g));
		GetCmdArg(4, b, sizeof(b));
		int hex;

		hex |= ((StringToInt(sCol) & 0xFF) << 16);
		hex |= ((StringToInt(g) & 0xFF) << 8);
		hex |= ((StringToInt(b) & 0xFF) << 0);

		Format(sCol, 64, "#%06X", hex);
	}

	if ((iTarget = FindTarget(client, sTarget, true)) == -1)
	{
		return false;
	}

	char SID[64];
	GetClientAuthId(iTarget, AuthId_Steam2, SID, sizeof(SID));

	if (IsValidHex(sCol))
	{
		if (sCol[0] != '#')
			Format(sCol, sizeof(sCol), "#%s", sCol);

		SetColor(SID, Key, sCol, -1, true);

		if (!strcmp(Key, "namecolor"))
			CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Successfully set {green}%N's{default} name color to: \x07%s#%s{default}!", iTarget, sCol[1], sCol[1]);
		else if (!strcmp(Key, "tagcolor"))
			CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Successfully set {green}%N's{default} tag color to: \x07%s#%s{default}!", iTarget, sCol[1], sCol[1]);
		else
			CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Successfully set {green}%N's{default} text color to: \x07%s#%s{default}!", iTarget, sCol[1], sCol[1]);
	}
	else
	{
		CReplyToCommand(client, "{green}[{red}C{green}C{blue}C{green}]{default} Invalid HEX|RGB color code given.");
	}

	return true;
}

bool IsValidRGBNum(char[] arg)
{
	if (SimpleRegexMatch(arg, "^([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])$") == 2)
	{
		return true;
	}

	return false;
}

bool IsValidHex(char[] arg)
{
	if (SimpleRegexMatch(arg, "^(#?)([A-Fa-f0-9]{6})$") == 0)
	{
		return false;
	}

	return true;
}

bool SetColor(char SID[64], char Key[64], char HEX[64], int client, bool IgnoreBan=false)
{
	if (!IgnoreBan)
	{
		KvRewind(g_hBanFile);

		if (KvJumpToKey(g_hBanFile, SID))
		{
			if (KvGetNum(g_hBanFile, "length") == 0)
			{
				CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}]{default} You are currently {red}banned{default} from changing your {green}%s{default}.", Key);
				return false;
			}
			else if (KvGetNum(g_hBanFile, "length") < GetTime())
			{
				KvDeleteThis(g_hBanFile);
			}
			else
			{
				char TimeBuffer[64];
				int tstamp = KvGetNum(g_hBanFile, "length");
				tstamp = (tstamp - GetTime());

				int days = (tstamp / 86400);
				int hrs = ((tstamp / 3600) % 24);
				int mins = ((tstamp / 60) % 60);
				int sec = (tstamp % 60);

				if (tstamp > 86400)
				{
					Format(TimeBuffer, sizeof(TimeBuffer), "%d %s, %d %s, %d %s, %d %s", days, SingularOrMultiple(days) ? "Days" : "Day", hrs, SingularOrMultiple(hrs) ? "Hours" : "Hour", mins, SingularOrMultiple(mins) ? "Minutes" : "Minute", sec, SingularOrMultiple(sec) ? "Seconds" : "Second");
				}
				else if (tstamp > 3600)
				{
					Format(TimeBuffer, sizeof(TimeBuffer), "%d %s, %d %s, %d %s", hrs, SingularOrMultiple(hrs) ? "Hours" : "Hour", mins, SingularOrMultiple(mins) ? "Minutes" : "Minute", sec, SingularOrMultiple(sec) ? "Seconds" : "Second");
				}
				else if (tstamp > 60)
				{
					Format(TimeBuffer, sizeof(TimeBuffer), "%d %s, %d %s", mins, SingularOrMultiple(mins) ? "Minutes" : "Minute", sec, SingularOrMultiple(sec) ? "Seconds" : "Second");
				}
				else
				{
					Format(TimeBuffer, sizeof(TimeBuffer), "%d %s", sec, SingularOrMultiple(sec) ? "Seconds" : "Second");
				}

				CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}]{default} You are currently {red}banned{default} from changing your {green}%s{default}. (Time remaining: {green}%s{default})", Key, TimeBuffer);
				return false;
			}
		}
	}

	KvRewind(g_hConfigFile);
	KvRewind(g_hBanFile);

	if (KvJumpToKey(g_hConfigFile, SID, true))
	{
		KvSetString(g_hConfigFile, Key, HEX);
	}

	KvRewind(g_hConfigFile);
	KeyValuesToFile(g_hConfigFile, g_sPath);
	KeyValuesToFile(g_hBanFile, g_sBanPath);

	LoadConfig();
	Call_StartForward(configReloadedForward);
	Call_Finish();

	return true;
}

bool SetTag(char SID[64], char text[64], int client, bool IgnoreBan=false)
{
	if (!IgnoreBan)
	{
		KvRewind(g_hBanFile);

		if (KvJumpToKey(g_hBanFile, SID))
		{
			if (KvGetNum(g_hBanFile, "length") == 0)
			{
				CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}]{default} You are currently {red}banned{default} from changing your {green}tag{default}.");
				return false;
			}
			else if (KvGetNum(g_hBanFile, "length") < GetTime())
			{
				KvDeleteThis(g_hBanFile);
			}
			else
			{
				char TimeBuffer[128];
				int tstamp = KvGetNum(g_hBanFile, "length");
				tstamp = (tstamp - GetTime());

				int days = (tstamp / 86400);
				int hrs = ((tstamp / 3600) % 24);
				int mins = ((tstamp / 60) % 60);
				int sec = (tstamp % 60);

				if (tstamp > 86400)
				{
					Format(TimeBuffer, sizeof(TimeBuffer), "%d %s, %d %s, %d %s, %d %s", days, SingularOrMultiple(days) ? "Days" : "Day", hrs, SingularOrMultiple(hrs) ? "Hours" : "Hour", mins, SingularOrMultiple(mins) ? "Minutes" : "Minute", sec, SingularOrMultiple(sec) ? "Seconds" : "Second");
				}
				else if (tstamp > 3600)
				{
					Format(TimeBuffer, sizeof(TimeBuffer), "%d %s, %d %s, %d %s", hrs, SingularOrMultiple(hrs) ? "Hours" : "Hour", mins, SingularOrMultiple(mins) ? "Minutes" : "Minute", sec, SingularOrMultiple(sec) ? "Seconds" : "Second");
				}
				else if (tstamp > 60)
				{
					Format(TimeBuffer, sizeof(TimeBuffer), "%d %s, %d %s", mins, SingularOrMultiple(mins) ? "Minutes" : "Minute", sec, SingularOrMultiple(sec) ? "Seconds" : "Second");
				}
				else
				{
					Format(TimeBuffer, sizeof(TimeBuffer), "%d %s", sec, SingularOrMultiple(sec) ? "Seconds" : "Second");
				}

				CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}]{default} You are currently {red}banned{default} from changing your {green}tag{default}. (Time remaining: {green}%s{default})", TimeBuffer);
				return false;
			}
		}
	}

	KvRewind(g_hConfigFile);
	KvRewind(g_hBanFile);

	if (KvJumpToKey(g_hConfigFile, SID, true))
	{
		if (StrEqual(text, ""))
		{
			KvSetString(g_hConfigFile, "tag", "");
		}
		else
		{
			char FormattedText[64];
			VFormat(FormattedText, sizeof(FormattedText), "%.24s ", 2);

			KvSetString(g_hConfigFile, "tag", FormattedText);
		}
	}

	KvRewind(g_hConfigFile);
	KeyValuesToFile(g_hConfigFile, g_sPath);
	KeyValuesToFile(g_hBanFile, g_sBanPath);

	LoadConfig();
	Call_StartForward(configReloadedForward);
	Call_Finish();

	return true;
}

bool RemoveCCC(char SID[64])
{
	KvRewind(g_hConfigFile);

	if (KvJumpToKey(g_hConfigFile, SID, false))
	{
		KvDeleteThis(g_hConfigFile);
	}
	else
	{
		return false;
	}

	KvRewind(g_hConfigFile);
	KeyValuesToFile(g_hConfigFile, g_sPath);

	LoadConfig();
	Call_StartForward(configReloadedForward);
	Call_Finish();

	return true;
}

bool BanCCC(char SID[64], int client, int target, char Time[128])
{
	KvRewind(g_hBanFile);

	if (KvJumpToKey(g_hBanFile, SID, false))
	{
		KvDeleteThis(g_hBanFile);
		KvRewind(g_hBanFile);
	}

	if (KvJumpToKey(g_hBanFile, SID, true))
	{
		int time = StringToInt(Time);
		time = GetTime() + (time * 60);

		if (StringToInt(Time) == 0)
		{
			time = 0;
		}

		KvSetNum(g_hBanFile, "length", time);
		CPrintToChatAll("{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} {green}%N{red} restricted {green}%N{default} from modifying his tag/color settings", client, target);
	}

	KvRewind(g_hBanFile);
	KeyValuesToFile(g_hBanFile, g_sBanPath);
	return true;
}

bool UnBanCCC(char SID[64], int client, int target)
{
	KvRewind(g_hBanFile);

	if (KvJumpToKey(g_hBanFile, SID, false))
	{
		CPrintToChatAll("{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} {green}%N{olive} unrestricted {green}%N{default} from modifying his tag/color settings", client, target);
		KvDeleteThis(g_hBanFile);
	}
	else
	{
		CReplyToCommand(client, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Client not restricted");
		return false;
	}

	KvRewind(g_hBanFile);
	KeyValuesToFile(g_hBanFile, g_sBanPath);
	return true;
}

bool ToggleCCC(char SID[64], int client)
{
	KvRewind(g_hConfigFile);

	if (KvJumpToKey(g_hConfigFile, SID, true))
	{
		g_bTagToggled[client] = view_as<bool>(KvGetNum(g_hConfigFile, "toggled", 0));
		g_bTagToggled[client] = !g_bTagToggled[client];
		KvSetNum(g_hConfigFile, "toggled", view_as<bool>(g_bTagToggled[client]));
	}

	KvRewind(g_hConfigFile);
	KeyValuesToFile(g_hConfigFile, g_sPath);
	return true;
}

//   .d8888b.   .d88888b.  888b     d888 888b     d888        d8888 888b    888 8888888b.   .d8888b.
//  d88P  Y88b d88P" "Y88b 8888b   d8888 8888b   d8888       d88888 8888b   888 888  "Y88b d88P  Y88b
//  888    888 888     888 88888b.d88888 88888b.d88888      d88P888 88888b  888 888    888 Y88b.
//  888        888     888 888Y88888P888 888Y88888P888     d88P 888 888Y88b 888 888    888  "Y888b.
//  888        888     888 888 Y888P 888 888 Y888P 888    d88P  888 888 Y88b888 888    888     "Y88b.
//  888    888 888     888 888  Y8P  888 888  Y8P  888   d88P   888 888  Y88888 888    888       "888
//  Y88b  d88P Y88b. .d88P 888   "   888 888   "   888  d8888888888 888   Y8888 888  .d88P Y88b  d88P
//   "Y8888P"   "Y88888P"  888       888 888       888 d88P     888 888    Y888 8888888P"   "Y8888P"
//

public Action Command_ReloadConfig(int client, int args)
{
	LoadConfig();

	LogAction(client, -1, "Reloaded Custom Chat Colors config file");
	ReplyToCommand(client, "[CCC] Reloaded config file.");
	Call_StartForward(configReloadedForward);
	Call_Finish();
	return Plugin_Handled;
}

public Action Command_TagMenu(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	Menu_Main(client);
	return Plugin_Handled;
}

public Action Command_Say(int client, const char[] command, int argc)
{
	char text[MAX_CHAT_LENGTH];
	GetCmdArgString(text, sizeof(text));

	if (client && IsClientInGame(client) && !HasFlag(client, Admin_Generic))
	{
		if (MakeStringPrintable(text, sizeof(text), ""))
		{
			return Plugin_Handled;
		}
	}

	if (g_bWaitingForChatInput[client])
	{
		char SID[64];
		GetClientAuthId(client, AuthId_Steam2, SID, sizeof(SID));

		if (text[strlen(text)-1] == '"')
		{
			text[strlen(text)-1] = '\0';
		}

		strcopy(g_sReceivedChatInput[client], sizeof(g_sReceivedChatInput[]), text[1]);
		g_bWaitingForChatInput[client] = false;
		ReplaceString(g_sReceivedChatInput[client], sizeof(g_sReceivedChatInput), "\"", "'");

		if (g_sReceivedChatInput[client][0] != '#' && !StrEqual(g_sInputType[client], "ChangeTag") && !StrEqual(g_sInputType[client], "MenuForceTag"))
			Format(g_sReceivedChatInput[client], sizeof(g_sReceivedChatInput[]), "#%s", g_sReceivedChatInput[client]);

		if (StrEqual(g_sInputType[client], "ChangeTag"))
		{
			if (SetTag(SID, g_sReceivedChatInput[client], client))
			{
				CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}]{default} Successfully set your {green}tag{default} to: {green}%s{default}", g_sReceivedChatInput[client]);
			}
		}
		else if (StrEqual(g_sInputType[client], "ColorTag"))
		{
			if (IsValidHex(g_sReceivedChatInput[client]))
			{
				if (SetColor(SID, "tagcolor", g_sReceivedChatInput[client], client))
				{
					ReplaceString(g_sReceivedChatInput[client], sizeof(g_sReceivedChatInput[]), "#", "");
					CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}]{default} Successfully set your {green}tag color{default} to: \x07%s#%s", g_sReceivedChatInput[client], g_sReceivedChatInput[client]);
				}
			}
			else
			{
				CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}]{default} Invalid HEX Color code given.");
			}
		}
		else if (StrEqual(g_sInputType[client], "ColorName"))
		{
			if (IsValidHex(g_sReceivedChatInput[client]))
			{
				if (SetColor(SID, "namecolor", g_sReceivedChatInput[client], client))
				{
					ReplaceString(g_sReceivedChatInput[client], sizeof(g_sReceivedChatInput[]), "#", "");
					CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}]{default} Successfully set your {green}name color{default} to: \x07%s#%s", g_sReceivedChatInput[client], g_sReceivedChatInput[client]);
				}
			}
			else
			{
				CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}]{default} Invalid HEX Color code given.");
			}
		}
		else if (StrEqual(g_sInputType[client], "ColorText"))
		{
			if (IsValidHex(g_sReceivedChatInput[client]))
			{
				if (SetColor(SID, "textcolor", g_sReceivedChatInput[client], client))
				{
					ReplaceString(g_sReceivedChatInput[client], sizeof(g_sReceivedChatInput[]), "#", "");
					CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}]{default} Successfully set your {green}text color{default} to: \x07%s#%s", g_sReceivedChatInput[client], g_sReceivedChatInput[client]);
				}
			}
			else
			{
				CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}]{default} Invalid HEX Color code given.");
			}
		}
		else if (StrEqual(g_sInputType[client], "MenuForceTag"))
		{
			if (SetTag(g_sATargetSID[client], g_sReceivedChatInput[client], client, true))
			{
				CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Successfully set {green}%N's{default} tag to: {green}%s{default}!", g_iATarget[client], g_sReceivedChatInput[client]);
			}
		}
		else if (StrEqual(g_sInputType[client], "MenuForceTagColor"))
		{
			if (IsValidHex(g_sReceivedChatInput[client]))
			{
				if (SetColor(g_sATargetSID[client], "tagcolor", g_sReceivedChatInput[client], client, true))
				{
					ReplaceString(g_sReceivedChatInput[client], sizeof(g_sReceivedChatInput[]), "#", "");
					CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Successfully set {green}%N's{default} tag color to: \x07%s#%s{default}!", g_iATarget[client], g_sReceivedChatInput[client], g_sReceivedChatInput[client]);
				}
			}
			else
			{
				CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Invalid HEX Color code given.");
			}
		}
		else if (StrEqual(g_sInputType[client], "MenuForceNameColor"))
		{
			if (IsValidHex(g_sReceivedChatInput[client]))
			{
				if (SetColor(g_sATargetSID[client], "namecolor", g_sReceivedChatInput[client], client, true))
				{
					ReplaceString(g_sReceivedChatInput[client], sizeof(g_sReceivedChatInput[]), "#", "");
					CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Successfully set {green}%N's{default} name color to: \x07%s#%s{default}!", g_iATarget[client], g_sReceivedChatInput[client], g_sReceivedChatInput[client]);
				}
			}
			else
			{
				CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Invalid HEX Color code given.");
			}
		}
		else if (StrEqual(g_sInputType[client], "MenuForceTextColor"))
		{
			if (IsValidHex(g_sReceivedChatInput[client]))
			{
				if (SetColor(g_sATargetSID[client], "textcolor", g_sReceivedChatInput[client], client, true))
				{
					ReplaceString(g_sReceivedChatInput[client], sizeof(g_sReceivedChatInput[]), "#", "");
					CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Successfully set {green}%N's{default} text color to: \x07%s#%s{default}!", g_iATarget[client], g_sReceivedChatInput[client], g_sReceivedChatInput[client]);
				}
			}
			else
			{
				CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Invalid HEX Color code given.");
			}
		}

		return Plugin_Handled;
	}
	else
	{
		if (StrEqual(command, "say_team", false))
			g_msgIsTeammate = true;
		else
			g_msgIsTeammate = false;
	}

	return Plugin_Continue;
}

////////////////////////////////////////////
//Force Tag                            /////
////////////////////////////////////////////

public Action Command_ForceTag(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_forcetag <name|#userid|@filter> <tag text>");
		return Plugin_Handled;
	}

	int iTarget;
	char sTarget[64];
	char sTag[64];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	GetCmdArg(2, sTag, sizeof(sTag));

	if ((iTarget = FindTarget(client, sTarget, true)) == -1)
	{
		return Plugin_Handled;
	}

	char SID[64];
	GetClientAuthId(iTarget, AuthId_Steam2, SID, sizeof(SID));

	SetTag(SID, sTag, client, true);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Force Tag Color                      /////
////////////////////////////////////////////

public Action Command_ForceTagColor(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_forcetagcolor <name|#userid|@filter> <RRGGBB HEX|0-255 0-255 0-255 RGB CODE>");
		return Plugin_Handled;
	}

	ForceColor(client, "tagcolor");

	return Plugin_Handled;
}

////////////////////////////////////////////
//Force Name Color                     /////
////////////////////////////////////////////

public Action Command_ForceNameColor(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_forcenamecolor <name|#userid|@filter> <RRGGBB HEX|0-255 0-255 0-255 RGB CODE>");
		return Plugin_Handled;
	}

	ForceColor(client, "namecolor");

	return Plugin_Handled;
}

////////////////////////////////////////////
//Force Text Color                     /////
////////////////////////////////////////////

public Action Command_ForceTextColor(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_forcetextcolor <name|#userid|@filter> <RRGGBB HEX|0-255 0-255 0-255 RGB CODE>");
		return Plugin_Handled;
	}

	ForceColor(client, "textcolor");

	return Plugin_Handled;
}

////////////////////////////////////////////
//Reset Tag & Colors                   /////
////////////////////////////////////////////

public Action Command_CCCReset(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_cccreset <name|#userid|@filter>");
		return Plugin_Handled;
	}

	int iTarget;
	char sTarget[64];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	if ((iTarget = FindTarget(client, sTarget, true)) == -1)
	{
		return Plugin_Handled;
	}

	char SID[64];
	GetClientAuthId(iTarget, AuthId_Steam2, SID, sizeof(SID));

	CReplyToCommand(client, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Cleared {green}%N's tag {default}&{green} colors{default}.", iTarget);
	RemoveCCC(SID);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Ban Tag & Color Changes              /////
////////////////////////////////////////////

public Action Command_CCCBan(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_cccban <name|#userid|@filter> <optional:time>");
		return Plugin_Handled;
	}

	int iTarget;
	char sTarget[64];
	char sTime[128];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	if (args > 1)
	{
		GetCmdArg(2, sTime, sizeof(sTime));
	}

	if ((iTarget = FindTarget(client, sTarget, true)) == -1)
	{
		return Plugin_Handled;
	}

	char SID[64];
	GetClientAuthId(iTarget, AuthId_Steam2, SID, sizeof(SID));

	BanCCC(SID, client, iTarget, sTime);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Allow Tag & Color Changes            /////
////////////////////////////////////////////

public Action Command_CCCUnban(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_cccunban <name|#userid|@filter>");
		return Plugin_Handled;
	}

	int iTarget;
	char sTarget[64];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	if ((iTarget = FindTarget(client, sTarget, true)) == -1)
	{
		return Plugin_Handled;
	}

	char SID[64];
	GetClientAuthId(iTarget, AuthId_Steam2, SID, sizeof(SID));

	UnBanCCC(SID, client, iTarget);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Set Tag                              /////
////////////////////////////////////////////

public Action Command_SetTag(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_tag <tag text>");
		Menu_Main(client);
		return Plugin_Handled;
	}

	char SID[64];
	char arg[64];
	GetCmdArgString(arg, sizeof(arg));
	GetClientAuthId(client, AuthId_Steam2, SID, sizeof(SID));

	ReplaceString(arg, sizeof(arg), "\"", "'");

	if (SetTag(SID, arg, client))
	{
		CReplyToCommand(client, "{green}[{red}C{green}C{blue}C{green}]{default} Successfully set your {green}tag{default} to: {green}%s{default}", arg);
	}

	return Plugin_Handled;
}

////////////////////////////////////////////
//Clear Tag                            /////
////////////////////////////////////////////

public Action Command_ClearTag(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	char SID[64];
	GetClientAuthId(client, AuthId_Steam2, SID, sizeof(SID));

	SetTag(SID, "", client);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Set Tag Color                        /////
////////////////////////////////////////////

public Action Command_SetTagColor(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		PrintToChat(client, "[SM] Usage: sm_tagcolor <RRGGBB HEX|0-255 0-255 0-255 RGB CODE>");
		Menu_TagPrefs(client);
		return Plugin_Handled;
	}

	char SID[64];
	char col[64];
	GetCmdArg(1, col, sizeof(col));
	GetClientAuthId(client, AuthId_Steam2, SID, sizeof(SID));

	if (IsValidRGBNum(col))
	{
		char g[8];
		char b[8];
		GetCmdArg(2, g, sizeof(g));
		GetCmdArg(3, b, sizeof(b));
		int hex;
		hex |= ((StringToInt(col) & 0xFF) << 16);
		hex |= ((StringToInt(g) & 0xFF) << 8);
		hex |= ((StringToInt(b) & 0xFF) << 0);

		Format(col, 64, "%06X", hex);
	}

	if (IsValidHex(col))
	{
		Format(col, sizeof(col), "#%s", col);
		if (SetColor(SID, "tagcolor", col, client))
		{
			ReplaceString(col, sizeof(col), "#", "");
			CReplyToCommand(client, "{green}[{red}C{green}C{blue}C{green}]{default} Successfully set your {green}tag color{default} to: \x07%s#%s", col, col);
		}
	}
	else
	{
		CReplyToCommand(client, "{green}[{red}C{green}C{blue}C{green}]{default} Invalid HEX|RGB color code given.");
	}

	return Plugin_Handled;
}

////////////////////////////////////////////
//Clear Tag Color                      /////
////////////////////////////////////////////

public Action Command_ClearTagColor(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	char SID[64];
	GetClientAuthId(client, AuthId_Steam2, SID, sizeof(SID));

	SetColor(SID, "tagcolor", "", client);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Set Name Color                       /////
////////////////////////////////////////////

public Action Command_SetNameColor(int client, int args)
{
	if (!client)
	{
		PrintToServer("[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		PrintToChat(client, "[SM] Usage: sm_namecolor <RRGGBB HEX|0-255 0-255 0-255 RGB CODE>");
		Menu_NameColor(client);
		return Plugin_Handled;
	}

	char SID[64];
	char col[64];
	GetCmdArg(1, col, sizeof(col));
	GetClientAuthId(client, AuthId_Steam2, SID, sizeof(SID));

	if (IsValidRGBNum(col))
	{
		char g[8];
		char b[8];
		GetCmdArg(2, g, sizeof(g));
		GetCmdArg(3, b, sizeof(b));
		int hex;
		hex |= ((StringToInt(col) & 0xFF) << 16);
		hex |= ((StringToInt(g) & 0xFF) << 8);
		hex |= ((StringToInt(b) & 0xFF) << 0);

		Format(col, 64, "%06X", hex);
	}

	if (IsValidHex(col))
	{
		Format(col, sizeof(col), "#%s", col);
		if (SetColor(SID, "namecolor", col, client))
		{
			ReplaceString(col, sizeof(col), "#", "");
			CReplyToCommand(client, "{green}[{red}C{green}C{blue}C{green}]{default} Successfully set your {green}name color{default} to: \x07%s#%s", col, col);
		}
	}
	else
	{
		CReplyToCommand(client, "{green}[{red}C{green}C{blue}C{green}]{default} Invalid HEX|RGB color code given.");
	}

	return Plugin_Handled;
}

////////////////////////////////////////////
//Clear Name Color                     /////
////////////////////////////////////////////

public Action Command_ClearNameColor(int client, int args)
{
	if (!client)
	{
		PrintToServer("[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	char SID[64];
	GetClientAuthId(client, AuthId_Steam2, SID, sizeof(SID));

	SetColor(SID, "namecolor", "", client);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Set Text Color                       /////
////////////////////////////////////////////

public Action Command_SetTextColor(int client, int args)
{
	if (!client)
	{
		PrintToServer("[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		PrintToChat(client, "[SM] Usage: sm_textcolor <RRGGBB HEX|0-255 0-255 0-255 RGB CODE>");
		Menu_ChatColor(client);
		return Plugin_Handled;
	}

	char SID[64];
	char col[64];
	GetCmdArg(1, col, sizeof(col));
	GetClientAuthId(client, AuthId_Steam2, SID, sizeof(SID));

	if (IsValidRGBNum(col))
	{
		char g[8];
		char b[8];
		GetCmdArg(2, g, sizeof(g));
		GetCmdArg(3, b, sizeof(b));
		int hex;
		hex |= ((StringToInt(col) & 0xFF) << 16);
		hex |= ((StringToInt(g) & 0xFF) << 8);
		hex |= ((StringToInt(b) & 0xFF) << 0);

		Format(col, 64, "%06X", hex);
	}

	if (IsValidHex(col))
	{
		Format(col, sizeof(col), "#%s", col);
		if (SetColor(SID, "textcolor", col, client))
		{
			ReplaceString(col, sizeof(col), "#", "");
			CReplyToCommand(client, "{green}[{red}C{green}C{blue}C{green}]{default} Successfully set your {green}text color{default} to: \x07%s#%s", col, col);
		}
	}
	else
	{
		CReplyToCommand(client, "{green}[{red}C{green}C{blue}C{green}]{default} Invalid HEX|RGB color code given.");
	}

	return Plugin_Handled;
}

////////////////////////////////////////////
//Clear Text Color                     /////
////////////////////////////////////////////

public Action Command_ClearTextColor(int client, int args)
{
	if (!client)
	{
		PrintToServer("[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	char SID[64];
	GetClientAuthId(client, AuthId_Steam2, SID, sizeof(SID));

	SetColor(SID, "textcolor", "", client);

	return Plugin_Handled;
}

public Action Command_ToggleTag(int client, int args)
{
	if (!client)
	{
		PrintToServer("[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	//g_bTagToggled[client] = !g_bTagToggled[client];
	char SID[64];
	GetClientAuthId(client, AuthId_Steam2, SID, sizeof(SID));

	ToggleCCC(SID, client);
	CReplyToCommand(client, "{green}[{red}C{green}C{blue}C{green}]{default} {green}Tag and color{default} displaying %s", g_bTagToggled[client] ? "{red}disabled{default}." : "{green}enabled{default}.");

	return Plugin_Handled;
}

//  888b     d888 8888888888 888b    888 888     888
//  8888b   d8888 888        8888b   888 888     888
//  88888b.d88888 888        88888b  888 888     888
//  888Y88888P888 8888888    888Y88b 888 888     888
//  888 Y888P 888 888        888 Y88b888 888     888
//  888  Y8P  888 888        888  Y88888 888     888
//  888   "   888 888        888   Y8888 Y88b. .d88P
//  888       888 8888888888 888    Y888  "Y88888P"

/* public Handle_Commands(Handle menu, TopMenuAction action, TopMenuObject:object_id, param1, char buffer[], maxlength)
{
		if (action == TopMenuAction_DisplayOption)
		{
			Format(buffer, maxlength, "%s", "CCC Commands", param1);
		}
		else if (action == TopMenuAction_DisplayTitle)
		{
			Format(buffer, maxlength, "%s", "CCC Commands:", param1);
		}
		else if (action == TopMenuAction_SelectOption)
		{
			PrintToChat(param1, "ur gay");
		}
}

public Handle_AMenuReset(Handle menu, TopMenuAction action, TopMenuObject:object_id, param1, char buffer[], maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Reset", param1);
	}
	else if(action == TopMenuAction_SelectOption)
	{
		new Handle MenuAReset = CreateMenu(MenuHandler_AdminReset);
		SetMenuTitle(MenuAReset, "Select a Target (Reset Tag/Colors)");
		SetMenuExitBackButton(MenuAReset, true);

		AddTargetsToMenu2(MenuAReset, 0, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

		DisplayMenu(MenuAReset, param1, MENU_TIME_FOREVER);
	}
}

public Handle_AMenuBan(Handle menu, TopMenuAction action, TopMenuObject:object_id, param1, char buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Ban", param1);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		new Handle MenuABan = CreateMenu(MenuHandler_AdminBan);
		SetMenuTitle(MenuABan, "Select a Target (Ban from Tag/Colors)");
		SetMenuExitBackButton(MenuABan, true);

		AddTargetsToMenu2(MenuABan, 0, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

		DisplayMenu(MenuABan, param1, MENU_TIME_FOREVER);
	}
}

public Handle_AMenuUnBan(Handle menu, TopMenuAction action, TopMenuObject:object_id, param1, char buffer[], maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Unban", param1);
	}
	else if(action == TopMenuAction_SelectOption)
	{
		AdminMenu_UnBanList(param1);
	}
} */

public void AdminMenu_UnBanList(int client)
{
	Menu MenuAUnBan = new Menu(MenuHandler_AdminUnBan);
	char temp[64];
	MenuAUnBan.SetTitle("Select a Target (Unban from Tag/Colors)");
	MenuAUnBan.ExitBackButton = true;
	int clients;

	for (int i = 1; i <= MaxClients; i++)
	{
		KvRewind(g_hBanFile);

		if (IsClientInGame(i))
		{
			char SID[64];
			GetClientAuthId(i, AuthId_Steam2, SID, sizeof(SID));

			if (KvJumpToKey(g_hBanFile, SID, false))
			{
				char info[64];
				char id[32];
				int remaining;
				KvGetString(g_hBanFile, "length", info, sizeof(info), "0");
				remaining = ((StringToInt(info) - GetTime()) / 60);

				if (StringToInt(info) != 0 && StringToInt(info) < GetTime())
				{
					KvDeleteThis(g_hBanFile);
					continue;
				}

				if (StringToInt(info) == 0)
				{
					Format(info, sizeof(info), "%N (Permanent)", i);
				}
				else
				{
					Format(info, sizeof(info), "%N (%d minutes remaining)", i, remaining);
				}

				Format(id, sizeof(id), "%i", GetClientUserId(i));

				//PrintToChat(client, "Added uid (%d) with info (%s)", id, info);

				MenuAUnBan.AddItem(id, info);

				clients++;
			}
		}
	}

	if (!clients)
	{
		Format(temp, sizeof(temp), "No banned clients");
		MenuAUnBan.AddItem("0", temp, ITEMDRAW_DISABLED);
	}

	MenuAUnBan.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_AdminUnBan(Menu MenuAUnBan, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuAUnBan);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Admin(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		char SID[64];
		MenuAUnBan.GetItem(param2, Selected, sizeof(Selected));
		int target;
		int userid = StringToInt(Selected);
		target = GetClientOfUserId(userid);

		if (!target)
		{
			CReplyToCommand(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Player no longer available.");

			/*if (g_hAdminMenu != null)
			{
				DisplayTopMenu(g_hAdminMenu, param1, TopMenuPosition_LastCategory);
			}*/
			Menu_Admin(param1);
		}
		else
		{
			GetClientAuthId(target, AuthId_Steam2, SID, sizeof(SID));

			UnBanCCC(SID, param1, target);

			/*if (g_hAdminMenu != null)
			{
				DisplayTopMenu(g_hAdminMenu, param1, TopMenuPosition_LastCategory);
				return;
			}*/
		}

		Menu_Admin(param1);
	}

	return 0;
}

public void Menu_Main(int client)
{
	if (IsVoteInProgress())
		return;

	Menu MenuMain = new Menu(MenuHandler_Main);
	MenuMain.SetTitle("Chat Tags & Colors");

	MenuMain.AddItem("Current", "View Current Settings");
	MenuMain.AddItem("Tag", "Tag Options");
	MenuMain.AddItem("Name", "Name Options");
	MenuMain.AddItem("Chat", "Chat Options");

	if (g_bWaitingForChatInput[client])
	{
		MenuMain.AddItem("CancelCInput", "Cancel Chat Input");
	}

	if (HasFlag(client, Admin_Slay) || HasFlag(client, Admin_Cheats))
	{
		MenuMain.AddItem("", "", ITEMDRAW_SPACER);
		MenuMain.AddItem("Admin", "Administrative Options");
	}

	MenuMain.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Main(Menu MenuMain, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuMain);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		GetMenuItem(MenuMain, param2, Selected, sizeof(Selected));

		if (StrEqual(Selected, "Tag"))
		{
			Menu_TagPrefs(param1);
		}
		else if (StrEqual(Selected, "Name"))
		{
			Menu_NameColor(param1);
		}
		else if (StrEqual(Selected, "Chat"))
		{
			Menu_ChatColor(param1);
		}
		else if (StrEqual(Selected, "Admin"))
		{
			Menu_Admin(param1);
		}
		else if (StrEqual(Selected, "CancelCInput"))
		{
			g_bWaitingForChatInput[param1] = false;
			g_sInputType[param1] = "";
			Menu_Main(param1);
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Cancelled chat input.");
		}
		else if (StrEqual(Selected, "Current"))
		{
			char SID[64];
			GetClientAuthId(param1, AuthId_Steam2, SID, sizeof(SID));
			KvRewind(g_hConfigFile);

			if (KvJumpToKey(g_hConfigFile, SID))
			{
				Menu hMenuCurrent = new Menu(MenuHandler_Current);
				char sTag[32];
				char sTagColor[32];
				char sNameColor[32];
				char sTextColor[32];
				char sTagF[64];
				char sTagColorF[64];
				char sNameColorF[64];
				char sTextColorF[64];
				hMenuCurrent.SetTitle("Current Settings:");
				hMenuCurrent.ExitBackButton = true;

				KvGetString(g_hConfigFile, "tag", sTag, sizeof(sTag), "");
				KvGetString(g_hConfigFile, "tagcolor", sTagColor, sizeof(sTagColor), "");
				KvGetString(g_hConfigFile, "namecolor", sNameColor, sizeof(sNameColor), "");
				KvGetString(g_hConfigFile, "textcolor", sTextColor, sizeof(sTextColor), "");

				Format(sTagF, sizeof(sTagF), "Current Tag: %s", sTag);
				Format(sTagColorF, sizeof(sTagColorF), "Current Tag Color: %s", sTagColor);
				Format(sNameColorF, sizeof(sNameColorF), "Current Name Color: %s", sNameColor);
				Format(sTextColorF, sizeof(sTextColorF), "Current Text Color: %s", sTextColor);

				hMenuCurrent.AddItem("sTag", sTagF, ITEMDRAW_DISABLED);
				hMenuCurrent.AddItem("sTagColor", sTagColorF, ITEMDRAW_DISABLED);
				hMenuCurrent.AddItem("sNameColor", sNameColorF, ITEMDRAW_DISABLED);
				hMenuCurrent.AddItem("sTextColor", sTextColorF, ITEMDRAW_DISABLED);

				hMenuCurrent.Display(param1, MENU_TIME_FOREVER);

			}
			else
			{
				CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Could not find entry for {green}%s{default}.", SID);
			}
		}
		else
		{
			PrintToChat(param1, "congrats you broke it");
		}
	}

	return 0;
}

public int MenuHandler_Current(Menu hMenuCurrent, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(hMenuCurrent);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Main(param1);
		return 0;
	}

	return 0;
}

public void Menu_Admin(int client)
{
	if (IsVoteInProgress())
		return;

	Menu MenuAdmin = new Menu(MenuHandler_Admin);
	MenuAdmin.SetTitle("Chat Tags & Colors Admin");
	MenuAdmin.ExitBackButton = true;

	MenuAdmin.AddItem("Reset", "Reset a client's Tag & Colors");
	MenuAdmin.AddItem("Ban", "Ban a client from the Tag & Colors system");
	MenuAdmin.AddItem("Unban", "Unban a client from the Tag & Colors system");

	if (HasFlag(client, Admin_Cheats))
	{
		MenuAdmin.AddItem("ForceTag", "Forcefully change a client's Tag");
		MenuAdmin.AddItem("ForceTagColor", "Forcefully change a client's Tag Color");
		MenuAdmin.AddItem("ForceNameColor", "Forcefully change a client's Name Color");
		MenuAdmin.AddItem("ForceTextColor", "Forcefully change a client's Chat Color");
	}

	MenuAdmin.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Admin(Menu MenuAdmin, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuAdmin);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Main(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		MenuAdmin.GetItem(param2, Selected, sizeof(Selected));

		if (StrEqual(Selected, "Reset"))
		{
			Menu MenuAReset = new Menu(MenuHandler_AdminReset);
			MenuAReset.SetTitle("Select a Target (Reset Tag/Colors)");
			MenuAReset.ExitBackButton = true;

			AddTargetsToMenu2(MenuAReset, 0, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

			MenuAReset.Display(param1, MENU_TIME_FOREVER);
			return 0;
		}
		else if (StrEqual(Selected, "Ban"))
		{
			Menu MenuABan = new Menu(MenuHandler_AdminBan);
			MenuABan.SetTitle("Select a Target (Ban from Tag/Colors)");
			MenuABan.ExitBackButton = true;

			AddTargetsToMenu2(MenuABan, 0, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

			MenuABan.Display(param1, MENU_TIME_FOREVER);
			return 0;
		}
		else if (StrEqual(Selected, "Unban"))
		{
			AdminMenu_UnBanList(param1);
			return 0;
		}
		else if (StrEqual(Selected, "ForceTag"))
		{
			Menu MenuAFTag = new Menu(MenuHandler_AdminForceTag);
			MenuAFTag.SetTitle("Select a Target (Force Tag)");
			MenuAFTag.ExitBackButton = true;

			AddTargetsToMenu2(MenuAFTag, 0, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

			MenuAFTag.Display(param1, MENU_TIME_FOREVER);
			return 0;
		}
		else if (StrEqual(Selected, "ForceTagColor"))
		{
			Menu MenuAFTColor = new Menu(MenuHandler_AdminForceTagColor);
			MenuAFTColor.SetTitle("Select a Target (Force Tag Color)");
			MenuAFTColor.ExitBackButton = true;

			AddTargetsToMenu2(MenuAFTColor, 0, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

			MenuAFTColor.Display(param1, MENU_TIME_FOREVER);
			return 0;
		}
		else if (StrEqual(Selected, "ForceNameColor"))
		{
			Menu MenuAFNColor = new Menu(MenuHandler_AdminForceNameColor);
			MenuAFNColor.SetTitle("Select a Target (Force Name Color)");
			MenuAFNColor.ExitBackButton = true;

			AddTargetsToMenu2(MenuAFNColor, 0, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

			MenuAFNColor.Display(param1, MENU_TIME_FOREVER);
			return 0;
		}
		else if (StrEqual(Selected, "ForceTextColor"))
		{
			Menu MenuAFTeColor = new Menu(MenuHandler_AdminForceTextColor);
			MenuAFTeColor.SetTitle("Select a Target (Force Text Color)");
			MenuAFTeColor.ExitBackButton = true;

			AddTargetsToMenu2(MenuAFTeColor, 0, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

			MenuAFTeColor.Display(param1, MENU_TIME_FOREVER);
			return 0;
		}
		else if (StrEqual(Selected, "CancelCInput"))
		{
			g_bWaitingForChatInput[param1] = false;
			g_sInputType[param1] = "";
			Menu_Admin(param1);
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Cancelled chat input.");
		}
		else
		{
			PrintToChat(param1, "congrats you broke it");
		}

		Menu_Admin(param1);
	}

	return 0;
}

public int MenuHandler_AdminReset(Menu MenuAReset, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuAReset);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Admin(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		char SID[64];
		MenuAReset.GetItem(param2, Selected, sizeof(Selected));
		int target;
		int userid = StringToInt(Selected);
		target = GetClientOfUserId(userid);

		if (!target)
		{
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Player no longer available.");

			/*if (g_hAdminMenu != null)
			{
				DisplayTopMenu(g_hAdminMenu, param1, TopMenuPosition_LastCategory);
				return;
			}*/
			Menu_Admin(param1);
		}
		else
		{
			GetClientAuthId(target, AuthId_Steam2, SID, sizeof(SID));

			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Cleared {green}%N's tag {default}&{green} colors{default}.", target);
			RemoveCCC(SID);
		}

		Menu_Admin(param1);
	}

	return 0;
}

public int MenuHandler_AdminBan(Menu MenuABan, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuABan);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Admin(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		char SID[64];
		MenuABan.GetItem(param2, Selected, sizeof(Selected));
		int target;
		int userid = StringToInt(Selected);
		target = GetClientOfUserId(userid);

		if (!target)
		{
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Player no longer available.");

			/*if (g_hAdminMenu != null)
			{
				DisplayTopMenu(g_hAdminMenu, param1, TopMenuPosition_LastCategory);
				return;
			}*/
			Menu_Admin(param1);
		}
		else
		{
			GetClientAuthId(target, AuthId_Steam2, SID, sizeof(SID));
			g_iATarget[param1] = target;
			g_sATargetSID[param1] = SID;

			Menu MenuABTime = new Menu(MenuHandler_AdminBanTime);
			MenuABTime.SetTitle("Select Ban Length");
			MenuABTime.ExitBackButton = true;

			MenuABTime.AddItem("10", "10 Minutes");
			MenuABTime.AddItem("30", "30 Minutes");
			MenuABTime.AddItem("60", "1 Hour");
			MenuABTime.AddItem("1440", "1 Day");
			MenuABTime.AddItem("10080", "1 Week");
			MenuABTime.AddItem("40320", "1 Month");
			MenuABTime.AddItem("0", "Permanent");

			MenuABTime.Display(param1, MENU_TIME_FOREVER);
		}
	}

	return 0;
}

public int MenuHandler_AdminBanTime(Menu MenuABTime, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuABTime);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu MenuABan = new Menu(MenuHandler_AdminBan);
		MenuABan.SetTitle("Select a Target (Ban from Tag/Colors)");
		MenuABan.ExitBackButton = true;

		AddTargetsToMenu2(MenuABan, 0, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

		MenuABan.Display(param1, MENU_TIME_FOREVER);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[128];
		MenuABTime.GetItem(param2, Selected, sizeof(Selected));

		if (!g_iATarget[param1])
		{
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Player no longer available.");

			/*if (g_hAdminMenu != null)
			{
				DisplayTopMenu(g_hAdminMenu, param1, TopMenuPosition_LastCategory);
				return;
			}*/

			Menu_Admin(param1);
		}

		BanCCC(g_sATargetSID[param1], param1, g_iATarget[param1], Selected);

		/*if (g_hAdminMenu != null)
		{
			DisplayTopMenu(g_hAdminMenu, param1, TopMenuPosition_LastCategory);
			return;
		}*/

		Menu_Admin(param1);
	}

	return 0;
}

public int MenuHandler_AdminForceTag(Menu MenuAFTag, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuAFTag);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Admin(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		char SID[64];
		MenuAFTag.GetItem(param2, Selected, sizeof(Selected));
		int target;
		int userid = StringToInt(Selected);
		target = GetClientOfUserId(userid);

		if (!target)
		{
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Player no longer available.");
			Menu_Admin(param1);
		}
		else
		{
			GetClientAuthId(target, AuthId_Steam2, SID, sizeof(SID));
			g_iATarget[param1] = target;
			g_sATargetSID[param1] = SID;
			g_bWaitingForChatInput[param1] = true;
			g_sInputType[param1] = "MenuForceTag";
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Please enter what you want {green}%N's{default} tag to be.", target);
		}

		Menu_Admin(param1);
	}

	return 0;
}

public int MenuHandler_AdminForceTagColor(Menu MenuAFTColor, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuAFTColor);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Admin(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		MenuAFTColor.GetItem(param2, Selected, sizeof(Selected));
		int target;
		int userid = StringToInt(Selected);

		target = GetClientOfUserId(userid);

		if (!target)
		{
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Player no longer available.");
			Menu_Admin(param1);
		}
		else
		{
			char SID[64];
			GetClientAuthId(target, AuthId_Steam2, SID, sizeof(SID));

			g_iATarget[param1] = target;
			g_sATargetSID[param1] = SID;
			g_bWaitingForChatInput[param1] = true;
			g_sInputType[param1] = "MenuForceTagColor";

			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Please enter what you want {green}%N's{default} tag color to be (#{red}RR{green}GG{blue}BB{default} HEX only!).", target);
		}

		Menu_Admin(param1);
	}

	return 0;
}

public int MenuHandler_AdminForceNameColor(Menu MenuAFNColor, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuAFNColor);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Admin(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		char SID[64];
		MenuAFNColor.GetItem(param2, Selected, sizeof(Selected));
		int target;
		int userid = StringToInt(Selected);
		target = GetClientOfUserId(userid);

		if (!target)
		{
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Player no longer available.");
			Menu_Admin(param1);
		}
		else
		{
			GetClientAuthId(target, AuthId_Steam2, SID, sizeof(SID));
			g_iATarget[param1] = target;
			g_sATargetSID[param1] = SID;
			g_bWaitingForChatInput[param1] = true;
			g_sInputType[param1] = "MenuForceNameColor";
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Please enter what you want {green}%N's{default} name color to be (#{red}RR{green}GG{blue}BB{default} HEX only!).", target);
		}

		Menu_Admin(param1);
	}

	return 0;
}

public int MenuHandler_AdminForceTextColor(Menu MenuAFTeColor, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuAFTeColor);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Admin(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		char SID[64];
		MenuAFTeColor.GetItem(param2, Selected, sizeof(Selected));
		int target;
		int userid = StringToInt(Selected);
		target = GetClientOfUserId(userid);

		if (!target)
		{
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Player no longer available.");
			Menu_Admin(param1);
		}
		else
		{
			GetClientAuthId(target, AuthId_Steam2, SID, sizeof(SID));
			g_iATarget[param1] = target;
			g_sATargetSID[param1] = SID;
			g_bWaitingForChatInput[param1] = true;
			g_sInputType[param1] = "MenuForceTextColor";
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Please enter what you want {green}%N's{default} text color to be (#{red}RR{green}GG{blue}BB{default} HEX only!).", target);
		}

		Menu_Admin(param1);
	}

	return 0;
}

public void Menu_TagPrefs(int client)
{
	if (IsVoteInProgress())
		return;

	Menu MenuTPrefs = new Menu(MenuHandler_TagPrefs);
	MenuTPrefs.SetTitle("Tag Options:");
	MenuTPrefs.ExitBackButton = true;

	MenuTPrefs.AddItem("Reset", "Clear Tag");
	MenuTPrefs.AddItem("ResetColor", "Clear Tag Color");
	MenuTPrefs.AddItem("ChangeTag", "Change Tag (Chat input)");
	MenuTPrefs.AddItem("Color", "Change Tag Color");
	MenuTPrefs.AddItem("ColorTag", "Change Tag Color (Chat input)");

	MenuTPrefs.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_TagPrefs(Menu MenuTPrefs, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuTPrefs);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Main(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		MenuTPrefs.GetItem(param2, Selected, sizeof(Selected));

		if (StrEqual(Selected, "Reset"))
		{
			char SID[64];
			GetClientAuthId(param1, AuthId_Steam2, SID, sizeof(SID));

			SetTag(SID, "", param1);

			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Cleared your custom {green}tag{default}.");
		}
		else if (StrEqual(Selected, "ResetColor"))
		{
			char SID[64];
			GetClientAuthId(param1, AuthId_Steam2, SID, sizeof(SID));

			if (SetColor(SID, "tagcolor", "", param1))
				CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Cleared your custom {green}tag color{default}.");
		}
		else if (StrEqual(Selected, "ChangeTag"))
		{
			g_bWaitingForChatInput[param1] = true;
			g_sInputType[param1] = "ChangeTag";
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Please enter what you want your {green}tag{default} to be.");
		}
		else if (StrEqual(Selected, "ColorTag"))
		{
			g_bWaitingForChatInput[param1] = true;
			g_sInputType[param1] = "ColorTag";
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Please enter what you want your {green}tag color{default} to be (#{red}RR{green}GG{blue}BB{default} HEX only!).");
		}
		else
		{
			Menu ColorsMenu = new Menu(MenuHandler_TagColorSub);
			char info[64];
			ColorsMenu.SetTitle("Pick a color:");
			ColorsMenu.ExitBackButton = true;

			for (int i = 0; i < 120; i++)
			{
				Format(info, sizeof(info), "%s (#%s)", g_sColorsArray[i][0], g_sColorsArray[i][1]);
				ColorsMenu.AddItem(g_sColorsArray[i][1], info);
			}

			ColorsMenu.Display(param1, MENU_TIME_FOREVER);
			return 0;
		}

		Menu_Main(param1);
	}

	return 0;
}

public void Menu_NameColor(int client)
{
	if (IsVoteInProgress())
		return;

	Menu MenuNColor = new Menu(MenuHandler_NameColor);
	MenuNColor.SetTitle("Name Options:");
	MenuNColor.ExitBackButton = true;

	MenuNColor.AddItem("ResetColor", "Clear Name Color");
	MenuNColor.AddItem("Color", "Change Name Color");
	MenuNColor.AddItem("ColorName", "Change Name Color (Chat input)");

	MenuNColor.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_NameColor(Menu MenuNColor, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuNColor);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Main(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		MenuNColor.GetItem(param2, Selected, sizeof(Selected));

		if (StrEqual(Selected, "ResetColor"))
		{
			char SID[64];
			GetClientAuthId(param1, AuthId_Steam2, SID, sizeof(SID));

			if (SetColor(SID, "namecolor", "", param1))
				CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Cleared your custom {green}name color{default}.");
		}
		else if (StrEqual(Selected, "ColorName"))
		{
			g_bWaitingForChatInput[param1] = true;
			g_sInputType[param1] = "ColorName";
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Please enter what you want your {green}name color{default} to be (#{red}RR{green}GG{blue}BB{default} HEX only!).");
		}
		else
		{
			Menu ColorsMenu = new Menu(MenuHandler_NameColorSub);
			char info[64];
			char SID[64];
			GetClientAuthId(param1, AuthId_Steam2, SID, sizeof(SID));
			ColorsMenu.SetTitle("Pick a color:");
			ColorsMenu.ExitBackButton = true;

			for (int i = 0; i < 120; i++)
			{
				Format(info, sizeof(info), "%s (#%s)", g_sColorsArray[i][0], g_sColorsArray[i][1]);
				ColorsMenu.AddItem(g_sColorsArray[i][1], info);
			}

			if (HasFlag(param1, Admin_Cheats))
			{
				ColorsMenu.AddItem("X", "X");
			}

			ColorsMenu.Display(param1, MENU_TIME_FOREVER);
			return 0;
		}

		Menu_Main(param1);
	}

	return 0;
}

public void Menu_ChatColor(int client)
{
	if (IsVoteInProgress())
		return;

	Menu MenuCColor = new Menu(MenuHandler_ChatColor);
	MenuCColor.SetTitle("Chat Options:");
	MenuCColor.ExitBackButton = true;

	MenuCColor.AddItem("ResetColor", "Clear Chat Text Color");
	MenuCColor.AddItem("Color", "Change Chat Text Color");
	MenuCColor.AddItem("ColorText", "Change Chat Text Color (Chat input)");

	MenuCColor.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ChatColor(Menu MenuCColor, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuCColor);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Main(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		MenuCColor.GetItem(param2, Selected, sizeof(Selected));

		if (StrEqual(Selected, "ResetColor"))
		{
			char SID[64];
			GetClientAuthId(param1, AuthId_Steam2, SID, sizeof(SID));

			if (SetColor(SID, "textcolor", "", param1))
				CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Cleared your custom {green}text color{default}.");
		}
		else if (StrEqual(Selected, "ColorText"))
		{
			g_bWaitingForChatInput[param1] = true;
			g_sInputType[param1] = "ColorText";
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Please enter what you want your {green}text color{default} to be (#{red}RR{green}GG{blue}BB{default} HEX only!).");
		}
		else
		{
			Menu ColorsMenu = new Menu(MenuHandler_ChatColorSub);
			char info[64];
			ColorsMenu.SetTitle("Pick a color:");
			ColorsMenu.ExitBackButton = true;

			for (int i = 0; i < 120; i++)
			{
				Format(info, sizeof(info), "%s (#%s)", g_sColorsArray[i][0], g_sColorsArray[i][1]);
				ColorsMenu.AddItem(g_sColorsArray[i][1], info);
			}

			ColorsMenu.Display(param1, MENU_TIME_FOREVER);
			return 0;
		}

		Menu_Main(param1);
	}

	return 0;
}

public int MenuHandler_TagColorSub(Menu MenuTCSub, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuTCSub);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_TagPrefs(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char SID[64];
		char Selected[64];
		char SelectedFinal[64];
		MenuTCSub.GetItem(param2, Selected, sizeof(Selected));
		GetClientAuthId(param1, AuthId_Steam2, SID, sizeof(SID));

		Format(SelectedFinal, sizeof(SelectedFinal), "#%s", Selected);

		if (SetColor(SID, "tagcolor", SelectedFinal, param1))
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Successfully set your {green}tag color{default} to: \x07%s%s", Selected, SelectedFinal);

		Menu_TagPrefs(param1);
	}

	return 0;
}

public int MenuHandler_NameColorSub(Menu MenuNCSub, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuNCSub);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_NameColor(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char SID[64];
		char Selected[64];
		char SelectedFinal[64];
		MenuNCSub.GetItem(param2, Selected, sizeof(Selected));
		GetClientAuthId(param1, AuthId_Steam2, SID, sizeof(SID));

		Format(SelectedFinal, sizeof(SelectedFinal), "#%s", Selected);

		if (SetColor(SID, "namecolor", SelectedFinal, param1))
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Successfully set your {green}name color{default} to: \x07%s%s", Selected, SelectedFinal);

		Menu_NameColor(param1);
	}

	return 0;
}

public int MenuHandler_ChatColorSub(Menu MenuCCSub, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuCCSub);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_ChatColor(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char SID[64];
		char Selected[64];
		char SelectedFinal[64];
		MenuCCSub.GetItem(param2, Selected, sizeof(Selected));
		GetClientAuthId(param1, AuthId_Steam2, SID, sizeof(SID));

		Format(SelectedFinal, sizeof(SelectedFinal), "#%s", Selected);

		if (SetColor(SID, "textcolor", SelectedFinal, param1))
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Successfully set your {green}text color{default} to: \x07%s%s", Selected, SelectedFinal);

		Menu_ChatColor(param1);
	}

	return 0;
}

//  88888888888     d8888  .d8888b.        .d8888b.  8888888888 88888888888 88888888888 8888888 888b    888  .d8888b.
//      888        d88888 d88P  Y88b      d88P  Y88b 888            888         888       888   8888b   888 d88P  Y88b
//      888       d88P888 888    888      Y88b.      888            888         888       888   88888b  888 888    888
//      888      d88P 888 888              "Y888b.   8888888        888         888       888   888Y88b 888 888
//      888     d88P  888 888  88888          "Y88b. 888            888         888       888   888 Y88b888 888  88888
//      888    d88P   888 888    888            "888 888            888         888       888   888  Y88888 888    888
//      888   d8888888888 Y88b  d88P      Y88b  d88P 888            888         888       888   888   Y8888 Y88b  d88P
//      888  d88P     888  "Y8888P88       "Y8888P"  8888888888     888         888     8888888 888    Y888  "Y8888P88

void ClearValues(int client)
{
	Format(g_sTag[client], sizeof(g_sTag[]), "");
	Format(g_sTagColor[client], sizeof(g_sTagColor[]), "");
	Format(g_sUsernameColor[client], sizeof(g_sUsernameColor[]), "");
	Format(g_sChatColor[client], sizeof(g_sChatColor[]), "");

	Format(g_sDefaultTag[client], sizeof(g_sDefaultTag[]), "");
	Format(g_sDefaultTagColor[client], sizeof(g_sDefaultTagColor[]), "");
	Format(g_sDefaultUsernameColor[client], sizeof(g_sDefaultUsernameColor[]), "");
	Format(g_sDefaultChatColor[client], sizeof(g_sDefaultChatColor[]), "");
}

public void OnClientConnected(int client)
{
	Format(g_sReceivedChatInput[client], sizeof(g_sReceivedChatInput[]), "");
	Format(g_sInputType[client], sizeof(g_sInputType[]), "");
	Format(g_sATargetSID[client], sizeof(g_sATargetSID[]), "");
	g_bWaitingForChatInput[client] = false;
	g_bTagToggled[client] = false;
	g_iATarget[client] = 0;

	ClearValues(client);
}

public void OnClientDisconnect(int client)
{
	Format(g_sReceivedChatInput[client], sizeof(g_sReceivedChatInput[]), "");
	Format(g_sInputType[client], sizeof(g_sInputType[]), "");
	Format(g_sATargetSID[client], sizeof(g_sATargetSID[]), "");
	g_bWaitingForChatInput[client] = false;
	g_bTagToggled[client] = false;
	g_iATarget[client] = 0;

	ClearValues(client);
}

public void OnClientPostAdminCheck(int client)
{
	if (!ConfigForward(client))
		return;

	char auth[32];
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
	KvRewind(g_hConfigFile);

	bool found = false;
	if (KvJumpToKey(g_hConfigFile, auth))
	{
		found = true;
		g_bTagToggled[client] = view_as<bool>(KvGetNum(g_hConfigFile, "toggled"));
	}

	if (!found || !CheckCommandAccess(client, "sm_tag", ADMFLAG_CUSTOM1))
	{
		KvRewind(g_hConfigFile);
		KvGotoFirstSubKey(g_hConfigFile);

		AdminId admin = GetUserAdmin(client);
		AdminFlag flag;
		char configFlag[2];
		char section[32];
		found = false;

		do
		{
			KvGetSectionName(g_hConfigFile, section, sizeof(section));
			KvGetString(g_hConfigFile, "flag", configFlag, sizeof(configFlag));

			if (strlen(configFlag) > 1)
			{
				LogError("Multiple flags given in section \"%s\", which is not allowed. Using first character.", section);
			}

			if (strlen(configFlag) == 0 && StrContains(section, "STEAM_", false) == -1 && StrContains(section, "[U:1:", false) == -1)
			{
				found = true;
				break;
			}

			if (!FindFlagByChar(configFlag[0], flag))
			{
				if (strlen(configFlag) > 0)
				{
					LogError("Invalid flag given for section \"%s\", skipping", section);
				}

				continue;
			}

			if (GetAdminFlag(admin, flag))
			{
				found = true;
				break;
			}
		}
		while (KvGotoNextKey(g_hConfigFile));

		if (!found)
		{
			return;
		}
	}

	char clientTagColor[12];
	char clientNameColor[12];
	char clientChatColor[12];

	KvGetString(g_hConfigFile, "tag", g_sTag[client], sizeof(g_sTag[]));
	KvGetString(g_hConfigFile, "tagcolor", clientTagColor, sizeof(clientTagColor));
	KvGetString(g_hConfigFile, "namecolor", clientNameColor, sizeof(clientNameColor));
	KvGetString(g_hConfigFile, "textcolor", clientChatColor, sizeof(clientChatColor));

	ReplaceString(clientTagColor, sizeof(clientTagColor), "#", "");
	ReplaceString(clientNameColor, sizeof(clientNameColor), "#", "");
	ReplaceString(clientChatColor, sizeof(clientChatColor), "#", "");

	int tagLen = strlen(clientTagColor);
	int nameLen = strlen(clientNameColor);
	int chatLen = strlen(clientChatColor);

	if (tagLen == 6 || tagLen == 8 || StrEqual(clientTagColor, "T", false) || StrEqual(clientTagColor, "G", false) || StrEqual(clientTagColor, "O", false) || StrEqual(clientTagColor, "X", false))
	{
		strcopy(g_sTagColor[client], sizeof(g_sTagColor[]), clientTagColor);
	}

	if (nameLen == 6 || nameLen == 8 || StrEqual(clientNameColor, "G", false) || StrEqual(clientNameColor, "O", false) || StrEqual(clientNameColor, "X", false))
	{
		strcopy(g_sUsernameColor[client], sizeof(g_sUsernameColor[]), clientNameColor);
	}

	if (chatLen == 6 || chatLen == 8 || StrEqual(clientChatColor, "T", false) || StrEqual(clientChatColor, "G", false) || StrEqual(clientChatColor, "O", false) || StrEqual(clientChatColor, "X", false))
	{
		strcopy(g_sChatColor[client], sizeof(g_sChatColor[]), clientChatColor);
	}

	strcopy(g_sDefaultTag[client], sizeof(g_sDefaultTag[]), g_sTag[client]);
	strcopy(g_sDefaultTagColor[client], sizeof(g_sDefaultTagColor[]), g_sTagColor[client]);
	strcopy(g_sDefaultUsernameColor[client], sizeof(g_sDefaultUsernameColor[]), g_sUsernameColor[client]);
	strcopy(g_sDefaultChatColor[client], sizeof(g_sDefaultChatColor[]), g_sChatColor[client]);

	Call_StartForward(loadedForward);
	Call_PushCell(client);
	Call_Finish();
}

public Action Hook_UserMessage(UserMsg msg_id, Handle bf, const players[], int playersNum, bool reliable, bool init)
{
	char sAuthorTag[64];
	g_msgAuthor = BfReadByte(bf);
	g_msgIsChat = view_as<bool>(BfReadByte(bf));
	BfReadString(bf, g_msgName, sizeof(g_msgName), false);
	BfReadString(bf, g_msgSender, sizeof(g_msgSender), false);
	BfReadString(bf, g_msgText, sizeof(g_msgText), false);

	if (strlen(g_msgName) == 0 || strlen(g_msgSender) == 0)
		return Plugin_Continue;

	if (!strcmp(g_msgName, "#Cstrike_Name_Change"))
		return Plugin_Continue;

	TrimString(g_msgText);

	if (strlen(g_msgText) == 0)
		return Plugin_Handled;

	CCC_GetTag(g_msgAuthor, sAuthorTag, sizeof(sAuthorTag));

	bool bNameAlpha;
	bool bChatAlpha;
	bool bTagAlpha;
	bool bIsAction;
	int xiNameColor = CCC_GetColor(g_msgAuthor, view_as<CCC_ColorType>(CCC_NameColor), bNameAlpha);
	int xiChatColor = CCC_GetColor(g_msgAuthor, view_as<CCC_ColorType>(CCC_ChatColor), bChatAlpha);
	int xiTagColor = CCC_GetColor(g_msgAuthor, view_as<CCC_ColorType>(CCC_TagColor), bTagAlpha);

	if (!strncmp(g_msgText, "/me", 3, false))
	{
		strcopy(g_msgName, sizeof(g_msgName), "Cstrike_Chat_Me");
		strcopy(g_msgText, sizeof(g_msgText), g_msgText[4]);
		bIsAction = true;
	}

	if (GetConVarInt(g_hReplaceText) > 0)
	{
		char sPart[MAX_CHAT_LENGTH];
		char sBuff[MAX_CHAT_LENGTH];
		int CurrentIndex = 0;
		int NextIndex = 0;

		while(NextIndex != -1 && CurrentIndex < sizeof(g_msgText))
		{
			NextIndex = BreakString(g_msgText[CurrentIndex], sPart, sizeof(sPart));

			KvGetString(g_hReplaceConfigFile, sPart, sBuff, sizeof(sBuff), NULL_STRING);

			if(sBuff[0])
			{
				ReplaceString(g_msgText[CurrentIndex], sizeof(g_msgText) - CurrentIndex, sPart, sBuff);
				CurrentIndex += strlen(sBuff);
			}
			else
				CurrentIndex += NextIndex;
		}
	}

	if (!g_msgAuthor || HasFlag(g_msgAuthor, Admin_Generic))
	{
		CFormatColor(g_msgText, sizeof(g_msgText), g_msgAuthor);
	}

	if (!bIsAction)
	{
		if (xiNameColor == COLOR_TEAM || g_bTagToggled[g_msgAuthor])
		{
			Format(g_msgSender, sizeof(g_msgSender), "\x03%s", g_msgSender);
		}
		else if (xiNameColor == COLOR_CGREEN)
		{
			Format(g_msgSender, sizeof(g_msgSender), "\x04%s", g_msgSender);
		}
		else if (xiNameColor == COLOR_OLIVE)
		{
			Format(g_msgSender, sizeof(g_msgSender), "\x05%s", g_msgSender);
		}
		else if (xiNameColor == COLOR_NULL)
		{
			Format(g_msgSender, sizeof(g_msgSender), "", g_msgSender);
		}
		else if (!bNameAlpha)
		{
			Format(g_msgSender, sizeof(g_msgSender), "\x07%06X%s", xiNameColor, g_msgSender);
		}
		else
		{
			Format(g_msgSender, sizeof(g_msgSender), "\x08%08X%s", xiNameColor, g_msgSender);
		}

		if (!g_bTagToggled[g_msgAuthor] && strlen(sAuthorTag) > 0)
		{
			if (xiTagColor == COLOR_TEAM)
			{
				Format(g_msgSender, sizeof(g_msgSender), "\x03%s%s", sAuthorTag, g_msgSender);
			}
			else if (xiTagColor == COLOR_CGREEN)
			{
				Format(g_msgSender, sizeof(g_msgSender), "\x04%s%s", sAuthorTag, g_msgSender);
			}
			else if (xiTagColor == COLOR_OLIVE)
			{
				Format(g_msgSender, sizeof(g_msgSender), "\x05%s%s", sAuthorTag, g_msgSender);
			}
			else if (xiTagColor == COLOR_NONE)
			{
				Format(g_msgSender, sizeof(g_msgSender), "\x01%s%s", sAuthorTag, g_msgSender);
			}
			else if (!bTagAlpha)
			{
				Format(g_msgSender, sizeof(g_msgSender), "\x07%06X%s%s", xiTagColor, sAuthorTag, g_msgSender);
			}
			else
			{
				Format(g_msgSender, sizeof(g_msgSender), "\x08%08X%s%s", xiTagColor, sAuthorTag, g_msgSender);
			}
		}

		if (g_msgText[0] == '>' && GetConVarInt(g_hGreenText) > 0)
		{
			Format(g_msgText, sizeof(g_msgText), "\x0714C800%s", g_msgText);
		}
		else if (xiChatColor == COLOR_NONE || g_bTagToggled[g_msgAuthor])
		{
		}
		else if (xiChatColor == COLOR_TEAM)
		{
			Format(g_msgText, sizeof(g_msgText), "\x03%s", g_msgText);
		}
		else if (xiChatColor == COLOR_CGREEN)
		{
			Format(g_msgText, sizeof(g_msgText), "\x04%s", g_msgText);
		}
		else if (xiChatColor == COLOR_OLIVE)
		{
			Format(g_msgText, sizeof(g_msgText), "\x05%s", g_msgText);
		}
		else if (!bChatAlpha)
		{
			Format(g_msgText, sizeof(g_msgText), "\x07%06X%s", xiChatColor, g_msgText);
		}
		else
		{
			Format(g_msgText, sizeof(g_msgText), "\x08%08X%s", xiChatColor, g_msgText);
		}
	}

	Format(g_msgFinal, sizeof(g_msgFinal), "%t", g_msgName, g_msgSender, g_msgText);

	return Plugin_Handled;
}

public Action Event_PlayerSay(Handle event, const char[] name, bool dontBroadcast)
{
	if (g_msgAuthor == -1 || GetClientOfUserId(GetEventInt(event, "userid")) != g_msgAuthor)
	{
		return;
	}

	if (strlen(g_msgText) == 0)
		return;

	int[] players = new int[MaxClients + 1];
	int playersNum = 0;

	if (g_msgIsTeammate && g_msgAuthor > 0)
	{
		int team = GetClientTeam(g_msgAuthor);

		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && GetClientTeam(client) == team)
			{
				if(!g_Ignored[client * (MAXPLAYERS + 1) + g_msgAuthor] && MessageForward(client, g_msgAuthor, g_msgText))
					players[playersNum++] = client;
			}
		}
	}
	else
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				if(!g_Ignored[client * (MAXPLAYERS + 1) + g_msgAuthor] && MessageForward(client, g_msgAuthor, g_msgText))
					players[playersNum++] = client;
			}
		}
	}

	if (!playersNum)
	{
		g_msgAuthor = -1;
		return;
	}

	Handle SayText2 = StartMessage("SayText2", players, playersNum, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS);

	if (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(SayText2, "ent_idx", g_msgAuthor);
		PbSetBool(SayText2, "chat", g_msgIsChat);
		PbSetString(SayText2, "text", g_msgFinal);
		EndMessage();
	}
	else
	{
		BfWriteByte(SayText2, g_msgAuthor);
		BfWriteByte(SayText2, g_msgIsChat);
		BfWriteString(SayText2, g_msgFinal);
		EndMessage();
	}

	g_msgAuthor = -1;
}

//  888b    888        d8888 88888888888 8888888 888     888 8888888888 .d8888b.
//  8888b   888       d88888     888       888   888     888 888       d88P  Y88b
//  88888b  888      d88P888     888       888   888     888 888       Y88b.
//  888Y88b 888     d88P 888     888       888   Y88b   d88P 8888888    "Y888b.
//  888 Y88b888    d88P  888     888       888    Y88b d88P  888           "Y88b.
//  888  Y88888   d88P   888     888       888     Y88o88P   888             "888
//  888   Y8888  d8888888888     888       888      Y888P    888       Y88b  d88P
//  888    Y888 d88P     888     888     8888888     Y8P     8888888888 "Y8888P"

stock bool CheckForward(int author, const char[] message, CCC_ColorType type)
{
	new Action result = Plugin_Continue;

	Call_StartForward(applicationForward);
	Call_PushCell(author);
	Call_PushString(message);
	Call_PushCell(type);
	Call_Finish(result);

	if (result >= Plugin_Handled)
		return false;

	// Compatibility
	switch(type)
	{
		case CCC_TagColor: return TagForward(author);
		case CCC_NameColor: return NameForward(author);
		case CCC_ChatColor: return ColorForward(author);
	}

	return true;
}

stock bool ColorForward(int author)
{
	Action result = Plugin_Continue;

	Call_StartForward(colorForward);
	Call_PushCell(author);
	Call_Finish(result);

	if (result >= Plugin_Handled)
		return false;

	return true;
}

stock bool NameForward(int author)
{
	Action result = Plugin_Continue;

	Call_StartForward(nameForward);
	Call_PushCell(author);
	Call_Finish(result);

	if (result >= Plugin_Handled)
		return false;

	return true;
}

stock bool TagForward(int author)
{
	Action result = Plugin_Continue;

	Call_StartForward(tagForward);
	Call_PushCell(author);
	Call_Finish(result);

	if (result >= Plugin_Handled)
		return false;

	return true;
}

stock bool ConfigForward(int client)
{
	Action result = Plugin_Continue;

	Call_StartForward(preLoadedForward);
	Call_PushCell(client);
	Call_Finish(result);

	if (result >= Plugin_Handled)
		return false;

	return true;
}

stock bool MessageForward(int client, int author, char[] message)
{
	Action result = Plugin_Continue;

	Call_StartForward(messageForward);
	Call_PushCell(client);
	Call_PushCell(author);
	Call_PushString(message);
	Call_Finish(result);

	if (result >= Plugin_Handled)
		return false;

	return true;
}

public int Native_GetColor(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!client || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
		return COLOR_NONE;
	}

	switch(GetNativeCell(2))
	{
		case CCC_TagColor:
		{
			if (StrEqual(g_sTagColor[client], "T", false))
			{
				SetNativeCellRef(3, false);
				return COLOR_TEAM;
			}
			else if (StrEqual(g_sTagColor[client], "G", false))
			{
				SetNativeCellRef(3, false);
				return COLOR_CGREEN;
			}
			else if (StrEqual(g_sTagColor[client], "O", false))
			{
				SetNativeCellRef(3, false);
				return COLOR_OLIVE;
			}
			else if (strlen(g_sTagColor[client]) == 6 || strlen(g_sTagColor[client]) == 8)
			{
				SetNativeCellRef(3, strlen(g_sTagColor[client]) == 8);
				return StringToInt(g_sTagColor[client], 16);
			}
			else
			{
				SetNativeCellRef(3, false);
				return COLOR_NONE;
			}
		}

		case CCC_NameColor:
		{
			if (StrEqual(g_sUsernameColor[client], "G", false))
			{
				SetNativeCellRef(3, false);
				return COLOR_CGREEN;
			}
			else if (StrEqual(g_sUsernameColor[client], "X", false))
			{
				SetNativeCellRef(3, false);
				return COLOR_NULL;
			}
			else if (StrEqual(g_sUsernameColor[client], "O", false))
			{
				SetNativeCellRef(3, false);
				return COLOR_OLIVE;
			}
			else if (strlen(g_sUsernameColor[client]) == 6 || strlen(g_sUsernameColor[client]) == 8)
			{
				SetNativeCellRef(3, strlen(g_sUsernameColor[client]) == 8);
				return StringToInt(g_sUsernameColor[client], 16);
			}
			else
			{
				SetNativeCellRef(3, false);
				return COLOR_TEAM;
			}
		}

		case CCC_ChatColor:
		{
			if (StrEqual(g_sChatColor[client], "T", false))
			{
				SetNativeCellRef(3, false);
				return COLOR_TEAM;
			}
			else if (StrEqual(g_sChatColor[client], "G", false))
			{
				SetNativeCellRef(3, false);
				return COLOR_CGREEN;
			}
			else if (StrEqual(g_sChatColor[client], "O", false))
			{
				SetNativeCellRef(3, false);
				return COLOR_OLIVE;
			}
			else if (strlen(g_sChatColor[client]) == 6 || strlen(g_sChatColor[client]) == 8)
			{
				SetNativeCellRef(3, strlen(g_sChatColor[client]) == 8);
				return StringToInt(g_sChatColor[client], 16);
			}
			else
			{
				SetNativeCellRef(3, false);
				return COLOR_NONE;
			}
		}
	}

	return COLOR_NONE;
}

public int Native_SetColor(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!client || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
		return 0;
	}

	char color[32];

	if (GetNativeCell(3) < 0)
	{
		switch (GetNativeCell(3))
		{
			case COLOR_CGREEN:
			{
				Format(color, sizeof(color), "G");
			}
			case COLOR_OLIVE:
			{
				Format(color, sizeof(color), "O");
			}
			case COLOR_TEAM:
			{
				Format(color, sizeof(color), "T");
			}
			case COLOR_NULL:
			{
				Format(color, sizeof(color), "X");
			}
			case COLOR_NONE:
			{
				Format(color, sizeof(color), "");
			}
		}
	}
	else
	{
		if (!GetNativeCell(4))
		{
			// No alpha
			Format(color, sizeof(color), "%06X", GetNativeCell(3));
		}
		else
		{
			// Alpha specified
			Format(color, sizeof(color), "%08X", GetNativeCell(3));
		}
	}

	if (strlen(color) != 6 && strlen(color) != 8 && !StrEqual(color, "G", false) && !StrEqual(color, "O", false) && !StrEqual(color, "T", false) && !StrEqual(color, "X", false))
	{
		return 0;
	}

	switch (GetNativeCell(2))
	{
		case CCC_TagColor:
		{
			strcopy(g_sTagColor[client], sizeof(g_sTagColor[]), color);
		}
		case CCC_NameColor:
		{
			strcopy(g_sUsernameColor[client], sizeof(g_sUsernameColor[]), color);
		}
		case CCC_ChatColor:
		{
			strcopy(g_sChatColor[client], sizeof(g_sChatColor[]), color);
		}
	}

	return 1;
}

public int Native_GetTag(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!client || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
		return 0;
	}

	SetNativeString(2, g_sTag[client], GetNativeCell(3));
	return 1;
}

public int Native_SetTag(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!client || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
		return 0;
	}

	GetNativeString(2, g_sTag[client], sizeof(g_sTag[]));
	return 1;
}

public int Native_ResetColor(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!client || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
		return 0;
	}

	switch(GetNativeCell(2))
	{
		case CCC_TagColor:
		{
			strcopy(g_sTagColor[client], sizeof(g_sTagColor[]), g_sDefaultTagColor[client]);
		}
		case CCC_NameColor:
		{
			strcopy(g_sUsernameColor[client], sizeof(g_sUsernameColor[]), g_sDefaultUsernameColor[client]);
		}
		case CCC_ChatColor:
		{
			strcopy(g_sChatColor[client], sizeof(g_sChatColor[]), g_sDefaultChatColor[client]);
		}
	}

	return 1;
}

public int Native_ResetTag(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!client || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
		return 0;
	}

	strcopy(g_sTag[client], sizeof(g_sTag[]), g_sDefaultTag[client]);
	return 1;
}

public int Native_UpdateIgnoredArray(Handle plugin, int numParams)
{
	GetNativeArray(1, g_Ignored, sizeof(g_Ignored));

	return 1;
}