# Code Review Antipatterns

## Review mistakes to avoid

- **Bikeshedding** — arguing about naming while there's a bug. Fix bugs first, style second.
- **Style over substance** — don't criticize formatting when logic is broken.
- **Rewrite suggestions** — "I would do it differently" is not a review finding. Show specific issue.
- **Missing severity** — every finding needs a criticality score. Not everything is Critical.
- **No Before/After** — saying "this is wrong" without showing what's right is useless.
- **Reviewing generated code** — don't nitpick auto-generated files (lock files, configs).
- **Scope creep** — review what was changed, not the entire file history.
