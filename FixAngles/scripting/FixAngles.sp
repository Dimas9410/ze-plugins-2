#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "FixAngles",
	author = "BotoX",
	description = "",
	version = "1.0",
	url = ""
};

public void OnMapStart()
{
	CreateTimer(1.0, CheckAngles, 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action CheckAngles(Handle timer)
{
	int entity = INVALID_ENT_REFERENCE;
	while((entity = FindEntityByClassname(entity, "func_rotating")) != INVALID_ENT_REFERENCE)
	{
		if(!HasEntProp(entity, Prop_Send, "m_angRotation"))
			continue;

		static float aAngles[3];
		GetEntPropVector(entity, Prop_Send, "m_angRotation", aAngles);

		bool bChanged = false;
		for(int i = 0; i < 3; i++)
		{
			if(aAngles[i] < -360 || aAngles[i] > 360)
			{
				aAngles[i] = float(RoundFloat(aAngles[i]) % 360);
				bChanged = true;
			}
		}

		if(bChanged)
			SetEntPropVector(entity, Prop_Send, "m_angRotation", aAngles);
	}

	return Plugin_Continue;
}
