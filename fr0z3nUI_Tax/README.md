# fr0z3nUI Tax

This folder is loaded as part of `fr0z3nUI_GameOptions` through the parent TOC.

It can also be run standalone by placing the folder fr0z3nUI_Tax into `Interface/AddOns` and used
without FGO. 

Standalone mode provides:
- `/fax` or `/ftax` to open the Tax window (if LDB is used, right click opens it.)
- Guild Bank and WarBank tax tracking, depositing and withdrawing when enabled.
- Separate account and character savedvariables (FGO's tax data cannot be seen).

If both FGO and FAX are running, the standalone Tax addon is inactive
so Tax does not register duplicate events or broker objects.