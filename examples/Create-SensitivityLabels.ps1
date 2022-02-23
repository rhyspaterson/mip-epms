
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
    . .\_functions.ps1
    . .\_labels.ps1
} Catch {
    Throw 'Could not import pre-requisites ($_.Exception).'
}

# Connect to EXO and SCC via certificate and app registration. Discnnect any existing sessions for good measure.
Assert-ServiceConnection -CertificateThumbprint $certificateThumbprint -AppId $appId -Tenant $tenant

foreach ($label in $labels) {
    
    # Create the sensitivty labels
    Assert-EPMSLabel `
        -DisplayName $label.LabelDisplayName `
        -Tooltip $label.Tooltip `
        -IsParent $label.IsParent `
        -ParentLabelDisplayName $label.ParentLabel

    if (-not($label.IsParent)) {
        # Create the matching auto-labeling policies
        Assert-AutoSensitivityLabelPolicyAndRule `
            -Identifier $label.Identifier `
            -LabelDisplayName $label.LabelDisplayName `
            -HeaderRegex $label.HeaderRegex 
    }
}

# Disconnect!
Assert-ServiceConnection -Disconnect

