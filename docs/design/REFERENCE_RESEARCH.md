# Reference research

Use external product references to improve the quality of a decision, not to choose a new visual identity. Mobbin is the preferred source when the user asks to explore designs, find inspiration, compare flows, or learn how other products handle an unfamiliar user moment.

## When to use Mobbin

Use the connected `mobbin` MCP server when:

- the user explicitly asks for exploration, inspiration, benchmarking, or examples;
- a PRD leaves an important interaction or information-architecture question unresolved;
- an existing flow has a known usability problem and comparable patterns could clarify options; or
- the design brief needs evidence for a consequential pattern choice.

Do not use Mobbin for every small visual edit, to decorate a settled Snabbit pattern, or to replace inspection of the supplied Figma and current implementation.

## Research sequence

1. **Frame the question.** State the user, moment, job, constraint, and decision the research should inform. A useful question is narrow, such as “How do worker apps confirm a time-sensitive check-in without implying the shift has started?”
2. **Inspect Snabbit first.** Find the nearest screen family, reusable components, and documented pattern. This reveals the actual gap and prevents unnecessary novelty.
3. **Search Mobbin deliberately.** Fetch a small set of closely related screens or flows. Prefer complete sequences and relevant product contexts over visually attractive isolated screens.
4. **Extract lessons.** Record observed hierarchy, disclosure, CTA placement, state transitions, recovery, trust signals, and content strategy. Do not infer behavior that the evidence does not show.
5. **Synthesize options.** Keep only patterns that address the framed question. Explain their advantages, risks, and relevance to Snabbit experts.
6. **Translate to Snabbit.** Rebuild the selected idea using Snabbit components, semantic tokens, spacing, typography, iconography, voice, state behavior, accessibility rules, and Android screen constraints.
7. **Brief before building.** Add the evidence and adaptation to `DESIGN_BRIEF_TEMPLATE.md`. For a new screen or meaningful redesign, present the brief and resolve material choices before implementation.

## What an agent should return

For meaningful exploration, summarize:

- the focused research question;
- the exact Mobbin screens or flows reviewed, with links or stable identifiers when available;
- observed patterns, clearly separated from interpretation;
- 1–3 applicable directions and their tradeoffs;
- the recommended direction and why it fits Snabbit;
- what will be retained, changed, or rejected during Snabbit translation; and
- gaps or assumptions the references could not answer.

Store durable task evidence in the design brief's `Reference synthesis` section. Do not claim that the underlying model was trained or permanently learned from Mobbin; agents use the fetched evidence for the current task, while approved documented decisions become reusable repository knowledge.

## Translation rules

Mobbin may inform:

- information order and progressive disclosure;
- interaction and navigation models;
- useful state coverage and recovery paths;
- CTA hierarchy and decision timing;
- trust, status, and confirmation patterns; and
- concise content structures.

Mobbin must not directly supply:

- Snabbit colors, fonts, spacing, radii, elevation, or icon style;
- copied branding, assets, screenshots, or product copy;
- a new component when approved primitives can express the solution;
- a pattern that conflicts with the design-system package or `docs/design/`; or
- assumed product requirements that are absent from the PRD or user decision.

The source order remains:

1. Approved product outcome and facts.
2. Installed Snabbit design-system package.
3. Rules in `docs/design/`.
4. The nearest consistent Snabbit reference.
5. External research as supporting evidence.
6. A documented local decision only when the existing system cannot express the need.

## If no existing component fits

An external reference can reveal a missing capability, but it does not authorize a component by itself. Follow [DESIGN_EXTENSION_PROCESS.md](./DESIGN_EXTENSION_PROCESS.md): try composition first, name the capability gap, classify its ownership, and propose the narrowest token-aligned extension. Use [NEW_COMPONENT_BRIEF_TEMPLATE.md](./NEW_COMPONENT_BRIEF_TEMPLATE.md) when the threshold is met.

## Failure and access handling

If the `mobbin` MCP server is missing, unavailable, or unauthorized:

- state that external research was not completed;
- ask the user to reconnect Mobbin only when the research is necessary to proceed;
- continue with supplied references and Snabbit evidence when that is sufficient; and
- never fabricate Mobbin screens, links, findings, or implied trends.

Mobbin authentication is user-level Codex configuration and is not committed to this repository. A collaborator can connect it with:

```sh
codex mcp add mobbin --url https://api.mobbin.com/mcp
codex mcp login mobbin
```
