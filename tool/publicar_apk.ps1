# Prepara los archivos de una versión de Mi Voz para descargar.
#
#   powershell -ExecutionPolicy Bypass -File tool\publicar_apk.ps1
#
# 1. Compila el APK universal y los APK por arquitectura.
# 2. Deja en build\release:
#      mi-voz.apk        (cualquier Android, ~87 MB)
#      mi-voz-arm64.apk  (teléfonos actuales, ~35 MB)
#      SHA256SUMS.txt
# 3. Recuerda cómo publicarlos en GitHub.
#
# La página web/instalar.html enlaza a
#   https://github.com/8Muffin09/Mi-Voz/releases/latest/download/<archivo>
# por lo que cada versión debe subir los archivos CON ESTOS NOMBRES.
#
# Sube antes "version:" en pubspec.yaml (p. ej. 1.0.2+3): Android no instala
# una versión con un número menor encima de una mayor.

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

$version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
Write-Host "Versión: $version"

flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw 'Falló la compilación del APK universal.' }
flutter build apk --release --split-per-abi
if ($LASTEXITCODE -ne 0) { throw 'Falló la compilación por arquitectura.' }

$out = 'build\release'
New-Item -ItemType Directory -Force $out | Out-Null
Copy-Item build\app\outputs\flutter-apk\app-release.apk "$out\mi-voz.apk" -Force
Copy-Item build\app\outputs\flutter-apk\app-arm64-v8a-release.apk "$out\mi-voz-arm64.apk" -Force

$sums = Get-ChildItem "$out\*.apk" | ForEach-Object {
  '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(), $_.Name
}
$sums | Out-File -Encoding ascii "$out\SHA256SUMS.txt"
$sums

$tag = 'v' + ($version -split '\+')[0]
Write-Host ""
Write-Host "Listo. Publica la versión en GitHub:"
Write-Host "  1. https://github.com/8Muffin09/Mi-Voz/releases/new"
Write-Host "  2. Etiqueta: $tag  (sobre la rama main)"
Write-Host "  3. Adjunta: $out\mi-voz-arm64.apk, $out\mi-voz.apk y $out\SHA256SUMS.txt"
Write-Host "  4. Publica (no la marques como borrador ni como prerelease)."
