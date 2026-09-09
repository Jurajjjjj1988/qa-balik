---
name: check-api-contract
description: >-
  Use when an HTTP API's promises and its behaviour may have drifted apart — a payload that matches
  the published schema and is rejected anyway, a client or fixtures generated from Swagger that the
  service will not accept, a validation error surfacing as 500 instead of 400, errors shaped
  differently on every endpoint, a required field that silently stores null, pagination done one way
  here and another way there, or simply reviewing an endpoint, route handler or OpenAPI spec before
  it ships. Load it because the confident answer here is usually incomplete in the way that costs
  most: a contract is only proven by checking BOTH directions — the spec permits it and the service
  accepts it, AND the service rejects what the spec forbids — and testing an API against
  expectations generated from its own spec compares two outputs of one source, so a mistake present
  in both cancels out and the suite stays green. Triggers on "API contract", "endpoint review",
  "status codes", "400 or 500", "error format", "validate API", "pagination", "Content-Type",
  "OpenAPI", "Swagger", "spec does not match the implementation", "generated client rejected".
  Do not use for writing the endpoint (that is implementation), for load testing, or for injection
  and authorization flaws — that is security-audit.
argument-hint: [endpoint or route file]
allowed-tools: Read, Grep, Glob
---

Check API contract:

1. Input validation — what happens with missing/extra fields?
2. Correct HTTP status codes? (200, 201, 400, 401, 404, 500)
3. Same error format everywhere? `{ error, message, code }`
4. Content-Type headers?
5. Pagination — consistent approach?
6. Does implementation match documentation?

Output: | Endpoint | Method | Issue | Fix |

## The contract must be checked in BOTH directions

Point 6 is where contracts actually break, and one direction is not enough. For each field, put what
the **spec** says next to what the **service** does:

| spec | služba | znamená |
|---|---|---|
| platné | prijaté | zhoda |
| neplatné | odmietnuté | zhoda |
| platné | **odmietnuté** | 🔴 **špecifikácia klame** |
| neplatné | **prijaté** | 🔴 **chýbajúca validácia** |

Measured 2026-09-01 on `spring-petclinic-rest`, field `telephone`:

| dĺžka | OpenAPI hovorí | služba vracia | |
|---|---|---|---|
| 1, 5, 9, 11 | PLATNÉ (`minLength 1, maxLength 20`) | **HTTP 500** | 🔴 spec klame |
| 10 | PLATNÉ | 201 | zhoda |
| 21 | NEPLATNÉ (nad `maxLength`) | 400 | zhoda |

Two independent defects in one field: the published contract is **wrong** (a client generated from
Swagger sends payloads the service rejects), and a client-input violation surfaces as **500 instead
of 400**, so it pages as a server outage and gets triaged as an incident. Note also that the service
has TWO validation layers — one matching the spec and returning 400, one deeper that the spec does
not document and that throws 500. Finding only the first is the usual mistake.

**Do not test an API against expectations generated from its own spec.** That compares two outputs
of one source, so a mistake present in both cancels out and the suite stays green — the same class
as a round-trip test. The spec is a valid oracle only when checked AGAINST the running service.

A dependency-free validator that reports what the spec permits — and, deliberately, flags what it
could NOT evaluate (`$ref`, `oneOf`, ECMA-262 `\p{L}` patterns) instead of calling it valid — ships
with the `characterization-tests` skill as `scripts/openapi-oracle.py`.

## Error class is part of the contract

`4xx` says the caller must change something; `5xx` says the caller should retry because the fault is
ours. Returning 500 for bad input tells every client to retry a request that can never succeed, and
buries a validation bug in the outage graph. A framework exception reaching the client unhandled
(`ConstraintViolationException`, `NullPointerException`) is always a contract defect, whatever the
status code beside it.

$ARGUMENTS

---

## Kritik — povinné pred výstupom

Postup: `_lib/KRITIK.md`

> **Otázka pre tento skill:** Skúšal si pri každom poli OBA smery na bežiacej službe — hraničnú hodnotu, ktorú spec POVOĽUJE (nevráti 500?), aj hodnotu, ktorú spec ZAKAZUJE (naozaj ju odmietne?) — alebo riadok stojí na čítaní handlera/spec, prípadne na fixtures vygenerovaných z tej istej spec?
