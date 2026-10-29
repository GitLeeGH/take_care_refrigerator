-- LOCAL DESIGN / SOURCE-SCHEMA REVIEW ONLY. Not a migration.
-- No existing SQL or migration files were found in the original repository.
-- Source: hcthpegwiefdpkrsgfav (insaeng-matjip), currently reported INACTIVE.
-- Target: lcoauupfidbrjifacedv (take-care-refrigerator), reported empty public schema.
-- Do not create tables in the target until the real source schema and backup
-- have been inspected. Never run DDL or destructive SQL against the source.
-- The executable statements below inspect schema metadata only, not row data,
-- auth credentials, configuration values, or function source bodies.

-- APP CONTRACT (types below are candidates, not recovered source types)
-- public.profiles:
--   id uuid (auth.users.id), role text; app reads own role, defaults to 'user'.
--   Auth signup trigger should create role='user' without copying authorization
--   from user_metadata. Only trusted server administration may assign 'admin'.
-- public.ingredients:
--   id UUID serialized as String, user_id uuid, name text, quantity text,
--   expiry_date date, storage_type text, created_at timestamptz.
--   storage_type values actually written: refrigerated / frozen / ambient.
--   All CRUD is owner-only; UPDATE must protect user_id in USING AND WITH CHECK.
--   Index candidate: (user_id, expiry_date). Realtime .stream(primaryKey:['id']).
-- public.recipes:
--   id UUID serialized as String, name text, description text nullable,
--   image_url text nullable, youtube_video_id text nullable, blog_url text nullable,
--   total_time text nullable (NOT numeric), cuisine_type text nullable,
--   required_ingredients text[] (JSON array on the wire), like_count integer,
--   created_at timestamptz. Author column is NOT established by current model.
--   Insert payload omits author: source may have a default/trigger; inspect it.
--   Unused account cleanup tries user_id first, then author_id: not proof either exists.
--   Public recipe reads; UI allows create/edit only when own profiles.role='admin'.
--   Conservative candidate: admin AND owner writes. Cross-owner admin editing
--   must be confirmed, not inferred from the UI's visible edit button.
--   If author is user_id, default auth.uid() server-side. Client cannot rewrite
--   author, like_count, id, or created_at (column-specific INSERT/UPDATE grants).
--   Index candidates: created_at DESC, like_count DESC, author FK.
-- public.recipe_likes:
--   user_id uuid + recipe_id matching recipes.id, composite primary key.
--   Read/insert/delete own rows; no UPDATE required. No public user-like listing.
--   FK(recipe_id) cascade; index recipe_id for counting/cascade.
--   App never updates recipes.like_count: source trigger/function is required.
--   A replacement counter trigger must handle insert/delete/cascade atomically,
--   not accept a client-supplied count; privileged helper stays in private schema,
--   fixed search_path, no public EXECUTE. Verify source implementation first.
--   Realtime .stream(primaryKey:['user_id','recipe_id']).
-- public.shelf_life_data:
--   name text, days integer; read shared (select name,days), insert name/days.
--   App offers crowd contributions without author in payload. Need source review
--   for uniqueness, moderation, author default and duplicate handling.
--   Conservative candidate: public read, authenticated insert with server-owned
--   created_by=auth.uid(), positive days, unique normalized name; no client
--   update/delete unless explicitly approved. This is not expert food-safety data.

-- SECURITY POLICY SHAPE (illustrative; DO NOT APPLY until source review):
-- ALTER TABLE each exposed table ENABLE ROW LEVEL SECURITY;
-- REVOKE ALL table privileges from anon/authenticated before explicit grants.
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ingredients TO authenticated;
-- CREATE POLICY inventory_select ON ingredients FOR SELECT TO authenticated
--   USING (user_id = (SELECT auth.uid()));
-- CREATE POLICY inventory_insert ON ingredients FOR INSERT TO authenticated
--   WITH CHECK (user_id = (SELECT auth.uid()));
-- CREATE POLICY inventory_update ON ingredients FOR UPDATE TO authenticated
--   USING (user_id = (SELECT auth.uid()))
--   WITH CHECK (user_id = (SELECT auth.uid()));
-- CREATE POLICY inventory_delete ON ingredients FOR DELETE TO authenticated
--   USING (user_id = (SELECT auth.uid()));
-- profiles: own SELECT only; client cannot INSERT/UPDATE role or DELETE profile.
-- recipes: anon/authenticated SELECT; owner/admin writes with both RLS clauses.
-- recipe_likes: own SELECT/INSERT/DELETE using authenticated uid, no UPDATE.
-- Explicit grants are required even if Data API auto-exposure is disabled.
-- Keep private helper schema OUT of exposed schemas. Never authorize from
-- raw_user_meta_data, nickname, provider='kakao', or email supplied by client.

-- STORAGE CONTRACT:
-- Bucket 'recipes'; upload path recipe_images/<milliseconds>.<extension>.
-- Uses upload/uploadBinary(upsert:false), then getPublicUrl(). Bucket must serve
-- public recipe images (public download does not imply public metadata/writes).
-- Candidate INSERT policy: authenticated admin, bucket_id='recipes', first
-- path segment='recipe_images', owner_id=auth.uid()::text. No UPDATE needed.
-- Metadata SELECT and optional DELETE limited to object owner; no cross-owner
-- overwrite/delete. Preserve actual source bucket flags, limits, MIME policy.
-- Object bytes must be copied through Storage API; copying storage.objects rows
-- alone does not migrate image bytes. Markdown descriptions may embed old URLs.

