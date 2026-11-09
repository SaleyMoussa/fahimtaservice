-- =====================================================================
-- Fahimta : comptes apprenants et équipe (formateurs, gestionnaires, admin)
-- À coller dans Supabase : SQL Editor > New query > Run
-- Le script peut être relancé sans danger : il ne supprime aucune donnée.
-- =====================================================================

-- 1. PROFILS : un profil par compte, créé automatiquement à l'inscription
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  email text,
  nom text,
  prenom text,
  role text not null default 'apprenant'
    check (role in ('apprenant','responsable','gestionnaire','admin'))
);

-- Rôle de la personne connectée (utilisé par les règles d'accès ci-dessous)
create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select coalesce((select role from public.profiles where id = auth.uid()), 'aucun')
$$;

-- Création automatique du profil quand quelqu'un crée un compte
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, nom, prenom)
  values (new.id, new.email, new.raw_user_meta_data->>'nom', new.raw_user_meta_data->>'prenom')
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Profils manquants pour les comptes déjà créés avant ce script
insert into public.profiles (id, email, nom, prenom)
select u.id, u.email, u.raw_user_meta_data->>'nom', u.raw_user_meta_data->>'prenom'
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id);

-- 2. COURS, LEÇONS, DEMANDES D'ACCÈS, PROGRESSION
create table if not exists public.courses (
  id bigint generated always as identity primary key,
  created_at timestamptz default now(),
  titre text not null,
  description text,
  prix text,
  publie boolean not null default false,
  created_by uuid references public.profiles(id) on delete set null
);

create table if not exists public.lessons (
  id bigint generated always as identity primary key,
  course_id bigint not null references public.courses(id) on delete cascade,
  position int not null default 1,
  titre text,
  contenu text default '',
  quiz jsonb default '[]'::jsonb
);

