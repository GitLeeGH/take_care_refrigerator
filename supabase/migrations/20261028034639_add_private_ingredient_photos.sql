-- Private ingredient photos. Existing recipe bucket and policies unchanged.
alter table public.ingredients add column image_path text;
alter table public.ingredients add constraint ingredients_image_path_owned_format
check (image_path is null or (
 split_part(image_path, '/', 1) = user_id::text
 and split_part(image_path, '/', 2) = id::text
 and image_path ~ '^(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})[.](jpg|jpeg|png)$'
));
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('ingredient-photos','ingredient-photos',false,5242880,array['image/jpeg','image/png']);

-- Restrictive policies prevent any existing permissive policy from broadening this bucket.
create policy ingredient_photos_owner_guard on storage.objects as restrictive for all to public
using (bucket_id is distinct from 'ingredient-photos' or ((select auth.uid()) is not null and split_part(name, '/', 1) = (select auth.uid())::text and name ~ '^(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})[.](jpg|jpeg|png)$'))
with check (bucket_id is distinct from 'ingredient-photos' or ((select auth.uid()) is not null and split_part(name, '/', 1) = (select auth.uid())::text and name ~ '^(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})[.](jpg|jpeg|png)$'));

-- Immutable keys: neither an old object nor a new target may be in this bucket on UPDATE.
create policy ingredient_photos_no_update on storage.objects as restrictive for update to public
using (bucket_id is distinct from 'ingredient-photos')
with check (bucket_id is distinct from 'ingredient-photos');

create policy ingredient_photos_select_own on storage.objects for select to authenticated
using (bucket_id='ingredient-photos' and ((select auth.uid()) is not null and split_part(name, '/', 1) = (select auth.uid())::text and name ~ '^(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})[.](jpg|jpeg|png)$'));
create policy ingredient_photos_insert_own on storage.objects for insert to authenticated
with check (bucket_id='ingredient-photos' and ((select auth.uid()) is not null and split_part(name, '/', 1) = (select auth.uid())::text and name ~ '^(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})[.](jpg|jpeg|png)$'));
create policy ingredient_photos_delete_own on storage.objects for delete to authenticated
using (bucket_id='ingredient-photos' and ((select auth.uid()) is not null and split_part(name, '/', 1) = (select auth.uid())::text and name ~ '^(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})[.](jpg|jpeg|png)$'));
