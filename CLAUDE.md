# Deep Dive Tycoon

Roblox game: train oxygen in pools on a pier, dive for fish, sell at a
player-driven market, buy eggs that hatch fish for the aquarium. Product
context: `docs/PROJECT.md`; current scope: `docs/ROADMAP.md`.

## Stack

- Luau, synced into Roblox Studio with **Rojo** (`default.project.json`).
- Tools pinned in `rokit.toml` (Rojo, StyLua, Selene, Lune). Install with
  `rokit install`; binaries live in `~/.rokit/bin`.
- Two dev machines share this repo: a Linux desktop (no Studio) and a Windows
  laptop (Studio + Rojo plugin). On Windows, Studio connects to a local
  `rojo serve`; from Linux it connects over the LAN (see README).
- `.gitattributes` forces LF line endings. Never enable `core.autocrlf` on
  Windows: CRLF makes `stylua --check` fail on every file.

## Commands

```bash
rokit install                      # install pinned tools
lune run tests/run                 # unit tests (pure logic)
stylua . && selene src tests       # format + lint
rojo build -o build/DeepDiveTycoon.rbxl   # build a place file
rojo serve                         # live sync to Studio on this machine (port 34872)
rojo serve --address 0.0.0.0       # same, but reachable over the LAN (Linux -> laptop)
```

Before every commit: `stylua --check . && selene src tests && lune run tests/run && rojo build -o build/DeepDiveTycoon.rbxl`.

Windows notes: the shell is PowerShell 5.1, so chain with `;` instead of `&&`.
Tools live in `%USERPROFILE%\.rokit\bin` and Git in `C:\Program Files\Git\cmd`;
a terminal opened before they were installed needs a restart to see them.
`selene` downloads the Roblox API dump on first run; if it fails with
"error when getting API dump", it is a transient network error: rerun it.

## Layout

| Path | In Studio | What |
| --- | --- | --- |
| `src/shared/Config.luau` | `ReplicatedStorage.Shared.Config` | All balance numbers |
| `src/shared/Logic/*` | `ReplicatedStorage.Shared.Logic` | Pure logic, no Roblox APIs |
| `src/shared/Attributes.luau` | `ReplicatedStorage.Shared.Attributes` | Names of Player attributes (MaxO2, CurrentO2, Coins, Net and Eggs as JSON) |
| `src/shared/Remotes.luau` | `ReplicatedStorage.Shared.Remotes` | Names of RemoteEvents under `ReplicatedStorage.Remotes` |
| `src/shared/RarityColors.luau` | `ReplicatedStorage.Shared.RarityColors` | Rarity → Color3, used by fish models and the market list |
| `src/server/` | `ServerScriptService.Server` (Script) | Server entry + services |
| `src/server/World/MapBuilder.luau` | | Greybox map built at runtime (terrain, island, pools, kiosk, pier, palms) |
| `src/server/World/SeabedBuilder.luau` | | Seeded reef patches composed hero / middle / base like the owner's watercolor references, giant kelp stalks, bubble vents |
| `src/shared/KelpRig.luau` | `ReplicatedStorage.Shared.KelpRig` | Kelp stalk geometry and sway constants, shared by server and client |
| `src/client/World/KelpSway.luau` | | Client-only kelp animation (tag + attributes, BulkMoveTo, distance cull) |
| `src/client/World/UnderwaterFx.luau` | | Client-only underwater grade, blur and marine snow |
| `src/server/World/WreckBuilder.luau` | | Sunken ship on the seabed (ship space + root CFrame, like the kiosk) |
| `src/server/Eggs/EggService.luau` | | Nests on the seabed: egg model, odds label, buy prompt, restock |
| `src/server/Player/` | | `PlayerState` (attributes, net, speed: weight × fins in water), `OxygenService` (drain/refill tick, sets in-water), `PoolService` (MaxO2 training in pools), `Fins` (fin models welded to the feet) |
| `src/server/Fish/` | | `FishBuilder` (one part recipe per species at natural size, `SCALE` applied on output; tail is a Model pivoted on its hinge), `FishService` (spawn, swim, prompt, respawn), `CatchService` (take a fish) |
| `src/server/Market/MarketService.luau` | | `SellCatch` remote: zone + cooldown check, payout |
| `src/client/` | `StarterPlayerScripts.Client` (LocalScript) | UI controllers |
| `src/client/Hud/` | | `DepthHud`, `StatsHud` (O₂ bar, coins, net) |
| `src/client/Market/MarketUi.luau` | | Market panel shown inside `Map.Market.SellZone` |
| `tests/` | not synced | Lune specs for `src/shared` |

