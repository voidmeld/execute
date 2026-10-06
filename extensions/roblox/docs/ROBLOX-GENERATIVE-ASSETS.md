# Generative asset production

This page owns the workflow from generation to consumer.
[ROBLOX.md](ROBLOX.md) owns the account, destination and general asset rules.

## Production line

These steps form one line:

1. a conditioned reference
2. generated geometry
3. a safe, group-owned durable asset
4. source integration
5. runtime composition
6. a played experience

Inventory without a real consumer is not progress.
Favor reusable families of environment, structure, prop, gear, avatar and creature. Name the in-game consumer before generation starts.

Image conditioning improves the control of shape and design.
Record the prompt, the conditioning inputs, the tool or provider, the output hash, the creator, the rights, the review and every transformation.
When generation capacity is scarce, pause only new generation. Continue work with accepted references and in other lanes.

## Candidate discipline

- Before you generate, define the family, the tier, the consumer, the silhouette and function requirements, and the safety class.
- Spend one candidate on one materially distinct hypothesis.
- Never retry a warned or rejected hash. Never disguise a derivative.
- Before upload, inspect topology, scale, materials, scripts or capabilities, body and deformation risk, and moderation exposure.
- For humanlike, body-bearing, deforming or uncertain payloads, use the strongest coverage and the independent-review floor of the project. Uncertainty selects the higher risk tier.
- Upload only under exact authority. Read back group ownership, privacy and moderation. Prove the durable ID in the intended runtime consumer.

## Staging is ephemeral

Keep the original staged candidate until its content is durably retained and read back.
A place file can keep an Instance shell without its Opaque mesh or texture.
Save an approved candidate as a durable asset through the existing upload route of the project. If that route requires them, keep the exact export bytes.
A prompt and conditioning inputs keep the provenance. Regeneration produces a new candidate. It is not a backup of the old one.
Do not restart an editor that holds unretained work, unless you accept the loss.

If generation outlasts an automation call, use the completion or status route of the native job.
Bound image and geometry reads to the execution limits of the tool.
A timeout can leave native work unresolved. `pcall` cannot cancel a call that never returns.
Diagnose and reconcile that attempt before you retry.

Keep the generation origin clear. Move results and reference rigs to named staging areas, so that overlapping objects are not mistaken for defects.
Inspect a candidate in clear space before you alter it.

## Create idempotence and the creator field

- Before you create a durable asset, check the durable marker attribute for the exact artifact. For a map set, check each map separately.
- Reconcile an existing marker with the operation record before another attempt.
- After a successful create, record its IDs. If you run a create again without checking its prior outcome, you can produce orphan assets.
- Name the creator explicitly on the first attempt. If you omit the creator fields, the creation API silently succeeds with the user of the editor session as creator. It does not fail, warn or default to the group of the place.
- Before an unfamiliar create call, read the current API signature. Do not use a live mutation to probe parameters. Follow the [external-action procedure](../../../docs/PLAYBOOK.md#external-actions).

## Acceptance

These are separate claims: technical validity, safety and rights, visual quality, source integration, runtime composition and played experience.
Owner taste acceptance settles only taste, for the exact artifact that the Owner observed.
Keep quarantine and lineage evidence cold, immutable and exactly referenced.
