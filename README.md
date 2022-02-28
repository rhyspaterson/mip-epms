# Email Protective Marking Standard and Microsoft 365
This repository provides information and configuration as code to support for the Australian Government's Email Protective Marking Standard (EPMS) within Microsoft 365. 

The focus is primarily to support Outlook, cross-platform, using the native (non-AIP UL) client. Not all functionality that might be expected to be provided through third-party tools are currently supported. Note that unlike purely client-side solutions, controls are implemented either client or server-side, depending on the scenario. The intent is to leverage the information protection services available within Microsoft 365 to provide a functional and practical data protection capability that supports zero trust, and negates the requirement for traditional client-side or perimeter controls to protect information.

## Components

- PowerShell 7
- [App-only authentication in EXO V2](https://docs.microsoft.com/en-us/powershell/exchange/app-only-auth-powershell-v2?view=exchange-ps)
- Sensitivity Labels
- Encryption
- Auto-labelling policies
- Data loss prevention policies
- Exchange Online transport rules

### Feature status

#### Implemented

- [x] On mail send for Outlook, require a label to be applied if it is missing across all Outlook clients (Windows, Mac, Web, iOS and Android) `[via native client]`.
- [x] On mail send from a shared or delegated mailbox in Outlook for iOS, a sensitivity label can not be applied `[via native client]`.
- [x] On mail send from Outlook, allow an `x-protective-marking` header to be inserted based on the metadata of the sensitivity label selected `[via auto-labelling]`.
- [x] On mail received into Exchange Online, the email cannot be marked with a sensitivity label based on the `x-protective-marking` header and/or subject `[via auto-labelling]`.
- [x] On mail received into Exchange Online, the email cannot be encrypted via the sensitivity label `[via auto-labelling]`.
- [x] On mail send from Outlook, the display name of the sensitivity label could not be appended into the email subject line, only prefixed `[via dlp]`.
- [x] On mail send from Outlook, using a sensitivity label that applies rights management encryption, both the email body and any attachments cannot be decrypted for a given scenario  `[via etr]`.

#### Not implemented
- [ ] When downgrading a sensitivity label, the downgrade can not be prevented, only require justification.
- [ ] When manipulating the `x-protective-marking` header, variables cannot be inserted, such as a user principal name.
- [ ] When manipulating the `x-protective-marking` header, advanced characters such as commas `,` or colons `:` cannot be inserted.
- [ ] When manipulating the `x-protective-marking` header, the new header value cannot exceed 64 characters.
- [ ] Allow the application of sensitivity labels to calendar objects.
- [ ] To do: clarify inheritance.

## Getting started

If you'd like to skip to coding part, check out the provisioning example. Otherwise, this will step through the approach in provisioning a label and the supporting configuration from scratch.

## Complete Provisioning Example

For the bold, you can reference the [Create-SensitivityLabelsAndPolicies.ps1](examples/Create-SensitivityLabelsAndPolicies.ps1) PowerShell script that will provision a set of sensitivity labels and their supporting configuration. This for the most part assumes you are operating in a development environment, but won't modify existing sensitivity labels just in case.

Simply provide it with the certificate thumbprint, app registration and tenancy name as configured via [App-only authentication in EXO V2](https://docs.microsoft.com/en-us/powershell/exchange/app-only-auth-powershell-v2?view=exchange-ps), and off you go.

```PowerShell
.\Create-SensitivityLabelsAndPolicies.ps1 `
    -certificateThumbprint 'CFE601DF99EC017EAA19D8853004873B5B46DBBA' `
    -appId "07f8ec11-b3e4-4484-8af4-1b02c42f7d4a" `
    -tenant "contoso.onmicrosoft.com"
```

## Attributes

The labels are defined in the [_labels.ps1](examples/_labels.ps1) file and use the following defined structure.

```Identifier```

The identifier attribute is the unique name for the label within the object. You probably do not need to change this.

```LabelDisplayName```

The display name to use in the sensitivity label, noting character restrictions such as colons `:`.

```Tooltip```

The description to provide context when hovering over the label, otherwise known as a tooltip.

```HeaderRegex```

The regular expression used to match the specific classification within the x-protective-marking mail header, noting there are several restrictions within regex engine as implemented by Microsoft. he capabilities of the regex engine as implemented by Microsoft. 

```HeaderExample```

An example of a valid x-protective-marking header for unit tests.

```SubjectRegex```

The regular expression used to match the specific classification within the mail subject, noting there are several restrictions within regex engine as implemented by Microsoft. 

```SubjectExample```

An example of a valid x-protective-marking header for unit tests and the intelligent subject line append.

```DocumentMarkingText```

The text to inject into the document for content marking.

```Hierarchy```

Where in the sensitivity label hierarchy the label resides. Can be one of:

- `NoParent`: the label has no parent and sits at the root level.
- `IsParent`: the label is a parent and has child labels, and at the root level.
- `HasParent`: the label is a child and has a parent label.

```ParentLabel```

Optional. If the label is a child label as defined above through `HasParent`, then this specifies the name of the relevant parent label.
