# Roblox operations

This page owns the Roblox operating rules. [INTEGRATION](../INTEGRATION.md) lists the values that the adopter
must supply. Keep exact IDs and commands in the project. For generation work, read [generative
assets](ROBLOX-GENERATIVE-ASSETS.md).

## Account and destination

- One Studio operator with minimum permissions makes all changes. Do not use Owner or recovery accounts for automation.
- Group accounts own experiences and durable assets.
- Before a change, bind the operator, creator, owner, destination, access and expected source. Read those bindings back.
- After a warning or a rejection, never switch accounts.
- Credentials, cookies, keys, account changes and payment data are Owner-only. They never enter Git, logs, chat or the context of a bounded task.

## Verification ladder

1. **Static and spec:** source, types, contracts and deterministic builds.
2. **Headless engine:** APIs and engine behavior on an isolated test place.
3. **Scenario play:** a scripted journey with captures, under the exact identity of the built source.
4. **Played destination:** the published client journey and the accountable CEO's artifact verdict, with any review required by OWNER.

A lower tier cannot prove a higher tier's claim. Publication is complete only when you read back the source
identity, owner, privacy, moderation, access and destination bytes. Do not use a failed build as a rollback
target. For rollback, publish the last accepted source through the same gate and readback.

## Studio and persistence

### Source sync

