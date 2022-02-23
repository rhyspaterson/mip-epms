
<#
.DESCRIPTION
To do.

.NOTES
Requires the Global Administrator role.

.EXAMPLE
.\Create-AutoLabelingPolicies.ps1 -certificateThumbprint 'CFE601DF99EC017EAA19D8853004873B5B46DBBA' -appId "07f8ec11-b3e4-4484-8af4-1b02c42f7d4a" -tenant "contoso.onmicrosoft.com"

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
} Catch {
    Throw 'Could not import _functions.ps1.'
}

# Connect to EXO and SCC via certificate and app registration. Discnnect any existing sessions for good measure.
Assert-ServiceConnection -CertificateThumbprint $certificateThumbprint -AppId $appId -Tenant $tenant

# The regular expression engine afforded to us within Microsoft 365 oeprates with some limitations.
# The most important being that variable length lookaheads are not supported (e.g: .*, or .+)
# Therefore we must assume the whitespaces are commas as defined in the specificaiton are adhered to (e.g., no variable whitespace).
# Currently escpaing commas as unicode as the engine did not like that, either.
$labels = [PSCustomObject]@(
    [PSCustomObject]@{
        Identifier          = "unofficial"
        LabelDisplayName    = "UNOFFICIAL"
        Tooltip             = "No damage. This information does not form part of official duty."
        HeaderRegex         = "(?im)sec=unofficial\u002C"
        HeaderExample       = "VER=2018.3, NS=gov.au, SEC=UNOFFICIAL, ORIGIN=jane.doe@contoso.gov.au"
    }
    [PSCustomObject]@{
        Identifier          = "official-parent"
        LabelDisplayName    = "OFFICIAL [Parent]"
    }     
    [PSCustomObject]@{
        Identifier          = "official"
        LabelDisplayName    = "OFFICIAL"
        Tooltip             = "No or insignificant damage. This is the majority of routine information."
        HeaderRegex         = "(?im)(sec=official)(?!:sensitive)"
        HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL, ORIGIN=jane.doe@contoso.gov.au"
    }    
    [PSCustomObject]@{
        Identifier          = 'official-sensitive'
        LabelDisplayName    = "OFFICIAL - Sensitive"
        Tooltip             = "Limited damage to an individual, organisation or government generally if compromised."
        ParentLabel         = "official"
        HeaderRegex         = "(?im)(sec=official:sensitive)(?!\u002C\saccess)"   
        HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL:Sensitive, ORIGIN=jane.doe@contoso.gov.au"
    } 
    [PSCustomObject]@{
        Identifier          = 'official-sensitive-legal-privilege'
        LabelDisplayName    = "OFFICIAL - Sensitive - Legal Privilege"
        ParentLabel         = "official"
        HeaderRegex         = "(?im)(sec=official:sensitive\u002C\saccess=legal-privilege)"
        HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL:Sensitive, ACCESS=Legal-Privilege, ORIGIN=jane.doe@contoso.gov.au"
    }  
    [PSCustomObject]@{
        Identifier          = 'official-sensitive-personal-privacy'
        LabelDisplayName    = "OFFICIAL - Sensitive - Personal Privacy"
        ParentLabel         = "official"
        HeaderRegex         = "(?im)(sec=official:sensitive\u002C\saccess=personal-privacy)"
        HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL:Sensitive, ACCESS=Personal-Privacy, ORIGIN=jane.doe@contoso.gov.au"
    }
    [PSCustomObject]@{
        Identifier          = 'protected-parent'
        LabelDisplayName    = "PROTECTED [Parent]"
    }     
    [PSCustomObject]@{
        Identifier          = 'protected'
        LabelDisplayName    = "PROTECTED"
        Tooltip             = "Damage to the national interest, organisations or individuals."
        HeaderRegex         = "(?im)(sec=protected)(?!\u002C\saccess)"
        HeaderExample       = "VER=2018.3, NS=gov.au, SEC=PROTECTED, ORIGIN=jane.doe@contoso.gov.au"
    }        
)

foreach ($label in $labels) {

        Write-Host "Configuring '$($label.LabelDisplayName)."

        if (-not ($label.Identifier -like "*-parent")) {

            $deployedLabel = Get-Label | Where-Object { ($_.DisplayName -eq $label.LabelDisplayName) -and ($_.Mode -ne 'PendingDeletion') }
            
            if (-not($deployedLabel)) {
                Throw "Could not get label details."
            }

            $policyName = "Auto-label '$($label.Identifier)' mail" # 64 characters, max
            $ruleName = "Detect x-header for '$($label.Identifier)'" # 64 characters, max

            Write-Host "Creating auto-labeling policy: $policyName"
            
            New-AutoSensitivityLabelPolicy `
                -Name $policyName `
                -ApplySensitivityLabel $deployedLabel.Guid `
                -ExchangeLocation 'All' `
                -Mode 'TestWithoutNotifications' `
                -OverwriteLabel $true              
            
            Write-Host "Creating auto-labeling policy rule: $ruleName"

            New-AutoSensitivityLabelRule `
                -Name $ruleName `
                -HeaderMatchesPatterns @{"x-protective-marking" =  "(?im)sec=official\u002C"} `
                -Workload "Exchange" `
                -Policy "$policyName"

        }

}