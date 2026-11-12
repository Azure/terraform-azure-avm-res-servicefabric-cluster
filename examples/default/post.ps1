#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Remove generated credentials after Terraform cleanup.
.DESCRIPTION
    Retains credentials when resources remain in local state so that a failed
    destroy can be retried without losing write-only inputs.
.EXAMPLE
    .\post.ps1
.NOTES
    Invoked by Avm.Authoring after policy planning or E2E cleanup.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if ($MyInvocation.InvocationName -ne '.') {
    . (Join-Path $PSScriptRoot '..\..\tests\integration\setup.ps1')
    $StatePath = Join-Path $PSScriptRoot 'terraform.tfstate'
    if (Test-Path -LiteralPath $StatePath) {
        $State = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
        if (@($State.resources).Count -gt 0) {
            throw 'Terraform state still contains resources. Retaining example credentials; retry terraform destroy before running post.ps1.'
        }
    }
    $Directory = Join-Path $PSScriptRoot '.generated'
    $InputsPath = Join-Path $PSScriptRoot 'avm.generated.auto.tfvars.json'
    if ((Test-Path -LiteralPath $Directory) -and (Test-Path -LiteralPath $InputsPath)) {
        Remove-Item -LiteralPath $InputsPath -Force
    }
    Remove-IntegrationMaterial -OutputDirectory $Directory
    Write-Host 'Removed generated example credentials.'
}
