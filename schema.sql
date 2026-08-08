-- ============================================================
-- KAYE LMS - Database schema for Supabase (PostgreSQL)
-- ============================================================
--
-- HOW TO USE
--   Paste the whole file into the Supabase SQL Editor and Run.
--   "Success. No rows returned" is the correct result.
--
--   You can run this file as many times as you like. It clears
--   the old KAYE tables first, so it never fails with
--   "relation already exists".
--
-- WARNING
--   Running this DELETES all KAYE data: courses, grades,
--   submissions, messages. It does NOT delete the login accounts
--   under Authentication, those are safe.
--
--   Once real student data is in here, stop re-running this file
--   and make changes with ALTER TABLE instead.
--
-- Read the SECURITY NOTES at the bottom before storing anything real.
-- ============================================================


-- ============================================================
-- CLEAN SLATE
-- ============================================================

drop trigger if exists on_auth_user_created on auth.users;

drop policy if exists sub_files_own      on storage.objects;
drop policy if exists sub_files_teacher  on storage.objects;
drop policy if exists brief_read         on storage.objects;
drop policy if exists brief_write        on storage.objects;

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
drop table if exists profiles           cascade;
drop table if exists institutions       cascade;

drop function if exists handle_new_user()      cascade;
drop function if exists my_role()              cascade;
drop function if exists my_institution()       cascade;
drop function if exists teaches(uuid)          cascade;
drop function if exists enrolled_in(uuid)      cascade;
drop function if exists submit_quiz_attempt(uuid, jsonb) cascade;

drop type if exists user_role         cascade;
drop type if exists item_kind         cascade;
drop type if exists submission_status cascade;
drop type if exists question_kind     cascade;


-- ============================================================
-- STAGE 1: institutions, people and roles
-- ============================================================

create table institutions (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  code        text not null unique,          -- e.g. 'SFXO'
  grade_scale text not null default 'out_of_20',
  active_term text not null default 'Automne 2026',
  created_at  timestamptz not null default now()
);

create type user_role as enum ('student', 'teacher', 'admin');

-- profiles extends Supabase's built in auth.users table.
-- auth.users holds email and password; profiles holds everything
-- KAYE needs to know about the person.
create table profiles (
  id             uuid primary key references auth.users(id) on delete cascade,
  institution_id uuid not null references institutions(id) on delete restrict,
  role           user_role not null,
  full_name      text not null,
  student_number text,                        -- 'SFXO-2026-09', null for staff
  phone          text,                        -- for SMS notifications
  lang           text not null default 'fr',  -- 'fr' or 'ht'
  is_active      boolean not null default true,
  created_at     timestamptz not null default now()
);

create index on profiles (institution_id);
create index on profiles (role);


-- The school has to exist before the trigger below can fall back to it.
insert into institutions (name, code)
values ('Saint-François-Xavier', 'SFXO');


-- When someone signs up, create their profile row automatically.
--
-- This function must never raise an error. It runs inside the same
-- transaction that creates the account, so if it fails, creating the
-- account fails with it. That includes adding users by hand in the
-- Supabase dashboard, where there is no metadata at all, so every
-- value needs a fallback.
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_inst uuid;
begin
  v_inst := coalesce(
    nullif(new.raw_user_meta_data ->> 'institution_id', '')::uuid,
    (select id from institutions order by created_at limit 1)
  );

  if v_inst is null then
    return new;              -- no school yet, skip the profile
  end if;

  insert into profiles (id, institution_id, role, full_name)
  values (
    new.id,
    v_inst,
    coalesce(nullif(new.raw_user_meta_data ->> 'role','')::user_role, 'student'),
    coalesce(nullif(new.raw_user_meta_data ->> 'full_name',''), new.email)
  )
  on conflict (id) do nothing;

  return new;

exception when others then
  return new;                -- never block signup over a profile problem
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();


-- Any accounts that already exist under Authentication get a profile
-- now, so re-running this file does not orphan them.
insert into profiles (id, institution_id, role, full_name)
select u.id,
       (select id from institutions order by created_at limit 1),
       'student',
       coalesce(u.raw_user_meta_data ->> 'full_name', u.email)
from auth.users u
on conflict (id) do nothing;


-- ------------------------------------------------------------
-- Helper functions used by the security policies.
--
-- SECURITY DEFINER means they ignore row level security while they
-- run. That is necessary: without it, a policy on profiles that
-- needs to read profiles would call itself forever.
-- ------------------------------------------------------------

create or replace function my_role()
returns user_role
language sql stable security definer set search_path = public
as $$ select role from profiles where id = auth.uid() $$;

create or replace function my_institution()
returns uuid
language sql stable security definer set search_path = public
as $$ select institution_id from profiles where id = auth.uid() $$;

