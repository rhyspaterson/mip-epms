<#
.DESCRIPTION
Provisions sensitivity labels and the supporting DLP and ETR policies to provide EPMS support under the PSPF.

.NOTES
Assumes the Global Administrator role or appropraite privilege is allocated to the app registration.

.EXAMPLE
.\Create-SensitivityLabelsAndPolicies.ps1 `
    -certificateThumbprint 'CFE601DF99EC017EAA19D8853004873B5B46DBBA' `
    -appId "07f8ec11-b3e4-4484-8af4-1b02c42f7d4a" `
    -tenant "contoso.onmicrosoft.com"

.LINK
https://github.com/rhyspaterson/mip-epms
#>

#Requires -Modules ExchangeOnlineManagement

param (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string] $appId,    
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string] $certificateThumbprint,
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string] $tenant,
    [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
    [switch] $RemoveExistingLabelsAndPolicies,
    [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
    [switch] $WaitForPendingDeletions    
)

# Import our common functions.
Try {
    . .\_functions.ps1
    . .\_labels.ps1
    . .\_domains.ps1    
} Catch {
    Throw 'Could not import pre-requisites ($_.Exception).'
}

# Connect to EXO and SCC via certificate and app registration. Discnnect any existing sessions for good measure.
Assert-ServiceConnection -CertificateThumbprint $certificateThumbprint -AppId $appId -Tenant $tenant

# Trash everything prior, useful in building the full configuration state.
if ($RemoveExistingLabelsAndPolicies) {
    Write-Log -Message "Removing all exisitng labels and policies" -Level 'Warning'
    Remove-AllLabelsAndPolicies
}

# Wait for pending deletions, useful if you want to re-use the same name for some objects.
if ($WaitForPendingDeletions) {
    Write-Log -Message "Waiting for pending label and policy deletions. This can take a very long time."
    $deletionStatus = Get-PendingLabelAndPolicyDeletionStatus
    while ($deletionStatus -ne 'complete') {
        $deletionStatus = Get-PendingLabelAndPolicyDeletionStatus
        Start-Sleep 30
    }    
}

# Enumerate the configuration and provision our labels, auto-labelling policies, and dlp policies.
foreach ($label in $labels) {

    Write-Log -Message "Enumerating: $($label.Identifier)" -Level 'Success'
    
    # Configure the sensitivity labels.
    Assert-EPMSLabel `
        -DisplayName $label.LabelDisplayName `
        -Tooltip $label.Tooltip `
        -DocumentMarkingText $label.DocumentMarkingText `
        -Hierarchy $label.Hierarchy `
        -ParentLabelDisplayName $label.ParentLabel       

    if (-not($label.Hierarchy -eq 'IsParent')) {
        
        # Configure the auto-labeling policies and rules to apply labels to inbound mail.
        Assert-AutoSensitivityLabelPolicyAndRule `
            -Identifier $label.Identifier `
            -LabelDisplayName $label.LabelDisplayName `
            -HeaderRegex $label.HeaderRegex 

        # Configure DLP rule to intelligently append the EPMS marking into the subject line.
        Assert-DlpCompliancePolicyAndRule `
            -Identifier $label.Identifier `
            -LabelDisplayName $label.LabelDisplayName `
            -SubjectRegex $label.SubjectRegex `
            -SubjectExample $label.SubjectExample            
    }
    
    Write-Log -Message ""
}

# Enumerate the configuration and provision our client side/manual labeling policies.
foreach ($policy in $labelPolicies) {

    Write-Log -Message "Enumerating: $($policy.Identifier)" -Level 'Success'

    # Configure the sensitivity label policy.
    Assert-EPMSLabelPolicy `
        -DisplayName $policy.DisplayName `
        -Labels (($labels | Where-Object { $_.LabelPolicy -eq $policy.Identifier}).LabelDisplayName) `
        -DeployTo $policy.DeployTo

    Write-Log -Message ""

}

# Create the ETR to strip encryption for mail send to trusted domains.
Assert-DecryptionTransportRule -DisplayName 'EPMS - Strip encryption for outgoing emails and attachments' -TrustedDomains $authorisedDomains

# Disconnect!
Assert-ServiceConnection -Disconnect