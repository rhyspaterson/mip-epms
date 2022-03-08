<#
The regular expression engine afforded to us within Microsoft 365 oeprates with some limitations.
The most important being that variable length lookaheads are not supported (e.g: .*, or .+)
Therefore we must assume the whitespaces are commas as defined in the specificaiton are adhered to (e.g., no variable whitespace).
Currently escpaing commas as unicode as the engine did not like that, either.
#>

function Get-EPMSLabels {
    return [PSCustomObject]@(
        [PSCustomObject]@{
            Identifier          = "unofficial"
            LabelDisplayName    = "UNOFFICIAL"
            Tooltip             = "No damage. This information does not form part of official duty."
            HeaderRegex         = "(?im)(sec=unofficial\u002C)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=UNOFFICIAL, ORIGIN={{UPN}}"
            SubjectRegex        = "(?im)(sec=unofficial\u002C)"
            SubjectExample      = "[SEC=UNOFFICIAL]"
            DocumentMarkingText = "UNOFFICIAL"        
            Hierarchy           = "NoParent"
            Encrypted           = $false
            LabelPolicy         = 'standard-labels'
        }
        [PSCustomObject]@{
            Identifier          = "official-parent"
            LabelDisplayName    = "OFFICIAL [Parent]" # keep the [parent] value to avoid issues with duplicate names
            Tooltip             = "Parent label for visual purposes."
            Hierarchy           = "IsParent"
        }     
        [PSCustomObject]@{
            Identifier          = "official"
            LabelDisplayName    = "OFFICIAL"
            Tooltip             = "No or insignificant damage. This is the majority of routine information."
            HeaderRegex         = "(?im)(sec=official)(?!:sensitive)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL, ORIGIN={{UPN}}"
            ParentLabel         = "OFFICIAL [Parent]"
            SubjectRegex        = "(?im)sec=official\u002C"
            SubjectExample      = "[SEC=OFFICIAL]"   
            DocumentMarkingText = "OFFICIAL"
            Hierarchy           = "HasParent"
            Encrypted           = $false
            LabelPolicy         = 'standard-labels'
        }    
        [PSCustomObject]@{
            Identifier          = 'official-sensitive'
            LabelDisplayName    = "OFFICIAL - Sensitive"
            Tooltip             = "Limited damage to an individual, organisation or government generally if compromised."
            HeaderRegex         = "(?im)(sec=official:sensitive)(?!\u002C\saccess)"   
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL:Sensitive, ORIGIN={{UPN}}"
            SubjectRegex        = "(?im)(sec=official:sensitive)(?!\u002C\saccess)"
            SubjectExample      = "[SEC=OFFICIAL:Sensitive]"
            DocumentMarkingText = "OFFICIAL:Sensitive"      
            ParentLabel         = "OFFICIAL [Parent]"
            Hierarchy           = "HasParent"
            Encrypted           = $false
            LabelPolicy         = 'standard-labels'
        } 
        [PSCustomObject]@{
            Identifier          = 'official-sensitive-lp'
            LabelDisplayName    = "OFFICIAL - Sensitive - Legal Privilege"
            Tooltip             = "Limited damage to an individual, organisation or government generally if compromised. Restrictions on access to, or use of, information covered by legal professional privilege."
            HeaderRegex         = "(?im)(sec=official:sensitive\u002C\saccess=legal-privilege)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL:Sensitive, ACCESS=Legal-Privilege, ORIGIN={{UPN}}"
            SubjectRegex        = "(?im)(sec=official:sensitive\u002C\saccess=legal-privilege)"
            SubjectExample      = "[SEC=OFFICIAL:Sensitive, ACCESS=Legal-Privilege]"   
            DocumentMarkingText = "OFFICIAL:Sensitive//Legal-Privilege"         
            ParentLabel         = "OFFICIAL [Parent]"
            Hierarchy           = "HasParent"
            Encrypted           = $false
            LabelPolicy         = 'standard-labels'
        }         
        [PSCustomObject]@{
            Identifier          = 'official-sensitive-ls'
            LabelDisplayName    = "OFFICIAL - Sensitive - Legislative-Secrecy"
            Tooltip             = "Limited damage to an individual, organisation or government generally if compromised. Restrictions on access to, or use of, information covered by specific legislative secrecy provisions."
            HeaderRegex         = "(?im)(sec=official:sensitive\u002C\saccess=legislative-secrecy)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL:Sensitive, ACCESS=Legislative-Secrecy, ORIGIN={{UPN}}"
            SubjectRegex        = "(?im)(sec=official:sensitive\u002C\saccess=legislative-secrecy)"
            SubjectExample      = "[SEC=OFFICIAL:Sensitive, ACCESS=Legislative-Secrecy]"   
            DocumentMarkingText = "OFFICIAL:Sensitive//Legislative-Secrecy"         
            ParentLabel         = "OFFICIAL [Parent]"
            Hierarchy           = "HasParent"
            Encrypted           = $false
            LabelPolicy         = 'standard-labels'
        }      
        [PSCustomObject]@{
            Identifier          = 'official-sensitive-pp'
            LabelDisplayName    = "OFFICIAL - Sensitive - Personal Privacy"
            Tooltip             = "Limited damage to an individual, organisation or government generally if compromised. Restrictions under the Privacy Act on access to, or use of, personal information collected for business purposes."
            HeaderRegex         = "(?im)(sec=official:sensitive\u002C\saccess=personal-privacy)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL:Sensitive, ACCESS=Personal-Privacy, ORIGIN={{UPN}}"
            SubjectRegex        = "(?im)(sec=official:sensitive\u002C\saccess=personal-privacy)"
            SubjectExample      = "[SEC=OFFICIAL:Sensitive, ACCESS=Personal-Privacy]"     
            DocumentMarkingText = "OFFICIAL:Sensitive//Personal-Privacy"
            ParentLabel         = "OFFICIAL [Parent]"
            Hierarchy           = "HasParent"
            Encrypted           = $false
            LabelPolicy         = 'standard-labels'
        }
        [PSCustomObject]@{
            Identifier          = 'protected-parent'
            LabelDisplayName    = "PROTECTED [Parent]" # keep the [parent] value to avoid issues with duplicate names
            Tooltip             = "Parent label for visual purposes."
            Hierarchy           = "IsParent"
        }     
        [PSCustomObject]@{
            Identifier          = 'protected'
            LabelDisplayName    = "PROTECTED"
            Tooltip             = "High business impact. Damage to the national interest, organisations or individuals."
            HeaderRegex         = "(?im)(sec=protected)(?!\u002C\saccess)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=PROTECTED, ORIGIN={{UPN}}"
            SubjectRegex        = "(?im)(sec=protected)(?!\u002C\saccess)"
            SubjectExample      = "[SEC=PROTECTED]"    
            DocumentMarkingText = "PROTECTED"
            Hierarchy           = "HasParent"
            ParentLabel         = "PROTECTED [Parent]"
            Encrypted           = $true
            LabelPolicy         = 'protected-labels'
        }
        [PSCustomObject]@{
            Identifier          = 'protected-lp'
            LabelDisplayName    = "PROTECTED - Legal-Privilege"
            Tooltip             = "High business impact. Damage to the national interest, organisations or individuals. Restrictions on access to, or use of, information covered by legal professional privilege."
            HeaderRegex         = "(?im)(sec=protected\u002C\saccess=legal-privilege)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=PROTECTED, ACCESS=Legal-Privilege, ORIGIN={{UPN}}"
            SubjectRegex        = "(?im)(sec=protected\u002C\saccess=legal-privilege)"
            SubjectExample      = "[SEC=PROTECTED, ACCESS=Legal-Privilege]"    
            DocumentMarkingText = "PROTECTED//Legal-Privilege"      
            Hierarchy           = "HasParent"
            ParentLabel         = "PROTECTED [Parent]"
            Encrypted           = $true
            LabelPolicy         = 'protected-labels'
        }
        [PSCustomObject]@{
            Identifier          = 'protected-ls'
            LabelDisplayName    = "PROTECTED - Legislative-Secrecy"
            Tooltip             = "High business impact. Damage to the national interest, organisations or individuals. Restrictions on access to, or use of, information covered by specific legislative secrecy provisions."
            HeaderRegex         = "(?im)(sec=protected\u002C\saccess=legislative-secrecy)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=PROTECTED, ACCESS=Legislative-Secrecy, ORIGIN={{UPN}}"
            SubjectRegex        = "(?im)(sec=protected\u002C\saccess=legislative-secrecy)"
            SubjectExample      = "[SEC=PROTECTED, ACCESS=Legislative-Secrecy]"    
            DocumentMarkingText = "PROTECTED//Legislative-Secrecy"      
            Hierarchy           = "HasParent"
            ParentLabel         = "PROTECTED [Parent]"
            Encrypted           = $true
            LabelPolicy         = 'protected-labels'
        }
        [PSCustomObject]@{
            Identifier          = 'protected-pp'
            LabelDisplayName    = "PROTECTED - Personal-Privacy"
            Tooltip             = "High business impact. Damage to the national interest, organisations or individuals. Restrictions under the Privacy Act on access to, or use of, personal information collected for business purposes."
            HeaderRegex         = "(?im)(sec=protected\u002C\saccess=personal-privacy)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=PROTECTED, ACCESS=Personal-Privacy, ORIGIN={{UPN}}"
            SubjectRegex        = "(?im)(sec=protected\u002C\saccess=personal-privacy)"
            SubjectExample      = "[SEC=PROTECTED, ACCESS=Personal-Privacy]"    
            DocumentMarkingText = "PROTECTED//Personal-Privacy"      
            Hierarchy           = "HasParent"
            ParentLabel         = "PROTECTED [Parent]"
            Encrypted           = $true
            LabelPolicy         = 'protected-labels'
        }      
    )
}

function Get-EPMSLabelPolicies {
    return [PSCustomObject]@(
        [PSCustomObject]@{
            Identifier          = "standard-labels"
            DisplayName         = "PSPF - Deploy standard labels to all staff"
            DeployTo            = "All"
        }
        [PSCustomObject]@{
            Identifier          = "protected-labels"
            DisplayName         = "PSPF - Deploy protected labels to cleared staff"
            DeployTo            = "protected-labels-mail-enabled-security-group"
        }
    )    
}

# Add additional domains into here as required.
function Get-EPMSDomains {
    return @(
        'contoso-1.com', 
        'contoso-2.com',
        'contoso-3.com',
        'contoso-4.com',
        'contoso-5.com'
    )
}