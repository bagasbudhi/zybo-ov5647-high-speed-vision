$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$bsp = Join-Path $root 'build\hsi_eth_bsp\ps7_cortexa9_0'
$gcc = 'C:\AMDDesignTools\2025.2\Vitis\gnu\aarch32\nt\gcc-arm-none-eabi\bin\arm-none-eabi-gcc.exe'
$linker = Join-Path $root 'build\ethernet_stream.ld'
$elf = Join-Path $root 'build\ethernet_stream.elf'
$map = Join-Path $root 'build\ethernet_stream.map'
foreach ($required in @($gcc, $linker, (Join-Path $bsp 'lib\libxil.a'), (Join-Path $bsp 'lib\liblwip4.a'))) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing build dependency: $required" }
}
Add-Type -Namespace Win32 -Name ShortPath -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern uint GetShortPathName(string longPath, System.Text.StringBuilder shortPath, uint bufferLength);
'@
function ConvertTo-ShortPath([string] $path) {
    $buffer = [System.Text.StringBuilder]::new(4096)
    if ([Win32.ShortPath]::GetShortPathName($path, $buffer, 4096) -eq 0) { throw "GetShortPathName failed: $path" }
    return $buffer.ToString()
}
$shortRoot = ConvertTo-ShortPath $root
$shortBsp = ConvertTo-ShortPath $bsp
Write-Host "Build path: $shortRoot"
$arguments = @(
    '-mcpu=cortex-a9', '-mfpu=vfpv3', '-mfloat-abi=hard',
    '-O2', '-g', '-Wall', '-Wextra', '-fno-tree-loop-distribute-patterns',
    '-nostartfiles', '-specs=nosys.specs',
    '-I', (Join-Path $shortBsp 'include'),
    (Join-Path $shortRoot 'firmware\ethernet_stream.c'),
    (Join-Path $shortRoot 'firmware\zcam_protocol.c'),
    ('-Wl,-T,' + (Join-Path $shortRoot 'build\ethernet_stream.ld')),
    ('-Wl,-Map,' + (Join-Path $shortRoot 'build\ethernet_stream.map')),
    '-L', (Join-Path $shortBsp 'lib'),
    '-Wl,--start-group', '-llwip4', '-lxil', '-lc', '-lgcc', '-Wl,--end-group',
    '-o', (Join-Path $shortRoot 'build\ethernet_stream.elf')
)
& $gcc @arguments
if ($LASTEXITCODE -ne 0) { throw "ARM GCC failed with exit code $LASTEXITCODE" }
Write-Host "Built $elf"
