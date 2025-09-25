# Issue Triage Process

To keep the public issue tracker healthy, follow this triage checklist at least twice per week (or whenever new reports arrive).

## 1. Intake

1. **Label with `needs-triage`** (automatically applied via template).
2. **Check for duplicates** by searching keywords and close with reference if already tracked.
3. **Confirm reproduction** when possible; request clarifying details if reproduction steps are unclear.

## 2. Categorize

- Apply one `type/*` label (`type:bug`, `type:docs`, `type:feature`, `type:infra`).
- Apply priority:
  - `P0`: release blocker / crashes / data-loss
  - `P1`: severe regression / unusable feature
  - `P2`: default priority (most items)
  - `P3`: nice-to-have / low risk
- Add `area/*` labels (e.g., `area:property`, `area:benchmark`, `area:runner`).

## 3. Assign

- Mention or assign a maintainer responsible for the affected area.
- If help-wanted, add `good-first-issue` or `help-wanted`.

## 4. Plan

- For bugs: capture reproduction, expected/actual, environment.
- For features: ensure acceptance criteria and success metrics are written.
- Link to roadmap milestone (`Milestone: Alpha`, `Beta`, etc.).

## 5. Update Status

- Remove `needs-triage` once categorized.
- Move to project board column (e.g., Inbox → Ready → In Progress → Done).

## 6. SLA Guidelines

- **P0**: acknowledge within 24h, fix before next release candidate.
- **P1**: acknowledge within 48h, plan fix within current milestone.
- **P2**: acknowledge within 5 days.
- **P3**: acknowledge when bandwidth allows; bundle into batch fixes.

Consistently applying this process keeps the roadmap honest and ensures contributors can find impactful work quickly.
