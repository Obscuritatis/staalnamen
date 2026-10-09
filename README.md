# Staalnamen

Webapp om staalnamerondes bij te houden. Per site kies je een soort ronde (*Legionella* of *Afvalwater en linnen*)
en maak je een nieuwe ronde aan. Elke ronde krijgt de vaste punten (looproute) van die site en soort.
Per punt vink je elk staal aan dat genomen is (bij legionella soms twee: *Legionella* en *Chemisch +
bacteriologisch*) en vul je opmerkingen en foto's in. Een ronde is te exporteren
naar Excel (met foto's).

Sites: Psychiatrisch ziekenhuis Tienen, WZC Sint-Alexius, WZC-Passionisten, WZC-Huize Nazareth en PSC-Leuven.
Sites, soorten rondes en stalen staan bovenaan in [`index.html`](index.html) (`SITES`, `TYPES`).

**Vaste punten**: per site en soort ronde. Plak ze vanuit Excel (met kolomtitels: Legionella en Chemische +
bacteriologische analyse met een x, Afdeling, Verdiep, Tappunt naam) of voeg ze één voor één toe. De volgorde
van de looproute pas je aan met de pijltjes; per punt kan je een foto van het tappunt toevoegen. Wijzigingen
aan de looproute veranderen bestaande rondes niet. Met *Excel-lijst* op de pagina van de site download je een korte lijst
van de vaste punten (welke stalen, afdeling en tappunt) om door te sturen naar wie de staalnames inplant.

De app is een statische pagina (GitHub Pages), gebouwd op dezelfde basis als
[veiligheidsrondes](https://github.com/Obscuritatis/veiligheidsrondes). Ze gebruikt hetzelfde Supabase-project
en dezelfde aanmelding met een link per e-mail, maar eigen tabellen (`staalpunten`, `staalrondes`,
`staalronde_punten`) en een eigen fotobucket (`staalnamen-fotos`). De gegevens van de veiligheidsrondes worden niet aangeraakt.

## Eenmalige opzet

1. **Database**: open in het bestaande Supabase-project *SQL Editor*, plak de inhoud van
   [`supabase/schema.sql`](supabase/schema.sql) en klik *Run*. Het script maakt enkel nieuwe onderdelen aan en mag
   opnieuw uitgevoerd worden (bv. na een update van de app).
2. **Toegang**: de app gebruikt dezelfde toegangslijst (`toegang`) als de veiligheidsrondes.
   Wie daar staat, kan ook de staalnamen zien en invullen. Iemand toevoegen:
   ```sql
   insert into public.toegang (email) values ('naam@voorbeeld.be');
   ```
3. **Aanmeldlink**: voeg onder *Authentication > URL Configuration* een extra *Redirect URL* toe voor het adres
   van deze app, bv. `https://obscuritatis.github.io/staalnamen/`. Laat de bestaande van de veiligheidsrondes staan.
4. **GitHub Pages**: repository > *Settings > Pages* > *Deploy from a branch* > `main` / `(root)`.

De koppeling met Supabase staat in [`config.js`](config.js) (zelfde project als de veiligheidsrondes).

## Opmerkingen

- De gratis aanmeldmails van Supabase zijn beperkt in aantal per uur. Voor een grotere groep stel je
  een eigen mailserver in onder *Authentication > SMTP*.
- Een gratis Supabase-project wordt gepauzeerd na een week zonder gebruik; je zet het terug aan in het dashboard.
- In de Excel-export staan maximaal 4 foto's per punt; meer foto's blijven zichtbaar in de app.
