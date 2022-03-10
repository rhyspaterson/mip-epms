# Email Protective Marking Standard and Microsoft 365

This repository provides information and configuration as code to support (as much as possible) the Australian Government's [Email Protective Marking Standard](https://www.protectivesecurity.gov.au/publications-library/policy-8-sensitive-and-classified-information) (EPMS) within Microsoft 365. It is expected this approach can be adopted by other governments and organisations that leverage similar protective marking approaches for the classification of mail.

Unlike purely client-side solutions, controls are implemented either client or server-side, depending on the scenario. The intent is to leverage the information protection services available within Microsoft 365 to provide a functional and practical data protection capability that supports zero trust, and negates the requirement for traditional client-side or perimeter controls to protect information. The focus is primarily to support Outlook using the native (non-AIP UL) sensitivity labelling clients that are built into the modern channels of the Microsoft productivity suite. This approach is cross-platform, supporting Windows, Mac, iOS, Android and web. 

Please note that currently, this approach is **not** fully compliant with the EPMS specification, nor does it cater for other peripheral classification functionality that might otherwise be expected through existing third-party integrations. However, as new functionality is realised by the vendor that improves compliance, this repository will be updated to reflect that. Refer to the feature status section below for further information.

**Note:** This is an unofficial, personal project developed for research purposes.

