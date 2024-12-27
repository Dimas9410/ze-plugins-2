//====================================================================================================
//
// Name: [entWatch] Core
// Author: zaCade & Prometheum
// Description: Handle the core functions of [entWatch]
//
//====================================================================================================
#include <smlib>

#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <entWatch4>

/* BOOLS */
bool g_bLate;

/* ARRAYS */
ArrayList g_hArray_Items;
ArrayList g_hArray_Config;

/* FORWARDS */
Handle g_hFwd_OnClientItemDrop;
Handle g_hFwd_OnClientItemDeath;
Handle g_hFwd_OnClientItemPickup;
Handle g_hFwd_OnClientItemActivate;
Handle g_hFwd_OnClientItemDisconnect;

/* HOOKS */
Handle g_hFwd_OnClientItemCanPickup;
Handle g_hFwd_OnClientItemCanActivate;

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin myinfo =
{
	name         = "[entWatch] Core",
	author       = "zaCade & Prometheum",
	description  = "Handle the core functions of [entWatch]",
	version      = "4.0.0"
};

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int errorSize)
{
	g_bLate = bLate;

	CreateNative("EW_GetItemCount", Native_GetItemCount);
	CreateNative("EW_GetItemArray", Native_GetItemArray);
	CreateNative("EW_SetItemArray", Native_SetItemArray);

	RegPluginLibrary("entWatch-core");
	return APLRes_Success;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnPluginStart()
{
	g_hFwd_OnClientItemDrop        = CreateGlobalForward("EW_OnClientItemDrop",        ET_Ignore, Param_Array, Param_Cell, Param_Cell);
	g_hFwd_OnClientItemDeath       = CreateGlobalForward("EW_OnClientItemDeath",       ET_Ignore, Param_Array, Param_Cell, Param_Cell);
	g_hFwd_OnClientItemPickup      = CreateGlobalForward("EW_OnClientItemPickup",      ET_Ignore, Param_Array, Param_Cell, Param_Cell);
	g_hFwd_OnClientItemActivate    = CreateGlobalForward("EW_OnClientItemActivate",    ET_Ignore, Param_Array, Param_Cell, Param_Cell);
	g_hFwd_OnClientItemDisconnect  = CreateGlobalForward("EW_OnClientItemDisconnect",  ET_Ignore, Param_Array, Param_Cell, Param_Cell);

	g_hFwd_OnClientItemCanPickup   = CreateGlobalForward("EW_OnClientItemCanPickup",   ET_Hook, Param_Array, Param_Cell, Param_Cell);
	g_hFwd_OnClientItemCanActivate = CreateGlobalForward("EW_OnClientItemCanActivate", ET_Hook, Param_Array, Param_Cell, Param_Cell);

	g_hArray_Items  = new ArrayList(512);
	g_hArray_Config = new ArrayList(512);

	HookEvent("player_death", OnClientDeath);
	HookEvent("round_start",  OnRoundStart);

	if (g_bLate)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client) || IsFakeClient(client))
				continue;

			SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponPickup);
			SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDrop);
			SDKHook(client, SDKHook_WeaponCanUse, OnWeaponTouch);
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnMapStart()
{
	g_hArray_Items.Clear();
	g_hArray_Config.Clear();

	char sCurrentMap[128];
	GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));
	String_ToLower(sCurrentMap, sCurrentMap, sizeof(sCurrentMap));

	char sFilePathDefault[PLATFORM_MAX_PATH];
	char sFilePathOverride[PLATFORM_MAX_PATH];

	BuildPath(Path_SM, sFilePathDefault, sizeof(sFilePathDefault), "configs/entwatch/%s.cfg", sCurrentMap);
	BuildPath(Path_SM, sFilePathOverride, sizeof(sFilePathOverride), "configs/entwatch/%s.override.cfg", sCurrentMap);

	KeyValues hConfig = new KeyValues("items");

	if (FileExists(sFilePathOverride))
	{
		if (!hConfig.ImportFromFile(sFilePathOverride))
		{
			LogMessage("Unable to load config \"%s\"!", sFilePathOverride);

			delete hConfig;
			return;
		}
		else LogMessage("Loaded config \"%s\"", sFilePathOverride);
	}
	else
	{
		if (!hConfig.ImportFromFile(sFilePathDefault))
		{
			LogMessage("Unable to load config \"%s\"!", sFilePathDefault);

			delete hConfig;
			return;
		}
		else LogMessage("Loaded config \"%s\"", sFilePathDefault);
	}

	if (hConfig.GotoFirstSubKey())
	{
		do
		{
			any itemArray[items];
			hConfig.GetString("name",   itemArray[item_name],   sizeof(itemArray[item_name]));
			hConfig.GetString("short",  itemArray[item_short],  sizeof(itemArray[item_short]));
			hConfig.GetString("color",  itemArray[item_color],  sizeof(itemArray[item_color]));
			hConfig.GetString("filter", itemArray[item_filter], sizeof(itemArray[item_filter]));

			itemArray[item_weaponid]  = hConfig.GetNum("weaponid");
			itemArray[item_buttonid]  = hConfig.GetNum("buttonid");
			itemArray[item_triggerid] = hConfig.GetNum("triggerid");
			itemArray[item_display]   = hConfig.GetNum("display");
			itemArray[item_mode]      = hConfig.GetNum("mode");
			itemArray[item_maxuses]   = hConfig.GetNum("maxuses");
			itemArray[item_cooldown]  = hConfig.GetNum("cooldown");

			g_hArray_Config.PushArray(itemArray, sizeof(itemArray));
		}
		while (hConfig.GotoNextKey());
	}

	delete hConfig;
	return;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnRoundStart(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	if (g_hArray_Items.Length)
	{
		for (int index; index < g_hArray_Items.Length; index++)
		{
			any itemArray[items];
			g_hArray_Items.GetArray(index, itemArray, sizeof(itemArray));

			if (itemArray[item_owned] && itemArray[item_owner] >= 0)
				g_hArray_Items.Erase(index);
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnEntityCreated(int entity, const char[] sClassname)
{
	if (Entity_IsValid(entity))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawned);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnEntitySpawned(int entity)
{
	if (Entity_IsValid(entity) && g_hArray_Config.Length)
	{
		for (int index; index < g_hArray_Items.Length; index++)
		{
			any itemArray[items];
			g_hArray_Items.GetArray(index, itemArray, sizeof(itemArray));

			if (RegisterItem(itemArray, entity))
			{
				g_hArray_Items.SetArray(index, itemArray, sizeof(itemArray));
				return;
			}
		}

		for (int index; index < g_hArray_Config.Length; index++)
		{
			any itemArray[items];
			g_hArray_Config.GetArray(index, itemArray, sizeof(itemArray));

			if (RegisterItem(itemArray, entity))
			{
				g_hArray_Items.PushArray(itemArray, sizeof(itemArray));
				return;
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock bool RegisterItem(any[] itemArray, int entity)
{
	if (Entity_IsValid(entity))
	{
		if (itemArray[item_weaponid] && itemArray[item_weaponid] == Entity_GetHammerId(entity))
		{
			if (!itemArray[item_weapon] && (Entity_GetOwner(entity) == INVALID_ENT_REFERENCE))
			{
				itemArray[item_weapon] = entity;
				return true;
			}
		}
		else if (itemArray[item_buttonid] && itemArray[item_buttonid] == Entity_GetHammerId(entity))
		{
			if (!itemArray[item_button] && (Entity_GetParent(entity) == INVALID_ENT_REFERENCE ||
				(itemArray[item_weapon] && Entity_GetParent(entity) == itemArray[item_weapon])))
			{
				SDKHook(entity, SDKHook_Use, OnButtonPress);

				itemArray[item_button] = entity;
				return true;
			}
		}
		else if (itemArray[item_triggerid] && itemArray[item_triggerid] == Entity_GetHammerId(entity))
		{
			if (!itemArray[item_trigger] && (Entity_GetParent(entity) == INVALID_ENT_REFERENCE ||
				(itemArray[item_weapon] && Entity_GetParent(entity) == itemArray[item_weapon])))
			{
				SDKHook(entity, SDKHook_StartTouch, OnTriggerTouch);
				SDKHook(entity, SDKHook_EndTouch, OnTriggerTouch);
				SDKHook(entity, SDKHook_Touch, OnTriggerTouch);

				itemArray[item_trigger] = entity;
				return true;
			}
		}
	}
	return false;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnEntityDestroyed(int entity)
{
	if (Entity_IsValid(entity) && g_hArray_Items.Length)
	{
		for (int index; index < g_hArray_Items.Length; index++)
		{
			any itemArray[items];
			g_hArray_Items.GetArray(index, itemArray, sizeof(itemArray));

			if (itemArray[item_weapon] && itemArray[item_weapon] == entity)
			{
				g_hArray_Items.Erase(index);
				return;
			}

			if (itemArray[item_button] && itemArray[item_button] == entity)
			{
				itemArray[item_button] = INVALID_ENT_REFERENCE;

				g_hArray_Items.SetArray(index, itemArray, sizeof(itemArray));
				return;
			}

			if (itemArray[item_trigger] && itemArray[item_trigger] == entity)
			{
				itemArray[item_trigger] = INVALID_ENT_REFERENCE;

				g_hArray_Items.SetArray(index, itemArray, sizeof(itemArray));
				return;
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnClientPutInServer(int client)
{
	if (!IsFakeClient(client))
	{
		SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponPickup);
		SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDrop);
		SDKHook(client, SDKHook_WeaponCanUse, OnWeaponTouch);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnClientDisconnect(int client)
{
	if (!IsFakeClient(client) && g_hArray_Items.Length)
	{
		for (int index; index < g_hArray_Items.Length; index++)
		{
			any itemArray[items];
			g_hArray_Items.GetArray(index, itemArray, sizeof(itemArray));

			if (itemArray[item_owned] && itemArray[item_owner] == client)
			{
				itemArray[item_owner] = INVALID_ENT_REFERENCE;
				itemArray[item_owned] = false;

				Call_StartForward(g_hFwd_OnClientItemDisconnect);
				Call_PushArray(itemArray, sizeof(itemArray));
				Call_PushCell(client);
				Call_PushCell(index);
				Call_Finish();

				g_hArray_Items.SetArray(index, itemArray, sizeof(itemArray));
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnClientDeath(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));

	if (Client_IsValid(client) && !IsFakeClient(client) && g_hArray_Items.Length)
	{
		for (int index; index < g_hArray_Items.Length; index++)
		{
			any itemArray[items];
			g_hArray_Items.GetArray(index, itemArray, sizeof(itemArray));

			if (itemArray[item_owned] && itemArray[item_owner] == client)
			{
				itemArray[item_owner] = INVALID_ENT_REFERENCE;
				itemArray[item_owned] = false;

				Call_StartForward(g_hFwd_OnClientItemDeath);
				Call_PushArray(itemArray, sizeof(itemArray));
				Call_PushCell(client);
				Call_PushCell(index);
				Call_Finish();

				g_hArray_Items.SetArray(index, itemArray, sizeof(itemArray));
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action OnWeaponPickup(int client, int weapon)
{
	if (Client_IsValid(client) && Entity_IsValid(weapon) && g_hArray_Items.Length)
	{
		for (int index; index < g_hArray_Items.Length; index++)
		{
			any itemArray[items];
			g_hArray_Items.GetArray(index, itemArray, sizeof(itemArray));

			if (itemArray[item_weapon] && itemArray[item_weapon] == weapon)
			{
				itemArray[item_owner] = client;
				itemArray[item_owned] = true;

				Call_StartForward(g_hFwd_OnClientItemPickup);
				Call_PushArray(itemArray, sizeof(itemArray));
				Call_PushCell(client);
				Call_PushCell(index);
				Call_Finish();

				g_hArray_Items.SetArray(index, itemArray, sizeof(itemArray));
				return;
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action OnWeaponDrop(int client, int weapon)
{
	if (Client_IsValid(client) && Entity_IsValid(weapon) && g_hArray_Items.Length)
	{
		for (int index; index < g_hArray_Items.Length; index++)
		{
			any itemArray[items];
			g_hArray_Items.GetArray(index, itemArray, sizeof(itemArray));

			if (itemArray[item_weapon] && itemArray[item_weapon] == weapon)
			{
				itemArray[item_owner] = INVALID_ENT_REFERENCE;
				itemArray[item_owned] = false;

				Call_StartForward(g_hFwd_OnClientItemDrop);
				Call_PushArray(itemArray, sizeof(itemArray));
				Call_PushCell(client);
				Call_PushCell(index);
				Call_Finish();

				g_hArray_Items.SetArray(index, itemArray, sizeof(itemArray));
				return;
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action OnButtonPress(int button, int client)
{
	if (Client_IsValid(client) && Entity_IsValid(button) && g_hArray_Items.Length)
	{
		if (HasEntProp(button, Prop_Data, "m_bLocked") &&
			GetEntProp(button, Prop_Data, "m_bLocked"))
			return Plugin_Handled;

		for (int index; index < g_hArray_Items.Length; index++)
		{
			any itemArray[items];
			g_hArray_Items.GetArray(index, itemArray, sizeof(itemArray));

			if (itemArray[item_button] && itemArray[item_button] == button)
			{
				if (itemArray[item_owned] && itemArray[item_owner] == client)
				{
					Action aResult;
					Call_StartForward(g_hFwd_OnClientItemCanActivate);
					Call_PushArray(itemArray, sizeof(itemArray));
					Call_PushCell(client);
					Call_PushCell(index);
					Call_Finish(aResult);

					if ((aResult == Plugin_Continue) || (aResult == Plugin_Changed))
					{
						switch(itemArray[item_mode])
						{
							case(1):
							{
								if (itemArray[item_nextuse] < RoundToCeil(GetEngineTime()))
								{
									itemArray[item_nextuse] = RoundToCeil(GetEngineTime()) + itemArray[item_cooldown];
								}
								else return Plugin_Handled;
							}
							case(2):
							{
								if (itemArray[item_uses] < itemArray[item_maxuses])
								{
									itemArray[item_uses]++;
								}
								else return Plugin_Handled;
							}
							case(3):
							{
								if (itemArray[item_nextuse] < RoundToCeil(GetEngineTime()) && itemArray[item_uses] < itemArray[item_maxuses])
								{
									itemArray[item_nextuse] = RoundToCeil(GetEngineTime()) + itemArray[item_cooldown];
									itemArray[item_uses]++;
								}
								else return Plugin_Handled;
							}
							case(4):
							{
								if (itemArray[item_nextuse] < RoundToCeil(GetEngineTime()))
								{
									itemArray[item_uses]++;

									if (itemArray[item_uses] >= itemArray[item_maxuses])
									{
										itemArray[item_nextuse] = RoundToCeil(GetEngineTime()) + itemArray[item_cooldown];
										itemArray[item_uses] = 0;
									}
								}
								else return Plugin_Handled;
							}
						}

						if (itemArray[item_filter][0])
							Entity_SetName(client, itemArray[item_filter]);

						Call_StartForward(g_hFwd_OnClientItemActivate);
						Call_PushArray(itemArray, sizeof(itemArray));
						Call_PushCell(client);
						Call_PushCell(index);
						Call_Finish();
					}

					g_hArray_Items.SetArray(index, itemArray, sizeof(itemArray));
					return aResult;
				}
			}
		}
	}
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action OnTriggerTouch(int trigger, int client)
{
	if (Client_IsValid(client) && Entity_IsValid(trigger) && g_hArray_Items.Length)
	{
		for (int index; index < g_hArray_Items.Length; index++)
		{
			any itemArray[items];
			g_hArray_Items.GetArray(index, itemArray, sizeof(itemArray));

			if (itemArray[item_trigger] && itemArray[item_trigger] == trigger)
			{
				Action aResult;
				Call_StartForward(g_hFwd_OnClientItemCanPickup);
				Call_PushArray(itemArray, sizeof(itemArray));
				Call_PushCell(client);
				Call_PushCell(index);
				Call_Finish(aResult);

				g_hArray_Items.SetArray(index, itemArray, sizeof(itemArray));
				return aResult;
			}
		}
	}
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action OnWeaponTouch(int client, int weapon)
{
	if (Client_IsValid(client) && Entity_IsValid(weapon) && g_hArray_Items.Length)
	{
		for (int index; index < g_hArray_Items.Length; index++)
		{
			any itemArray[items];
			g_hArray_Items.GetArray(index, itemArray, sizeof(itemArray));

			if (itemArray[item_weapon] && itemArray[item_weapon] == weapon)
			{
				Action aResult;
				Call_StartForward(g_hFwd_OnClientItemCanPickup);
				Call_PushArray(itemArray, sizeof(itemArray));
				Call_PushCell(client);
				Call_PushCell(index);
				Call_Finish(aResult);

				g_hArray_Items.SetArray(index, itemArray, sizeof(itemArray));
				return aResult;
			}
		}
	}
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int Native_GetItemCount(Handle hPlugin, int numParams)
{
	return g_hArray_Items.Length;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int Native_GetItemArray(Handle hPlugin, int numParams)
{
	any itemArray[items];

	int index = GetNativeCell(1);
	int size  = GetNativeCell(3);

	g_hArray_Items.GetArray(index, itemArray, size);

	SetNativeArray(2, itemArray, size);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public int Native_SetItemArray(Handle hPlugin, int numParams)
{
	any itemArray[items];

	int index = GetNativeCell(1);
	int size  = GetNativeCell(3);

	GetNativeArray(2, itemArray, size);

	g_hArray_Items.SetArray(index, itemArray, size);
}