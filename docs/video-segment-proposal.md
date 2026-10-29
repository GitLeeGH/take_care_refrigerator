# Step video segments — implementation and pending persistence

Status: client implemented; approximate segment persistence authorized by parent;
no database migration or recipe update executed on this PC. Parent owns application.
No phone installation performed for this increment.

The app reads an optional `recipes.video_segments` JSON value. Existing `select()`
calls include it if present; a missing column/value is harmless. Unknown, invalid,
unverified, wrong-video or stale-step metadata disables synchronization. Exact
step strings must match the current parsed description in order and count.

Suggested additive schema (proposal only, not an executable migration):

```sql
alter table public.recipes add column video_segments jsonb;
alter table public.recipes add constraint recipes_video_segments_object
  check (video_segments is null or jsonb_typeof(video_segments) = 'object');
```

Keep existing admin-only recipe writes and public SELECT policies unchanged.
Before application, inspect the actual schema and existing value. Any update must
target only `def1200d-5e5a-5abb-88d2-1727e03c83c7`, with video ID and current
description equality guards, and require exactly one returned row. Preserve every
other column and row; compare fingerprints before/after. No client credentials or
new RPC are needed. Parent owns approval and database execution.

Metadata contract (illustrative test data, not timings for the real recipe):

```json
{
  "version": 1,
  "video_id": "rLEyOHvGb1Y",
  "verified": true,
  "verified_at": "2026-10-29T00:00:00Z",
  "coverage": "excerpt",
  "duration_seconds": 61.461,
  "segments": [
    {"step_text": "Exact stored step text", "start_seconds": 20, "end_seconds": 25}
  ]
}
```

All segments must be finite, nonnegative, non-overlapping, ordered, end after
start and within the declared duration. `coverage` accepts `excerpt` or
`complete`; the UI conservatively warns that a segment may omit parts of a step.
Missing metadata never falls back to invented timings or a video-ID hardcode.

## Direct source observations, 2026-10-29

Source: https://www.youtube.com/watch?v=rLEyOHvGb1Y
Official public YouTube in the user's PC browser; signed out, muted, paused.
Times below came from the rendered video element's currentTime, paired with
screenshots of visible burned-in captions/action. Restored temporary speed to
1.0 and closed the temporary tab. No download or transcript export.
Duration observed: 61.461 seconds.

| Time (seconds) | Actual visible evidence |
| --- | --- |
| 18.42 | presenter tasting; not yet ingredient preparation |
| 19.67 | pork package on scale; caption 목전지 이거 |
| 20.00 | scale and burned-in 600g입니다 |
| 21.25 | empty pan, 팬에다가 |
| 23.75 | pan with oil/sugar, 다진마늘 1스푼을 |
| 25.00 | garlic being added |
| 33.20 | frying garlic, 갈색으로 조금 |
| 34.45 | garlic stirring, 변했다 싶으면 |
| 35.70 | pork being added, 바로 고기를 넣고 |
| 41.73 | pork frying, 이렇게 고기가 |
| 42.98 | pork frying, 80%정도 익으면 |
| 44.23 | gochujang, 고추장 1스푼 |
| 50.37 | slicing chilies, 청양고추 2개 (20g) |
| 51.62 | stirring seasoned pork, 양념이 |
| 52.87 | tossing pan, 센불로 '1분'만 |
| 54.12 | stirring, 더 볶아주다가 |
| 55.37 | sliced green onion, 대파 1대를 (100g) |
| 56.62 | vegetables added, 넣어주고 |
| 57.87 | vegetables cooking, 반 정도 익으면 |
| 59.12 | sesame oil, 참기름 1스푼 |
| 60.37 | finished mixture, 잘 섞어주면 됩니다 |

These are observed frames, **not exact editorial boundaries**. Boundary brackets:
preparation→pan (20.00,21.25); garlic→meat (34.45,35.70);
meat→sauce (42.98,44.23); sauce→mixing (50.37,51.62);
mixing→vegetables (54.12,55.37); vegetables→finish (57.87,59.12).
Do not convert bracket midpoints to verified times.

Conservative scene excerpts whose endpoint frames were observed in the relevant
step: 19.67–20.00, 21.25–34.45, 35.70–41.73, 44.23–50.37,
51.62–54.12, 55.37–56.62, 59.12–60.37. These omit transitions and some actions;
the first is too short for a useful loop. They are evidence for selecting a
future reviewed range, not an approved production payload. Full step boundaries
remain pending tighter review. No sample timings are enabled in production.

## Playback behavior and verification

Official API: https://developers.google.com/youtube/iframe_api_reference
Rules: https://developers.google.com/youtube/terms/required-minimum-functionality

`seekTo` cancels `endSeconds`; use object-form `cueVideoById` when paused and
`loadVideoById` while playing, with start/end. No autoplay on initial load.
Repeat is opt-in and responds to ENDED only for the selected video and endpoint.
Turning step following off restores the full video at the current time.
Route exit, background, errors and completion pause; disposal destroys the
player. Returning permits user-initiated playback but does not start it.
Controls remain outside the player. No downloads, replacement playback or overlays.
YouTube keyframe seeking is not frame-accurate; UI discloses this limitation.

Run `flutter test --no-pub` and `node tool/test_player_segments.cjs`.
The JavaScript state tests use the actual embedded script with a fake official
API object; they are not proof of live Android IFrame playback. Actual device
seek/end/repeat behavior still needs verification after metadata approval.

## Approved approximate-range follow-up

The parent authorized reasonable scene-based, whole-second approximation with
explicit UI disclosure. This supersedes the need to finalize frame-exact cuts
before storing approximate metadata. Selected ranges for steps 1–7 are:
**19–21, 21–35, 35–43, 43–51, 51–55, 55–58, 58–61 seconds.**
The boundaries lie in/near the observed transition brackets above. They can
include a little adjacent action. This is not a claim of precise scene cuts.
UI says `단계 영상 · 약 …초` and explains approximate boundaries. `verified:true`
means visually reviewed relevance, with `precision:approximate_seconds`, not
frame accuracy. Timing data is not hardcoded into production widgets.

Exact SQL drafts:
- `supabase/drafts/add_video_segments.sql` — additive nullable JSONB column.
- `supabase/drafts/set_jeyuk_video_segments.sql` — one locked recipe, exact video
  and seven-step text guard, no overwrite of existing nonmatching metadata,
  repeat-run no-op, and all other recipe data fingerprint comparison. SQL has
  not been executed against PostgreSQL here. If the exact text differs, parent
  must inspect actual stored steps and reconcile the guard; never drop it.

Preflight: inspect column/constraint existence and type, target ID/video/
description/current metadata, count and ordered fingerprints of recipes,
`pg_policies` for recipes, and RLS flags. Retain the original NULL metadata and
description hash. Apply DDL through parent migration tool; compare existing
recipe data excluding the new nullable column and security definitions before/
after. Execute data draft; verify seven ordered ranges and public SELECT, count,
unchanged columns/other rows and unchanged policies. Retain returned
`rollback_metadata_hash`.

Guarded data rollback template (replace only the captured 32-hex hash):

```sql
update public.recipes set video_segments = null
where id = 'def1200d-5e5a-5abb-88d2-1727e03c83c7'
  and youtube_video_id = 'rLEyOHvGb1Y'
  and md5(video_segments::text) = '<captured rollback_metadata_hash>'
returning id;
```

Require exactly one returned row, or inspect without forcing. Retain the nullable
column on rollback; this avoids destroying any subsequently added timings. No
RLS, roles, credentials, auth, other recipe fields or rows are modified.
