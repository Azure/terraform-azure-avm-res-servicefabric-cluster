#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Run the operational integration suite against an explicitly selected target.
.DESCRIPTION
    Checks the authenticated subscription without changing it, invokes the
    managed integration command, and removes local generated secrets in finally.
.PARAMETER SubscriptionId
    Approved Azure subscription. Must match ARM_SUBSCRIPTION_ID or Azure CLI.
.PARAMETER ManagementSourcePrefix
    Approved IPv4 CIDR allowed to reach the authenticated cluster gateways.
.PARAMETER Location
    Azure region. Defaults to westus3.
.PARAMETER VmSku
    Three instances of this Windows VM size are deployed per scenario.
.EXAMPLE
    ./Invoke-IntegrationTests.ps1 -SubscriptionId '<approved-guid>' -ManagementSourcePrefix '192.0.2.1/32'
.NOTES
    Requires Avm.Authoring and Azure authentication. Creates billable resources.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [guid]$SubscriptionId,

    [Parameter(Mandatory)]
    [string]$ManagementSourcePrefix,

    [string]$Location = 'westus3',

    [string]$VmSku = 'Standard_D2s_v5'
)

$ErrorActionPreference = 'Stop'

if ($MyInvocation.InvocationName -ne '.') {
    $Names = @('AVM_INTEGRATION_MANAGEMENT_CIDR', 'AVM_INTEGRATION_LOCATION', 'AVM_INTEGRATION_VM_SKU')
    $Previous = @{}
    foreach ($Name in $Names) { $Previous[$Name] = [Environment]::GetEnvironmentVariable($Name) }
    try {
        $Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $ActiveSubscription = $env:ARM_SUBSCRIPTION_ID
        $DotEnv = Join-Path $Root '.env'
        if (Test-Path -LiteralPath $DotEnv -PathType Leaf) {
            foreach ($Line in (Get-Content -LiteralPath $DotEnv)) {
                if ($Line -match '^\s*(?:export +)?ARM_SUBSCRIPTION_ID\s*=(.*)$') {
                    $ActiveSubscription = $Matches[1].Trim().Trim([char[]]@('"', "'"))
                }
            }
        }
        if ([string]::IsNullOrWhiteSpace($ActiveSubscription)) {
            $ActiveSubscription = & az account show --query id --output tsv
            if ($LASTEXITCODE -ne 0) { throw 'Azure CLI authentication is unavailable.' }
        }
        if ([guid]$ActiveSubscription -ne $SubscriptionId -or $SubscriptionId -eq [guid]::Empty) {
            throw 'The authenticated subscription does not match the explicitly approved target.'
        }
        $env:AVM_INTEGRATION_MANAGEMENT_CIDR = $ManagementSourcePrefix
        $env:AVM_INTEGRATION_LOCATION = $Location
        $env:AVM_INTEGRATION_VM_SKU = $VmSku
        Import-Module Avm.Authoring -ErrorAction Stop
        avm test integration -Path $Root
    }
    finally {
        try {
            . (Join-Path $PSScriptRoot 'setup.ps1')
            Remove-IntegrationMaterial -OutputDirectory (Join-Path $PSScriptRoot '.generated')
        }
        finally {
            foreach ($Name in $Names) { [Environment]::SetEnvironmentVariable($Name, $Previous[$Name]) }
        }
    }
}
