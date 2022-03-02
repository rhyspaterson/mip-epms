# Email Protective Marking Standard and Microsoft 365

This repository provides information and configuration as code to support for the Australian Government's [Email Protective Marking Standard](https://www.protectivesecurity.gov.au/publications-library/policy-8-sensitive-and-classified-information) (EPMS) within Microsoft 365. It is expected this approach can be adopted by other governments and organisations that leverage similar protective marking approaches for the classification of mail.

The focus is primarily to support Outlook using the native (non-AIP UL) client that is built into the Microsoft productivity suite. This approach is cross-platform, supporting Windows, Mac, iOS, Android and web.

Not all functionality that might be expected to be provided through third-party tools are currently supported. Note that unlike purely client-side solutions, controls are implemented either client or server-side, depending on the scenario. The intent is to leverage the information protection services available within Microsoft 365 to provide a functional and practical data protection capability that supports zero trust, and negates the requirement for traditional client-side or perimeter controls to protect information.

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

#### Implemented

- [x] On mail send for Outlook, require a label to be applied if it is missing across all Outlook clients (Windows, Mac, Web, iOS and Android) `[via native client]`.
- [x] On mail send from a shared or delegated mailbox in Outlook for iOS, a sensitivity label can not be applied `[via native client]`.
- [x] On mail received into Exchange Online, the email cannot be marked with a sensitivity label based on the `x-protective-marking` header and/or subject `[via auto-labelling]`.
- [x] On mail received into Exchange Online, the email cannot be encrypted via the sensitivity label `[via auto-labelling]`.
- [x] On mail send from Outlook, the display name of the sensitivity label could not be appended into the email subject line, only prefixed `[via dlp]`.
- [x] On mail send from Outlook, using a sensitivity label that applies rights management encryption, both the email body and any attachments cannot be decrypted for a given scenario  `[via etr]`.

#### Partially implemented

- [x] On mail send from Outlook, allow an `x-protective-marking` header to be inserted based on the metadata of the sensitivity label selected `[via dlp, via etr]`.

#### Not implemented
- [ ] When downgrading a sensitivity label, the downgrade can not be prevented, only require justification `[m365-limitation]`.
- [ ] When manipulating the `x-protective-marking` header, variables cannot be inserted, such as a user principal name `[m365-limitation]`.
- [ ] When manipulating the `x-protective-marking` header, the new header value cannot exceed 64 characters `[m365-limitation]`.
- [ ] Allow the application of sensitivity labels to calendar objects `[m365-limitation]`.

#### Other
- [ ] To do: clarify other header insertion limitations `[readme-update]`.
- [ ] To do: clarify inheritance `[readme-update]`.
- [ ] To do: fix parent label display names `[readme-update, code-update]`.
- [ ] To do: add additional protective markings (e.g., cabinet) `[code-update]`.
- [ ] To do: add encryption steps `[readme-update, code-update]`.
- [ ] To do: add outbound x-header steps `[readme-update, code-update]`.

## Getting started

If you'd like to skip to already-coded-part, check out the [complete provisioning example](https://github.com/rhyspaterson/mip-epms/#complete-provisioning-example). Otherwise, this will step through the approach in provisioning a label and the supporting configuration from scratch.

