# Interactive QA

This page owns evidence rules for products with an interface. The project supplies exact commands, hosts,
devices and destinations.

## Evidence for an experience claim

Follow the core [evidence record](../../../docs/PLAYBOOK.md#evidence). Run the exact candidate through ordinary
input in the required host. Also record the device, input class, console output and original capture. If
live-state observations are available, record them.

## Captures

Capture the assigned application window or output region. Inspect the originals. For motion and audio, use
evidence that records changes with time. One viewport does not prove other devices or orientations.

## Scenarios and user checks

A scenario proves only the path that it exercises. Workers run QA, inspect evidence and repair assigned
outcomes. The CEO judges the integrated result and evidence against fixed criteria. State coverage and limits.
Present a build only after required scenarios and user checks pass. Before integration of user-visible work,
inspect saved captures.

## Input and release

Before input or capture, confirm identity and exclusive ownership. Independent runtimes can run concurrently.
Shared desktop input or capture requires serial ownership. When the scenario ends, release held input. End test
mode. Follow [runtime ownership](../../../docs/PLAYBOOK.md#runtime-ownership) for each driver.
