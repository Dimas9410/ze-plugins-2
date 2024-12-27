#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define SF_WEAPON_START_CONSTRAINED (1<<0)

Handle hFallInit;
Handle hTeleport;

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin myinfo =
{
	name         = "FixPointTeleport",
	author       = "zaCade",
	description  = "Fix crashes caused by point_teleport entity teleporting weapons.",
	version      = "1.0.0"
};

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnPluginStart()
{
	Handle hGameConf;
	if ((hGameConf = LoadGameConfigFile("FixPointTeleport.games")) == INVALID_HANDLE)
	{
		SetFailState("Couldn't load \"FixPointTeleport.games\" game config!");
		return;
	}

	// CBaseCombatWeapon::FallInit()
	StartPrepSDKCall(SDKCall_Entity);

	if (!PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "FallInit"))
	{
		CloseHandle(hGameConf);
		SetFailState("PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, \"FallInit\") failed!");
		return;
	}

	hFallInit = EndPrepSDKCall();

	// CBaseEntity::Teleport(Vector const*, QAngle const*, Vector const*)
	int iOffset;
	if ((iOffset = GameConfGetOffset(hGameConf, "Teleport")) == -1)
	{
		CloseHandle(hGameConf);
		SetFailState("GameConfGetOffset(hGameConf, \"Teleport\") failed!");
		return;
	}

	if ((hTeleport = DHookCreate(iOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, OnEntityTeleport)) == INVALID_HANDLE)
	{
		CloseHandle(hGameConf);
		SetFailState("DHookCreate(iOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, OnEntityTeleport) failed!");
		return;
	}

	DHookAddParam(hTeleport, HookParamType_VectorPtr);
	DHookAddParam(hTeleport, HookParamType_ObjectPtr);
	DHookAddParam(hTeleport, HookParamType_VectorPtr);

	// Late load.
	int entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, "weapon_*")) != INVALID_ENT_REFERENCE)
	{
		OnEntityCreated(entity, "weapon_*");
	}

	CloseHandle(hGameConf);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnEntityCreated(int entity, const char[] classname)
{
	if (strncmp(classname, "weapon_", 7, false) == 0)
	{
		DHookEntity(hTeleport, true, entity);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public MRESReturn OnEntityTeleport(int entity, Handle hParams)
{
	if (IsValidEntity(entity))
	{
		// Dont reinitialize, if we dont have spawnflags or are missing the start constrained spawnflag.
		if (!HasEntProp(entity, Prop_Data, "m_spawnflags") || (GetEntProp(entity, Prop_Data, "m_spawnflags") & SF_WEAPON_START_CONSTRAINED) == 0)
			return;

		SDKCall(hFallInit, entity);
	}
}