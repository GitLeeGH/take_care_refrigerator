# APK에서 실제 서명 정보 확인
param(
    [string]$ApkPath = "..\..\build\app\outputs\flutter-apk\app-release.apk"
)

Write-Host "APK 경로: $ApkPath"

if (-not (Test-Path $ApkPath)) {
    Write-Host "APK 파일을 찾을 수 없습니다: $ApkPath"
    exit 1
}

Write-Host "APK에서 서명 정보 추출 중..."

# APK의 서명 정보 확인
$apksignerPath = Get-ChildItem -Path "$env:ANDROID_HOME\build-tools" -Recurse -Filter "apksigner.bat" | Select-Object -First 1
if ($apksignerPath) {
    Write-Host "APK 서명 검증:"
    & $apksignerPath.FullName verify --verbose $ApkPath
} else {
    Write-Host "apksigner를 찾을 수 없습니다."
}

# keytool로 APK 내부 인증서 확인
Write-Host "`nAPK 내부 인증서 정보:"
& jarsigner -verify -verbose -certs $ApkPath