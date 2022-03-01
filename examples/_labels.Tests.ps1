# To do: make this much prettier and add subject tests.

#Requires -Modules @{ ModuleName = "Pester"; ModuleVersion = "5.3.1" }

BeforeAll { 

    # Import our functions to test.
    Try {
        . $PSCommandPath.Replace('.Tests.ps1','.ps1')
    } Catch {
        Throw 'Could not import pre-requisites ($_.Exception).'
    }

    $labels = Get-EPMSLabels    

    # Assign our test variables.
    $unofficial = $labels | Where-Object { $_.Identifier -eq 'unofficial'}

    $official = $labels | Where-Object { $_.Identifier -eq 'official'}
    $officialSensitive = $labels | Where-Object { $_.Identifier -eq 'official-sensitive'}
    $officialSensitiveLegalPrivilege = $labels | Where-Object { $_.Identifier -eq 'official-sensitive-legal-privilege'}
    $officialSensitiveLegislativeSecrecy = $labels | Where-Object { $_.Identifier -eq 'official-sensitive-legislative-secrecy'}
    $officialSensitivePersonalPrivacy = $labels | Where-Object { $_.Identifier -eq 'official-sensitive-personal-privacy'}
    
    $protected = $labels | Where-Object { $_.Identifier -eq 'protected'}
    $protectedLegalPrivilege = $labels | Where-Object { $_.Identifier -eq 'protected-legal-privilege'}
    $protectedLegislativeSecrecy = $labels | Where-Object { $_.Identifier -eq 'protected-legislative-secrecy'}
    $protectedPersonalPrivacy = $labels | Where-Object { $_.Identifier -eq 'protected-personal-privacy'}
}

