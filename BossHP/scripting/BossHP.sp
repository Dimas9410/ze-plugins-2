#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <outputinfo>

#include <basic>
#include "CConfig.inc"
#include "CBoss.inc"

bool g_bLate = true;

ArrayList g_aConfig;
ArrayList g_aBoss;
StringMap g_aHadOnce;

char g_sHUDText[256];

public Plugin myinfo =
{
	name 			= "BossHP",
	author 			= "BotoX",
	description 	= "",
	version 		= "0.2",
	url 			= ""
};

public void OnPluginStart()
{
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEntityOutput("env_entity_maker", "OnEntitySpawned", OnEnvEntityMakerEntitySpawned);
}

public void OnPluginEnd()
{
	Cleanup();
}

void Cleanup()
{
	if(g_aConfig)
	{
		for(int i = 0; i < g_aConfig.Length; i++)
		{
			CConfig Config = g_aConfig.Get(i);
			delete Config;
		}
		delete g_aConfig;
	}

	if(g_aBoss)
	{
		for(int i = 0; i < g_aBoss.Length; i++)
		{
			CBoss Boss = g_aBoss.Get(i);
			delete Boss;
		}
		delete g_aBoss;
	}
}

public void OnMapEnd()
{
	Cleanup();
}

public void OnMapStart()
{
	bool bLate = g_bLate;
	g_bLate = false;

	char sMapName[PLATFORM_MAX_PATH];
	GetCurrentMap(sMapName, sizeof(sMapName));

	char sConfigFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), "configs/bosshp/%s.cfg", sMapName);
	if(!FileExists(sConfigFile))
	{
		LogMessage("Could not find mapconfig: \"%s\"", sConfigFile);
		return;
	}
	LogMessage("Found mapconfig: \"%s\"", sConfigFile);

	KeyValues KvConfig = new KeyValues("bosses");
	if(!KvConfig.ImportFromFile(sConfigFile))
	{
		delete KvConfig;
		LogError("ImportFromFile() failed!");
		return;
	}
	KvConfig.Rewind();

	if(!KvConfig.GotoFirstSubKey())
	{
		delete KvConfig;
		LogError("GotoFirstSubKey() failed!");
		return;
	}

	g_aConfig = new ArrayList();

	do
	{
		char sSection[64];
		KvConfig.GetSectionName(sSection, sizeof(sSection));

		char sName[64];
		KvConfig.GetString("name", sName, sizeof(sName));
		if(!sName[0])
		{
			LogError("Could not find \"name\" in \"%s\"", sSection);
			continue;
		}

		char sMethod[64];
		KvConfig.GetString("method", sMethod, sizeof(sMethod));
		if(!sMethod[0])
		{
			LogError("Could not find \"method\" in \"%s\"", sSection);
			continue;
		}

		char sTrigger[64 * 2];
		KvConfig.GetString("trigger", sTrigger, sizeof(sTrigger));
		if(!sTrigger[0])
		{
			LogError("Could not find \"trigger\" in \"%s\"", sSection);
			continue;
		}

		int iTriggerDelim;
		if((iTriggerDelim = FindCharInString(sTrigger, ':')) == -1)
		{
			LogError("Delimiter ':' not found in \"trigger\"(%s) in \"%s\"", sTrigger, sSection);
			continue;
		}
		sTrigger[iTriggerDelim] = 0;

		float fTriggerDelay = 0.0;
		int iTriggerDelayDelim;
		if((iTriggerDelayDelim = FindCharInString(sTrigger[iTriggerDelim + 1], ':')) != -1)
		{
			iTriggerDelayDelim += iTriggerDelim + 1;
			fTriggerDelay = StringToFloat(sTrigger[iTriggerDelayDelim + 1]);
			sTrigger[iTriggerDelayDelim] = 0;
		}

		char sShowTrigger[64 * 2];
		int iShowTriggerDelim;
		float fShowTriggerDelay = 0.0;
		int iShowTriggerDelayDelim;
		KvConfig.GetString("showtrigger", sShowTrigger, sizeof(sShowTrigger));
		if(sShowTrigger[0])
		{
			if((iShowTriggerDelim = FindCharInString(sShowTrigger, ':')) == -1)
			{
				LogError("Delimiter ':' not found in \"showtrigger\"(%s) in \"%s\"", sShowTrigger, sSection);
				continue;
			}
			sShowTrigger[iShowTriggerDelim] = 0;

			if((iShowTriggerDelayDelim = FindCharInString(sShowTrigger[iShowTriggerDelim + 1], ':')) != -1)
			{
				iShowTriggerDelayDelim += iShowTriggerDelim + 1;
				fShowTriggerDelay = StringToFloat(sShowTrigger[iShowTriggerDelayDelim + 1]);
				sShowTrigger[iShowTriggerDelayDelim] = 0;
			}
		}

		char sKillTrigger[64 * 2];
		int iKillTriggerDelim;
		float fKillTriggerDelay = 0.0;
		int iKillTriggerDelayDelim;
		KvConfig.GetString("killtrigger", sKillTrigger, sizeof(sKillTrigger));
		if(sKillTrigger[0])
		{
			if((iKillTriggerDelim = FindCharInString(sKillTrigger, ':')) == -1)
			{
				LogError("Delimiter ':' not found in \"killtrigger\"(%s) in \"%s\"", sKillTrigger, sSection);
				continue;
			}
			sKillTrigger[iKillTriggerDelim] = 0;

			if((iKillTriggerDelayDelim = FindCharInString(sKillTrigger[iKillTriggerDelim + 1], ':')) != -1)
			{
				iKillTriggerDelayDelim += iKillTriggerDelim + 1;
				fKillTriggerDelay = StringToFloat(sKillTrigger[iKillTriggerDelayDelim + 1]);
				sKillTrigger[iKillTriggerDelayDelim] = 0;
			}
		}

		bool bMultiTrigger = view_as<bool>(KvConfig.GetNum("multitrigger", 0));
		bool bNameFixup = view_as<bool>(KvConfig.GetNum("namefixup", 0));
		int iTimeout = KvConfig.GetNum("timeout", -1);

		CConfig Config = view_as<CConfig>(INVALID_HANDLE);

		if(StrEqual(sMethod, "breakable"))
		{
			char sBreakable[64];
			if(!KvConfig.GetString("breakable", sBreakable, sizeof(sBreakable)))
			{
				LogError("Could not find \"breakable\" in \"%s\"", sSection);
				continue;
			}

			CConfigBreakable BreakableConfig = new CConfigBreakable();

			BreakableConfig.SetBreakable(sBreakable);

			Config = view_as<CConfig>(BreakableConfig);
		}
		else if(StrEqual(sMethod, "counter"))
		{
			char sCounter[64];
			if(!KvConfig.GetString("counter", sCounter, sizeof(sCounter)))
			{
				LogError("Could not find \"counter\" in \"%s\"", sSection);
				continue;
			}

			CConfigCounter CounterConfig = new CConfigCounter();

			CounterConfig.SetCounter(sCounter);

			Config = view_as<CConfig>(CounterConfig);
		}
		else if(StrEqual(sMethod, "hpbar"))
		{
			char sIterator[64];
			if(!KvConfig.GetString("iterator", sIterator, sizeof(sIterator)))
			{
				LogError("Could not find \"iterator\" in \"%s\"", sSection);
				continue;
			}

			char sCounter[64];
			if(!KvConfig.GetString("counter", sCounter, sizeof(sCounter)))
			{
				LogError("Could not find \"counter\" in \"%s\"", sSection);
				continue;
			}

			char sBackup[64];
			if(!KvConfig.GetString("backup", sBackup, sizeof(sBackup)))
			{
				LogError("Could not find \"backup\" in \"%s\"", sSection);
				continue;
			}

			CConfigHPBar HPBarConfig = new CConfigHPBar();

			HPBarConfig.SetIterator(sIterator);
			HPBarConfig.SetCounter(sCounter);
			HPBarConfig.SetBackup(sBackup);

			Config = view_as<CConfig>(HPBarConfig);
		}

		if(Config == INVALID_HANDLE)
		{
			LogError("Invalid \"method\"(%s) in \"%s\"", sMethod, sSection);
			continue;
		}

		Config.SetName(sName);
		Config.bMultiTrigger = bMultiTrigger;
		Config.bNameFixup = bNameFixup;
		Config.iTimeout = iTimeout;

		Config.SetTrigger(sTrigger);
		Config.SetOutput(sTrigger[iTriggerDelim + 1]);
		Config.fTriggerDelay = fTriggerDelay;

		if(sShowTrigger[0])
		{
			Config.SetShowTrigger(sShowTrigger);
			Config.SetShowOutput(sShowTrigger[iShowTriggerDelim + 1]);
			Config.fShowTriggerDelay = fShowTriggerDelay;
		}

		if(sKillTrigger[0])
		{
			Config.SetKillTrigger(sKillTrigger);
			Config.SetKillOutput(sKillTrigger[iKillTriggerDelim + 1]);
			Config.fKillTriggerDelay = fKillTriggerDelay;
		}

		g_aConfig.Push(Config);
	} while(KvConfig.GotoNextKey(false));

	delete KvConfig;

	if(!g_aConfig.Length)
	{
		delete g_aConfig;
		LogError("Empty mapconfig: \"%s\"", sConfigFile);
		return;
	}

	g_aBoss = new ArrayList();
	g_aHadOnce = new StringMap();

	/* Late Load */
	if(bLate)
	{
		int entity = INVALID_ENT_REFERENCE;
		while((entity = FindEntityByClassname(entity, "*")) != INVALID_ENT_REFERENCE)
		{
			OnEntitySpawned(entity);
		}
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_aConfig)
		return;

	if(g_aBoss)
	{
		for(int i = 0; i < g_aBoss.Length; i++)
		{
			CBoss Boss = g_aBoss.Get(i);
			delete Boss;
		}
		delete g_aBoss;
	}

	g_aBoss = new ArrayList();

	if(g_aHadOnce)
		delete g_aHadOnce;

	g_aHadOnce = new StringMap();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(!g_aConfig)
		return;

	SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawned);
}

