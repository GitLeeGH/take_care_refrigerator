-- DRAFT ONLY: parent applies through Supabase migration tool after inspection.
-- CLI is unavailable here; no timestamped migration history is invented.
-- Fail if the column/constraint already exists; inspect before retrying.
ALTER TABLE public.recipes ADD COLUMN video_segments jsonb;
ALTER TABLE public.recipes ADD CONSTRAINT recipes_video_segments_object
  CHECK (video_segments IS NULL OR jsonb_typeof(video_segments) = 'object');
COMMENT ON COLUMN public.recipes.video_segments IS
  'Admin-reviewed approximate source-video ranges, bound to exact recipe step text; optional.';
