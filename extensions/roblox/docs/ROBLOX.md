# Roblox operations

Keep the allowed operator, group, places, access scopes and ship destinations in the project.
Use a dedicated operator with the least privilege needed. Reserve owner and recovery accounts for their holders.
Use group ownership for experiences and durable assets. Keep credentials out of source, logs and agent messages.
If Studio needs sign-in, leave recovery to the account holder. On Windows, keep Studio bound to its usual user profile.

## Choose a check

| Claim | Where to check it |
| --- | --- |
| Source builds and pure logic works | Static checks and focused specs |
| Engine calls work | Headless engine with isolated test data |
| A user can complete an interaction | Scripted play on the candidate, using ordinary controls |
| The shipped change works | Played client at the allowed destination, with its running revision confirmed |

For rollback, ship the last accepted revision through the project's usual command. Read back the place, owner, privacy, access and version.

## Studio and source sync

Use one driver per Studio window and one source synchronizer per script tree. Reuse the assigned Edit session.
After a mount change or reconnection, inspect the actual instances and source in that document before starting Play.
A cached module can still contain the previous revision.

For tests with multiple clients, use `StudioTestService` in the assigned session. Match the client count to the claim.
For replicated actions, observe both the actor and another client. Exercise cleanup when a user leaves the experience.
Check that a probe belongs to the current scenario before it ends the session. Stop play with the native controls and preserve the Edit document.

Plugin-context code and experience scripts have separate module caches. Use shared engine state for test hooks.
For required replicated instances, wait for them at the point of use. Check client startup and input in an actual client.

## Captures

Capture the assigned Roblox client window. A Studio automation screenshot can omit world-space labels.
For a label, inspect the original window image and check that its text is readable.
For motion or audio, capture the change over time. Record the candidate, device and input used.
Release held input when the scenario ends.

## Live clients and persistence

- Confirm the place, account and direct-join access before a run. Read the client's own log if admission fails.
- Run one client per test identity at a time. If a session stalls, stop the assigned client normally and reconcile its profile lease before retrying.
- Never test against production DataStores. Use isolated data to exercise leases, session fencing, write order, close and recovery. Read the saved result back.
- Check replicated attribute sizes, store and key limits, instance writes and required dependencies on the actual service. Keep the underlying failure when an engine call refuses.
- Let the server validate requests and own the consequences. Check observer state when claiming an action replicates.

## Assets

Check the exact payload's rights, creator, dependencies and intended consumer before upload.
Inspect imported rigs and geometry for scripts and capabilities. Keep rejected or warned assets and their derivatives quarantined.
Use only the authorized account and destination. Never switch accounts to retry a refusal.
After upload, check the returned ID, ownership, permissions and moderation for the asset and its dependencies.
Keep assets private and off sale by default. Never enable irreversible open use.

For animation, preview the exact clip on its rig. In Edit, use `AnimationClipProvider:RegisterActiveAnimationClip`
with `Animator:StepAnimations` to inspect joint motion. `SerializationService:SerializeInstancesAsync({clip})` preserves native RBXM bytes.
Specify the creator when uploading. Resume status checks on the returned ID after an interruption.
Check `Workspace.AuthorityMode`, then play the equipped action on both clients and observe the joints.
Re-query live tracks after a rollback.

For generated assets, follow the [generation and staging procedure](ROBLOX-GENERATIVE-ASSETS.md).
