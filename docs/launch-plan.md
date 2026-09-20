# From Studio to real playtesting: the plan

A step-by-step guide to getting Squishy Merge onto Roblox, playing it with other
people, and switching the shop on. It's written for someone doing this for the
first time, so every step says **where to click** and **what you should see**.

Roblox moves its menus around. Where a button isn't where this says, look for the
same words nearby, or send a screenshot.

Tick the boxes as you go.

---

## Words you'll meet

| Word | What it means here |
| --- | --- |
| **Experience** | Roblox's name for a game. Squishy Merge will be one experience. |
| **Place** | The actual world inside an experience. We have exactly one. |
| **Universe ID** | The experience's number. Needed by the publish script. |
| **Place ID** | The place's number. It's the one in the game's web address: `roblox.com/games/<placeId>/...` |
| **Creator Hub** | The website where you manage the experience: <https://create.roblox.com/dashboard/creations> |
| **Publish** | Uploading the game so it can be joined on Roblox. |
| **Game pass** | Something bought **once** and kept forever (for example x2 Currency). |
| **Developer product** | Something that can be bought **again and again** (for example a cash pack). |
| **Asset ID** | The number Roblox gives a pass or product. The game needs these to sell them. |
| **DataStore** | Roblox's save storage. Player saves and leaderboards live there. |
| **Rojo** | The tool that moves our code from this repo into Studio. |

---

## Phase 0: Tidy up before anything goes online (about 20 minutes)

- [ ] **0.1 Check the buns in Studio.** Connect Rojo, press **Play**, and walk
  around. Look at a plain unit (Droplet), an animal (Puddle Pup, Squish Cat), a
  pet, and the giant buns in the scenery. If anything looks wrong, take a
  screenshot and fix it now. Fixing it later means publishing again.
- [ ] **0.2 Check the test-only settings** in `src/shared/Settings.luau`:
  - `StudioPasses = {}` should be empty.
  - `StudioGems` and `StudioPlaytimeSpeed` don't need changing. A live server
    ignores both.
- [ ] **0.3 Save the work in git.** Ask Claude to commit it. This gives you a
  point to come back to if something breaks.

---

## Phase 1: Account checks (about 10 minutes, done once)

- [ ] **1.1 Use the same Roblox account you imported the bun with.** The bun's
  meshes belong to that account. An experience owned by a **different** account,
  or by a **group**, may show the buns as invisible. Publish under your own
  account for now. Moving to a group later is possible, but the meshes would
  need re-uploading to the group.
- [ ] **1.2 Turn on 2-step verification** on your Roblox account
  (Roblox website → Settings → Security). Roblox asks for it before letting
  creators do money-related things, and it protects your Robux.
- [ ] **1.3 Be ready to verify.** Roblox may ask for a phone number or ID before
  it lets a game go public or sell things. If it asks, follow its steps. There's
  nothing to change in the game for this.

---

## Phase 2: Make a clean game file (about 5 minutes)

Your Studio test place (`squishytest.rbxl`) has leftovers in it, such as the bun
you imported into Workspace. So we build a **fresh** file straight from the repo
instead.

- [ ] **2.1 Build the file.** Ask Claude to run this, or run it yourself in the
  WSL terminal from the repo folder:
  ```bash
  rojo build default.project.json -o /mnt/c/Users/penno/Downloads/SquishyMerge.rbxl
  ```
  You should see `Built project to ...SquishyMerge.rbxl`.
- [ ] **2.2 Open it.** In Windows File Explorer, go to **Downloads** and
  **double-click `SquishyMerge.rbxl`**. It opens in Studio. Double-clicking
  avoids pasting into Studio's file dialog, which has crashed it before.
- [ ] **2.3 Quick look.** Press **Play** once and check the game starts and the
  buns are there. Then press **Stop**.

---

## Phase 3: Publish for the first time (about 10 minutes)

This creates the experience on Roblox. It starts **private**, so nobody else can
join yet.

- [ ] **3.1** In Studio: **File → Publish to Roblox**.
- [ ] **3.2** Choose **Create new experience**.
  - **Name:** `Squishy Merge` (you can change it later).
  - **Creator:** **you**, not a group (see 1.1).
  - **Genre / devices:** anything sensible. Tick at least Computer and Phone.
- [ ] **3.3** Click **Create**. Wait for the "published" message.
- [ ] **3.4 Turn on saving.** Still in Studio: **File → Experience Settings →
  Security** → switch on **Enable Studio Access to API Services** → **Save**.
  Without this, saves and leaderboards don't work in Studio.
  - ⚠️ From now on, playing in Studio uses the **real** save data, the same
    saves the live game uses. Test in Studio as yourself, and don't worry about
    your own save getting messy. You can reset it later.
