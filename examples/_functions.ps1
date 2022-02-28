function Write-Log {
    Param(
        [string] $Message,
        [string] $Level
    )

    $timeStamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

    if ($Level) {

        if ($Level -eq 'warning') {
            $colour = 'Yellow'
        }
        if ($Level -eq 'error') {
            $colour = 'Red'
        }
        if ($Level -eq 'success') {
            $colour = 'Green'
        }
    
        $initialColour = $host.ui.RawUI.ForegroundColor
        $host.UI.RawUI.ForegroundColor = $colour
        Write-Output "$timeStamp`t$Message"
        $host.UI.RawUI.ForegroundColor = $initialColour
    
    }
    else {
        Write-Output "$timeStamp`t$Message"
    }   
}

function Assert-ServiceConnection {
    param(
        [string] $CertificateThumbprint,
        [string] $AppId,
        [string] $Tenant,
        [switch] $Disconnect
    )

    Write-Log "Removing any existing Exchange Online connections."

    Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue

    if ($disconnect) { return }

    # Requires WinRM basic configuration enabled on the client, assumes Windows currently
    if (-not (Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client' -Name 'AllowBasic')) {
        Write-Log -Message "WinRM based auth is not configured." -Level 'Error'
        throw
    }

    Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue

    try {

        Import-Module ExchangeOnlineManagement -ErrorAction Stop

        Write-Log -Message "Establishing connection to '$Tenant'."
        Write-Log -Message "`tCertificate: '$CertificateThumbprint'"
        Write-Log -Message "`tApplication registration: '$AppId'."

        # Connect EOL
        Connect-ExchangeOnline -CertificateThumbprint $CertificateThumbprint -AppID $AppId -Organization $Tenant -ShowBanner:$false -ShowProgress:$false | Out-Null

        # Connect SCC, https://github.com/MicrosoftDocs/office-docs-powershell/issues/6716
        Connect-ExchangeOnline -CertificateThumbprint $CertificateThumbprint -AppID $AppId -Organization $Tenant -ShowBanner:$false -ShowProgress:$false -ConnectionURI "https://ps.compliance.protection.outlook.com/powershell-liveid/" | Out-Null

    } catch {
        Write-Log -Message "Failed to connect to Exchange Online and the SCC ($_.Exception)" -Level 'Error'
        throw        
    }

}

function Get-SensitivityLabelByDisplayName {
    Param(
        [string] $DisplayName,
        [switch] $ThrowIfMissing
    )

    $label = Get-Label | Where-Object { ($_.DisplayName -eq $DisplayName) -and ($_.Mode -ne 'PendingDeletion') }

    if ($label) {
        return $label
    } else {
        if ($ThrowIfMissing) {
            Write-Log -Message "Sensitivity label '$DisplayName' does not exist." -Level 'Error'
            throw
        }
        return $false
    }
}
function Assert-EPMSLabel {
    param(
        [string] $DisplayName,
        [string] $Tooltip,
        [string] $DocumentMarkingText,
        [string] $Hierarchy,
        [string] $ParentLabelDisplayName
      )
    # Check for existance.
    if ($label = Get-Label | Where-Object { ($_.DisplayName -eq $DisplayName) -and ($_.Mode -ne 'PendingDeletion') }) {
        Write-Log -Message "Existing label '$DisplayName' detected, skipping modifications." -Level 'Warning'
        return
    }

    # If it's a parent label for visual purposes only, configure the essentials.
    if ($Hierarchy -eq 'IsParent') {
       
        Write-Log -Message "Creating parent label '$DisplayName'." 

        $label = New-Label `
            -DisplayName $DisplayName `
            -Name $(New-Guid) `
            -Comment 'Provides EPMS support in Microsoft 365' `
            -Tooltip $Tooltip `
            -ContentType 'File, Email, Site, UnifiedGroup, PurviewAssets'            

    # Else it's in the root with no parent or is a child label with a parent, so configure a full label.
    } else {
        
        Write-Log -Message "Creating root or child label '$DisplayName'."

        # Configure a fully fledged label.
        $label = New-Label `
            -DisplayName $DisplayName `
            -Name $(New-Guid) `
            -Comment 'Provides EPMS support in Microsoft 365' `
            -Tooltip $Tooltip `
            -ApplyContentMarkingFooterEnabled $true `
            -ApplyContentMarkingFooterAlignment 'Center' `
            -ApplyContentMarkingFooterText $DocumentMarkingText `
            -ApplyContentMarkingFooterFontSize 12 `
            -ApplyContentMarkingFooterFontColor '#ef233c' `
            -ApplyContentMarkingHeaderEnabled $true `
            -ApplyContentMarkingHeaderAlignment 'Center' `
            -ApplyContentMarkingHeaderText $DocumentMarkingText `
            -ApplyContentMarkingHeaderFontSize 12 `
            -ApplyContentMarkingHeaderFontColor '#ef233c' `
            -ContentType 'File, Email, Site, UnifiedGroup, PurviewAssets'
    }

    # Finally, assign a parent label to the child, if required.
    if ($Hierarchy -eq 'HasParent') {
        Write-Log -Message "Setting parent label for '$($label.displayName)' to '$($ParentLabelDisplayName)'."
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
    
    Write-Log -Message "Configuring auto-labeling for '$($LabelDisplayName)'."

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
            Write-Log -Message "Auto-labeling policy '$policyName' exists in a pending deletion state. Cannot update." -Level 'Warning'
            return
        } else {
            Write-Log -Message "Auto-labeling policy '$policyName' exists, updating."
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
        Write-Log -Message "Creating auto-labeling policy: $policyName"

        New-AutoSensitivityLabelPolicy `
            -Name $policyName `
            -ApplySensitivityLabel $deployedLabel.Guid `
            -ExchangeLocation 'All' `
            -Mode 'TestWithoutNotifications' `
            -OverwriteLabel $true `
            | Out-Null
    }

    if($rule = Get-AutoSensitivityLabelRule | Where-Object { ($_.Name -eq $ruleName) }) {
        if ($rule.Mode -eq 'PendingDeletion') {
            Write-Log -Message "Auto-labeling rule '$ruleName' exists in a pending deletion state. Cannot update." -Level 'Warning'
            return
        } else {
            # Note that we can't changed the linked ParentPolicyName without deleting and re-creating the rule.
            if ($rule.ParentPolicyName -eq $policyName) {
                Write-Log -Message "Auto-labeling rule '$ruleName' exists, updating."
                Set-AutoSensitivityLabelRule `
                    -Identity $ruleName `
                    -HeaderMatchesPatterns @{"x-protective-marking" =  $HeaderRegex} `
                    -Workload "Exchange" 
            } else {
                Write-Log -Message "Auto-labeling rule '$ruleName' exists, but is not linked to '$policyName'. Cannot update." -Level 'Warning'
                return                
            }
        }
    } else {
        # Thrash out a new one.
        Write-Log -Message "Creating auto-labeling policy rule: $ruleName"

        New-AutoSensitivityLabelRule `
            -Name $ruleName `
            -HeaderMatchesPatterns @{"x-protective-marking" =  $HeaderRegex} `
            -Workload "Exchange" `
            -Policy "$policyName" | Out-Null
    }

}

function Assert-DlpCompliancePolicyAndRule {
    param(
        [string] $Identifier,
        [string] $LabelDisplayName,
        [string] $SubjectRegex,
        [string] $SubjectExample
    )

    Write-Log -Message "Configuring intelligent auto-subject append for '$($LabelDisplayName)'."
    
    # Ensure the sensitivity label we are linking the policy to exists.
    $deployedLabel = Get-SensitivityLabelByDisplayName -DisplayName $LabelDisplayName -ThrowIfMissing
            
    $policyName = "Subject append '$identifier' mail" # max 64 characters
    $ruleName = "If '$LabelDisplayName', append subject" # max 64 characters      

    Write-Log -Message "Creating compliance policy '$policyName'."

    New-DlpCompliancePolicy `
        -Name $policyName `
        -ExchangeLocation 'All' `
        -Mode 'TestWithoutNotifications' | Out-Null

    $complexRule = @(
        @{
            operator = "And"; 
            groups = @(
                @{
                    operator="Or";
                    name="Default";
                    labels = @(
                        @{
                            name="$($deployedLabel.Name)";
                            type="Sensitivity"
                        } 
                    )
                }
            )
        }
    )
    
    Write-Log -Message "Creating compliance rule '$ruleName'."

    # Change this to modify subject once I have a tenant with the feature enabled
    New-DlpComplianceRule `
        -Name $ruleName `
        -Policy $policyName `
        -PrependSubject $SubjectExample `
        -ContentContainsSensitiveInformation $complexRule `
        | Out-Null
}
function Assert-DecryptionTransportRule {
    param(
        [string]
        $DisplayName,
        [string[]]
        $TrustedDomains
    )

    If (Get-TransportRule -Identity $DisplayName -ErrorAction SilentlyContinue) {
        Write-Log -Message "Transport rule '$DisplayName' exists, updating."
        Set-TransportRule `
            -Identity $DisplayName `
            -FromScope 'InOrganization' `
            -RecipientDomainIs $TrustedDomains `
            -RemoveOMEv2 $true `
            -RemoveRMSAttachmentEncryption $true                
    } else {
        Write-Log -Message "Creating new transport rule '$DisplayName'."
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

    $compliancePolicies = Get-DlpCompliancePolicy | Where-Object { $_.mode -ne 'PendingDeletion' }
    if ($compliancePolicies) {
        Write-Log -Message "Removing $($compliancePolicies.Count) compliance policies." -Level 'Warning'
        $compliancePolicies | Remove-DlpCompliancePolicy -Confirm:$true
    } else {
        Write-Log -Message "No DLP compliance policies to delete."
    }

    $autoLabelPolicies = Get-AutoSensitivityLabelPolicy | Where-Object { $_.mode -ne 'PendingDeletion' }
    if ($autoLabelPolicies) {
        Write-Log -Message "`tRemoving $($autoLabelPolicies.Count) auto-labeling policies." -Level 'Warning'
        $autoLabelPolicies | Remove-AutoSensitivityLabelPolicy -Confirm:$true
    } else {
        Write-Log -Message "No auto-labling policies to delete."
    }

    # TO DO, check if there are children, and remove them first.
    # (Get-Label).ParentId.Guid
    [array] $skippedLabels = $null
    $labels = Get-Label | Where-Object { $_.mode -ne 'PendingDeletion' }
    if ($labels) {
        Write-Log -Message "Removing $($labels.Count) sensitivity labels." -Level 'Warning'

        ForEach ($label in $labels) {
            if ($null -ne $label.ParentId.Guid) {
                # Label has no parent, we can delete it.
                $label | Remove-Label -Confirm:$true
            } else {
                # Store it for a subsequent deletion.
                $skippedLabels += $label.name
            }
        }
        # Trash the skipped labels now that the childs are deleted.
        $skippedLabels | ForEach-Object {
            Remove-Label -Identity $_ -Confirm:$true
        }

    } else {
        Write-Log -Message "No sensitivity labels to delete."
    }  
}

function Get-PendingLabelAndPolicyDeletionStatus {

    $compliancePolicies = Get-DlpCompliancePolicy | Where-Object { $_.mode -eq 'PendingDeletion' }
    $autoLabelPolicies = Get-AutoSensitivityLabelPolicy | Where-Object { $_.mode -eq 'PendingDeletion' }
    $labels = Get-Label | Where-Object { $_.mode -eq 'PendingDeletion' }

    Write-Log -Message "Pending deletion: $($compliancePolicies.count) compliance policies, $($autoLabelPolicies.count) auto-label policies, $($labels.count) labels."

    if (($compliancePolicies.count -ne 0) -or ($autoLabelPolicies.count -ne 0) -or ($labels.count -ne 0)) {
        return 'pending'
    } else {
        return 'completed'
    }
}