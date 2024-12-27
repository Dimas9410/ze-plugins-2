#if defined _TopDefenders_OnRoundEnd
	#endinput
#endif
#define _TopDefenders_OnRoundEnd

/**
 * Called when TopDefenders are being printed out.
 *
 * @param iPlayers          The sorted array of the Defenders' Client IDs. (iPlayers[0] is the TopDefender)
 * @param iDamage           The sorted array of the Defenders' Damages. (iDamage[0] is the TopDefender's Damage)
 */
forward void TopDefenders_OnRoundEnd(int iPlayers[MAXPLAYERS+1], int iDamage[MAXPLAYERS+1]);

/**
 * Returns the current damage of a client
 *
 * @param client		Client index.
 * @return				The current damage of the client.
 */
native int TopDefenders_GetClientDamage(int client);