#if defined _SelectiveBhop_Included
	#endinput
#endif
#define _SelectiveBhop_Included

native int LimitBhop(int client, bool bLimited);
native int IsBhopLimited(int client);

public SharedPlugin __pl_SelectiveBhop =
{
	name = "SelectiveBhop",
	file = "SelectiveBhop.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_SelectiveBhop_SetNTVOptional()
{
	MarkNativeAsOptional("LimitBhop");
	MarkNativeAsOptional("IsBhopLimited");
}
#endif
