-- Run only on a disposable/local Supabase DB: psql <connection> -v ON_ERROR_STOP=1 -f supabase/tests/rls.sql
-- Everything is rolled back, including test users and storage metadata.
begin;
insert into auth.users(id, aud, role, email) values
  ('aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', 'naugi-test-a@example.invalid'),
  ('bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb', 'authenticated', 'authenticated', 'naugi-test-b@example.invalid');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa', true);
select public.save_notebook('{"schemaVersion":1,"recipes":[],"ingredients":[],"meals":[],"pantry":[],"lists":[],"preferences":{}}', 0);
do $$ begin
  if (select count(*) from public.notebooks) <> 1 then raise exception 'Own data unreadable'; end if;
  begin
    perform public.save_notebook('{"schemaVersion":1,"recipes":[],"ingredients":[],"meals":[],"pantry":[],"lists":[],"preferences":{}}', 0);
    raise exception 'Conflict was not rejected';
  exception when serialization_failure then null; end;
end $$;
select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb', true);
do $$ begin
  if (select count(*) from public.notebooks) <> 0 then raise exception 'Cross-user leak'; end if;
  begin
    perform public.consume_ai_quota('bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb');
    raise exception 'Quota RPC exposed to user';
  exception when insufficient_privilege then null; end;
  begin
    insert into storage.objects(bucket_id, name) values ('recipe-images', 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa/forbidden.jpg');
    raise exception 'Cross-user image insert allowed';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ declare i integer; begin
  for i in 1..10 loop
    if not public.consume_ai_quota('aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa') then raise exception 'Quota rejected too soon'; end if;
  end loop;
  if public.consume_ai_quota('aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa') then raise exception 'Quota exceeded'; end if;
end $$;
rollback;
