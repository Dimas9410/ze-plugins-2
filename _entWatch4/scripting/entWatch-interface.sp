//====================================================================================================
//
// Name: [entWatch] Interface
// Author: zaCade & Prometheum
// Description: Handle the interface of [entWatch]
//
//====================================================================================================
#include <smlib>

#pragma newdecls required

#include <sourcemod>
#include <entWatch4>
#include <entWatch_core>

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin myinfo =
{
	name         = "[entWatch] Interface",
	author       = "zaCade & Prometheum",
	description  = "Handle the interface of [entWatch]",
	version      = "4.0.0"
};

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnGameFrame()
{
	if (EW_GetItemCount())
	{
		char sHUDFormat[250];
		char sHUDBuffer[64];

		for (int index; index < EW_GetItemCount(); index++)
		{
			any itemArray[items];
			EW_GetItemArray(index, itemArray, sizeof(itemArray));

			if (itemArray[item_display] & DISPLAY_HUD)
			{
				if (itemArray[item_owned] && itemArray[item_owner] >= 0)
				{
					switch(itemArray[item_mode])
					{
						case(1):
						{
							if (itemArray[item_nextuse] > RoundToCeil(GetEngineTime()))
							{
								Format(sHUDBuffer, sizeof(sHUDBuffer), "%s [%d]: %N", itemArray[item_short], itemArray[item_nextuse] - RoundToCeil(GetEngineTime()), itemArray[item_owner]);
							}
							else
							{
								Format(sHUDBuffer, sizeof(sHUDBuffer), "%s [%s]: %N", itemArray[item_short], "R", itemArray[item_owner]);
							}
						}
						case(2):
						{
							if (itemArray[item_uses] < itemArray[item_maxuses])
							{
								Format(sHUDBuffer, sizeof(sHUDBuffer), "%s [%d/%d]: %N", itemArray[item_short], itemArray[item_uses], itemArray[item_maxuses], itemArray[item_owner]);
							}
							else
							{
								Format(sHUDBuffer, sizeof(sHUDBuffer), "%s [%s]: %N", itemArray[item_short], "D", itemArray[item_owner]);
							}
						}
						case(3):
						{
							if (itemArray[item_uses] < itemArray[item_maxuses])
							{
								if (itemArray[item_nextuse] > RoundToCeil(GetEngineTime()))
								{
									Format(sHUDBuffer, sizeof(sHUDBuffer), "%s [%d]: %N", itemArray[item_short], itemArray[item_nextuse] - RoundToCeil(GetEngineTime()), itemArray[item_owner]);
								}
								else
								{
									Format(sHUDBuffer, sizeof(sHUDBuffer), "%s [%d/%d]: %N", itemArray[item_short], itemArray[item_uses], itemArray[item_maxuses], itemArray[item_owner]);
								}
							}
							else
							{
								Format(sHUDBuffer, sizeof(sHUDBuffer), "%s [%s]: %N", itemArray[item_short], "D", itemArray[item_owner]);
							}
						}
						case(4):
						{
							if (itemArray[item_nextuse] > RoundToCeil(GetEngineTime()))
							{
								Format(sHUDBuffer, sizeof(sHUDBuffer), "%s [%d]: %N", itemArray[item_short], itemArray[item_nextuse] - RoundToCeil(GetEngineTime()), itemArray[item_owner]);
							}
							else
							{
								Format(sHUDBuffer, sizeof(sHUDBuffer), "%s [%d/%d]: %N", itemArray[item_short], itemArray[item_uses], itemArray[item_maxuses], itemArray[item_owner]);
							}
						}
						default:
						{
							Format(sHUDBuffer, sizeof(sHUDBuffer), "%s [%s]: %N", itemArray[item_short], "N/A", itemArray[item_owner]);
						}
					}

					if (strlen(sHUDFormat) + strlen(sHUDBuffer) <= sizeof(sHUDFormat) - 2)
					{
						Format(sHUDFormat, sizeof(sHUDFormat), "%s\n%s", sHUDFormat, sHUDBuffer);
					}
					else break;
				}
			}
		}

		Handle hMessage = StartMessageAll("KeyHintText");
		BfWriteByte(hMessage, 1);
		BfWriteString(hMessage, sHUDFormat);
		EndMessage();
	}
}