-- Storage RLS for the private `uploads` bucket (used by photo OCR).
--
-- The ocr/chat Edge Functions DOWNLOAD via the service role, which bypasses RLS,
-- so the bucket worked without any policies. But the Flutter client uploads with
-- the user's JWT / publishable key, which IS subject to RLS — with no policy the
-- upload is denied. These policies let a signed-in user read/write/delete objects
-- only under their own `{uid}/` prefix, matching ownedPath() in chat/index.ts.
--
-- "Paid only" is NOT enforced here: premium is a client-side flag today (no
-- server-side IAP yet), and RLS cannot see it. The app gates the attach button on
-- premium; move that check into an Edge Function once IAP is verified server-side.

create policy "uploads_insert_own"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'uploads' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "uploads_select_own"
  on storage.objects for select to authenticated
  using (bucket_id = 'uploads' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "uploads_delete_own"
  on storage.objects for delete to authenticated
  using (bucket_id = 'uploads' and (storage.foldername(name))[1] = auth.uid()::text);
