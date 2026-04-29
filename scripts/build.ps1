$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Go = Join-Path $Root 'tools\go\bin\go.exe'
$V = Join-Path $Root 'tools\v\v.exe'
$Bin = Join-Path $Root 'bin'
$Limited = Join-Path $Root 'scripts\run_limited.ps1'
New-Item -ItemType Directory -Force -Path $Bin | Out-Null

$env:PATH = "E:\mingw64\bin;$env:PATH"
$env:GOMAXPROCS = '1'
$env:GOMEMLIMIT = '768MiB'

function Invoke-Limited {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$ChildArguments = @(),

        [int]$MemoryLimitMB = 2048
    )

    & $Limited `
        -FilePath $FilePath `
        -ChildArguments $ChildArguments `
        -WorkingDirectory $Root `
        -CpuCores 1 `
        -Priority Idle `
        -MemoryLimitMB $MemoryLimitMB
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($ChildArguments -join ' ')"
    }
}

Invoke-Limited -FilePath $Go -ChildArguments @('version') -MemoryLimitMB 512
Invoke-Limited -FilePath $V -ChildArguments @('version') -MemoryLimitMB 512

Push-Location $Root
Invoke-Limited -FilePath $Go -ChildArguments @(
    'build',
    '-p', '1',
    '-o', (Join-Path $Bin 'ds50_go.exe'),
    './src/go'
) -MemoryLimitMB 2048
Pop-Location
Invoke-Limited -FilePath $V -ChildArguments @(
    '-cc', 'gcc',
    '-prod',
    '-o', (Join-Path $Bin 'ds50_v.exe'),
    (Join-Path $Root 'src\v\ds50.v')
) -MemoryLimitMB 2048

Write-Host "Built:"
Write-Host "  $(Join-Path $Bin 'ds50_go.exe')"
Write-Host "  $(Join-Path $Bin 'ds50_v.exe')"
