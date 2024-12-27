#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <zombiereloaded>
#include <zr_tools>

#include "TeamManager.inc"
#include "zr_grenade_effects.inc"

#pragma newdecls required

#define VOTE_NO "###no###"
#define VOTE_YES "###yes###"

enum
{
	Hit_Undefined = -1,
	Hit_NotAPlayer,
	Hit_Teammate,
	Hit_Enemy
}

ArrayList g_hLiveKnives = null;

ConVar g_cvarKnifeDamage = null;
ConVar g_cvarKnifeDamageHS = null;
ConVar g_cvarKnifeTrail = null;
ConVar g_cvarStartingKnivesMother = null;
ConVar g_cvarStartingKnives = null;
ConVar g_cvarMaxKnives = null;
ConVar g_cvarKnifeRegenTime = null;
ConVar g_cvarVotePercent = null;

Handle g_hNotifyTimer = null;
Handle g_hKnifeRegenerationTimer[MAXPLAYERS + 1] = { null, ... };

bool g_bLoadedLate = false;
bool g_bEnabled = false;
bool g_bInWarmup = false;
bool g_bTeamManagerLoaded = false;
bool g_bIgnoredFirstUpdate[MAXPLAYERS + 1] = { false, ... };

int g_iTimeUntilNextKnife[MAXPLAYERS + 1] = { -1, ... };
int g_iPlayerKnives[MAXPLAYERS + 1] = { 0, ... };
int g_iKnifeModelIdx = 0;
int g_iLastKnifeDeath = 0;

public Plugin myinfo =
{
	name = "Fun Mode",
	author = "Obus, idea by D()G@N",
	description = "",
	version = "1.1.2",
	url = ""
}

public APLRes AskPluginLoad2(Handle hThis, bool bLoadedLate, char[] error, int err_max)
{
	g_bLoadedLate = bLoadedLate;

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("basevotes.phrases");

	g_hLiveKnives = new ArrayList(2);

	g_cvarKnifeDamage = CreateConVar("sm_funmode_knifedamage", "10", "How much damage a knife hit shall deal");
	g_cvarKnifeDamageHS = CreateConVar("sm_funmode_knifedamagehs", "20", "How much damage a knife headshot shall deal");
	g_cvarKnifeTrail = CreateConVar("sm_funmode_knifetrail", "1", "Enables knife trails");
	g_cvarStartingKnivesMother = CreateConVar("sm_funmode_startingknivesmother", "3", "How many knives mother zm shall spawn with");
	g_cvarStartingKnives = CreateConVar("sm_funmode_startingknives", "0", "How many knives normal zm shall spawn with");
	g_cvarMaxKnives = CreateConVar("sm_funmode_maxknives", "5", "Maximum number of knives a zm can carry");
	g_cvarKnifeRegenTime = CreateConVar("sm_funmode_regentime", "45", "How long it takes to regenerate 1 knife");
	g_cvarVotePercent = CreateConVar("sm_funmode_votepercent", "0.6", "Percentage of votes requires to enable FunMode");

	AutoExecConfig(true, "plugin.FunMode");

	g_cvarMaxKnives.AddChangeHook(ConVarChanged_Max_Regen);
	g_cvarKnifeRegenTime.AddChangeHook(ConVarChanged_Max_Regen);

	HookEvent("player_death", EventHook_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", EventHook_PlayerSpawn, EventHookMode_Post);

	g_hNotifyTimer = CreateTimer(0.25, Timer_UpdateKnives, _, TIMER_REPEAT);

	AddNormalSoundHook(NormalSHook_SmokeImpact);
}

public void OnAllPluginsLoaded()
{
	g_bTeamManagerLoaded = LibraryExists("TeamManager");

	if (!g_bLoadedLate)
		return;

	if (!g_bTeamManagerLoaded || (g_bTeamManagerLoaded && !TeamManager_InWarmup()))
	{
		CreateTimer(1.0, Timer_OnWarmupEnd, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnLibraryAdded(const char[] sName)
{
	if (!strcmp(sName, "TeamManager", false))
		g_bTeamManagerLoaded = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if (!strcmp(sName, "TeamManager", false))
		g_bTeamManagerLoaded = false;
}

public void OnPluginEnd()
{
	if (g_hNotifyTimer != null)
		delete g_hNotifyTimer;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		OnClientDisconnect(i);
	}

	UnhookEvent("player_death", EventHook_PlayerDeath, EventHookMode_Pre);
	UnhookEvent("player_spawn", EventHook_PlayerSpawn, EventHookMode_Post);

	g_cvarMaxKnives.RemoveChangeHook(ConVarChanged_Max_Regen);
	g_cvarKnifeRegenTime.RemoveChangeHook(ConVarChanged_Max_Regen);
}

public Action ZR_OnGrenadeEffect(int client, int grenade)
{
	if (!g_bEnabled)
		return Plugin_Continue;

	if (!IsValidClient(client) || !IsValidEntity(grenade))
		return Plugin_Continue;

	if (g_hLiveKnives.FindValue(grenade) != -1)
		return Plugin_Stop;

	return Plugin_Continue;
}

public void OnMapStart()
{
	if (g_bTeamManagerLoaded)
		g_bInWarmup = true;

	g_iKnifeModelIdx = PrecacheModel("models/weapons/w_knife_t.mdl");

	for (int i = 0; i < MAXPLAYERS + 1; i++)
	{
		g_bIgnoredFirstUpdate[i] = false;
	}
}

public void OnMapEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_hKnifeRegenerationTimer[i] != null)
			delete g_hKnifeRegenerationTimer[i];
	}
}

