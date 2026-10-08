-- Staalnamen: vaste tappunten, rondes, toegangsregels en fotobucket.
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

-- Vaste punten (looproute) per site en soort ronde.
-- "analyses": welke stalen op dit punt genomen worden, bv. {legionella, chemisch}.
-- "foto": foto van het tappunt, zodat je het terugvindt.
create table if not exists public.staalpunten (
  id uuid primary key default gen_random_uuid(),
  site text not null,
  type text not null,
  volgorde integer not null default 0,
  afdeling text not null default '',
  verdiep text not null default '',
  tappunt text not null default '',
  analyses text[] not null default '{}',
  foto text,
  aangemaakt timestamptz not null default now(),
  aangemaakt_door uuid default auth.uid()
);
create index if not exists staalpunten_site_type_idx on public.staalpunten(site, type, volgorde);

create table if not exists public.staalrondes (
  id uuid primary key default gen_random_uuid(),
  site text not null,
  type text not null,
  datum date not null,
  aangemaakt timestamptz not null default now(),
  aangemaakt_door uuid default auth.uid()
);
create index if not exists staalrondes_site_type_idx on public.staalrondes(site, type, datum desc);

-- Elk punt van een ronde, met een kopie van het vaste punt zodat latere wijzigingen
-- aan de looproute oude rondes niet veranderen.
-- "genomen": de analyses waarvan het staal genomen is.
create table if not exists public.staalronde_punten (
  id uuid primary key default gen_random_uuid(),
  ronde_id uuid not null references public.staalrondes(id) on delete cascade,
  aangemaakt timestamptz not null default now(),
  aangemaakt_door uuid default auth.uid()
);
alter table public.staalronde_punten add column if not exists punt_id uuid references public.staalpunten(id) on delete set null;
alter table public.staalronde_punten add column if not exists volgorde integer not null default 0;
alter table public.staalronde_punten add column if not exists afdeling text not null default '';
alter table public.staalronde_punten add column if not exists verdiep text not null default '';
alter table public.staalronde_punten add column if not exists tappunt text not null default '';
alter table public.staalronde_punten add column if not exists analyses text[] not null default '{}';
alter table public.staalronde_punten add column if not exists genomen_analyses text[] not null default '{}';
alter table public.staalronde_punten add column if not exists staalnummer text not null default '';
alter table public.staalronde_punten add column if not exists temperatuur text not null default '';
alter table public.staalronde_punten add column if not exists opmerkingen text not null default '';
alter table public.staalronde_punten add column if not exists fotos text[] not null default '{}';
create index if not exists staalronde_punten_ronde_idx on public.staalronde_punten(ronde_id, volgorde);

alter table public.staalpunten enable row level security;
alter table public.staalrondes enable row level security;
alter table public.staalronde_punten enable row level security;

drop policy if exists "staalpunten voor collega's" on public.staalpunten;
create policy "staalpunten voor collega's" on public.staalpunten
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
  alter publication supabase_realtime add table public.staalpunten;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.staalrondes;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.staalronde_punten;
exception when duplicate_object then null; end $$;

-- Tabellen uit eerdere versies die niet meer gebruikt worden. Opruimen kan (enkel als er niets in
-- staat dat je wil bewaren) door de streepjes voor de volgende regels weg te halen:
-- drop table if exists public.staalnamen;
-- drop table if exists public.staalpuntlijsten;
