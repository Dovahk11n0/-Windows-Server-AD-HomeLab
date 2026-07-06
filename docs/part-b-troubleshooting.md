# Part B — Hybrid Identity Sync: Troubleshooting Log

Systematic root-cause investigation of an Entra Cloud Sync provisioning failure.
Documented as a real diagnostic workflow: observe → hypothesize → test → rule out → iterate.

**Final status:** Agent active and configured; provisioning blocked by a gateway-side
timeout at Microsoft's proxy layer. Multiple local causes tested and eliminated with evidence.

---

## Environment at time of issue

- FS01 — Windows Server 2022, Entra Cloud Sync provisioning agent
- DC01 — Windows Server 2022, Domain Controller (`lab.local`)
- Tenant — `contosolab.onmicrosoft.com` (redacted)
- 8 users across 4 department OUs (IT, HR, Finance, Management)

---

## Issue 1 — Portal 401 "You don't have access"

**Symptom:** Cloud Sync blade returned `Error code 401` when opening Configurations.

**Investigation:**
- Verified the signed-in account held **Global Administrator** (checked Roles &
  Administrators → Global Administrator → Assignments). Confirmed present.
- Since permissions were correct, the 401 pointed to a stale/corrupted portal session.

**Resolution:** Full sign-out + fresh sign-in cleared the token. Blade loaded normally.

**Takeaway:** A 401 on an account that *does* hold the right role is usually a session/token
issue, not a permissions gap — verify the role first, then reset the session.

---

## Issue 2 — Agent installed but not visible in portal

**Symptom:** Provisioning agent installed and service running on FS01, but the portal's
Agents list showed "No results."

**Investigation:**
- Confirmed service state: `Get-Service AADConnectProvisioningAgent` → **Running**
- Confirmed outbound connectivity: `Test-NetConnection login.microsoftonline.com -Port 443`
  → `TcpTestSucceeded: True`
- Event log (`Microsoft-AzureADConnect-ProvisioningAgent/Admin`) showed the agent
  successfully reading config and reaching the bootstrap service host.
- Two recurring **Error** events appeared (performance counters / registry key 'Global'
  access denied) — investigated and determined to be cosmetic telemetry errors that do
  not affect sync (agent reaches Microsoft regardless).

**Resolution:** The registration was propagating on Microsoft's side. After allowing time,
the agent appeared as **active** (Machine Name: `FS01.lab.local`, status: active).

**Takeaway:** Newly-registered agents on a fresh tenant can take time to surface in the
portal — the local event log (bootstrap host reached) is a faster source of truth than
the portal UI.

---

## Issue 3 — Directory sync showed "Disabled" at tenant level

**Symptom:** Tenant status card showed **Microsoft Entra Connect: Disabled**.

**Investigation:** Navigated to Entra Connect → Cloud Sync. Determined that Cloud Sync is
"enabled" by *creating and enabling a sync configuration*, not a standalone toggle. The
"Disabled" state simply meant no active configuration existed yet.

**Resolution:** Created a sync configuration for `lab.local` and proceeded to scoping.

---

## Issue 4 — Provisioning quarantined (the core issue)

**Symptom:** After enabling the configuration, status went to **Provisioning quarantined**.

**Initial error:**

Error code:    HybridIdentityServiceAgentTimeout
Response:      GatewayTimeout
max_duration:  600000 ms (10 min)
Last cycle:    6 min 33 sec (for only 8 users — abnormally slow)
Steady state:  Never

### Root-cause isolation — causes tested and ruled out

| Hypothesis | Test | Result |
|-----------|------|--------|
| Agent not running / stale | `Restart-Service` + status check | Running — not the cause |
| VM RAM too low | Raised FS01 to 5 GB, DC01 to 4 GB; host has 32 GB | Status briefly went Healthy but sync still failed — **not the root cause** |
| gMSA broken | `Test-ADServiceAccount provAgentgMSA` | `True` — account healthy |
| Users outside scope | `Get-ADUser -SearchBase` per OU | All 8 users present in correct OUs |
| LDAP unreachable | `Test-NetConnection DC01 -Port 389` | `True` — reachable |
| Global Catalog unreachable | `Test-NetConnection DC01 -Port 3268` | `True` — reachable |
| Clock skew (certs) | Compared `Get-Date` on both VMs vs real time | In sync — not the cause |
| Password Hash Sync failing | Disabled PHS, re-ran provisioning | **Identical error persisted** — PHS ruled out |

### Conclusion
With every local cause eliminated, the failure was isolated to **Microsoft's provider
gateway**. The error response carried `x-ms-proxy-*` headers (proxy-app-id, proxy-connector-id,
proxy-data-center), confirming the timeout occurred at Azure's proxy layer receiving the
agent's response — not at the local agent, network, or directory.

**Final status:** Configuration built and active; sync pending resolution at the provider
layer. Documented as a known limitation rather than a hidden failure.

---

## Tools used

`Get-Service` · `Test-NetConnection` · `Test-ADServiceAccount` · `Get-ADUser` ·
`Get-WinEvent` (agent Admin log) · Entra portal (Agents, Provisioning logs,
Diagnose and solve problems) · `Restart-Service`

## What I'd try next

- Re-test provisioning after tenant-side propagation (trial tenants can have transient
  gateway limits)
- Open a Microsoft support case referencing the Correlation ID / Job ID from the error
- Validate gMSA replication permissions (`Replicating Directory Changes`) if re-enabling PHS

