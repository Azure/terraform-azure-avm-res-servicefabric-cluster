#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

Describe 'Example policy-plan inputs' -Tag 'Unit' {
    BeforeAll {
        $SourceDirectory = Join-Path $PSScriptRoot '..\..\examples\default'
    }

    BeforeEach {
        $PreviousGitHubActions = $env:GITHUB_ACTIONS
        $PreviousGitHubJob = $env:GITHUB_JOB
        $env:GITHUB_ACTIONS = $null
        $env:GITHUB_JOB = $null
        $Directory = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $Directory | Out-Null
        foreach ($File in 'pre.ps1', 'terraform.tfvars.example') {
            Copy-Item -LiteralPath (Join-Path $SourceDirectory $File) -Destination $Directory
        }
        $Hook = Join-Path $Directory 'pre.ps1'
        $Inputs = Join-Path $Directory 'policy.auto.tfvars'
    }

    AfterEach {
        $env:GITHUB_ACTIONS = $PreviousGitHubActions
        $env:GITHUB_JOB = $PreviousGitHubJob
    }

    It 'Does not create illustrative inputs outside GitHub Actions' {
        $env:GITHUB_JOB = 'pr-check'
        & $Hook
        Test-Path -LiteralPath $Inputs | Should -BeFalse
    }

    It 'Does not create illustrative inputs in the <Job> job' -ForEach @(
        @{ Job = 'e2e-execute' },
        @{ Job = 'integration-tests' },
        @{ Job = 'unit-tests' },
        @{ Job = '' }
    ) {
        $env:GITHUB_ACTIONS = 'true'
        $env:GITHUB_JOB = $Job
        & $Hook
        Test-Path -LiteralPath $Inputs | Should -BeFalse
    }

    It 'Copies all required sample inputs only in the managed PR-check job' {
        $env:GITHUB_ACTIONS = 'true'
        $env:GITHUB_JOB = 'pr-check'
        & $Hook
        $Content = Get-Content -LiteralPath $Inputs -Raw
        $Content | Should -BeExactly (Get-Content -LiteralPath (Join-Path $Directory 'terraform.tfvars.example') -Raw)
        foreach ($Name in @(
            'admin_client_certificate_common_name',
            'admin_client_certificate_issuer_thumbprint',
            'certificate_common_name',
            'certificate_issuer_thumbprint',
            'management_endpoint',
            'parent_id'
        )) {
            $Content | Should -Match "(?m)^$Name\s*="
        }
    }

    It 'Refuses to overwrite existing policy settings' {
        $env:GITHUB_ACTIONS = 'true'
        $env:GITHUB_JOB = 'pr-check'
        Set-Content -LiteralPath $Inputs -Value 'existing settings'
        { & $Hook } | Should -Throw '*Refusing to overwrite*'
        Get-Content -LiteralPath $Inputs | Should -BeExactly 'existing settings'
    }

    It 'Fails explicitly when the sample settings are missing' {
        $env:GITHUB_ACTIONS = 'true'
        $env:GITHUB_JOB = 'pr-check'
        Remove-Item -LiteralPath (Join-Path $Directory 'terraform.tfvars.example')
        { & $Hook } | Should -Throw
        Test-Path -LiteralPath $Inputs | Should -BeFalse
    }
}
