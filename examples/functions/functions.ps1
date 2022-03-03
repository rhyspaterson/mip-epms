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

function Assert-GraphConnection {
    param(
        [string] $CertificateThumbprint,
        [string] $AppId,
        [string] $Tenant
    ) 
    
    try {

        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

        Write-Log -Message "Establishing connection to '$Tenant'."
        Write-Log -Message "`tCertificate: '$CertificateThumbprint'"
        Write-Log -Message "`tApplication registration: '$AppId'."

        # Connect Graph
        Connect-MgGraph `
            -ClientID $AppId `
            -TenantId $Tenant `
            -CertificateThumbprint $CertificateThumbprint 
        
        Select-MgProfile -Name "beta"   

    } catch {
        Write-Log -Message "Failed to connect to Graph ($_.Exception)" -Level 'Error'
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
        Write-Log -Message "Existing label with name '$DisplayName' detected. Skipping." -Level 'Warning'
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

function Assert-EPMSLabelPolicy {
    param(
        [string] $DisplayName,
        [array] $Labels,
        [boolean] $Mandatory,
        [string] $DeployTo 
    )

    [array] $labelGuids = $null

     # Check each of the labels we need to add to the policies exist
    ForEach ($label in $Labels) {
        if (-not($label = Get-Label | Where-Object { ($_.DisplayName -eq $label) -and ($_.Mode -ne 'PendingDeletion') })) {
            Write-Log -Message "Could not find label '$label'." -Level 'Warning'
            throw
        } else {
            $labelGuids += $label.Name
        }
    }

    # Build the complex settings objects
    $complexSettings = @{
        powerbimandatory = $true
        requiredowngradejustification = $true
        siteandgroupmandatory = $true
        mandatory = $true
        disablemandatoryinoutlook = $false
    }

    # Check if the auto-labelling policy already exists, updating if it so.    
    if($policy = Get-LabelPolicy  | Where-Object { ($_.Name -eq $DisplayName) }) {
        if ($policy.Mode -eq 'PendingDeletion') {
            Write-Log -Message "Label policy '$DisplayName' exists in a pending deletion state. Cannot update." -Level 'Warning'
            return
        } else {
            Write-Log -Message "Label policy '$DisplayName' exists, updating."

            if ($DeployTo -eq 'All') {
                Set-LabelPolicy `
                    -Identity $DisplayName `
                    -Settings $complexSettings `
                    | Out-Null
            } else {                
                Set-LabelPolicy `
                    -Identity $DisplayName `
                    -Settings $complexSettings `
                    | Out-Null
            }
        }
    } else {

        Write-Log -Message "Creating label policy: $DisplayName"

        if ($DeployTo -eq 'All') {
            New-LabelPolicy `
                -Name $DisplayName `
                -Labels $labelGuids `
                -Settings $complexSettings `
                -ExchangeLocation 'All' `
                | Out-Null
        } else {
            if (-not($distributionGroup = Get-DistributionGroup -Identity $DeployTo -ErrorAction SilentlyContinue)) {
                Write-Log -Message "Could not find distribution group '$DeployTo', creating." -Level 'Warning'
                $distributionGroup = New-DistributionGroup -Name $DeployTo -Type "Security"
            }
            New-LabelPolicy `
                -Name $DisplayName `
                -Settings $complexSettings `
                -Labels $labelGuids `
                -ModernGroupLocation $distributionGroup.PrimarySmtpAddress `
                | Out-Null        
        }
    }
}

function Assert-AutoSensitivityLabelPolicyAndRule {
    param(
        [string]$Identifier,
        [string]$LabelDisplayName,
        [string]$HeaderRegex
    )
    
    Write-Log -Message "Configuring auto-labelling for '$($LabelDisplayName)'."

    # Ensure the sensitivity label we are linking the policy to exists.
    $deployedLabel = Get-Label | Where-Object { ($_.DisplayName -eq $LabelDisplayName) -and ($_.Mode -ne 'PendingDeletion') }
            
    if (-not($deployedLabel)) {
        Throw "Could not get the deployed label details."
    }

    $policyName = "Auto-label '$($Identifier)' mail" # 64 characters, max
    $ruleName = "Detect x-header for '$($Identifier)'" # 64 characters, max    

    # Check if the auto-labelling policy already exists, updating if it so.    
    if($policy = Get-AutoSensitivityLabelPolicy | Where-Object { ($_.Name -eq $policyName) }) {
        if ($policy.Mode -eq 'PendingDeletion') {
            Write-Log -Message "Auto-labelling policy '$policyName' exists in a pending deletion state. Cannot update." -Level 'Warning'
            return
        } else {
            Write-Log -Message "Auto-labelling policy '$policyName' exists, updating."
            Set-AutoSensitivityLabelPolicy `
                -Identity $policyName `
                -ApplySensitivityLabel $deployedLabel.Guid `
                -AddExchangeLocation 'All' `
                -OverwriteLabel $true `
                | Out-Null            
        }
    } else {
        # Thrash out a new one.
        Write-Log -Message "Creating auto-labelling policy: $policyName"

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
            Write-Log -Message "Auto-labelling rule '$ruleName' exists in a pending deletion state. Cannot update." -Level 'Warning'
            return
        } elseif ($policy.Mode -eq 'Enable') {
            Write-Log -Message "The associated auto-labelling parent policy '$policyName' is in 'Enable' mode. Cannot update the associated rule unless the parent policy is in test mode. Skipping. " -Level 'Warning'
            return
        } else {
            # Note that we can't changed the linked ParentPolicyName without deleting and re-creating the rule.
            if ($rule.ParentPolicyName -eq $policyName) {
                Write-Log -Message "Auto-labelling rule '$ruleName' exists, updating."
                Set-AutoSensitivityLabelRule `
                    -Identity $ruleName `
                    -HeaderMatchesPatterns @{"x-protective-marking" =  $HeaderRegex} `
                    -Workload "Exchange" 
            } else {
                Write-Log -Message "Auto-labelling rule '$ruleName' exists, but is not linked to '$policyName'. Cannot update." -Level 'Warning'
                return                
            }
        }
    } else {
        # Thrash out a new one.
        Write-Log -Message "Creating auto-labelling policy rule: $ruleName"

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

    if (-not($deployedLabel)) {
        Throw "Could not get the deployed label details."
    }

    $policyName = "Subject append '$identifier' mail" # max 64 characters
    $ruleName = "If '$LabelDisplayName', append subject" # max 64 characters      

    # Check if the auto-labelling policy already exists, updating if it so.    
    if(Get-DlpCompliancePolicy | Where-Object { ($_.Name -eq $policyName) }) {
        
        Write-Log -Message "Compliance policy '$policyName' exists, updating."

        Set-DlpCompliancePolicy `
            -Identity $policyName `
            -Mode 'TestWithoutNotifications' | Out-Null        

    } else {

        Write-Log -Message "Creating compliance policy '$policyName'."

        New-DlpCompliancePolicy `
            -Name $policyName `
            -ExchangeLocation 'All' `
            -Mode 'TestWithoutNotifications' | Out-Null

    }

    # Build the complex rule objects
    $complexSensitiveInformationRule = @(
        @{
            operator = "And"
            groups = @(
                @{
                    operator="Or"
                    name="Default"
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
    
    $complexModifySubjectRule = @{
        patterns = "{\[SEC=.*?\]}"
        ReplaceStrategy = 'Append' # Remove matches and append replacement text to subject
        SubjectText = " $SubjectExample" # Note the additional whitepsace at the prefix of the protective marking
    }

    # Check if the compliance rule already exists, updating if it so.    
    if($rule = Get-DlpComplianceRule | Where-Object { ($_.Name -eq $ruleName) }) {

        if ($rule.Mode -eq 'PendingDeletion') {
            Write-Log -Message "Compliance rule '$ruleName' exists in a pending deletion state. Cannot update." -Level 'Warning'
            return
        } else {        
            # Note that we can't changed the linked ParentPolicyName without deleting and re-creating the rule.
            if ($rule.ParentPolicyName -eq $policyName) {
            Write-Log -Message "Compliance rule '$ruleName' exists, updating."

            Set-DlpComplianceRule `
                -Identity $ruleName `
                -ContentContainsSensitiveInformation $complexSensitiveInformationRule `
                -ModifySubject $complexModifySubjectRule `
            } else {
                Write-Log -Message "Compliance rule '$ruleName' exists, but is not linked to '$policyName'. Cannot update." -Level 'Warning'
                return                
            }
        }
    } else {
        # Thrash out a new one.
        Write-Log -Message "Creating compliance rule '$ruleName'."

        New-DlpComplianceRule `
            -Name $ruleName `
            -Policy $policyName `
            -ContentContainsSensitiveInformation $complexSensitiveInformationRule `
            -ModifySubject $complexModifySubjectRule `
            | Out-Null
    }
}

function Assert-HeaderTransportRule {
    param(
        [string] $Identifier,
        [string] $LabelDisplayName,
        [string] $HeaderExample
    )

    Write-Log -Message "Configuring x-protective-marking header insertion for '$($LabelDisplayName)'."
    
    # Ensure the sensitivity label we are linking the policy to exists.
    $deployedLabel = Get-SensitivityLabelByDisplayName -DisplayName $LabelDisplayName -ThrowIfMissing

    if (-not($deployedLabel)) {
        Throw "Could not get the deployed label details."
    }

    $ruleName = "EPMS - x-header for label '$($deployedLabel.guid)'" # max 64 characters
    $comment = "This transport rule writes the relevant x-protective-marking header when mail flagged with the internal '$($deployedLabel.DisplayName)' sensitivity label is detected."

    If (Get-TransportRule -Identity $ruleName -ErrorAction SilentlyContinue) {
        Write-Log -Message "Transport rule '$ruleName' exists, updating."
        Set-TransportRule `
            -Identity $ruleName `
            -HeaderMatchesMessageHeader 'msip_labels' `
            -HeaderMatchesPatterns "(?im)$($deployedLabel.guid)" `
            -SetHeaderName 'x-protective-marking' `
            -SetHeaderValue $HeaderExample `
            -Comments $comment
            | Out-Null
    } else {
        Write-Log -Message "Creating new transport rule '$ruleName'."
        New-TransportRule `
            -Name $ruleName `
            -HeaderMatchesMessageHeader 'msip_labels' `
            -HeaderMatchesPatterns "(?im)$($deployedLabel.guid)" `
            -SetHeaderName 'x-protective-marking' `
            -SetHeaderValue $HeaderExample `
            -Comments $comment `
            -Mode 'Audit' `
            | Out-Null
    }
}

function Assert-DecryptionTransportRule {
    param(
        [string] $DisplayName,
        [string[]] $TrustedDomains
    )

    If (Get-TransportRule -Identity $DisplayName -ErrorAction SilentlyContinue) {
        Write-Log -Message "Transport rule '$DisplayName' exists, updating."
        Set-TransportRule `
            -Identity $DisplayName `
            -FromScope 'InOrganization' `
            -RecipientDomainIs $TrustedDomains `
            -RemoveOMEv2 $true `
            -RemoveRMSAttachmentEncryption $true `
            | Out-Null           
    } else {
        Write-Log -Message "Creating new transport rule '$DisplayName'."
        New-TransportRule `
            -Name $DisplayName `
            -FromScope 'InOrganization' `
            -RecipientDomainIs $TrustedDomains `
            -RemoveOMEv2 $true `
            -RemoveRMSAttachmentEncryption $true `
            -Mode 'Audit' `
            | Out-Null
    }
}

# Debugging.

function Enable-AllLabelsAndPolicies {
    Get-DlpCompliancePolicy | Set-DlpCompliancePolicy -Mode 'Enable'
    Get-AutoSensitivityLabelPolicy | Set-AutoSensitivityLabelPolicy -Mode 'Enable'
    Get-TransportRule | Set-TransportRule -Mode 'Enable'
}

function Disable-AllLabelsAndPolicies {
    Get-DlpCompliancePolicy | Set-DlpCompliancePolicy -Mode 'TestWithoutNotifications'
    Get-AutoSensitivityLabelPolicy | Set-AutoSensitivityLabelPolicy -Mode 'TestWithoutNotifications'
    Get-TransportRule | Set-TransportRule -Mode 'Audit'
}


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
        Write-Log -Message "`tRemoving $($autoLabelPolicies.Count) auto-labelling policies." -Level 'Warning'
        $autoLabelPolicies | Remove-AutoSensitivityLabelPolicy -Confirm:$true
    } else {
        Write-Log -Message "No auto-labling policies to delete."
    }

    $labelPolicies = Get-LabelPolicy | Where-Object { $_.mode -ne 'PendingDeletion' }
    if ($labelPolicies) {
        Write-Log -Message "`tRemoving $($labelPolicies.Count) manual labeling policies." -Level 'Warning'
        $labelPolicies | Remove-LabelPolicy -Confirm:$true
    } else {
        Write-Log -Message "No manual label policies to delete."
    }

    # TO DO, (Get-Label).ParentId.Guid
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
    $labelPolicies = Get-LabelPolicy | Where-Object { $_.mode -eq 'PendingDeletion' }
    $labels = Get-Label | Where-Object { $_.mode -eq 'PendingDeletion' }

    Write-Log -Message "Pending deletion: $($compliancePolicies.count) compliance policies, $($autoLabelPolicies.count) auto-label policies, $($labels.count) labels."

    if (($compliancePolicies.count -ne 0) -or ($autoLabelPolicies.count -ne 0) -or ($labelPolicies.count -ne 0) -or ($labels.count -ne 0)) {
        return 'pending'
    } else {
        return 'completed'
    }
}