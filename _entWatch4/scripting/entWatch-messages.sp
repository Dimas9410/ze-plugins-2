//====================================================================================================
//
// Name: [entWatch] Messages
// Author: zaCade & Prometheum
// Description: Handle the chat messages of [entWatch]
//
//====================================================================================================
#include <smlib>
#include <multicolors>

#pragma newdecls required

#include <sourcemod>
#include <entWatch4>
#include <entWatch_core>

#define MESSAGEFORMAT "\x07%s[entWatch] \x07%s%s \x07%s(\x07%s%s\x07%s) %t \x07%s%s"

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin myinfo =
{
	name         = "[entWatch] Messages",
	author       = "zaCade & Prometheum",
	description  = "Handle the chat messages of [entWatch]",
	version      = "4.0.0"
};

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnPluginStart()
{
	LoadTranslations("entWatch.messages.phrases");
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void EW_OnClientItemDrop(any[] itemArray, int client, int index)
{
	if (itemArray[item_display] & DISPLAY_CHAT)
	{
		char sName[32];
		GetClientName(client, sName, sizeof(sName));

		char sAuth[32];
		GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));

		CRemoveTags(sName, sizeof(sName));
		CPrintToChatAll(MESSAGEFORMAT, "E01B5D", "EDEDED", sName, "E562BA", "B2B2B2", sAuth, "E562BA", "Item Drop", itemArray[item_color], itemArray[item_name]);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void EW_OnClientItemDeath(any[] itemArray, int client, int index)
{
	if (itemArray[item_display] & DISPLAY_CHAT)
	{
		char sName[32];
		GetClientName(client, sName, sizeof(sName));

		char sAuth[32];
		GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));

		CRemoveTags(sName, sizeof(sName));
		CPrintToChatAll(MESSAGEFORMAT, "E01B5D", "EDEDED", sName, "F1B567", "B2B2B2", sAuth, "F1B567", "Item Death", itemArray[item_color], itemArray[item_name]);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void EW_OnClientItemPickup(any[] itemArray, int client, int index)
{
	if (itemArray[item_display] & DISPLAY_CHAT)
	{
		char sName[32];
		GetClientName(client, sName, sizeof(sName));

		char sAuth[32];
		GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));

		CRemoveTags(sName, sizeof(sName));
		CPrintToChatAll(MESSAGEFORMAT, "E01B5D", "EDEDED", sName, "C9EF66", "B2B2B2", sAuth, "C9EF66", "Item Pickup", itemArray[item_color], itemArray[item_name]);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void EW_OnClientItemDisconnect(any[] itemArray, int client, int index)
{
	if (itemArray[item_display] & DISPLAY_CHAT)
	{
		char sName[32];
		GetClientName(client, sName, sizeof(sName));

		char sAuth[32];
		GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));

		CRemoveTags(sName, sizeof(sName));
		CPrintToChatAll(MESSAGEFORMAT, "E01B5D", "EDEDED", sName, "F1B567", "B2B2B2", sAuth, "F1B567", "Item Disconnect", itemArray[item_color], itemArray[item_name]);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void EW_OnClientItemActivate(any[] itemArray, int client, int index)
{
	if (itemArray[item_display] & DISPLAY_USE)
	{
		char sName[32];
		GetClientName(client, sName, sizeof(sName));

		char sAuth[32];
		GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));

		CRemoveTags(sName, sizeof(sName));
		CPrintToChatAll(MESSAGEFORMAT, "E01B5D", "EDEDED", sName, "67ADDF", "B2B2B2", sAuth, "67ADDF", "Item Activate", itemArray[item_color], itemArray[item_name]);
	}
}