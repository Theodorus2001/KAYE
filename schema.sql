-- ============================================================
-- KAYE LMS - schema complet
-- PostgreSQL / Supabase
-- ============================================================
--
-- UTILISATION
--   Collez tout ce fichier dans le SQL Editor de Supabase,
--   cliquez sur Run. Resultat attendu : « Tables : 17 ».
--
--   Ce fichier contient TOUT : tables, securite, quiz,
--   invitations. Il n'y a aucun autre fichier a executer.
--
-- ATTENTION
--   Ce fichier EFFACE les donnees KAYE : cours, devoirs, copies,
--   notes, quiz, invitations. Les comptes de connexion sous
--   Authentication ne sont PAS supprimes.
--
--   Des qu'il y a de vraies notes d'eleves, arretez de relancer
--   ce fichier.
--
-- COMMENT ON ENTRE DANS KAYE
--   L'ecole depose la liste des personnes autorisees. Chacune
--   recoit un identifiant et un code d'activation, et choisit
--   son mot de passe. Sans invitation, aucun compte ne marche.
--   Le role vient de la liste de l'ecole, jamais du navigateur.
--
-- Lisez les NOTES DE SECURITE en bas avant d'y mettre de vraies
-- donnees d'eleves.
-- ============================================================


-- ============================================================
-- REMISE A ZERO
-- ============================================================

drop trigger if exists on_auth_user_created on auth.users;

drop policy if exists sub_files_own     on storage.objects;
drop policy if exists sub_files_teacher on storage.objects;
drop policy if exists brief_read        on storage.objects;
drop policy if exists brief_write       on storage.objects;

drop table if exists discussion_replies cascade;
drop table if exists discussions        cascade;
drop table if exists announcements      cascade;
drop table if exists messages           cascade;
drop table if exists quiz_attempts      cascade;
drop table if exists quiz_questions     cascade;
drop table if exists quizzes            cascade;
drop table if exists submissions        cascade;
drop table if exists assignments        cascade;
drop table if exists module_items       cascade;
drop table if exists modules            cascade;
drop table if exists attendance         cascade;
drop table if exists enrollments        cascade;
drop table if exists courses            cascade;
drop table if exists invitations        cascade;
drop table if exists profiles           cascade;
drop table if exists institutions       cascade;

drop function if exists handle_new_user()                cascade;
drop function if exists my_role()                        cascade;
drop function if exists my_institution()                 cascade;
drop function if exists teaches(uuid)                    cascade;
drop function if exists enrolled_in(uuid)                cascade;
drop function if exists make_claim_code()                cascade;
drop function if exists check_invitation(text, text)     cascade;
drop function if exists get_quiz_questions(uuid)         cascade;
drop function if exists quiz_question_count(uuid)        cascade;
drop function if exists submit_quiz_attempt(uuid, jsonb) cascade;

drop type if exists user_role         cascade;
drop type if exists item_kind         cascade;
drop type if exists submission_status cascade;
drop type if exists question_kind     cascade;


-- ============================================================
-- 1. ETABLISSEMENTS ET PERSONNES
-- ============================================================

create table institutions (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  code        text not null unique,
  grade_scale text not null default 'out_of_20',
  active_term text not null default 'Automne 2026',
  created_at  timestamptz not null default now()
);

create type user_role as enum ('student', 'teacher', 'admin');

create table profiles (
  id             uuid primary key references auth.users(id) on delete cascade,
  institution_id uuid not null references institutions(id) on delete restrict,
  role           user_role not null,
  full_name      text not null,
  student_number text,
  phone          text,
  lang           text not null default 'fr',
  is_active      boolean not null default true,
  created_at     timestamptz not null default now()
);

create index on profiles (institution_id);
create index on profiles (role);


-- L'ecole doit exister avant tout le reste.
insert into institutions (name, code)
values ('Saint-François-Xavier', 'SFXO');


-- ============================================================
-- 2. INVITATIONS : QUI A LE DROIT D'ENTRER
--
-- Rien ne remplace cette table. C'est elle qui decide qui peut
-- creer un compte et avec quel role.
-- ============================================================

create table invitations (
  id             uuid primary key default gen_random_uuid(),
  institution_id uuid not null references institutions(id) on delete cascade,
  email          text not null,
  full_name      text not null,
  role           user_role not null default 'student',
  student_number text,
  claim_code     text not null,
  used_at        timestamptz,
  used_by        uuid references auth.users(id) on delete set null,
  created_by     uuid references profiles(id) on delete set null,
  created_at     timestamptz not null default now()
);

