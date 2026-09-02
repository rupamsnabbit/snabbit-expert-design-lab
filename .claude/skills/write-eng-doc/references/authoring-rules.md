# Authoring rules & document flow (reference)

Loaded only when deeper detail is needed. Primary rules live in SKILL.md.

## Document flow
```
PRD ──► HLD ──► TRD ──► LLD ──► build-feature
(what/why) (system how) (verifiable reqs) (class-level how)
```
- Each doc traces to its parent via front-matter `traceability.parent`.
- Produce standalone TRD/LLD only when traceability or compliance requires it; otherwise fold their content into the HLD.

## Reference, don't restate
`.claude/documents/*` is the trusted baseline. Emitted docs **cite** it per-doc — `core-facts.md`, `feature-template.md`, `platform-rules.md`, `library-guide.md`, `component-catalog.md`, `git-discipline.md` — never copy its rules. Output to `docs/design/<feature>/` (per `git-discipline.md`).

## When to produce which
| Task size | Produce |
|-----------|---------|
| Small feature / bugfix | PRD (light) + HLD |
| Medium feature | PRD + HLD + TRD |
| Large / new module | All four |

## Markers
| Marker | Meaning |
|--------|---------|
| `[TBD]` | Unknown — stop and ask the human; never guess. |
| `[ASSUMPTION]` | Stated assumption; needs human confirmation before build. |

## Authoring rules (expanded)
1. **Tables first** — structured content (fields, gates, rules, matrices, contracts, dependencies) MUST be a table. Bullets only for short non-tabular notes. No wall-of-text. One idea per row.
2. **Diagrams required** — every non-trivial flow, state machine, sequence, topology, or architecture MUST include a Mermaid diagram. A section describing interactions/structure without one is incomplete.
3. **Human tone** — plain, direct sentences understandable on first pass. Lean = no filler, NOT cryptic shorthand.
4. **Lean scope** — only decision-bearing content. Never restate general knowledge a capable model already has (what a PRD is, that metrics must be measurable, standard lifecycle facts).
5. **Current** — web-search official sources before asserting any version, SDK, API, OS limit, or platform recommendation. Never rely on training memory.
6. **Evidence** — every concept recommendation cites an official source (vendor/standards docs); otherwise mark `[ASSUMPTION]` and flag for confirmation.
7. **STOP-on-unknown** — a gap is a hard stop: write `[TBD]`, ask the human. Do not fabricate scope, metrics, contracts, permissions, or design decisions.
8. **Gate** — do not advance to the next document in the flow until the current one has no unresolved `[TBD]`.
9. **No new sections** — use the template's headings exactly; do not add or remove.

## Boundary quick-test
If a reader could start writing production code directly from a section, it is too detailed for a PRD/HLD — move it down to TRD/LLD. If a section argues user value or product rationale, it belongs in the PRD, not a design doc.

## Platform handling
- Repo targets **Android + iOS via KMP `:shared`**; `platforms:` lists targets (android, ios).
- Per-platform differences go in the per-platform table (**Android / iOS only**). commonMain purity: verify `./gradlew :shared:compileTestKotlinIosArm64` (per `library-guide.md`).

## Mermaid safety (parser-breaking tokens to avoid in diagram text)
- `;` — treated as a statement separator; splits the line.
- `<...>` angle brackets, `=` at a label start.
- `→` / `∧` unicode in structural positions — use "and" / "then".
- Class-diagram members: one per line inside `{ }`, not `;`-separated.