public void OnClientPutInServer(int client)
{
	if (!g_bEnabled)
		return;

	if (g_hKnifeRegenerationTimer[client] != null)
		delete g_hKnifeRegenerationTimer[client];

	g_iPlayerKnives[client] = 0;
	g_bIgnoredFirstUpdate[client] = false;
}

public Action EventHook_PlayerSpawn(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled || g_bInWarmup)
		return;

	int serial = GetClientSerial(GetClientOfUserId(GetEventInt(hEvent, "userid")));
	CreateTimer(1.0, EventHook_PlayerSpawnPost, serial);
}

public Action EventHook_PlayerSpawnPost(Handle hTimer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != CS_TEAM_CT)
		return;

	int ent = GivePlayerItem(client, "weapon_smokegrenade");
	EquipPlayerWeapon(client, ent);
}

public void OnClientDisconnect(int client)
{
	if (g_hKnifeRegenerationTimer[client] != null)
		delete g_hKnifeRegenerationTimer[client];

	g_iPlayerKnives[client] = 0;
	g_bIgnoredFirstUpdate[client] = false;
}

public void OnEntityCreated(int entity, const char[] sClassName)
{
	if (!g_bEnabled)
		return;

	if (!strncmp(sClassName[7], "knife", 5))
		RequestFrame(RequestFrame_OnEntityCreated_Knife, entity);

	if (!strcmp(sClassName, "smokegrenade_projectile"))
		RequestFrame(RequestFrame_OnEntityCreated_SmokeProjectile, entity);
}

public void RequestFrame_OnEntityCreated_SmokeProjectile(int entity)
{
	if (!IsValidEntity(entity))
		return;

	if (g_hLiveKnives.FindValue(entity) == -1)
		return;

	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0, 4);
}

public void RequestFrame_OnEntityCreated_Knife(int entity)
{
	if (!IsValidEntity(entity))
		return;

	if (!HasEntProp(entity, Prop_Send, "m_hOwnerEntity"))
		return;

	int iOwner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

	if (!IsValidClient(iOwner))
		return;

	g_bIgnoredFirstUpdate[iOwner] = false;
}

public void OnEntityDestroyed(int entity)
{
	int idx = -1;

	if ((idx = g_hLiveKnives.FindValue(entity)) != -1)
		g_hLiveKnives.Erase(idx);
}

