# To do: make this dynamic via the external function, and much prettier.

#Requires -Modules @{ ModuleName = "Pester"; ModuleVersion = "5.3.1" }

BeforeAll { 
# Import our labels functions.

    function Get-Unofficial {
        @{
            HeaderRegex         = "(?im)sec=unofficial\u002C"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=UNOFFICIAL, ORIGIN=jane.doe@contoso.gov.au"
        } 
    }

    function Get-Official {
        @{
            HeaderRegex         = "(?im)(sec=official)(?!:sensitive)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL, ORIGIN=jane.doe@contoso.gov.au"
        } 
    }    

    function Get-OfficialSensitive {
        @{
            HeaderRegex         = "(?im)(sec=official:sensitive)(?!\u002C\saccess)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL:Sensitive, ORIGIN=jane.doe@contoso.gov.au"
        } 
    } 
    
    function Get-OfficialSensitiveLegislativeSecrecy {
        @{
            HeaderRegex         = "(?im)(sec=official:sensitive\u002C\saccess=legislative-secrecy)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL:Sensitive, ACCESS=Legislative-Secrecy, ORIGIN=jane.doe@contoso.gov.au"
        } 
    }    

    function Get-OfficialSensitiveLegalPrivilege {
        @{
            HeaderRegex         = "(?im)(sec=official:sensitive\u002C\saccess=legal-privilege)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL:Sensitive, ACCESS=Legal-Privilege, ORIGIN=jane.doe@contoso.gov.au"
        } 
    }  
    
    function Get-OfficeSensitivePersonalPrivacy {
        @{
            HeaderRegex         = "(?im)(sec=official:sensitive\u002C\saccess=personal-privacy)"
            HeaderExample       = "VER=2018.3, NS=gov.au, SEC=OFFICIAL:Sensitive, ACCESS=Personal-Privacy, ORIGIN=jane.doe@contoso.gov.au"
        } 
    }    
}

