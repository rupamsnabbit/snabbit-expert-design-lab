# Engineering Document Conventions — Snabbit Runner KMP

Conventions for the four templates (PRD/HLD/TRD/LLD) authored by the `write-eng-doc` skill for `:shared` KMP/CMP features. Docs are version-controlled under `docs/design/<feature>/` (see `.claude/documents/git-discipline.md`).

## The 4 documents & flow
| Doc | Answers | Owner |
|-----|---------|-------|
| PRD | What / Why (users) | Product |
| HLD | System-level How — architecture, module interaction, platform abstraction | Tech Lead |
| TRD | Verifiable requirements — functional + NFRs, permissions, contracts | Eng Lead |
| LLD | Class/method-level How for one module | Engineer |

```
PRD ──► HLD ──► TRD ──► LLD ──► build-feature
```

| Task size | Produce |
|-----------|---------|
| Small feature / bugfix | PRD (light) + HLD |
| Medium feature | PRD + HLD + TRD |
| Large / new module | All four |

Fold TRD/LLD into the HLD unless traceability needs them standalone.

## Reference, don't restate (repo baseline)
`.claude/documents/*` is the trusted baseline. Emitted docs **cite** it per-doc — never copy its rules:
| Concern | Cite |
|---------|------|
| Architecture / MVI / AppErrorType / D1 / D2 / Koin | `core-facts.md` + `feature-template.md` |
| Design System — SnabbitScreen, components, tokens | `component-catalog.md` |
| Platform — CmpHostActivity (TARGET), Navigation 3 (not in build), StoreManager, FGS/WorkManager | `platform-rules.md` |
| Stack / pinned versions / iOS compile gate | `library-guide.md` |
| Branch / PR / output path | `git-discipline.md` |

## Conventions (apply to all four)
| Marker | Meaning |
|--------|---------|
| `[TBD]` | Unknown. **Stop and ask — never guess or invent.** |
| `[ASSUMPTION]` | Stated assumption; confirm before build. |
| front-matter | YAML: type, status, owner, version, `traceability`. |
| gate | Don't advance to the next doc while any `[TBD]` is unresolved. |

## Authoring rules (enforced)
- **Tables first** — structured content is a table; bullets only for short notes.
- **Diagrams required** — every non-trivial flow/state/topology/architecture has a Mermaid diagram.
- **Human tone** — plain, first-pass-readable; lean ≠ cryptic shorthand.
- **Current** — web-search official sources for any version/API/limit **not** in the recorded docs.
- **Evidence** — recommendations cite an official source or recorded doc, else `[ASSUMPTION]`.
- **Lean scope** — only decision-bearing content; don't restate recorded rules; don't add/drop sections.
- **Mermaid safety** — no `;`, `<...>`, `=` at a label start, `→`, `∧`; class members one per line.

## Platforms
This repo targets **Android + iOS via KMP `:shared`** (`commonMain` + `androidMain` + `iosMain`). Per-platform tables carry **Android / iOS only**. commonMain purity is verified with `./gradlew :shared:compileTestKotlinIosArm64` (per `library-guide.md`).
