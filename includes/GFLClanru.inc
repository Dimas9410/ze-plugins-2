#if defined _GFLClanru_Included
	#endinput
#endif
#define _GFLClanru_Included

typeset AsyncHasSteamIDReservedSlotCallbackFunc
{
	function void (const char[] sSteam32ID, int Result);
	function void (const char[] sSteam32ID, int Result, any Data);
};

native void AsyncHasSteamIDReservedSlot(const char[] sSteam32ID, AsyncHasSteamIDReservedSlotCallbackFunc Callback, any Data = 0);

public SharedPlugin __pl_GFLClanru =
{
	name = "GFLClanru",
	file = "GFLClanru.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_GFLClanru_SetNTVOptional()
{
	MarkNativeAsOptional("AsyncHasSteamIDReservedSlot");
}
#endif
