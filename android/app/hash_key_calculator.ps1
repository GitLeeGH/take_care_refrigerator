# SHA1 지문을 카카오 해시 키로 변환 (콜론 제거)
$sha1Hex = "2F8AEB23CC721296264FB90C21BCAEEF4B07AA45"

# 16진수 문자열을 바이트 배열로 변환
$sha1Bytes = [byte[]]@()
for ($i = 0; $i -lt $sha1Hex.Length; $i += 2) {
    $hexPair = $sha1Hex.Substring($i, 2)
    $sha1Bytes += [Convert]::ToByte($hexPair, 16)
}

# Base64로 인코딩하여 카카오 해시 키 생성
$kakaoHashKey = [Convert]::ToBase64String($sha1Bytes)
Write-Host "릴리스용 카카오 해시 키: $kakaoHashKey"