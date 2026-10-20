$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force target | Out-Null
$rtlFiles = @(Get-ChildItem -Path src -Filter '*.v' | Sort-Object Name | ForEach-Object { $_.FullName })
$names = @('register_bank', 'memory', 'memory_compat', 'memory_byte_enabled', 'load_store_unit', 'memory_arbiter', 'memory_4wide', 'memory_subsystem_4wide', 'writeback_unit', 'gabriel_integration')
foreach ($name in $names) {
    $tb = if ($name -eq 'memory') { 'memory_tb' } else { "${name}_tb" }
    Write-Host "=== $tb ==="
    & iverilog -g2012 -Wall -s $tb -o target/gabriel_output @rtlFiles "tests/${tb}.v"
    if ($LASTEXITCODE -ne 0) { throw "Compilacao falhou: $tb" }
    & vvp target/gabriel_output
    if ($LASTEXITCODE -ne 0) { throw "Teste falhou: $tb" }
}
Write-Host 'Testes Gabriel concluidos.'
