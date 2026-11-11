#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '..\integration\setup.ps1')
}

Describe 'Integration certificate preparation' -Tag 'Unit' {
    It 'Creates a matching exportable certificate without putting private material in public metadata' {
        $Directory = Join-Path $TestDrive 'certificate'
        New-IntegrationMaterial -OutputDirectory $Directory -ManagementSourcePrefix '192.0.2.1/32'
        $Public = Get-Content -Raw (Join-Path $Directory 'public.json') | ConvertFrom-Json
        $Private = Get-Content -Raw (Join-Path $Directory 'private.json') | ConvertFrom-Json
        $Package = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Private.certificate_secret)) | ConvertFrom-Json
        $Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
            [Convert]::FromBase64String($Package.data), $Package.password,
            [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
        )
        try {
            $Certificate.Thumbprint | Should -Be $Public.certificate_thumbprint
            $Certificate.HasPrivateKey | Should -BeTrue
            $Certificate.Subject | Should -Be "CN=$($Public.certificate_common_name)"
            $Certificate.NotAfter.ToUniversalTime() | Should -BeLessThan ([DateTime]::UtcNow.AddDays(46))
            $Certificate.NotAfter.ToUniversalTime() | Should -BeGreaterThan ([DateTime]::UtcNow.AddDays(44))
            $Package.dataType | Should -Be 'pfx'
            $Private.admin_password.Length | Should -BeGreaterThan 30
            $Public.PSObject.Properties.Name | Should -Not -Contain 'admin_password'
            $Public.PSObject.Properties.Name | Should -Not -Contain 'certificate_secret'
            $Usages = ($Certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' }).EnhancedKeyUsages.Value
            $Usages | Should -Contain '1.3.6.1.5.5.7.3.1'
            $Usages | Should -Contain '1.3.6.1.5.5.7.3.2'
            if ($IsWindows) {
                $Owner = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
                $Access = (Get-Acl -LiteralPath (Join-Path $Directory 'private.json')).Access
                foreach ($Rule in $Access) {
                    $Rule.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value | Should -Be $Owner
                }
            }

            else {
                [int][System.IO.File]::GetUnixFileMode((Join-Path $Directory 'private.json')) | Should -Be 384
            }
        }
        finally {
            $Certificate.Dispose()
        }
    }

    It 'Rejects unsafe or invalid gateway source <Cidr>' -ForEach @(
        @{ Cidr = '0.0.0.0/0' },
        @{ Cidr = 'not-an-address/32' },
        @{ Cidr = '192.0.2.1/33' },
        @{ Cidr = '::1/128' }
    ) {
        { New-IntegrationMaterial -OutputDirectory (Join-Path $TestDrive 'invalid') -ManagementSourcePrefix $Cidr } | Should -Throw '*restricted IPv4 CIDR*'
    }

    It 'Cleans only the generated files and preserves unrelated content' {
        $Directory = Join-Path $TestDrive 'cleanup'
        New-IntegrationMaterial -OutputDirectory $Directory -ManagementSourcePrefix '192.0.2.1/32'
        Set-Content -LiteralPath (Join-Path $Directory 'keep.txt') -Value 'unrelated'
        Remove-IntegrationMaterial -OutputDirectory $Directory
        Test-Path (Join-Path $Directory 'private.json') | Should -BeFalse
        Test-Path (Join-Path $Directory 'public.json') | Should -BeFalse
        Test-Path (Join-Path $Directory 'keep.txt') | Should -BeTrue
    }
}

