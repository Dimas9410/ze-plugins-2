#include <sourcemod>
#include <cstrike>

ConVar g_Cvar_HlxBonusHuman;
ConVar g_Cvar_HlxBonusZombie;

public Plugin myinfo =
{
	name			= "SuperLogs: Z:R",
	author			= "BotoX",
	description		= "HLstatsX CE Zombie:Reloaded extension",
	version			= "1.0",
	url				= ""
};

public void OnPluginStart()
{
	g_Cvar_HlxBonusHuman = CreateConVar("hlx_bonus_human", "0", "", 0, true, 0.0, true, 1000.0);
	g_Cvar_HlxBonusZombie = CreateConVar("hlx_bonus_zombie", "0", "", 0, true, 0.0, true, 1000.0);

	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);

	AutoExecConfig(true, "plugin.superlogs-zr");
}

public void Event_RoundEnd(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	switch(hEvent.GetInt("winner"))
	{
		case(CS_TEAM_CT):
		{
			LogToGame("Team \"CT\" triggered \"Humans_Win\" (hlx_team_bonuspoints \"%d\")", g_Cvar_HlxBonusHuman.IntValue);
		}
		case(CS_TEAM_T):
		{
			LogToGame("Team \"TERRORIST\" triggered \"Zombies_Win\" (hlx_team_bonuspoints \"%d\")", g_Cvar_HlxBonusZombie.IntValue);
		}
	}
}