[![Run tests](https://github.com/rhyspaterson/mip-epms/actions/workflows/main.yml/badge.svg)](https://github.com/rhyspaterson/mip-epms/actions/workflows/main.yml)

## Components

- [PowerShell 7+](https://github.com/PowerShell/PowerShell)
- [App-only authentication in EXO V2](https://docs.microsoft.com/en-us/powershell/exchange/app-only-auth-powershell-v2?view=exchange-ps)
- [Sensitivity Labels](https://docs.microsoft.com/en-us/microsoft-365/compliance/sensitivity-labels)
- [Encryption](https://docs.microsoft.com/en-us/microsoft-365/compliance/encryption-sensitivity-labels)
- [Auto-labelling policies](https://docs.microsoft.com/en-us/microsoft-365/compliance/apply-sensitivity-label-automatically)
- [Data loss prevention policies](https://docs.microsoft.com/en-us/microsoft-365/compliance/dlp-learn-about-dlp)
- [Exchange Online transport rules](https://docs.microsoft.com/en-us/exchange/security-and-compliance/mail-flow-rules/mail-flow-rules)

### Feature status

#### Implemented :love_you_gesture:

- [x] On mail send for Outlook, require a label to be applied if it is missing across all Outlook clients (Windows, Mac, Web, iOS and Android) `[via native client]`.
- [x] On mail send from a shared or delegated mailbox in Outlook for iOS, a sensitivity label can not be applied `[via native client]`.
- [x] On mail received into Exchange Online, the email cannot be marked with a sensitivity label based on the `x-protective-marking` header and/or subject `[via auto-labelling]`.
- [x] On mail received into Exchange Online, the email cannot be encrypted via the sensitivity label `[via auto-labelling]`.
- [x] On mail send from Outlook, the display name of the sensitivity label could not be appended into the email subject line, only prefixed `[via dlp]`.
- [x] On mail send from Outlook, using a sensitivity label that applies rights management encryption, both the email body and any attachments cannot be decrypted for a given scenario  `[via etr]`.

#### Partially implemented :crossed_fingers:

- [x] On mail send from Outlook, allow an `x-protective-marking` header to be inserted based on the metadata of the sensitivity label selected `[via dlp, via etr]`.

#### Not implemented :facepunch:
- [ ] When downgrading a sensitivity label, the downgrade can not be prevented, only require justification `[m365-limitation]`.
- [ ] When manipulating the `x-protective-marking` header, variables cannot be inserted, such as a user principal name `[m365-limitation]`.
- [ ] When manipulating the `x-protective-marking` header via dlp rules, the new header value cannot exceed 64 characters `[m365-limitation]`.
- [ ] When manipulating the `x-protective-marking` header via dlp rules, the new header value cannot include special characters `[m365-limitation]`.
- [ ] Allow the application of sensitivity labels to calendar objects `[m365-limitation]`.
- [ ] When appling a sensitivity label with content markings from mail that already has content markings, the markings are duplicated `[m365-limitation]`.

#### Other :pray:
- [ ] To do: clarify inheritance `[readme-update]`.
- [ ] To do: fix parent label display names `[readme-update, code-update]`.
- [ ] To do: add additional protective markings (e.g., cabinet) `[code-update]`.
- [ ] To do: support modifying enabled policies `[code-update]`.
- [ ] To do: document the email tests `[readme-update]`.

## Getting started

It is recommended to read the supporting article that steps through the approach in provisioning a label and the supporting configuration from scratch, including it's relevance to the EPMS.  If you've done that and would like to skip to already-coded-part, you've come to the right place. 

You'll need a recent version of the [ExchangeOnlineManagement](https://www.powershellgallery.com/packages/ExchangeOnlineManagement) module. Once that is installed, run the `Connect-ExchangeOnline` and `Connect-IPPSSession` to connect to Exchange Online and the Compliance centers, respectively.

**Note**: if you are in an older or temporary tenant, [ensure you have set](https://docs.microsoft.com/en-us/azure/active-directory/enterprise-users/groups-settings-cmdlets) the `EnableMIPLabels = true` directory setting, run `Execute-AzureAdLabelSync` and [enabled consent for Azure Purview](https://docs.microsoft.com/en-us/azure/purview/how-to-automatically-label-your-content#step-2-consent-to-use-sensitivity-labels-in-azure-purview). 

## Complete provisioning example

For the bold, you can reference the [Assert-SensitivityLabelsAndPolicies.ps1](examples/Assert-SensitivityLabelsAndPolicies.ps1) PowerShell script that will provision a set of sensitivity labels and their supporting configuration. This for the most part assumes you are operating in a development environment, but won't modify existing sensitivity labels just in case.

Simply provide it with the certificate thumbprint, app registration and tenancy name as configured via [App-only authentication in EXO V2](https://docs.microsoft.com/en-us/powershell/exchange/app-only-auth-powershell-v2?view=exchange-ps), and off you go. Note that in its current form, the script will deploy labels to all users in the tenant, and set the dlp, auto-labelling and transport rules to test/audit mode. 

```PowerShell
.\Assert-SensitivityLabelsAndPolicies.ps1 `
    -certificateThumbprint 'CFE601DF99EC017EAA19D8853004873B5B46DBBA' `
    -appId "07f8ec11-b3e4-4484-8af4-1b02c42f7d4a" `
    -tenant "contoso.onmicrosoft.com"
```

### Deleting existing labels and policies

If you like, you can request the deletion of all existing labels and policies. This is helpful for development or demo tenants where you are evaluating the code and solution. To do this, leverage the following flags:

```-RemoveExistingLabelsAndPolicies```

Will remove all existing manual labelling policies, auto-labelling policies, DLP rules and the labels themselves.

```-WaitForPendingDeletions```

Will wait for any pending deletions of the above to complete before proceeding. This can take a very long time - many, many hours.

### Label attributes

The labels are defined in the [configuration.ps1](examples/functions/configuration.ps1) file. For a first run in a demo or dev environment, you shouldn't need to modify it. But, if you'd like to get stuck into it, the properties leverage the following defined structure. 

```Identifier```

The identifier attribute is the unique name for the label within the PowerShell object. You probably do not need to change this, and I use it a bit inconsistently. If you add a new label, make sure you add a unique identifier for it that makes sense to you.

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

```Encrypted```

Optional. If the label has rights management protections applied. Can be one of `$true` or `$false`. If `$true`, leverages the security group in the associated label policy as the identity to apply the `co-author` usage rights to.

```LabelPolicy```

Optional. The assocaited labelling policy the label is assigned to. This is required to deploy the label to end users. Only applicable on child labels, any associated parent labels will be automatically included in the policy.

### Policy attributes

The policies are also defined in the [configuration.ps1](examples/functions/configuration.ps1) file and use the following defined structure.

```Identifier```

The identifier attribute is the unique name for the label within the object. You probably do not need to change this.

```DisplayName```

The display name of the sensitivity label policy.

```DeployTo```

To whom the policy is deployed to. Can be one of:

- `All`: the label is deployed to everyone.
- `<group-name>`: the the name of the mail enabled security group to filter the policy to.

### Regular expressions

The regular expressions in use are all defined in the [configuration.ps1](examples/functions/configuration.ps1) file for the given label. They are validated against their example via the [configuration.Tests.ps1](examples/tests/configuration.Tests.ps1) Pester tests. This will pull the regular expressions as defined in the label structure above and validate them against their examples. It also validates a negative match against the other labels. This provides a quick assurance that the regex as defined in the configuration is both valid and functional.

GitHub Actions will run this for any modification to [configuration.ps1](examples/functions/configuration.ps1) or the associated test. You can also run this yourself via:

```powershell
Invoke-Pester -Output Detailed .\examples\tests\configuration.Tests.ps1
```
