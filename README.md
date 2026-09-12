# New H Election Night

A complete fictional election-night broadcast package for GitHub Pages.

## What is included

- `index.html` — full-screen presentation / broadcast view.
- `control.html` — control room.
- `style.css` — all broadcast UI, glass/diamond graphics, overlays and responsive layouts.
- `data.js` — 16 fictional counties, 640 constituencies and 128 councils.
- `core.js` — shared state, local tab sync and optional Supabase Realtime sync.
- `presentation.js` — live map, totals, projections, exit poll, winner and council presentation logic.
- `control.js` — control-room interactions.
- `supabase.sql` — one-time database setup for cross-browser/device realtime sync.

Everything is root-level so it can be dropped straight into a GitHub Pages repository.

## Main features

### General Election

- Exactly **640 fictional constituencies** grouped into 16 New H counties.
- Live constituency declaration controls.
- Abstract 640-seat hex/cartogram map that changes party colour as results are declared.
- HOLD / GAIN FROM calculation based on the fictional previous election.
- Live seat totals and a majority marker at **321**.
- Starting prediction for every constituency; undeclared seats feed a live projection.
- Search and county filtering for all 640 seats.
- Latest declaration log and live ticker.
- Undo last result, clear all results and one-click "Declare Next Prediction" for testing.

### Exit Poll

- Party-by-party projected seat editor.
- Auto-fill button that creates a random 640-seat exit poll.
- Full-screen broadcast animation.
- Glassy multi-layer diamond cards with party-colour outer rims, bevels, highlights and very low-opacity diagonal/chevron lines.
- Can be shown or hidden live without refreshing the presentation.

### General Election Winner

- Pick the winning party and number of seats.
- Full-screen animated winner sequence with party-colour light wash and moving grid effects.
- Can be triggered or hidden from the control room.

### Parties

- Conservative, Labour, Liberal Democrats, Reform UK, Green, UIP and Independent are included by default.
- Add more parties from the control room with a custom short code and colour.
- Parties are immediately available in constituency, council, winner and exit-poll controls.

### Councils mode

- One button switches the entire live presentation from General Election to Council Elections.
- 128 fictional councils across the same 16 counties.
- Declare council control as HOLD or GAIN FROM.
- Enter a national net councillor change for each party, including large fictional values if wanted.
- Council control totals, latest results and county-level visual summaries update live.

## Quick GitHub Pages setup

1. Create a new GitHub repository.
2. Upload every file in this project to the **root** of the repository.
3. In GitHub open **Settings → Pages**.
4. Under **Build and deployment**, choose **Deploy from a branch**.
5. Select your main branch and `/ (root)`.
6. Wait for GitHub Pages to publish.
7. Open `index.html` for the presentation and `control.html` for the control room.

Example layout:

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

## Live sync: two levels

### Level 1 — no database

The project automatically uses browser storage plus `BroadcastChannel`. This means:

- control room in one tab;
- presentation in another tab;
- both on the same browser/device;

will update without refreshing.

### Level 2 — separate browsers/devices with Supabase

1. Create a Supabase project.
2. Open **SQL Editor**.
3. Paste and run everything in `supabase.sql` once.
4. Open `control.html`.
5. Scroll to **Supabase Live Sync**.
6. Paste the project URL and anon/public key.
7. Click **Save & Connect**.
8. Put the same URL/key into each browser/device control page once. The setting is stored locally in that browser.

The presentation page automatically uses the saved Supabase configuration on that device and subscribes to realtime database changes.

## Security note

The included SQL deliberately allows anonymous updates to one row so a plain static GitHub Pages control room works with no login. This is suitable for a private/demo election project, but it is not secure enough for a public production control room. If the URL is public, add Supabase Auth and restrict UPDATE/INSERT policies to an authenticated admin account.

## Running locally

A web server is recommended rather than double-clicking the HTML files. From the repository folder:

```bash
python -m http.server 8000
```

Then open:

- Presentation: `http://localhost:8000/`
- Control room: `http://localhost:8000/control.html`

## Broadcast use

For OBS, add the published `index.html` URL as a Browser Source. A 1920×1080 browser source works well. Keep `control.html` open separately.

---

## V3 update — country map, prediction desk and synced winner seats

This package includes the September 2026 V3 changes:

- The 640-seat constituency cartogram is reshaped into a fictional New H country/island silhouette. Every constituency is still an individual live seat.
- A constituency prediction desk now sits beside the map. Before a result it shows the model prediction; after a declaration the declared winner appears at the top, a centre divider marks the result, and the original prediction remains below for comparison.
- Latest declaration cards show the pre-election prediction and flag an upset when the declared winner differs.
- **Random Next Declaration** now selects a random undeclared constituency and simulates a result with the seat prediction weighted most heavily, while still allowing upsets.
- Changing **General Election Winner → Seats won** now synchronises the real constituency declarations. If the target is higher it declares unused seats first and then reassigns seats if necessary. If the target is lower it reassigns excess seats to other parties.
- The presentation UI has a light broadcast-style refresh while keeping the existing visual identity, exit poll and winner animations.

### Updating an existing GitHub Pages repo

All files in this ZIP are root-level. Upload them into the root of the existing `turbo-octo` repository and choose **Replace** when GitHub reports files with the same names. Do not create a second folder around them.

Your Supabase table/schema is unchanged, so you do not need to rerun `supabase.sql` just for this visual/logic update if live sync is already working.
