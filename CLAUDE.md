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
| `src/shared/Attributes.luau` | `ReplicatedStorage.Shared.Attributes` | Names of Player attributes (MaxO2, CurrentO2, Coins) |
| `src/server/` | `ServerScriptService.Server` (Script) | Server entry + services |
| `src/server/World/MapBuilder.luau` | | Greybox map built at runtime |
| `src/server/Player/` | | `PlayerState` (attributes), `OxygenService` (drain/refill tick), `PoolService` (MaxO2 training in pools) |
| `src/server/Fish/` | | `FishBuilder` (greybox model), `FishService` (spawn + swim) |
| `src/client/` | `StarterPlayerScripts.Client` (LocalScript) | UI controllers |
| `src/client/Hud/` | | `DepthHud`, `StatsHud` (O₂ bar + coins) |
| `tests/` | not synced | Lune specs for `src/shared` |

## Conventions

- `--!strict` at the top of every file; tabs; StyLua formatting.
- Server is authoritative for oxygen, fish, coins, market. Clients send
  intents through Remotes; server validates (distance, rate limit).
- Server → client display state goes through Player attributes named in
  `shared/Attributes`; the HUD listens to `GetAttributeChangedSignal`.
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
