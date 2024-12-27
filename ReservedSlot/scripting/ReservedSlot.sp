#include <sourcemod>
#include <cstrike>
#include <connect>

#undef REQUIRE_PLUGIN
#include <AFKManager>
#include <GFLClanru>
#include <entWatch>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

bool g_Plugin_AFKManager;
bool g_Plugin_GFLClanru;
bool g_Plugin_entWatch;

int g_Client_Reservation[MAXPLAYERS + 1] = {0, ...};

public Plugin myinfo =
{
	name = "Reserved Slot",
	author = "BotoX",
	description = "Kicks someone to make space for a connecting donator.",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	/* Late load */
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && IsClientAuthorized(client))
			OnClientPostAdminCheck(client);
	}
}

public void OnAllPluginsLoaded()
{
	g_Plugin_AFKManager = LibraryExists("AFKManager");
	g_Plugin_GFLClanru = LibraryExists("GFLClanru");
	g_Plugin_entWatch = LibraryExists("entWatch");

	LogMessage("ReservedSlots capabilities:\nAFKManager: %s\nGFLClanru: %s\nentWatch: %s",
		(g_Plugin_AFKManager ? "loaded" : "not loaded"),
		(g_Plugin_GFLClanru ? "loaded" : "not loaded"),
		(g_Plugin_entWatch ? "loaded" : "not loaded"));
}

public void OnClientPostAdminCheck(int client)
{
	AdminId admin = GetUserAdmin(client);
	if(admin == INVALID_ADMIN_ID)
		return;

	if(GetAdminFlag(admin, Admin_Reservation))
	{
		g_Client_Reservation[client] = GetAdminImmunityLevel(admin);
		if(!g_Client_Reservation[client])
			g_Client_Reservation[client] = 1;
	}
}

public void OnClientDisconnect(int client)
{
	g_Client_Reservation[client] = 0;
}

public EConnect OnClientPreConnectEx(const char[] sName, char sPassword[255], const char[] sIP, const char[] sSteam32ID, char sRejectReason[255])
{
	// Server not full, nothing to do...
	if(GetClientCount(false) < MaxClients)
		return k_OnClientPreConnectEx_Accept;

	// Try to get precached admin id.
	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, sSteam32ID);
	int Immunity = 0;

	// Valid and has reserved slot?
	if(admin != INVALID_ADMIN_ID && GetAdminFlag(admin, Admin_Reservation))
	{
		Immunity = GetAdminImmunityLevel(admin);

		if(!KickValidClient(sName, sSteam32ID, admin, Immunity))
		{
			Format(sRejectReason, sizeof(sRejectReason), "No reserved slot available, sorry.");
			return k_OnClientPreConnectEx_Reject;
		}
		else
			return k_OnClientPreConnectEx_Accept;
	}

	if(g_Plugin_GFLClanru)
	{
		DataPack pack = new DataPack();
		pack.WriteCell(admin);
		pack.WriteCell(Immunity);
		pack.WriteString(sName);

		AsyncHasSteamIDReservedSlot(sSteam32ID, AsyncHasSteamIDReservedSlotCallback, pack);
		return k_OnClientPreConnectEx_Async;
	}

	// Let the engine handle the rest.
	return k_OnClientPreConnectEx_Accept;
}

public void AsyncHasSteamIDReservedSlotCallback(const char[] sSteam32ID, int Result, any Data)
{
	DataPack pack = view_as<DataPack>(Data);
	// Slot free'd up while waiting or doesn't have a reserved slot?
	if(GetClientCount(false) < MaxClients || Result <= 0)
	{
		delete pack;
		ClientPreConnectEx(sSteam32ID, k_OnClientPreConnectEx_Accept, "");
		return;
	}

	pack.Reset();

	AdminId admin = view_as<AdminId>(pack.ReadCell());
	int Immunity = pack.ReadCell();
	char sName[MAX_NAME_LENGTH];
	pack.ReadString(sName, sizeof(sName));

	delete pack;

	if(Result > Immunity)
		Immunity = Result;

	if(!KickValidClient(sName, sSteam32ID, admin, Immunity))
		ClientPreConnectEx(sSteam32ID, k_OnClientPreConnectEx_Reject, "No reserved slot available, sorry.");
	else
		ClientPreConnectEx(sSteam32ID, k_OnClientPreConnectEx_Accept, "");
}

stock bool KickValidClient(const char[] sName, const char[] sSteam32ID, AdminId admin, int Immunity)
{
	int HighestValue[4] = {0, ...};
	int HighestValueClient[4] = {0, ...};

	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client) || IsFakeClient(client))
			continue;

		int Donator = g_Client_Reservation[client];
		int ConnectionTime = RoundToNearest(GetClientTime(client));

		int IdleTime;
		if(g_Plugin_AFKManager)
			IdleTime = GetClientIdleTime(client);
		else // Fall back to highest connection time.
			IdleTime = ConnectionTime;

		bool HasItem = false;
		if(g_Plugin_entWatch)
			HasItem = entWatch_HasSpecialItem(client);

		/* Spectators
		 * Sort by idle time and also kick donators if IdleTime > 30
		 */
		if(GetClientTeam(client) <= CS_TEAM_SPECTATOR)
		{
			if(!Donator || IdleTime > 30)
			{
				if(IdleTime > HighestValue[0])
				{
					HighestValue[0] = IdleTime;
					HighestValueClient[0] = client;
				}
			}
		}
		/* Spectators */

		/* Dead non-donator with IdleTime > 30
		 * Sort by idle time and don't kick donators.
		 */
		if(!Donator && GetClientTeam(client) > CS_TEAM_SPECTATOR && !IsPlayerAlive(client))
		{
			if(IdleTime > 30 && IdleTime > HighestValue[1])
			{
				HighestValue[1] = IdleTime;
				HighestValueClient[1] = client;
			}
		}
		/* Dead non-donator with IdleTime > 30 */

		/* Alive non-donator with IdleTime > 30
		 * Sort by idle time and don't kick donators and item owners.
		 *
		if(!Donator && IsPlayerAlive(client) && !HasItem)
		{
			if(IdleTime > 30 && IdleTime > HighestValue[2])
			{
				HighestValue[2] = IdleTime;
				HighestValueClient[2] = client;
			}
		}
		* Alive non-donator with IdleTime > 30 */
	}

	// Check if any condition was met in the correct order and perform kick
	for(int i = 0; i < sizeof(HighestValue); i++)
	{
		if(HighestValue[i])
		{
			ExecuteKickValidClient(HighestValueClient[i], sName, sSteam32ID, admin, Immunity);
			return true;
		}
	}

	return false;
}

stock void ExecuteKickValidClient(int client, const char[] sName, const char[] sSteam32ID, AdminId admin, int Immunity)
{
	KickClientEx(client, "Kicked for reserved slot (%s joined).", sName);
}
