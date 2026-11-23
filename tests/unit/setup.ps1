#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Prepare the Terraform module directory for mocked unit tests.
.DESCRIPTION
    Terraform copies an already installed remote package into a test-run module with
    a non-recursive mkdir, so the parent of the test-run module key must exist before
    terraform init. The example unit test runs the example, whose cluster module uses
    the AVM interfaces utility module that the root module also installs.
.EXAMPLE
    ./setup.ps1
.NOTES
    Avm.Authoring runs this hook before terraform init for avm test unit.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Force -Path (Join-Path $PSScriptRoot '../../.terraform/modules/test.tests/unit') | Out-Null
