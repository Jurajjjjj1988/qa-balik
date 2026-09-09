# Security Audit Antipatterns

## Audit mistakes to avoid

- **False positives** — flagging `innerHTML` used on static content as XSS. Check if user input actually reaches it.
- **Guessing vulnerabilities** — don't flag something as "might be vulnerable". Trace the actual data flow. If unsure, write TODO.
- **Ignoring context** — admin-only endpoint with auth is different from public endpoint. Severity depends on exposure.
- **Missing remediation** — finding without a fix is useless. Always show how to fix it.
- **Skipping dependencies** — don't only look at source code. Check npm packages too.
- **Theoretical attacks** — focus on realistic attack vectors, not theoretical ones that require physical access.
