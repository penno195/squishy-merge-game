# Roadmap

**Where things stand (2026-09-14).** Batches 1 and 2 are both done. None of
batch 2 has been played yet, and it's the batch that most needs it: quests, the
playtime ladder and the weekly race are all things that only show themselves
over time. Next session is a playthrough, not a build.

Two of the three can't be checked by sitting down for ten minutes, so there are
knobs for it: `Settings.StudioPlaytimeSpeed` runs the playtime ladder twenty
times faster in Studio. The weekly race has no equivalent — its board is keyed
on the real week number, and the only honest way to see a payout is to set a
player's `Weekly.PaidWeek` back by hand in a Studio session and rejoin.

Batch 3 is monetisation, and it's the first batch that can't be finished from
here: every item is a gamepass or product ID, and this place has never been
published, so `Settings.GamePasses` and `Settings.Products` are all still `0`.
Publishing it is the blocker to start on.

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

Small and mostly independent — each is a Settings ID plus a shop entry — so
they're done together.

- [ ] Starter pack (one-time, time-limited)
- [ ] Second craft slot
- [ ] Luck pass (permanent lucky charm)
- [ ] Auto-collect pass
- [ ] Bigger garden (beyond what the cash upgrade reaches)

## Batch 4 — Pets

- [ ] **Pets.** Pet list in theme data, eggs and hatching, equipping, effects
      (auto-collect, auto-merge, income), and the UI for all of it. The biggest
      single system on the list; it gets its own batch and its own testing pass.

## Batch 5 — Polish for launch

- [ ] **Codes.** Redeemable codes.
- [ ] **Events.** Limited-time theme overlay and an event-only sparkle that
      can't be crafted afterwards. Needs variants and the overlay.
- [ ] **Onboarding.** A forced first drop, first merge and first income
      callout. Deliberately last, so it teaches the finished game — but it
      moves to the front of whichever batch turns out to be the last one before
      launch.
