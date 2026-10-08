-- Staalnamen: rondes met vaste punten, toegangsregels en fotobucket.
-- Draait in hetzelfde Supabase-project als de veiligheidsrondes en raakt die gegevens niet aan.
-- Het gebruikt wel de bestaande toegangslijst "toegang" en de functie heeft_toegang() van de
-- veiligheidsrondes: wie daar toegang heeft, heeft ook toegang tot de staalnamen.
-- Plak dit volledig in Supabase > SQL Editor en klik op Run. Opnieuw uitvoeren kan geen kwaad.

-- Veiligheidscheck: de toegangslijst van de veiligheidsrondes moet al bestaan.
do $$ begin
  if to_regprocedure('public.heeft_toegang()') is null then
    raise exception 'Functie public.heeft_toegang() ontbreekt. Voer eerst het schema van de veiligheidsrondes uit.';
  end if;
end $$;

-- Vaste punten per site en type ronde, zoals geplakt uit Excel:
-- "kolommen" zijn de kolomtitels, "punten" is een lijst rijen met per kolom een waarde.
create table if not exists public.staalpuntlijsten (
  site text not null,
  type text not null,
  kolommen text[] not null default '{}',
  punten jsonb not null default '[]',
  bijgewerkt timestamptz not null default now(),
  primary key (site, type)
);

create table if not exists public.staalrondes (
  id uuid primary key default gen_random_uuid(),
  site text not null,
  type text not null,
  datum date not null,
  kolommen text[] not null default '{}',  -- kolomtitels van de vaste punten bij het aanmaken
  aangemaakt timestamptz not null default now(),
  aangemaakt_door uuid default auth.uid()
);
create index if not exists staalrondes_site_type_idx on public.staalrondes(site, type, datum desc);

-- Elk punt van een ronde, met een kopie van de vaste gegevens zodat latere wijzigingen
-- aan de vaste punten oude rondes niet veranderen.
create table if not exists public.staalronde_punten (
  id uuid primary key default gen_random_uuid(),
  ronde_id uuid not null references public.staalrondes(id) on delete cascade,
  volgorde integer not null default 0,
  waarden text[] not null default '{}',
  genomen boolean not null default false,
  staalnummer text not null default '',
  temperatuur text not null default '',
  opmerkingen text not null default '',
  fotos text[] not null default '{}',
  aangemaakt timestamptz not null default now(),
  aangemaakt_door uuid default auth.uid()
);
create index if not exists staalronde_punten_ronde_idx on public.staalronde_punten(ronde_id, volgorde);

alter table public.staalpuntlijsten enable row level security;
alter table public.staalrondes enable row level security;
alter table public.staalronde_punten enable row level security;

drop policy if exists "staalpuntlijsten voor collega's" on public.staalpuntlijsten;
create policy "staalpuntlijsten voor collega's" on public.staalpuntlijsten
  for all to authenticated using (public.heeft_toegang()) with check (public.heeft_toegang());
drop policy if exists "staalrondes voor collega's" on public.staalrondes;
create policy "staalrondes voor collega's" on public.staalrondes
  for all to authenticated using (public.heeft_toegang()) with check (public.heeft_toegang());
drop policy if exists "staalronde_punten voor collega's" on public.staalronde_punten;
create policy "staalronde_punten voor collega's" on public.staalronde_punten
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
  alter publication supabase_realtime add table public.staalpuntlijsten;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.staalrondes;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.staalronde_punten;
exception when duplicate_object then null; end $$;

-- De tabel "staalnamen" uit de eerste versie wordt niet meer gebruikt. Wie ze wil opruimen
-- (enkel als er niets in staat dat je wil bewaren), haalt de streepjes voor de volgende regel weg:
-- drop table if exists public.staalnamen;
