param(
    [string]$Sizes = '512,2048,8192',
    [int]$Trials = 20,
    [int]$Repeat = 3,
    [int]$MinMs = 5,
    [int]$CpuCores = 1,
    [int]$MemoryLimitMB = 1024
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Data = Join-Path $Root 'data'
$Bin = Join-Path $Root 'bin'
$Limited = Join-Path $Root 'scripts\run_limited.ps1'
New-Item -ItemType Directory -Force -Path $Data | Out-Null

$GoExe = Join-Path $Bin 'ds50_go.exe'
$VExe = Join-Path $Bin 'ds50_v.exe'
if (!(Test-Path $GoExe) -or !(Test-Path $VExe)) {
    & (Join-Path $Root 'scripts\build.ps1')
}

$GoRaw = Join-Path $Data 'raw_go.csv'
$VRaw = Join-Path $Data 'raw_v.csv'
$Raw = Join-Path $Data 'raw_results.csv'
$GoErr = Join-Path $Data 'raw_go.err.txt'
$VErr = Join-Path $Data 'raw_v.err.txt'

function Invoke-Benchmark {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$StdoutPath,

        [Parameter(Mandatory = $true)]
        [string]$StderrPath
    )

    Remove-Item -Force -ErrorAction SilentlyContinue $StdoutPath, $StderrPath
    & $Limited `
        -FilePath $FilePath `
        -ChildArguments @('-trials', "$Trials", '-sizes', $Sizes, '-repeat', "$Repeat", '-min-ms', "$MinMs") `
        -WorkingDirectory $Root `
        -StdoutPath $StdoutPath `
        -StderrPath $StderrPath `
        -CpuCores $CpuCores `
        -Priority Idle `
        -MemoryLimitMB $MemoryLimitMB
    if ($LASTEXITCODE -ne 0) {
        if (Test-Path $StderrPath) {
            Get-Content $StderrPath | Write-Error
        }
        throw "$Name benchmark failed with exit code $LASTEXITCODE"
    }
}

function Test-RawCsv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $sizeCount = @($Sizes -split ',' | Where-Object { $_.Trim().Length -gt 0 }).Count
    $expectedLines = 1 + 50 * $sizeCount * $Trials
    $actualLines = (Get-Content $Path).Count
    if ($actualLines -ne $expectedLines) {
        throw "Unexpected line count for ${Path}: got $actualLines, expected $expectedLines"
    }
}

Write-Host "Running Go benchmark..."
Invoke-Benchmark -Name 'Go' -FilePath $GoExe -StdoutPath $GoRaw -StderrPath $GoErr
Test-RawCsv -Path $GoRaw

Write-Host "Running V benchmark..."
Invoke-Benchmark -Name 'V' -FilePath $VExe -StdoutPath $VRaw -StderrPath $VErr
Test-RawCsv -Path $VRaw

Get-Content $GoRaw | Set-Content -Encoding utf8 $Raw
Get-Content $VRaw | Select-Object -Skip 1 | Add-Content -Encoding utf8 $Raw

Write-Host "Wrote:"
Write-Host "  $GoRaw"
Write-Host "  $VRaw"
Write-Host "  $Raw"
