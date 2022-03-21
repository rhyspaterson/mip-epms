# Email Protective Marking Standard and Microsoft 365

This repository provides information and configuration as code to support (as much as possible) the Australian Government's [Email Protective Marking Standard](https://www.protectivesecurity.gov.au/publications-library/policy-8-sensitive-and-classified-information) (EPMS) within Microsoft 365. It is expected this approach can be adopted by other governments and organisations that leverage similar protective marking approaches for the classification of mail.

![alt text](https://raw.githubusercontent.com/rhyspaterson/mip-epms/master/docs/owa-labels.png)

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

#### Implemented :metal:

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
- [ ] When appling a sensitivity label with content markings from mail that already has content markings, the content markings are duplicated `[m365-limitation]`.
- [ ] When manipulating the `x-protective-marking` header, variables cannot be inserted, such as a user principal name `[m365-limitation]`.
- [ ] When manipulating the `x-protective-marking` header via dlp rules, the new header value cannot exceed 64 characters `[m365-limitation]`.
- [ ] When manipulating the `x-protective-marking` header via dlp rules, the new header value cannot include special characters `[m365-limitation]`.
- [ ] Allow the application of sensitivity labels to calendar objects `[m365-limitation]`.

#### Other :pray:
- [ ] To do: clarify inheritance `[readme-update]`.
- [ ] To do: fix parent label display names `[readme-update, code-update]`.
- [ ] To do: add additional protective markings (e.g., cabinet) `[code-update]`.
- [ ] To do: support modifying enabled policies `[code-update]`.
- [ ] To do: document the email tests `[readme-update]`.

## Getting started

If you'd like to skip to already-coded-part, check out the [complete provisioning example](https://github.com/rhyspaterson/mip-epms) in the GitHub repository. Otherwise, this will step through the approach in provisioning a label and the supporting configuration from scratch.

You'll need a recent version of the [ExchangeOnlineManagement](https://www.powershellgallery.com/packages/ExchangeOnlineManagement) module. Once that is installed, run the `Connect-ExchangeOnline` and `Connect-IPPSSession` to connect to Exchange Online and the Compliance centers, respectively.

**Note**: if you are in an older or temporary tenant, [ensure you have set](https://docs.microsoft.com/en-us/azure/active-directory/enterprise-users/groups-settings-cmdlets) the `EnableMIPLabels = true` directory setting, run `Execute-AzureAdLabelSync` and [enabled consent for Azure Purview](https://docs.microsoft.com/en-us/azure/purview/how-to-automatically-label-your-content#step-2-consent-to-use-sensitivity-labels-in-azure-purview). 

## Encryption-less approach

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
    SubjectText = ' [SEC=OFFICIAL]'
}

# Create the policy
New-DlpComplianceRule `
    -Name "If 'unofficial', append subject" `
    -Policy $($policy.name) `
    -ContentContainsSensitiveInformation $complexSensitiveInformationRule `
    -ModifySubject $complexModifySubjectRule `
```

This is a bit more advanced. First, we define the `PswsHashtable` for `ContentContainsSensitiveInformation`. This is a nested hashtable that defines the logic to fire any time a label with a given name is seen. We are re-using the `$label.name` attribute we generated previously. 

Then, we define the `ModifySubject` rule, also a `PswsHashtable`. Here we leverage regular expressions again to find our visual marking (any `[SEC=*]` value we find), replace it with our desired text, and append that desired text to the end of the of the subject. This single regex should do for any protective marking that meets the specification. We even plonk a space at the front of the additive subject text to pretty up things.

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

That's it, we are done! You should be able to send emails internal and external to the organisation, with a compliant `x-protective-marking` header and subject line, noting the limitations documented at the top of this page. Not only that, but our data is also now labelled, which affords us a huge amount of additional control over it through, DLP, telemetry and the integration of labelling through the Microsoft 365 platform.

## Adding encryption to the approach

This is somewhat outside the scope of the EPMS and PSPF, although a valuable addition from a data classificaiton and protection perspective. Adopting rights management, otherwise known as encryption or protection, provides for the implementation of strong cryptographic controls on the individual data. 

Encrypting the individual data (e.g., a file, an email) allows us to move away from traditional perimeter controls such as the concepts of the trusted corporate network, secure enclaves or similar logical or physical boundary, firewalls or other inline or external security apparatus, or any other wild and exotic set of questionable traditional controls – which are almost always to the punitive degradation of the end user experience. 

Adopting persistent encryption means the protections follows the data wherever it goes, at rest or in transit. The encryption is removed on demand by authorised users only through the rights management process. The location of the file is no longer the protection, rather it is based on the identity of the user. Even better, we can integrate these concepts into the broader security toolsets at our disposal, such as conditional access and the endless telemetry we have available. Even better again, we can enable business processes to allow for mixed groups of people access to data stores, inboxes, and the like, and not worry about accidental or malicious access to the sensitive content that is encrypted. 

This allows people to operate with a fast feedback loop, in the same context as their peers, while still protecting individual assets at their relevant classification or protective marking. Want to delegate access to your inbox which contains sensitive information, your device was stolen, or you accidently or maliciously distributed content to someone or somewhere you shouldn’t? No problem. Rights management solves these issues. 
Let’s turn it on!

### Configure encryption on the label

We're going to use a new label to demonstrate this capability. Repeating the above steps, we've created a new label. We've also deployed the label through a *new* label policy, to a specific set of people via a mail enabled security group. You can leverage the `ModernGroupLocation` parameter on the `New-LabelPolicy` cmdlet to do this. This means only specific people see this label, which is important for the end-user experience when we also apply rights-management to it. So let's get going with rights management and update our new label via `Set-Label`:

```powershell
Set-Label `
    -Identity "<my-new-label-guid>" `
    -EncryptionEnabled $true `
    -EncryptionContentExpiredOnDateInDaysOrNever 'Never' `
    -EncryptionOfflineAccessDays '30' `
    -EncryptionProtectionType 'Template' `
    -EncryptionRightsDefinitions "my-security-group@contoso.com:VIEW,VIEWRIGHTSDATA,DOCEDIT,EDIT,PRINT,EXTRACT,REPLY,REPLYALL,FORWARD,OBJMODEL"
```

Here, we are enabling rights management, or encryption, on our existing label, and ensuring the rights never expire. We also enable offline access for 30 days, which is [the default behaviour](https://docs.microsoft.com/en-us/microsoft-365/compliance/encryption-sensitivity-labels?view=o365-worldwide#rights-management-use-license-for-offline-access) and it sounds like a sensible one at that. Finally, through the elaborate `EncryptionRightsDefinitions` property, we provide the `co-owner` privilege to those who are a member of the `my-security-group@contoso.com` group we used in the `New-LabelPolicy` cmdlet above. This way, those who can see the label, are also authorised under rights management to decrypt the content. This co-owner privilege provides allows full rights to the data, except for the ability to permanently remove the encryption.

That's it! You can apply this new label to your files or email and demonstrate the encryption. Try sharing it with someone who is, and is not, a member of the mail enabled security group. Once will be able to view, the other will not. You will need a [relatively modern version of the Office suite](https://docs.microsoft.com/en-us/microsoft-365/compliance/sensitivity-labels-office-apps) on your respective platform for this to function seamlessly. You can even co-author, on the fly. The fact the the data is fully encrypted will be seamless to the end user. 

A consideration for the offline access approach is one of usability. In a 'dial it to 11' zero trust mindset, we may want to disable offline access entirely as we consider the device hostile, so we could leverage the `EncryptionContentExpiredOnDateInDaysOrNever` flag and set it to `0`. However, it does mean you end users are then unable to ever view the labelled content without a network connection. Pulling up those emails on the plane, or in the middle of an environmental disaster or humanitarian crisis could be a challenge. You could also look at enabling  offline access forever via the quality `-1` integer, if we have greater trust in the device, or other supporting and compensating controls.

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

## What next?

It's time to pump out the rest of the labels! Check out the [complete provisioning example](https://github.com/rhyspaterson/mip-epms) in the GitHub repository. If you'd like to step through things manually, you can leverage the [functioning label configuration](https://github.com/rhyspaterson/mip-epms/blob/master/examples/functions/configuration.ps1) to use as a reference point.
