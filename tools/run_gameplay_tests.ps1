param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [switch]$Screenshots,
    [switch]$EngineVerbose,
    [ValidateSet('gameplay', 'chapter', 'chapter2', 'chapter3', 'recovery', 'desk', 'browser', 'events', 'arcade', 'desk_assets', 'studio', 'career')][string]$Suite = 'gameplay',
    [ValidateSet('prevent', 'recover', 'resume')][string]$Profile = 'prevent'
)

$ErrorActionPreference = 'Stop'
$workspacePath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$enginePath = (Resolve-Path -LiteralPath $Godot).Path
$qaName = 'codien-gameplay-qa-' + [guid]::NewGuid().ToString('N')
$qaPath = Join-Path ([IO.Path]::GetTempPath()) $qaName
$outputPath = Join-Path $workspacePath 'build\gameplay-qa'
if ($Suite -eq 'chapter') { $outputPath = Join-Path $workspacePath ('build\chapter-qa\' + $Profile) }
if ($Suite -eq 'chapter2') { $outputPath = Join-Path $workspacePath ('build\chapter2-qa\' + $Profile) }
if ($Suite -eq 'chapter3') { $outputPath = Join-Path $workspacePath ('build\chapter3-qa\' + $Profile) }
if ($Suite -eq 'recovery') { $outputPath = Join-Path $workspacePath 'build\recovery-qa' }
if ($Suite -eq 'desk') { $outputPath = Join-Path $workspacePath 'build\desk-qa' }
if ($Suite -eq 'events') { $outputPath = Join-Path $workspacePath 'build\events-qa' }
if ($Suite -eq 'desk_assets') { $outputPath = Join-Path $workspacePath 'build\desk-assets-qa' }
if ($Suite -eq 'studio') { $outputPath = Join-Path $workspacePath 'build\studio-qa' }
if ($Suite -eq 'career') { $outputPath = Join-Path $workspacePath 'build\career-qa' }
if ($Suite -eq 'browser') { $outputPath = Join-Path $workspacePath 'build\browser-qa' }
if ($Suite -eq 'arcade') { $outputPath = Join-Path $workspacePath 'build\arcade-qa' }
New-Item -ItemType Directory -Path $qaPath, $outputPath -Force | Out-Null
$buildIgnore = Join-Path $workspacePath 'build\.gdignore'
if (-not (Test-Path -LiteralPath $buildIgnore)) { [IO.File]::WriteAllText($buildIgnore, '') }

foreach ($entry in @('scripts', 'scenes', 'shaders', 'content', 'audio', 'tests', 'icon.svg')) {
    Copy-Item -LiteralPath (Join-Path $workspacePath $entry) -Destination $qaPath -Recurse
}
$projectText = [IO.File]::ReadAllText((Join-Path $workspacePath 'project.godot'))
$projectText = $projectText.Replace('config/name="Developer Life Simulator"', ('config/name="' + $qaName + '"'))
[IO.File]::WriteAllText((Join-Path $qaPath 'project.godot'), $projectText, [Text.UTF8Encoding]::new($false))
$previousOutput = $env:CODIEN_QA_OUTPUT
$env:CODIEN_QA_OUTPUT = $outputPath
try {
    $importOutput = & $enginePath --headless --path $qaPath --editor --quit 2>&1
    $importExitCode = $LASTEXITCODE
    $importOutput | Set-Content -LiteralPath (Join-Path $outputPath 'import.log')
    if ($importExitCode -ne 0 -or ($importOutput -match 'SCRIPT ERROR:|ERROR:')) { throw 'Godot import failed. See build/gameplay-qa/import.log.' }
    Write-Host 'Godot import checked.'
    $preflight = & $enginePath --headless --path $qaPath res://tests/preflight.tscn --max-fps 120 --quit-after 600 2>&1
    $preflight | Set-Content -LiteralPath (Join-Path $outputPath 'preflight.log')
    if ($LASTEXITCODE -ne 0 -or -not ($preflight -match 'QA_PREFLIGHT_OK') -or ($preflight -match 'SCRIPT ERROR:|ERROR:')) { throw ('QA compilation failed. See ' + (Join-Path $outputPath 'preflight.log')) }
    $scenePath = 'res://tests/' + $Suite + '_test.tscn'
    $resultTag = $Suite.ToUpper() + '_QA'
    $stages = if ($Suite -eq 'chapter2') { @('before', 'after', 'finale') } elseif ($Suite -eq 'chapter3') { @('before', 'after') } elseif ($Suite -eq 'recovery') { @('before', 'after') } elseif ($Suite -eq 'chapter' -and $Profile -eq 'resume') { @('before', 'review', 'after') } else { @('') }
    foreach ($stage in $stages) {
        $runArgs = @('--path', $qaPath, $scenePath, '--max-fps', '120', '--quit-after', '72000')
        if ($EngineVerbose) { $runArgs += '--verbose' }
        $userArgs = @()
        if ($Screenshots) { $userArgs += '--screenshots' } else { $runArgs = @('--headless') + $runArgs }
        if ($Suite -in @('chapter', 'chapter2', 'chapter3')) { $userArgs += @('--profile', $Profile) }
        if ($stage) { $userArgs += @('--stage', $stage) }
        if ($userArgs.Count -gt 0) { $runArgs += @('--') + $userArgs }
        $logName = if ($stage) { 'tests_' + $stage + '.log' } else { 'tests.log' }
        $logPath = Join-Path $outputPath $logName
        $testOutput = & $enginePath @runArgs 2>&1 | Tee-Object -FilePath $logPath
        $testExitCode = $LASTEXITCODE
        $testOutput | Write-Output
        if ($testExitCode -ne 0 -or -not ($testOutput -match ($resultTag + ': \d+ checks, 0 failures')) -or ($testOutput -match 'SCRIPT ERROR:|ERROR:')) {
            throw ('Gameplay checks failed. See ' + $logPath)
        }
    }
    Write-Host ('QA output: ' + $outputPath)
} finally {
    $env:CODIEN_QA_OUTPUT = $previousOutput
    # Keep the isolated project and save for debugging; no player files are modified or deleted.
    Write-Host ('Isolated QA project: ' + $qaPath)
}
