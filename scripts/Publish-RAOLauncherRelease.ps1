[CmdletBinding(SupportsShouldProcess)]
param(
    # RAO-Launcher.exe compilado (go build -ldflags="-H=windowsgui").
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$LauncherPath,

    # Debe coincidir con launcher.Version del código del launcher.
    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+$')]
    [string]$Version,

    [string]$Repository = 'Sazked/RAO-AutoUpdater',

    [switch]$Publish
)

# Publica una versión nueva del launcher: crea el release launcher-v<versión>
# con RAO-Launcher.exe y actualiza launcher-manifest.json. Los launchers
# instalados lo descargan, lo verifican (SHA-256) y se reemplazan solos.
# No toca manifest.json (el del cliente del juego).

$ErrorActionPreference = 'Stop'
$assetName = 'RAO-Launcher.exe'

function Require-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found."
    }
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$launcher = Get-Item -LiteralPath $LauncherPath
if ($launcher.Extension -ne '.exe') {
    throw 'LauncherPath must point to the launcher .exe.'
}

# The exe must report the version being published; otherwise installed
# launchers would keep finding a "new" version.
$reported = (& $launcher.FullName --version | Out-String).Trim()
if ($reported -ne $Version) {
    throw "The exe reports version '$reported', not '$Version'. Bump launcher.Version and rebuild."
}

$tag = "launcher-v$Version"
$sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $launcher.FullName).Hash.ToLowerInvariant()
$downloadUrl = "https://github.com/$Repository/releases/download/$tag/$assetName"
$manifest = [ordered]@{
    version = $Version
    download_url = $downloadUrl
    sha256 = $sha256
    executable = $assetName
}
$manifestJson = $manifest | ConvertTo-Json

if (-not $Publish) {
    Write-Host 'Launcher publication preview (no GitHub changes were made):'
    Write-Output $manifestJson
    Write-Host "Run again with -Publish to create release $tag and publish launcher-manifest.json."
    exit 0
}

Require-Command gh
Require-Command git

# gh y git escriben avisos en stderr; cada llamada se valida con $LASTEXITCODE.
$ErrorActionPreference = 'Continue'

$staging = Join-Path ([System.IO.Path]::GetTempPath()) ("rao-launcher-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $staging | Out-Null
Push-Location $repositoryRoot
try {
    $existingRelease = gh release view $tag --repo $Repository 2>$null
    if ($LASTEXITCODE -eq 0 -or $null -ne $existingRelease) {
        throw "Release $tag already exists. Refusing to overwrite it."
    }

    # The asset must be named RAO-Launcher.exe whatever the local file is called.
    $asset = Join-Path $staging $assetName
    Copy-Item -LiteralPath $launcher.FullName -Destination $asset

    if ($PSCmdlet.ShouldProcess("GitHub release $tag", 'Create release and upload the launcher')) {
        # --latest=false keeps the client release as the repository's latest.
        gh release create $tag $asset --repo $Repository --title "RAO Launcher $Version" --notes "Launcher $Version (se actualiza solo en las PCs de los jugadores)." --latest=false
        if ($LASTEXITCODE -ne 0) {
            throw "GitHub release creation failed for $tag."
        }
    }

    $manifestPath = Join-Path $repositoryRoot 'launcher-manifest.json'
    if ($PSCmdlet.ShouldProcess($manifestPath, 'Write launcher manifest')) {
        [System.IO.File]::WriteAllText($manifestPath, "$manifestJson`n", [System.Text.UTF8Encoding]::new($false))
        git add -- launcher-manifest.json
        git commit -m "release: publicar launcher $Version" -m "Se publicó el manifiesto de autoactualización del launcher $Version."
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not commit launcher-manifest.json.'
        }
        git push origin main
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not push launcher-manifest.json to main.'
        }
    }
}
finally {
    Pop-Location
    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Published launcher $Version. Manifest: https://raw.githubusercontent.com/$Repository/main/launcher-manifest.json"