public void ZR_OnClientInfected(int client, int attacker, bool bMotherInfect, bool bRespawnOverride, bool bRespawn)
{
	if (!g_bEnabled)
		return;

	if (bMotherInfect)
	{
		int iCurHealth = GetClientHealth(client);

		SetEntProp(client, Prop_Send, "m_iHealth", iCurHealth * 2);

		g_iPlayerKnives[client] = g_cvarStartingKnivesMother.IntValue;
	}
	else
	{
		g_iPlayerKnives[client] = g_cvarStartingKnives.IntValue;
	}

	if (g_hKnifeRegenerationTimer[client] != null)
	{
		delete g_hKnifeRegenerationTimer[client];
		g_hKnifeRegenerationTimer[client] = null;
	}

	g_hKnifeRegenerationTimer[client] = CreateTimer(g_cvarKnifeRegenTime.FloatValue, Timer_RegenerateKnives, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	g_iTimeUntilNextKnife[client] = GetTime() + g_cvarKnifeRegenTime.IntValue;
}

public void TeamManager_WarmupEnd()
{
	g_bInWarmup = false;
	if (!g_bEnabled)
		CreateTimer(1.0, Timer_OnWarmupEnd, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	static float fLastSecondaryAttack[MAXPLAYERS + 1];

	if (!g_bEnabled)
		return Plugin_Continue;

	if (!(buttons & IN_ATTACK2) || !IsValidClient(client) || !ZR_IsClientZombie(client))
		return Plugin_Continue;

	int iKnife = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);

	if (iKnife <= 0)
		return Plugin_Continue;

	char sWeapon[32];
	GetClientWeapon(client, sWeapon, sizeof(sWeapon));

	if (strncmp(sWeapon[7], "knife", 5))
		return Plugin_Continue;

	float fNextSecondaryAttack = GetEntPropFloat(iKnife, Prop_Send, "m_flNextSecondaryAttack");

	if (fNextSecondaryAttack == fLastSecondaryAttack[client] || !g_bIgnoredFirstUpdate[client])
	{
		g_bIgnoredFirstUpdate[client] = true;
		return Plugin_Continue;
	}

	fLastSecondaryAttack[client] = fNextSecondaryAttack;

	DispatchKnife(client);

	return Plugin_Continue;
}

public Action EventHook_PlayerDeath(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return Plugin_Continue;

	int victim = GetClientOfUserId(hEvent.GetInt("userid"));
	char sWeapon[32];

	hEvent.GetString("weapon", sWeapon, sizeof(sWeapon));

	if (victim == g_iLastKnifeDeath)
	{
		g_iLastKnifeDeath = 0;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action Timer_OnWarmupEnd(Handle hThis)
{
	static int iTimePassed = 0;
	static bool bDelayed = false;

	if (iTimePassed++ >= 5)
	{
		if (IsVoteInProgress())
		{
			iTimePassed = 0;
			bDelayed = true;
			PrintCenterTextAll("FunMode vote delayed, retrying in %d", 5);
			return Plugin_Continue;
		}

		Menu hFunModeVote = new Menu(MenuHandler_FunModeVote);
		hFunModeVote.SetTitle("Enable Freezenades vs Throwing Knives?");
		hFunModeVote.AddItem(VOTE_YES, "Yes");
		hFunModeVote.AddItem(VOTE_NO, "No");
		hFunModeVote.OptionFlags = MENUFLAG_BUTTON_NOVOTE;
		hFunModeVote.ExitButton = false;

		hFunModeVote.DisplayVoteToAll(20);

		bDelayed = false;
		iTimePassed = 0;

		return Plugin_Stop;
	}

	if (!bDelayed)
		PrintCenterTextAll("FunMode vote in %d", 6 - iTimePassed);
	else
		PrintCenterTextAll("FunMode vote delayed, retrying in %d", 6 - iTimePassed);

	return Plugin_Continue;
}

public int MenuHandler_FunModeVote(Menu menu, MenuAction action, int param1, int param2) //i copypasted it again mom look
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_DisplayItem)
	{
		char display[64];
		menu.GetItem(param2, "", 0, _, display, sizeof(display));

	 	if (strcmp(display, VOTE_NO) == 0 || strcmp(display, VOTE_YES) == 0)
	 	{
			char buffer[255];
			Format(buffer, sizeof(buffer), "%T", display, param1);

			return RedrawMenuItem(buffer);
		}
	}
	else if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes)
	{
		PrintToChatAll("[SM] %t", "No Votes Cast");
	}
	else if (action == MenuAction_VoteEnd)
	{
		char item[64], display[64];
		float percent, limit;
		int votes, totalVotes;

		GetMenuVoteInfo(param2, votes, totalVotes);
		menu.GetItem(param1, item, sizeof(item), _, display, sizeof(display));

		if (strcmp(item, VOTE_NO) == 0)
		{
			votes = totalVotes - votes;
		}

		limit = g_cvarVotePercent.FloatValue;
		percent = float(votes) / float(totalVotes);

		if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent, limit) < 0) || strcmp(item, VOTE_NO) == 0)
		{
			PrintToChatAll("[SM] %t", "Vote Failed", RoundToNearest(100.0 * limit), RoundToNearest(100.0 * percent), totalVotes);
		}
		else
		{
			g_bEnabled = true;
			ServerCommand("exec funmodeload");

			PrintToChatAll("[SM] %t", "Vote Successful", RoundToNearest(100.0 * percent), totalVotes);
			PrintCenterTextAll("FunMode vote passed!");

			// Give all CTs smokegrenades
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i) || GetClientTeam(i) != CS_TEAM_CT)
					continue;

				int ent = GivePlayerItem(i, "weapon_smokegrenade");
				EquipPlayerWeapon(i, ent);
			}
		}
	}

	return 0;
}

