-- ============================================================
-- KAYE - mise à jour pour la section Quiz
--
-- À exécuter une fois dans le SQL Editor de Supabase.
-- Sans danger : ne touche à aucune donnée existante.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Laisser les élèves LIRE les questions, sans les réponses
--
-- La table quiz_questions contient les bonnes réponses, donc
-- elle reste interdite aux élèves. Cette fonction leur renvoie
-- uniquement l'énoncé et les choix.
-- ------------------------------------------------------------

create or replace function get_quiz_questions(p_quiz uuid)
returns table (
  id       uuid,
  kind     question_kind,
  prompt   text,
  choices  jsonb,
  position int
)
language plpgsql stable security definer set search_path = public
as $$
declare
  v_course uuid;
  v_pub    boolean;
begin
  select course_id, is_published into v_course, v_pub
  from quizzes q where q.id = p_quiz;

  if v_course is null then
    raise exception 'Quiz introuvable';
  end if;

  -- l'enseignant du cours voit tout, l'élève seulement si publié
  if not (teaches(v_course) or (enrolled_in(v_course) and v_pub)) then
    raise exception 'Accès refusé';
  end if;

  return query
    select qq.id, qq.kind, qq.prompt, qq.choices, qq.position
    from quiz_questions qq
    where qq.quiz_id = p_quiz
    order by qq.position;
end;
$$;

grant execute on function get_quiz_questions(uuid) to authenticated;


-- ------------------------------------------------------------
-- 2. Compter les questions sans les lire
-- ------------------------------------------------------------

create or replace function quiz_question_count(p_quiz uuid)
returns int
language sql stable security definer set search_path = public
as $$ select count(*)::int from quiz_questions where quiz_id = p_quiz $$;

grant execute on function quiz_question_count(uuid) to authenticated;


-- ------------------------------------------------------------
-- 3. Autoriser la correction automatique
-- ------------------------------------------------------------

grant execute on function submit_quiz_attempt(uuid, jsonb) to authenticated;


-- ------------------------------------------------------------
-- 4. Vérification
-- ------------------------------------------------------------

select 'Fonctions quiz installees' as resultat;
