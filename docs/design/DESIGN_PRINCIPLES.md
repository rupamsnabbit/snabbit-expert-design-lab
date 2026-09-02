# Snabbit design principles

## Purpose

These principles define how the Snabbit Expert App should feel and how design decisions should be made. The app is an operational companion used while travelling, starting shifts, completing jobs, checking earnings, and recovering from problems. Clarity and confidence matter more than decoration.

## Product personality

### Bright

Use Snabbit pink to make the main action and important brand moments easy to find. Keep the canvas light, fresh, and energetic. Bright does not mean using many accent colors at once.

### Warm

Write and design like a supportive coordinator. Explain consequences without sounding punitive, acknowledge effort, and use friendly illustrations only when they help the expert understand the moment.

### Confident

Give every screen a clear hierarchy, one primary action, and decisive status language. Avoid vague labels, competing CTAs, and visual treatments that make an important state look optional.

### Practical

Optimize for fast scanning, one-handed use, outdoor conditions, intermittent connectivity, and time pressure. Put the current state, time, money impact, and next step before secondary detail.

### Trustworthy

Never hide payment, attendance, safety, cancellation, or penalty consequences. Keep values and status persistent when they matter. Confirm irreversible actions and explain whether retrying is safe.

### Human

Use familiar words, realistic examples, and respectful guidance. Do not blame the expert for system, network, location, or permission failures. Support English and Hindi without making either feel like a fallback.

## Design principles

### 1. Make the current state obvious

An expert should understand what is happening within two seconds. Lead with the status, then the action and consequence. Use text plus an icon, shape, or status label; never use color alone.

### 2. Make the next action unmistakable

Each decision area has one primary CTA. Secondary actions must be visually quieter. In time-sensitive job states, do not show two equally strong actions.

### 3. Show the consequence before commitment

Before attendance changes, job rejection, logout, payment setup, SOS, or other consequential actions, state the effect in plain language. Confirmation screens should repeat the essential outcome, not merely ask “Are you sure?”

### 4. Design the whole state machine

A screen is not complete at its happy path. Define default, loading, empty, success, error, disabled, offline or permission, timeout or expiry, and interrupted-session behavior where relevant. Preserve entered data after recoverable errors.

### 5. Reuse before creating

Start with the design-system package, then the app wrappers and documented patterns. A new reusable component is justified only when an existing component would misrepresent the hierarchy or when a repeated interaction needs one consistent state model.

### 6. Use tokens, not taste

Map every visible value to a semantic color, typography role, spacing value, radius, border, icon size, or component size in [DESIGN_TOKENS.md](./DESIGN_TOKENS.md). A one-off value needs a written reason and an owner.

### 7. Keep operational information stable

Countdowns, addresses, earnings, attendance, and job status should not jump around as data refreshes. Loading should preserve layout. Updates should announce what changed without resetting the user's place.

### 8. Design for real conditions

Validate at Android phone widths, with system font scaling, long names and translations, the keyboard open, a system gesture inset, weak connectivity, and one-handed reach. The minimum interactive target is 48 dp.

### 9. Be positive without hiding risk

Celebrate success and earnings, but keep warnings direct. Pink is brand/action, green is success, amber is attention, red is danger/failure, and blue is information. Do not use celebratory styling for pending or uncertain outcomes.

### 10. One app across implementation surfaces

Compose/KMP, legacy Flutter, and hosted/webview screens must share hierarchy, semantic colors, spacing rhythm, CTA placement, state behavior, and voice. Migration differences are implementation facts, not permission to create different product personalities.

## Quick decision test

Before approving a design, answer yes to all five questions:

1. Can the expert tell what state they are in immediately?
2. Is there one obvious next action?
3. Are time, money, safety, and failure consequences explicit?
4. Does the design use approved tokens, components, and patterns?
5. Can the expert recover from loading, error, offline, disabled, or expired states?

