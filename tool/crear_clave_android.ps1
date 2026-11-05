# Crea la clave de firma de Android (upload key) y android/key.properties.
#
# Ejecútalo tú, en una terminal de PowerShell, desde la carpeta del proyecto:
#   powershell -ExecutionPolicy Bypass -File tool\crear_clave_android.ps1
#
# Te pide las contraseñas (no se muestran ni se guardan en ningún otro lugar).
# Guarda una copia de seguridad del archivo .jks y de sus contraseñas: si los
# pierdes, no podrás publicar actualizaciones con la misma firma.

$ErrorActionPreference = 'Stop'

$keytool = Join-Path $env:ProgramFiles 'Android\Android Studio\jbr\bin\keytool.exe'
if (-not (Test-Path $keytool)) {
    $cmd = Get-Command keytool -ErrorAction SilentlyContinue
    if ($null -eq $cmd) { throw 'No se encontró keytool. Instala Android Studio o un JDK.' }
    $keytool = $cmd.Source
}

$dir = Read-Host 'Carpeta donde guardar la clave (fuera del proyecto, p. ej. C:\claves)'
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
$store = Join-Path $dir 'mi_voz_upload.jks'
if (Test-Path $store) { throw "Ya existe $store. No se sobrescribe." }
$alias = 'upload'

# keytool pide la contraseña y los datos del certificado (nombre, organización…).
& $keytool -genkeypair -v -keystore $store -keyalg RSA -keysize 2048 -validity 10000 -alias $alias
if ($LASTEXITCODE -ne 0) { throw 'keytool no creó la clave.' }

$secure = Read-Host 'Vuelve a escribir la contraseña del almacén (para key.properties)' -AsSecureString
$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))

$props = Join-Path $PSScriptRoot '..\android\key.properties'
@(
    "storePassword=$plain",
    "keyPassword=$plain",
    "keyAlias=$alias",
    "storeFile=$($store -replace '\\', '\\')"
) | Set-Content -Path $props -Encoding ascii

Write-Host ''
Write-Host "Listo. Clave: $store"
Write-Host 'android/key.properties creado (está en .gitignore: no lo compartas).'
Write-Host 'Ahora: flutter build appbundle --release   y/o   flutter build apk --release --split-per-abi'
