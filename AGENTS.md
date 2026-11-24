# Execute maintainer guide

Execute supplies operating documents and optional Luau tools for agent work.
It owns reusable procedures. Adopters own authority, product policy and host operations.
This file owns contribution rules. The [README](README.md) maps the repository.

First action: identify the contract for the assigned change in the README task table.
Read only that contract and its consumers. For a first use, follow the [quickstart](docs/quickstart.md).
The [adopter template](AGENTS.template.md) governs an adopter only after its values and grants are filled.

## Rules

- Apply the [agentic standard](docs/AGENTIC-STANDARD.md) when changing a workflow. Read it for that task.
- Keep each fact in one owning document. Repair the contract and its callers together.
- Keep adopter identities, destinations, credentials, policy and milestones out of this repository.
- Preserve authority, recovery and evidence requirements when simplifying procedures.
- Keep only machinery that current consumers need. Inspect dynamic, CLI, documentation and test consumers before removal.
- Write tools in Luau. Start maintained source with `--!strict`. Use no explicit `any` or type assertions.
- Add no code comments except compiler directives and required license notices.
- Inject Git, filesystem, clock and process operations. A module grants no authority to invoke them.
- Do not stop or reconfigure resources owned by another session.

## Validate

- Run a focused check while editing: `lute run tools/gate.luau --file extensions/luau/scoped-checks.verify.luau`.
- Use `--tier fast` for all fast checks. Use Verify cases for specifications.
- After changing the specification list, run `lute run tools/check-test-manifest.luau --write`.
- Update [the API](docs/api.md) for a changed public contract. The public-surface check requires documentation entries.
- Commit the candidate. Run `lute run tools/gate.luau` on the clean HEAD, including the fresh-clone check.
- Do not change verified bytes before integration. Reuse evidence while its inputs remain unchanged.
- Read [validation](docs/VALIDATE.md) only for setup, selectors or failure diagnosis.

## Repository

Use a pull request to `main` and the required `Gate` check.
Do not push directly to `main` or bypass a failed check.
Use author and committer `voidmeld <158495725+voidmeld@users.noreply.github.com>` without attribution trailers.
Keep history append-only unless the repository owner authorizes a rewrite.
