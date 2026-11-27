# Continuous quality loop

Use this loop to keep workers improving a product around the clock, including when the owner has nothing
queued. The owner sets direction and judges taste. The CEO keeps the queue full, lands results and verifies
them where users run the product. Workers run lanes.

## Order of work

1. **Owner items.** Take the highest open owner item first. Owner feedback overrides CEO design calls.
2. **Weakest area.** Otherwise take the weakest area from the latest refill findings. Rank by what users
   meet first.
3. **Alternate with simplification.** Every other lane removes code: deletions, folds, generated files built
   instead of committed, and generic parts moved into shared libraries.

## Lane shapes

- **QA lane.** Up to three hours. The worker uses the product as a user would, fixes what it finds and
  commits each fix as soon as its checks pass. QA lanes have design latitude within owner decisions.
- **Fix lane.** One defect, at most one hour.
- **Simplification lane.** One target with behavior preserved and net lines removed reported.

Each fix ships with the check that would have caught it. A worker that hits its cap stops and hands off its
committed work.

## Refill

When the queue runs low, refill it from three independent inputs. Workers run all three. The CEO does not
review in its own context, so its attention stays on landing and judgment.

1. **Output review.** A read-only worker reviews recent captures or outputs against the project's quality bar
   and ranks the ten weakest user-visible areas with evidence paths.
2. **Codebase review.** A read-only worker measures size by area, growth, committed generated files,
   duplication, dead code and extraction candidates, and ranks the highest-yield simplifications.
3. **Feature playthrough.** A worker uses every feature on the [feature map](../FEATURES.template.md) end to
   end, records whether it was reachable and worked and the worst thing an expert user would notice, fixes
   only blockers and ranks features worst first.

The CEO turns the merged rankings into queued lane briefs, each naming the problem, its evidence and what
done looks like.

## Capacity

Measure the host before raising concurrency: memory pressure, swap and load average under the current lanes.
Set the slot count for heavy lanes, such as those that open an editor or a client, at the measured ceiling
and record the reason. Run light lanes beside them. A slow, swapping host costs more than one fewer lane,
because shared checks time out during integration.

## Landing discipline

- Land each lane as soon as it reports. A finished lane that sits unlanded is lost throughput.
- Watch reports by change, not by first sight, so a rewritten report is noticed.
- Make no direct pushes to the trunk while a landing runs; queue them behind it.
- After resolving a merge conflict, run the checks that each side's change relied on.
- Leave no litter. The [lane tick](api.md#laneshygiene) removes clean, idle lanes whose work reached
  trunk and reports idle unlanded work on every pass. Land or explicitly discard each `UNLANDED`
  finding within the same watch cycle. Review stray worktrees, unattached branches and remote branches.
- After every release, verify the change where users run it before reporting it.
