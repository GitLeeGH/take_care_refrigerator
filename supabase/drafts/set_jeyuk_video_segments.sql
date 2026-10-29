-- DRAFT ONLY. Parent executes after the additive schema migration and preflight.
-- Exact text guards intentionally abort if the saved steps differ; do not weaken.
DO $block$
DECLARE
  target_id CONSTANT uuid := 'def1200d-5e5a-5abb-88d2-1727e03c83c7';
  expected_steps CONSTANT text[] := ARRAY[
    '돼지고기 목전지 600g을 준비합니다.',
    '팬에 식용유 3스푼, 설탕 2스푼, 다진 마늘 1스푼을 넣고 중약불에서 볶습니다.',
    '마늘이 조금 갈색으로 변하면 고기를 넣고 센 불에서 볶습니다.',
    '고기가 약 80% 익으면 고추장 1스푼, 고춧가루 4스푼, 진간장 3스푼, 미림 2스푼, 굴소스 1스푼, 후추와 썬 청양고추 2개를 넣습니다.',
    '양념이 섞이도록 센 불에서 1분 더 볶습니다.',
    '썬 양파 1/2개와 대파 1대를 넣어 볶습니다.',
    '채소가 반쯤 익으면 참기름 1스푼과 통깨 1스푼을 넣고 섞습니다.'
  ];
  starts CONSTANT integer[] := ARRAY[19,21,35,43,51,55,58];
  ends CONSTANT integer[] := ARRAY[21,35,43,51,55,58,61];
  saved public.recipes%ROWTYPE;
  actual_steps text[];
  actual_numbers integer[];
  payload jsonb;
  unchanged_before text;
  unchanged_after text;
  changed integer;
BEGIN
  SELECT * INTO STRICT saved FROM public.recipes WHERE id = target_id FOR UPDATE;
  IF saved.youtube_video_id IS DISTINCT FROM 'rLEyOHvGb1Y'
     OR saved.description IS NULL
     OR position('## 조리 방법' in saved.description) = 0
     OR position('[아직 확인되지 않은 정보]' in saved.description) > 0
     OR position('steps=unverified' in saved.description) > 0 THEN
    RAISE EXCEPTION 'Target video or verified cooking section differs';
  END IF;
  SELECT array_agg(btrim(m[2]) ORDER BY ord), array_agg(m[1]::integer ORDER BY ord)
    INTO actual_steps, actual_numbers
    FROM regexp_matches(saved.description, E'(?m)^[ \\t]*([0-9]+)[.)][ \\t]+([^\\r\\n]+)', 'g')
      WITH ORDINALITY AS matches(m, ord);
  IF actual_steps IS DISTINCT FROM expected_steps
     OR actual_numbers IS DISTINCT FROM ARRAY[1,2,3,4,5,6,7] THEN
    RAISE EXCEPTION 'Saved steps differ from reviewed text; inspect and reconcile before retry';
  END IF;
  SELECT jsonb_build_object(
    'version', 1, 'video_id', 'rLEyOHvGb1Y', 'verified', true,
    'verified_at', '2026-10-29', 'coverage', 'excerpt',
    'precision', 'approximate_seconds', 'timing_basis', 'manual_visual_review',
    'duration_seconds', 61.461,
    'segments', jsonb_agg(jsonb_build_object('step_text', expected_steps[i],
      'start_seconds', starts[i], 'end_seconds', ends[i]) ORDER BY i)
  ) INTO payload FROM generate_series(1,7) AS s(i);
  IF saved.video_segments = payload THEN
    RAISE NOTICE 'Already applied; no changes';
    RETURN;
  ELSIF saved.video_segments IS NOT NULL THEN
    RAISE EXCEPTION 'Existing timing metadata must not be overwritten';
  END IF;

  SELECT md5(string_agg(
    (CASE WHEN r.id = target_id THEN to_jsonb(r) - 'video_segments' ELSE to_jsonb(r) END)::text,
    E'\n' ORDER BY r.id)) INTO unchanged_before FROM public.recipes r;

  UPDATE public.recipes SET video_segments = payload
    WHERE id = target_id AND youtube_video_id = 'rLEyOHvGb1Y'
      AND description IS NOT DISTINCT FROM saved.description AND video_segments IS NULL;
  GET DIAGNOSTICS changed = ROW_COUNT;
  IF changed <> 1 THEN RAISE EXCEPTION 'Expected exactly one updated recipe'; END IF;

  SELECT md5(string_agg(
    (CASE WHEN r.id = target_id THEN to_jsonb(r) - 'video_segments' ELSE to_jsonb(r) END)::text,
    E'\n' ORDER BY r.id)) INTO unchanged_after FROM public.recipes r;
  IF unchanged_after IS DISTINCT FROM unchanged_before THEN
    RAISE EXCEPTION 'Unrelated recipe data changed; rolling back this update';
  END IF;
END;
$block$;

-- Preserve this exact hash for guarded rollback; also verify through public SELECT.
SELECT id, youtube_video_id, jsonb_array_length(video_segments->'segments') AS segment_count,
       video_segments->>'precision' AS precision,
       md5(video_segments::text) AS rollback_metadata_hash,
       video_segments
FROM public.recipes WHERE id = 'def1200d-5e5a-5abb-88d2-1727e03c83c7';
