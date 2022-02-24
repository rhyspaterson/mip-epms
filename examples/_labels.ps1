
# The regular expression engine afforded to us within Microsoft 365 oeprates with some limitations.
# The most important being that variable length lookaheads are not supported (e.g: .*, or .+)
# Therefore we must assume the whitespaces are commas as defined in the specificaiton are adhered to (e.g., no variable whitespace).
# Currently escpaing commas as unicode as the engine did not like that, either.

$labels = [PSCustomObject]@(
    [PSCustomObject]@{
        Identifier          = "unofficial"
        LabelDisplayName    = "UNOFFICIAL"
        Tooltip             = "No damage. This information does not form part of official duty."
        HeaderRegex         = "(?im)sec=unofficial\u002C"
        HeaderExample       = "VER=2018.3, NS=gov.au, SEC=UNOFFICIAL, ORIGIN=jane.doe@contoso.gov.au"
        SubjectRegex        = "(?im)sec=unofficial\u002C"
        SubjectExample      = "[SEC=UNOFFICIAL]"
        Hierarchy           = "Root"
    }
    [PSCustomObject]@{
        Identifier          = "official-parent"
        LabelDisplayName    = "OFFICIAL [Parent]"
        Tooltip             = "Parent label for visual purposes."
        Hierarchy           = "IsParent"
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
        Hierarchy           = "HasParent"
    }    
    [PSCustomObject]@{
        Identifier          = 'official-sensitive'
        LabelDisplayName    = "OFFICIAL - Sensitive"
        Tooltip             = "Limited damage to an individual, organisation or government generally if compromised."
        HeaderRegex         = "(?im)(sec=official:sensitive)(?!\u002C\saccess)"   
        HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL:Sensitive, ORIGIN=jane.doe@contoso.gov.au"
        SubjectRegex        = "(?im)(sec=official:sensitive)(?!\u002C\saccess)"
        SubjectExample      = "[SEC=OFFICIAL:Sensitive]"           
        ParentLabel         = "OFFICIAL [Parent]"
        Hierarchy           = "HasParent"
    } 
    [PSCustomObject]@{
        Identifier          = 'official-sensitive-legal-privilege'
        LabelDisplayName    = "OFFICIAL - Sensitive - Legal Privilege"
        Tooltip             = "TBC"
        HeaderRegex         = "(?im)(sec=official:sensitive\u002C\saccess=legal-privilege)"
        HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL:Sensitive, ACCESS=Legal-Privilege, ORIGIN=jane.doe@contoso.gov.au"
        SubjectRegex        = "(?im)(sec=official:sensitive\u002C\saccess=legal-privilege)"
        SubjectExample      = "[SEC=OFFICIAL:Sensitive, ACCESS=Legal-Privilege]"            
        ParentLabel         = "OFFICIAL [Parent]"
        Hierarchy           = "HasParent"
    }  
    [PSCustomObject]@{
        Identifier          = 'official-sensitive-personal-privacy'
        LabelDisplayName    = "OFFICIAL - Sensitive - Personal Privacy"
        Tooltip             = "TBC"
        HeaderRegex         = "(?im)(sec=official:sensitive\u002C\saccess=personal-privacy)"
        HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL:Sensitive, ACCESS=Personal-Privacy, ORIGIN=jane.doe@contoso.gov.au"
        SubjectRegex        = "(?im)(sec=official:sensitive\u002C\saccess=personal-privacy)"
        SubjectExample      = "[SEC=OFFICIAL:Sensitive, ACCESS=Personal-Privacy]"           
        ParentLabel         = "OFFICIAL [Parent]"
        Hierarchy           = "HasParent"
    }
    [PSCustomObject]@{
        Identifier          = 'protected-parent'
        LabelDisplayName    = "PROTECTED [Parent]"
        Tooltip             = "Parent label for visual purposes."
        Hierarchy           = "IsParent"
    }     
    [PSCustomObject]@{
        Identifier          = 'protected'
        LabelDisplayName    = "PROTECTED"
        Tooltip             = "Damage to the national interest, organisations or individuals."
        HeaderRegex         = "(?im)(sec=protected)(?!\u002C\saccess)"
        HeaderExample       = "VER=2018.3, NS=gov.au, SEC=PROTECTED, ORIGIN=jane.doe@contoso.gov.au"
        SubjectRegex        = "(?im)(sec=protected)(?!\u002C\saccess)"
        SubjectExample      = "[SEC=PROTECTED]"          
        ParentLabel         = "PROTECTED [Parent]"
        Hierarchy           = "HasParent"
    }        
)