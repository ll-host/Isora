[CmdletBinding()]
param(
    [string]$QemuDirectory = 'C:\Program Files\qemu',
    [string]$DiskPath = 'C:\Users\ll-host\Documents\Virtual Machines\EndeavourOS-10G.qcow2',
    [ValidateRange(1024, 262144)]
    [int]$MemoryMiB = 4096,
    [ValidateRange(1, 256)]
    [int]$CpuCount = 4,
    [switch]$FullScreen,
    [switch]$InspectOnly
)

$ErrorActionPreference = 'Stop'
$qemu = Join-Path $QemuDirectory 'qemu-system-x86_64.exe'
$qemuImg = Join-Path $QemuDirectory 'qemu-img.exe'

foreach ($requiredFile in @($qemu, $qemuImg, $DiskPath)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Required file was not found: $requiredFile"
    }
}

$resolvedDisk = (Resolve-Path -LiteralPath $DiskPath).Path
$version = & $qemu --version | Select-Object -First 1
$diskCheck = & $qemuImg check $resolvedDisk 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "qemu-img check failed: $($diskCheck -join [Environment]::NewLine)"
}
$diskInfo = & $qemuImg info --output=json $resolvedDisk | ConvertFrom-Json

[pscustomobject]@{
    Qemu = $version
    Disk = $resolvedDisk
    Format = $diskInfo.format
    VirtualSizeGiB = [math]::Round($diskInfo.'virtual-size' / 1GB, 2)
    ActualSizeGiB = [math]::Round($diskInfo.'actual-size' / 1GB, 2)
    Dirty = [bool]$diskInfo.'dirty-flag'
    Check = ($diskCheck -join ' ').Trim()
}

if ($InspectOnly) {
    return
}

$qemuArguments = [System.Collections.Generic.List[string]]::new()
@(
    '-accel', 'whpx',
    '-m', $MemoryMiB.ToString(),
    '-smp', $CpuCount.ToString(),
    '-device', 'virtio-mouse-pci',
    '-device', 'VGA,vgamem_mb=256,xres=1920,yres=1080',
    '-display', 'sdl,gl=off',
    '-drive', "file=$resolvedDisk,if=virtio,format=qcow2",
    '-boot', 'order=c',
    '-name', 'Isora — EndeavourOS smoke'
) | ForEach-Object { $qemuArguments.Add([string]$_) }
if ($FullScreen) {
    $qemuArguments.Add('-full-screen')
}

$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $qemu
$startInfo.UseShellExecute = $false
foreach ($argument in $qemuArguments) {
    $startInfo.ArgumentList.Add($argument)
}
$process = [System.Diagnostics.Process]::Start($startInfo)
if ($null -eq $process) {
    throw 'QEMU process did not start'
}

[pscustomobject]@{
    Started = $true
    ProcessId = $process.Id
    Profile = "WHPX, $MemoryMiB MiB, $CpuCount vCPU, VGA 256 MiB, SDL gl=off, USB tablet"
}
