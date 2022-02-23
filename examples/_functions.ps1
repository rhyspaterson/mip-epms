
function Assert-ServiceConnection {
    param(
        [string] $CertificateThumbprint,
        [string] $AppId,
        [string] $Tenant,
        [switch] $Disconnect
    )

    Write-Host "Removing any existing Exchange Online connections."

    Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue

    if ($disconnect) { return }

    # Requires WinRM basic configuration enabled on the client, assumes Windows currently
    if (-not (Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client' -Name 'AllowBasic')) {
        throw "WinRM based auth is not configured."
    }

    Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue

    try {

        Import-Module ExchangeOnlineManagement -ErrorAction Stop

        Write-Host "Establishing connection to '$Tenant' via certificate '$CertificateThumbprint' and app registration '$AppId'."

        # Connect EOL
        Connect-ExchangeOnline -CertificateThumbprint $CertificateThumbprint -AppID $AppId -Organization $Tenant -ShowBanner:$false -ShowProgress:$false

        # Connect SCC, https://github.com/MicrosoftDocs/office-docs-powershell/issues/6716
        Connect-ExchangeOnline -CertificateThumbprint $CertificateThumbprint -AppID $AppId -Organization $Tenant -ShowBanner:$false -ShowProgress:$false -ConnectionURI "https://ps.compliance.protection.outlook.com/powershell-liveid/"

    } catch {
        throw "Failed to connect to Exchange Online and the SCC ($_.Exception)"
    }

}
function Assert-EPMSLabel {
    param(
        [string] $DisplayName,
        [string] $Tooltip,
        [string] $ParentLabelDisplayName,
        [switch] $IsParet
      )

        # Check for existance.
        if ($label = Get-Label | Where-Object { ($_.DisplayName -eq $DisplayName) -and ($_.Mode -ne 'PendingDeletion') }) {
            Write-Warning "Existing label '$DisplayName' detected. Skipping modifications."
            return
        }
        
        # If it's a parent label for visual purposes only, configure the essentials.
        if ($IsParet) {

            Write-Host "Creating parent label '$displayName'" 

            $label = New-Label `
                -DisplayName $DisplayName `
                -Name $(New-Guid) `
                -Comment 'Provides EPMS support in Microsoft 365' `
                -ContentType 'File, Email, Site, UnifiedGroup, PurviewAssets'            

        } else {
            
            Write-Host "Creating functional label '$displayName'"

            # Configure a fully fledged label.
            $label = New-Label `
                -DisplayName $DisplayName `
                -Name $(New-Guid) `
                -Comment 'Provides EPMS support in Microsoft 365' `
                -Tooltip $Tooltip `
                -ApplyContentMarkingFooterEnabled $true `
                -ApplyContentMarkingFooterAlignment 'Center' `
                -ApplyContentMarkingFooterText $DisplayName `
                -ApplyContentMarkingHeaderEnabled $true `
                -ApplyContentMarkingHeaderAlignment 'Center' `
                -ApplyContentMarkingHeaderText $DisplayName `
                -ContentType 'File, Email, Site, UnifiedGroup, PurviewAssets'
        
        }

        if ($ParentLabelDisplayName) {
            $parentLabel = Get-Label | Where-Object { ($_.DisplayName -eq $ParentLabelDisplayName) -and ($_.Mode -ne 'PendingDeletion') }
            Write-Host "Set parent label for '$($label.displayName)' to '$($parentLabel.displayName)'"
            
            Set-Label -Identity $($label.Guid) -ParentId $parentLabel.Guid
        }
}


function Assert-AutoSensitivityLabelPolicyAndRule {
    param(
        [string]$Identifier,
        [string]$LabelDisplayName,
        [string]$HeaderRegex
    )
    
    Write-Host "Configuring auto-labeling for '$($LabelDisplayName)'."

    # Check for existance
    $deployedLabel = Get-Label | Where-Object { ($_.DisplayName -eq $LabelDisplayName) -and ($_.Mode -ne 'PendingDeletion') }
            
    if (-not($deployedLabel)) {
        Throw "Could not get the deployed label details."
    }

    $policyName = "Auto-label '$($Identifier)' mail" # 64 characters, max
    $ruleName = "Detect x-header for '$($Identifier)'" # 64 characters, max    

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
        -HeaderMatchesPatterns @{"x-protective-marking" =  $HeaderRegex} `
        -Workload "Exchange" `
        -Policy "$policyName"
}

function Assert-DecryptionTransportRule {
    param(
        [string]
        $DisplayName,
        [string[]]
        $TrustedDomains
    )

    If (Get-TransportRule -Identity $DisplayName) {
        Write-Host "Transport rule '$DisplayName' exists, updating."
        Set-TransportRule `
            -Identity $DisplayName `
            -FromScope 'InOrganization' `
            -RecipientDomainIs $TrustedDomains `
            -RemoveOMEv2 $true `
            -RemoveRMSAttachmentEncryption $true                
    } else {
        Write-Host "Creating new transport rule '$DisplayName'."
        New-TransportRule `
            -Name $DisplayName `
            -FromScope 'InOrganization' `
            -RecipientDomainIs $TrustedDomains `
            -RemoveOMEv2 $true `
            -RemoveRMSAttachmentEncryption $true    
    }
}


# Wild, be careful.
function Remove-AllLabelsAndPolicies {

    $policies = Get-AutoSensitivityLabelPolicy | Where-Object { $_.mode -ne 'PendingDeletion' }
    if ($policies) {
        Write-Warning "Removing all $($policies.Count) policies"
        $policies | Remove-AutoSensitivityLabelPolicy -Confirm:$true
    } else {
        Write-Host "No policies to delete."
    }

    $labels = Get-Label | Where-Object { $_.mode -ne 'PendingDeletion' }
    if ($labels) {
        Write-Warning "Removing all $($labels.Count) labels"
        $labels | Remove-Label -Confirm:$true
    } else {
        Write-Host "No labels to delete."
    }  
}