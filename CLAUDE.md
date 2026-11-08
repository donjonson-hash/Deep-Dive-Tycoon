# Deep Dive Tycoon

Roblox game: train oxygen in pools on a pier, dive for fish, sell at a
player-driven market, buy eggs that hatch fish for the aquarium. Product
context: `docs/PROJECT.md`; current scope: `docs/ROADMAP.md`.

## Stack

- Luau, synced into Roblox Studio with **Rojo** (`default.project.json`).
- Tools pinned in `rokit.toml` (Rojo, StyLua, Selene, Lune). Install with
  `rokit install`; binaries live in `~/.rokit/bin`.
- Code is written on Linux; Studio runs on a separate Windows laptop and
  connects to `rojo serve` over the LAN (see README).

## Commands

```bash
rokit install                      # install pinned tools
lune run tests/run                 # unit tests (pure logic)
stylua . && selene src tests       # format + lint
rojo build -o build/DeepDiveTycoon.rbxl   # build a place file
rojo serve --address 0.0.0.0       # live sync to Studio on the LAN (port 34872)
```

Before every commit: `stylua --check . && selene src tests && lune run tests/run && rojo build -o build/DeepDiveTycoon.rbxl`.

## Layout

| Path | In Studio | What |
| --- | --- | --- |
| `src/shared/Config.luau` | `ReplicatedStorage.Shared.Config` | All balance numbers |
| `src/shared/Logic/*` | `ReplicatedStorage.Shared.Logic` | Pure logic, no Roblox APIs |
| `src/server/` | `ServerScriptService.Server` (Script) | Server entry + services |
| `src/server/World/MapBuilder.luau` | | Greybox map built at runtime |
| `src/client/` | `StarterPlayerScripts.Client` (LocalScript) | UI controllers |
| `tests/` | not synced | Lune specs for `src/shared` |

## Conventions

- `--!strict` at the top of every file; tabs; StyLua formatting.
- Server is authoritative for oxygen, fish, coins, market. Clients send
  intents through Remotes; server validates (distance, rate limit).
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

Studio does not run on this Linux machine. Lint, tests and `rojo build`
verify code here; gameplay is verified by the owner in Studio on the
Windows laptop. Say which one was done.
