#include <sourcemod>
#include <sdktools>
#include <dhooks>
#undef REQUIRE_PLUGIN
#include <zombiereloaded>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name 			= "PlayerVisibility",
	author 			= "BotoX",
	description 	= "Fades players away when you get close to them.",
	version 		= "1.2",
	url 			= ""
};

// bool CBaseEntity::AcceptInput( const char *szInputName, CBaseEntity *pActivator, CBaseEntity *pCaller, variant_t Value, int outputID )
Handle g_hAcceptInput;
Handle g_hThinkTimer;

ConVar g_CVar_MaxDistance;
ConVar g_CVar_MinFactor;
ConVar g_CVar_MinAlpha;
ConVar g_CVar_MinPlayers;

float g_fMaxDistance;
float g_fMinFactor;
float g_fMinAlpha;
int g_iMinPlayers;

int g_Client_Alpha[MAXPLAYERS + 1] = {255, ...};
bool g_Client_bEnabled[MAXPLAYERS + 1] = {false, ...};

bool g_Plugin_zombiereloaded = false;

public void OnPluginStart()
{
	Handle hGameConf = LoadGameConfigFile("sdktools.games");
	if(hGameConf == INVALID_HANDLE)
	{
		SetFailState("Couldn't load sdktools game config!");
		return;
	}

	int Offset = GameConfGetOffset(hGameConf, "AcceptInput");
	g_hAcceptInput = DHookCreate(Offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, AcceptInput);
	DHookAddParam(g_hAcceptInput, HookParamType_CharPtr);
	DHookAddParam(g_hAcceptInput, HookParamType_CBaseEntity);
	DHookAddParam(g_hAcceptInput, HookParamType_CBaseEntity);
	DHookAddParam(g_hAcceptInput, HookParamType_Object, 20, DHookPass_ByVal|DHookPass_ODTOR|DHookPass_OCTOR|DHookPass_OASSIGNOP); //varaint_t is a union of 12 (float[3]) plus two int type params 12 + 8 = 20
	DHookAddParam(g_hAcceptInput, HookParamType_Int);

	CloseHandle(hGameConf);

	g_CVar_MaxDistance = CreateConVar("sm_pvis_maxdistance", "100.0", "Distance at which models stop fading.", 0, true, 0.0);
	g_fMaxDistance = g_CVar_MaxDistance.FloatValue;
	g_CVar_MaxDistance.AddChangeHook(OnConVarChanged);

	g_CVar_MinFactor = CreateConVar("sm_pvis_minfactor", "0.75", "Smallest allowed alpha factor per client.", 0, true, 0.0, true, 1.0);
	g_fMinFactor = g_CVar_MinFactor.FloatValue;
	g_CVar_MinFactor.AddChangeHook(OnConVarChanged);

	g_CVar_MinAlpha = CreateConVar("sm_pvis_minalpha", "75.0", "Minimum allowed alpha value.", 0, true, 0.0, true, 255.0);
	g_fMinAlpha = g_CVar_MinAlpha.FloatValue;
	g_CVar_MinAlpha.AddChangeHook(OnConVarChanged);

	g_CVar_MinPlayers = CreateConVar("sm_pvis_minplayers", "3.0", "Minimum players within distance to enable fading.", 0, true, 0.0, true, 255.0);
	g_iMinPlayers = g_CVar_MinPlayers.IntValue;
	g_CVar_MinPlayers.AddChangeHook(OnConVarChanged);

	AutoExecConfig(true, "plugin.PlayerVisibility");

	HookEvent("player_spawn", Event_Spawn, EventHookMode_Post);
	HookEvent("player_death", Event_Death, EventHookMode_Post);

	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
			OnClientPutInServer(client);
	}

	g_hThinkTimer = CreateTimer(0.2, Timer_Think, _, TIMER_REPEAT);
}

public Action Timer_Think(Handle timer)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
			DoClientThink(client);
	}
	return Plugin_Continue;
}

public void OnAllPluginsLoaded()
{
	g_Plugin_zombiereloaded = LibraryExists("zombiereloaded");
}

public void OnLibraryAdded(const char[] sName)
{
	if(strcmp(sName, "zombiereloaded", false) == 0)
		g_Plugin_zombiereloaded = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if(strcmp(sName, "zombiereloaded", false) == 0)
		g_Plugin_zombiereloaded = false;
}

public void OnPluginEnd()
{
	KillTimer(g_hThinkTimer);

	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(g_Client_bEnabled[client] && g_Client_Alpha[client] != 255.0)
				SetEntityRenderMode(client, RENDER_NORMAL);
		}
	}
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar == g_CVar_MaxDistance)
		g_fMaxDistance = g_CVar_MaxDistance.FloatValue;

	else if(convar == g_CVar_MinFactor)
		g_fMinFactor = g_CVar_MinFactor.FloatValue;

	else if(convar == g_CVar_MinAlpha)
		g_fMinAlpha = g_CVar_MinAlpha.FloatValue;

	else if(convar == g_CVar_MinPlayers)
		g_iMinPlayers = g_CVar_MinPlayers.IntValue;
}

public void OnClientPutInServer(int client)
{
	g_Client_Alpha[client] = 255;
	g_Client_bEnabled[client] = true;

	DHookEntity(g_hAcceptInput, false, client);
}

