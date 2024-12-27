#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <zombiereloaded>

#pragma semicolon 1
#pragma newdecls required

Handle g_hCVar_PushNadesEnabled = INVALID_HANDLE;
Handle g_hCVar_PushRange = INVALID_HANDLE;
Handle g_hCVar_PushStrength = INVALID_HANDLE;
Handle g_hCVar_PushScale = INVALID_HANDLE;


public Plugin myinfo =
{
	name 		= "PushNades",
	author 		= "Neon",
	description = "Push Zombies away from the Human that threw the HE-Grenade",
	version 	= "1.0",
	url 		= "https://steamcommunity.com/id/n3ontm"
}

public void OnPluginStart()
{
	g_hCVar_PushNadesEnabled = CreateConVar("sm_hegrenade_push_enabled", "0", "Enable PushBack for HE-Grenades", 0, true, 0.0, true, 1.0);
	g_hCVar_PushScale = CreateConVar("sm_hegrenade_push_scale", "0", "Make the push scale with the distance to the explosion", 0, true, 0.0, true, 1.0);
	g_hCVar_PushRange = CreateConVar("sm_hegrenade_push_range", "500", "Range arround Explosion in which Zombies are affected by the push.");
	g_hCVar_PushStrength = CreateConVar("sm_hegrenade_push_strength", "2500", "How strong the HE-Grenade pushes back");

	AutoExecConfig(true, "plugin.PushNades");

	HookEvent("hegrenade_detonate", OnHEDetonate);
}

public Action OnHEDetonate(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	if (!GetConVarBool(g_hCVar_PushNadesEnabled))
		return Plugin_Continue;

	float fNadeOrigin[3];
	fNadeOrigin[0] = hEvent.GetFloat("x");
	fNadeOrigin[1] = hEvent.GetFloat("y");
	fNadeOrigin[2] = hEvent.GetFloat("z");

	int iOwner = GetClientOfUserId(hEvent.GetInt("userid"));

	if (!IsValidClient(iOwner, false))
		return Plugin_Continue;

	if (!IsPlayerAlive(iOwner) || !ZR_IsClientHuman(iOwner))
		return Plugin_Continue;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidClient(client, false))
		{
			if (IsPlayerAlive(client) && ZR_IsClientZombie(client))
			{
				float fZombieOrigin[3];
				GetClientAbsOrigin(client, fZombieOrigin);

				float fDistance = GetVectorDistance(fZombieOrigin, fNadeOrigin, false);
				float fMaxRange = GetConVarFloat(g_hCVar_PushRange);

				if (fDistance <= fMaxRange)
				{
					float fOwnerOrigin[3];
					GetClientAbsOrigin(iOwner, fOwnerOrigin);

					float fPushVector[3];
					MakeVectorFromPoints(fOwnerOrigin, fZombieOrigin, fPushVector);

					float fCurrentVector[3];
					//GetEntPropVector(iOwner, Prop_Data, "m_vecVelocity", fCurrentVector);

					float fPushStrength = GetConVarFloat(g_hCVar_PushStrength);

					float fDistanceScalingFactor = 1.0;
					if (GetConVarBool(g_hCVar_PushScale))
						fDistanceScalingFactor = 1.0 - ((1.0/fMaxRange) * fDistance);


					NormalizeVector(fPushVector, fPushVector);
					fPushVector[0] *= fPushStrength * fDistanceScalingFactor;
					fPushVector[1] *= fPushStrength * fDistanceScalingFactor;
					fPushVector[2] *= fPushStrength * fDistanceScalingFactor;

					fPushVector[0] += fCurrentVector[0];
					fPushVector[1] += fCurrentVector[1];
					fPushVector[2] += fCurrentVector[2];

					TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fPushVector);
				}
			}
		}

	}
	return Plugin_Continue;
}


bool IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}
