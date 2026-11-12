#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Supplies illustrative inputs for the managed PR policy plan.
.DESCRIPTION
    Copies the public sample settings only in the managed pr-check job, which
    plans the example in an isolated staging directory without applying it.
    Local runs and deployment jobs must supply their own existing infrastructure.
.EXAMPLE
    .\pre.ps1
.NOTES
    Invoked by Avm.Authoring before example policy planning.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if ($MyInvocation.InvocationName -ne '.') {
    if ($env:GITHUB_ACTIONS -ceq 'true' -and $env:GITHUB_JOB -ceq 'pr-check') {
        $Destination = Join-Path $PSScriptRoot 'policy.auto.tfvars'
        if (Test-Path -LiteralPath $Destination) {
            throw 'Refusing to overwrite existing policy.auto.tfvars settings.'
        }

        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'terraform.tfvars.example') -Destination $Destination
        Write-Host 'Prepared illustrative inputs for the PR policy plan only. No Azure resources were deployed.'
    }
    else {
        Write-Host 'Policy sample inputs are disabled outside the managed PR-check job. Supply existing-infrastructure inputs.'
    }
}