create unique index invitations_email_uniq
  on invitations (institution_id, lower(email));

create index invitations_lookup on invitations (lower(email));


-- Code d'activation court. On evite les caracteres qu'on
-- confond a l'ecrit : 0 et O, 1 et I et L.
create function make_claim_code()
returns text
language plpgsql volatile
as $fn$
declare
  v_alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code     text := '';
  v_i        int;
begin
  for v_i in 1..6 loop
    v_code := v_code ||
      substr(v_alphabet, floor(random() * length(v_alphabet))::int + 1, 1);
  end loop;
  return v_code;
end;
$fn$;

alter table invitations
  alter column claim_code set default make_claim_code();


-- A l'inscription, le profil est cree A PARTIR DE L'INVITATION.
-- Tout ce que le navigateur envoie est ignore, sauf le code
-- d'activation, qui doit correspondre.
--
-- Cette fonction ne doit jamais lever d'erreur : elle tourne
-- dans la transaction qui cree le compte.
create function handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $fn$
declare
  v_inv  invitations%rowtype;
  v_code text;
begin
  v_code := upper(coalesce(nullif(new.raw_user_meta_data ->> 'claim_code', ''), ''));

  select * into v_inv
  from invitations
  where lower(email) = lower(new.email)
    and used_at is null
  limit 1;

  if not found then
    return new;                 -- pas invite : pas de profil
  end if;

  if v_inv.claim_code <> v_code then
    return new;                 -- mauvais code : pas de profil
  end if;

  insert into profiles (id, institution_id, role, full_name, student_number)
  values (new.id, v_inv.institution_id, v_inv.role, v_inv.full_name, v_inv.student_number)
  on conflict (id) do nothing;

  update invitations
     set used_at = now(), used_by = new.id
   where id = v_inv.id;

  return new;

exception when others then
  return new;
end;
$fn$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();


-- Verifier une invitation avant l'inscription, pour donner un
-- message clair sans exposer la liste.
create function check_invitation(p_email text, p_code text)
returns jsonb
language plpgsql stable security definer set search_path = public
as $fn$
declare
  v_inv invitations%rowtype;
begin
  select * into v_inv
  from invitations
  where lower(email) = lower(btrim(p_email))
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'inconnu');
  end if;

  if v_inv.used_at is not null then
    return jsonb_build_object('ok', false, 'reason', 'deja_utilise');
  end if;

  if v_inv.claim_code <> upper(btrim(p_code)) then
    return jsonb_build_object('ok', false, 'reason', 'code');
  end if;

  return jsonb_build_object('ok', true,
                            'full_name', v_inv.full_name,
                            'role', v_inv.role::text);
end;
$fn$;


-- ------------------------------------------------------------
-- Fonctions utilisees par les regles de securite.
--
-- SECURITY DEFINER : elles ignorent la securite au niveau des
-- lignes pendant leur execution. Sans cela, une regle sur
-- profiles qui doit lire profiles s'appellerait sans fin.
-- ------------------------------------------------------------

create function my_role()
returns user_role
language sql stable security definer set search_path = public
as $fn$ select role from profiles where id = auth.uid() $fn$;

create function my_institution()
returns uuid
language sql stable security definer set search_path = public
as $fn$ select institution_id from profiles where id = auth.uid() $fn$;


-- ============================================================
-- 3. COURS ET INSCRIPTIONS
-- ============================================================

create table courses (
  id             uuid primary key default gen_random_uuid(),
  institution_id uuid not null references institutions(id) on delete cascade,
  teacher_id     uuid references profiles(id) on delete set null,
  code           text not null,
  title          text not null,
  description    text,
  room           text,
  schedule       text,
  capacity       int  not null default 30,
  term           text not null default 'Automne 2026',
  colour         text not null default 'violet',
  is_archived    boolean not null default false,
  created_at     timestamptz not null default now(),
  unique (institution_id, code, term)
);

create index on courses (institution_id);
create index on courses (teacher_id);

create table enrollments (
  id          uuid primary key default gen_random_uuid(),
  course_id   uuid not null references courses(id) on delete cascade,
  student_id  uuid not null references profiles(id) on delete cascade,
  is_active   boolean not null default true,
  enrolled_at timestamptz not null default now(),
  unique (course_id, student_id)
);

