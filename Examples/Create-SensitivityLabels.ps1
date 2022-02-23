
<#
.DESCRIPTION
To do.

.NOTES
Requires the Global Administrator role.

.EXAMPLE
.\Create-SensitivityLabels.ps1 -certificateThumbprint 'CFE601DF99EC017EAA19D8853004873B5B46DBBA' -appId "07f8ec11-b3e4-4484-8af4-1b02c42f7d4a" -tenant "contoso.onmicrosoft.com"

.LINK
https://github.com/rhyspaterson/mip-epms
#>

#Requires -Modules ExchangeOnlineManagement

param (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    $appId,    
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    $certificateThumbprint,
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    $tenant
)

# Import our common functions.
Try {
    . .\Functions.ps1
} Catch {
    Throw 'Could not import functions.ps1.'
}

# Connect to EXO and SCC via certificate and app registration. Discnnect any existing sessions for good measure.
Assert-ServiceConnection -CertificateThumbprint $certificateThumbprint -AppId $appId -Tenant $tenant

# Provision our labels.
Assert-EPMSLabel -DisplayName "UNOFFICIAL" -Tooltip "No damage. This information does not form part of official duty."
Assert-EPMSLabel -DisplayName "OFFICIAL" -Tooltip "No or insignificant damage. This is the majority of routine information."
Assert-EPMSLabel -DisplayName "OFFICIAL - Sensitive" -Tooltip "Limited damage to an individual, organisation or government generally if compromised." -ParentLabelDisplayName "OFFICIAL"
Assert-EPMSLabel -DisplayName "PROTECTED" -Tooltip "Damage to the national interest, organisations or individuals."

# Disconnect!
Assert-ServiceConnection -Disconnect

