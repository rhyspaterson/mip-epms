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

    Write-Log "Removing any existing Graph connections."

    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    
    try {

        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

        Write-Log -Message "Establishing connection to '$Tenant'."
        Write-Log -Message "`tCertificate: '$CertificateThumbprint'"
        Write-Log -Message "`tApplication registration: '$AppId'."

        # Connect Graph
        Connect-MgGraph `
            -ClientID $AppId `
            -TenantId $Tenant `
            -CertificateThumbprint $CertificateThumbprint `

        Write-Log -Message "Scopes: $((Get-MgContext).scopes)"
        
        Select-MgProfile -Name "beta"   

    } catch {
        Write-Log -Message "Failed to connect to Graph ($_.Exception)" -Level 'Error'
        throw      
    }  
        
}

function Get-SensitivityLabelByDisplayName {
    Param(
        [string] $DisplayName,
        [switch] $ExcludeParentLabels,
        [switch] $ParentLabelsOnly
    )  
    <#
    There is no easy way to distinguish the difference between a parent label with children, and a normal root label without children by looking at the label itself.
    All the properties are the same. There is an internal IsParent property which looks great, but as far as I can tell it doesn't work, which means we get creative.
    If we look at all labels, any with a ParentId property can easily be considered child labels. We are inferring that the label is a child label based upon the fact it has a parent.
    Therefore, the label guid listed in the ParentId property must be considered a parent label. This allows us to then filter in or out those ParentId guids based on our requirements.
    #>

    # Get all labels.
    $allLabels = Get-Label | Where-Object { $_.Mode -ne 'PendingDeletion' }

    # Record any ParentId attributes.
    $parentIds = ($allLabels | Where-Object { $null -ne $_.ParentId}).ParentId | Get-Unique

    # We want to exclude parent labels from our query.
    if ($ExcludeParentLabels) {

        # Remove labels with these GUIDs from our object.
        $filteredLabels = $allLabels | Where-Object { $_.Guid -notin $parentIds}

        # Return the label with a given display name from our filtered result.
        return $filteredLabels | Where-Object { $_.DisplayName -eq $DisplayName }
    } 

    # We want to include only parent labels in our query.
    if ($ParentLabelsOnly) {

        # Remove labels with these GUIDs from our object.
        $filteredLabels = $allLabels | Where-Object { $_.Guid -in $parentIds}

        # Return the label with a given display name from our filtered result.
        return $filteredLabels | Where-Object { $_.DisplayName -eq $DisplayName }
    } 

    # Otherwise, run our search across all labels.
    return Get-Label | Where-Object { ($_.DisplayName -eq $DisplayName) -and ($_.Mode -ne 'PendingDeletion') }

}

