# Google Play Console에서 사용하는 실제 SHA-1 확인을 위한 안내

Write-Host "=== Google Play Console SHA-1 확인 방법 ==="
Write-Host ""
Write-Host "1. Google Play Console 접속: https://play.google.com/console"
Write-Host "2. 앱 선택 → '릴리스' → '설정' → '앱 서명'"
Write-Host "3. 'App signing key certificate' 섹션에서 SHA-1 지문 확인"
Write-Host ""
Write-Host "Google Play에서 앱을 자동으로 재서명하면 SHA-1이 바뀔 수 있습니다."
Write-Host "이 경우 Play Console에서 확인한 SHA-1로 새 카카오 해시키를 생성해야 합니다."
Write-Host ""
Write-Host "=== 카카오 해시키 변환 공식 ==="
Write-Host "1. Play Console에서 SHA-1 복사 (예: AB:CD:EF:12:34...)"
Write-Host "2. 콜론(:) 제거"
Write-Host "3. 16진수를 바이트로 변환 후 Base64 인코딩"
Write-Host ""

# Play Console SHA-1을 입력받아서 카카오 해시키로 변환하는 함수
function Convert-PlayConsoleSHA1ToKakaoHash {
    param([string]$PlayConsoleSHA1)
    
    if ([string]::IsNullOrEmpty($PlayConsoleSHA1)) {
        Write-Host "Play Console에서 SHA-1을 입력하세요 (형식: AB:CD:EF:12:34...)"
        return
    }
    
    # 콜론 제거
    $sha1Hex = $PlayConsoleSHA1.Replace(":", "").Replace(" ", "").ToUpper()
    Write-Host "정리된 SHA-1: $sha1Hex"
    
    try {
        # 16진수 문자열을 바이트 배열로 변환
        $sha1Bytes = [byte[]]@()
        for ($i = 0; $i -lt $sha1Hex.Length; $i += 2) {
            $hexPair = $sha1Hex.Substring($i, 2)
            $sha1Bytes += [Convert]::ToByte($hexPair, 16)
        }
        
        # Base64로 인코딩하여 카카오 해시 키 생성
        $kakaoHashKey = [Convert]::ToBase64String($sha1Bytes)
        Write-Host "Play Console용 카카오 해시 키: $kakaoHashKey"
        
    } catch {
        Write-Host "오류: SHA-1 형식이 올바르지 않습니다. 다시 확인해주세요."
    }
}

Write-Host "사용 예시:"
Write-Host "Convert-PlayConsoleSHA1ToKakaoHash '2F:8A:EB:23:CC:72:12:96:26:4F:B9:0C:21:BC:AE:EF:4B:07:AA:45'"