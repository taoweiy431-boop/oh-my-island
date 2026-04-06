# Session Title Support Design

## Goal

Make expanded session cards show real session titles without abandoning the existing project-first header structure. Codex sessions should read user-assigned titles from Codex's local session index, and the design should leave a clear extension point for future providers such as Claude Code.

## Problem Summary

Today the card header uses the session display name derived from `cwd`'s last path component. This works as a rough project label, but it breaks down when a user opens multiple sessions in the same repository. In that case every card shows the same title and the UI falls back to a short session ID suffix such as `#019d`, which is useful for debugging but not useful as a primary label.

Codex already persists user-defined session titles in `~/.codex/session_index.jsonl` under `thread_name`, but CodeIsland does not currently read that file.

## Desired UX

### Card Header

- Keep the current single-line, project-first structure.
- The header should read as `project #session-label · #short-id` when a provider title exists.
- If no provider session title exists, collapse to `project #short-id` without rendering an empty separator or duplicating the short ID.
- Do not add an extra line just to show the title.
- Project/path context remains the leading label, preserving the original information architecture.

### Session ID

- A short session ID remains visibly present in the header.
- The short ID should appear as its own compact segment after the session label, separated by a light divider such as `·`.
- A copy affordance should live immediately next to the short ID so it is clear that the control copies the full session ID rather than the session title.
- The UI may continue showing a compact short ID such as `#beaf`, while the copy action and tooltip expose the full session ID.

### Consistency

- The UI should not special-case Codex inside the view layer.
- Session cards should consume a provider-agnostic session-title model and compose it into the existing header shape.

## Design Options Considered

### Option 1: Codex-only patch

Add a Codex title lookup directly in the card view and replace `#019d` with `thread_name`.

Pros:

- Fastest path.

Cons:

- Hard-codes provider logic in UI.
- Makes Claude and other providers harder to add later.
- Leaves naming rules spread across multiple files.

### Option 2: Provider-agnostic session title layer

Add a session-title abstraction in the model/state layer. Providers populate an optional `sessionTitle`, and UI composes that with the existing project label and short-ID helpers.

Pros:

- Cleanest long-term structure.
- Codex support lands now without blocking future Claude support.
- Keeps fallback rules centralized.

Cons:

- Slightly more code than a one-off patch.

### Option 3: Standalone title index watcher

Build a dedicated background service that watches provider title stores and continuously updates sessions.

Pros:

- Most flexible long term.

Cons:

- Too heavy for the current scope.
- Adds lifecycle and synchronization complexity before it is needed.

## Recommendation

Use Option 2.

It solves the immediate Codex problem while creating a clean seam for future providers. It also supports the conservative UI direction: preserve the original project-first line, add the provider title into the existing suffix area, and keep the short ID plus copy affordance visibly tied together.

## Proposed Architecture

### 1. Session title fields in shared state

Extend the session snapshot model with provider-agnostic title fields:

- `sessionTitle: String?`
  The best title sourced from the provider, if any.
- `sessionTitleSource: SessionTitleSource?`
  Optional enum to track where the title came from.

Add computed display helpers oriented around the existing header layout:

- `projectDisplayName`
  Keeps the current folder-derived naming behavior for the leading header label.
- `sessionLabel`
  Returns the provider title when present and non-empty, otherwise `nil`.
- `shortSessionID`
  Returns the compact inline ID token used in the header.

This separates "which project is this session attached to?" from "does this session have a user-facing title?" and "which ID token should the header expose for copying/debugging?"

### 2. Provider title resolver layer

Introduce a lightweight title resolver path in app state:

- `SessionTitleResolver` protocol or a small static helper namespace
- provider-specific lookup entry points, starting with Codex

The first provider implementation:

- `CodexSessionTitleStore`
  Reads `~/.codex/session_index.jsonl`
  maps session ID -> `thread_name`
  returns the latest matching title

This can start as on-demand file reads during discovery/event handling rather than a live file watcher. A watcher can be added later if needed.

### 3. Integration points

Codex titles should be applied in two places:

- During Codex session discovery, when a `SessionSnapshot` is first created from transcript files.
- During Codex event handling for known sessions, so a newly assigned title can be picked up after the session already exists.

The lookup should be cheap and isolated. If the index file is missing, malformed, or the session ID has no entry, the app should simply leave `sessionTitle` empty.

### 4. UI changes

Update the session card header to use:

- leading project label: current project/folder-derived name
- optional inline session label: `#session-title`
- inline short ID segment: `#beaf`-style token
- inline copy affordance beside the short ID

The new header behavior should be:

- title present: `project #session-label · #beaf [copy]`
- title absent: `project #beaf [copy]`

Additional UI rules:

- keep the layout on one line in both expanded and collapsed representations where space allows
- remove the extra title line introduced by the more aggressive title-first experiment
- preserve the existing project-first visual rhythm rather than replacing it with a session-title-first layout
- allow copying the full session ID from the copy affordance even though only the short token is shown inline

## Data Flow

### Codex

1. CodeIsland discovers or updates a Codex session.
2. It extracts the Codex session ID as it does today.
3. It queries the Codex title store using that session ID.
4. If a `thread_name` exists, it stores it in `sessionTitle`.
5. The card view renders `projectDisplayName` first, then inserts `#session-label` when available.
6. The short session ID and copy affordance remain visible for copy/debugging.

### Future providers

Each provider can later add its own resolver without changing card rendering rules.

## Error Handling

- Missing `~/.codex/session_index.jsonl`: no title, no error surfaced to user.
- Malformed JSON lines: skip bad lines, continue scanning.
- Duplicate entries for the same session ID: use the newest matching entry.
- Empty or whitespace-only titles: treat as no title.
- Very long titles: truncate inline without pushing the short ID and copy affordance off-screen when avoidable.

## Testing Strategy

### Unit-level behavior

Add focused tests for:

- parsing `session_index.jsonl`
- selecting the latest `thread_name` for a matching session ID
- ignoring malformed lines
- ignoring blank titles
- fallback behavior when no title exists

### Model/UI behavior

Add tests for display helpers:

- title present -> header renders `project #title · #short-id`
- title absent -> header renders `project #short-id` with no duplicate separator
- copy affordance remains visually associated with the short ID
- project display name remains the leading header label

### Manual verification

Verify in a live Codex setup:

- named Codex sessions display as `project #session-label · #short-id`
- unnamed Codex sessions display as `project #short-id`
- the copy icon is read as belonging to the ID, not the title
- project/folder context is still visible first
- session-ID control copies the full ID

## Non-goals

- Implementing Claude title support in this change
- Building a persistent background watcher for every provider title source
- Redesigning the whole session card layout beyond the title/id area

## Risks

- Codex index format may evolve. Mitigation: keep parser narrow and tolerant.
- Session index may lag behind transcript creation. Mitigation: refresh title lookup during later event handling, not discovery only.
- Very long titles may compete with the short ID for horizontal space. Mitigation: truncate the title segment first and keep the short ID plus copy affordance readable.
- Two inline `#` segments may feel noisy if styled identically. Mitigation: separate title and short ID with a lighter divider and keep the ID styling more compact.

## Implementation Outline

1. Add provider-agnostic title fields and display helpers to session state.
2. Add a Codex title reader for `session_index.jsonl`.
3. Populate Codex session titles during discovery and later updates.
4. Update session card rendering to preserve the project-first header while inserting the optional session title inline.
5. Replace duplicate-only `#019d` behavior with a consistent short-ID segment and copy action.
6. Add tests around Codex title parsing and fallback behavior.
