# Not Pester tests, but useful for generating sample mail from one tenant to another.

#Requires -Modules @{ ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "1.9.2" }

param (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string] $appId,    
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string] $certificateThumbprint,
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string] $tenant,
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string] $mailSender,   
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string] $mailRecipient
)

Try {
    . $PSScriptRoot\..\functions\configuration.ps1
    . $PSScriptRoot\..\functions\functions.ps1
} Catch {
    Throw 'Could not import pre-requisites ($_.Exception).'
}

# We use the PowerShell graph module to simplify authentication.
Assert-GraphConnection -CertificateThumbprint $certificateThumbprint -AppId $appId -Tenant $tenant

# Get all our functional labels.
$labels = Get-EPMSLabels | Where-Object { $_.Hierarchy -ne 'IsParent'}

# For each label, send an email with the relevant subject suffix and x-header, from a given person, to a given person.
ForEach ($label in $labels) {
    Write-Log -Message "Sending mail for $($label.SubjectExample)"

    $body = [PSCustomObject]@{
        message = [PSCustomObject]@{
            subject = "EPMS - Protective markings test email"
            body = [PSCustomObject]@{
                contentType = "text"
                content = "Hello! This is a test. Header as originally sent: '$($label.HeaderExample)'. Subject suffix as originally sent: '$($label.SubjectExample)'."
            }
            toRecipients = [PSCustomObject]@([PSCustomObject]@{
                emailAddress = [PSCustomObject]@{
                    address = $mailRecipient
                }
            })
            internetMessageHeaders = [PSCustomObject]@([PSCustomObject]@{
                name = "x-protective-marking"
                value = $($label.HeaderExample)
            })                
        }
    } | ConvertTo-Json -Depth 99

    # Requires the Mail.Send privilege on the app registration.
    Invoke-MgGraphRequest `
        -Uri "https://graph.microsoft.com/beta/users/$mailSender/sendMail" `
        -Method POST `
        -Body $body 
    
    # Just in case.
    Start-Sleep 1
}