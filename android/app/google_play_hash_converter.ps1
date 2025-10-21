# Google Play Console SHA-1을 카카오 키 해시로 변환
$sha1 = 'D4:9F:A1:B3:20:E6:6B:2A:5D:2E:8A:C1:F8:AC:57:6B:B9:7F:BF:CB'

Write-Host "=== Google Play Console SHA-1 to Kakao Hash Converter ===" -ForegroundColor Green
Write-Host "Original SHA-1: $sha1" -ForegroundColor Yellow

# SHA-1에서 콜론 제거
$cleanSha1 = $sha1.Replace(':', '')
Write-Host "Clean SHA-1: $cleanSha1" -ForegroundColor Yellow

try {
    # Hex string을 바이트 배열로 변환 (.NET Framework 호환)
    $bytes = New-Object byte[] ($cleanSha1.Length / 2)
    for ($i = 0; $i -lt $cleanSha1.Length; $i += 2) {
        $bytes[$i / 2] = [Convert]::ToByte($cleanSha1.Substring($i, 2), 16)
    }
    Write-Host "Bytes converted successfully" -ForegroundColor Green
    
    # Base64로 인코딩
    $base64 = [System.Convert]::ToBase64String($bytes)
    
    Write-Host "" 
    Write-Host "=== RESULT ===" -ForegroundColor Green
    Write-Host "Kakao Key Hash: $base64" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "이 키 해시를 카카오 개발자 콘솔에 추가하세요!" -ForegroundColor Yellow
    
} catch {
    Write-Host "Error converting: $_" -ForegroundColor Red
}