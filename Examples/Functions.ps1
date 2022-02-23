
function Assert-ServiceConnection {
    param(
        [string] $CertificateThumbprint,
        [string] $AppId,
        [string] $Tenant,
        [switch] $Disconnect
    )

    if ($disconnect) { 
        Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore 
    } else {

        # Requires WinRM basic configuration enabled on the client
        # Assumes Windows currently
        if (-not (Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client' -Name 'AllowBasic')) {
            throw "WinRM based auth is not configured."
        }

        try {

            Import-Module ExchangeOnlineManagement -ErrorAction Stop

            Write-Host "Removing any existing Exchange Online connections."

            Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore

            Write-Host "Establishing connection to '$Tenant' via certificate '$CertificateThumbprint' and app registration '$AppId'."

            # Connect EOL
            Connect-ExchangeOnline -CertificateThumbprint $CertificateThumbprint -AppID $AppId -Organization $Tenant -ShowBanner:$false -ShowProgress:$false

            # Connect SCC, https://github.com/MicrosoftDocs/office-docs-powershell/issues/6716
            Connect-ExchangeOnline -CertificateThumbprint $CertificateThumbprint -AppID $AppId -Organization $Tenant -ShowBanner:$false -ShowProgress:$false -ConnectionURI "https://ps.compliance.protection.outlook.com/powershell-liveid/"

        } catch {
            throw "Failed to connect to Exchange Online and the SCC"
        }
    }
}
function Assert-EPMSLabel {
    param(
        [string] $DisplayName,
        [string] $Tooltip,
        [string] $ParentLabelDisplayName
      )

        if ($label = Get-Label | Where-Object { ($_.DisplayName -eq $DisplayName) -and ($_.Mode -ne 'PendingDeletion') }) {
            Throw "Label '$DisplayName' already exists."
        }

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

        Write-Host "Created label $($label.Name) with display name '$displayName'"

        if ($ParentLabelDisplayName) {
            $parentLabel = Get-Label | Where-Object { ($_.DisplayName -eq $ParentLabelDisplayName) -and ($_.Mode -ne 'PendingDeletion') }
            Write-Host "Set parent label for '$($label.displayName)' to '$($parentLabel.displayName)'"
            
            Set-Label -Identity $($label.Guid) -ParentId $parentLabel.Guid
        }
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



function Remove-EPMSLabel {
    param(
        [string] $DisplayName,
        [switch] $IncludeAll
    )

    if ($IncludeAll) {
        $labels = Get-Label | Where-Object { $_.mode -ne 'PendingDeletion' }
        if ($labels) {
            Write-Warning "Removing all $($labels.Count) labels"
            $labels | Remove-Label -Confirm:$true
        } else {
            Write-Host "No labels to delete."
        }
        
    } else {
        $label = Get-Label | Where-Object { $_.DisplayName -eq $DisplayName}
        Remove-Label -Identity $label.Guid -Force
    }    
}