Describe 'Regular Expressions' {
    BeforeAll {
        $unofficial = Get-Unofficial 
        $official = Get-Official    
        $officialSensitive = Get-OfficialSensitive
        $officeSensitiveLegislativeSecrecy = Get-OfficialSensitiveLegislativeSecrecy
        $officeSensitiveLegalPrivilege = Get-OfficialSensitiveLegalPrivilege
        $officeSensitivePersonalPrivacy = Get-OfficeSensitivePersonalPrivacy
    }    
    Context "Evaluate unofficial" {
        It 'Should match unofficial' {
            $unofficial.HeaderExample | Should -Match $unofficial.HeaderRegex
        } 
        It 'Should not match official' {          
            $unofficial.HeaderExample | Should -Not -Match $official.HeaderRegex
        }
        It 'Should not match official:sensitive' {          
            $unofficial.HeaderExample | Should -Not -Match $officialSensitive.HeaderRegex
        }    
        It 'Should not match official:sensitive legislative-secrecy' {          
            $unofficial.HeaderExample | Should -Not -Match $officeSensitiveLegislativeSecrecy.HeaderRegex
        }    
        It 'Should not match official:sensitive legal-privilege' {          
            $unofficial.HeaderExample | Should -Not -Match $officeSensitiveLegalPrivilege.HeaderRegex
        } 
        It 'Should not match official:sensitive personal-privacy' {          
            $unofficial.HeaderExample | Should -Not -Match $officeSensitivePersonalPrivacy.HeaderRegex
        }                            
    }
    Context "Evaluate official" {
        It 'Should not match unofficial' {
            $official.HeaderExample | Should -Not -Match $unofficial.HeaderRegex
        } 
        It 'Should match official' {          
            $official.HeaderExample | Should -Match $official.HeaderRegex
        }
        It 'Should not match official:sensitive' {          
            $official.HeaderExample | Should -Not -Match $officialSensitive.HeaderRegex
        }    
        It 'Should not match official:sensitive legislative-secrecy' {          
            $official.HeaderExample | Should -Not -Match $officeSensitiveLegislativeSecrecy.HeaderRegex
        }  
        It 'Should not match official:sensitive legal-privilege' {          
            $official.HeaderExample | Should -Not -Match $officeSensitiveLegalPrivilege.HeaderRegex
        }   
        It 'Should not match official:sensitive personal-privacy' {          
            $official.HeaderExample | Should -Not -Match $officeSensitivePersonalPrivacy.HeaderRegex
        }                       
    } 
    Context "Evaluate official:sensitive" {
        It 'Should not match unofficial' {
            $officialSensitive.HeaderExample | Should -Not -Match $unofficial.HeaderRegex
        } 
        It 'Should not match official' {          
            $officialSensitive.HeaderExample | Should -Not -Match $official.HeaderRegex
        }
        It 'Should match official:sensitive' {          
            $officialSensitive.HeaderExample | Should -Match $officialSensitive.HeaderRegex
        }  
        It 'Should not match official:sensitive legislative-secrecy' {          
            $officialSensitive.HeaderExample | Should -Not -Match $officeSensitiveLegislativeSecrecy.HeaderRegex
        } 
        It 'Should not match official:sensitive legal-privilege' {          
            $officialSensitive.HeaderExample | Should -Not -Match $officeSensitiveLegalPrivilege.HeaderRegex
        }
        It 'Should not match official:sensitive personal-privacy' {          
            $officialSensitive.HeaderExample | Should -Not -Match $officeSensitivePersonalPrivacy.HeaderRegex
        }                             
    }  

    Context "Evaluate official:sensitive legislative-secrecy" {
        It 'Should not match unofficial' {
            $officeSensitiveLegislativeSecrecy.HeaderExample | Should -Not -Match $unofficial.HeaderRegex
        } 
        It 'Should not match official' {          
            $officeSensitiveLegislativeSecrecy.HeaderExample | Should -Not -Match $official.HeaderRegex
        }
        It 'Should not match official:sensitive' {          
            $officeSensitiveLegislativeSecrecy.HeaderExample | Should -Not -Match $officialSensitive.HeaderRegex
        }  
        It 'Should match official:sensitive legislative-secrecy' {          
            $officeSensitiveLegislativeSecrecy.HeaderExample | Should -Match $officeSensitiveLegislativeSecrecy.HeaderRegex
        } 
        It 'Should match official:sensitive legal-privilege' {          
            $officeSensitiveLegislativeSecrecy.HeaderExample | Should -Not -Match $officeSensitiveLegalPrivilege.HeaderRegex
        }  
        It 'Should not match official:sensitive personal-privacy' {          
            $officeSensitiveLegislativeSecrecy.HeaderExample | Should -Not -Match $officeSensitivePersonalPrivacy.HeaderRegex
        }                           
    }

    Context "Evaluate official:sensitive legal-privilege" {
        It 'Should not match unofficial' {
            $officeSensitiveLegalPrivilege.HeaderExample | Should -Not -Match $unofficial.HeaderRegex
        } 
        It 'Should not match official' {          
            $officeSensitiveLegalPrivilege.HeaderExample | Should -Not -Match $official.HeaderRegex
        }
        It 'Should not match official:sensitive' {          
            $officeSensitiveLegalPrivilege.HeaderExample | Should -Not -Match $officialSensitive.HeaderRegex
        }  
        It 'Should not match official:sensitive legislative-secrecy' {          
            $officeSensitiveLegalPrivilege.HeaderExample | Should -Not -Match $officeSensitiveLegislativeSecrecy.HeaderRegex
        } 
        It 'Should match official:sensitive legal-privilege' {          
            $officeSensitiveLegalPrivilege.HeaderExample | Should -Match $officeSensitiveLegalPrivilege.HeaderRegex
        }  
        It 'Should not match official:sensitive personal-privacy' {          
            $officeSensitiveLegalPrivilege.HeaderExample | Should -Not -Match $officeSensitivePersonalPrivacy.HeaderRegex
        }                            
    }  
    
    Context "Evaluate official:sensitive personal-privacy" {
        It 'Should not match unofficial' {
            $officeSensitivePersonalPrivacy.HeaderExample | Should -Not -Match $unofficial.HeaderRegex
        } 
        It 'Should not match official' {          
            $officeSensitivePersonalPrivacy.HeaderExample | Should -Not -Match $official.HeaderRegex
        }
        It 'Should not match official:sensitive' {          
            $officeSensitivePersonalPrivacy.HeaderExample | Should -Not -Match $officialSensitive.HeaderRegex
        }  
        It 'Should not match official:sensitive legislative-secrecy' {          
            $officeSensitivePersonalPrivacy.HeaderExample | Should -Not -Match $officeSensitiveLegislativeSecrecy.HeaderRegex
        } 
        It 'Should match official:sensitive legal-privilege' {          
            $officeSensitivePersonalPrivacy.HeaderExample | Should -Not -Match $officeSensitiveLegalPrivilege.HeaderRegex
        }  
        It 'Should not match official:sensitive personal-privacy' {          
            $officeSensitivePersonalPrivacy.HeaderExample | Should -Match $officeSensitivePersonalPrivacy.HeaderRegex
        }                            
    }     
}