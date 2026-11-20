#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../integration/setup.ps1')
}

Describe 'Terraform test module directories' -Tag 'Unit' {
    It 'Creates the unit test parent directory' {
        $Root = Join-Path $TestDrive 'unit'
        New-Item -ItemType Directory -Path (Join-Path $Root 'tests/unit') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'setup.ps1') -Destination (Join-Path $Root 'tests/unit')

        & (Join-Path $Root 'tests/unit/setup.ps1')

        Test-Path -LiteralPath (Join-Path $Root '.terraform/modules/test.tests/unit') -PathType Container | Should -BeTrue
    }

    It 'Creates the integration parent directory only inside a Terraform module' {
        $Root = Join-Path $TestDrive 'integration'
        New-Item -ItemType Directory -Path $Root -Force | Out-Null
        Initialize-TestModuleDirectory -ModuleRoot $Root -TestPath 'tests/integration'
        Test-Path -LiteralPath (Join-Path $Root '.terraform') | Should -BeFalse

        Set-Content -LiteralPath (Join-Path $Root 'terraform.tf') -Value 'terraform {}'
        Initialize-TestModuleDirectory -ModuleRoot $Root -TestPath 'tests/integration'

        Test-Path -LiteralPath (Join-Path $Root '.terraform/modules/test.tests/integration') -PathType Container | Should -BeTrue
    }
}
