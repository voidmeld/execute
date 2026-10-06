# Interactive QA

This page owns the evidence rules for a product that a person operates through an interface.
The adopter supplies the exact commands, hosts, devices and destinations.

## Evidence for an experience claim

The assigned helper or the CEO runs the exact candidate through ordinary input in the required host. Record:

- the product commit and artifact
- the host and the destination version
- the relevant configuration and dependencies
- the device and input class
- the console output
- the original capture
- live-state observations, when available
- the receipt path

Bind the evidence to the product commit that ran, not to a later receipt commit.

## Captures

Address captures to the assigned application window or output region. Inspect the originals.
Motion and audio need time-based evidence. One viewport does not prove other devices or orientations.

## Scenarios and user checks

A scenario proves the path that it exercises.
Helpers execute QA and repair their assigned outcomes. The CEO inspects the integrated result and evaluates the returned evidence against the fixed criteria.
State the coverage and the limits. A passing gate does not prove the whole experience.
Do not present a build until its required scenario and user checks pass.
Inspect the saved captures before you land user-visible work.

## Input and release

Confirm identity and handoff before you send input.
When the scenario ends, release held input and end test mode.
Follow [runtime ownership](../../../docs/PLAYBOOK.md#runtime-ownership) for the driver of each surface.
