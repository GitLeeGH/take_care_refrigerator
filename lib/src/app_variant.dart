import 'package:flutter/foundation.dart';

// Android's debug build has applicationIdSuffix ".dev" in Gradle.
// Keep release, web and other platform authentication unchanged.
bool get isDevelopmentApp =>
    kDebugMode && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

String get mobileLoginRedirect => isDevelopmentApp
    ? 'com.tcf.take_care_refrigerator.dev://login-callback'
    : 'io.supabase.flutterquickstart://login-callback';