create index on enrollments (student_id);
create index on enrollments (course_id);

create table attendance (
  id         uuid primary key default gen_random_uuid(),
  course_id  uuid not null references courses(id) on delete cascade,
  student_id uuid not null references profiles(id) on delete cascade,
  on_date    date not null,
  status     text not null default 'present',
  unique (course_id, student_id, on_date)
);


create function teaches(course uuid)
returns boolean
language sql stable security definer set search_path = public
as $fn$ select exists (
  select 1 from courses c
  where c.id = course and c.teacher_id = auth.uid()
) $fn$;

create function enrolled_in(course uuid)
returns boolean
language sql stable security definer set search_path = public
as $fn$ select exists (
  select 1 from enrollments e
  where e.course_id = course and e.student_id = auth.uid() and e.is_active
) $fn$;


-- ============================================================
-- 4. CONTENU DES COURS
-- ============================================================

create table modules (
  id           uuid primary key default gen_random_uuid(),
  course_id    uuid not null references courses(id) on delete cascade,
  title        text not null,
  weeks_label  text,
  position     int  not null default 0,
  is_published boolean not null default false,
  created_at   timestamptz not null default now()
);

create index on modules (course_id);

create type item_kind as enum ('page', 'video', 'quiz', 'assignment', 'file');

create table module_items (
  id        uuid primary key default gen_random_uuid(),
  module_id uuid not null references modules(id) on delete cascade,
  kind      item_kind not null,
  title     text not null,
  body      text,
  url       text,
  duration  text,
  ref_id    uuid,
  position  int not null default 0
);

create index on module_items (module_id);


-- ============================================================
-- 5. DEVOIRS ET COPIES
-- ============================================================

create table assignments (
  id           uuid primary key default gen_random_uuid(),
  course_id    uuid not null references courses(id) on delete cascade,
  title        text not null,
  instructions text,
  brief_path   text,
  points       int  not null default 20,
  due_at       timestamptz,
  allow_late   boolean not null default true,
  is_published boolean not null default false,
  rubric       jsonb not null default '[]',
  created_at   timestamptz not null default now()
);

create index on assignments (course_id);
create index on assignments (due_at);

create type submission_status as enum ('draft', 'submitted', 'graded', 'returned');

create table submissions (
  id            uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references assignments(id) on delete cascade,
  student_id    uuid not null references profiles(id) on delete cascade,
  status        submission_status not null default 'draft',
  file_path     text,
  text_entry    text,
  submitted_at  timestamptz,
  is_late       boolean not null default false,

  score         numeric(5,2),
  rubric_scores jsonb,
  feedback      text,
  graded_by     uuid references profiles(id) on delete set null,
  graded_at     timestamptz,

  updated_at    timestamptz not null default now(),
  unique (assignment_id, student_id)
);

create index on submissions (student_id);
create index on submissions (assignment_id);
create index on submissions (status);


-- ============================================================
-- 6. QUIZ
-- ============================================================

create table quizzes (
  id               uuid primary key default gen_random_uuid(),
  course_id        uuid not null references courses(id) on delete cascade,
  title            text not null,
  points           int  not null default 10,
  time_limit_min   int,
  attempts_allowed int  not null default 3,
  randomise        boolean not null default false,
  questions_to_ask int,
  is_published     boolean not null default false,
  created_at       timestamptz not null default now()
);

create index on quizzes (course_id);

create type question_kind as enum ('numeric', 'multiple_choice', 'true_false', 'short_answer');

-- Les bonnes reponses sont ici. Les eleves ne lisent jamais
-- cette table : ils passent par get_quiz_questions().
create table quiz_questions (
  id             uuid primary key default gen_random_uuid(),
  quiz_id        uuid not null references quizzes(id) on delete cascade,
  kind           question_kind not null,
  prompt         text not null,
  choices        jsonb,
  correct_answer text not null,
  position       int not null default 0
);

create index on quiz_questions (quiz_id);

create table quiz_attempts (
  id           uuid primary key default gen_random_uuid(),
  quiz_id      uuid not null references quizzes(id) on delete cascade,
  student_id   uuid not null references profiles(id) on delete cascade,
  attempt_no   int  not null,
  answers      jsonb not null default '{}',
  score        numeric(5,2),
  max_score    numeric(5,2),
  started_at   timestamptz not null default now(),
  submitted_at timestamptz,
  unique (quiz_id, student_id, attempt_no)
);