create table if not exists public.enrollments (
  id bigint generated always as identity primary key,
  created_at timestamptz default now(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  course_id bigint not null references public.courses(id) on delete cascade,
  statut text not null default 'demande',
  unique (user_id, course_id)
);

create table if not exists public.progress (
  user_id uuid not null references public.profiles(id) on delete cascade,
  lesson_id bigint not null references public.lessons(id) on delete cascade,
  course_id bigint not null references public.courses(id) on delete cascade,
  done boolean default false,
  score int default 0,
  total int default 0,
  updated_at timestamptz default now(),
  primary key (user_id, lesson_id)
);

-- 3. RÈGLES D'ACCÈS
alter table public.profiles    enable row level security;
alter table public.courses     enable row level security;
alter table public.lessons     enable row level security;
alter table public.enrollments enable row level security;
alter table public.progress    enable row level security;

-- Profils : chacun voit le sien, l'équipe voit tout, seul l'admin change les rôles
drop policy if exists "profil lecture" on public.profiles;
create policy "profil lecture" on public.profiles for select to authenticated
  using (id = auth.uid() or public.my_role() in ('admin','gestionnaire','responsable'));
drop policy if exists "profil admin" on public.profiles;
create policy "profil admin" on public.profiles for update to authenticated
  using (public.my_role() = 'admin') with check (true);

-- Cours : tout le monde voit les cours publiés ; formateurs et admin les gèrent
drop policy if exists "cours lecture" on public.courses;
create policy "cours lecture" on public.courses for select to anon, authenticated
  using (publie or public.my_role() in ('admin','gestionnaire','responsable'));
drop policy if exists "cours creation" on public.courses;
create policy "cours creation" on public.courses for insert to authenticated
  with check (public.my_role() in ('admin','responsable') and created_by = auth.uid());
drop policy if exists "cours modification" on public.courses;
create policy "cours modification" on public.courses for update to authenticated
  using (public.my_role() = 'admin' or (public.my_role() = 'responsable' and created_by = auth.uid()));

-- Leçons : visibles par l'équipe et par les apprenants dont l'accès est actif
drop policy if exists "lecons lecture" on public.lessons;
create policy "lecons lecture" on public.lessons for select to authenticated
  using (public.my_role() in ('admin','gestionnaire','responsable')
         or exists (select 1 from public.enrollments e
                    where e.course_id = lessons.course_id and e.user_id = auth.uid() and e.statut in ('actif','termine')));
drop policy if exists "lecons gestion" on public.lessons;
create policy "lecons gestion" on public.lessons for all to authenticated
  using (public.my_role() = 'admin'
         or (public.my_role() = 'responsable'
             and exists (select 1 from public.courses c where c.id = lessons.course_id and c.created_by = auth.uid())))
  with check (public.my_role() = 'admin'
         or (public.my_role() = 'responsable'
             and exists (select 1 from public.courses c where c.id = lessons.course_id and c.created_by = auth.uid())));

-- Demandes d'accès : l'apprenant demande, l'équipe active
drop policy if exists "acces lecture" on public.enrollments;
create policy "acces lecture" on public.enrollments for select to authenticated
  using (user_id = auth.uid() or public.my_role() in ('admin','gestionnaire','responsable'));
drop policy if exists "acces demande" on public.enrollments;
create policy "acces demande" on public.enrollments for insert to authenticated
  with check (user_id = auth.uid() and statut = 'demande');
drop policy if exists "acces activation" on public.enrollments;
create policy "acces activation" on public.enrollments for update to authenticated
  using (public.my_role() in ('admin','gestionnaire','responsable')) with check (true);

-- Progression : chacun enregistre la sienne, l'équipe la consulte
drop policy if exists "progression lecture" on public.progress;
create policy "progression lecture" on public.progress for select to authenticated
  using (user_id = auth.uid() or public.my_role() in ('admin','gestionnaire','responsable'));
drop policy if exists "progression ajout" on public.progress;
create policy "progression ajout" on public.progress for insert to authenticated
  with check (user_id = auth.uid());
drop policy if exists "progression maj" on public.progress;
create policy "progression maj" on public.progress for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Inscriptions : avant, tout compte connecté (même un apprenant) pouvait lire
-- toutes les fiches d'inscription. On réserve la lecture à l'équipe.
do $$ begin
  if to_regclass('public.inscriptions') is not null then
    drop policy if exists "lecture equipe" on public.inscriptions;
    create policy "lecture equipe" on public.inscriptions for select to authenticated
      using (public.my_role() in ('admin','gestionnaire'));
    drop policy if exists "modification equipe" on public.inscriptions;
    create policy "modification equipe" on public.inscriptions for update to authenticated
      using (public.my_role() in ('admin','gestionnaire')) with check (true);
  end if;
end $$;

-- 4. CATALOGUE, SUIVI DE FIN DE FORMATION ET ATTESTATIONS
alter table public.courses add column if not exists categorie text;
alter table public.courses add column if not exists niveau text;
alter table public.courses add column if not exists page text;      -- page du cours sur le site (ex. cours-word.html)
alter table public.courses add column if not exists ordre int default 100;

alter table public.enrollments add column if not exists date_activation timestamptz;
alter table public.enrollments add column if not exists date_fin timestamptz;
alter table public.enrollments add column if not exists mention text;      -- appréciation du formateur
alter table public.enrollments add column if not exists valide_par uuid references public.profiles(id) on delete set null;
alter table public.enrollments drop constraint if exists enrollments_statut_check;
alter table public.enrollments add constraint enrollments_statut_check
  check (statut in ('demande','actif','termine','refuse'));

-- Codes d'accès des pages de cours : visibles seulement par l'équipe
-- et par les apprenants dont l'accès est actif ou terminé
create table if not exists public.course_codes (
  course_id bigint primary key references public.courses(id) on delete cascade,
  codes text not null default ''          -- plusieurs codes séparés par des virgules
);
alter table public.course_codes enable row level security;
drop policy if exists "codes lecture" on public.course_codes;
create policy "codes lecture" on public.course_codes for select to authenticated
  using (public.my_role() in ('admin','responsable','gestionnaire')
         or exists (select 1 from public.enrollments e
                    where e.course_id = course_codes.course_id and e.user_id = auth.uid()
                      and e.statut in ('actif','termine')));
drop policy if exists "codes gestion" on public.course_codes;
create policy "codes gestion" on public.course_codes for all to authenticated
  using (public.my_role() in ('admin','responsable'))
  with check (public.my_role() in ('admin','responsable'));

-- Un apprenant peut annuler sa propre demande tant qu'elle n'est pas activée
drop policy if exists "acces annulation" on public.enrollments;
create policy "acces annulation" on public.enrollments for delete to authenticated
  using ((user_id = auth.uid() and statut = 'demande') or public.my_role() = 'admin');

-- Chacun peut corriger son nom et prénom (pour l'attestation), sans toucher à son rôle
create or replace function public.maj_mon_nom(p_nom text, p_prenom text) returns void
language sql security definer set search_path = public as $$
  update public.profiles set nom = p_nom, prenom = p_prenom where id = auth.uid()
$$;
grant execute on function public.maj_mon_nom(text, text) to authenticated;

-- Catalogue de départ (ajoute seulement les cours qui n'existent pas encore)
insert into public.courses (titre, description, prix, categorie, niveau, page, ordre, publie)
select v.* from (values
  ('Word', 'Écrire et mettre en forme des documents professionnels. 4 modules et 78 fiches d''exercices.', '10 000 FCFA / mois', 'Bureautique', 'Débutant', 'cours-word.html', 1, true),
  ('Excel', 'Calculer, analyser et présenter des données. 4 modules et 80 fiches d''exercices.', '10 000 FCFA / mois', 'Bureautique', 'Débutant à intermédiaire', 'cours-excel.html', 2, true),
  ('PowerPoint', 'Créer des présentations claires et convaincantes. 4 modules et 60 fiches d''exercices.', '10 000 FCFA / mois', 'Bureautique', 'Débutant', 'cours-powerpoint.html', 3, true),
  ('Windows', 'Utiliser et entretenir son ordinateur : fichiers, paramètres, sécurité, dépannage.', '10 000 FCFA / mois', 'Bureautique', 'Débutant', null, 4, true),
  ('KoboToolbox et KoboCollect', 'Concevoir, déployer et gérer une enquête de terrain, du formulaire à l''export des données.', 'Tarif sur demande', 'Collecte et analyse de données', 'Débutant à intermédiaire', 'cours-kobotoolbox.html', 10, true),
  ('SPSS', 'Analyser des données quantitatives et qualitatives, du nettoyage au rapport final.', 'Tarif sur demande', 'Collecte et analyse de données', 'Débutant à avancé', 'cours-spss.html', 11, true),
  ('XLSTAT', 'Les statistiques avancées dans Excel : tests, régressions, ACP, AFC, classification.', 'Tarif sur demande', 'Collecte et analyse de données', 'Intermédiaire', 'cours-xlstat.html', 12, true),
  ('QGIS', 'De l''installation au projet cartographique de mémoire ou de thèse (Master et Doctorat).', 'Tarif sur demande', 'Cartographie', 'Master et Doctorat', 'cours-qgis.html', 20, true),
  ('ArcGIS', 'Cartes et analyses spatiales : occupation du sol, analyse hydrologique, bases de données spatiales.', 'Analyse hydrologique : 30 000 FCFA', 'Cartographie', 'Débutant à intermédiaire', null, 21, true),
  ('IA responsable en rédaction scientifique', 'Utiliser l''IA sans tricher ni se tromper : formuler, vérifier, citer.', '20 000 FCFA', 'Recherche scientifique', 'Tous niveaux', null, 30, true),
  ('Zotero', 'Gérer ses références et produire une bibliographie automatique dans Word.', '15 000 FCFA', 'Recherche scientifique', 'Débutant', null, 31, true),
  ('Analyse bibliométrique (VOSviewer)', 'Cartographier la littérature scientifique avec VOSviewer.', '20 000 FCFA', 'Recherche scientifique', 'Intermédiaire', null, 32, true)
) as v(titre, description, prix, categorie, niveau, page, ordre, publie)
where not exists (select 1 from public.courses c where c.titre = v.titre);

-- 5. STATISTIQUES DE VISITES
create table if not exists public.visites (
  id bigint generated always as identity primary key,
  jour timestamptz not null default now(),
  page text,
  visiteur text,          -- identifiant anonyme tiré au hasard dans le navigateur
  provenance text
);
create index if not exists visites_jour_idx on public.visites (jour);
alter table public.visites enable row level security;
-- Tout visiteur peut enregistrer sa visite, personne ne peut lire la table directement
drop policy if exists "visite ajout" on public.visites;
create policy "visite ajout" on public.visites for insert to anon, authenticated
  with check (length(coalesce(page,'')) < 200 and length(coalesce(visiteur,'')) < 60 and length(coalesce(provenance,'')) < 300);

-- Chiffres pour l'espace formateur (réservé à l'équipe)
create or replace function public.stats_visites(p_jours int default 30) returns json
language plpgsql stable security definer set search_path = public as $$
declare r json; z text := 'Africa/Niamey'; n timestamptz := now();
begin
  if public.my_role() not in ('admin','gestionnaire','responsable') then
    raise exception 'Accès réservé à l''équipe';
  end if;
  select json_build_object(
    'jour',     (select json_build_object('v',count(*),'u',count(distinct visiteur)) from visites where jour >= date_trunc('day',  n at time zone z) at time zone z),
    'semaine',  (select json_build_object('v',count(*),'u',count(distinct visiteur)) from visites where jour >= date_trunc('week', n at time zone z) at time zone z),
    'mois',     (select json_build_object('v',count(*),'u',count(distinct visiteur)) from visites where jour >= date_trunc('month',n at time zone z) at time zone z),
    'annee',    (select json_build_object('v',count(*),'u',count(distinct visiteur)) from visites where jour >= date_trunc('year', n at time zone z) at time zone z),
    'total',    (select json_build_object('v',count(*),'u',count(distinct visiteur)) from visites),
    'par_jour', (select coalesce(json_agg(json_build_object('d',d,'v',v,'u',u) order by d),'[]') from (
                   select (jour at time zone z)::date d, count(*) v, count(distinct visiteur) u from visites
                   where jour >= n - make_interval(days => p_jours) group by 1) t),
    'par_mois', (select coalesce(json_agg(json_build_object('m',m,'v',v,'u',u) order by m),'[]') from (
                   select to_char(jour at time zone z,'YYYY-MM') m, count(*) v, count(distinct visiteur) u from visites
                   where jour >= n - interval '12 months' group by 1) t),
    'par_annee',(select coalesce(json_agg(json_build_object('a',a,'v',v,'u',u) order by a),'[]') from (
                   select to_char(jour at time zone z,'YYYY') a, count(*) v, count(distinct visiteur) u from visites group by 1) t),
    'pages',    (select coalesce(json_agg(json_build_object('p',page,'v',v) order by v desc),'[]') from (
                   select page, count(*) v from visites where jour >= n - interval '30 days' group by 1 order by 2 desc limit 10) t)
  ) into r;
  return r;
end $$;
grant execute on function public.stats_visites(int) to authenticated;

-- 6. VIDÉOS YOUTUBE ET RÉGLAGES DU SITE
create table if not exists public.videos (
  id bigint generated always as identity primary key,
  created_at timestamptz default now(),
  course_id bigint references public.courses(id) on delete cascade,   -- vide = vidéo générale
  titre text not null,
  url text not null,
  ordre int default 100
);
alter table public.videos enable row level security;
drop policy if exists "videos lecture" on public.videos;
create policy "videos lecture" on public.videos for select to anon, authenticated using (true);
drop policy if exists "videos gestion" on public.videos;
create policy "videos gestion" on public.videos for all to authenticated
  using (public.my_role() in ('admin','responsable')) with check (public.my_role() in ('admin','responsable'));

create table if not exists public.reglages (
  cle text primary key,
  valeur text
);
alter table public.reglages enable row level security;
drop policy if exists "reglages lecture" on public.reglages;
create policy "reglages lecture" on public.reglages for select to anon, authenticated using (true);
drop policy if exists "reglages gestion" on public.reglages;
create policy "reglages gestion" on public.reglages for all to authenticated
  using (public.my_role() = 'admin') with check (public.my_role() = 'admin');
insert into public.reglages (cle, valeur) values ('youtube', '') on conflict (cle) do nothing;

-- 7. VOTRE COMPTE ADMINISTRATEUR
-- Créez d'abord votre compte sur la page « Espace apprenant », puis remplacez
-- l'adresse ci-dessous par la vôtre et exécutez seulement cette ligne :
-- update public.profiles set role = 'admin' where email = 'votre.adresse@exemple.com';
