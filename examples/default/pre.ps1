#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Prepare real certificate material for the standalone cluster example.
.DESCRIPTION
    Reuses the integration credential generator without provisioning Azure.
    Keeps credentials stable until Terraform has destroyed the deployment.
.EXAMPLE
    .\pre.ps1
.NOTES
    Invoked by Avm.Authoring before policy planning and E2E deployment.
    Uses the AVM_INTEGRATION_LOCATION, AVM_INTEGRATION_VM_SKU, and
    AVM_INTEGRATION_MANAGEMENT_CIDR environment settings.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if ($MyInvocation.InvocationName -ne '.') {
    . (Join-Path $PSScriptRoot '..\..\tests\integration\setup.ps1')
    $Directory = Join-Path $PSScriptRoot '.generated'
    $PublicExists = Test-Path -LiteralPath (Join-Path $Directory 'public.json')
    $PrivateExists = Test-Path -LiteralPath (Join-Path $Directory 'private.json')
    $InputsPath = Join-Path $PSScriptRoot 'avm.generated.auto.tfvars.json'
    if ((Test-Path -LiteralPath $InputsPath) -and -not ($PublicExists -and $PrivateExists)) {
        throw 'Refusing to overwrite generated settings without their matching credential material.'
    }
    if ($PublicExists -or $PrivateExists) {
        if (-not ($PublicExists -and $PrivateExists)) {
            throw 'Incomplete example credentials. Preserve existing material until all Azure resources have been destroyed.'
        }
        Write-Host 'Reusing existing example credentials until Terraform cleanup completes.'
    }
    else {
        $Prefix = $env:AVM_INTEGRATION_MANAGEMENT_CIDR
        if ([string]::IsNullOrWhiteSpace($Prefix) -and $env:GITHUB_ACTIONS -ceq 'true' -and $env:GITHUB_JOB -ceq 'pr-check') {
            $Prefix = '192.0.2.1/32'
        }
        $Prefix = Get-IntegrationManagementSourcePrefix -ManagementSourcePrefix $Prefix
        $Location = if ([string]::IsNullOrWhiteSpace($env:AVM_INTEGRATION_LOCATION)) { 'westus3' } else { $env:AVM_INTEGRATION_LOCATION }
        $VmSku = if ([string]::IsNullOrWhiteSpace($env:AVM_INTEGRATION_VM_SKU)) { 'Standard_D2s_v5' } else { $env:AVM_INTEGRATION_VM_SKU }
        New-IntegrationMaterial -OutputDirectory $Directory -ManagementSourcePrefix $Prefix -Location $Location -VmSku $VmSku
        Write-Host 'Prepared real, owner-restricted example credentials. No Azure resources were created by the hook.'
    }

    $Inputs = [ordered]@{
        fixture_settings = Get-Content -LiteralPath (Join-Path $Directory 'public.json') -Raw | ConvertFrom-Json
        fixture_secrets  = Get-Content -LiteralPath (Join-Path $Directory 'private.json') -Raw | ConvertFrom-Json
    }
    $Json = $Inputs | ConvertTo-Json -Depth 10 -Compress
    if (Test-Path -LiteralPath $InputsPath) {
        $Existing = Get-Content -LiteralPath $InputsPath -Raw | ConvertFrom-Json | ConvertTo-Json -Depth 10 -Compress
        if ($Existing -cne $Json) {
            throw 'Generated settings do not match the retained credential material. Refusing to overwrite them.'
        }
    }
    else {
        New-Item -ItemType File -Path $InputsPath | Out-Null
        Protect-IntegrationMaterial -Path $InputsPath
        Set-Content -LiteralPath $InputsPath -Value $Json -Encoding utf8
    }
}
