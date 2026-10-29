# Original video playback

Android: official YouTube IFrame Player API inside Flutter's official system WebView plugin. Loaded only after an explicit tap, autoplay disabled, 240 logical-pixel height and available card width (over the 200px minimum at 320px screen width). The local HTML base URL/origin uses the actual configured Android app ID (`com.tcf.take_care_refrigerator.dev` for debug, production ID otherwise), following YouTube's mobile WebView Referer identity guidance. No API key, download or transcript service.

The navigation delegate rejects top-level external/intent/file/javascript navigation and only permits official YouTube iframe navigations. JS messages are interpreted only as ready/error status, never evaluated. Player errors including 100, 101/150 and 153, startup errors and a 20-second readiness timeout retain the original-link fallback. App backgrounding, covered routes and external launching pause playback; disposal destroys the player and clears its HTML. Return does not autoplay. Actual device playback and platform-specific timing still require user testing; mocked tests are not a successful YouTube playback claim.

Instagram: strict HTTPS `instagram.com`/`www.instagram.com` `/reel/<code>/` links only. Open original externally, then browser fallback, then copyable URL/error if both fail. Explicitly disclose login, private account and creator embed restrictions. No Instagram iframe, oEmbed token, account permissions or paid provider configured. Other platforms also use the original-link fallback for YouTube.

Recipe preview remains transient. Exact-ID creator-comment fixture is still manually verified example content, not general extraction. No unknown steps or timestamps are generated. Link changes discard the old embedded widget; app Back returns through normal Flutter navigation.

Official references consulted:
- https://developers.google.com/youtube/iframe_api_reference
- https://developers.google.com/youtube/player_parameters
- https://developers.google.com/youtube/terms/required-minimum-functionality (Referer identity, local HTML baseUrl, minimum size)
- https://pub.dev/packages/webview_flutter (Flutter publisher)
- https://help.instagram.com/620154495870484/ (public content and embedding restrictions)

Build preparation disables Windows/Linux desktop targets only in the current Android build process. This avoids unrelated desktop symlink generation; no Windows Developer Mode, ACL, global Flutter configuration or other security settings are changed.
