# Roblox adoption

When a project adopts this extension, declare the values below. The operating rules are in
[README.md](README.md) and [docs/ROBLOX.md](docs/ROBLOX.md).

Record exact project values:

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

By default, publish only to private or restricted destinations outside production. Do not use production as an
implicit alias, alternative or retry destination. Merge only rules against irreversible loss into AGENTS. Link
PLAYBOOK to the project's exact Roblox procedure. Read generation guidance only for generation work.
