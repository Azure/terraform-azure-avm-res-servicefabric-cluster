#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Prepare short-lived credentials for the operational integration fixtures.
.DESCRIPTION
    Creates an owner-restricted, git-ignored directory containing a 45-day
    self-signed certificate package and a random VM administrator password.
    Does not contact Azure. Avm.Authoring runs this hook before integration tests.
.PARAMETER Cleanup
    Remove only the two generated fixture files and their empty directory.
.EXAMPLE
    $env:AVM_INTEGRATION_MANAGEMENT_CIDR = '192.0.2.1/32'
    ./setup.ps1
.NOTES
    AVM_INTEGRATION_LOCATION defaults to westus3.
    AVM_INTEGRATION_VM_SKU defaults to Standard_D2s_v5.
#>

[CmdletBinding()]
param(
    [switch]$Cleanup
)

$ErrorActionPreference = 'Stop'

function Remove-IntegrationMaterial {
    <#
    .SYNOPSIS
        Remove the known generated files without deleting unrelated content.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputDirectory
    )

    foreach ($Name in @('private.json', 'public.json')) {
        $Path = Join-Path $OutputDirectory $Name
        if (Test-Path -LiteralPath $Path) {
            Remove-Item -LiteralPath $Path -Force
        }
    }
    if ((Test-Path -LiteralPath $OutputDirectory) -and @(Get-ChildItem -LiteralPath $OutputDirectory -Force).Count -eq 0) {
        Remove-Item -LiteralPath $OutputDirectory
    }
}

