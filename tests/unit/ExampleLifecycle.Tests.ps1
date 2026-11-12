#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Describe 'Standalone example lifecycle' -Tag 'Unit' {
    BeforeAll {
        $Repository = Join-Path $PSScriptRoot '..\..'
    }

    BeforeEach {
        $PreviousEnvironment = @{}
        foreach ($Name in @('GITHUB_ACTIONS', 'GITHUB_JOB', 'AVM_INTEGRATION_MANAGEMENT_CIDR', 'AVM_INTEGRATION_LOCATION', 'AVM_INTEGRATION_VM_SKU')) {
            $PreviousEnvironment[$Name] = [Environment]::GetEnvironmentVariable($Name)
            [Environment]::SetEnvironmentVariable($Name, $null)
        }
        $Root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $Example = Join-Path $Root 'examples\default'
        $Setup = Join-Path $Root 'tests\integration'
        New-Item -ItemType Directory -Path $Example, $Setup -Force | Out-Null
        foreach ($Name in 'pre.ps1', 'post.ps1') {
            Copy-Item -LiteralPath (Join-Path $Repository "examples\default\$Name") -Destination $Example
        }
        Copy-Item -LiteralPath (Join-Path $Repository 'tests\integration\setup.ps1') -Destination $Setup
        $PreHook = Join-Path $Example 'pre.ps1'
        $PostHook = Join-Path $Example 'post.ps1'
        $Directory = Join-Path $Example '.generated'
        $PublicPath = Join-Path $Directory 'public.json'
        $PrivatePath = Join-Path $Directory 'private.json'
        $InputsPath = Join-Path $Example 'avm.generated.auto.tfvars.json'
        $env:AVM_INTEGRATION_MANAGEMENT_CIDR = '192.0.2.1/32'
        Mock Invoke-RestMethod { [pscustomobject]@{ ip = '8.8.8.8' } }
    }

    AfterEach {
        foreach ($Name in $PreviousEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable($Name, $PreviousEnvironment[$Name])
        }
    }

    It 'Generates real credentials and public metadata without external resource inputs' {
        & $PreHook
        $Public = Get-Content -LiteralPath $PublicPath -Raw | ConvertFrom-Json
        $Private = Get-Content -LiteralPath $PrivatePath -Raw | ConvertFrom-Json
        $Package = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Private.certificate_secret)) | ConvertFrom-Json
        $Certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new(
            [Convert]::FromBase64String($Package.data), $Package.password,
            [Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
        )
        try {
            $Certificate.HasPrivateKey | Should -BeTrue
            $Certificate.Thumbprint | Should -Be $Public.certificate_thumbprint
            $Public.management_source_prefix | Should -Be '192.0.2.1/32'
            $Public.location | Should -Be 'westus3'
            $Public.vm_sku | Should -Be 'Standard_D2s_v5'
            $Private.admin_password.Length | Should -BeGreaterThan 30
            $Inputs = Get-Content -LiteralPath $InputsPath -Raw | ConvertFrom-Json
            $Inputs.fixture_settings.certificate_thumbprint | Should -Be $Public.certificate_thumbprint
            $Inputs.fixture_secrets.admin_password | Should -Be $Private.admin_password
            if ($IsWindows) {
                $Owner = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
                foreach ($Rule in (Get-Acl -LiteralPath $InputsPath).Access) {
                    $Rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value | Should -Be $Owner
                }
            }
            else {
                [int][IO.File]::GetUnixFileMode($InputsPath) | Should -Be 384
            }
            Test-Path -LiteralPath (Join-Path $Example 'policy.auto.tfvars') | Should -BeFalse
        }
        finally {
            $Certificate.Dispose()
        }
    }

    It 'Uses the configured location and VM size' {
        $env:AVM_INTEGRATION_LOCATION = 'centralus'
        $env:AVM_INTEGRATION_VM_SKU = 'Standard_D4s_v5'
        & $PreHook
        $Public = Get-Content -LiteralPath $PublicPath -Raw | ConvertFrom-Json
        $Public.location | Should -Be 'centralus'
        $Public.vm_sku | Should -Be 'Standard_D4s_v5'
    }

    It 'Discovers only the real E2E runner IPv4 when no CIDR is configured' {
        $env:AVM_INTEGRATION_MANAGEMENT_CIDR = $null
        $env:GITHUB_ACTIONS = 'true'
        $env:GITHUB_JOB = 'e2e-test'
        & $PreHook
        (Get-Content -LiteralPath $PublicPath -Raw | ConvertFrom-Json).management_source_prefix | Should -Be '8.8.8.8/32'
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly
    }

    It 'Honors an explicit CIDR without discovery' {
        $env:GITHUB_ACTIONS = 'true'
        $env:GITHUB_JOB = 'e2e-test'
        & $PreHook
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    }

    It 'Uses a documentation CIDR only for the isolated PR policy plan' {
        $env:AVM_INTEGRATION_MANAGEMENT_CIDR = $null
        $env:GITHUB_ACTIONS = 'true'
        $env:GITHUB_JOB = 'pr-check'
        & $PreHook
        (Get-Content -LiteralPath $PublicPath -Raw | ConvertFrom-Json).management_source_prefix | Should -Be '192.0.2.1/32'
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    }

    It 'Requires an approved CIDR for local deployment' {
        $env:AVM_INTEGRATION_MANAGEMENT_CIDR = $null
        { & $PreHook } | Should -Throw '*approved runner IPv4 CIDR*'
        Test-Path -LiteralPath $Directory | Should -BeFalse
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    }

    It 'Stops rather than replacing failed runner discovery with policy inputs' {
        $env:AVM_INTEGRATION_MANAGEMENT_CIDR = $null
        $env:GITHUB_ACTIONS = 'true'
        $env:GITHUB_JOB = 'e2e-test'
        Mock Invoke-RestMethod { throw 'Discovery unavailable' }
        { & $PreHook } | Should -Throw '*Runner IPv4 discovery failed*'
        Test-Path -LiteralPath $Directory | Should -BeFalse
    }

    It 'Keeps names and credentials stable when the pre-hook is rerun' {
        & $PreHook
        $PublicHash = (Get-FileHash -LiteralPath $PublicPath).Hash
        $PrivateHash = (Get-FileHash -LiteralPath $PrivatePath).Hash
        $InputsHash = (Get-FileHash -LiteralPath $InputsPath).Hash
        & $PreHook
        (Get-FileHash -LiteralPath $PublicPath).Hash | Should -Be $PublicHash
        (Get-FileHash -LiteralPath $PrivatePath).Hash | Should -Be $PrivateHash
        (Get-FileHash -LiteralPath $InputsPath).Hash | Should -Be $InputsHash
    }

    It 'Refuses to overwrite incomplete credential material' {
        New-Item -ItemType Directory -Path $Directory | Out-Null
        Set-Content -LiteralPath $PublicPath -Value '{}'
        { & $PreHook } | Should -Throw '*Incomplete example credentials*'
        Test-Path -LiteralPath $PrivatePath | Should -BeFalse
    }

    It 'Removes generated credentials after an empty-state destroy' {
        & $PreHook
        Set-Content -LiteralPath (Join-Path $Example 'terraform.tfstate') -Value '{"resources":[]}'
        & $PostHook
        Test-Path -LiteralPath $Directory | Should -BeFalse
        Test-Path -LiteralPath $InputsPath | Should -BeFalse
    }

    It 'Cleans policy-plan credentials without a state file and preserves unrelated files' {
        & $PreHook
        Set-Content -LiteralPath (Join-Path $Directory 'keep.txt') -Value 'unrelated'
        & $PostHook
        Test-Path -LiteralPath $PublicPath | Should -BeFalse
        Test-Path -LiteralPath $PrivatePath | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $Directory 'keep.txt') | Should -BeTrue
    }

    It 'Retains credentials and reports an error if Terraform still tracks resources' {
        & $PreHook
        Set-Content -LiteralPath (Join-Path $Example 'terraform.tfstate') -Value '{"resources":[{"type":"azapi_resource"}]}'
        { & $PostHook } | Should -Throw '*state still contains resources*'
        Test-Path -LiteralPath $PublicPath | Should -BeTrue
        Test-Path -LiteralPath $PrivatePath | Should -BeTrue
        Test-Path -LiteralPath $InputsPath | Should -BeTrue
    }

    It 'Retains credentials if Terraform state cannot be parsed' {
        & $PreHook
        Set-Content -LiteralPath (Join-Path $Example 'terraform.tfstate') -Value 'invalid state'
        { & $PostHook } | Should -Throw
        Test-Path -LiteralPath $PrivatePath | Should -BeTrue
    }
}