Particularly if you are in an old or temporary tenant, ensure you have run `Execute-AzureAdLabelSync` and [enabled consent for Azure Purview](https://docs.microsoft.com/en-us/azure/purview/how-to-automatically-label-your-content#step-2-consent-to-use-sensitivity-labels-in-azure-purview) first. You'll also need a recent version of the [ExchangeOnlineManagement](https://www.powershellgallery.com/packages/ExchangeOnlineManagement) module.

### Create our label

Sensitivity labels are the data classification capability within Microsoft Information Protection. and can be most easily compared to the use of protective markings within the Protective Security Policy Framework (PSPF). Sensitivity labels allow for the manual and automatic classification  of data, which enables the organisation to analyse and protect the associated information. By labelling - or classifying - the data, the supporting business rules can be enforced, including encryption. 

When a label is applied to content, it applies metadata for first and third-party consumption much like the x-protective-marking header as defined by the EPMS. Labels become the basis for applying and enforcing business rules, whether through primary label policies, supporting controls such as data loss prevention or transport rules, or even more holistic security controls in the broader enterprise ecosystem.

There are two elements to sensitivity labels. The establishment of the label itself, and the policy that deploys the label. A priority hierarchy is used to define the sensitivity, the higher the number, the more sensitive it is. This facilitates supporting constructs such as the requirement to justify the downgrade of a label.

Let's [create a label](https://docs.microsoft.com/en-us/powershell/module/exchange/new-label) via `New-Label`:

```powershell
$label = New-Label `
    -DisplayName 'UNOFFICIAL' `
    -Name $(New-Guid) `
    -Comment 'Provides EPMS support in Microsoft 365' `
    -Tooltip 'No damage. This information does not form part of official duty.' `
    -ApplyContentMarkingFooterEnabled $true `
    -ApplyContentMarkingFooterAlignment 'Center' `
    -ApplyContentMarkingFooterText 'UNOFFICIAL' `
    -ApplyContentMarkingFooterFontSize 12 `
    -ApplyContentMarkingFooterFontColor '#ef233c' `
    -ApplyContentMarkingHeaderEnabled $true `
    -ApplyContentMarkingHeaderAlignment 'Center' `
    -ApplyContentMarkingHeaderText 'UNOFFICIAL' `
    -ApplyContentMarkingHeaderFontSize 12 `
    -ApplyContentMarkingHeaderFontColor '#ef233c' `
    -ContentType 'File, Email, Site, UnifiedGroup, PurviewAssets'
```

Here we are defining the display name and guidance for those leveraging it. We generate a random GUID for the name, as our label purpose may change in the future. We're also enabling content marking, and making it available to all of our files and emails, our SharePoint sites and modern groups, and even Azure Purview. We want to use this label everywhere, so we can bank the benefits of integrated data classification. Now we just need to deploy it.

Then, we [create a new label policy](https://docs.microsoft.com/en-us/powershell/module/exchange/new-labelpolicy) via `New-LabelPolicy`:

```powershell
New-LabelPolicy `
    -Name 'Deploy labels to all staff'`
    -Labels $label.name `
    -ExchangeLocation 'All' `
    -Settings @{
        powerbimandatory = $true
        requiredowngradejustification = $true
        siteandgroupmandatory = $true
        mandatory = $true
        disablemandatoryinoutlook = $false
    }
```

Here we deploy a new label policy to all staff via the `ExchangeLocation` property, and include advanced settings to enforce mandatory labeling. We include the label we just created as a label. We can easily include multiple labels through that property as an `array`.

### Configure the inbound auto-labelling policies

Unlike traditional reliance on client-side tools for classification data, we want to ensure data is identified and classified appropriately as soon as it is identified, server-side. This is one of the greatest benefits of adopting and integrated data classification model that functions on both the client and server side. From the perspective of mail, particularly for higher classifications, we want to apply a sensitivity label as soon as it arrives in our Exchange organisation. This ensures our business processes are enforced regardless of to whom the mail is sent, or how it is accessed. We can achieve this through auto-labelling by inspecting the `x-protective-marking` header and applying the appropriate sensitivity label. This effectively ensures that all inbound mail (e.g., sent from outside the organisation) that has a valid protective marking applied, will also have an appropriate sensitivity label applied.

First, [we deploy an auto-labelling policy](https://docs.microsoft.com/en-us/powershell/module/exchange/new-autosensitivitylabelpolicy) that is assocaited with our classificaiton or protective marking via the `New-AutoSensitivityLabelPolicy` cmdlet.

```powershell
$policy = New-AutoSensitivityLabelPolicy `
    -Name "Auto-label 'unofficial' mail" `
    -ApplySensitivityLabel $($label.Guid) `
    -ExchangeLocation 'All' `
    -OverwriteLabel $true `
    -Mode 'TestWithoutNotifications'
```

Here we define a new policy that applies our previously created label (via it's GUID). We specify everywhere in Exchange, overwrite any existing labels, and set the `mode` to `TestWithoutNotifications`. This allows us to deploy the policy but simulate the result without actually applying the label. Once we're happy, we can shift the `mode` to `Enable`.

Then, [we define and apply the rule](https://docs.microsoft.com/en-us/powershell/module/exchange/new-autosensitivitylabelrule) that actually fires the auto-labelling policy via the `New-AutoSensitivityLabelRule` cmdlet. 

```powershell
New-AutoSensitivityLabelRule `
    -Name "Detect x-header for 'unofficial'" `
    -HeaderMatchesPatterns @{"x-protective-marking" = "(?im)sec=unofficial\u002C"} `
    -Workload "Exchange" `
    -Policy $($policy.name)
```

We leverage regular expressions to pattern match our classification in the x-header of the mail, and associate with the previous policy. For those new to the wild world of regular expressions, here we are saying:

- `(?im)`: case insensitive, match across multiple lines
- `sec=unofficial`: match the characters sec=unofficial literally
- `\u002C`: match a comma

Putting it all together gives us `(?im)sec=unofficial\u002C`, which will match the string `sec=unofficial,` in the `x-protective-marking` header. Although not the greatest expression, we must be creative here as we are limited in our ability to use advanced concepts (like negative lookaheads) in the regex engine that is provided to us via Microsoft 365. Assuming the organisation implements the `x-protective-marking` header to specification, this regex will do the job.

Check out the [regular expressions](https://github.com/rhyspaterson/mip-epms/#regular-expressions) section below for more details.

### Configure the data loss prevention policies

Although arguably an optional control and of questionable value, the appending of the protective marking to the mail subject is ubiquitous. We can achieve this by leveraging a data loss prevention rule that modifies our subject based on the attached sensitivity label. Once a label is applied within Microsoft 365, we have full confidence about the classification of the given email. In this respect, we may only choose then to modify the subject in more specific scenarios, such as for mail destined outside of the organisation. However, if we want full confidence the classification is correctly appended in any scenario, we can be more generic in our application. 

First, [we define a dlp policy](https://docs.microsoft.com/en-us/powershell/module/exchange/new-dlpcompliancepolicy) that is associated with our sensitivity label via the `New-DlpCompliancePolicy` cmdlet.

```powershell
$policy = New-DlpCompliancePolicy `
    -Name "Subject append 'unofficial' mail" `
    -ExchangeLocation 'All' `
    -Mode 'TestWithoutNotifications'
```

Here we define a new policy that applies everywhere in Exchange and sets the `mode` to `TestWithoutNotifications`. This allows us to deploy the policy but simulate the result without actually modifying the subject line. Once we're happy, we can shift the `mode` to `Enable`.

Then, [we define and apply the rule](https://docs.microsoft.com/en-us/powershell/module/exchange/new-dlpcompliancerule) that actually fires the dlp policy via the `New-DlpComplianceRule` cmdlet. 

```powershell
# Build the first complex PswsHashtable to match on a label
$complexSensitiveInformationRule = @(
    @{
        operator = "And"
        groups = @(
            @{
                operator="Or"
                name="Default"
                labels = @(
                    @{
                        name="$($label.Name)";
                        type="Sensitivity"
                    } 
                )
            }
        )
    }
)

# Build the second complex PswsHashtable to perform the rewrite
$complexModifySubjectRule = @{
    patterns = "{\[SEC=.*?\]}"
    ReplaceStrategy = 'Append'
    SubjectText = $SubjectExample
}

# Create the policy
New-DlpComplianceRule `
    -Name "If 'unofficial', append subject" `
    -Policy $($policy.name) `
    -ContentContainsSensitiveInformation $complexSensitiveInformationRule `
    -ModifySubject $complexModifySubjectRule `
```

This is a bit more advanced. First, we define the `PswsHashtable` for `ContentContainsSensitiveInformation`. This is a nested hashtable that defines the logic to fire any time a label with a given name is seen. We are re-using the `$label.name` attribute we generated previously. 

Then, we define the `ModifySubject` rule, also a `PswsHashtable`. Here we leverage regular expressions again to find our visual marking, replace it with our desired text, and append it to the end of the of the subject. This single regex should do for any protective marking that meets the specification.

Finally, we create the policy with both of the hashtables.

### Configure the outbound transport rules to write the x-protective-marking header

When sending mail external to the organisation, our adherence to the EPMS is required to ensure the reliable transport of our mail across organisations. The receiving party is not necessarily familiar with our internal labelling configuration and it's associated metadata, and thus cannot determine the classification of the mail without leveraging the x-protective-marking header. This is one of the primary use cases of the EPMS. 

Given the simplicity of the approach to tag inbound mail with a label based on the x-header as seen in the auto-labelling policy above, or the approach to rewrite the subject line via dlp, adopting a similar approach would be desirable. Unfortunately, we are currently bound by a product limitation in Microsoft 365 that prevents us from inserting an x-header that is greater than 64 characters via dlp rules. Even for our basic protective markings, this is too small, even if we do exclude the `origin=` attribute that we can't current write dynamically. Additionally, we cannot insert commas or colons into the x-header, which further breaks adherence to the specification.

To solve this, we revert to good old fashioned transport rules. We can query the label applied to a given email via the x-header that is written by MIP, and write the associated x-protective-marking header as required. It's not as elegant as above, but it gets the job done. 

Note that in both the dlp and etr approaches, we currently cannot insert a dynamic `origin=upn@domain` attribute. The adherence requirement here might be somewhat more philosophical, for the moment I am simply hard-coding it to a generic name. We have endless audit data to identify the applier of the label and sender of the mail.

```powershell
New-TransportRule `
    -Name "Insert x-header for 'unofficial'" `
    -HeaderMatchesMessageHeader 'msip_labels' `
    -HeaderMatchesPatterns "(?im)$($label.guid)" `
    -SetHeaderName 'x-protective-marking' `
    -SetHeaderValue 'VER=2018.4, NS=gov.au, SEC=UNOFFICIAL, ORIGIN=transport-rule@contoso.com' `
    -Mode 'Audit'
```

Here we define a new transport rule that queries the `msip_labels` x-header for the guid of our label. If it's there, then write the supporting `x-protective-marking` header and off we go. The `msip_labels` is an internal header written by MIP when a label is applied to mail. We leverage regular expressions to pattern match our sensitivity label guid using this header. Here we are saying:

- `(?im)`: case insensitive, match across multiple lines
- `$($label.guid)`: match the characters `guid-of-our-label` literally

You could enhance this to be more specific in your mail flows, such as to only fire on mail sent outside the organisation via the `-SentToScope 'NotInOrganization'`, if you wished. Like the above approach, we've set the `mode` to `Audit`to allow us to deploy the policy but simulate the result without actually modifying the `x-protective-marking` header. Once we're happy, we can shift the `mode` to `Enforce`.

### Configure encryption on the label/s

TBC

### Configure the exchange online transport rules to decrypt

Adopting a position where classified data can be controlled through rights management will drastically improve data security. It also improves the end-user experience by allowing for the elimination of traditional perimeter controls in favour of those now afforded to us in the hybrid cloud. However, in some cases the impact of this approach may be undesirable. A major consideration with adopting encryption is how the rights management process integrates with the business processes for the organisation. 

From this perspective, we may require the flexibility to decrypt our content for a given scenario. For example, some inter-organisation communication channels may be significantly impacted by the adoption of rights management and may in fact have compensating controls in place already. Having to authenticate or otherwise decrypt the content may not align with existing systems or processes. For this use case, we can apply transport rules to strip the encryption as required.

We achieve this by [defining a new transport rule policy](https://docs.microsoft.com/en-us/powershell/module/exchange/new-transportrule).

```powershell
    New-TransportRule `
        -Name 'Strip encryption for outgoing emails and attachments to trusted domains'`
        -FromScope 'InOrganization' `
        -RecipientDomainIs @('contoso-1.com', 'contoso-2.com') `
        -RemoveOMEv2 $true `
        -RemoveRMSAttachmentEncryption $true    
}
```

Here we define a new policy that strips any encryption from mail and attachments, when sent from inside the Exchange organisation to a set of trusted domains.

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

```LabelPolicy```

Optional. The assocaited labelling policy the label is assigned to. This is required to deploy the label to end users.

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