create index on quiz_attempts (student_id);


-- ============================================================
-- 7. COMMUNICATION
-- ============================================================

create table messages (
  id           uuid primary key default gen_random_uuid(),
  course_id    uuid references courses(id) on delete set null,
  sender_id    uuid not null references profiles(id) on delete cascade,
  recipient_id uuid not null references profiles(id) on delete cascade,
  body         text not null,
  read_at      timestamptz,
  sent_at      timestamptz not null default now()
);

create index on messages (recipient_id, read_at);
create index on messages (sender_id);

create table announcements (
  id             uuid primary key default gen_random_uuid(),
  institution_id uuid not null references institutions(id) on delete cascade,
  course_id      uuid references courses(id) on delete cascade,
  author_id      uuid references profiles(id) on delete set null,
  title          text not null,
  body           text not null,
  published_at   timestamptz not null default now()
);

create index on announcements (institution_id, published_at desc);

create table discussions (
  id         uuid primary key default gen_random_uuid(),
  course_id  uuid not null references courses(id) on delete cascade,
  author_id  uuid references profiles(id) on delete set null,
  title      text not null,
  body       text not null,
  created_at timestamptz not null default now()
);

create table discussion_replies (
  id            uuid primary key default gen_random_uuid(),
  discussion_id uuid not null references discussions(id) on delete cascade,
  author_id     uuid references profiles(id) on delete set null,
  body          text not null,
  created_at    timestamptz not null default now()
);

create index on discussion_replies (discussion_id);


-- ============================================================
-- 8. FONCTIONS QUIZ
--
-- Les bonnes reponses ne quittent jamais le serveur.
-- ============================================================

-- Les questions, SANS les reponses.
-- La colonne s'appelle sort_order : « position » est un mot
-- reserve de PostgreSQL et ne peut pas nommer une sortie.
create function get_quiz_questions(p_quiz uuid)
returns table (
  id         uuid,
  kind       question_kind,
  prompt     text,
  choices    jsonb,
  sort_order int
)
language plpgsql stable security definer set search_path = public
as $fn$
declare
  v_course uuid;
  v_pub    boolean;
begin
  select q.course_id, q.is_published
    into v_course, v_pub
  from quizzes q
  where q.id = p_quiz;

  if v_course is null then
    raise exception 'Quiz introuvable';
  end if;

  if not (teaches(v_course) or (enrolled_in(v_course) and v_pub)) then
    raise exception 'Acces refuse';
  end if;

  return query
    select qq.id, qq.kind, qq.prompt, qq.choices, qq.position
    from quiz_questions qq
    where qq.quiz_id = p_quiz
    order by qq.position;
end;
$fn$;


create function quiz_question_count(p_quiz uuid)
returns int
language sql stable security definer set search_path = public
as $fn$ select count(*)::int from quiz_questions where quiz_id = p_quiz $fn$;


-- Corrige une tentative. La bonne reponse n'est revelee qu'a la
-- derniere tentative autorisee.
create function submit_quiz_attempt(p_quiz uuid, p_answers jsonb)
returns jsonb
language plpgsql security definer set search_path = public
as $fn$
declare
  v_quiz    quizzes%rowtype;
  v_used    int;
  v_correct int := 0;
  v_total   int := 0;
  v_results jsonb := '[]'::jsonb;
  v_q       record;
  v_given   text;
  v_ok      boolean;
begin
  select * into v_quiz from quizzes where id = p_quiz;
  if not found then
    raise exception 'Quiz introuvable';
  end if;

  if not enrolled_in(v_quiz.course_id) then
    raise exception 'Vous n''etes pas inscrit a ce cours';
  end if;

  select count(*) into v_used
  from quiz_attempts
  where quiz_id = p_quiz and student_id = auth.uid();

  if v_used >= v_quiz.attempts_allowed then
    raise exception 'Nombre maximal de tentatives atteint';
  end if;

  for v_q in
    select * from quiz_questions where quiz_id = p_quiz order by position
  loop
    v_total := v_total + 1;
    v_given := p_answers ->> v_q.id::text;
    v_ok := (v_given is not null
             and lower(btrim(v_given)) = lower(btrim(v_q.correct_answer)));
    if v_ok then
      v_correct := v_correct + 1;
    end if;
    v_results := v_results || jsonb_build_object(
      'question_id', v_q.id,
      'correct', v_ok,
      'correct_answer', case when v_used + 1 >= v_quiz.attempts_allowed
                             then v_q.correct_answer else null end
    );
  end loop;

  insert into quiz_attempts (quiz_id, student_id, attempt_no, answers,
                             score, max_score, submitted_at)
  values (p_quiz, auth.uid(), v_used + 1, p_answers,
          v_correct, v_total, now());

  return jsonb_build_object(
    'score', v_correct,
    'total', v_total,
    'attempts_used', v_used + 1,
    'attempts_allowed', v_quiz.attempts_allowed,
    'results', v_results
  );
