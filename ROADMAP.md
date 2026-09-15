# Roadmap

**Where things stand (2026-09-15).** Batches 1, 2 and 3 are built. Batch 3's
behaviour is all there and testable; its *prices* are not, because the IDs are
still `0`.

Batch 2 has still never been played, and it's the batch that most needs it:
quests and the playtime ladder only show themselves over time. The playtime
ladder has a knob for that — `Settings.StudioPlaytimeSpeed` runs it twenty times
faster in Studio.

**The weekly race cannot be tested in this place at all.** Both of its boards are
OrderedDataStores, which are unreachable until the experience is published, so
`readWeek` comes back with nothing and the column stays empty. Setting
`Weekly.PaidWeek` back by hand, which this file used to suggest, does not get
round that — there is no board to have placed on. (ProfileStore does fall back to
a mock store, so everything *else* works in Studio; it just doesn't persist
between sessions.)

Batch 3 turned out not to need publishing to build after all. The `id ~= 0` check
was already threaded through `PassService`, `ProductService` and the shop panel,
so all five items are written with their IDs at `0`: the effects are live and
testable in Studio right now, and the only thing publishing adds is the ability to
charge for them. What is left is to create eight passes and four products in
Studio and paste the IDs into `src/shared/Settings.luau`.

`tests/README.md` explains how to run the headless checks — worth doing before
and after any change to the shared modules.

Planned work, in dependency order. Each batch is meant to be synced to Studio
and played before the next one starts.

Anything added here has to keep the reskin promise: new content is **theme
data**, new behaviour is **shared code**. If a feature can only be expressed by
editing `src/server` or `src/client` per game, it's designed wrong.

## Batch 1 — Foundations

Groundwork the rest of the list is built on. Only one of the three is visible
to a player.

- [x] **Analytics.** An `AnalyticsService` plus event taps on the verbs the
      game already has (drop, merge, buy, sell, upgrade, craft, spin, rebirth,
      purchase). First on the list so every later feature reports for free, and
      so the question "where do first sessions end?" has an answer before
      there's anything to answer it with.
- [x] **Save schema.** One pass over the ProfileStore template adding the
      fields the whole roadmap needs, rather than a migration per feature.
- [x] **Variants.** Golden / rainbow / shiny units: a `Variants` list in the
      theme giving each one a tint or effect, an income multiplier and a roll
      chance, rolled alongside the tier on every drop. Deepest change to the
      core — it touches the item model, the drop roll, income, the collection
      index and the save — so it lands before anything is built on top of the
      item representation.

## Batch 2 — The engagement loop

`Balance.Variants` is worth revisiting once quests exist: a quest that asks for
a variant is a good one, and the current chances were picked to feel right on
drops alone. Variants now also have a sink — the crafting machine — so their
rate is balanced against two demands rather than one.

- [x] **The action bus.** Pulled forward into batch 1: analytics needed the
      same taps quests will, and tapping every verb twice would have been the
      only other way to get there. `ActionService` announces them;
      `StatsService` keeps the lifetime tallies.
- [x] **Claimable-ladder UI.** `ClaimList` — one panel shape for a row of
      claims over the existing `RewardService` bundles, used by the three below.
- [x] **Quests.** Three daily and one weekly, pointed at the verbs the game
      already has.
- [x] **Playtime rewards.** A ladder of claims through a session, on
      `ClaimList`. Session-scoped and never saved: it's a reason to stay for
      another ten minutes, and the daily streak already pays for coming back.
      The session clock is its own rather than the analytics one, so nothing
      else has to depend on a service whose job is to listen.
- [x] **Leaderboard payouts.** A third board — the weekly race, ranking earned
      since the player's week turned over — with gems for last week's top
      finishers. The two lifetime boards were the wrong thing to pay out on:
      nobody new can climb them, so a prize on one rewards seniority. Each
      week's board is its own OrderedDataStore named for its week, so the reset
      is a rename and last week's standings survive to be paid out on.

## Batch 3 — Monetisation

Done. Not small, in the end: two of the five changed the save schema, and one
changed what the word "slot" means. See "What Robux buys" in the README.

- [x] **Starter pack** (one-time, time-limited). A gamepass rather than a
      product, because Roblox won't sell a pass twice and that is what "one-time"
      has to mean. Offered for `StarterPack.Hours` from `FirstJoin`; granted from
      ownership on every join, gated by `StarterClaimed`, so a purchase that
      landed on a dying server is still honoured later.
- [x] **Second craft slot.** A second *craft*, not a fifth input: `data.Craft` is
      a list of `CraftState` now, each with its own load and clock, and the panel
      grew a tab strip that a player without the pass never sees. `Balance.Craft`
      splits into `Slots` (crafts at once) and `Inputs` (units each takes).
- [x] **Luck pass** (permanent lucky charm). Expressed as the `bias` override
      every luck-sensitive `Economy` function already took, so nothing new was
      added to the drop roll. The board and the server both stop selling the
      timed charm to someone who owns it.
- [x] **Auto-collect pass.** Read as offline earnings, since auto-merge already
      plays the moment-to-moment game for you and income is already collected per
      second. Full rate for 24 hours against half for 8; the one-minute minimum
      is deliberately not waived.
- [x] **Bigger garden** (beyond what the cash upgrade reaches). A flat
      `BiggerGardenSpaces` on top of the upgrade rather than extra levels, so it
      is worth the same at level 0 as at level 5.

Two things fell out of building it rather than being asked for. Gamepass sales
were not reported to analytics at all, so `PassPurchased` joins the action bus
(with the price looked up once per pass, since a pass purchase hands the server no
receipt); and `Components.button` gained `setColor`, which the craft tabs need to
show which slot is selected.

## Batch 4 — Pets

- [ ] **Pets.** Pet list in theme data, eggs and hatching, equipping, effects
      (auto-merge, income, and whatever else), and the UI for all of it. The
      biggest single system on the list; it gets its own batch and its own testing
      pass.

      This line used to say "auto-collect" among the effects. Batch 3 has spent
      that name on offline earnings, so a pet that picks units up needs a
      different one — and a pet effect that duplicates a pass is worth avoiding
      anyway.

## Batch 5 — Polish for launch

- [ ] **Codes.** Redeemable codes.
- [ ] **Events.** Limited-time theme overlay and an event-only sparkle that
      can't be crafted afterwards. Needs variants and the overlay.
- [ ] **Onboarding.** A forced first drop, first merge and first income
      callout. Deliberately last, so it teaches the finished game — but it
      moves to the front of whichever batch turns out to be the last one before
      launch.