public void OnEntitySpawned(int entity)
{
	if(!g_aConfig)
		return;

	char sTargetname[64];
	GetEntPropString(entity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

	int iHammerID = GetEntProp(entity, Prop_Data, "m_iHammerID");

	for(int i = 0; i < g_aConfig.Length; i++)
	{
		CConfig Config = g_aConfig.Get(i);

		char sTrigger[64];
		Config.GetTrigger(sTrigger, sizeof(sTrigger));

		int iTriggerHammerID = -1;
		if(sTrigger[0] == '#')
			iTriggerHammerID = StringToInt(sTrigger[1]);

		if((iTriggerHammerID == -1 && sTargetname[0] && StrEqual(sTargetname, sTrigger)) || iTriggerHammerID == iHammerID)
		{
			char sOutput[64];
			Config.GetOutput(sOutput, sizeof(sOutput));

			if(StrEqual(sOutput, "OnTakeDamage"))
			{
				SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
			}
			else
			{
				bool Once = !Config.bMultiTrigger;
				HookSingleEntityOutput(entity, sOutput, OnEntityOutput, Once);
			}

			LogMessage("Hooked trigger %s:%s", sTrigger, sOutput);
		}

		char sShowTrigger[64];
		Config.GetShowTrigger(sShowTrigger, sizeof(sShowTrigger));

		int iShowTriggerHammerID = -1;
		if(sShowTrigger[0] == '#')
			iShowTriggerHammerID = StringToInt(sShowTrigger[1]);

		if((iShowTriggerHammerID == -1 && sShowTrigger[0] && StrEqual(sTargetname, sShowTrigger)) || iShowTriggerHammerID == iHammerID)
		{
			char sShowOutput[64];
			Config.GetShowOutput(sShowOutput, sizeof(sShowOutput));

			if(StrEqual(sShowOutput, "OnTakeDamage"))
			{
				SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePostShow);
			}
			else
			{
				bool Once = !Config.bMultiTrigger;
				HookSingleEntityOutput(entity, sShowOutput, OnEntityOutputShow, Once);
			}

			LogMessage("Hooked showtrigger %s:%s", sShowTrigger, sShowOutput);
		}

		char sKillTrigger[64];
		Config.GetKillTrigger(sKillTrigger, sizeof(sKillTrigger));

		int iKillTriggerHammerID = -1;
		if(sKillTrigger[0] == '#')
			iKillTriggerHammerID = StringToInt(sKillTrigger[1]);

		if((iKillTriggerHammerID == -1 && sKillTrigger[0] && StrEqual(sTargetname, sKillTrigger)) || iKillTriggerHammerID == iHammerID)
		{
			char sKillOutput[64];
			Config.GetKillOutput(sKillOutput, sizeof(sKillOutput));

			if(StrEqual(sKillOutput, "OnTakeDamage"))
			{
				SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePostKill);
			}
			else
			{
				bool Once = !Config.bMultiTrigger;
				HookSingleEntityOutput(entity, sKillOutput, OnEntityOutputKill, Once);
			}

			LogMessage("Hooked killtrigger %s:%s", sKillTrigger, sKillOutput);
		}
	}
}

