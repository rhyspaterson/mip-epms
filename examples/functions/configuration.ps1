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
            HeaderRegex         = "(?im)sec=unofficial\u002C"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=UNOFFICIAL, ORIGIN=jane.doe@contoso.gov.au"
            SubjectRegex        = "(?im)sec=unofficial\u002C"
            SubjectExample      = "[SEC=UNOFFICIAL]"
            DocumentMarkingText = "UNOFFICIAL"        
            Hierarchy           = "NoParent"
            LabelPolicy         = 'standard-labels'
        }
        [PSCustomObject]@{
            Identifier          = "official-parent"
            LabelDisplayName    = "OFFICIAL [Parent]"
            Tooltip             = "Parent label for visual purposes."
            Hierarchy           = "IsParent"
            LabelPolicy         = 'standard-labels'
        }     
        [PSCustomObject]@{
            Identifier          = "official"
            LabelDisplayName    = "OFFICIAL"
            Tooltip             = "No or insignificant damage. This is the majority of routine information."
            HeaderRegex         = "(?im)(sec=official)(?!:sensitive)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL, ORIGIN=jane.doe@contoso.gov.au"
            ParentLabel         = "OFFICIAL [Parent]"
            SubjectRegex        = "(?im)sec=official\u002C"
            SubjectExample      = "[SEC=OFFICIAL]"   
            DocumentMarkingText = "OFFICIAL"
            Hierarchy           = "HasParent"
            LabelPolicy         = 'standard-labels'
        }    
        [PSCustomObject]@{
            Identifier          = 'official-sensitive'
            LabelDisplayName    = "OFFICIAL - Sensitive"
            Tooltip             = "Limited damage to an individual, organisation or government generally if compromised."
            HeaderRegex         = "(?im)(sec=official:sensitive)(?!\u002C\saccess)"   
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL:Sensitive, ORIGIN=jane.doe@contoso.gov.au"
            SubjectRegex        = "(?im)(sec=official:sensitive)(?!\u002C\saccess)"
            SubjectExample      = "[SEC=OFFICIAL:Sensitive]"
            DocumentMarkingText = "OFFICIAL:Sensitive"      
            ParentLabel         = "OFFICIAL [Parent]"
            Hierarchy           = "HasParent"
            LabelPolicy         = 'standard-labels'
        } 
        [PSCustomObject]@{
            Identifier          = 'official-sensitive-legislative-secrecy'
            LabelDisplayName    = "OFFICIAL - Sensitive - Legislative-Secrecy"
            Tooltip             = "TBC"
            HeaderRegex         = "(?im)(sec=official:sensitive\u002C\saccess=legislative-secrecy)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL:Sensitive, ACCESS=Legislative-Secrecy, ORIGIN=jane.doe@contoso.gov.au"
            SubjectRegex        = "(?im)(sec=official:sensitive\u002C\saccess=legislative-secrecy)"
            SubjectExample      = "[SEC=OFFICIAL:Sensitive, ACCESS=Legislative-Secrecy]"   
            DocumentMarkingText = "OFFICIAL:Sensitive//Legislative-Secrecy"         
            ParentLabel         = "OFFICIAL [Parent]"
            Hierarchy           = "HasParent"
            LabelPolicy         = 'standard-labels'
        }
        [PSCustomObject]@{
            Identifier          = 'official-sensitive-legal-privilege'
            LabelDisplayName    = "OFFICIAL - Sensitive - Legal Privilege"
            Tooltip             = "TBC"
            HeaderRegex         = "(?im)(sec=official:sensitive\u002C\saccess=legal-privilege)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL:Sensitive, ACCESS=Legal-Privilege, ORIGIN=jane.doe@contoso.gov.au"
            SubjectRegex        = "(?im)(sec=official:sensitive\u002C\saccess=legal-privilege)"
            SubjectExample      = "[SEC=OFFICIAL:Sensitive, ACCESS=Legal-Privilege]"   
            DocumentMarkingText = "OFFICIAL:Sensitive//Legal-Privilege"         
            ParentLabel         = "OFFICIAL [Parent]"
            Hierarchy           = "HasParent"
            LabelPolicy         = 'standard-labels'
        }       
        [PSCustomObject]@{
            Identifier          = 'official-sensitive-personal-privacy'
            LabelDisplayName    = "OFFICIAL - Sensitive - Personal Privacy"
            Tooltip             = "TBC"
            HeaderRegex         = "(?im)(sec=official:sensitive\u002C\saccess=personal-privacy)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL:Sensitive, ACCESS=Personal-Privacy, ORIGIN=jane.doe@contoso.gov.au"
            SubjectRegex        = "(?im)(sec=official:sensitive\u002C\saccess=personal-privacy)"
            SubjectExample      = "[SEC=OFFICIAL:Sensitive, ACCESS=Personal-Privacy]"     
            DocumentMarkingText = "OFFICIAL:Sensitive//Personal-Privacy"
            ParentLabel         = "OFFICIAL [Parent]"
            Hierarchy           = "HasParent"
            LabelPolicy         = 'standard-labels'
        }  
        [PSCustomObject]@{
            Identifier          = 'protected-parent'
            LabelDisplayName    = "PROTECTED [Parent]"
            Tooltip             = "Parent label for visual purposes."
            Hierarchy           = "IsParent"
            LabelPolicy         = 'protected-labels'
        }     
        [PSCustomObject]@{
            Identifier          = 'protected'
            LabelDisplayName    = "PROTECTED"
            Tooltip             = "High business impact. Damage to the national interest, organisations or individuals."
            HeaderRegex         = "(?im)(sec=protected)(?!\u002C\saccess)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=PROTECTED, ORIGIN=jane.doe@contoso.gov.au"
            SubjectRegex        = "(?im)(sec=protected)(?!\u002C\saccess)"
            SubjectExample      = "[SEC=PROTECTED]"    
            DocumentMarkingText = "PROTECTED"
            Hierarchy           = "HasParent"
            ParentLabel         = "PROTECTED [Parent]"
            LabelPolicy         = 'protected-labels'
        }
        [PSCustomObject]@{
            Identifier          = 'protected-legal-privilege'
            LabelDisplayName    = "PROTECTED - Legal-Privilege"
            Tooltip             = "High business impact. Damage to the national interest, organisations or individuals."
            HeaderRegex         = "(?im)(sec=protected\u002C\saccess=legal-privilege)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=PROTECTED, ACCESS=Legal-Privilege, ORIGIN=jane.doe@contoso.gov.au"
            SubjectRegex        = "(?im)(sec=protected\u002C\saccess=legal-privilege)"
            SubjectExample      = "[SEC=PROTECTED, ACCESS=Legal-Privilege]"    
            DocumentMarkingText = "PROTECTED//Legal-Privilege"      
            Hierarchy           = "HasParent"
            ParentLabel         = "PROTECTED [Parent]"
            LabelPolicy         = 'protected-labels'
        }
        [PSCustomObject]@{
            Identifier          = 'protected-legislative-secrecy'
            LabelDisplayName    = "PROTECTED - Legislative-Secrecy"
            Tooltip             = "High business impact. Damage to the national interest, organisations or individuals."
            HeaderRegex         = "(?im)(sec=protected\u002C\saccess=legislative-secrecy)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=PROTECTED, ACCESS=Legislative-Secrecy, ORIGIN=jane.doe@contoso.gov.au"
            SubjectRegex        = "(?im)(sec=protected\u002C\saccess=legislative-secrecy)"
            SubjectExample      = "[SEC=PROTECTED, ACCESS=Legislative-Secrecy]"    
            DocumentMarkingText = "PROTECTED//Legislative-Secrecy"      
            Hierarchy           = "HasParent"
            ParentLabel         = "PROTECTED [Parent]"
            LabelPolicy         = 'protected-labels'
        }
        [PSCustomObject]@{
            Identifier          = 'protected-personal-privacy'
            LabelDisplayName    = "PROTECTED - Personal-Privacy"
            Tooltip             = "High business impact. Damage to the national interest, organisations or individuals."
            HeaderRegex         = "(?im)(sec=protected\u002C\saccess=personal-privacy)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=PROTECTED, ACCESS=Personal-Privacy, ORIGIN=jane.doe@contoso.gov.au"
            SubjectRegex        = "(?im)(sec=protected\u002C\saccess=personal-privacy)"
            SubjectExample      = "[SEC=PROTECTED, ACCESS=Personal-Privacy]"    
            DocumentMarkingText = "PROTECTED//Personal-Privacy"      
            Hierarchy           = "HasParent"
            ParentLabel         = "PROTECTED [Parent]"
            LabelPolicy         = 'protected-labels'
        }           
    )
}

function Get-EPMSLabelPolicies {
    return [PSCustomObject]@(
        [PSCustomObject]@{
            Identifier          = "standard-labels"
            DisplayName         = "Deploy standard labels to all staff"
            DeployTo            = 'All'
        }
        [PSCustomObject]@{
            Identifier          = "protected-labels"
            DisplayName         = "Deploy protected labels to cleared staff"
            DeployTo            = 'protected-labels-mail-enabled-security-group'
        }
    )    
}

function Get-EPMSDomains {
    # Add additional domains into here as required.
    return @(
        'contoso-1.gov.au', 
        'contoso-2.gov.au',
        'contoso-3.gov.au',
        'contoso-4.gov.au',
        'contoso-5.gov.au'
    )
}