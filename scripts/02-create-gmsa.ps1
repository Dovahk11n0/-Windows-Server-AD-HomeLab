<#
.SYNOPSIS
    Creates the Group Managed Service Account (gMSA) used by the Entra Cloud Sync agent.
.DESCRIPTION
    Part B of the homelab. The Cloud Sync provisioning agent runs under this gMSA
    instead of a normal user account. A gMSA has its password managed automatically
    by Active Directory (rotated, never known by a human) — the secure way to run
    a service that needs domain access.
.NOTES
    Run on DC01 as a Domain Admin. Requires the KDS root key to exist in the domain
    (created once per forest — see prerequisite below).
#>

# --- Prerequisite (run once per forest, if not already done) ---
# The KDS root key lets AD generate/manage gMSA passwords.
# In production you wait 10 hours for replication; in a single-DC lab you can
# backdate it to take effect immediately:
# Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10))

# --- Create the gMSA ---
# -Name             : the account name (will appear as provAgentgMSA$)
# -DNSHostName      : FQDN the account is tied to
# -PrincipalsAllowedToRetrieveManagedPassword : ONLY these computers can use the
#                     gMSA — here, the two servers that run/authorize the agent.
New-ADServiceAccount -Name "provAgentgMSA" `
    -DNSHostName "FS01.lab.local" `
    -PrincipalsAllowedToRetrieveManagedPassword "DC01$","FS01$"

# --- Verify creation ---
Get-ADServiceAccount -Identity "provAgentgMSA"

# --- On FS01: confirm the server can actually use the gMSA ---
# (Run this part on FS01, not DC01)
# Test-ADServiceAccount -Identity "provAgentgMSA"    # should return True
