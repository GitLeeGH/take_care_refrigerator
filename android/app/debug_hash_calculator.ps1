# 디버그 키스토어에서 SHA1 지문 추출 후 카카오 해시 키로 변환

$debugKeystorePath = "$env:USERPROFILE\.android\debug.keystore"

if (-not (Test-Path $debugKeystorePath)) {
    Write-Host "디버그 키스토어를 찾을 수 없습니다: $debugKeystorePath"
    exit 1
}

# keytool을 사용하여 SHA1 지문 추출
$keytoolOutput = & keytool -list -v -keystore $debugKeystorePath -alias androiddebugkey -storepass android -keypass android 2>$null

# SHA1 지문 추출 (콜론 제거)
$sha1Line = $keytoolOutput | Select-String "SHA1:"
if ($sha1Line) {
    $sha1Hex = ($sha1Line -split "SHA1: ")[1].Replace(":", "").Trim()
    
    Write-Host "디버그 SHA1 지문: $sha1Hex"
    
    # 16진수 문자열을 바이트 배열로 변환
    $sha1Bytes = [byte[]]@()
    for ($i = 0; $i -lt $sha1Hex.Length; $i += 2) {
        $hexPair = $sha1Hex.Substring($i, 2)
        $sha1Bytes += [Convert]::ToByte($hexPair, 16)
    }
    
    # Base64로 인코딩하여 카카오 해시 키 생성
    $kakaoHashKey = [Convert]::ToBase64String($sha1Bytes)
    Write-Host "디버그용 카카오 해시 키: $kakaoHashKey"
} else {
    Write-Host "SHA1 지문을 찾을 수 없습니다."
}