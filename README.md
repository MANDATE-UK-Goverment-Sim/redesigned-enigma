# New H Election Night — Surprise Election Edition

A fictional 640-seat election-night broadcast package for GitHub Pages, with a control room, live presentation, country-shaped constituency map, prediction desk, exit-poll animation, winner sequence, councils mode and Supabase realtime sync.

All project files are **flat/root-level** for GitHub Pages.

## Files

- `index.html` — live presentation / broadcast output.
- `control.html` — election control room.
- `style.css` — broadcast and control-room styling.
- `data.js` — 16 New H counties, 640 constituencies and 128 councils.
- `core.js` — shared state, tab sync, Supabase realtime and RPC helper.
- `presentation.js` — map, predictions, totals, declarations and overlays.
- `control.js` — control-room logic, including Surprise Mode.
- `supabase.sql` — full database setup and hidden election engine.
- `README.md` — this guide.

## NEW: Surprise Election Night

This edition can run an election where **you do not know the result in advance**.

When you press **Generate Secret Election**, Supabase creates and privately stores all 640 constituency winners. The final winner and undeclared seat winners are not returned to the browser.

The election rules are:

- Conservative, Labour or Liberal Democrats can finish as the overall winner.
- Reform, Green and UIP can win individual constituencies but cannot win the election overall.
- Independent candidates can win seats but are not eligible to be the overall winner.
- The hidden final winner is chosen randomly every time a new secret election is generated.
- The final seat totals are also random, so the winner may have a majority or the result may be closer.
- The **22:00 Exit Poll deliberately has a different leading party from the real hidden winner**. That means the exit poll does not spoil the eventual result.
- `Reveal Random Declaration` asks Supabase for one random hidden seat result.
- Clicking `Reveal` on a particular constituency reveals that seat's locked result without letting you choose the winner.
- The winner control is locked while Surprise Mode is active.
- The election automatically calls a winner only when the declared mathematics makes that party certain to win.

The normal manual/scripted election mode is still available. In manual mode, changing the winner seat target still adds/reassigns constituency declarations as in V3.

## 22:00 Exit Poll

In Surprise Mode you have two options:

1. Press **Reveal 22:00 Exit Poll** manually at 22:00.
2. Tick **Automatically reveal the exit poll when this control room reaches 22:00**.

Automatic reveal uses the clock on the device running `control.html`, so keep the control-room tab open if you want it to fire automatically.

Once revealed, the existing full-screen glass/diamond exit-poll animation appears live on connected presentation pages without a refresh.

## Supabase setup — required for Surprise Mode

If you already used an older New H SQL file, run the **new complete `supabase.sql` again**. It keeps the existing `live_state` system and adds the private surprise-election tables/functions.

1. Open your Supabase project.
2. Go to **SQL Editor**.
3. Open `supabase.sql` from this project.
4. Copy the entire file into the SQL Editor.
5. Press **Run**.
6. Open `control.html` on your GitHub Pages site.
7. Scroll to **Supabase Live Sync**.
8. Enter your Supabase Project URL and anon/public key.
9. Press **Save & Connect**.
10. Scroll to **Surprise Election Night** and press **Generate Secret Election**.

The private tables use RLS and do not grant `SELECT` access to the public anon key. The browser only receives a hidden result when you explicitly reveal that constituency through the RPC function.

Do not inspect the private surprise tables in the Supabase dashboard if you want to preserve the surprise for yourself — as the project owner, the Supabase dashboard can of course see your own database.

## GitHub Pages update

Upload/replace **all files from the ZIP** directly in the root of your existing `redesigned-enigma` repository. Do not place them inside another folder.

Expected repository layout:

```text
index.html
control.html
style.css
data.js
core.js
presentation.js
control.js
supabase.sql
README.md
```

After committing the replacement files, wait for GitHub Pages to redeploy and then hard-refresh both pages with `Ctrl + F5`.

Presentation:

```text
https://mandate-uk-goverment-sim.github.io/redesigned-enigma/
```

Control room:

```text
https://mandate-uk-goverment-sim.github.io/redesigned-enigma/control.html
```

## Existing broadcast features

- 640 fictional constituencies across 16 counties.
- Country/island-shaped live constituency map.
- Party colours update as seats declare.
- Constituency prediction panel keeps the pre-election prediction visible after the real result.
- HOLD / GAIN FROM labels.
- Latest declaration cards and ticker.
- Live seat totals and 321-seat majority line.
- Exit-poll glass/diamond animation with configurable centre card in manual mode.
- Full-screen winner animation.
- 128-council local-election mode.
- Same-device instant syncing with local storage/BroadcastChannel.
- Cross-device/browser realtime syncing with Supabase.

## Security note

The hidden election **results themselves** are protected from normal anon-table reads, but this remains a personal/static GitHub Pages control room: anyone who can access the control room and your public Supabase credentials can invoke the allowed control functions. Keep the control-room URL private for a personal simulation. A public production system should add Supabase Auth and admin-only policies.