Describe "Get-Labels" {
    Context "Evaluate unofficial regular expressions" {
        It "Should match unofficial and no others" {
            $unofficial.HeaderExample | Should -Match $unofficial.HeaderRegex      
            $unofficial.HeaderExample | Should -Not -Match $official.HeaderRegex      
            $unofficial.HeaderExample | Should -Not -Match $officialSensitive.HeaderRegex    
            $unofficial.HeaderExample | Should -Not -Match $officialSensitiveLegislativeSecrecy.HeaderRegex       
            $unofficial.HeaderExample | Should -Not -Match $officialSensitiveLegalPrivilege.HeaderRegex     
            $unofficial.HeaderExample | Should -Not -Match $officialSensitivePersonalPrivacy.HeaderRegex
            $unofficial.HeaderExample | Should -Not -Match $protected.HeaderRegex      
            $unofficial.HeaderExample | Should -Not -Match $protectedLegalPrivilege.HeaderRegex      
            $unofficial.HeaderExample | Should -Not -Match $protectedLegislativeSecrecy.HeaderRegex      
            $unofficial.HeaderExample | Should -Not -Match $protectedPersonalPrivacy.HeaderRegex
        }                 

    }
    Context "Evaluate official regular expressions" {
        It 'Should match official and no others' {
            $official.HeaderExample | Should -Not -Match $unofficial.HeaderRegex
            $official.HeaderExample | Should -Match $official.HeaderRegex
            $official.HeaderExample | Should -Not -Match $officialSensitive.HeaderRegex 
            $official.HeaderExample | Should -Not -Match $officialSensitiveLegislativeSecrecy.HeaderRegex
            $official.HeaderExample | Should -Not -Match $officialSensitiveLegalPrivilege.HeaderRegex       
            $official.HeaderExample | Should -Not -Match $officialSensitivePersonalPrivacy.HeaderRegex        
            $official.HeaderExample | Should -Not -Match $protected.HeaderRegex      
            $official.HeaderExample | Should -Not -Match $protectedLegalPrivilege.HeaderRegex      
            $official.HeaderExample | Should -Not -Match $protectedLegislativeSecrecy.HeaderRegex       
            $official.HeaderExample | Should -Not -Match $protectedPersonalPrivacy.HeaderRegex      
        }                    
    } 
    Context "Evaluate official:sensitive regular expressions" {
        It 'Should match official:sensitive and no others' {   
            $officialSensitive.HeaderExample | Should -Not -Match $unofficial.HeaderRegex 
            $officialSensitive.HeaderExample | Should -Not -Match $official.HeaderRegex
            $officialSensitive.HeaderExample | Should -Match $officialSensitive.HeaderRegex
            $officialSensitive.HeaderExample | Should -Not -Match $officialSensitiveLegislativeSecrecy.HeaderRegex 
            $officialSensitive.HeaderExample | Should -Not -Match $officialSensitiveLegalPrivilege.HeaderRegex       
            $officialSensitive.HeaderExample | Should -Not -Match $officialSensitivePersonalPrivacy.HeaderRegex      
            $officialSensitive.HeaderExample | Should -Not -Match $protected.HeaderRegex        
            $officialSensitive.HeaderExample | Should -Not -Match $protectedLegalPrivilege.HeaderRegex   
            $officialSensitive.HeaderExample | Should -Not -Match $protectedLegislativeSecrecy.HeaderRegex
            $officialSensitive.HeaderExample | Should -Not -Match $protectedPersonalPrivacy.HeaderRegex
        }                                     
    }  

    Context "Evaluate official:sensitive legislative-secrecy regular expressions" {
        It 'Should match official:sensitive legislative-secrecy and no others' {      
            $officialSensitiveLegislativeSecrecy.HeaderExample | Should -Not -Match $unofficial.HeaderRegex        
            $officialSensitiveLegislativeSecrecy.HeaderExample | Should -Not -Match $official.HeaderRegex
            $officialSensitiveLegislativeSecrecy.HeaderExample | Should -Not -Match $officialSensitive.HeaderRegex
            $officialSensitiveLegislativeSecrecy.HeaderExample | Should -Match $officialSensitiveLegislativeSecrecy.HeaderRegex
            $officialSensitiveLegislativeSecrecy.HeaderExample | Should -Not -Match $officialSensitiveLegalPrivilege.HeaderRegex
            $officialSensitiveLegislativeSecrecy.HeaderExample | Should -Not -Match $officialSensitivePersonalPrivacy.HeaderRegex
            $officialSensitiveLegislativeSecrecy.HeaderExample | Should -Not -Match $protected.HeaderRegex
            $officialSensitiveLegislativeSecrecy.HeaderExample | Should -Not -Match $protectedLegalPrivilege.HeaderRegex
            $officialSensitiveLegislativeSecrecy.HeaderExample | Should -Not -Match $protectedLegislativeSecrecy.HeaderRegex
            $officialSensitiveLegislativeSecrecy.HeaderExample | Should -Not -Match $protectedPersonalPrivacy.HeaderRegex
        }                                   
    }

    Context "Evaluate official:sensitive legal-privilege regular expressions" {
        It 'Should match official:sensitive legal-privilege and no others' {
            $officialSensitiveLegalPrivilege.HeaderExample | Should -Not -Match $unofficial.HeaderRegex
            $officialSensitiveLegalPrivilege.HeaderExample | Should -Not -Match $official.HeaderRegex
            $officialSensitiveLegalPrivilege.HeaderExample | Should -Not -Match $officialSensitive.HeaderRegex
            $officialSensitiveLegalPrivilege.HeaderExample | Should -Not -Match $officialSensitiveLegislativeSecrecy.HeaderRegex
            $officialSensitiveLegalPrivilege.HeaderExample | Should -Match $officialSensitiveLegalPrivilege.HeaderRegex
            $officialSensitiveLegalPrivilege.HeaderExample | Should -Not -Match $officialSensitivePersonalPrivacy.HeaderRegex
            $officialSensitiveLegalPrivilege.HeaderExample | Should -Not -Match $protected.HeaderRegex
            $officialSensitiveLegalPrivilege.HeaderExample | Should -Not -Match $protectedLegalPrivilege.HeaderRegex
            $officialSensitiveLegalPrivilege.HeaderExample | Should -Not -Match $protectedLegislativeSecrecy.HeaderRegex
            $officialSensitiveLegalPrivilege.HeaderExample | Should -Not -Match $protectedPersonalPrivacy.HeaderRegex
        }                                    
    }  
    
    Context "Evaluate official:sensitive personal-privacy regular expressions" {
        It 'Should match official:sensitive legal-privilege and no others' { 
            $officialSensitivePersonalPrivacy.HeaderExample | Should -Not -Match $unofficial.HeaderRegex
            $officialSensitivePersonalPrivacy.HeaderExample | Should -Not -Match $official.HeaderRegex
            $officialSensitivePersonalPrivacy.HeaderExample | Should -Not -Match $officialSensitive.HeaderRegex
            $officialSensitivePersonalPrivacy.HeaderExample | Should -Not -Match $officialSensitiveLegislativeSecrecy.HeaderRegex
            $officialSensitivePersonalPrivacy.HeaderExample | Should -Not -Match $officialSensitiveLegalPrivilege.HeaderRegex
            $officialSensitivePersonalPrivacy.HeaderExample | Should -Match $officialSensitivePersonalPrivacy.HeaderRegex
            $officialSensitivePersonalPrivacy.HeaderExample | Should -Not -Match $protected.HeaderRegex
            $officialSensitivePersonalPrivacy.HeaderExample | Should -Not -Match $protectedLegalPrivilege.HeaderRegex
            $officialSensitivePersonalPrivacy.HeaderExample | Should -Not -Match $protectedLegislativeSecrecy.HeaderRegex
            $officialSensitivePersonalPrivacy.HeaderExample | Should -Not -Match $protectedPersonalPrivacy.HeaderRegex
        }                                     
    }    
    
    Context "Evaluate protected regular expressions" {
        It 'Should match protected and no others' { 
            $protected.HeaderExample | Should -Not -Match $unofficial.HeaderRegex
            $protected.HeaderExample | Should -Not -Match $official.HeaderRegex
            $protected.HeaderExample | Should -Not -Match $officialSensitive.HeaderRegex
            $protected.HeaderExample | Should -Not -Match $officialSensitiveLegislativeSecrecy.HeaderRegex
            $protected.HeaderExample | Should -Not -Match $officialSensitiveLegalPrivilege.HeaderRegex
            $protected.HeaderExample | Should -Not -Match $officialSensitivePersonalPrivacy.HeaderRegex
            $protected.HeaderExample | Should -Match $protected.HeaderRegex
            $protected.HeaderExample | Should -Not -Match $protectedLegalPrivilege.HeaderRegex
            $protected.HeaderExample | Should -Not -Match $protectedLegislativeSecrecy.HeaderRegex
            $protected.HeaderExample | Should -Not -Match $protectedPersonalPrivacy.HeaderRegex
        }                                     
    } 

    Context "Evaluate protected legislative-secrecy regular expressions" {
        It 'Should match protected legislative-secrecy and no others' { 
            $protectedLegislativeSecrecy.HeaderExample | Should -Not -Match $unofficial.HeaderRegex
            $protectedLegislativeSecrecy.HeaderExample | Should -Not -Match $official.HeaderRegex
            $protectedLegislativeSecrecy.HeaderExample | Should -Not -Match $officialSensitive.HeaderRegex
            $protectedLegislativeSecrecy.HeaderExample | Should -Not -Match $officialSensitiveLegislativeSecrecy.HeaderRegex
            $protectedLegislativeSecrecy.HeaderExample | Should -Not -Match $officialSensitiveLegalPrivilege.HeaderRegex
            $protectedLegislativeSecrecy.HeaderExample | Should -Not -Match $officialSensitivePersonalPrivacy.HeaderRegex
            $protectedLegislativeSecrecy.HeaderExample | Should -Not -Match $protected.HeaderRegex
            $protectedLegislativeSecrecy.HeaderExample | Should -Not -Match $protectedLegalPrivilege.HeaderRegex
            $protectedLegislativeSecrecy.HeaderExample | Should -Match $protectedLegislativeSecrecy.HeaderRegex
            $protectedLegislativeSecrecy.HeaderExample | Should -Not -Match $protectedPersonalPrivacy.HeaderRegex
        }                                     
    }    

    Context "Evaluate protected legal-privilege regular expressions" {
        It 'Should match protected legal-privilege and no others' { 
            $protectedLegalPrivilege.HeaderExample | Should -Not -Match $unofficial.HeaderRegex
            $protectedLegalPrivilege.HeaderExample | Should -Not -Match $official.HeaderRegex
            $protectedLegalPrivilege.HeaderExample | Should -Not -Match $officialSensitive.HeaderRegex
            $protectedLegalPrivilege.HeaderExample | Should -Not -Match $officialSensitiveLegislativeSecrecy.HeaderRegex
            $protectedLegalPrivilege.HeaderExample | Should -Not -Match $officialSensitiveLegalPrivilege.HeaderRegex
            $protectedLegalPrivilege.HeaderExample | Should -Not -Match $officialSensitivePersonalPrivacy.HeaderRegex
            $protectedLegalPrivilege.HeaderExample | Should -Not -Match $protected.HeaderRegex
            $protectedLegalPrivilege.HeaderExample | Should -Match $protectedLegalPrivilege.HeaderRegex
            $protectedLegalPrivilege.HeaderExample | Should -Not -Match $protectedLegislativeSecrecy.HeaderRegex
            $protectedLegalPrivilege.HeaderExample | Should -Not -Match $protectedPersonalPrivacy.HeaderRegex
        }                                     
    } 
    
    Context "Evaluate protected personal-privacy regular expressions" {
        It 'Should match protected personal-privacy and no others' { 
            $protectedPersonalPrivacy.HeaderExample | Should -Not -Match $unofficial.HeaderRegex
            $protectedPersonalPrivacy.HeaderExample | Should -Not -Match $official.HeaderRegex
            $protectedPersonalPrivacy.HeaderExample | Should -Not -Match $officialSensitive.HeaderRegex
            $protectedPersonalPrivacy.HeaderExample | Should -Not -Match $officialSensitiveLegislativeSecrecy.HeaderRegex
            $protectedPersonalPrivacy.HeaderExample | Should -Not -Match $officialSensitiveLegalPrivilege.HeaderRegex
            $protectedPersonalPrivacy.HeaderExample | Should -Not -Match $officialSensitivePersonalPrivacy.HeaderRegex
            $protectedPersonalPrivacy.HeaderExample | Should -Not -Match $protected.HeaderRegex
            $protectedPersonalPrivacy.HeaderExample | Should -Not -Match $protectedLegalPrivilege.HeaderRegex
            $protectedPersonalPrivacy.HeaderExample | Should -Not -Match $protectedLegislativeSecrecy.HeaderRegex
            $protectedPersonalPrivacy.HeaderExample | Should -Match $protectedPersonalPrivacy.HeaderRegex
        }                                     
    }     
}