void OnTrigger(int entity, const char[] output, SDKHookType HookType = view_as<SDKHookType>(-1))
{
	char sTargetname[64];
	GetEntPropString(entity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

	int iHammerID = GetEntProp(entity, Prop_Data, "m_iHammerID");

	PrintToServer("OnTrigger(%d:\"%s\":#%d, \"%s\")", entity, sTargetname, iHammerID, output);

	for(int i = 0; i < g_aConfig.Length; i++)
	{
		CConfig Config = g_aConfig.Get(i);

		char sTrigger[64];
		Config.GetTrigger(sTrigger, sizeof(sTrigger));

		int iTriggerHammerID = -1;
		if(sTrigger[0] == '#')
		{
			iTriggerHammerID = StringToInt(sTrigger[1]);

			if(iTriggerHammerID != iHammerID)
				continue;
		}
		else if(!sTargetname[0] || !StrEqual(sTargetname, sTrigger))
			continue;

		char sOutput[64];
		Config.GetOutput(sOutput, sizeof(sOutput));

		if(!StrEqual(output, sOutput))
			continue;

		bool Once = !Config.bMultiTrigger;
		char sTemp[8];

		if(Once)
		{
			IntToString(i, sTemp, sizeof(sTemp));
			bool bHadOnce = false;
			if(g_aHadOnce.GetValue(sTemp, bHadOnce) && bHadOnce)
				continue;
		}

		if(HookType != view_as<SDKHookType>(-1) && Once)
		{
			if(HookType == SDKHook_OnTakeDamagePost)
				SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
		}

		CBoss Boss = view_as<CBoss>(INVALID_HANDLE);

		if(Config.IsBreakable)
			Boss = new CBossBreakable();
		else if(Config.IsCounter)
			Boss = new CBossCounter();
		else if(Config.IsHPBar)
			Boss = new CBossHPBar();

		if(Boss != INVALID_HANDLE)
		{
			Boss.dConfig = Config;
			Boss.bActive = false;

			float fTriggerDelay = Config.fTriggerDelay;
			if(fTriggerDelay > 0)
				Boss.fWaitUntil = GetGameTime() + fTriggerDelay;

			char sShowTrigger[8];
			Config.GetShowTrigger(sShowTrigger, sizeof(sShowTrigger));
			if(sShowTrigger[0])
				Boss.bShow = false;

			g_aBoss.Push(Boss);

			if(Once)
				g_aHadOnce.SetValue(sTemp, true);

			if(iTriggerHammerID == -1)
				LogMessage("Triggered boss %s(%d) from output %s", sTargetname, entity, output);
			else
				LogMessage("Triggered boss #%d(%d) from output %s", iTriggerHammerID, entity, output);
		}
	}
}

void OnShowTrigger(int entity, const char[] output, SDKHookType HookType = view_as<SDKHookType>(-1))
{
	char sTargetname[64];
	GetEntPropString(entity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

	int iHammerID = GetEntProp(entity, Prop_Data, "m_iHammerID");

	int iTemplateNum = -1;
	int iTemplateLoc = FindCharInString(sTargetname, '&', true);
	if(iTemplateLoc != -1)
	{
		iTemplateNum = StringToInt(sTargetname[iTemplateLoc + 1]);
		sTargetname[iTemplateLoc] = 0;
	}

	for(int i = 0; i < g_aConfig.Length; i++)
	{
		CConfig Config = g_aConfig.Get(i);

		char sShowTrigger[64];
		Config.GetShowTrigger(sShowTrigger, sizeof(sShowTrigger));

		if(!sShowTrigger[0])
			continue;

		int iShowTriggerHammerID = -1;
		if(sShowTrigger[0] == '#')
		{
			iShowTriggerHammerID = StringToInt(sShowTrigger[1]);

			if(iShowTriggerHammerID != iHammerID)
				continue;
		}
		else if(!sTargetname[0] || !StrEqual(sTargetname, sShowTrigger))
			continue;

		char sShowOutput[64];
		Config.GetShowOutput(sShowOutput, sizeof(sShowOutput));

		if(!StrEqual(output, sShowOutput))
			continue;

		if(iShowTriggerHammerID == -1)
			LogMessage("Triggered show boss %s(%d) from output %s", sTargetname, entity, output);
		else
			LogMessage("Triggered show boss #%d(%d) from output %s", iShowTriggerHammerID, entity, output);

		if(HookType != view_as<SDKHookType>(-1) && !Config.bMultiTrigger)
		{
			if(HookType == SDKHook_OnTakeDamagePost)
				SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
		}

		float fShowTriggerDelay = Config.fShowTriggerDelay;

		for(int j = 0; j < g_aBoss.Length; j++)
		{
			CBoss Boss = g_aBoss.Get(j);

			if(Boss.dConfig != Config)
				continue;

			if(Boss.iTemplateNum != iTemplateNum)
				continue;

			if(fShowTriggerDelay > 0)
			{
				Boss.fShowAt = GetGameTime() + fShowTriggerDelay;
				LogMessage("Scheduled show(%f) boss %d", fShowTriggerDelay, j);
			}
			else
			{
				Boss.bShow = true;
				LogMessage("Showing boss %d", j);
			}
		}
	}
}

void OnKillTrigger(int entity, const char[] output, SDKHookType HookType = view_as<SDKHookType>(-1))
{
	char sTargetname[64];
	GetEntPropString(entity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

	int iHammerID = GetEntProp(entity, Prop_Data, "m_iHammerID");

	int iTemplateNum = -1;
	int iTemplateLoc = FindCharInString(sTargetname, '&', true);
	if(iTemplateLoc != -1)
	{
		iTemplateNum = StringToInt(sTargetname[iTemplateLoc + 1]);
		sTargetname[iTemplateLoc] = 0;
	}

	for(int i = 0; i < g_aConfig.Length; i++)
	{
		CConfig Config = g_aConfig.Get(i);

		char sKillTrigger[64];
		Config.GetKillTrigger(sKillTrigger, sizeof(sKillTrigger));

		if(!sKillTrigger[0])
			continue;

		int iKillTriggerHammerID = -1;
		if(sKillTrigger[0] == '#')
		{
			iKillTriggerHammerID = StringToInt(sKillTrigger[1]);

			if(iKillTriggerHammerID != iHammerID)
				continue;
		}
		else if(!sTargetname[0] || !StrEqual(sTargetname, sKillTrigger))
			continue;

		char sKillOutput[64];
		Config.GetKillOutput(sKillOutput, sizeof(sKillOutput));

		if(!StrEqual(output, sKillOutput))
			continue;

		if(iKillTriggerHammerID == -1)
			LogMessage("Triggered kill boss %s(%d) from output %s", sTargetname, entity, output);
		else
			LogMessage("Triggered kill boss #%d(%d) from output %s", iKillTriggerHammerID, entity, output);

		if(HookType != view_as<SDKHookType>(-1) && !Config.bMultiTrigger)
		{
			if(HookType == SDKHook_OnTakeDamagePost)
				SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
		}

		float fKillTriggerDelay = Config.fKillTriggerDelay;

		for(int j = 0; j < g_aBoss.Length; j++)
		{
			CBoss Boss = g_aBoss.Get(j);

			if(Boss.dConfig != Config)
				continue;

			if(Boss.iTemplateNum != iTemplateNum)
				continue;

			if(fKillTriggerDelay > 0)
			{
				Boss.fKillAt = GetGameTime() + fKillTriggerDelay;
				LogMessage("Scheduled kill(%f) boss %d", fKillTriggerDelay, j);
			}
			else
			{
				delete Boss;
				g_aBoss.Erase(j);
				j--;
				LogMessage("Killed boss %d", j + 1);
			}
		}
	}
}

public void OnEnvEntityMakerEntitySpawned(const char[] output, int caller, int activator, float delay)
{
	if(!g_aConfig)
		return;

	char sClassname[64];
	if(!GetEntityClassname(caller, sClassname, sizeof(sClassname)))
		return;

	if(!StrEqual(sClassname, "env_entity_maker"))
	{
		LogError("[SOURCEMOD BUG] output: \"%s\", caller: %d, activator: %d, delay: %f, classname: \"%s\"",
			output, caller, activator, delay, sClassname);
		return;
	}

	char sPointTemplate[64];
	if(GetEntPropString(caller, Prop_Data, "m_iszTemplate", sPointTemplate, sizeof(sPointTemplate)) <= 0)
		return;

	int iPointTemplate = FindEntityByTargetname(INVALID_ENT_REFERENCE, sPointTemplate, "point_template");
	if(iPointTemplate == INVALID_ENT_REFERENCE)
		return;

	OnEntityOutput("OnEntitySpawned", iPointTemplate, caller, delay);
}

public void OnEntityOutput(const char[] output, int caller, int activator, float delay)
{
	OnTrigger(caller, output);
}

public void OnEntityOutputShow(const char[] output, int caller, int activator, float delay)
{
	OnShowTrigger(caller, output);
}

public void OnEntityOutputKill(const char[] output, int caller, int activator, float delay)
{
	OnKillTrigger(caller, output);
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	OnTrigger(victim, "OnTakeDamage", SDKHook_OnTakeDamagePost);
}

public void OnTakeDamagePostShow(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	OnShowTrigger(victim, "OnTakeDamage", SDKHook_OnTakeDamagePost);
}

public void OnTakeDamagePostKill(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	OnKillTrigger(victim, "OnTakeDamage", SDKHook_OnTakeDamagePost);
}

public void OnGameFrame()
{
	if(!g_aBoss)
		return;

	static bool s_bLastHudPrinted = false;
	g_sHUDText[0] = 0;

	for(int i = 0; i < g_aBoss.Length; i++)
	{
		CBoss Boss = g_aBoss.Get(i);

		if(Boss.fKillAt && Boss.fKillAt < GetGameTime())
		{ // Delete Boss
			LogMessage("Deleting boss %d (KillAt)", i);
			delete Boss;
			g_aBoss.Erase(i);
			i--;
			continue;
		}

		if(!Boss.bActive)
		{
			if(Boss.fWaitUntil)
			{
				if(Boss.fWaitUntil > GetGameTime())
					continue;
				Boss.fWaitUntil = 0.0;
			}

			if(!BossInit(Boss))
				continue;
		}

		if(!BossProcess(Boss))
		{ // Delete Boss
			LogMessage("Deleting boss %d (dead)", i);
			delete Boss;
			g_aBoss.Erase(i);
			i--;
		}
	}

	if(!IsVoteInProgress())
	{
		if(g_sHUDText[0])
		{
			for(int client = 1; client <= MaxClients; client++)
			{
				if(IsClientInGame(client))
				{
					PrintHintText(client, g_sHUDText);
					StopSound(client, SNDCHAN_STATIC, "UI/hint.wav");
				}
			}
			s_bLastHudPrinted = true;
		}
		else if(s_bLastHudPrinted)
		{
			for(int client = 1; client <= MaxClients; client++)
			{
				if(IsClientInGame(client))
				{
					PrintHintText(client, "");
					StopSound(client, SNDCHAN_STATIC, "UI/hint.wav");
				}
			}
			s_bLastHudPrinted = false;
		}
	}
}

bool BossInit(CBoss _Boss)
{
	CConfig _Config = _Boss.dConfig;
	bool bNameFixup = _Config.bNameFixup;
	int iTemplateNum = -1;

	if(_Boss.IsBreakable)
	{
		CBossBreakable Boss = view_as<CBossBreakable>(_Boss);
		CConfigBreakable Config = view_as<CConfigBreakable>(_Config);

		char sBreakable[64];
		Config.GetBreakable(sBreakable, sizeof(sBreakable));

		int iBreakableEnt = INVALID_ENT_REFERENCE;

		if(!bNameFixup)
		{
			iBreakableEnt = FindEntityByTargetname(iBreakableEnt, sBreakable, "*");
			if(iBreakableEnt == INVALID_ENT_REFERENCE)
				return false;
		}
		else
		{
			StrCat(sBreakable, sizeof(sBreakable), "&*");
			while((iBreakableEnt = FindEntityByTargetname(iBreakableEnt, sBreakable, "*")) != INVALID_ENT_REFERENCE)
			{
				bool bSkip = false;
				for(int i = 0; i < g_aBoss.Length; i++)
				{
					CBoss _tBoss = g_aBoss.Get(i);
					if(!_tBoss.IsBreakable)
						continue;

					CBossBreakable tBoss = view_as<CBossBreakable>(_tBoss);
					if(tBoss.iBreakableEnt == iBreakableEnt)
					{
						bSkip = true;
						break;
					}
				}

				if(!bSkip)
					break;
			}

			if(iBreakableEnt == INVALID_ENT_REFERENCE)
				return false;

			GetEntPropString(iBreakableEnt, Prop_Data, "m_iName", sBreakable, sizeof(sBreakable));

			int iTemplateLoc = FindCharInString(sBreakable, '&', true);
			if(iTemplateLoc == -1)
				return false;

			iTemplateNum = StringToInt(sBreakable[iTemplateLoc + 1]);
		}

		Boss.iBreakableEnt = iBreakableEnt;
	}
	else if(_Boss.IsCounter)
	{
		CBossCounter Boss = view_as<CBossCounter>(_Boss);
		CConfigCounter Config = view_as<CConfigCounter>(_Config);

		char sCounter[64];
		Config.GetCounter(sCounter, sizeof(sCounter));

		int iCounterEnt = INVALID_ENT_REFERENCE;

		if(!bNameFixup)
		{
			iCounterEnt = FindEntityByTargetname(iCounterEnt, sCounter, "math_counter");
			if(iCounterEnt == INVALID_ENT_REFERENCE)
				return false;
		}
		else
		{
			StrCat(sCounter, sizeof(sCounter), "&*");
			while((iCounterEnt = FindEntityByTargetname(iCounterEnt, sCounter, "math_counter")) != INVALID_ENT_REFERENCE)
			{
				char sBuf[64];
				GetEntPropString(iCounterEnt, Prop_Data, "m_iName", sBuf, sizeof(sBuf));

				bool bSkip = false;
				for(int i = 0; i < g_aBoss.Length; i++)
				{
					CBoss _tBoss = g_aBoss.Get(i);
					if(!_tBoss.IsCounter)
						continue;

					CBossCounter tBoss = view_as<CBossCounter>(_tBoss);
					if(tBoss.iCounterEnt == iCounterEnt)
					{
						bSkip = true;
						break;
					}
				}

				if(!bSkip)
					break;
			}

			if(iCounterEnt == INVALID_ENT_REFERENCE)
				return false;

			GetEntPropString(iCounterEnt, Prop_Data, "m_iName", sCounter, sizeof(sCounter));

			int iTemplateLoc = FindCharInString(sCounter, '&', true);
			if(iTemplateLoc == -1)
				return false;

			iTemplateNum = StringToInt(sCounter[iTemplateLoc + 1]);
		}

		Boss.iCounterEnt = iCounterEnt;

		int iCounterOnHitMinCount = GetOutputCount(iCounterEnt, "m_OnHitMin");
		int iCounterOnHitMaxCount = GetOutputCount(iCounterEnt, "m_OnHitMax");

		Config.bCounterReverse = iCounterOnHitMaxCount > iCounterOnHitMinCount;
	}
	else if(_Boss.IsHPBar)
	{
		CBossHPBar Boss = view_as<CBossHPBar>(_Boss);
		CConfigHPBar Config = view_as<CConfigHPBar>(_Config);

		char sIterator[64];
		char sCounter[64];
		char sBackup[64];

		Config.GetIterator(sIterator, sizeof(sIterator));
		Config.GetCounter(sCounter, sizeof(sCounter));
		Config.GetBackup(sBackup, sizeof(sBackup));

		int iIteratorEnt = INVALID_ENT_REFERENCE;
		int iCounterEnt = INVALID_ENT_REFERENCE;
		int iBackupEnt = INVALID_ENT_REFERENCE;

		if(!bNameFixup)
		{
			iIteratorEnt = FindEntityByTargetname(iIteratorEnt, sIterator, "math_counter");
			if(iIteratorEnt == INVALID_ENT_REFERENCE)
				return false;

			iCounterEnt = FindEntityByTargetname(iCounterEnt, sCounter, "math_counter");
			if(iCounterEnt == INVALID_ENT_REFERENCE)
				return false;

			iBackupEnt = FindEntityByTargetname(iBackupEnt, sBackup, "math_counter");
			if(iBackupEnt == INVALID_ENT_REFERENCE)
				return false;
		}
		else
		{
			StrCat(sIterator, sizeof(sIterator), "&*");
			while((iIteratorEnt = FindEntityByTargetname(iIteratorEnt, sIterator, "math_counter")) != INVALID_ENT_REFERENCE)
			{
				bool bSkip = false;
				for(int i = 0; i < g_aBoss.Length; i++)
				{
					CBoss _tBoss = g_aBoss.Get(i);
					if(!_tBoss.IsHPBar)
						continue;

					CBossHPBar tBoss = view_as<CBossHPBar>(_tBoss);
					if(tBoss.iIteratorEnt == iIteratorEnt)
					{
						bSkip = true;
						break;
					}
				}

				if(!bSkip)
					break;
			}

			if(iIteratorEnt == INVALID_ENT_REFERENCE)
				return false;

			GetEntPropString(iIteratorEnt, Prop_Data, "m_iName", sIterator, sizeof(sIterator));

			int iTemplateLoc = FindCharInString(sIterator, '&', true);
			if(iTemplateLoc == -1)
				return false;

			StrCat(sCounter, sizeof(sCounter), sIterator[iTemplateLoc]);
			StrCat(sBackup, sizeof(sBackup), sIterator[iTemplateLoc]);

			iCounterEnt = FindEntityByTargetname(iCounterEnt, sCounter, "math_counter");
			if(iCounterEnt == INVALID_ENT_REFERENCE)
				return false;

			iBackupEnt = FindEntityByTargetname(iBackupEnt, sBackup, "math_counter");
			if(iBackupEnt == INVALID_ENT_REFERENCE)
				return false;

			iTemplateNum = StringToInt(sIterator[iTemplateLoc + 1]);
		}

		Boss.iIteratorEnt = iIteratorEnt;
		Boss.iCounterEnt = iCounterEnt;
		Boss.iBackupEnt = iBackupEnt;

		int iIteratorOnHitMinCount = GetOutputCount(iIteratorEnt, "m_OnHitMin");
		int iIteratorOnHitMaxCount = GetOutputCount(iIteratorEnt, "m_OnHitMax");

		Config.bIteratorReverse = iIteratorOnHitMaxCount > iIteratorOnHitMinCount;

		int iCounterOnHitMinCount = GetOutputCount(iCounterEnt, "m_OnHitMin");
		int iCounterOnHitMaxCount = GetOutputCount(iCounterEnt, "m_OnHitMax");

		Config.bCounterReverse = iCounterOnHitMaxCount > iCounterOnHitMinCount;
	}

	_Boss.bActive = true;

	if(iTemplateNum != -1)
	{
		_Boss.iTemplateNum = iTemplateNum;

		char sShowTrigger[64];
		_Config.GetShowTrigger(sShowTrigger, sizeof(sShowTrigger));

		if(sShowTrigger[0])
		{
			Format(sShowTrigger, sizeof(sShowTrigger), "%s&%04d", sShowTrigger, iTemplateNum);

			char sShowOutput[64];
			_Config.GetShowOutput(sShowOutput, sizeof(sShowOutput));

			int entity = INVALID_ENT_REFERENCE;
			while((entity = FindEntityByTargetname(entity, sShowTrigger)) != INVALID_ENT_REFERENCE)
			{
				if(StrEqual(sShowOutput, "OnTakeDamage"))
				{
					SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePostShow);
				}
				else
				{
					HookSingleEntityOutput(entity, sShowOutput, OnEntityOutputShow, true);
				}

				LogMessage("Hooked showtrigger %s:%s", sShowTrigger, sShowOutput);
			}
		}

		char sKillTrigger[64];
		_Config.GetKillTrigger(sKillTrigger, sizeof(sKillTrigger));

		if(sKillTrigger[0])
		{
			Format(sKillTrigger, sizeof(sKillTrigger), "%s&%04d", sKillTrigger, iTemplateNum);

			char sKillOutput[64];
			_Config.GetKillOutput(sKillOutput, sizeof(sKillOutput));

			int entity = INVALID_ENT_REFERENCE;
			while((entity = FindEntityByTargetname(entity, sKillTrigger)) != INVALID_ENT_REFERENCE)
			{
				if(StrEqual(sKillOutput, "OnTakeDamage"))
				{
					SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePostKill);
				}
				else
				{
					HookSingleEntityOutput(entity, sKillOutput, OnEntityOutputKill, true);
				}

				LogMessage("Hooked killtrigger %s:%s", sKillTrigger, sKillOutput);
			}
		}
	}

	char sBoss[64];
	_Config.GetName(sBoss, sizeof(sBoss));
	LogMessage("Initialized boss %s (template = %d)", sBoss, iTemplateNum);

	return true;
}

bool BossProcess(CBoss _Boss)
{
	CConfig _Config = _Boss.dConfig;

	bool bInvalid = false;
	int iHealth = 0;
	int iLastHealth = _Boss.iHealth;
	int iLastChange = _Boss.iLastChange;

	if(_Boss.IsBreakable)
	{
		CBossBreakable Boss = view_as<CBossBreakable>(_Boss);

		int iBreakableEnt = Boss.iBreakableEnt;

		if(IsValidEntity(iBreakableEnt))
			iHealth = GetEntProp(iBreakableEnt, Prop_Data, "m_iHealth");
		else
			bInvalid = true;
	}
	else if(_Boss.IsCounter)
	{
		CBossCounter Boss = view_as<CBossCounter>(_Boss);
		CConfigCounter Config = view_as<CConfigCounter>(_Config);

		int iCounterEnt = Boss.iCounterEnt;

		if(IsValidEntity(iCounterEnt))
		{
			int iCounterVal = RoundFloat(GetOutputValueFloat(iCounterEnt, "m_OutValue"));

			if(!Config.bCounterReverse)
			{
				int iCounterMin = RoundFloat(GetEntPropFloat(iCounterEnt, Prop_Data, "m_flMin"));
				iHealth = iCounterVal - iCounterMin;
			}
			else
			{
				int iCounterMax = RoundFloat(GetEntPropFloat(iCounterEnt, Prop_Data, "m_flMax"));
				iHealth = iCounterMax - iCounterVal;
			}
		}
		else
			bInvalid = true;
	}
	else if(_Boss.IsHPBar)
	{
		CBossHPBar Boss = view_as<CBossHPBar>(_Boss);
		CConfigHPBar Config = view_as<CConfigHPBar>(_Config);

		int iIteratorEnt = Boss.iIteratorEnt;
		int iCounterEnt = Boss.iCounterEnt;
		int iBackupEnt = Boss.iBackupEnt;

		if(IsValidEntity(iIteratorEnt) && IsValidEntity(iCounterEnt) && IsValidEntity(iBackupEnt))
		{
			int iIteratorVal = RoundFloat(GetOutputValueFloat(iIteratorEnt, "m_OutValue"));
			int iCounterVal = RoundFloat(GetOutputValueFloat(iCounterEnt, "m_OutValue"));
			int iBackupVal = RoundFloat(GetOutputValueFloat(iBackupEnt, "m_OutValue"));

			if(!Config.bIteratorReverse)
			{
				int iIteratorMin = RoundFloat(GetEntPropFloat(iIteratorEnt, Prop_Data, "m_flMin"));
				iHealth = (iIteratorVal - iIteratorMin - 1) * iBackupVal;
			}
			else
			{
				int iIteratorMax = RoundFloat(GetEntPropFloat(iIteratorEnt, Prop_Data, "m_flMax"));
				iHealth = (iIteratorMax - iIteratorVal - 1) * iBackupVal;
			}

			if(!Config.bCounterReverse)
			{
				int iCounterMin = RoundFloat(GetEntPropFloat(iCounterEnt, Prop_Data, "m_flMin"));
				iHealth += iCounterVal - iCounterMin;
			}
			else
			{
				int iCounterMax = RoundFloat(GetEntPropFloat(iCounterEnt, Prop_Data, "m_flMax"));
				iHealth += iCounterMax - iCounterVal;
			}
		}
		else
			bInvalid = true;
	}

	if(iHealth < 0)
		iHealth = 0;

	if(iHealth != iLastHealth)
	{
		iLastChange = GetTime();
		_Boss.iLastChange = iLastChange;
	}

	// Boss hasn't initialized HP yet.
	if(iHealth == 0 && iLastHealth == 0)
	{
		// Boss invalid: Delete boss
		if(bInvalid)
			return false;

		return true;
	}

	_Boss.iHealth = iHealth;

	bool bShow = _Boss.bShow;
	if(!bShow && _Boss.fShowAt && _Boss.fShowAt < GetGameTime())
	{
		bShow = true;
		_Boss.bShow = true;
	}

	if(bShow)
	{
		int iTimeout = _Config.iTimeout;
		if(iTimeout < 0 || GetTime() - iLastChange < iTimeout)
		{
			char sFormat[64];
			if(g_sHUDText[0])
			{
				sFormat[0] = '\n';
				_Config.GetName(sFormat[1], sizeof(sFormat) - 1);
			}
			else
				_Config.GetName(sFormat, sizeof(sFormat));

			int FormatLen = strlen(sFormat);
			sFormat[FormatLen++] = ':';
			sFormat[FormatLen++] = ' ';

			FormatLen += IntToString(iHealth, sFormat[FormatLen], sizeof(sFormat) - FormatLen);
			sFormat[FormatLen] = 0;

			StrCat(g_sHUDText, sizeof(g_sHUDText), sFormat);
		}
	}

	// Boss dead/invalid: Delete boss
	if(!iHealth || bInvalid)
		return false;

	return true;
}

int FindEntityByTargetname(int entity, const char[] sTargetname, const char[] sClassname="*")
{
	if(sTargetname[0] == '#') // HammerID
	{
		int HammerID = StringToInt(sTargetname[1]);

		while((entity = FindEntityByClassname(entity, sClassname)) != INVALID_ENT_REFERENCE)
		{
			if(GetEntProp(entity, Prop_Data, "m_iHammerID") == HammerID)
				return entity;
		}
	}
	else // Targetname
	{
		int Wildcard = FindCharInString(sTargetname, '*');
		char sTargetnameBuf[64];

		while((entity = FindEntityByClassname(entity, sClassname)) != INVALID_ENT_REFERENCE)
		{
			if(GetEntPropString(entity, Prop_Data, "m_iName", sTargetnameBuf, sizeof(sTargetnameBuf)) <= 0)
				continue;

			if(strncmp(sTargetnameBuf, sTargetname, Wildcard) == 0)
				return entity;
		}
	}

	return INVALID_ENT_REFERENCE;
}
