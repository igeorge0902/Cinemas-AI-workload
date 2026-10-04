# Routing Diagrams

Sources of truth, in order:

1. `.ai/agents/definitions/Cinemas Router.agent.md`
2. `.ai/agents/agents-role.yaml` (`umbrellaRouting`, `modelTiers`, and `triggerRouting`)
3. `.ai/agents/AGENTS.md`
4. `.ai/agents/ROUTING-TELEMETRY.md`

If a diagram conflicts with a source, the source wins.

```mermaid
flowchart TD
    U([User request]) --> E{Entry point}
    E -->|Cinemas Router selected| R[Cinemas Router]
    E -->|Specialist selected| S[Specialist keeps task]
    E -->|/speckit.*| K[Speckit lifecycle]
    R --> C[Classify trigger and dependencies]
    C --> M{Trustworthy match?}
    M -->|No| A[Use AGENTS.md, then ask]
    M -->|Yes| T{Fast criteria met?<br/>Protected areas excluded except approved schema docs}
    T -->|Yes| F[Cinemas Scout / Quick Engineer]
    T -->|No| D[Delegate smallest owning set]
    F -->|ESCALATE| D
    F --> V
    D --> P{Independent stages?}
    P -->|Yes| PAR[Run in parallel]
    P -->|No| SEQ[Run in dependency order]
    PAR --> V[Reconcile and verify]
    SEQ --> V
    V --> H[Hand off outcome]
```

Fully specified edits recording approved schema decisions go directly to the MAI-backed
Quick Engineer, in up to three named linked documentation files. This permits prose, approval
labels, and diagram annotations, not SQL edits or new design. Schema design, migrations,
and repairs go to Database Engineer. Neither path uses nested delegation for the same task.

## Retained telemetry lifecycle (disabled)

The diagram below is reference only. With `umbrellaRouting.telemetry.enabled: false`,
skip the entire telemetry lifecycle and preserve existing records without updates.

```mermaid
flowchart LR
    Q([Prompt]) --> RS[Route start: create manifest]
    RS --> CL[Record triggers and selection rule]
    CL --> SS[Stage start: agent, model, IDs, time]
    SS --> A[Delegated specialist]
    A --> SE[Stage end: status and evidence]
    SE --> N{More stages?}
    N -->|Yes| SS
    N -->|No| J{Usage join}
    J -->|Verified ID| EX[Exact]
    J -->|Non-overlapping window| ES[Estimated]
    J -->|Neither| UN[Unavailable]
    EX & ES & UN --> RE[Route end]
    RE --> HO[Manifest path and usage table]
```
