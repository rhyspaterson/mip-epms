# EPMS + MIP
Configuration as code to enable support for the Australian Government's Email Protective Marking Standard (EPMS) within Microsoft 365. 

- Focus is on Outlook primarially and the native (non-AIP UL) client.

## Components

- PowerShell 7
- [App-only authentication in EXO V2](https://docs.microsoft.com/en-us/powershell/exchange/app-only-auth-powershell-v2?view=exchange-ps)
- Sensitivity Labels
- Encryption
- Auto-labeling
- Compliance Data Loss Prevention Policies
- Exchange Online Transport Rules

### Supported
- Mandatory labeling in all Outlook clients (Windows, Web, iOS and Android)
- Shared and delegate mailboxes support in Outlook for iOS
- Strip encryption from all email and attachments (GA March 22*)
- Auto-labelling based on x-header and/or subject (classify mail coming in)
- In auto-labelling, allow encryption to be applied if the label has it configured
- Append the classificaiton in the subject

### Limitations

 - The x-header manipulation does not support variables, so we cannot insert ORIGIN=<sender-upn@contoso.gov.au> (H2 22)
 - The x-header manipulation does not support commas `,` or colons `:` so we cannot support DLMs/access markers/caveats
 - The x-header is restricted to a length of 64 characters
 - Prevent downgrade of labelling (H2 22)

### Beavhours to expect

- Reclassify on reply (e.g., TITUS wanting origin=)
- End of june for testing H2 22 features in preview
- Future MVP: support calendar, and label inheritance