end;
$fn$;


-- ============================================================
-- 9. SECURITE AU NIVEAU DES LIGNES
--
-- C'est ce qui protege reellement les donnees des eleves.
-- KAYE tourne dans le navigateur, ou n'importe qui peut lire le
-- code et changer ce qu'il demande. Ces regles font que la base
-- refuse elle-meme les lignes interdites.
--
-- Rien de tout cela n'est optionnel.
-- ============================================================

alter table institutions       enable row level security;
alter table profiles           enable row level security;
alter table invitations        enable row level security;
alter table courses            enable row level security;
alter table enrollments        enable row level security;
alter table attendance         enable row level security;
alter table modules            enable row level security;
alter table module_items       enable row level security;
alter table assignments        enable row level security;
alter table submissions        enable row level security;
alter table quizzes            enable row level security;
alter table quiz_questions     enable row level security;
alter table quiz_attempts      enable row level security;
alter table messages           enable row level security;
alter table announcements      enable row level security;
alter table discussions        enable row level security;
alter table discussion_replies enable row level security;


-- Etablissement
create policy inst_read on institutions for select
  using (id = my_institution());
create policy inst_write on institutions for all
  using (id = my_institution() and my_role() = 'admin')
  with check (id = my_institution() and my_role() = 'admin');


-- Profils
create policy prof_read_self on profiles for select
  using (id = auth.uid());
create policy prof_read_staff on profiles for select
  using (institution_id = my_institution() and my_role() in ('teacher','admin'));
create policy prof_update_self on profiles for update
  using (id = auth.uid())
  with check (id = auth.uid() and role = my_role());
create policy prof_admin_all on profiles for all
  using (institution_id = my_institution() and my_role() = 'admin')
  with check (institution_id = my_institution() and my_role() = 'admin');


-- Invitations : le personnel gere, personne d'autre ne lit.
create policy inv_admin on invitations for all
  using (institution_id = my_institution() and my_role() = 'admin')
  with check (institution_id = my_institution() and my_role() = 'admin');
create policy inv_teacher_read on invitations for select
  using (institution_id = my_institution() and my_role() = 'teacher');
create policy inv_teacher_add on invitations for insert
  with check (institution_id = my_institution()
              and my_role() = 'teacher'
              and role = 'student');
create policy inv_teacher_del on invitations for delete
  using (institution_id = my_institution()
         and my_role() = 'teacher'
         and role = 'student'
         and used_at is null);


-- Cours
create policy course_read on courses for select
  using (
    institution_id = my_institution() and (
      my_role() = 'admin' or teacher_id = auth.uid() or enrolled_in(id)
    )
  );
create policy course_insert on courses for insert
  with check (
    institution_id = my_institution()
    and (my_role() = 'admin'
         or (my_role() = 'teacher' and teacher_id = auth.uid()))
  );
create policy course_teacher_update on courses for update
  using (teacher_id = auth.uid())
  with check (teacher_id = auth.uid());
create policy course_teacher_delete on courses for delete
  using (teacher_id = auth.uid());
create policy course_admin_all on courses for all
  using (institution_id = my_institution() and my_role() = 'admin')
  with check (institution_id = my_institution() and my_role() = 'admin');


-- Inscriptions
create policy enrol_read on enrollments for select
  using (student_id = auth.uid() or teaches(course_id) or my_role() = 'admin');
create policy enrol_teacher on enrollments for all
  using (teaches(course_id)) with check (teaches(course_id));
create policy enrol_admin on enrollments for all
  using (my_role() = 'admin') with check (my_role() = 'admin');


