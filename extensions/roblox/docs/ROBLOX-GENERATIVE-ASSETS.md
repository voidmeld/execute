# Generative asset production

This page owns the workflow from generation to consumer. [ROBLOX.md](ROBLOX.md) owns the account, destination
and general asset rules.

## Production line

These steps form one line:

1. a conditioned reference
2. generated geometry
3. a safe, group-owned durable asset
4. source integration
5. runtime composition
6. a played experience

Assets without a real consumer do not establish progress. Use reusable families for environments, structures,
props, gear, avatars and creatures. Name the game consumer before generation starts.

Image conditioning helps control shape and design. Record the prompt, the conditioning inputs, the tool or
provider, the output hash, the creator, the rights, the review and every transformation. If generation capacity
is low, pause new generation only. Continue with accepted references and other assigned work.

## Candidate discipline

- Before you generate, define the family, the tier, the consumer, the silhouette and function requirements, and the safety class.
- Use one candidate to test one distinct idea.
- Never retry a warned or rejected hash. Do not conceal a derivative's source.
- Before upload, inspect topology, scale, materials, scripts or capabilities, body and deformation risk, and moderation exposure.
- For humanlike, body-bearing, deforming or uncertain payloads, use the strongest coverage and the review requirements declared by OWNER. If the risk is uncertain, use the higher risk tier.
- Upload only under exact authority. Read back group ownership, privacy and moderation. Prove the durable ID in the intended runtime consumer.

## Temporary staging

Keep the original staged candidate until its content is durably retained and read back. A place file can keep an
Instance shell without its Opaque mesh or texture. Save an approved candidate as a durable asset through the
existing upload route of the project. If that route requires them, keep the exact export bytes. A prompt and
conditioning inputs record the source. Regeneration produces a new candidate. It does not restore the original.
Do not restart an editor that holds unretained work, unless you accept the loss.

If generation outlasts an automation call, use the completion or status route of the native job. Bound image and
geometry reads to the execution limits of the tool. A timeout can leave native work unresolved. `pcall` cannot
cancel a call that never returns. Diagnose and reconcile that attempt before you retry.

Keep the generation origin clear. Move results and reference rigs to named staging areas, so that overlapping
objects are not mistaken for defects. Inspect a candidate in clear space before you alter it.

## Repeated create calls and the creator field

- Before you create a durable asset, check the durable marker attribute for the exact artifact. For a map set, check each map separately.
- Reconcile an existing marker with the operation record before another attempt.
- After a successful create, record its IDs. If you repeat a create call without checking its result, you can produce unused assets.
- Name the creator explicitly on the first attempt. If you omit the creator fields, the API uses the editor session's user as creator. It gives no failure or warning. It does not use the place's group.
- Before an unfamiliar create call, read the current API signature. Do not make a live change to test parameters. Follow the [external-action procedure](../../../docs/PLAYBOOK.md#external-actions).

## Acceptance

These are separate claims: technical validity, safety and rights, visual quality, source integration, runtime
composition and played experience. Owner taste acceptance settles only taste, for the exact artifact that the
Owner observed. Keep quarantine and source-history evidence outside startup. Prevent changes to that evidence.
Link its exact location.
