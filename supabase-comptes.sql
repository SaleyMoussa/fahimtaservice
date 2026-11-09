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
  statut text not null default 'demande' check (statut in ('demande','actif')),
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
                    where e.course_id = lessons.course_id and e.user_id = auth.uid() and e.statut = 'actif'));
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

-- 4. VOTRE COMPTE ADMINISTRATEUR
-- Créez d'abord votre compte sur la page « Espace apprenant », puis remplacez
-- l'adresse ci-dessous par la vôtre et exécutez seulement cette ligne :
-- update public.profiles set role = 'admin' where email = 'votre.adresse@exemple.com';
