<#
.SYNOPSIS
    Bulk-updates all users' UPN suffix across department OUs for hybrid identity.
.DESCRIPTION
    Part B prerequisite. Before syncing to Entra ID, on-prem users need a routable
    UPN suffix that matches the cloud tenant (the default .local suffix is not
    routable to the cloud). This script loops through all four department OUs and
    rewrites each user's UPN from <user>@lab.local to <user>@contosolab.onmicrosoft.com.
.NOTES
    Run on DC01 as a Domain Admin. The routable UPN suffix must first be added to
    the forest (Active Directory Domains and Trusts > Properties > UPN Suffixes).
#>

# --- Define the target OUs ---
# All four department OUs. Storing them in an array lets us process every OU
# with one loop instead of repeating the command four times.
$OUs = @(
    "OU=IT,DC=lab,DC=local",
    "OU=Finance,DC=lab,DC=local",
    "OU=Management,DC=lab,DC=local",
    "OU=HR,DC=lab,DC=local"
)

# --- Loop through each OU and update every user's UPN ---
foreach ($ou in $OUs) {
    Get-ADUser -Filter * -SearchBase $ou | ForEach-Object {
        # Build the new UPN: keep the existing username (SamAccountName),
        # swap the suffix to the routable cloud domain.
        Set-ADUser -Identity $_ `
            -UserPrincipalName ($_.SamAccountName + "@contosolab.onmicrosoft.com")
    }
}

# --- Verify the change (example: IT OU) ---
Get-ADUser -Filter * -SearchBase "OU=IT,DC=lab,DC=local" |
    Select-Object Name, UserPrincipalName
