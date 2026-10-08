-- Staalnamen: tabel, fotobucket en toegangsregels.
-- Draait in hetzelfde Supabase-project als de veiligheidsrondes en raakt die gegevens niet aan:
-- alles hier is nieuw (tabel "staalnamen", bucket "staalnamen-fotos").
-- Het gebruikt wel de bestaande toegangslijst "toegang" en de functie heeft_toegang() van de
-- veiligheidsrondes: wie daar toegang heeft, heeft ook toegang tot de staalnamen.
-- Plak dit volledig in Supabase > SQL Editor en klik op Run.

-- Veiligheidscheck: de toegangslijst van de veiligheidsrondes moet al bestaan.
do $$ begin
  if to_regprocedure('public.heeft_toegang()') is null then
    raise exception 'Functie public.heeft_toegang() ontbreekt. Voer eerst het schema van de veiligheidsrondes uit.';
  end if;
end $$;

create table if not exists public.staalnamen (
  id uuid primary key default gen_random_uuid(),
  site text not null,
  datum date not null,
  gebouw text not null default '',
  verdiep text not null default '',
  lokaal text not null default '',
  staaltype text not null,
  staalnummer text not null default '',
  uitvoerder text not null default '',
  opmerkingen text not null default '',
  fotos text[] not null default '{}',
  aangemaakt timestamptz not null default now(),
  aangemaakt_door uuid default auth.uid()
);
-- De lijst met staaltypes staat in de app (index.html), niet in de database.
create index if not exists staalnamen_site_datum_idx on public.staalnamen(site, datum desc);

alter table public.staalnamen enable row level security;

drop policy if exists "staalnamen voor collega's" on public.staalnamen;
create policy "staalnamen voor collega's" on public.staalnamen
  for all to authenticated using (public.heeft_toegang()) with check (public.heeft_toegang());

-- Foto's: aparte privé-bucket, enkel voor e-mailadressen in "toegang".
insert into storage.buckets (id, name, public) values ('staalnamen-fotos', 'staalnamen-fotos', false)
on conflict (id) do nothing;

drop policy if exists "staalnamen fotos lezen" on storage.objects;
create policy "staalnamen fotos lezen" on storage.objects for select to authenticated
  using (bucket_id = 'staalnamen-fotos' and public.heeft_toegang());
drop policy if exists "staalnamen fotos toevoegen" on storage.objects;
create policy "staalnamen fotos toevoegen" on storage.objects for insert to authenticated
  with check (bucket_id = 'staalnamen-fotos' and public.heeft_toegang());
drop policy if exists "staalnamen fotos wijzigen" on storage.objects;
create policy "staalnamen fotos wijzigen" on storage.objects for update to authenticated
  using (bucket_id = 'staalnamen-fotos' and public.heeft_toegang());
drop policy if exists "staalnamen fotos verwijderen" on storage.objects;
create policy "staalnamen fotos verwijderen" on storage.objects for delete to authenticated
  using (bucket_id = 'staalnamen-fotos' and public.heeft_toegang());

-- Live bijwerken wanneer een collega iets wijzigt.
do $$ begin
  alter publication supabase_realtime add table public.staalnamen;
exception when duplicate_object then null; end $$;
