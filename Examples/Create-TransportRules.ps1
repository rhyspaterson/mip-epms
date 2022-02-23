<#
.DESCRIPTION
To do.

.NOTES
Requires the Global Administrator role.

.EXAMPLE
.\Create-TransportRules.ps1 -certificateThumbprint 'CFE601DF99EC017EAA19D8853004873B5B46DBBA' -appId "07f8ec11-b3e4-4484-8af4-1b02c42f7d4a" -tenant "contoso.onmicrosoft.com"
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

# Add domains into here as required.
$authorisedDomains = @('department-1.gov.au', 'department-2.gov.au')

Assert-DecryptionTransportRule -DisplayName 'EPMS - Strip encryption for outgoing emails and attachments' -TrustedDestinations $authorisedDomains