# fr0z3nUI Tax

This folder is loaded as part of `fr0z3nUI_GameOptions` through the parent TOC.

It can also be run standalone by placing the folder fr0z3nUI_Tax into `Interface/AddOns` and used
without FGO. 

Standalone mode provides:
- `/fax` or `/ftax` to open the Tax window (if LDB is used, right click opens it.)
- Guild Bank and WarBank tax tracking, depositing and withdrawing when enabled.
- Separate account and character savedvariables (FGO's tax data cannot be seen).

When WoW Token is enabled, XS Min reserves the current token price plus Min Gold,
so purchasing a token leaves the configured minimum on the character. This applies
to both Guild Bank and WarBank excess deposits.

If both FGO and FAX are running, the standalone Tax addon is inactive
so Tax does not register duplicate events or broker objects.

Non-deposit owed reductions print a `[Tax]` message with the bank/balance, cause,
and before/after amounts for legacy account-balance migration and Clear calls.
These diagnostics remain enabled with Quiet on, Debug off, bank prints off,
or a closed bank frame. Clear messages are printed even when nothing is owed;
borrowed debt is retained.
Routine automatic, Pay Now, and tracked manual deposits use normal bank-move
messages, never an abnormal-clear diagnostic. Normal messages respect Quiet and
the selected bank print mode, but do not depend on bank-frame visibility when
a delayed deposit callback runs.
LootChat leaves `[Tax]` diagnostics intact instead of rewriting them as loot money.

Deposit messages report that the deposit API returned without a Lua error;
this is not confirmation that the server accepted the transfer. Manual bank
tracking treats player money losses while the bank is open as deposits.
Switching character/shared owed scope displays a different balance; it does
not clear the previous balance.