public Action Timer_UpdateKnives(Handle hThis)
{
	if (!g_bEnabled)
		return Plugin_Continue;

	if (IsVoteInProgress())
		return Plugin_Continue;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || IsFakeClient(i))
			continue;

		if (!ZR_IsClientZombie(i))
			continue;

		if (g_hKnifeRegenerationTimer[i] != null)
			PrintHintText(i, "Throwing knives: %d/%d [%d]", g_iPlayerKnives[i], g_cvarMaxKnives.IntValue, g_iTimeUntilNextKnife[i] - GetTime());
		else
			PrintHintText(i, "Throwing knives: %d/%d", g_iPlayerKnives[i], g_cvarMaxKnives.IntValue);

		StopSound(i, SNDCHAN_STATIC, "UI/hint.wav");
	}

	return Plugin_Continue;
}

public Action NormalSHook_SmokeImpact(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (!g_bEnabled)
		return Plugin_Continue;

	int idx = -1;

	if ((idx = g_hLiveKnives.FindValue(entity)) != -1 && !strncmp(sample, "weapons/smokegrenade/grenade_hit", 32))
	{
		int iHitType = g_hLiveKnives.Get(idx, 1, false);

		switch (iHitType)
		{
			case Hit_Undefined, Hit_Teammate:
			{
				return Plugin_Handled;
			}

			case Hit_NotAPlayer:
			{
				return Plugin_Continue;
			}

			case Hit_Enemy:
			{
				EmitSoundToAll("physics/flesh/flesh_impact_bullet4.wav", entity, channel, level, flags, volume, pitch);
				return Plugin_Handled;
			}

			default:
			{
				return Plugin_Continue; //monkaS
			}
		}
	}

	return Plugin_Continue;
}

