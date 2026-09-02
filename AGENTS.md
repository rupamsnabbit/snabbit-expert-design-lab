# Snabbit Expert App agent entrypoint

This repository is used by a product designer to explore, review, and implement high-fidelity frontend experiences. Preserve the existing product language and make decisions legible to a non-engineer.

## Route design work

For any PRD, Figma, screenshot, UI/UX critique, new or redesigned screen, component, visual state, frontend prototype, or design QA task, use the repository skill at `.agents/skills/snabbit-design/SKILL.md`.

Keep routine engineering questions outside that workflow unless they materially affect the interface.

## Working boundaries

- Frontend is the default scope. Use deterministic frontend fixtures for review; do not require a live backend, authentication, or production data.
- Do not delete, rewrite, or expand backend, API, analytics, navigation, or infrastructure code unless the user explicitly requests that exact change. Preserve existing seams and replace data only at a fixture or preview boundary.
- Work in the framework that already owns the target feature: Compose/KMP for KMP surfaces, Flutter for existing Flutter surfaces, and the existing shell for hosted surfaces. Propose a framework change in the design brief before attempting one.
- For a new screen or meaningful redesign, present a concise design brief and resolve outcome-changing questions before implementation. For a small, explicit visual correction, state the intended change and proceed without ceremony.
- Do not create or switch branches unless asked. When Git metadata is present, check the current branch and avoid mixing separate design projects.
- Follow `CLAUDE.md` for repository engineering constraints and `docs/design/` for product-design rules.
- Do not claim a visual result is verified unless it was rendered or captured. Report exactly what was and was not checked.

## Product source order

When visual sources disagree, use:

1. The installed design-system package.
2. `docs/design/` rules.
3. The nearest consistent Snabbit reference screen.
4. A documented local decision only when the first three cannot express the requirement.

PRDs and Figma define the intended user outcome. They do not silently create new tokens or interaction patterns.
