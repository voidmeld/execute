# Roblox operations

This page owns the Roblox operating rules. [INTEGRATION](../INTEGRATION.md) lists the values that the adopter must supply.
Exact IDs and commands stay in the adopting project.
Read [generative assets](ROBLOX-GENERATIVE-ASSETS.md) only for generation work.

## Account and destination

- One least-privilege studio operator performs every mutation. Owner and recovery accounts stay outside automation.
- Group accounts own experiences and durable assets.
- Before a mutation, bind and read back the operator, creator, owner, destination, access and expected source.
- After a warning or a rejection, never switch accounts.
- Credentials, cookies, keys, account changes and payment data are Owner-only. They never enter Git, logs, chat or the context of a bounded task.

## Verification ladder

1. **Static and spec:** source, types, contracts and deterministic builds.
2. **Headless engine:** APIs and engine behavior on an isolated test place.
3. **Scenario play:** a scripted journey with captures, under the exact identity of the built source.
4. **Played destination:** the published client journey and an independent artifact verdict.

Evidence from a lower tier never proves a claim of a higher tier.
Publication is complete only when you read back the source identity, owner, privacy, moderation, access and destination bytes.
A failed build cannot be the rollback target. Rollback republishes the last accepted source through the same gate and readback.

## Studio and persistence

### Source sync

