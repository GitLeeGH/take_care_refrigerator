# Recorded remote migration

Version `20261028034639_add_private_ingredient_photos` was already applied by the separate authorized backend worker. Its SQL is recorded here verbatim and was NOT executed from this desktop. The worker reported unchanged hashes for all 281 existing ingredients, unchanged nine existing recipe-bucket policies, and 11 passing path-expression checks. Full rollback role/DML verification was blocked by expired request state; no real photo uploads were performed. Do not describe this as end-to-end storage permission verification.

The client uses immutable UUID photo paths, authenticated downloads, JPEG/PNG up to 5 MiB, and stable ingredient IDs when retrying saves. Uncertain DB responses retain candidate photos rather than risk deleting a committed object. Abandoned uncertain saves can therefore leave private orphan objects. Ingredient deletion currently retains its original row-delete behavior; orphan-photo garbage collection is not implemented. Camera activity/process-death draft recovery is not implemented; normal selection cancellation and permission errors are handled. These limitations do not authorize cleanup of real user objects or test uploads.

Version `20261027042644` was already applied to project `brghwnwkfhbhamrrrqnr` by the authorized security worker. The accompanying SQL preserves the exact supplied statement text. This desktop task saved the history only; it did not execute or reapply the migration, repair remote history, or push database changes.

The security worker reported 23 passing rollback-only assertions and unchanged source record fingerprints and counts. Those assertions were not rerun on the desktop. Reported counts: ingredients 281, recipes 200, profiles 1, recipe_likes 7, shelf_life_data 148.

This migration restricts recipe writes to administrators, protects profile roles, and isolates the privileged like-counter trigger. It assumes the existing restored schema and policies; it is not a fresh-database baseline or an idempotent script. The repository has no preceding schema migrations or Supabase CLI configuration. Do not blindly replay it against the restored project or use this directory alone to bootstrap an empty database.

Desktop verification uses only a public zero-row recipe read. No authenticated permission tests, account operations, or database writes are performed here. The existing schema review under `supabase/drafts` remains an unexecuted draft.