-- AUTH / RPC CONTRACT AND BLOCKERS:
-- Google: Supabase OAuth, PKCE. Mobile redirect explicitly:
--   io.supabase.flutterquickstart://login-callback/
-- Kakao flow currently signs in to Kakao separately then signInAnonymously(),
-- and writes Kakao identifiers into editable user_metadata. This does NOT link
-- an authenticated Kakao identity to a stable Supabase user. Re-login can create
-- new anonymous UUIDs. Do not trust those metadata fields for authorization.
-- Anonymous Auth must be enabled to retain current flow, OR replace this flow
-- with verified Supabase Kakao OAuth after a separate implementation decision.
-- Active deletion flow calls delete_my_account() then delete_auth_user(user_id).
-- Errors are caught and ignored, so UI can falsely claim deletion. No new
-- destructive RPC implementation is proposed until source definitions and intended
-- retention are reviewed. Prefer one verified server endpoint: validate caller,
-- revoke sessions, delete owned Storage objects through API, then Auth deletion
-- with reviewed FK behavior; server secret remains server-side. Guard target uid.
-- Deleted users' access JWTs do not immediately expire: session/profile existence
-- checks may be needed for authorization until token expiry. Do not assume logout
-- alone invalidates already-issued JWTs.
-- No recommendations RPC is used: current recommendations are calculated in Dart.

-- MIGRATION REVIEW CHECKLIST (requires real source access / approved backup):
-- 1. Recover exact table types/PK/FK/defaults/indexes/RLS/grants/functions/triggers.
-- 2. Match source UUIDs across auth.users, profiles, inventory, likes, authors.
--    Never fabricate auth identities or map users by unverified editable metadata.
-- 3. Separate schema, Auth identities, data, Storage bytes and Auth provider config.
--    Public table export alone cannot preserve users/passwords/OAuth identities.
-- 4. Take/verify backup; target-only import. Compare row counts, FK integrity and
--    representative content. Preserve source until user validates migration.
-- 5. Copy public image objects and rewrite source project URLs in image_url AND
--    markdown descriptions only after successful copy; preserve external URLs.
-- 6. Realtime publication must include ingredients and recipe_likes. Test insert,
--    update/delete refresh with two users; keep default replica identity unless
--    actual client requirements justify exposing more old-row fields.
-- 7. Test A cannot SELECT/UPDATE/DELETE B inventory or insert/reassign user_id=B;
--    test guest cannot read inventory; test user cannot promote own role;
--    test public recipes readable, unauthorized writes and count spoofing denied;
--    test likes idempotency/counts, storage owner isolation, RPC wrong-user denial.
-- 8. Existing recipe seed data and shelf-life data must come from actual source,
--    not invented replacements. Verify triggers do not double-count imported likes.
-- 9. New project URL + publishable client key only in local ignored .env; never
--    server secret/service_role in Flutter. Rebuild APK because .env is an asset.
-- 10. Run local/unit/widget tests, signed-in app smoke test and target security
--     advisors before calling the migration complete. No deployment/store release.

BEGIN READ ONLY;

SELECT c.table_schema, c.table_name, c.column_name, c.data_type,
       c.udt_name, c.is_nullable
FROM information_schema.columns c
WHERE c.table_schema = 'public'
  AND c.table_name IN ('profiles','ingredients','recipes','recipe_likes','shelf_life_data')
ORDER BY c.table_name, c.ordinal_position;

SELECT n.nspname AS schema_name, c.relname AS table_name,
       c.relrowsecurity AS rls_enabled, c.relforcerowsecurity AS rls_forced
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r';

SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' OR (schemaname = 'storage' AND tablename = 'objects')
ORDER BY schemaname, tablename, policyname;

SELECT table_schema, table_name, grantee, privilege_type
FROM information_schema.table_privileges
WHERE table_schema = 'public' AND grantee IN ('anon','authenticated')
ORDER BY table_name, grantee, privilege_type;

SELECT n.nspname AS schema_name, p.proname AS function_name,
       pg_get_function_identity_arguments(p.oid) AS arguments,
       pg_get_function_result(p.oid) AS result_type, p.prosecdef AS security_definer,
       p.proacl AS execute_grants
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname NOT IN ('pg_catalog','information_schema')
  AND (p.proname IN ('delete_my_account','delete_auth_user')
       OR n.nspname IN ('public','private'))
ORDER BY n.nspname, p.proname;

SELECT n.nspname AS schema_name, c.relname AS table_name, t.tgname AS trigger_name,
       pn.nspname AS function_schema, p.proname AS function_name
FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_proc p ON p.oid = t.tgfoid
JOIN pg_namespace pn ON pn.oid = p.pronamespace
WHERE NOT t.tgisinternal
  AND (n.nspname='public' OR (n.nspname='auth' AND c.relname='users'));

SELECT pubname, schemaname, tablename FROM pg_publication_tables
WHERE pubname = 'supabase_realtime';

SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets WHERE id = 'recipes';

ROLLBACK;
