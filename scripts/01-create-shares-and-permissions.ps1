<#
.SYNOPSIS
    Creates departmental file shares on FS01 with least-privilege NTFS permissions.
.DESCRIPTION
    Part A of the Windows Server homelab. Creates four base shares plus department
    shares, then applies NTFS ACLs so each group only accesses what it needs.
.NOTES
    Run on FS01 as a Domain Admin. Domain: lab.local
#>

# --- 1. Create the base share folders ---
# Loop creates all four folders in one pass instead of four separate commands.
"Home","Redirect","Shared","Software" | ForEach-Object {
    New-Item -Path "C:\Shares\$_" -ItemType Directory -Force
}

# Department folders
"IT","Finance" | ForEach-Object {
    New-Item -Path "C:\Shares\$_" -ItemType Directory -Force
}

# --- 2. Create the SMB shares ---
# Home$ and Redirect$ use "$" to make them hidden (not browsable in network view).
New-SmbShare -Name "Shared"    -Path "C:\Shares\Shared"    -FullAccess "Everyone"
New-SmbShare -Name "Home$"     -Path "C:\Shares\Home"      -FullAccess "Everyone"
New-SmbShare -Name "Redirect$" -Path "C:\Shares\Redirect"  -FullAccess "Everyone"
New-SmbShare -Name "Software"  -Path "C:\Shares\Software"  -FullAccess "Everyone"
New-SmbShare -Name "IT$"       -Path "C:\Shares\IT"        -FullAccess "Everyone"
New-SmbShare -Name "Finance$"  -Path "C:\Shares\Finance"   -FullAccess "Everyone"
# NOTE: Share-level "Everyone" is intentional — real access control is enforced
# at the NTFS layer below (best practice: loose share ACL, strict NTFS ACL).

# --- 3. Apply NTFS permissions (least privilege) ---
# icacls flags: (OI)=object inherit, (CI)=container inherit, (M)=modify,
# (F)=full, (RX)=read+execute, (AD)=append data, /inheritance:r=remove inheritance

# Shared: all domain users can read/write
icacls "C:\Shares\Shared" /grant "LAB\Domain Users:(OI)(CI)(M)"

# Software: computers read/execute (for MSI deployment), users read-only
icacls "C:\Shares\Software" /grant "LAB\Domain Computers:(OI)(CI)(RX)"
icacls "C:\Shares\Software" /grant "LAB\Domain Users:(OI)(CI)(RX)"

# Department shares: only that department's group gets Modify
icacls "C:\Shares\IT" /grant "LAB\IT-Team:(OI)(CI)(M)"
icacls "C:\Shares\Finance" /grant "LAB\Finance-Team:(OI)(CI)(M)"

# Redirect: strip inheritance, then grant minimal rights.
# Users get RX on the top folder only (AD = they can create their own subfolder),
# CREATOR OWNER gets Full on what they create (their own redirected folders).
icacls "C:\Shares\Redirect" /inheritance:r
icacls "C:\Shares\Redirect" /grant "SYSTEM:(OI)(CI)F"
icacls "C:\Shares\Redirect" /grant "LAB\Domain Admins:(OI)(CI)F"
icacls "C:\Shares\Redirect" /grant "LAB\Domain Users:(RX,AD)"
icacls "C:\Shares\Redirect" /grant "CREATOR OWNER:(OI)(CI)(IO)F"