// bool CBaseEntity::AcceptInput( const char *szInputName, CBaseEntity *pActivator, CBaseEntity *pCaller, variant_t Value, int outputID )
public MRESReturn AcceptInput(int pThis, Handle hReturn, Handle hParams)
{
	// Should not happen?
	if(DHookIsNullParam(hParams, 2))
		return MRES_Ignored;

	int client = EntRefToEntIndex(DHookGetParam(hParams, 2));
	if(client < 1 || client > MAXPLAYERS)
		return MRES_Ignored;

	if(!g_Client_bEnabled[client])
		return MRES_Ignored;

	char szInputName[32];
	DHookGetParamString(hParams, 1, szInputName, sizeof(szInputName));

	if(!StrEqual(szInputName, "addoutput", false))
		return MRES_Ignored;

	char sValue[128];
	DHookGetParamObjectPtrString(hParams, 4, 0, ObjectValueType_String, sValue, sizeof(sValue));
	int iValueLen = strlen(sValue);

	int aArgs[4] = {0, ...};
	int iArgs = 0;
	bool bFound = false;

	for(int i = 0; i < iValueLen; i++)
	{
		if(sValue[i] == ' ')
		{
			if(bFound)
			{
				sValue[i] = '\0';
				bFound = false;

				if(iArgs >= sizeof(aArgs))
					break;
			}
			continue;
		}

		if(!bFound)
		{
			aArgs[iArgs++] = i;
			bFound = true;
		}
	}

	if(StrEqual(szInputName, "addoutput", false))
	{
		if(StrEqual(sValue[aArgs[0]], "rendermode", false))
		{
			RenderMode renderMode = view_as<RenderMode>(StringToInt(sValue[aArgs[1]]) & 0xFF);
			if(renderMode == RENDER_ENVIRONMENTAL)
			{
				ToolsSetEntityAlpha(client, 255);
				g_Client_Alpha[client] = 255;
				g_Client_bEnabled[client] = false;
			}
			else
				g_Client_bEnabled[client] = true;
		}
		else if(StrEqual(sValue[aArgs[0]], "renderfx", false))
		{
			RenderFx renderFx = view_as<RenderFx>(StringToInt(sValue[aArgs[1]]) & 0xFF);
			if(renderFx != RENDERFX_NONE)
			{
				ToolsSetEntityAlpha(client, 255);
				g_Client_Alpha[client] = 255;
				g_Client_bEnabled[client] = false;
			}
			else
				g_Client_bEnabled[client] = true;
		}
	}
	else if(StrEqual(szInputName, "alpha", false))
	{
		int iAlpha = StringToInt(sValue[aArgs[0]]) & 0xFF;
		if(iAlpha == 0)
		{
			ToolsSetEntityAlpha(client, 255);
			g_Client_Alpha[client] = 255;
			g_Client_bEnabled[client] = false;
		}
		else
		{
			g_Client_bEnabled[client] = true;
			return MRES_Supercede;
		}
	}

	return MRES_Ignored;
}

public void Event_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	CreateTimer(0.1, Timer_SpawnPost, userid);
}

public void Event_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client)
		return;

	g_Client_bEnabled[client] = false;
}

public Action Timer_SpawnPost(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(!client)
		return Plugin_Stop;

	if(!IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Stop;

	ToolsSetEntityAlpha(client, 255);
	g_Client_Alpha[client] = 255;
	g_Client_bEnabled[client] = true;
	return Plugin_Stop;
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	ToolsSetEntityAlpha(client, 255);
	g_Client_Alpha[client] = 255;
	g_Client_bEnabled[client] = false;
}

public void ZR_OnClientHumanPost(int client, bool respawn, bool protect)
{
	ToolsSetEntityAlpha(client, 255);
	g_Client_Alpha[client] = 255;
	g_Client_bEnabled[client] = true;
}

public void DoClientThink(int client)
{
	if(!g_Client_bEnabled[client])
		return;

	int PlayersInRange = 0;
	float fAlpha = 255.0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i == client || !IsClientInGame(i) || !IsPlayerAlive(i))
			continue;

		if(g_Plugin_zombiereloaded && !ZR_IsClientHuman(i))
			continue;

		static float fVec1[3];
		static float fVec2[3];
		GetClientAbsOrigin(client, fVec1);
		GetClientAbsOrigin(i, fVec2);

		float fDistance = GetVectorDistance(fVec1, fVec2, false);
		if(fDistance <= g_fMaxDistance)
		{
			PlayersInRange++;

			float fFactor = fDistance / g_fMaxDistance;
			if(fFactor < g_fMinFactor)
				fFactor = g_fMinFactor;

			fAlpha *= fFactor;
		}
	}

	if(fAlpha < g_fMinAlpha)
		fAlpha = g_fMinAlpha;

	if(PlayersInRange < g_iMinPlayers)
		fAlpha = 255.0;

	int Alpha = RoundToNearest(fAlpha);

	if(Alpha == g_Client_Alpha[client])
		return;

	g_Client_Alpha[client] = Alpha;
	ToolsSetEntityAlpha(client, Alpha);
}

stock void ToolsSetEntityAlpha(int client, int Alpha)
{
	if(Alpha == 255)
	{
		SetEntityRenderMode(client, RENDER_NORMAL);
		return;
	}

	int aColor[4];
	ToolsGetEntityColor(client, aColor);

	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	SetEntityRenderColor(client, aColor[0], aColor[1], aColor[2], Alpha);
}

stock void ToolsGetEntityColor(int entity, int aColor[4])
{
	static bool s_GotConfig = false;
	static char s_sProp[32];

	if(!s_GotConfig)
	{
		Handle GameConf = LoadGameConfigFile("core.games");
		bool Exists = GameConfGetKeyValue(GameConf, "m_clrRender", s_sProp, sizeof(s_sProp));
		CloseHandle(GameConf);

		if(!Exists)
			strcopy(s_sProp, sizeof(s_sProp), "m_clrRender");

		s_GotConfig = true;
	}

	int Offset = GetEntSendPropOffs(entity, s_sProp);

	for(int i = 0; i < 4; i++)
		aColor[i] = GetEntData(entity, Offset + i, 1) & 0xFF;
}
