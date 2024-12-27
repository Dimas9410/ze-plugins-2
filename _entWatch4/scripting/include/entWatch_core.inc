#if defined entWatch_core_included
	#endinput
#endif

#define entWatch_core_included

public SharedPlugin __pl_entWatch_core =
{
	name = "entWatch-core",
	file = "entWatch-core.smx",

	#if defined REQUIRE_PLUGIN
		required = 1
	#else
		required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
	public void __pl_entWatch_core_SetNTVOptional()
	{
		MarkNativeAsOptional("EW_GetItemCount");
		MarkNativeAsOptional("EW_GetItemArray");
		MarkNativeAsOptional("EW_SetItemArray");
	}
#endif

native int EW_GetItemCount();

native void EW_GetItemArray(int index, any[] itemArray, int size);
native void EW_SetItemArray(int index, any[] itemArray, int size);

forward void EW_OnClientItemDrop(any[] itemArray, int client, int index);
forward void EW_OnClientItemDeath(any[] itemArray, int client, int index);
forward void EW_OnClientItemPickup(any[] itemArray, int client, int index);
forward void EW_OnClientItemActivate(any[] itemArray, int client, int index);
forward void EW_OnClientItemDisconnect(any[] itemArray, int client, int index);

forward Action EW_OnClientItemCanPickup(any[] itemArray, int client, int index);
forward Action EW_OnClientItemCanActivate(any[] itemArray, int client, int index);