-- Presence
create policy attend_read on attendance for select
  using (student_id = auth.uid() or teaches(course_id) or my_role() = 'admin');
create policy attend_write on attendance for all
  using (teaches(course_id) or my_role() = 'admin')
  with check (teaches(course_id) or my_role() = 'admin');


-- Modules
create policy mod_read on modules for select
  using (
    teaches(course_id) or my_role() = 'admin'
    or (enrolled_in(course_id) and is_published)
  );
create policy mod_write on modules for all
  using (teaches(course_id)) with check (teaches(course_id));

create policy item_read on module_items for select
  using (exists (
    select 1 from modules m where m.id = module_id and (
      teaches(m.course_id) or my_role() = 'admin'
      or (enrolled_in(m.course_id) and m.is_published)
    )
  ));
create policy item_write on module_items for all
  using (exists (select 1 from modules m
                 where m.id = module_id and teaches(m.course_id)))
  with check (exists (select 1 from modules m
                      where m.id = module_id and teaches(m.course_id)));


-- Devoirs
create policy asg_read on assignments for select
  using (
    teaches(course_id) or my_role() = 'admin'
    or (enrolled_in(course_id) and is_published)
  );
create policy asg_write on assignments for all
  using (teaches(course_id)) with check (teaches(course_id));


-- Copies
create policy sub_read_own on submissions for select
  using (student_id = auth.uid());
create policy sub_read_teacher on submissions for select
  using (exists (select 1 from assignments a
                 where a.id = assignment_id and teaches(a.course_id)));
create policy sub_insert_own on submissions for insert
  with check (
    student_id = auth.uid()
    and exists (select 1 from assignments a
                where a.id = assignment_id and enrolled_in(a.course_id))
  );
create policy sub_update_own on submissions for update
  using (student_id = auth.uid() and status in ('draft','submitted'))
  with check (student_id = auth.uid() and status in ('draft','submitted'));
create policy sub_update_teacher on submissions for update
  using (exists (select 1 from assignments a
                 where a.id = assignment_id and teaches(a.course_id)))
  with check (exists (select 1 from assignments a
                      where a.id = assignment_id and teaches(a.course_id)));


-- Quiz
create policy quiz_read on quizzes for select
  using (
    teaches(course_id) or my_role() = 'admin'
    or (enrolled_in(course_id) and is_published)
  );
create policy quiz_write on quizzes for all
  using (teaches(course_id)) with check (teaches(course_id));

create policy qq_teacher_only on quiz_questions for all
  using (exists (select 1 from quizzes q
                 where q.id = quiz_id and teaches(q.course_id)))
  with check (exists (select 1 from quizzes q
                      where q.id = quiz_id and teaches(q.course_id)));

create policy qa_read on quiz_attempts for select
  using (student_id = auth.uid()
         or exists (select 1 from quizzes q
                    where q.id = quiz_id and teaches(q.course_id)));
create policy qa_insert_own on quiz_attempts for insert
  with check (student_id = auth.uid()
              and exists (select 1 from quizzes q
                          where q.id = quiz_id and enrolled_in(q.course_id)));


-- Messages
create policy msg_read on messages for select
  using (sender_id = auth.uid() or recipient_id = auth.uid());
create policy msg_send on messages for insert
  with check (sender_id = auth.uid());
create policy msg_mark_read on messages for update
  using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());


-- Annonces
create policy ann_read on announcements for select
  using (
    institution_id = my_institution()
    and (course_id is null or enrolled_in(course_id)
         or teaches(course_id) or my_role() = 'admin')
  );
create policy ann_write on announcements for all
  using (my_role() in ('teacher','admin') and institution_id = my_institution())
  with check (my_role() in ('teacher','admin') and institution_id = my_institution());


-- Forums
create policy disc_read on discussions for select
  using (enrolled_in(course_id) or teaches(course_id) or my_role() = 'admin');
create policy disc_write on discussions for insert
  with check (author_id = auth.uid()
              and (enrolled_in(course_id) or teaches(course_id)));

create policy reply_read on discussion_replies for select
  using (exists (select 1 from discussions d
                 where d.id = discussion_id
                   and (enrolled_in(d.course_id) or teaches(d.course_id)
                        or my_role() = 'admin')));
create policy reply_write on discussion_replies for insert
  with check (author_id = auth.uid()
              and exists (select 1 from discussions d
                          where d.id = discussion_id
                            and (enrolled_in(d.course_id) or teaches(d.course_id))));


