# Routing, Token and AI Credit Telemetry

## Status: disabled

Routing telemetry is disabled by user request through
`umbrellaRouting.telemetry.enabled: false` in `.ai/agents/agents-role.yaml`.
Do not create, update, reconcile, or backfill manifests, query usage ledgers for telemetry,
or include routing token/AI-credit tables in handoffs while disabled. Preserve existing
records and this protocol; do not delete them. Re-enablement requires an explicit user request.
This does not change application OpenTelemetry or the runtime's own usage accounting.

All instructions below are retained reference material and apply **only when enabled**.

When enabled, the **Cinemas Router** records one local manifest for every request it handles:

```text
.ai/generated/routing-telemetry/<UTC-ts>_<route-id>_<slug>.yaml
```

The directory is gitignored. Telemetry is operational evidence, not repository authority,
application telemetry, or a replacement for OpenTelemetry.

## Lifecycle

1. **Route start** — create the manifest before the first delegation. Record the route ID,
   timestamps, a short sanitized request summary, matched trigger(s), the selection-policy decision,
   and planned stages.
2. **Stage start** — append the sequence number, trigger, agent, configured model (the agent's
   frontmatter `model:`, e.g. `gpt-6-luna` for fast-tier agents, or `runtime-default`), start time,
   and the delegation/session ID when the runtime returns one. An `ESCALATE` reroute is a new stage.
3. **Stage end** — record completion time, status, and result/evidence paths before selecting the
   next dependent stage.
4. **Route end** — record the outcome and token/AI-credit usage join, then include the manifest path
   and a compact route/usage table in the final handoff. Collect usage for passed, failed, blocked,
   and partial outcomes alike: a failed environment check still consumes AI usage.

Do not delay or fail engineering work because runtime usage telemetry is unavailable. The route trace
is still required.

## Routing coverage

Coverage is unconditional for every request entering the router, not an allowlist of triggers.
New registry triggers inherit this protocol without a separate telemetry opt-in. Explicitly selected
specialists still retain their task; this protocol does not force them through a router.

| Routing path | Required record |
|---|---|
| Any specialist trigger or default specialist | Classification, selected agent, actual delegation IDs and stage outcome |
| Multiple triggers / multi-stage workflow | All matched triggers and selection-policy decision; one ordered stage per execution, including review and verification |
| Router-handled work (`manifest-sync`, `handoff-pack`, documentation/configuration) | Router-only classification and `routerUsage`; no invented specialist delegation |
| No match / clarification / delegation unavailable | Record the decision before asking or returning; retain the intended route, use an empty `stages` list if nothing ran, and capture router usage |
| Retry / repair / rerun / follow-up to an agent | A new stage sequence and attempt number for each invocation, including failed attempts; link a later retry request to its previous route |
| Downstream stages not run | Record each as `skipped`, with reason and null start/end and usage; never claim a delegation ran |
| Cancellation / interruption | Close observed work as `cancelled` / `interrupted`; reconcile unfinished manifests from runtime evidence on resumption, never invent a completion time |
| External router / prompt handoff, including community/speckit handoffs | Record a handoff with target, dispatch status and IDs if available; link the child manifest when supplied; never claim execution from a recommendation alone |
| Missing runtime telemetry | Keep the route and every stage visible with unavailable usage, not a zero charge or omitted record |

Create the route at request admission, before classification, clarification or any work. Persist
`lifecycleStatus: waiting` while awaiting input and `closed` only when the route is finished.
Resume the same route after clarification; create a related route for a separate retry request.
Planned agents belong in `classification.route`; only actual invocations and explicitly skipped stages
belong in `stages`. Use a `handoff` stage for an external recommendation/dispatch, with
`handoff.status` distinguishing `requested`, `dispatched`, `unavailable` and `completed`.

## Manifest

```yaml
schema: cinemas-routing-telemetry/v1
routeId: rt-<UTC-ts>-<short-id>
parentSessionId: <runtime ID or null>
startedAt: <UTC timestamp>
completedAt: <UTC timestamp or null>
lifecycleStatus: running | waiting | closed
parentRouteId: <calling route ID or null>
relatedRouteId: <previous route ID for a separate retry request or null>
usageFinalized: <false until all route runtime records have been reconciled>
usageSnapshotAt: <last reconciled runtime usage timestamp or null>
request:
  summary: <sanitized one-line outcome>
  domain: <backend | devops | ios | database | web | testing | security | performance | ai | business | cpp | mixed>
  environment: <environment or null>
classification:
  triggers: [<trigger>]
  decision: <selectionPolicy rule used>
  route: [<agent names in execution order>]
  mode: delegated | router-only | clarification | fallback | handoff
routerUsage: <same usage fields as stages[].usage; router-only runtime rows, or unavailable>
stages:
  - sequence: 1
    attempt: 1
    kind: delegation | handoff
    trigger: <trigger>
    agent: <agent>
    configuredModel: <model alias or runtime-default>
    delegationId: <runtime ID or null>
    parentToolCallId: <runtime task tool-call ID or null>
    childSessionId: <runtime ID or null>
    startedAt: <UTC timestamp>
    completedAt: <UTC timestamp or null>
    status: running | passed | failed | blocked | skipped | cancelled | interrupted
    reason: <sanitized execution or skip reason>
    childManifest: <child route manifest path or null>
    handoff: <null, or mapping with target, status and reason>
    evidence: [<repository-relative result paths>]
    usage:
      attribution: exact | estimated | unavailable
      actualModels: [<runtime model names>]
      calls: <integer or null>
      inputTokens: <integer or null>
      outputTokens: <integer or null>
      cacheReadTokens: <integer or null>
      cacheWriteTokens: <integer or null>
      totalNanoAiu: <integer or null>
      aiCredits: <decimal or null>
      creditRecordedCalls: <integer or null>
      creditStatus: complete | partial | unavailable
      reason: <join method or reason unavailable>
outcome:
  status: passed | failed | blocked | partial | cancelled | interrupted
  summary: <sanitized one-line result>
```

