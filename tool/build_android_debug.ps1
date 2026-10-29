# Android-only preparation avoids unnecessary Windows desktop symlink setup.
# No global Flutter configuration or Windows security setting is changed.
$previousFlutterWindows = $env:FLUTTER_WINDOWS
$previousFlutterLinux = $env:FLUTTER_LINUX
try {
    $env:FLUTTER_WINDOWS = 'false'
    $env:FLUTTER_LINUX = 'false'
    flutter pub get --offline
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency/plugin preparation failed.' }
    if (!(Test-Path 'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java')) {
        throw 'Android plugin registrant is missing; do not install this build.'
    }
    flutter build apk --debug --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Android debug build failed.' }
} finally {
    $env:FLUTTER_WINDOWS = $previousFlutterWindows
    $env:FLUTTER_LINUX = $previousFlutterLinux
}
