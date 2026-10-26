# Roblox adoption

An adopting project must declare the values below when it adopts the Roblox extension.
The operating rules are in [README.md](README.md) and [docs/ROBLOX.md](docs/ROBLOX.md).

Declare these values in the project layer, with exact values:

1. Accounts and destinations:
   - the group owner, the operator account and the recovery account, kept apart
   - the universes, the places and the asset creator
   - distinct private development, private staging and restricted production destinations
   - a production exclusion that binds until the Owner gives exact public-release authority
2. The least-privilege Open Cloud scopes. Name them by variable, never by value.
3. The deterministic source build, the exact command of each verification-ladder tier, publish, rollback and destination readback.
4. Studio ownership, the application and input boundaries, and the abort floor.
5. DataStore isolation and the destructive-operation refusal.
6. Asset source, rights, lineage, quarantine, moderation, ownership, durable IDs, consumers and played proof.
7. The tracked gate and the audit of the user-scope permission overlay.

Publication defaults to non-production destinations: private or restricted. Production is never an implicit alias, fallback or retry destination.
Merge only irreversible-loss rules into AGENTS. Link PLAYBOOK to the exact Roblox procedure of the project.
Load generative guidance only for that work.
