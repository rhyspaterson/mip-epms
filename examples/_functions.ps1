
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
        # Connect-ExchangeOnline -CertificateThumbprint $CertificateThumbprint -AppID $AppId -Organization $Tenant -ShowBanner:$false -ShowProgress:$false

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
        [string] $Hierarchy,
        [string] $ParentLabelDisplayName
      )
    # Check for existance.
    if ($label = Get-Label | Where-Object { ($_.DisplayName -eq $DisplayName) -and ($_.Mode -ne 'PendingDeletion') }) {
        Write-Warning "Existing label '$DisplayName' detected. Skipping modifications."
        return
    }

    # If it's a parent label for visual purposes only, configure the essentials.
    if ($Hierarchy -eq 'IsParent') {
       
        Write-Host "Creating parent label '$DisplayName'" 

        $label = New-Label `
            -DisplayName $DisplayName `
            -Name $(New-Guid) `
            -Comment 'Provides EPMS support in Microsoft 365' `
            -Tooltip $Tooltip `
            -ContentType 'File, Email, Site, UnifiedGroup, PurviewAssets'            

    # Else it's in the root with no parent or is a child label with a parent, so configure a full label.
    } else {
        
        Write-Host "Creating root or child label '$DisplayName'"

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

    # Finally, assign a parent label to the child, if required.
    if ($Hierarchy -eq 'HasParent') {
        Write-Host "`tSetting parent label for '$($label.displayName)' to '$($ParentLabelDisplayName)'"
        $parentLabel = Get-Label | Where-Object { ($_.DisplayName -eq $ParentLabelDisplayName) -and ($_.Mode -ne 'PendingDeletion') }
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

    # Ensure the sensitivity label we are linking the policy to exists.
    $deployedLabel = Get-Label | Where-Object { ($_.DisplayName -eq $LabelDisplayName) -and ($_.Mode -ne 'PendingDeletion') }
            
    if (-not($deployedLabel)) {
        Throw "Could not get the deployed label details."
    }

    $policyName = "Auto-label '$($Identifier)' mail" # 64 characters, max
    $ruleName = "Detect x-header for '$($Identifier)'" # 64 characters, max    

    # Check if the auto-labeling policy already exists, updating if it so.    
    if($policy = Get-AutoSensitivityLabelPolicy | Where-Object { ($_.Name -eq $policyName) }) {
        if ($policy.Mode -eq 'PendingDeletion') {
            Write-Warning "`tAuto-labeling policy '$policyName' exists in a pending deletion state. Cannot update."
            return
        } else {
            Write-Host "`tAuto-labeling policy '$policyName' exists, updating."
            Set-AutoSensitivityLabelPolicy `
                -Identity $policyName `
                -ApplySensitivityLabel $deployedLabel.Guid `
                -AddExchangeLocation 'All' `
                -Mode 'TestWithoutNotifications' `
                -OverwriteLabel $true `
                | Out-Null            
        }
    } else {
        # Thrash out a new one.
        Write-Host "Creating auto-labeling policy: $policyName"

        New-AutoSensitivityLabelPolicy `
            -Name $policyName `
            -ApplySensitivityLabel $deployedLabel.Guid `
            -ExchangeLocation 'All' `
            -Mode 'TestWithoutNotifications' `
            -OverwriteLabel $true `
            | Out-Null
    }

    # To do: add in existance checks
    Write-Host "`tCreating auto-labeling policy rule: $ruleName"

    $rule = New-AutoSensitivityLabelRule `
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


# Debugging.
function Remove-AllLabelsAndPolicies {

    # TO DO, check if there are children, and remove them first.

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