- [ ] **3.5 Write down the two numbers.** On Creator Hub
  (<https://create.roblox.com/dashboard/creations>), click the experience.
  - **Universe ID:** on the experience's overview page, the **⋯** menu has
    **Copy Universe ID**. (It's also the number in the Creator Hub web address
    after `/experiences/`.)
  - **Place ID:** **Configure → Places**, then the place. Or open the game's
    Roblox page: the number in `roblox.com/games/<this number>/`.
  - Paste both to Claude.

---

## Phase 4: Settings on Creator Hub (about 10 minutes)

All of these are on Creator Hub, inside the experience. Studio no longer has most
of them.

- [ ] **4.1 Max players.** **Configure → Places** → the place → **Max Players =
  6**. The map has exactly six gardens (`PlotCount` in `Balance.luau`). A 7th
  player would have no garden.
- [ ] **4.2 Experience questionnaire.** **Audience → Maturity & Compliance**
  (the name may differ slightly). Answer honestly. It's a cute merge game: no
  violence, no chat features of our own, and it sells things for Robux. Roblox
  won't let the game be public until this is done.
- [ ] **4.3 Icon and thumbnail.** Optional for private testing, needed before
  going public. **Configure → Basic Info / Places**.
  - **Icon:** a square image, 512×512.
  - **Thumbnail:** a wide image, 1920×1080. A screenshot of the garden works to
    start with.
- [ ] **4.4 Leave it private for now.** **Audience → Access**, playability
  **Private**.

---

## Phase 5: Playtest with other people

Pick one of these, from least to most public.

### 5A. Fake players inside Studio (no one else needed)

Good for checking that six gardens, leaderboards and the hub work with more than
one player.

- [ ] In Studio: **Test** tab → **Clients and Servers** (it may be under
  **Start Test Session**) → choose **2 players** (or more) → **Start**.
- [ ] Several windows open, one per fake player. Check that each gets their own
  garden.
- [ ] Close them all with **Cleanup** / **Stop** when done.

### 5B. Invite specific friends (recommended for the first real test)

- [ ] **5B.1** In **Studio**, with the place open: the **Collaborate** button on
  the right of the top bar. Add each friend and give them **Play** permission
  (not Edit). It is not on the Creator Hub, which only lists who already has
  access, under **Safety → Collaborators**.
- [ ] **5B.2** Send them the link: `https://www.roblox.com/games/<placeId>`.
- [ ] **5B.3** Join together. If a friend can't join, check they were added with
  Play permission, and try again after a few minutes.

### 5C. Friends or connections, or public

- [ ] Only once 5B went well. **Audience → Access**, and pick the widest
  option you're comfortable with. Public needs step 4.2 done, and possibly
  account verification (1.3).

### What to write down while testing

Keep a note (a phone note is fine) of:

- [ ] Anything that **breaks** or looks wrong, and what you were doing.
- [ ] Where people **get bored** or **don't know what to do**.
- [ ] How long until they reach the first animal (Puddle Pup, tier 6).
- [ ] Whether the **weekly race** board fills in. It can only be tested on the
  published game.
- [ ] Whether **progress is still there** after leaving and rejoining.

To see errors from live servers: Creator Hub → experience → **Monitoring →
Error Report** (or **Analytics**), or in-game press **F9** to open the Developer
Console.

---

## Phase 6: Create the shop items

The shop code is finished. It just needs the IDs. Any item whose ID is still `0`
stays hidden, so you can do these a few at a time.

### How to create a game pass

- [ ] Creator Hub → experience → **Monetization → Passes** → **Create a Pass**.
- [ ] **Image:** 512×512. Roblox crops it to a circle, so keep the picture in the
  middle. Placeholder images are fine for testing.
- [ ] **Name** and **Description:** from the table below.
- [ ] Click **Create Pass**. Then open the pass → **Sales** → switch **Item for
  Sale** on → type the **price** → **Save**.
- [ ] Copy its **ID**: the pass's **⋯** menu → **Copy Asset ID**, or the
  number in its web address.

### How to create a developer product

- [ ] Creator Hub → experience → **Monetization → Developer Products** →
  **Create a Developer Product**.
- [ ] **Name**, **Description**, **Price** from the table below. The image is
  optional.
- [ ] Save, then copy its **ID** the same way.

### The eight game passes

Suggested prices are **starting points** for a small test, not advice for a big
launch. You can change a price at any time without touching the code.

| Settings key | Name on Roblox | Description | What the game does | Suggested price |
| --- | --- | --- | --- | --- |
| `DoubleCash` | x2 Goo | Double all the Goo you earn, forever. | Income ×2 | 199 R$ |
| `AutoMerge` | Auto Merge | Matching squishies merge for you while you play. | Merges a pair every 1.5 s | 249 R$ |
| `FastSpawn` | Fast Drops | Squishies drop twice as often, forever. | Drop wait halved | 149 R$ |
| `LuckCharm` | Lucky Forever | The Lucky Charm, always on. | Permanent luck | 149 R$ |
| `AutoCollect` | Auto Collect | Earn full Goo while you're away, for up to a day. | Offline earnings at 100% for 24 h | 99 R$ |
| `CraftSlot` | Second Craft Slot | Run two crafts at the Sparkle Machine at once. | +1 craft slot | 99 R$ |
| `BiggerGarden` | Bigger Garden | 15 more spaces in your garden. | +15 garden spaces | 149 R$ |
| `StarterPack` | Starter Pack | A one-time bundle of Goo, gems and a better squishy. First day only! | 60 min of income (at least 5,000), 150 gems, a unit 3 tiers up | 49 R$ |

### The four developer products

| Settings key | Name on Roblox | Description | What the game does | Suggested price |
| --- | --- | --- | --- | --- |
| `CashSmall` | Goo Pouch | A quick boost of Goo. | 15 min of income (at least 1,000) | 25 R$ |
| `CashLarge` | Goo Barrel | A big boost of Goo. | 2 hours of income (at least 10,000) | 99 R$ |
| `UnitBoost` | Squishy Boost | Get a squishy two tiers above your usual drop. | One unit +2 tiers | 49 R$ |
| `GemPack` | Gem Pack | 120 gems. | +120 gems | 75 R$ |

- [ ] **6.1** Create all twelve, or as many as you want to test first.
- [ ] **6.2** Send Claude the IDs as a list, for example `DoubleCash = 123456789`.
  Claude puts them into `GamePasses` and `Products` in
  `src/shared/Settings.luau`.
- [ ] **6.3** Publish the update (Phase 7).

### Testing purchases without spending Robux

- [ ] In Studio, press **Play** and buy from the shop. Studio shows a **test
  purchase** message and charges nothing, but the game still reacts as if you
  bought it. Test every item here first.
- [ ] Check each one did what the table says, and that game passes are still
  owned after stopping and playing again.
- [ ] On the real game, buying your own items **costs real Robux**. Only do it
  once you're happy in Studio.

Roblox takes a cut of every sale. The rest arrives as Robux on your account,
usually after a holding period of a few days.

---

## Phase 7: Publishing updates after the first time

Two ways. Use **A** until you're comfortable, then switch to **B**, which is one
command.

### A. Through Studio

- [ ] Repeat **Phase 2** to build a fresh `SquishyMerge.rbxl` and double-click
  it.
- [ ] **File → Publish to Roblox As** → pick the **existing** Squishy Merge
  experience → its place → **Overwrite**.
- [ ] Players in old servers keep the old version until they rejoin. Creator Hub
  → experience → **⋯ → Restart Servers** moves everyone onto the new one.

### B. One command, no Studio (`scripts/publish.sh`)

Set up once:

- [ ] **B.1** Go to <https://create.roblox.com/dashboard/credentials> →
  **Create API Key**.
  - **Name:** `squishy-publish`.
  - **Access Permissions:** add the API system **universe-places**, select the
    Squishy Merge experience, and tick **Write**.
  - **Security → IP addresses:** add `0.0.0.0/0` (the key works from any
    address). Keep the key secret.
  - **Expiration:** 90 days is a sensible choice. You'll make a new one when it
    runs out.
  - Click **Save & Generate Key**, and **copy the key immediately**. Roblox
    shows it only once.
- [ ] **B.2** Ask Claude to create `.env` from `.env.example` with the key, the
  Universe ID and the Place ID. `.env` is never committed to git.

Then every update is:

```bash
./scripts/publish.sh --live
```

- `--live` is the one players can join. Even a private game needs `--live` for
  testers to see the change.
- `--save` stores a version without letting anyone play it. It's only useful as a
  backup.

---

## Phase 8: Before going public (a checklist for later)

- [ ] Two or three private playtests done, and the notes from Phase 5 acted on.
- [ ] Nothing in the Error Report that happens every session.
- [ ] Every shop item tested in Studio and at least one bought for real.
- [ ] `DataStoreName` in `Settings.luau` is final. **Changing it after launch wipes
  everyone's save.**
- [ ] Icon, thumbnail and description look good.
- [ ] Maturity questionnaire done.
- [ ] **Audience → Access → Public.**

---

## If something goes wrong

| What you see | Most likely cause | What to do |
| --- | --- | --- |
| Buns are invisible, units are blobs | Meshes not allowed for this experience, or experience owned by a group | Check 1.1. Look in Output or F9 for "not found" or asset warnings, and send Claude the text. |
| Progress doesn't save in Studio | API access off | Step 3.4 |
| Shop is empty on the live game | IDs still `0`, or update not published | Phase 6.2, then Phase 7 |
| A friend can't join | Private game without Play permission | Step 5B.1 |
| A 7th player has no garden | Max players above 6 | Step 4.1 |
| `publish.sh` says HTTP 401 or 403 | Key wrong, expired, missing Write, or IP not allowed | Redo B.1 |
| Studio crashes in a file dialog | Pasting into the dialog | Browse or double-click instead |
