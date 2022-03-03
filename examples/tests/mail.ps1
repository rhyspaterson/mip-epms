#Requires -Modules @{ ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "1.9.2" }

param (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string] $appId,    
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string] $certificateThumbprint,
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string] $tenant,
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string] $mailRecipient
)

Try {
    . $PSScriptRoot\..\functions\configuration.ps1
    . $PSScriptRoot\..\functions\functions.ps1
} Catch {
    Throw 'Could not import pre-requisites ($_.Exception).'
}

Assert-GraphConnection -CertificateThumbprint $certificateThumbprint -AppId $appId -Tenant $tenant

$labels = Get-EPMSLabels | Where-Object { $_.Hierarchy -ne 'IsParent'}

ForEach ($label in $labels) {
    Write-Host "Sending email for $($label.SubjectExample)"

    $body = [PSCustomObject]@{
        message = [PSCustomObject]@{
            subject = "Test from Graph"
            body = [PSCustomObject]@{
                contentType = "text"
                content = "Testing protective markings."
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

    Invoke-MgGraphRequest `
        -Uri "https://graph.microsoft.com/beta//users/admin@M365x60780846.onmicrosoft.com/sendMail" `
        -Method POST `
        -Body $body 
    
    Start-Sleep 1
}