void DispatchKnife(int iOwner)
{
	if (g_iPlayerKnives[iOwner] <= 0)
		return;

	int iKnife = CreateEntityByName("smokegrenade_projectile");

	if (iKnife <= 0 || !DispatchSpawn(iKnife))
		return;

	SetEntPropEnt(iKnife, Prop_Send, "m_hOwnerEntity", iOwner);
	SetEntPropEnt(iKnife, Prop_Send, "m_hThrower", iOwner);
	SetEntProp(iKnife, Prop_Send, "m_iTeamNum", GetClientTeam(iOwner));
	SetEntProp(iKnife, Prop_Send, "m_nModelIndex", g_iKnifeModelIdx);
	SetEntPropFloat(iKnife, Prop_Send, "m_flModelScale", 1.0);
	SetEntPropFloat(iKnife, Prop_Send, "m_flElasticity", 0.2);
	SetEntPropFloat(iKnife, Prop_Data, "m_flGravity", 1.0);

	float vecOrigin[3];
	float vecAngles[3];
	float vecVelocity[3];
	float vecOwnerVelocity[3];
	float vecKnifeSpin[3] = { 2000.0, 0.0, 0.0 };

	GetClientEyePosition(iOwner, vecOrigin);
	GetClientEyeAngles(iOwner, vecAngles);
	GetAngleVectors(vecAngles, vecVelocity, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(vecVelocity, 2000.0);
	GetEntPropVector(iOwner, Prop_Data, "m_vecVelocity", vecOwnerVelocity);
	AddVectors(vecVelocity, vecOwnerVelocity, vecVelocity);
	SetEntPropVector(iKnife, Prop_Data, "m_vecAngVelocity", vecKnifeSpin);

	SetEntProp(iKnife, Prop_Data, "m_nNextThinkTick", -1);
	DispatchKeyValue(iKnife, "OnUser1", "!self,Kill,,10.0,-1");
	AcceptEntityInput(iKnife, "FireUser1");

	if (g_cvarKnifeTrail.BoolValue)
	{
		int iColor[4] = { 255, ... };
		TE_SetupBeamFollow(iKnife, PrecacheModel("sprites/bluelaser1.vmt"),	0, 0.5, 8.0, 1.0, 0, iColor);
		TE_SendToAll();
	}

	TeleportEntity(iKnife, vecOrigin, vecAngles, vecVelocity);
	SDKHook(iKnife, SDKHook_Touch, SDKHookCB_OnKnifeStartTouch);

	g_iPlayerKnives[iOwner]--;

	//PrintToServer("[DispatchKnife] %N threw knife %d | %d remaining", iOwner, iKnife, g_iPlayerKnives[iOwner]);
	g_hLiveKnives.Set(g_hLiveKnives.Push(iKnife), Hit_Undefined, 1, false);

	if (g_hKnifeRegenerationTimer[iOwner] == null)
	{
		g_hKnifeRegenerationTimer[iOwner] = CreateTimer(g_cvarKnifeRegenTime.FloatValue, Timer_RegenerateKnives, iOwner, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		g_iTimeUntilNextKnife[iOwner] = GetTime() + g_cvarKnifeRegenTime.IntValue;
	}
}

public Action SDKHookCB_OnKnifeStartTouch(int iKnife, int iHitEntity)
{
	if (IsValidClient(iHitEntity))
	{
		int iAttacker = GetEntPropEnt(iKnife, Prop_Send, "m_hThrower");

		if (!IsValidClient(iAttacker))
		{
			AcceptEntityInput(iKnife, "Kill");
			return Plugin_Continue;
		}

		if (iHitEntity == iAttacker)
			return Plugin_Continue;

		if (GetClientTeam(iAttacker) == GetClientTeam(iHitEntity))
		{
			int idx = -1;

			if ((idx = g_hLiveKnives.FindValue(iKnife)) != -1)
				g_hLiveKnives.Set(idx, Hit_Teammate, 1, false);

			SetEntProp(iKnife, Prop_Send, "m_CollisionGroup", 2, 4);
			CreateTimer(0.050, Timer_KillKnife, iKnife, TIMER_FLAG_NO_MAPCHANGE);
			return Plugin_Continue;
		}

		int idx = -1;

		if ((idx = g_hLiveKnives.FindValue(iKnife)) != -1)
			g_hLiveKnives.Set(idx, Hit_Enemy, 1, false);

		int iDamageToDeal = g_cvarKnifeDamage.IntValue;
		float vecVictimEyePos[3];
		float vecKnifeOrigin[3];
		float vecAttackerOrigin[3];

		GetClientEyePosition(iHitEntity, vecVictimEyePos);
		GetEntPropVector(iKnife, Prop_Send, "m_vecOrigin", vecKnifeOrigin);
		GetClientAbsOrigin(iAttacker, vecAttackerOrigin);

		Handle hDamageMsg = StartMessageOne("Damage", iHitEntity, USERMSG_RELIABLE);
		BfWriteByte(hDamageMsg, iDamageToDeal);
		BfWriteVecCoord(hDamageMsg, vecAttackerOrigin);
		EndMessage();

		float fDistToEyePos = GetVectorDistance(vecKnifeOrigin, vecVictimEyePos);
		bool bHeadShot = fDistToEyePos <= 22.5; //close enough :^)
		iDamageToDeal = bHeadShot ? g_cvarKnifeDamageHS.IntValue : iDamageToDeal;

		int iVictimHealth = GetClientHealth(iHitEntity);

		if (iVictimHealth - iDamageToDeal <= 0)
		{
			g_iLastKnifeDeath = iHitEntity;

			ForcePlayerSuicide(iHitEntity);

			Event hPlayerDeathEvent = CreateEvent("player_death");
			hPlayerDeathEvent.SetInt("userid", GetClientUserId(iHitEntity));
			hPlayerDeathEvent.SetInt("attacker", GetClientUserId(iAttacker));
			hPlayerDeathEvent.SetString("weapon", "throwing_knife");
			hPlayerDeathEvent.SetBool("headshot", bHeadShot);
			hPlayerDeathEvent.Fire();
		}
		else
		{
			SetEntProp(iHitEntity, Prop_Send, "m_iHealth", iVictimHealth - iDamageToDeal);

			Event hPlayerHurtEvent = CreateEvent("player_hurt");
			hPlayerHurtEvent.SetInt("userid", GetClientUserId(iHitEntity));
			hPlayerHurtEvent.SetInt("attacker", GetClientUserId(iAttacker));
			hPlayerHurtEvent.SetInt("health", iVictimHealth - iDamageToDeal);
			hPlayerHurtEvent.SetInt("armor", GetClientArmor(iHitEntity));
			hPlayerHurtEvent.SetString("weapon", "throwing_knife");
			hPlayerHurtEvent.SetInt("dmg_health", iDamageToDeal);
			hPlayerHurtEvent.SetInt("dmg_armor", 0);
			hPlayerHurtEvent.SetInt("hitgroup", bHeadShot?1:2);
			hPlayerHurtEvent.Fire();
		}

		SetEntPropFloat(iHitEntity, Prop_Send, "m_flStamina", 1000.0); // ¯\_(?)_/¯

		SetEntProp(iKnife, Prop_Send, "m_CollisionGroup", 2, 4);
		CreateTimer(0.050, Timer_KillKnife, iKnife, TIMER_FLAG_NO_MAPCHANGE);

		return Plugin_Continue;
	}

	char sClsName[64];

	GetEntityClassname(iHitEntity, sClsName, sizeof(sClsName));

	if (!strncmp(sClsName, "trigger_", 8) || !strncmp(sClsName, "func_", 5))
		return Plugin_Continue;

	int idx = -1;

	if ((idx = g_hLiveKnives.FindValue(iKnife)) != -1)
		g_hLiveKnives.Set(idx, Hit_NotAPlayer, 1, false);

	SetEntProp(iKnife, Prop_Send, "m_CollisionGroup", 2, 4);
	CreateTimer(0.050, Timer_KillKnife, iKnife, TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Continue;
}

public Action Timer_KillKnife(Handle hTimer, int iKnife)
{
	if (!IsValidEntity(iKnife))
		return Plugin_Handled;

	AcceptEntityInput(iKnife, "Kill");

	return Plugin_Handled;
}

public Action Timer_RegenerateKnives(Handle hTimer, int iOwner)
{
	if (!g_bEnabled)
		return Plugin_Continue;

	g_iPlayerKnives[iOwner]++;

	if (g_iPlayerKnives[iOwner] >= g_cvarMaxKnives.IntValue)
	{
		g_hKnifeRegenerationTimer[iOwner] = null;
		return Plugin_Stop;
	}

	g_iTimeUntilNextKnife[iOwner] = GetTime() + g_cvarKnifeRegenTime.IntValue;

	return Plugin_Continue;
}

public void ConVarChanged_Max_Regen(ConVar cvar, const char[] sOldVal, const char[] sNewVal)
{
	if (!g_bEnabled)
		return;

	if (cvar == g_cvarMaxKnives)
	{
		int iNewVal = StringToInt(sNewVal);

		for (int i = 0; i <= MaxClients; i++)
		{
			if (g_iPlayerKnives[i] <= iNewVal)
				continue;

			g_iPlayerKnives[i] = iNewVal;
		}
	}
	else
	{
		float fNewVal = StringToFloat(sNewVal);

		for (int i = 0; i <= MaxClients; i++)
		{
			if (g_hKnifeRegenerationTimer[i] == null)
				continue;

			delete g_hKnifeRegenerationTimer[i];
			g_hKnifeRegenerationTimer[i] = CreateTimer(fNewVal, Timer_RegenerateKnives, i, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			g_iTimeUntilNextKnife[i] = GetTime() + g_cvarKnifeRegenTime.IntValue;
		}
	}
}

stock bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client));
}
