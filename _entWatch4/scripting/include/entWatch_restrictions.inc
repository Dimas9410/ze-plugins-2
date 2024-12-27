#if defined entWatch_restrictions_included
	#endinput
#endif

#define entWatch_restrictions_included

public SharedPlugin __pl_entWatch_core =
{
	name = "entWatch-restrictions",
	file = "entWatch-restrictions.smx",

	#if defined REQUIRE_PLUGIN
		required = 1
	#else
		required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
	public void __pl_entWatch_core_SetNTVOptional()
	{
		MarkNativeAsOptional("EW_ClientRestrict");
		MarkNativeAsOptional("EW_ClientUnrestrict");
		MarkNativeAsOptional("EW_ClientRestricted");
	}
#endif

native bool EW_ClientRestrict(int client, int target, int length);
native bool EW_ClientUnrestrict(int client, int target);
native bool EW_ClientRestricted(int client);

forward void EW_OnClientRestricted(int client, int target, int length);
forward void EW_OnClientUnrestricted(int client, int target);