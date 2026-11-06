# Contributing to Execute

Thank you for helping improve Execute. Execute is a template for work that agents do in a project. These steps change Execute itself; to adopt it in a project, follow the README.

## Set up

Install [Rokit](https://github.com/rojo-rbx/rokit), then install the pinned tools from the repository root:

```console
rokit install
```

## Rules

Read [AGENTS.md](AGENTS.md) before you change anything. It owns the code, documentation and integration rules.
Every maintained Luau file starts with `--!strict` and uses no explicit `any` and no type casts.
Keep the machinery that current adopters need, and remove duplication without weakening authority or evidence.

## Check your change

While you edit, run the fast checks with `lute run tools/gate.luau --tier fast`, or focus them with `--file <test file>` or `--name <text>`.
Commit the change, then run the full gate once on the clean HEAD with `lute run tools/gate.luau`.

## Pull requests

Open a pull request to `main` from a branch. Keep each pull request to one coherent change, and describe what
it changes and how you checked it. The required checks must pass. Do not push directly to `main` or bypass a
failing check.

## Reporting issues

Open a GitHub issue with the steps to reproduce, the result you expected and the result you saw.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
