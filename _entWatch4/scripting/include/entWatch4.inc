#if defined entWatch_included
	#endinput
#endif

#define entWatch_included

#define DISPLAY_CHAT (1 << 0)
#define DISPLAY_HUD  (1 << 1)
#define DISPLAY_USE  (1 << 2)

enum items
{
	String:item_name[32],
	String:item_short[32],
	String:item_color[32],
	String:item_filter[32],
	bool:item_owned,
	item_buttonid,
	item_weaponid,
	item_triggerid,
	item_owner,
	item_button,
	item_weapon,
	item_trigger,
	item_display,
	item_mode,
	item_uses,
	item_maxuses,
	item_nextuse,
	item_cooldown,
};