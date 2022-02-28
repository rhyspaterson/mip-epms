# EPMS + MIP
Configuration as code to enable support for the Australian Government's Email Protective Marking Standard (EPMS) within Microsoft 365. 

The focus is primarially to support Outlook, cross-platform, using the native (non-AIP UL) client.

## Components

- PowerShell 7
- [App-only authentication in EXO V2](https://docs.microsoft.com/en-us/powershell/exchange/app-only-auth-powershell-v2?view=exchange-ps)
- Sensitivity Labels
- Encryption
- Auto-labeling
- Compliance Data Loss Prevention Policies
- Exchange Online Transport Rules

### Feature status

- [x] On mail send for Outlook, require a label to be applied if it is missing across all Outlook clients (Windows, Mac, Web, iOS and Android)
- [ ] On mail send from Outlook, allow a `x-protective-marking` be inserted based on the metadata of the sensitivity label label selected.
- [x] On mail received into Exchange Online, the email cannot be marked with a sensitivity label label based on the `x-protective-marking` header and/or subject.
- [x] On mail received into Exchange Online, the email cannot be encrypted via the sensitivity label.
- [ ] On mail send from Outlook, the display name of the sensitivity label could not be appended into the email subject line, only prefixed.
- [x] On mail send from Outlook, using a sensitivity label that applies rights management encryption, both the email body and any attachments cannot be decrypted for a given scenario.
- [x] On mail send from a shared or delegated mailbox in Outlook for iOS, a sensitivity label could not be applied.
- [ ] When downgrading a sensitivity label, the downgrade could not be prevented, only justified.
- [ ] When maniplulating the `x-protective-marking` header, we cannot insert variables, such as a username.
- [ ] When maniplulating the `x-protective-marking` header, we cannot insert commas `,` or colons `:` and thus DLMs/access markers/caveats
- [ ] When maniplulating the `x-protective-marking` header, we cannot insert a header that is greater than 64 characters
- [ ] Something about calendars
- [ ] Something about inheritance

# Getting started

For the bold, you can reference the [Create-SensitivityLabelsAndPolicies.ps1](examples/Create-SensitivityLabelsAndPolicies.ps1) PowerShell script that will provision a set of sensitivity labels and their supporting configuration. This for the most part assumes you are operating in a development environment. Simply provide it with the certificate thumbprint, app registration and tenancy name as configuired via [App-only authentication in EXO V2](https://docs.microsoft.com/en-us/powershell/exchange/app-only-auth-powershell-v2?view=exchange-ps).

```C#
.\Create-SensitivityLabels.ps1 `
    -certificateThumbprint 'CFE601DF99EC017EAA19D8853004873B5B46DBBA' `
    -appId "07f8ec11-b3e4-4484-8af4-1b02c42f7d4a" `
    -tenant "contoso.onmicrosoft.com"
```

The labels are defined in the [_labels.ps1](examples/_labels.ps1) file and use the following structure.

```
Identifier          = the unique identifier for this label within the object
LabelDisplayName    = The display name to use in thesensitivity label
Tooltip             = The tooltip to present
HeaderRegex         = The regular expression to match the x-protective-marking header
HeaderExample       = An example of the x-protective-marking header for unit tests
SubjectRegex        = The regular expression to match the subject
SubjectExample      = An example of the subject for unit tests
DocumentMarkingText = The text value to inject into content marking        
Hierarchy           = Where the label sits in the hierarchy
```