-- ============================================================
-- 10. DROITS D'EXECUTION DES FONCTIONS
-- ============================================================

grant execute on function check_invitation(text, text)      to anon, authenticated;
grant execute on function get_quiz_questions(uuid)          to authenticated;
grant execute on function quiz_question_count(uuid)         to authenticated;
grant execute on function submit_quiz_attempt(uuid, jsonb)  to authenticated;


-- ============================================================
-- 11. STOCKAGE DES FICHIERS
--
-- Apres ce fichier, creez deux buckets dans Storage, tous deux
-- PRIVES :
--
--   submissions   les copies des eleves
--   briefs        les enonces des enseignants
--
-- Forme des chemins :
--   submissions/<course_id>/<assignment_id>/<student_id>/<fichier>
--   briefs/<course_id>/<assignment_id>/<fichier>
-- ============================================================

create policy sub_files_own on storage.objects for all
  using (
    bucket_id = 'submissions'
    and (storage.foldername(name))[3] = auth.uid()::text
  )
  with check (
    bucket_id = 'submissions'
    and (storage.foldername(name))[3] = auth.uid()::text
  );

create policy sub_files_teacher on storage.objects for select
  using (
    bucket_id = 'submissions'
    and teaches(((storage.foldername(name))[1])::uuid)
  );

create policy brief_read on storage.objects for select
  using (
    bucket_id = 'briefs'
    and (enrolled_in(((storage.foldername(name))[1])::uuid)
         or teaches(((storage.foldername(name))[1])::uuid))
  );

create policy brief_write on storage.objects for all
  using (bucket_id = 'briefs'
         and teaches(((storage.foldername(name))[1])::uuid))
  with check (bucket_id = 'briefs'
              and teaches(((storage.foldername(name))[1])::uuid));


-- ============================================================
-- 12. PREMIERE PERSONNE : L'ADMINISTRATEUR
--
-- Quelqu'un doit pouvoir entrer en premier pour inviter les
-- autres. Remplacez l'email ci-dessous par le votre, puis
-- activez le compte dans KAYE avec le code affiche a la fin.
-- ============================================================

insert into invitations (institution_id, email, full_name, role)
select id, 'direction@sfxo.edu.ht', 'Direction SFXO', 'admin'
from institutions where code = 'SFXO';


-- ============================================================
-- 13. VERIFICATION
-- ============================================================

select 'Tables : ' || count(*)::text as resultat
from information_schema.tables
where table_schema = 'public';
-- Attendu : 17

select email as identifiant_admin,
       claim_code as code_activation,
       'Ouvrez KAYE, cliquez Activer mon compte' as etape_suivante
from invitations
where role = 'admin' and used_at is null;


-- ============================================================
-- ET APRES
--
-- 1. Storage : creer les buckets prives « submissions » et « briefs ».
--
-- 2. Authentication puis Providers puis Email : desactiver
--    « Confirm email » si vos eleves n'ont pas de vraie adresse.
--
-- 3. Ouvrir KAYE, cliquer « Activer mon compte », entrer
--    l'identifiant et le code affiches ci-dessus, choisir un
--    mot de passe.
--
-- 4. Une fois entre comme administrateur, aller dans Personnes
--    pour inviter les enseignants et les eleves. Chacun recoit
--    un code a imprimer.
--
-- 5. Les cours se creent dans l'application, par l'enseignant.
-- ============================================================


-- ============================================================
-- NOTES DE SECURITE
-- ============================================================
--
-- 1. Dans le navigateur, utilisez la cle anon, jamais
--    service_role. service_role ignore toutes les regles
--    ci-dessus.
--
-- 2. Le role vient toujours de la table invitations, jamais du
--    navigateur. handle_new_user() ignore ce que la page envoie.
--
-- 3. quiz_questions reste reserve aux enseignants. Si un eleve
--    peut lire cette table, il lit les reponses.
--
-- 4. Testez : connectez-vous comme un eleve et essayez
--    d'atteindre la copie d'un autre eleve. Si quelque chose
--    revient, corrigez avant d'aller plus loin.
--
-- 5. Activez Point in Time Recovery en passant au plan payant.
--    Le plan gratuit n'a aucune sauvegarde automatique.
--
-- 6. Demandez le consentement des familles avant de stocker des
--    donnees concernant des mineurs.
-- ============================================================