- Keep one source-sync owner for each script tree.
- With Rojo, keep the configured server, project and place binding. Use the saved endpoint of the plugin and its automatic reconnect where supported.
- A normal script edit needs no binary place build and no new Studio.
- After you change mounts or reconnect, verify the affected instances and source in the intended document before a fresh Play.
- Read the current source identity directly. Do not trust a cached module or an earlier build receipt.
- Native [Script Sync](https://create.roblox.com/docs/scripting/sync) is another option for script and folder editing. It does not synchronize every Instance property, attribute or tag.
- Before you migrate, exercise the shared mounts, the script classes and run contexts, and the non-script content of the adopter.
- Test the real authoring loop and the conflict recovery. Remove the displaced setup only after the new route works.
- Do not build a second custom synchronizer to hide a layout mismatch. Keep project-specific commands in the adopter.

### Local multiplayer

- Reuse the assigned Edit document and the `StudioTestService` launch and end flow of Roblox.
- After source sync, load the current launcher code and identity. The `require` cache of Edit can outlive many revisions.
- Keep any installed toolbar independent of the game commit. Then a game edit does not require a plugin reinstallation.
- Bind results to the actual run, the source and the participating clients. An installer receipt does not establish what those clients played.
- Stop through the native test controls and verify cleanup. Keep the source Studio.
- A readiness probe proves startup. It does not prove any gameplay interaction or durability. Observe the relevant interaction separately.
- Keep exploratory sessions usable without registering a new scenario.
- A scenario-specific server probe must check whether the launch arguments belong to it before it validates or ends the session. An unrelated probe must not end a manual test.
- Read the mounted identity after source generation. Generation can finish before live sync delivers its changes.

### Population and client startup

Choose the population by the claim:

- two clients for actor and observer behavior
- a small group for shared activity and rewards
- up to eight clients for overlapping activity and departure cleanup

Do not repeat the largest run for every content edit.
Server admission is not client readiness. Inspect the loaded UI, input and presentation of each client. Then exercise the interaction.
Keep failed cold launches apart from later successful runs. Distinguish local host contention from gameplay or network capacity.

Client startup must tolerate replication order at shared module boundaries.

- For a required replicated root or module, use native `WaitForChild`. Do not add another loader or retry manager.
- Scope UI subscriptions to the data that they consume. The replicated tree of another player must not rebuild a local list.
- Share expensive derived values through the existing reactive system. Keep the interfaces of the callers.
- Test these repairs in actual clients. Pure tests cannot reproduce a missing replicated Instance. They cannot qualify visual readiness.

### Captures

The [interactive QA rules](../../interactive-qa/docs/INTERACTIVE-QA.md#captures) apply first. The rules below add the Roblox window specifics.

Validate the capture surface against the actual window before you judge world-space UI.
A Studio automation screenshot can omit BillboardGui labels that the window displays. An enabled property does not prove that text is visible.
For world-space labels and markers, inspect a capture of the exact owned window. Use the existing window source when it is available.
Keep the original image and its source binding. A still image needs no video recording and no new calibration or receipt pipeline.

### Ownership and persistence

- Assign one driver for each Studio surface under [runtime ownership](../../../docs/PLAYBOOK.md#runtime-ownership).
- Bind the place and the account before you save or publish. Read them back afterward.
- Prefer native controls. A failed or ambiguous UI action enters the bounded recovery procedure of the project.
- Never run destructive operations against production DataStores. Never test on production data.
- A persistence claim needs an isolated test destination, a fail-closed lease, session fencing, ordered writes, bounded close draining, recovery observation and an exact readback.

### Plugin context

Plugin-context execution, such as an automation bridge or a plugin console, has its own module cache.
Module-level state that you set there is invisible to game scripts.
A testing hook must be engine state, such as an attribute, not a module flag.
Capability-restricted input APIs are unavailable from that context. Drive the public virtual-input seam that the shipped client also honors.
Capture only the application window region, never the desktop.

## Live client runs

The [interactive QA rules](../../interactive-qa/docs/INTERACTIVE-QA.md#evidence-for-an-experience-claim) define the evidence record for a played client.
The published client verifies destination behavior.
Follow [runtime ownership](../../../docs/PLAYBOOK.md#runtime-ownership) and use the isolated test data of the adopter.

- Run one played client at a time. Concurrent runs with the same identity can collide with a profile lease. Stop the prior run and confirm cleanup before another attempt.
- After a restart, reset or replace the test scope through the authorized project route. A stale character or session can block admission. A restart grants no publication and no mutation retry.
- Before the first run against a new place, verify direct-join access.
- If admission hangs, stop the assigned client normally and reconcile its lease before you retry. Forced termination needs the cleanup grant of the project.
- Keep the assigned window active. Diagnose host throttling separately from gameplay failure. Change OS settings only through an authorized route.
- Read the log of the client. Put the verdict instrumentation of the client on a channel that it receives.

## Admission gates that substitutes do not catch

Check the live boundaries that source tests and local fixtures cannot establish:

| Boundary | Verify |
| --- | --- |
| Loading and routing | Module and remote return shapes, required dependencies and the actual outcome API. |
| Replicated data | Attribute values and encoded string sizes against current platform limits. |
| Persistence | Store names and key sizes against platform limits, using an isolated real service. |
| Instance writes | Scriptability, mesh and collision writes and native create return values. |
| Failure reporting | Preserve the underlying reason through `pcall`. Return a named refusal instead of an anonymous timeout. |

A publication packet closes only after a real client journey.
Test the actual modules and platform resources. A hand-written fake cannot qualify service admission.

## Assets

Every imported or generated asset keeps these records:

- the source and conditioning provenance
- the rights
- the payload hash
- the creator and the owner
- moderation, privacy and access
- the dependencies
- the quarantine verdicts
- the durable ID
- the runtime consumer
- the played proof

Marketplace payloads are geometry and rigs only. Inspect them for scripts and capabilities before they enter the shipped Workspace.

Generation, upload, access change, place save and publication are external mutations.

1. Bind the exact payload and destination.
2. Apply risk-tiered independent review.
3. Perform one authorized act.
4. Read back ownership, privacy and moderation.

Never enable irreversible open use. Never blind-retry. Never reuse a rejected or warned payload or derivative.
Assets stay private, restricted and off-sale by default.
A privacy change is not retroactive proof. Read every destination and dependency again.
One parent receipt never licenses its dependency graph. Audit the ownership, permission, moderation and access of each dependency separately.

### Authored animation

Before you adopt an AnimationClip, preview the selected clip on the actual compatible rig.
In Studio Edit, `AnimationClipProvider:RegisterActiveAnimationClip` with `Animator:StepAnimations` supports a local preview.
Temporary registration can behave differently in split client and server Play.
A loaded length alone does not prove motion. Check advancing time, weight and visibly correct joint direction.

- Studio's `SerializationService:SerializeInstancesAsync({clip})` keeps native RBXM bytes.
- Open Cloud accepts RBXM and RBXMX as Animation with `model/x-rbxm`. Reuse the existing uploader, the explicit creator and the one-attempt journal.
- Check the supported types before you substitute AssetService for animation upload.
- After upload, keep the cloud ID and revision. Resume its status instead of recreating it.
- Prove the cloud clip through equipped public actions, confirmation and refusal, recovery and a second client.
- Acknowledgement waiting must allow the authoritative windup plus the response time. A premature local timeout must not permanently suppress a later confirmed action.
- Keep damage authority separate from motion.

Check `Workspace.AuthorityMode` before you assume that local Animator playback replicates.
Under server authority, follow the synchronized animation route. After a rollback, query the live tracks. Do not keep cached track handles.
A local clip at full time and weight can coexist with no observer motion.
Before you declare replication complete, inspect the server tracks, the observer tracks and the actual joint movement.

## Source authority

The server owns the consequences. Clients send validated intents and render projections.
The project docs name the exact source-to-place build and the verification route.
An old green receipt proves only its bound bytes and destination.
