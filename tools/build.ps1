param(
    [ValidateSet('release','test','preview','diagnostic')][string]$Mode = 'release',
    [string]$Sdk = '',
    [string]$Java = '',
    [string]$Key = '',
    [switch]$Run
)
$ErrorActionPreference = 'Stop'
$rootTask = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $rootTask
if (!$Sdk) { $Sdk = (Get-Content -LiteralPath "$env:APPDATA/Garmin/ConnectIQ/current-sdk.cfg" -Raw).Trim() }
if (!$Java) {
    $javaTask = Get-Command java -ErrorAction SilentlyContinue
    if ($javaTask) { $Java = $javaTask.Source }
    else { $Java = "$env:LOCALAPPDATA/Programs/Android Studio/jbr/bin/java.exe" }
}
if (!(Test-Path -LiteralPath $Java)) { throw 'Java not found. Pass -Java /path/to/java.exe.' }
New-Item -ItemType Directory -Force -Path bin,.local | Out-Null
if (!$Key) { $Key = Join-Path $rootTask '.local/developer_key_pkcs8.der' }
if (!(Test-Path -LiteralPath $Key)) {
    # Generate a local development signing key; never replace an existing key.
    $opensslTask = Get-Command openssl -ErrorAction SilentlyContinue
    $opensslTaskPath = if ($opensslTask) { $opensslTask.Source } else { 'C:/Program Files/OpenSSL-Win64/bin/openssl.exe' }
    & $opensslTaskPath genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out .local/keygen.pem 2> .local/keygen.log
    if ($LASTEXITCODE -ne 0) { throw 'Signing key generation failed.' }
    & $opensslTaskPath pkcs8 -topk8 -inform PEM -outform DER -in .local/keygen.pem -out $Key -nocrypt
    if ($LASTEXITCODE -ne 0) { throw 'PKCS8 conversion failed.' }
}
$jungleTask = switch ($Mode) { 'test' {'test.jungle'} 'preview' {'preview.jungle'} 'diagnostic' {'diagnostic.jungle'} default {'monkey.jungle'} }
$outputTask = Join-Path $rootTask "bin/field-$Mode.prg"
$compilerTask = @('-Dfile.encoding=UTF-8','-cp',"$Sdk/bin/monkeybrains.jar",'com.garmin.monkeybrains.Monkeybrains','-f',$jungleTask,'-d','instinct3solar45mm','-o',$outputTask,'-y',$Key,'-O','2','-w','--build-stats','0')
if ($Mode -eq 'test') { $compilerTask += '-t' }
if ($Mode -eq 'release') { $compilerTask += '-r' }
& $Java @compilerTask
if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $LASTEXITCODE" }
if ($Run) {
    if (!(Get-Process simulator -ErrorAction SilentlyContinue)) { Start-Process -FilePath "$Sdk/bin/simulator.exe" -WindowStyle Hidden }
    $runnerTask = @('-Dfile.encoding=UTF-8','-cp',"$Sdk/bin/monkeybrains.jar",'com.garmin.monkeybrains.monkeydodeux.MonkeyDoDeux','-f',$outputTask,'-d','instinct3solar45mm','-s',"$Sdk/bin/shell.exe")
    if ($Mode -eq 'test') { $runnerTask += '-t' }
    if ($Mode -eq 'test') {
        # SDK 9.2 MonkeyDoDeux can return 1 even after PASSED (its result regexp
        # expects an extra space). Check the simulator's final test summary too.
        $testOutputTask = & $Java @runnerTask 2>&1
        $runnerExitTask = $LASTEXITCODE
        $testOutputTask | ForEach-Object { Write-Output $_ }
        $testSummaryTask = ($testOutputTask | Where-Object { "$_" -match '^(PASSED|FAILED) \(passed=' } | Select-Object -Last 1)
        if ("$testSummaryTask" -notmatch '^PASSED \(passed=\d+, failed=0, ?errors=0\)') { throw "Simulator tests did not pass (exit $runnerExitTask)." }
    } else {
        & $Java @runnerTask
        if ($LASTEXITCODE -ne 0) { throw "Simulator run failed: $LASTEXITCODE" }
    }
}
exit 0
