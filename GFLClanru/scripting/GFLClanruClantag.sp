#include <sourcemod>
#include <cstrike>

#define CLANID "33752602"
#define GROUP "Clantag"

bool g_bInGroup[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name			= "GFLClan.com Clantag",
	author			= "BotoX",
	description		= "Assign group to people wearing gfl clantag",
	version			= "1.0",
	url				= ""
};

public void OnPluginStart()
{
	/* Handle late load */
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && IsClientAuthorized(client))
		{
			OnClientPostAdminFilter(client);
		}
	}
}

public void OnClientPostAdminFilter(int client)
{
	CheckClantag(client);
}

public void OnClientSettingsChanged(int client)
{
	CheckClantag(client);
}

public void OnClientDisconnect(int client)
{
	g_bInGroup[client] = false;
}

bool CheckClantag(int client)
{
	if(!IsClientAuthorized(client) || g_bInGroup[client])
		return false;

	char sClanID[32];
	GetClientInfo(client, "cl_clanid", sClanID, sizeof(sClanID));

	if(!StrEqual(sClanID, CLANID))
		return false;

	AdminId adm;
	// Use a pre-existing admin if we can
	if((adm = GetUserAdmin(client)) == INVALID_ADMIN_ID)
	{
		LogMessage("Creating new admin for %L", client);
		adm = CreateAdmin("");
		SetUserAdmin(client, adm, true);
	}

	GroupId grp;
	if((grp = FindAdmGroup(GROUP)) != INVALID_GROUP_ID)
	{
		if(adm.InheritGroup(grp))
		{
			LogMessage("Added %L to group %s", client, GROUP);
			return true;
		}
	}

	return false;
}
