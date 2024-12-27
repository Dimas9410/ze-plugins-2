#include <sourcemod>
#include <sdktools>
#include <cstrike>

public OnPluginStart()
{
    RegConsoleCmd("sm_smradio", Radio_Command);
}

public Action:Radio_Command(client, args)
{
    FakeClientCommand(client, "ignorerad");

    return Plugin_Handled;
}