function Assert-EPMSLabel {
    param(
        [string] $LabelDisplayName,
        [string] $Tooltip,
        [string] $DocumentMarkingText,
        [string] $Hierarchy,
        [string] $ParentLabelDisplayName
      )
    
    # If it's a parent label for visual purposes only, configure the essentials.
    if ($Hierarchy -eq 'IsParent') {
        
        # Check for existance. We will look for parent labels with the placeholder '<label> [Parent]' and end state '<label>' display names.
        $renamedDisplayName = $LabelDisplayName -replace "\s\[Parent\]$", ""

        $deployedLabel = Get-SensitivityLabelByDisplayName -DisplayName $LabelDisplayName -ParentLabelsOnly
        $deployedLabelRenamed = Get-SensitivityLabelByDisplayName  -DisplayName $renamedDisplayName -ParentLabelsOnly

        if ($deployedLabel -or $deployedLabelRenamed) {
            Write-Log -Message "Existing parent label with name '$LabelDisplayName' or '$renamedDisplayName' detected." -Level 'Warning'
            return
        }         

        Write-Log -Message "Creating parent label '$LabelDisplayName'." 

        $label = New-Label `
            -DisplayName $LabelDisplayName `
            -Name $(New-Guid) `
            -Comment 'Provides EPMS support in Microsoft 365. This is a parent label that is used to logically group child/sublabels. It is not used to apply sensitivity.' `
            -Tooltip $Tooltip `
            -ContentType 'File, Email, Site, UnifiedGroup, PurviewAssets'            

    # Else it's in the root with no parent or is a child label with a parent, so configure a full label.
    } else {

        # Check for existance.
        $deployedLabel = Get-SensitivityLabelByDisplayName -DisplayName $LabelDisplayName

        if ($deployedLabel) {
            Write-Log -Message "Existing label with name '$LabelDisplayName' detected." -Level 'Warning'
            return
        }         

        Write-Log -Message "Creating root or child label '$LabelDisplayName'."

        # Configure a fully fledged label.
        $label = New-Label `
            -DisplayName $LabelDisplayName `
            -Name $(New-Guid) `
            -Comment 'Provides EPMS support in Microsoft 365. This is a root or child/sublabel that is used to apply sensitivity.' `
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
        Write-Log -Message "Setting parent label for '$($label.LabelDisplayName)' to '$($ParentLabelDisplayName)'."
        $parentLabel = Get-SensitivityLabelByDisplayName -DisplayName $ParentLabelDisplayName
        Set-Label -Identity $($label.Guid) -ParentId $parentLabel.Guid
    }
}

function Assert-LabelEncryption {
    param(
        [string] $LabelDisplayName,
        [string] $DeployTo
    )

    Write-Log -Message "Apply encryption to root or child label '$LabelDisplayName' for '$DeployTo'."

    # Ensure the sensitivity label we are linking the policy to exists.
    $deployedLabel = Get-SensitivityLabelByDisplayName -DisplayName $LabelDisplayName -ExcludeParentLabels

    if (-not($deployedLabel)) {
        Throw "Could not get the deployed label details for $LabelDisplayName."
    }
   
    # Ensure the distribution group we are linking the rights management to exists.
    if (-not($distributionGroup = Get-DistributionGroup -Identity $DeployTo -ErrorAction SilentlyContinue)) {
        Write-Log -Message "Could not find distribution group '$DeployTo', creating." -Level 'Warning'
        $distributionGroup = New-DistributionGroup -Name $DeployTo -Type "Security"
    }
    
    Set-Label `
        -Identity $deployedLabel.Guid `
        -EncryptionEnabled $true `
        -EncryptionContentExpiredOnDateInDaysOrNever 'Never' `
        -EncryptionOfflineAccessDays '-1' `
        -EncryptionProtectionType 'Template' `
        -EncryptionRightsDefinitions "$($distributionGroup.PrimarySmtpAddress):VIEW,VIEWRIGHTSDATA,DOCEDIT,EDIT,PRINT,EXTRACT,REPLY,REPLYALL,FORWARD,OBJMODEL"
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
        if (-not($label = Get-SensitivityLabelByDisplayName -DisplayName $label)) {
            Write-Log -Message "Could not find label '$label'." -Level 'Warning'
        } else {

            # If it does, add the guid.
            $labelGuids += $label.Guid
            
            # Add any parent labels, just in case.
            if ($null -ne $label.ParentId) {
                $labelGuids += $label.ParentId
            }
            
        }
    }

    # Clean up any duplicates.
    $labelGuids = $labelGuids | Select-Object -Unique

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
    $deployedLabel = Get-SensitivityLabelByDisplayName -DisplayName $LabelDisplayName -ExcludeParentLabels

    if (-not($deployedLabel)) {
        Throw "Could not get the deployed label details for $LabelDisplayName."
    }

    $policyName = "EPMS - Auto-label '$($Identifier)' mail" # 64 characters, max
    $ruleName = "Detect x-header for '$($Identifier)'" # 64 characters, max    

    # Check if the auto-labelling policy already exists, updating if it so.    
    if($policy = Get-AutoSensitivityLabelPolicy | Where-Object { ($_.Name -eq $policyName) }) {
        if ($policy.Mode -eq 'PendingDeletion') {
            Write-Log -Message "Auto-labelling policy '$policyName' exists in a pending deletion state. Cannot update." -Level 'Warning'
            return
        } elseif ($policy.Mode -eq 'Enable') {
            Write-Log -Message "The auto-labelling policy '$policyName' is in 'Enable' mode. Cannot update the policy unless it is in test mode. Skipping." -Level 'Warning'
            return
        } else {
            Write-Log -Message "`tAuto-labelling policy '$policyName' exists, updating."
            Set-AutoSensitivityLabelPolicy `
                -Identity $policyName `
                -ApplySensitivityLabel $deployedLabel.Guid `
                -AddExchangeLocation 'All' `
                -OverwriteLabel $true `
                | Out-Null            
        }
    } else {
        # Thrash out a new one.
        Write-Log -Message "`tCreating auto-labelling policy: '$policyName'"

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
                Write-Log -Message "`tAuto-labelling rule '$ruleName' exists, updating."
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
        Write-Log -Message "Creating auto-labelling policy rule: '$ruleName'"

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
    $deployedLabel = Get-SensitivityLabelByDisplayName -DisplayName $LabelDisplayName -ExcludeParentLabels

    $policyName = "EPMS - Subject append '$identifier' mail" # max 64 characters
    $ruleName = "EPMS - If '$identifier' label, append subject" # max 64 characters      

    # Check if the auto-labelling policy already exists, updating if it so.    
    if(Get-DlpCompliancePolicy | Where-Object { ($_.Name -eq $policyName) }) {
        
        Write-Log -Message "`tCompliance policy '$policyName' exists, updating."

        Set-DlpCompliancePolicy `
            -Identity $policyName `
            | Out-Null        

    } else {

        Write-Log -Message "`tCreating compliance policy: '$policyName'."

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
            Write-Log -Message "`tCompliance rule '$ruleName' exists in a pending deletion state. Cannot update." -Level 'Warning'
            return
        } else {        
            # Note that we can't changed the linked ParentPolicyName without deleting and re-creating the rule.
            if ($rule.ParentPolicyName -eq $policyName) {
            Write-Log -Message "`tCompliance rule '$ruleName' exists, updating."

            Set-DlpComplianceRule `
                -Identity $ruleName `
                -ContentContainsSensitiveInformation $complexSensitiveInformationRule `
                -ModifySubject $complexModifySubjectRule `
            } else {
                Write-Log -Message "`tCompliance rule '$ruleName' exists, but is not linked to '$policyName'. Cannot update." -Level 'Warning'
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

function Remove-StringFromLabelName {
    param(
        [string] $LabelDisplayName,
        [string] $RegularExpression
    )

    # Ensure the sensitivity label we are linking the policy to exists.
    $deployedLabel = Get-SensitivityLabelByDisplayName -DisplayName $LabelDisplayName

    if (-not($deployedLabel)) {
        return
    } 

    # If the label contains our regular expression string, remove it.
    if ($deployedLabel.DisplayName -match $RegularExpression) {
        Write-Log -Message "Removing '$RegularExpression' from the display name of '$($deployedLabel.DisplayName)'."
        Set-Label -Identity $($deployedLabel.Guid) -DisplayName $($deployedLabel.DisplayName -replace $RegularExpression, "")
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
    $deployedLabel = Get-SensitivityLabelByDisplayName -DisplayName $LabelDisplayName -ExcludeParentLabels

    if (-not($deployedLabel)) {
        Throw "Could not get the deployed label details."
    }    

    $ruleName = "EPMS - Insert header for '$Identifier'" # max 64 characters
    $comment = "Inserts the relevant x-protective-marking header when mail flagged with the internal '$($Identifier)' sensitivity label is detected."

    # Replace the {{UPN}} token in our ORIGIN= string to something a bit more informative.
    $HeaderExample = $HeaderExample -replace "{{UPN}}", "transport.rule@$((Get-OrganizationConfig).Name)"

    If (Get-TransportRule -Identity $ruleName -ErrorAction SilentlyContinue) {
        Write-Log -Message "`tTransport rule '$ruleName' exists, updating."
        Set-TransportRule `
            -Identity $ruleName `
            -HeaderMatchesMessageHeader 'msip_labels' `
            -HeaderMatchesPatterns "(?im)$($deployedLabel.guid)" `
            -SetHeaderName 'x-protective-marking' `
            -SetHeaderValue $HeaderExample `
            -Comments $comment
            | Out-Null
    } else {
        Write-Log -Message "`tCreating new transport rule '$ruleName'."
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
        [string[]] $TrustedDomains
    )

    $ruleName = 'EPMS - Strip encryption for outgoing emails and attachments'
    $comment = "Removes the encryiption associated with the internal sensitivity labels for the mail and relevant attachments."

    If (Get-TransportRule -Identity $ruleName -ErrorAction SilentlyContinue) {
        Write-Log -Message "Transport rule '$ruleName' exists, updating."
        Set-TransportRule `
            -Identity $ruleName `
            -FromScope 'InOrganization' `
            -RecipientDomainIs $TrustedDomains `
            -RemoveOMEv2 $true `
            -RemoveRMSAttachmentEncryption $true `
            -Comments $comment `
            | Out-Null           
    } else {
        Write-Log -Message "Creating new transport rule '$ruleName'."
        New-TransportRule `
            -Name $ruleName `
            -FromScope 'InOrganization' `
            -RecipientDomainIs $TrustedDomains `
            -RemoveOMEv2 $true `
            -RemoveRMSAttachmentEncryption $true `
            -Comments $comment `
            -Mode 'Audit' `
            | Out-Null
    }
}

# Debugging.

function Enable-AllLabelsAndPolicies {
    Get-DlpCompliancePolicy | Where-Object { ($_.Name -like 'EPMS - *') } | Set-DlpCompliancePolicy -Mode 'Enable'
    Get-AutoSensitivityLabelPolicy | Where-Object { ($_.Name -like 'EPMS - *') } | Set-AutoSensitivityLabelPolicy -Mode 'Enable'
    Get-TransportRule | Where-Object { ($_.Name -like 'EPMS - *') } | Set-TransportRule -Mode 'Enforce'
}

function Disable-AllLabelsAndPolicies {
    Get-DlpCompliancePolicy | Where-Object { ($_.Name -like 'EPMS - *') } | Set-DlpCompliancePolicy -Mode 'TestWithoutNotifications'
    Get-AutoSensitivityLabelPolicy | Where-Object { ($_.Name -like 'EPMS - *') } | Set-AutoSensitivityLabelPolicy -Mode 'TestWithoutNotifications'
    Get-TransportRule | Where-Object { ($_.Name -like 'EPMS - *') } | Set-TransportRule -Mode 'Audit'
}


function Remove-AllLabelsAndPolicies {

    $compliancePolicies = Get-DlpCompliancePolicy | Where-Object { ($_.mode -ne 'PendingDeletion') -and ($_.name -like 'EPMS - *') }
    if ($compliancePolicies) {
        Write-Log -Message "Removing $($compliancePolicies.Count) compliance policies." -Level 'Warning'
        $compliancePolicies | Remove-DlpCompliancePolicy -Confirm:$true
    } else {
        Write-Log -Message "No DLP compliance policies to delete."
    }

    $autoLabelPolicies = Get-AutoSensitivityLabelPolicy | Where-Object { ($_.mode -ne 'PendingDeletion') -and ($_.name -like 'EPMS - *') }
    if ($autoLabelPolicies) {
        Write-Log -Message "`tRemoving $($autoLabelPolicies.Count) auto-labelling policies." -Level 'Warning'
        $autoLabelPolicies | Remove-AutoSensitivityLabelPolicy -Confirm:$true
    } else {
        Write-Log -Message "No auto-labling policies to delete."
    }

    $labelPolicies = Get-LabelPolicy | Where-Object { ($_.mode -ne 'PendingDeletion') -and ($_.name -like 'PSPF - *') }
    if ($labelPolicies) {
        Write-Log -Message "`tRemoving $($labelPolicies.Count) manual labeling policies." -Level 'Warning'
        $labelPolicies | Remove-LabelPolicy -Confirm:$true
    } else {
        Write-Log -Message "No manual label policies to delete."
    }

    [array] $skippedLabels = $null
    $labels = Get-EPMSLabels
    $deployedLabels = Get-Label | Where-Object { $_.mode -ne 'PendingDeletion' }

    if ($deployedLabels) {
        Write-Log -Message "Found $($deployedLabels.Count) sensitivity labels." -Level 'Warning'
        
        ForEach ($deployedLabel in $deployedLabels) {    
            # Only trash labels with the same display names as our configuration.
            if ($deployedLabel.DisplayName -in $labels.LabelDisplayName) {
                Write-Log -Message "`tFound matching sensitivity label '$($deployedLabel.DisplayName)'. Removing." -Level 'Warning'
                if ($null -ne $deployedLabel.ParentId.Guid) {
                    # Label has no parent, we can delete it.
                    $deployedLabel | Remove-Label -Confirm:$true
                } else {
                    # Store it for a subsequent deletion.
                    $skippedLabels += $deployedLabel.name
                }
            }
        }
        # Trash the skipped labels now that the childs are deleted.
        $skippedLabels | ForEach-Object {
            Write-Log -Message "`tFound matching sensitivity label '$($_)'. Removing." -Level 'Warning'
            Remove-Label -Identity $_ -Confirm:$true
        }

    } else {
        Write-Log -Message "No sensitivity labels to delete."
    }
    
    $transportRules = Get-TransportRule | Where-Object { ($_.mode -ne 'PendingDeletion') -and ($_.name -like 'EPMS - *') }
    if ($transportRules) {
        Write-Log -Message "`tRemoving $($transportRules.Count) transport rules." -Level 'Warning'
        $transportRules | Remove-TransportRule -Confirm:$true
    } else {
        Write-Log -Message "No transport rules to delete."
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