- Keep one source-sync owner for each script tree.
- With Rojo, keep the configured server, project and place binding. Use the saved endpoint of the plugin and its automatic reconnect where supported.
- A normal script edit needs no binary place build and no new Studio.
- After a mount change or reconnection, verify affected instances and source in the intended document. Then start a fresh Play.
- Read the current source identity directly. Do not trust a cached module or an earlier build receipt.
- Native [Script Sync](https://create.roblox.com/docs/scripting/sync) is another option for script and folder editing. It does not synchronize every Instance property, attribute or tag.
- Before migration, exercise the project's shared mounts, script classes, run contexts and non-script content.
- Test the real authoring loop and the conflict recovery. Remove the displaced setup only after the new route works.
- Do not add a second synchronizer to hide a layout mismatch. Keep project commands in the project.

### Local multiplayer

- Reuse the assigned Edit document and the `StudioTestService` launch and end flow of Roblox.
- After source sync, load current launcher code and identity. Edit's `require` cache can retain an earlier revision.
- Keep any installed toolbar independent of the game commit. Then a game edit does not require a plugin reinstallation.
- Bind results to the actual run, source and participating clients. An installer receipt does not prove what those clients played.
- Stop through the native test controls and verify cleanup. Keep the source Studio.
- A readiness check proves startup only. Observe the relevant interaction and durability separately.
- Keep exploratory sessions usable without registering a new scenario.
- Before a server probe validates or ends a session, it must check that the launch arguments belong to its scenario. An unrelated probe must not end a manual test.
- Read the mounted identity after source generation. Generation can finish before live sync delivers its changes.

### Population and client startup

Choose the population by the claim:

- two clients for actor and observer behavior
- a small group for shared activity and rewards
- up to eight clients for overlapping activity and departure cleanup

Do not repeat the largest run for each content edit. After server admission, inspect each client's loaded UI,
input and presentation. Then exercise the interaction. Keep failed cold launches apart from later successful
runs. Distinguish local host load from gameplay or network capacity.

Client startup must tolerate replication order at shared module boundaries.

- For a required replicated root or module, use native `WaitForChild`. Do not add another loader or retry manager.
- Scope UI subscriptions to the data that they consume. The replicated tree of another player must not rebuild a local list.
- Share expensive derived values through the existing reactive system. Keep the callers' interfaces.
- Test these repairs in actual clients. Pure tests cannot reproduce a missing replicated Instance. They cannot prove visual readiness.

### Captures

Apply the [capture rules](../../interactive-qa/docs/INTERACTIVE-QA.md#captures). The rules below add Roblox
window requirements.

Validate the capture surface against the actual window before you judge world-space UI. A Studio automation
screenshot can omit visible BillboardGui labels. An enabled property does not prove visible text. For
world-space labels and markers, inspect a capture of the exact owned window. Use the existing window source when
it is available. Keep the original image and its source binding. A still image needs no video recording and no
new calibration or receipt pipeline.

### Ownership and persistence

- Assign one driver for each Studio surface under [runtime ownership](../../../docs/PLAYBOOK.md#runtime-ownership).
- Before a save or publication, bind the place and account. Read them back afterward.
- Use native controls where possible. If a UI action fails or is ambiguous, follow the project's bounded recovery procedure.
- Never run destructive operations against production DataStores. Never test on production data.
- For a persistence claim, use an isolated test destination. Require a fail-closed lease, session fencing, ordered writes and bounded close draining. Observe recovery. Read the exact result back.

### Plugin context

Plugin-context execution, such as an automation bridge or a plugin console, has its own module cache.
Module-level state that you set there is invisible to game scripts. Use engine state, such as an attribute, for
a testing hook. Do not use a module flag. Capability-restricted input APIs are unavailable from that context.
Use the public virtual-input interface that the shipped client also uses. Capture only the application window
region. Do not capture the desktop.

## Live client runs

The [interactive QA rules](../../interactive-qa/docs/INTERACTIVE-QA.md#evidence-for-an-experience-claim) define
the evidence record for a played client. The published client verifies destination behavior. Follow [runtime
ownership](../../../docs/PLAYBOOK.md#runtime-ownership) and use the isolated test data of the adopter.

- Run one played client at a time. Concurrent runs with one identity can conflict over a profile lease. Before another attempt, stop the prior run. Confirm cleanup.
- After a restart, reset or replace the test scope through the authorized project route. A stale character or session can block admission. A restart grants no publication and no mutation retry.
- Before the first run against a new place, verify direct-join access.
- If admission stops progressing, stop the assigned client normally. Reconcile its lease before another attempt. Forced termination needs the project's cleanup grant.
- Keep the assigned window active. Diagnose host throttling separately from gameplay failure. Change OS settings only through an authorized route.
- Read the log of the client. Send the client's verdict data on a channel that it receives.

## Live admission checks

Check the live boundaries that source tests and local fixtures cannot prove:

| Boundary | Verify |
| --- | --- |
| Loading and routing | Module and remote return shapes, required dependencies and the actual outcome API. |
| Replicated data | Attribute values and encoded string sizes against current platform limits. |
| Persistence | Store names and key sizes against platform limits, using an isolated real service. |
| Instance writes | Scriptability, mesh and collision writes and native create return values. |
| Failure reporting | Preserve the underlying reason through `pcall`. Return a named refusal instead of an anonymous timeout. |

Close a publication packet only after a real client journey. Test the actual modules and platform resources. A
hand-written fake cannot prove service admission.

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

Marketplace payloads are geometry and rigs only. Inspect them for scripts and capabilities before they enter the
shipped Workspace.

Generation, upload, access change, place save and publication are external mutations.

1. Bind the exact payload and destination.
2. Apply the review and rights requirements declared by OWNER for this exact payload.
3. Perform one authorized act.
4. Read back ownership, privacy and moderation.

Do not enable irreversible open use. Check the prior result before another attempt. Do not reuse a rejected or
warned payload or derivative. Assets stay private, restricted and off-sale by default. A privacy change does not
prove prior access. Read every destination and dependency again. A parent receipt grants no rights to
dependencies. Check ownership, permission, moderation and access for each dependency.

### Authored animation

Before you adopt an AnimationClip, preview the selected clip on the actual compatible rig. In Studio Edit,
`AnimationClipProvider:RegisterActiveAnimationClip` with `Animator:StepAnimations` supports a local preview.
Temporary registration can behave differently in split client and server Play. A loaded length alone does not
prove motion. Check advancing time, weight and visible joint direction.

- Studio's `SerializationService:SerializeInstancesAsync({clip})` keeps native RBXM bytes.
- Open Cloud accepts RBXM and RBXMX as Animation with `model/x-rbxm`. Reuse the existing uploader, the explicit creator and the one-attempt journal.
- Check the supported types before you substitute AssetService for animation upload.
- After upload, keep the cloud ID and revision. Resume its status instead of recreating it.
- Prove the cloud clip through equipped public actions, confirmation and refusal, recovery and a second client.
- Allow the authoritative windup and response time when waiting for acknowledgement. An early local timeout must not permanently suppress a later confirmed action.
- Keep damage authority separate from motion.

Check `Workspace.AuthorityMode` before you assume that local Animator playback replicates. Under server
authority, use the synchronized animation route. After rollback, query live tracks. Do not keep cached track
handles. A local clip at full time and weight can coexist with no observer motion. Before you declare
replication complete, inspect the server tracks, the observer tracks and the actual joint movement.

## Source authority

The server owns the consequences. Clients send validated requests and display the results. The project docs name
the exact source-to-place build and the verification route. An earlier passed receipt proves only its bound
bytes and destination.
