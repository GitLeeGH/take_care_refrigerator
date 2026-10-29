-- Scope: admin-only recipe writes; prevent client role escalation.
-- No data rewrite, user deletion, auth configuration or unrelated policy changes.
CREATE SCHEMA recipe_security AUTHORIZATION postgres;
REVOKE ALL ON SCHEMA recipe_security FROM PUBLIC, anon, authenticated;
-- A trigger-only capability, not an exposed RPC. Existing trigger dependencies
-- follow the function OID when moved. All relation references are qualified.
ALTER FUNCTION public.update_recipe_like_count() SET SCHEMA recipe_security;
CREATE OR REPLACE FUNCTION recipe_security.update_recipe_like_count()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
BEGIN
  IF TG_RELID <> 'public.recipe_likes'::regclass
     OR TG_LEVEL <> 'ROW' OR TG_WHEN <> 'AFTER'
     OR TG_OP NOT IN ('INSERT', 'DELETE') THEN
    RAISE EXCEPTION 'Invalid recipe counter trigger context' USING ERRCODE = '42501';
  END IF;
  -- API writes require an authenticated identity. Trusted backend maintenance
  -- and existing cascade cleanup retain their prior behavior.
  IF current_setting('role', true) IN ('anon', 'authenticated')
     AND auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF TG_OP = 'INSERT' THEN
    UPDATE public.recipes SET like_count = like_count + 1 WHERE id = NEW.recipe_id;
  ELSE
    UPDATE public.recipes SET like_count = like_count - 1 WHERE id = OLD.recipe_id;
  END IF;
  RETURN NULL;
END;
$function$;
REVOKE ALL ON FUNCTION recipe_security.update_recipe_like_count()
  FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION recipe_security.guard_profile_role()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $function$
BEGIN
  IF current_user IN ('anon', 'authenticated') THEN
    IF TG_OP = 'INSERT' THEN
      IF NEW.role IS DISTINCT FROM 'user' THEN
        RAISE EXCEPTION 'Profile role is managed by trusted administrators'
          USING ERRCODE = '42501';
      END IF;
    ELSIF NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'Profile role is managed by trusted administrators'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION recipe_security.guard_profile_role()
  FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER guard_profile_role
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION recipe_security.guard_profile_role();

DROP POLICY "Allow all insert" ON public.recipes;
DROP POLICY "Allow all update" ON public.recipes;
DROP POLICY "Allow all delete" ON public.recipes;
ALTER POLICY "Admins can create recipes." ON public.recipes TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND role = 'admin'));
ALTER POLICY "Admins can update recipes." ON public.recipes TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND role = 'admin'));
ALTER POLICY "Admins can delete recipes." ON public.recipes TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND role = 'admin'));
REVOKE INSERT, UPDATE, DELETE ON public.recipes FROM PUBLIC, anon;
-- TRUNCATE bypasses RLS; client-created triggers must not attach privileged code.
REVOKE TRUNCATE, TRIGGER ON public.recipes, public.profiles, public.recipe_likes
  FROM PUBLIC, anon, authenticated;
NOTIFY pgrst, 'reload schema';
