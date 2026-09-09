---
name: security-audit
description: Manual security audit against OWASP Top 10 — SQL/NoSQL injection, XSS, hardcoded secrets, open CORS, auth/authorization bypass, sensitive data in logs, prototype pollution. Outputs severity-ranked findings with fixes. Use when reviewing a file or module for vulnerabilities by reading code. Triggers on "security audit", "OWASP", "XSS", "injection", "auth bypass", "secrets in code". Do not use for dependency CVE scanning (use check-dependencies) or tool-driven SAST scans (use semgrep or codeql).
argument-hint: [file or module]
allowed-tools: Read, Grep, Glob
---

Security audit. Find concrete vulnerabilities:

1. SQL/NoSQL injection — user input in queries?
2. XSS — user input rendered without escaping?
3. Hardcoded secrets — API keys, passwords, tokens in code
4. CORS — open to everyone?
5. Auth — can anything be bypassed? Missing authorization checks?
6. Sensitive data in logs or error messages
7. Prototype pollution — unsafe object merges

Output: | Severity | Category | File:Line | Finding | Fix |

Critical / High / Medium / Low

Avoid audit mistakes listed in [antipatterns/common.md](antipatterns/common.md).

$ARGUMENTS

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Vieš pri každom náleze ukázať vstupný bod (route/handler), z ktorého sa útočníkov vstup dostane až na ten riadok — alebo si videl len konkatenáciu v dotaze?
