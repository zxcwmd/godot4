# Windows PowerShell 5.1+. No administrator rights or Python required.
# Reports only: never overwrites game files or changes antivirus/editor settings.
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$problems = New-Object 'System.Collections.Generic.List[string]'
Write-Host 'RIFT RUSH 0.3.1 - integrity and folder access check' -ForegroundColor Cyan
Write-Host ('Project: ' + $root)
Write-Host ''

try {
    $manifestPath = Join-Path $root 'integrity.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.format -ne 1 -or $manifest.algorithm -ne 'SHA-256' -or -not $manifest.files) {
        throw 'Unsupported or empty integrity manifest.'
    }
    $count = 0
    foreach ($entry in $manifest.files.PSObject.Properties) {
        $name = $entry.Name
        try {
            $file = [IO.Path]::GetFullPath((Join-Path $root $name))
            if (-not $file.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                throw 'Unsafe manifest path.'
            }
            if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
                $problems.Add('MISSING: ' + $name)
                continue
            }
            $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
            if ($actual -ine $entry.Value) {
                $problems.Add('CHANGED: ' + $name)
            }
            $count++
        } catch {
            $problems.Add('UNREADABLE: ' + $name + ' - ' + $_.Exception.Message)
        }
    }
    Write-Host ('Checked file hashes: ' + $count)
} catch {
    $problems.Add('MANIFEST: ' + $_.Exception.Message)
}

try {
    $project = Get-Content -LiteralPath (Join-Path $root 'project.godot') -Raw -Encoding UTF8
    if ($project -notmatch '(?m)^run/main_scene="res://scenes/main\.tscn"\r?$') {
        $problems.Add('MAIN SCENE: project.godot does not select res://scenes/main.tscn')
    }
    $scene = Get-Content -LiteralPath (Join-Path $root 'scenes/main.tscn') -Raw -Encoding UTF8
    if (-not $scene.TrimStart().StartsWith('[gd_scene ')) {
        $problems.Add('MAIN SCENE: invalid scene header')
    }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'scripts/game.gd') -PathType Leaf)) {
        $problems.Add('MAIN SCRIPT MISSING: scripts/game.gd')
    }
} catch {
    $problems.Add('MAIN SCENE / PROJECT UNREADABLE: ' + $_.Exception.Message)
}

$folders = @($root, (Join-Path $root 'scenes'))
$cache = Join-Path $root '.godot'
if (Test-Path -LiteralPath $cache) { $folders += $cache }
foreach ($folder in $folders) {
    $probe = Join-Path $folder ('.rift-write-test-' + [Guid]::NewGuid().ToString('N'))
    try {
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) { throw 'Folder is missing.' }
        [void][IO.Directory]::CreateDirectory($probe)
        $old = Join-Path $probe 'original'
        $new = Join-Path $probe 'replacement'
        [IO.File]::WriteAllText($old, 'before')
        [IO.File]::WriteAllText($new, 'after')
        [IO.File]::Replace($new, $old, $null)
        if ([IO.File]::ReadAllText($old) -ne 'after') { throw 'Could not read replaced contents.' }
        Write-Host ('WRITE / REPLACE OK: ' + $folder) -ForegroundColor Green
    } catch {
        $problems.Add('WRITE / REPLACE FAILED: ' + $folder + ' - ' + $_.Exception.Message)
    } finally {
        if (Test-Path -LiteralPath $probe) {
            try { Remove-Item -LiteralPath $probe -Recurse -Force } catch {
                $problems.Add('TEMP CLEANUP FAILED: ' + $probe)
            }
        }
    }
}

Write-Host ''
if ($problems.Count -gt 0) {
    foreach ($problem in $problems) { Write-Host $problem -ForegroundColor Red }
    Write-Host ''
    Write-Host 'FAIL. Extract the COMPLETE fresh ZIP into a NEW writable folder.'
    Write-Host 'Suggested location: %LOCALAPPDATA%\RiftRush-0.3.1'
    Write-Host 'CHANGED may mean an intentional edit, not necessarily corruption.'
    Write-Host 'Do not disable antivirus or Safe Save. See START_HERE.txt.'
    exit 1
}
Write-Host 'PASS: release files match; temporary files can be written and replaced.' -ForegroundColor Green
Write-Host 'This does not test antivirus permissions for the Godot executable itself.'
Write-Host 'It also does not parse GDScript. See README.md for engine smoke tests.'
Write-Host ''
Write-Host 'Import this exact file in the Godot Project Manager:'
Write-Host (Join-Path $root 'project.godot') -ForegroundColor Cyan
exit 0
