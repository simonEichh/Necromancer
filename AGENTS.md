# Agent instructions

Read `CLAUDE.md` first: it is the project guide (workflow, the user's preferences, architecture, rules, gotchas,
remotes). Detailed docs live in `docs/` (world, models, economy, features, backlog); read the matching file before
working on an area. `Design.md` is the design direction.

- The Roblox Studio MCP is set up for this agent too: test in Studio as `CLAUDE.md` describes (its "Studio MCP tips"
  apply). Scripts are only edited in `src/` (Rojo syncs them), never in Studio.
- When you build or change a feature, update the matching file in `docs/` (and `CLAUDE.md` only if every session
  needs it), so the next session, with any tool, starts from the current state.