-- teaches() and enrolled_in() come at the end of STAGE 2, because
-- Postgres checks a function body when the function is created and
-- they need the courses and enrollments tables to exist first.


-- ============================================================
-- STAGE 2: courses and enrollment
-- ============================================================

create table courses (
  id             uuid primary key default gen_random_uuid(),
  institution_id uuid not null references institutions(id) on delete cascade,
  teacher_id     uuid references profiles(id) on delete set null,
  code           text not null,               -- 'MATH-102'
  title          text not null,
  description    text,
  room           text,
  schedule       text,                        -- 'Lun · Mer · Ven — 08h00'
  capacity       int  not null default 30,
  term           text not null default 'Automne 2026',
  colour         text not null default 'violet',  -- 'violet' or 'orange'
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

-- Attendance, used for the at risk flag on the teacher dashboard.
create table attendance (
  id         uuid primary key default gen_random_uuid(),
  course_id  uuid not null references courses(id) on delete cascade,
  student_id uuid not null references profiles(id) on delete cascade,
  on_date    date not null,
  status     text not null default 'present',  -- present | absent | late | excused
  unique (course_id, student_id, on_date)
);


create or replace function teaches(course uuid)
returns boolean
language sql stable security definer set search_path = public
as $$ select exists (
  select 1 from courses c where c.id = course and c.teacher_id = auth.uid()
) $$;

create or replace function enrolled_in(course uuid)
returns boolean
language sql stable security definer set search_path = public
as $$ select exists (
  select 1 from enrollments e
  where e.course_id = course and e.student_id = auth.uid() and e.is_active
) $$;


-- ============================================================
-- STAGE 2b: course content
-- ============================================================

create table modules (
  id           uuid primary key default gen_random_uuid(),
  course_id    uuid not null references courses(id) on delete cascade,
  title        text not null,
  weeks_label  text,                           -- 'Semaines 1 à 4'
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
  body      text,          -- page content
  url       text,          -- video or external link
  duration  text,          -- '6 min'
  ref_id    uuid,          -- points at assignments.id or quizzes.id
  position  int not null default 0
);

create index on module_items (module_id);


-- ============================================================
-- STAGE 3: assignments and submissions
-- ============================================================

create table assignments (
  id           uuid primary key default gen_random_uuid(),
  course_id    uuid not null references courses(id) on delete cascade,
  title        text not null,
  instructions text,
  brief_path   text,                            -- file in the 'briefs' bucket
  points       int  not null default 20,
  due_at       timestamptz,
  allow_late   boolean not null default true,
  is_published boolean not null default false,
  rubric       jsonb not null default '[]',     -- [{"criterion":"...","max":8}]
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
  file_path     text,        -- file in the private 'submissions' bucket
  text_entry    text,        -- typed answer, alternative to a file
  submitted_at  timestamptz,
  is_late       boolean not null default false,

  score         numeric(5,2),
  rubric_scores jsonb,       -- [{"criterion":"...","score":7,"max":8}]
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
-- STAGE 5a: quizzes
-- ============================================================

create table quizzes (
  id               uuid primary key default gen_random_uuid(),
  course_id        uuid not null references courses(id) on delete cascade,
  title            text not null,
  points           int  not null default 5,
  time_limit_min   int,
  attempts_allowed int  not null default 3,
  randomise        boolean not null default false,
  questions_to_ask int,
  is_published     boolean not null default false,
  created_at       timestamptz not null default now()
);

create index on quizzes (course_id);

create type question_kind as enum ('numeric', 'multiple_choice', 'true_false', 'short_answer');

-- Correct answers live here. Students must never read this table.
create table quiz_questions (
  id             uuid primary key default gen_random_uuid(),
  quiz_id        uuid not null references quizzes(id) on delete cascade,
  kind           question_kind not null,
  prompt         text not null,
  choices        jsonb,        -- ["2x", "2x²", "x"]
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
-- STAGE 5b: communication
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
  course_id      uuid references courses(id) on delete cascade,  -- null = whole school
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
-- ROW LEVEL SECURITY
--
-- This is what actually protects student data. The KAYE front end
-- runs in the browser, where anyone can read the code and change
-- what it asks for. These policies mean the database itself refuses
-- to hand over rows the signed in person is not entitled to.
--
-- None of this is optional.
-- ============================================================

alter table institutions        enable row level security;
alter table profiles            enable row level security;
alter table courses             enable row level security;
alter table enrollments         enable row level security;
alter table attendance          enable row level security;
alter table modules             enable row level security;
alter table module_items        enable row level security;
alter table assignments         enable row level security;
alter table submissions         enable row level security;
alter table quizzes             enable row level security;
alter table quiz_questions      enable row level security;
alter table quiz_attempts       enable row level security;
alter table messages            enable row level security;
alter table announcements       enable row level security;
alter table discussions         enable row level security;
alter table discussion_replies  enable row level security;


create policy inst_read on institutions for select
  using (id = my_institution());
create policy inst_write on institutions for all
  using (id = my_institution() and my_role() = 'admin')
  with check (id = my_institution() and my_role() = 'admin');


create policy prof_read_self on profiles for select
  using (id = auth.uid());
create policy prof_read_staff on profiles for select
  using (institution_id = my_institution() and my_role() in ('teacher','admin'));
create policy prof_update_self on profiles for update
  using (id = auth.uid())
  with check (id = auth.uid() and role = my_role());   -- cannot promote yourself
create policy prof_admin_all on profiles for all
  using (institution_id = my_institution() and my_role() = 'admin')
  with check (institution_id = my_institution() and my_role() = 'admin');


create policy course_read on courses for select
  using (
    institution_id = my_institution() and (
      my_role() = 'admin' or teacher_id = auth.uid() or enrolled_in(id)
    )
  );
create policy course_teacher_update on courses for update
  using (teacher_id = auth.uid())
  with check (teacher_id = auth.uid());
create policy course_admin_all on courses for all
  using (institution_id = my_institution() and my_role() = 'admin')
  with check (institution_id = my_institution() and my_role() = 'admin');


create policy enrol_read on enrollments for select
  using (student_id = auth.uid() or teaches(course_id) or my_role() = 'admin');
create policy enrol_admin on enrollments for all
  using (my_role() = 'admin') with check (my_role() = 'admin');


create policy attend_read on attendance for select
  using (student_id = auth.uid() or teaches(course_id) or my_role() = 'admin');
create policy attend_write on attendance for all
  using (teaches(course_id) or my_role() = 'admin')
  with check (teaches(course_id) or my_role() = 'admin');


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
  using (exists (select 1 from modules m where m.id = module_id and teaches(m.course_id)))
  with check (exists (select 1 from modules m where m.id = module_id and teaches(m.course_id)));


create policy asg_read on assignments for select
  using (
    teaches(course_id) or my_role() = 'admin'
    or (enrolled_in(course_id) and is_published)
  );
create policy asg_write on assignments for all
  using (teaches(course_id)) with check (teaches(course_id));


create policy sub_read_own on submissions for select
  using (student_id = auth.uid());
create policy sub_read_teacher on submissions for select
  using (exists (
    select 1 from assignments a where a.id = assignment_id and teaches(a.course_id)
  ));
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


create policy quiz_read on quizzes for select
  using (
    teaches(course_id) or my_role() = 'admin'
    or (enrolled_in(course_id) and is_published)
  );
create policy quiz_write on quizzes for all
  using (teaches(course_id)) with check (teaches(course_id));

-- quiz_questions holds the correct answers, so only teachers may read it.
-- Marking happens in submit_quiz_attempt() below, which checks answers
-- without revealing them.
create policy qq_teacher_only on quiz_questions for all
  using (exists (select 1 from quizzes q where q.id = quiz_id and teaches(q.course_id)))
  with check (exists (select 1 from quizzes q where q.id = quiz_id and teaches(q.course_id)));

create policy qa_read on quiz_attempts for select
  using (student_id = auth.uid()
         or exists (select 1 from quizzes q where q.id = quiz_id and teaches(q.course_id)));
create policy qa_insert_own on quiz_attempts for insert
  with check (student_id = auth.uid()
              and exists (select 1 from quizzes q
                          where q.id = quiz_id and enrolled_in(q.course_id)));


create policy msg_read on messages for select
  using (sender_id = auth.uid() or recipient_id = auth.uid());
create policy msg_send on messages for insert
  with check (sender_id = auth.uid());
create policy msg_mark_read on messages for update
  using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());


create policy ann_read on announcements for select
  using (
    institution_id = my_institution()
    and (course_id is null or enrolled_in(course_id) or teaches(course_id) or my_role() = 'admin')
  );
create policy ann_write on announcements for all
  using (my_role() in ('teacher','admin') and institution_id = my_institution())
  with check (my_role() in ('teacher','admin') and institution_id = my_institution());


create policy disc_read on discussions for select
  using (enrolled_in(course_id) or teaches(course_id) or my_role() = 'admin');
create policy disc_write on discussions for insert
  with check (author_id = auth.uid() and (enrolled_in(course_id) or teaches(course_id)));

create policy reply_read on discussion_replies for select
  using (exists (select 1 from discussions d where d.id = discussion_id
                 and (enrolled_in(d.course_id) or teaches(d.course_id) or my_role() = 'admin')));
create policy reply_write on discussion_replies for insert
  with check (author_id = auth.uid()
              and exists (select 1 from discussions d where d.id = discussion_id
                          and (enrolled_in(d.course_id) or teaches(d.course_id))));


-- ============================================================
-- Quiz marking, done in the database
--
-- Correct answers never leave the server. The student's browser
-- sends what they answered and receives a score and which
-- questions were wrong.
-- ============================================================

create or replace function submit_quiz_attempt(p_quiz uuid, p_answers jsonb)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_quiz    quizzes%rowtype;
  v_used    int;
  v_correct int := 0;
  v_total   int := 0;
  v_results jsonb := '[]';
  q         record;
  v_given   text;
  v_ok      boolean;
begin
  select * into v_quiz from quizzes where id = p_quiz;
  if not found then raise exception 'Quiz introuvable'; end if;

  if not enrolled_in(v_quiz.course_id) then
    raise exception 'Vous n''êtes pas inscrit à ce cours';
  end if;

  select count(*) into v_used from quiz_attempts
   where quiz_id = p_quiz and student_id = auth.uid();

  if v_used >= v_quiz.attempts_allowed then
    raise exception 'Nombre maximal de tentatives atteint';
  end if;

  for q in select * from quiz_questions where quiz_id = p_quiz order by position loop
    v_total := v_total + 1;
    v_given := p_answers ->> q.id::text;
    v_ok := (v_given is not null
             and lower(btrim(v_given)) = lower(btrim(q.correct_answer)));
    if v_ok then v_correct := v_correct + 1; end if;
    v_results := v_results || jsonb_build_object(
      'question_id', q.id,
      'correct', v_ok,
      'correct_answer', case when v_used + 1 >= v_quiz.attempts_allowed
                             then q.correct_answer else null end
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
$$;


-- ============================================================
-- FILE STORAGE
--
-- After running this, create two buckets in the dashboard under
-- Storage. Both must be PRIVATE, not public:
--
--   submissions   student work
--   briefs        assignment instructions from teachers
--
-- Paths must follow this shape for the policies to work:
--   submissions/<course_id>/<assignment_id>/<student_id>/<filename>
--   briefs/<course_id>/<assignment_id>/<filename>
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
  using (bucket_id = 'briefs' and teaches(((storage.foldername(name))[1])::uuid))
  with check (bucket_id = 'briefs' and teaches(((storage.foldername(name))[1])::uuid));


-- ============================================================
-- CHECK IT WORKED
-- ============================================================

select 'Tables created: ' || count(*)::text as result
from information_schema.tables
where table_schema = 'public';
-- Expect 16.


-- ============================================================
-- NEXT: set up the pilot classroom
--
-- 1. Go to Authentication then Users, and add two accounts,
--    ticking Auto Confirm User on each:
--       teacher@sfxo.edu.ht
--       student@sfxo.edu.ht
--
-- 2. Come back here and run the block below to give them their
--    names and roles, create the course, and enroll the student.
-- ============================================================

-- update profiles p set role = 'teacher', full_name = 'Dr. Jean-Baptiste'
-- from auth.users u where u.id = p.id and u.email = 'teacher@sfxo.edu.ht';
--
-- update profiles p set role = 'student', full_name = 'Pam Doe',
--        student_number = 'SFXO-2026-09'
-- from auth.users u where u.id = p.id and u.email = 'student@sfxo.edu.ht';
--
-- insert into courses (institution_id, teacher_id, code, title, room, schedule)
-- select i.id, p.id, 'MATH-102', 'Mathématiques Générales',
--        'Salle 12', 'Lun · Mer · Ven — 08h00'
-- from institutions i, profiles p
-- where i.code = 'SFXO' and p.role = 'teacher';
--
-- insert into enrollments (course_id, student_id)
-- select c.id, p.id from courses c, profiles p
-- where c.code = 'MATH-102' and p.role = 'student';
--
-- select full_name, role, student_number from profiles;


-- ============================================================
-- SECURITY NOTES - read before storing real student data
-- ============================================================
--
-- 1. Use the anon key in the browser, never the service_role key.
--    service_role ignores every policy above. If it ends up in
--    index.html, anyone can read every record in the school.
--
-- 2. Test the policies by signing in as a real student and trying
--    to reach another student's submission and grade. If anything
--    comes back, fix it before going further. Repeat after every
--    schema change.
--
-- 3. quiz_questions must stay teacher only. If a student can select
--    from that table, they can read the answers before answering.
--
-- 4. Turn on Point in Time Recovery when you move to the paid plan.
--    The free plan has no automatic backups, and these will be the
--    only copy of a term's grades.
--
-- 5. Ask families for consent before storing anything about minors,
--    and be able to explain plainly what is kept and who can see it.
-- ============================================================
