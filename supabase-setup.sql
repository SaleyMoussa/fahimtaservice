-- À coller dans Supabase : SQL Editor > New query > Run

create table if not exists inscriptions (
  id bigint generated always as identity primary key,
  created_at timestamptz default now(),
  statut text default 'Nouvelle',
  nom text, prenom text, sexe text,
  niveau_etudes text,
  date_naissance date, lieu_naissance text,
  nationalite text, telephone text, email text,
  formation text, niveau_souhaite text,
  duree_jours int, date_debut date,
  mode text, frais text
);

alter table inscriptions enable row level security;

-- Tout visiteur peut envoyer une inscription, mais pas la lire
create policy "envoi public" on inscriptions
  for insert to anon with check (true);

-- Seuls les comptes connectés (vous et vos assistants) peuvent lire et modifier
create policy "lecture equipe" on inscriptions
  for select to authenticated using (true);
create policy "modification equipe" on inscriptions
  for update to authenticated using (true) with check (true);