Describe 'Integration execution guard and cleanup' -Tag 'Unit' {
    BeforeAll {
        function avm { throw 'The integration command must be mocked in local tests.' }
    }

    Describe 'Integration guest DNS verification' -Tag 'Unit' {
        BeforeAll {
            $Fixture = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\integration\setup\main.tf') -Raw
            $GuestScript = [regex]::Match($Fixture, '(?s)<<-POWERSHELL\r?\n(?<Script>.*?)\r?\n\s*POWERSHELL').Groups['Script'].Value
            if (-not $GuestScript) { throw 'The integration guest script was not found.' }
            $GuestScript = $GuestScript.Replace('${local.settings.certificate_thumbprint}', 'test-thumbprint').
                Replace('${var.validation_revision}', 'test').
                Replace('${var.configure_optional_features ? "$true" : "$false"}', '$true')
            $ParseErrors = $null
            $Ast = [System.Management.Automation.Language.Parser]::ParseInput($GuestScript, [ref]$null, [ref]$ParseErrors)
            if ($ParseErrors) { throw "The integration guest script has syntax errors: $ParseErrors" }
            $HealthTry = $Ast.Find({ param($Node) $Node -is [System.Management.Automation.Language.TryStatementAst] }, $true)
            if (-not $HealthTry) { throw 'The integration guest health probe was not found.' }
            $Body = $HealthTry.Body.Extent.Text
            $Body = $Body.Substring(1, $Body.Length - 2).Replace('exit 0', 'return')
            $HealthProbe = [scriptblock]::Create("param([bool]`$RequireDnsService)`n$Body")
            function Connect-ServiceFabricCluster {}
            function Get-ServiceFabricNode {}
            function Get-ServiceFabricClusterHealth {}
            function Get-ServiceFabricServiceHealth {
                param([string]$ServiceName, [int]$TimeoutSec)
            }
        }

        BeforeEach {
            Mock Connect-ServiceFabricCluster {}
            Mock Get-ServiceFabricNode {
                1..3 | ForEach-Object { [pscustomobject]@{ NodeStatus = 'Up' } }
            }
            Mock Get-ServiceFabricClusterHealth { [pscustomobject]@{ AggregatedHealthState = 'Ok' } }
            Mock Get-ServiceFabricServiceHealth { [pscustomobject]@{ AggregatedHealthState = 'Ok' } }
        }

        It 'Requires healthy DNS at the system service URI when enabled' {
            $Output = @(& $HealthProbe $true)
            $Output | Should -Contain 'AVM_DNS_OK_test'
            $Output | Should -Contain 'AVM_HEALTH_OK_test'
            Should -Invoke Get-ServiceFabricServiceHealth -Times 1 -Exactly -ParameterFilter {
                $ServiceName -eq 'fabric:/System/DnsService' -and $TimeoutSec -eq 30
            }
        }

        It 'Does not query or claim DNS verification when disabled' {
            $Output = @(& $HealthProbe $false)
            $Output | Should -Contain 'AVM_HEALTH_OK_test'
            $Output | Should -Not -Contain 'AVM_DNS_OK_test'
            Should -Invoke Get-ServiceFabricServiceHealth -Times 0 -Exactly
        }

        It 'Withholds success markers when DNS health is <Health>' -ForEach @(
            @{ Health = 'Warning' },
            @{ Health = 'Error' }
        ) {
            Mock Get-ServiceFabricServiceHealth { [pscustomobject]@{ AggregatedHealthState = $Health } }
            $Output = @(& $HealthProbe $true)
            $Output | Should -Not -Contain 'AVM_HEALTH_OK_test'
            $Output | Should -Not -Contain 'AVM_DNS_OK_test'
        }

        It 'Does not treat a missing DNS service as healthy' {
            Mock Get-ServiceFabricServiceHealth { throw 'ServiceNotFound' }
            { & $HealthProbe $true } | Should -Throw '*ServiceNotFound*'
        }
    }

    BeforeEach {
        $Directory = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $Integration = Join-Path $Directory 'tests\integration'
        New-Item -ItemType Directory -Path $Integration -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\integration\Invoke-IntegrationTests.ps1') -Destination $Integration
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\integration\setup.ps1') -Destination $Integration
        $Runner = Join-Path $Integration 'Invoke-IntegrationTests.ps1'
        $Generated = Join-Path $Integration '.generated'
        New-Item -ItemType Directory -Path $Generated | Out-Null
        Set-Content -LiteralPath (Join-Path $Generated 'private.json') -Value '{}'
        Set-Content -LiteralPath (Join-Path $Generated 'public.json') -Value '{}'
        $Approved = '00000000-0000-0000-0000-000000000001'
        $OldSubscription = $env:ARM_SUBSCRIPTION_ID
        $OldCidr = $env:AVM_INTEGRATION_MANAGEMENT_CIDR
        $OldLocation = $env:AVM_INTEGRATION_LOCATION
        $OldVmSku = $env:AVM_INTEGRATION_VM_SKU
        $env:ARM_SUBSCRIPTION_ID = $Approved
        $env:AVM_INTEGRATION_MANAGEMENT_CIDR = 'sentinel'
        Mock Import-Module {}
        Mock avm {}
    }

    AfterEach {
        $env:ARM_SUBSCRIPTION_ID = $OldSubscription
        $env:AVM_INTEGRATION_MANAGEMENT_CIDR = $OldCidr
        $env:AVM_INTEGRATION_LOCATION = $OldLocation
        $env:AVM_INTEGRATION_VM_SKU = $OldVmSku
    }

    It 'Rejects a dotenv subscription that would override the approved target' {
        Set-Content -LiteralPath (Join-Path $Directory '.env') -Value 'export ARM_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000002"'
        { & $Runner -SubscriptionId $Approved -ManagementSourcePrefix '192.0.2.1/32' } | Should -Throw '*does not match*'
        Should -Invoke avm -Times 0 -Exactly
        Test-Path -LiteralPath $Generated | Should -BeFalse
    }

    It 'Invokes managed integration and restores configuration after success' {
        & $Runner -SubscriptionId $Approved -ManagementSourcePrefix '192.0.2.1/32'
        Should -Invoke avm -Times 1 -Exactly
        $env:AVM_INTEGRATION_MANAGEMENT_CIDR | Should -Be 'sentinel'
        Test-Path -LiteralPath $Generated | Should -BeFalse
    }

    It 'Preserves a suite failure while removing generated files and restoring configuration' {
        Mock avm { throw 'Simulated integration failure' }
        { & $Runner -SubscriptionId $Approved -ManagementSourcePrefix '192.0.2.1/32' } | Should -Throw '*Simulated integration failure*'
        $env:AVM_INTEGRATION_MANAGEMENT_CIDR | Should -Be 'sentinel'
        Test-Path -LiteralPath $Generated | Should -BeFalse
    }

    It 'Uses documented defaults when optional environment overrides are empty' {
        $env:AVM_INTEGRATION_MANAGEMENT_CIDR = '192.0.2.1/32'
        $env:AVM_INTEGRATION_LOCATION = ''
        $env:AVM_INTEGRATION_VM_SKU = ''
        & (Join-Path $Integration 'setup.ps1')
        $Public = Get-Content -LiteralPath (Join-Path $Generated 'public.json') -Raw | ConvertFrom-Json
        $Public.location | Should -Be 'westus3'
        $Public.vm_sku | Should -Be 'Standard_D2s_v5'
        Remove-IntegrationMaterial -OutputDirectory $Generated
    }

    It 'Can regenerate credentials in repeated non-interactive setup hook processes' {
        $env:AVM_INTEGRATION_MANAGEMENT_CIDR = '192.0.2.1/32'
        $Hook = Join-Path $Integration 'setup.ps1'
        & pwsh -NoProfile -NonInteractive -File $Hook
        $LASTEXITCODE | Should -Be 0
        & pwsh -NoProfile -NonInteractive -File $Hook
        $LASTEXITCODE | Should -Be 0
        Remove-IntegrationMaterial -OutputDirectory $Generated
    }
}
