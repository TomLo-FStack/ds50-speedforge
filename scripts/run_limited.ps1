param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,

    [string[]]$ChildArguments = @(),

    [string]$WorkingDirectory = (Get-Location).Path,

    [string]$StdoutPath = '',

    [string]$StderrPath = '',

    [ValidateRange(1, 64)]
    [int]$CpuCores = 1,

    [ValidateSet('Idle', 'BelowNormal', 'Normal')]
    [string]$Priority = 'Idle',

    [ValidateRange(128, 65536)]
    [int]$MemoryLimitMB = 2048,

    [hashtable]$Environment = @{}
)

$ErrorActionPreference = 'Stop'

if (-not ('LimitedRunner.NativeMethods' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace LimitedRunner {
    public static class NativeMethods {
        public const int JobObjectExtendedLimitInformation = 9;
        public const uint JOB_OBJECT_LIMIT_WORKINGSET = 0x00000001;
        public const uint JOB_OBJECT_LIMIT_PROCESS_MEMORY = 0x00000100;
        public const uint JOB_OBJECT_LIMIT_JOB_MEMORY = 0x00000200;
        public const uint JOB_OBJECT_LIMIT_AFFINITY = 0x00000010;
        public const uint JOB_OBJECT_LIMIT_PRIORITY_CLASS = 0x00000020;

        public const uint IDLE_PRIORITY_CLASS = 0x00000040;
        public const uint BELOW_NORMAL_PRIORITY_CLASS = 0x00004000;
        public const uint NORMAL_PRIORITY_CLASS = 0x00000020;

        [StructLayout(LayoutKind.Sequential)]
        public struct JOBOBJECT_BASIC_LIMIT_INFORMATION {
            public long PerProcessUserTimeLimit;
            public long PerJobUserTimeLimit;
            public uint LimitFlags;
            public UIntPtr MinimumWorkingSetSize;
            public UIntPtr MaximumWorkingSetSize;
            public uint ActiveProcessLimit;
            public IntPtr Affinity;
            public uint PriorityClass;
            public uint SchedulingClass;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct IO_COUNTERS {
            public ulong ReadOperationCount;
            public ulong WriteOperationCount;
            public ulong OtherOperationCount;
            public ulong ReadTransferCount;
            public ulong WriteTransferCount;
            public ulong OtherTransferCount;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION {
            public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
            public IO_COUNTERS IoInfo;
            public UIntPtr ProcessMemoryLimit;
            public UIntPtr JobMemoryLimit;
            public UIntPtr PeakProcessMemoryUsed;
            public UIntPtr PeakJobMemoryUsed;
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern IntPtr CreateJobObject(IntPtr lpJobAttributes, string lpName);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetInformationJobObject(
            IntPtr hJob,
            int jobObjectInfoClass,
            IntPtr lpJobObjectInfo,
            uint cbJobObjectInfoLength);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool AssignProcessToJobObject(IntPtr hJob, IntPtr hProcess);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CloseHandle(IntPtr hObject);
    }
}
'@
}

function Get-AffinityMask {
    param([int]$RequestedCores)
    $cores = [Math]::Max(1, [Math]::Min($RequestedCores, [Environment]::ProcessorCount))
    [UInt64]$mask = 0
    for ($i = 0; $i -lt $cores; $i++) {
        $mask = $mask -bor ([UInt64]1 -shl $i)
    }
    return [IntPtr]([Int64]$mask)
}

function Get-PriorityConstant {
    param([string]$PriorityName)
    switch ($PriorityName) {
        'Idle' { return [LimitedRunner.NativeMethods]::IDLE_PRIORITY_CLASS }
        'BelowNormal' { return [LimitedRunner.NativeMethods]::BELOW_NORMAL_PRIORITY_CLASS }
        default { return [LimitedRunner.NativeMethods]::NORMAL_PRIORITY_CLASS }
    }
}

function New-LimitedJob {
    param(
        [int]$MemoryLimitMB,
        [IntPtr]$AffinityMask,
        [uint32]$PriorityClass
    )

    $job = [LimitedRunner.NativeMethods]::CreateJobObject([IntPtr]::Zero, $null)
    if ($job -eq [IntPtr]::Zero) {
        throw "CreateJobObject failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
    }

    $bytes = [UInt64]$MemoryLimitMB * 1024 * 1024
    $info = [LimitedRunner.NativeMethods+JOBOBJECT_EXTENDED_LIMIT_INFORMATION]::new()
    $info.BasicLimitInformation.LimitFlags =
        [LimitedRunner.NativeMethods]::JOB_OBJECT_LIMIT_PROCESS_MEMORY -bor
        [LimitedRunner.NativeMethods]::JOB_OBJECT_LIMIT_JOB_MEMORY -bor
        [LimitedRunner.NativeMethods]::JOB_OBJECT_LIMIT_AFFINITY -bor
        [LimitedRunner.NativeMethods]::JOB_OBJECT_LIMIT_PRIORITY_CLASS
    $info.BasicLimitInformation.Affinity = $AffinityMask
    $info.BasicLimitInformation.PriorityClass = $PriorityClass
    $info.ProcessMemoryLimit = [UIntPtr]$bytes
    $info.JobMemoryLimit = [UIntPtr]$bytes

    $size = [Runtime.InteropServices.Marshal]::SizeOf([type][LimitedRunner.NativeMethods+JOBOBJECT_EXTENDED_LIMIT_INFORMATION])
    $ptr = [Runtime.InteropServices.Marshal]::AllocHGlobal($size)
    try {
        [Runtime.InteropServices.Marshal]::StructureToPtr($info, $ptr, $false)
        $ok = [LimitedRunner.NativeMethods]::SetInformationJobObject(
            $job,
            [LimitedRunner.NativeMethods]::JobObjectExtendedLimitInformation,
            $ptr,
            [uint32]$size)
        if (-not $ok) {
            throw "SetInformationJobObject failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
        }
    }
    finally {
        [Runtime.InteropServices.Marshal]::FreeHGlobal($ptr)
    }

    return $job
}

function Resolve-ForChild {
    param([string]$Path)
    if ([IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    $cmd = Get-Command $Path -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

$affinity = Get-AffinityMask -RequestedCores $CpuCores
$priorityConstant = Get-PriorityConstant -PriorityName $Priority
$jobHandle = [IntPtr]::Zero
$process = $null
$stdoutTask = $null
$stderrTask = $null
$exitCode = 1

try {
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = Resolve-ForChild -Path $FilePath
    $psi.WorkingDirectory = (Resolve-Path -LiteralPath $WorkingDirectory).Path
    $psi.UseShellExecute = $false

    foreach ($arg in $ChildArguments) {
        [void]$psi.ArgumentList.Add($arg)
    }
    foreach ($key in $Environment.Keys) {
        $psi.Environment[$key] = [string]$Environment[$key]
    }

    if ($StdoutPath) {
        $stdoutFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($StdoutPath)
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $stdoutFull) | Out-Null
        $psi.RedirectStandardOutput = $true
    }
    if ($StderrPath) {
        $stderrFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($StderrPath)
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $stderrFull) | Out-Null
        $psi.RedirectStandardError = $true
    }

    $jobHandle = New-LimitedJob -MemoryLimitMB $MemoryLimitMB -AffinityMask $affinity -PriorityClass $priorityConstant
    $process = [Diagnostics.Process]::Start($psi)

    try {
        $process.PriorityClass = [Enum]::Parse([Diagnostics.ProcessPriorityClass], $Priority)
        $process.ProcessorAffinity = $affinity
    }
    catch {
        Write-Warning "Could not set direct process priority/affinity: $($_.Exception.Message)"
    }

    $assigned = [LimitedRunner.NativeMethods]::AssignProcessToJobObject($jobHandle, $process.Handle)
    if (-not $assigned) {
        throw "AssignProcessToJobObject failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
    }

    if ($psi.RedirectStandardOutput) {
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    }
    if ($psi.RedirectStandardError) {
        $stderrTask = $process.StandardError.ReadToEndAsync()
    }

    $process.WaitForExit()
    $exitCode = $process.ExitCode

    if ($stdoutTask) {
        [IO.File]::WriteAllText($stdoutFull, $stdoutTask.GetAwaiter().GetResult())
    }
    if ($stderrTask) {
        [IO.File]::WriteAllText($stderrFull, $stderrTask.GetAwaiter().GetResult())
    }
}
finally {
    if ($process) {
        $process.Dispose()
    }
    if ($jobHandle -ne [IntPtr]::Zero) {
        [void][LimitedRunner.NativeMethods]::CloseHandle($jobHandle)
    }
}

exit $exitCode