function New-IntegrationMaterial {
    <#
    .SYNOPSIS
        Generate an exportable test certificate and secret-free public metadata.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputDirectory,

        [Parameter(Mandatory)]
        [string]$ManagementSourcePrefix,

        [string]$Location = 'westus3',

        [string]$VmSku = 'Standard_D2s_v5'
    )

    $Address = $null
    $Parts = $ManagementSourcePrefix.Split('/')
    if ($Parts.Count -ne 2 -or
        -not [System.Net.IPAddress]::TryParse($Parts[0], [ref]$Address) -or
        $Address.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork -or
        $Parts[1] -notmatch '^(?:[1-9]|[12][0-9]|3[0-2])$') {
        throw 'AVM_INTEGRATION_MANAGEMENT_CIDR must be a restricted IPv4 CIDR, not an unrestricted /0.'
    }
    if ($Location -notmatch '^[a-z0-9]+$' -or [string]::IsNullOrWhiteSpace($VmSku)) {
        throw 'Supply a canonical Azure region name and a non-empty VM SKU.'
    }

    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    if ($IsWindows) {
        $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
        $Directory = [System.IO.DirectoryInfo]::new($OutputDirectory)
        # Restrict only the DACL without requesting audit or ownership privileges.
        $Acl = [System.IO.FileSystemAclExtensions]::GetAccessControl(
            $Directory, [System.Security.AccessControl.AccessControlSections]::Access
        )
        $Acl.SetAccessRuleProtection($true, $false)
        foreach ($ExistingRule in $Acl.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier])) {
            $Acl.RemoveAccessRuleSpecific($ExistingRule)
        }
        $Rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            $Identity, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
        )
        $Acl.AddAccessRule($Rule)
        [System.IO.FileSystemAclExtensions]::SetAccessControl($Directory, $Acl)
    }
    else {
        [System.IO.File]::SetUnixFileMode($OutputDirectory, [System.IO.UnixFileMode]::UserRead -bor [System.IO.UnixFileMode]::UserWrite -bor [System.IO.UnixFileMode]::UserExecute)
    }

    $Prefix = 'sfit' + [guid]::NewGuid().ToString('N').Substring(0, 10)
    $CommonName = "$Prefix.servicefabric.test"
    $Rsa = [System.Security.Cryptography.RSA]::Create(2048)
    $Certificate = $null
    try {
        $Request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
            "CN=$CommonName", $Rsa, [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
        )
        $Request.CertificateExtensions.Add(
            [System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($false, $false, 0, $true)
        )
        $Request.CertificateExtensions.Add(
            [System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new(
                [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature -bor
                [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyEncipherment, $true
            )
        )
        $Usages = [System.Security.Cryptography.OidCollection]::new()
        $Usages.Add([System.Security.Cryptography.Oid]::new('1.3.6.1.5.5.7.3.1')) | Out-Null
        $Usages.Add([System.Security.Cryptography.Oid]::new('1.3.6.1.5.5.7.3.2')) | Out-Null
        $Request.CertificateExtensions.Add(
            [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($Usages, $true)
        )
        $San = [System.Security.Cryptography.X509Certificates.SubjectAlternativeNameBuilder]::new()
        $San.AddDnsName($CommonName)
        $San.AddDnsName("$Prefix-tp.$Location.cloudapp.azure.com")
        $San.AddDnsName("$Prefix-cn.$Location.cloudapp.azure.com")
        $Request.CertificateExtensions.Add($San.Build())
        $Certificate = $Request.CreateSelfSigned([DateTimeOffset]::UtcNow.AddMinutes(-5), [DateTimeOffset]::UtcNow.AddDays(45))
        $PfxPassword = [Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
        $Pfx = $Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $PfxPassword)
        $Package = @{
            data     = [Convert]::ToBase64String($Pfx)
            dataType = 'pfx'
            password = $PfxPassword
        } | ConvertTo-Json -Compress
        $Private = @{
            admin_password     = 'Avm!7a' + [Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(36))
            certificate_secret = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Package))
        }
        $Public = @{
            name_prefix              = $Prefix
            location                 = $Location
            vm_sku                   = $VmSku
            management_source_prefix = $ManagementSourcePrefix
            certificate_common_name  = $CommonName
            certificate_thumbprint   = $Certificate.Thumbprint
        }
        $PrivatePath = Join-Path $OutputDirectory 'private.json'
        $Private | ConvertTo-Json | Set-Content -LiteralPath $PrivatePath -Encoding utf8
        if (-not $IsWindows) {
            [System.IO.File]::SetUnixFileMode($PrivatePath, [System.IO.UnixFileMode]::UserRead -bor [System.IO.UnixFileMode]::UserWrite)
        }
        $Public | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputDirectory 'public.json') -Encoding utf8
    }
    finally {
        if ($null -ne $Certificate) { $Certificate.Dispose() }
        $Rsa.Dispose()
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $OutputDirectory = Join-Path $PSScriptRoot '.generated'
        if ($Cleanup) {
            Remove-IntegrationMaterial -OutputDirectory $OutputDirectory
        }
        else {
            if ([string]::IsNullOrWhiteSpace($env:AVM_INTEGRATION_MANAGEMENT_CIDR)) {
                throw 'Set AVM_INTEGRATION_MANAGEMENT_CIDR to an approved runner IPv4 CIDR before provisioning integration resources.'
            }
            $Location = if ([string]::IsNullOrWhiteSpace($env:AVM_INTEGRATION_LOCATION)) { 'westus3' } else { $env:AVM_INTEGRATION_LOCATION }
            $VmSku = if ([string]::IsNullOrWhiteSpace($env:AVM_INTEGRATION_VM_SKU)) { 'Standard_D2s_v5' } else { $env:AVM_INTEGRATION_VM_SKU }
            New-IntegrationMaterial -OutputDirectory $OutputDirectory `
                -ManagementSourcePrefix $env:AVM_INTEGRATION_MANAGEMENT_CIDR `
                -Location $Location `
                -VmSku $VmSku
            Write-Host 'Prepared owner-restricted, 45-day test credentials. No Azure resources were created.'
        }
    }
    catch {
        Write-Error -ErrorAction Continue "$($_.Exception.Message)`n$($_.ScriptStackTrace)"
        Remove-IntegrationMaterial -OutputDirectory (Join-Path $PSScriptRoot '.generated')
        exit 1
    }
}