## Conventions

- `--!strict` at the top of every file; tabs; StyLua formatting.
- Server is authoritative for oxygen, fish, coins, market. Clients send
  intents through Remotes; server validates (distance, rate limit).
- Server → client display state goes through Player attributes named in
  `shared/Attributes`; the HUD listens to `GetAttributeChangedSignal`. Tables
  (the net) travel as JSON strings.
- Interactions with world objects (fish) use `ProximityPrompt`: its distance
  check runs on the server, so no extra Remote is needed. Remotes are for
  UI buttons (`SellCatch`) and get a cooldown plus a zone/distance check.
- Area checks (pools, sell zone) convert the position to the part's object
  space and call the pure `Logic/Bounds.contains`.
- Prototype world: one zone (Lagoon, `World.oceanFloorMeters` = 50 m deep)
  and two species. Each zone with fish has a `spawn` ring (radii + the seabed
  under it); fish, seabed props and nests all derive their positions from
  those rings, never from hard-coded radii. Adding a zone = adding a `Zones`
  entry with a ring and a `FishBuilder` recipe per new species.
- Scenery scale: a Roblox character is ~5 studs ≈ 1.7 m at
  `World.studsPerMeter` = 3. Seabed props and the wreck are written in real
  meters and converted with that constant, so they match the player; corals
  are built at real colony sizes and each reef patch is then scaled ×1.3–1.7
  (`PATCH_SCALE`, owner wants them taller), kelp 22–42 m (capped 2 m
  below the surface). Fish are the
  exception: `FishBuilder.SCALE` = 2 on purpose (owner's call), for
  readability.
- Decorative motion runs on the client: the server builds the parts, tags
  the model and stores what the client needs as attributes; a client module
  poses them (see kelp). Never animate decor from the server.
- Terrain is smoothed on a 4-stud grid: anything built flush with the island
  top sinks into the sand. Keep walkable props ≥ 3 studs above
  `Config.World.islandTopY` (see `POOL_LIFT` / `MARKET_LIFT` in `MapBuilder`).
- Island layout: sand beach, spawn at the origin facing -Z, pools in front
  (-Z), market kiosk on a plinth to the right (-X) facing the spawn, pier off
  to +X, palms in a seeded ring near the shore with a gap toward the pier.
  Climbing uses `TrussPart` ladders; text on props uses `addSign` (SurfaceGui).
- Modules in `src/shared/Logic` must not touch Roblox APIs or `require`
  other modules — callers pass data in. This keeps them runnable in Lune.
- In Roblox code, require by instance (`require(script.World.MapBuilder)`),
  not by string path.
- Every balance number goes into `Config`, never inline.
- New logic in `Logic/` comes with a spec in `tests/` and is registered in
  `tests/run.luau`.
- Balance rules from `docs/PROJECT.md` are hard constraints (e.g. diving
  must out-earn the aquarium).

## Verification limits

Lint, tests and `rojo build` verify code on either machine. Gameplay is
verified only in Studio, which exists on the Windows laptop: run
`rojo serve`, connect the Rojo plugin to `localhost:34872`, press Play and
check Output. On Linux there is no Studio. Say which verification was done.
