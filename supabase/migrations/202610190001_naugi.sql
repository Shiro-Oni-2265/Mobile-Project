-- One atomic notebook per user. Optimistic revision prevents silent lost updates.
create table public.notebooks (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null,
  revision bigint not null default 1 check (revision > 0),
  updated_at timestamptz not null default now(),
  check (jsonb_typeof(payload) = 'object' and pg_column_size(payload) < 5000000)
);
alter table public.notebooks enable row level security;
create policy own_notebook_read on public.notebooks for select to authenticated
  using ((select auth.uid()) = user_id);
revoke all on public.notebooks from anon, authenticated;
grant select on public.notebooks to authenticated;

create function public.save_notebook(document jsonb, expected_revision bigint)
returns bigint language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); next_revision bigint; field text;
begin
  if uid is null then raise exception 'AUTH_REQUIRED' using errcode = '42501'; end if;
  if document is null or jsonb_typeof(document) <> 'object' or pg_column_size(document) > 5000000
    or (document->>'schemaVersion') is distinct from '1' then
    raise exception 'INVALID_DOCUMENT' using errcode = '22023';
  end if;
  foreach field in array array['recipes','ingredients','meals','pantry','lists'] loop
    if jsonb_typeof(document->field) is distinct from 'array' then
      raise exception 'INVALID_COLLECTION' using errcode = '22023';
    end if;
    if jsonb_array_length(document->field) > 2000 then raise exception 'DOCUMENT_LIMIT'; end if;
  end loop;
  if jsonb_typeof(document->'preferences') is distinct from 'object' then raise exception 'INVALID_PREFERENCES'; end if;
  if expected_revision = 0 then
    insert into public.notebooks(user_id, payload) values (uid, document)
      on conflict (user_id) do nothing returning revision into next_revision;
  else
    update public.notebooks set payload = document, revision = revision + 1, updated_at = now()
      where user_id = uid and revision = expected_revision returning revision into next_revision;
  end if;
  if next_revision is null then raise exception 'REVISION_CONFLICT' using errcode = '40001'; end if;
  return next_revision;
end $$;
revoke all on function public.save_notebook(jsonb, bigint) from public, anon;
grant execute on function public.save_notebook(jsonb, bigint) to authenticated;

create table public.recipe_catalog (
  id text primary key,
  payload jsonb not null
);
alter table public.recipe_catalog enable row level security;
create policy sample_read on public.recipe_catalog for select to anon, authenticated using (true);
revoke all on public.recipe_catalog from anon, authenticated;
grant select on public.recipe_catalog to anon, authenticated;

create table public.ai_daily_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null,
  requests integer not null default 0,
  primary key (user_id, usage_date)
);
alter table public.ai_daily_usage enable row level security;
revoke all on public.ai_daily_usage from anon, authenticated;

create function public.consume_ai_quota(target_user uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare count_now integer;
begin
  insert into public.ai_daily_usage(user_id, usage_date, requests)
  values (target_user, (now() at time zone 'Asia/Ho_Chi_Minh')::date, 1)
  on conflict(user_id, usage_date) do update set requests = public.ai_daily_usage.requests + 1
    where public.ai_daily_usage.requests < 10
  returning requests into count_now;
  return count_now is not null;
end $$;
revoke all on function public.consume_ai_quota(uuid) from public, anon, authenticated;
grant execute on function public.consume_ai_quota(uuid) to service_role;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('recipe-images', 'recipe-images', false, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
create policy image_read on storage.objects for select to authenticated
  using (bucket_id = 'recipe-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy image_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'recipe-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy image_delete on storage.objects for delete to authenticated
  using (bucket_id = 'recipe-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy image_update on storage.objects for update to authenticated
  using (bucket_id = 'recipe-images' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'recipe-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
