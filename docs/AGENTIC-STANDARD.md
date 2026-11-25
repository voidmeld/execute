# Changing a workflow

Start with the task table in the README and follow the links as if you were using Execute for the first time.
Within two links, a reader must be able to tell what the workflow is for, who may act, what work is underway,
and which check to run. Write each rule in one place. Keep a project's exact commands and permissions in its
own repository.

Before you remove a step or tool, check where code imports it or looks it up at runtime, where
commands invoke it, and how examples and tests use it. Preserve the behavior and error handling
that callers rely on unless the change explicitly replaces them.

Try the revised instructions on a real task. Go through a failure and the steps to recover from it.
Inspect the actual output before reporting success. Count how much someone has to read and remove
repeated instructions. Report what changed, what you checked, and any limits that remain.