Update the same manifest atomically; do not create one file per stage.
The coverage fields extend v1 additively; existing completed manifests remain readable.

## Attribution rules

| Level | Use when | Meaning |
|---|---|---|
| `exact` | Runtime usage rows carry the returned child session/delegation ID, or an agent ID and parent tool-call ID verified against the runtime task lifecycle | Usage belongs to that delegated stage |
| `estimated` | Stages did not overlap and usage can be bounded by stage start/end | Best available stage estimate; may include routing overhead |
| `unavailable` | No stable ID or trustworthy time window exists | Keep token fields `null`; do not guess |

- Runtime model names may differ from the configured model alias. Preserve both.
- Never assign all usage from a matching model family to an agent.
- Never estimate tokens from characters, file size, tool calls or elapsed time.
- Parallel independent stages need stable runtime IDs for attribution. If IDs are absent, their usage is unavailable rather than divided between them.
- Router overhead stays separate when the runtime exposes it. Otherwise mention it in the estimate reason.
- `routerUsage` includes only non-child runtime rows scoped to this request, never the whole session. In router-only routes it is the only usage bucket. If request boundaries cannot be established, mark it unavailable. Do not also add router overhead already included in a stage estimate.
- For repeated invocations of one agent ID, bound records by invocation/turn so earlier calls are not charged again. Each runtime usage row may contribute to a combined total only once.
- Nested handoff totals are inclusive or expanded, never both: show the parent handoff subtotal OR the child router and child stages. Label unjoined/partial totals; do not sum whole-session usage with per-agent usage. Do not label a route total complete if any executed stage or router usage is missing.

## Runtime token and credit collection

- Prefer runtime per-call records. When cloud usage is missing, check the local `assistant_usage_events` ledger before declaring usage unavailable.
- Query that ledger with plain `SELECT` statements. Schema-introspection statements such as `PRAGMA` are rejected, and that rejection is not evidence that the ledger is unreachable. Declare usage unavailable only after a `SELECT` scoped to the request returns no usable rows.
- Join on the parent session and verified `agent_id` / `parent_tool_call_id`, not on model name. Recover missing delegation IDs from the runtime task lifecycle when possible. Use task start/end timestamps, never SQL log timestamps, as delegation boundaries; the agent continues consuming tokens after the database attempt ends.
- Sum `input_tokens`, `output_tokens`, `cache_read_tokens`, `cache_write_tokens` and `total_nano_aiu` over the same selected records. Preserve the raw integer as `totalNanoAiu`; display runtime AI credits as `aiCredits = totalNanoAiu / 1,000,000,000`.
- `creditRecordedCalls` counts rows with a non-null charge. Set `creditStatus` to `complete` only when at least one call was selected and every selected call has a charge, `partial` when only some do, and `unavailable` when none do. A partial sum is a recorded subtotal, not a complete charge. Missing charges remain null, not zero; an explicitly recorded zero is valid.
- Do not calculate credits from token counts, model prices or request multipliers. Do not add cached tokens again to input tokens or treat them as additional charges. Runtime credits are not a currency amount or a statement of the user's remaining allowance.
- Keep router usage separate from specialist usage; label specialist-only totals accordingly.
- Round credits only for display and preserve full recorded precision in the manifest.

## Privacy

Store summaries, IDs, timestamps, model names, counts and repository-relative evidence paths only. Never
store the full prompt, credentials, secret-file contents, database connection strings, API response bodies,
SQL result rows or source-code excerpts.

## Handoff table

```text
| # | Trigger | Agent | Configured / actual model | Attribution | Input | Output | AI credits | Credit status | Evidence |
```

The handoff table is mandatory in every final handoff, and it must always end with a combined
`Route total` row summing router usage and every executed stage in the table. Show the table and its
combined total for every outcome — passed, failed, blocked, partial, cancelled, interrupted,
router-only, clarification and handoff routes alike — and for single-stage and router-only routes,
where the total equals the one usage bucket. Never omit, collapse or defer the table because the route
was short, no specialist ran, the work was trivial, or the user did not ask for usage.

Build the combined total from the same records already listed in the rows, counting each runtime usage
row once, and keep nested handoff totals inclusive or expanded but never both. Label it
`snapshot` while `usageFinalized: false`, and mark it a subtotal whenever any executed stage or router
row is partial or unavailable; a total is `complete` only when every listed executed row has recorded
charges. When no usable records exist at all, still show the row with `—` and the reason rather than a
zero charge.

Include a separate router row, every executed attempt, handoffs and skipped stages. Skipped stages display
`not run`, not an invented zero-token invocation. For waiting routes, display the current snapshot; reconcile
delayed ledger records when available without dropping the original outcome. Keep `usageFinalized: false`
when final handoff/closure calls are not yet in the ledger and label the display as a snapshot, even if all
selected records have charges. Do not claim a final total from it.

Always display token and AI-credit usage, including blocked/failed runs. When usage is unavailable,
show `—` and the reason; label partial charges as subtotals. The router must not claim that a specialist
ran unless the delegation actually occurred.
