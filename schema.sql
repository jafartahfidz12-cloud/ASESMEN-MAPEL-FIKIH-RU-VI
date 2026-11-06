-- Jalankan seluruh SQL ini di Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 role text not null default 'student' check (role in ('student','admin')),
 created_at timestamptz not null default now()
);
create table if not exists public.participants (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null unique references auth.users(id) on delete cascade,
 full_name text not null,
 class_name text not null,
 participant_no text not null unique,
 exam_year text not null,
 created_at timestamptz not null default now()
);
create table if not exists public.exam_questions (
 id integer primary key,
 topic text not null,
 prompt text not null,
 options jsonb not null
);
create table if not exists public.answer_keys (
 question_id integer primary key references public.exam_questions(id) on delete cascade,
 correct_option text not null
);
create table if not exists public.exam_attempts (
 id uuid primary key default gen_random_uuid(),
 participant_id uuid not null unique references public.participants(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 status text not null default 'in_progress' check(status in ('in_progress','submitted')),
 started_at timestamptz not null default now(),
 submitted_at timestamptz,
 score integer,
 correct_count integer,
 wrong_count integer,
 unanswered_count integer
);
create table if not exists public.exam_answers (
 attempt_id uuid not null references public.exam_attempts(id) on delete cascade,
 question_id integer not null references public.exam_questions(id),
 selected_option text,
 primary key(attempt_id,question_id)
);

alter table public.profiles enable row level security;
alter table public.participants enable row level security;
alter table public.exam_attempts enable row level security;
alter table public.exam_answers enable row level security;
alter table public.exam_questions enable row level security;
alter table public.answer_keys enable row level security;

create policy "profile read self" on public.profiles for select to authenticated using(id=auth.uid());
create policy "participant read self" on public.participants for select to authenticated using(user_id=auth.uid());
create policy "attempt read self" on public.exam_attempts for select to authenticated using(user_id=auth.uid());
create policy "answers read self" on public.exam_answers for select to authenticated using(exists(select 1 from public.exam_attempts a where a.id=attempt_id and a.user_id=auth.uid()));
-- Pertanyaan hanya dapat dibaca tanpa kunci jawaban.
create policy "questions visible to signed-in users" on public.exam_questions for select to authenticated using(true);
-- Tidak ada policy SELECT untuk answer_keys: kunci tidak dapat dibaca dari browser.

create or replace view public.public_questions with (security_invoker=true) as
 select id,topic,prompt,options from public.exam_questions;

create or replace function public.start_exam_attempt(p_full_name text,p_class_name text,p_participant_no text,p_exam_year text)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid(); v_part public.participants; v_attempt public.exam_attempts;
begin
 if v_uid is null then raise exception 'Sesi peserta tidak ditemukan. Muat ulang halaman.'; end if;
 if length(trim(p_full_name))<2 or length(trim(p_participant_no))<1 then raise exception 'Identitas belum lengkap.'; end if;
 if exists(select 1 from public.participants where participant_no=trim(p_participant_no)) then
   raise exception 'Nomor peserta sudah digunakan. Hubungi guru/panitia jika ini kesalahan.';
 end if;
 insert into public.profiles(id,role) values(v_uid,'student') on conflict(id) do nothing;
 insert into public.participants(user_id,full_name,class_name,participant_no,exam_year)
 values(v_uid,trim(p_full_name),trim(p_class_name),trim(p_participant_no),p_exam_year) returning * into v_part;
 insert into public.exam_attempts(participant_id,user_id) values(v_part.id,v_uid) returning * into v_attempt;
 return jsonb_build_object('id',v_attempt.id,'full_name',v_part.full_name,'class_name',v_part.class_name);
end $$;

create or replace function public.submit_exam_attempt(p_attempt_id uuid,p_answers jsonb)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid(); v_correct int:=0; v_wrong int:=0; v_empty int:=0; v_score int:=0; item jsonb; qid int;
begin
 if v_uid is null then raise exception 'Sesi tidak valid.'; end if;
 if not exists(select 1 from public.exam_attempts where id=p_attempt_id and user_id=v_uid and status='in_progress') then
   raise exception 'Asesmen sudah dikumpulkan atau tidak ditemukan.';
 end if;
 for item in select * from jsonb_array_elements(p_answers) loop
   select id into qid from public.exam_questions where prompt=item->>'prompt';
   if qid is not null then
     insert into public.exam_answers(attempt_id,question_id,selected_option)
     values(p_attempt_id,qid,nullif(item->>'answer',''))
     on conflict(attempt_id,question_id) do update set selected_option=excluded.selected_option;
   end if;
 end loop;
 select count(*) filter(where a.selected_option=k.correct_option),
        count(*) filter(where a.selected_option is not null and a.selected_option<>k.correct_option),
        count(*) filter(where a.selected_option is null)
 into v_correct,v_wrong,v_empty
 from public.exam_questions q join public.answer_keys k on k.question_id=q.id
 left join public.exam_answers a on a.question_id=q.id and a.attempt_id=p_attempt_id;
 v_score:=v_correct*2;
 update public.exam_attempts set status='submitted',submitted_at=now(),score=v_score,
 correct_count=v_correct,wrong_count=v_wrong,unanswered_count=v_empty
 where id=p_attempt_id and user_id=v_uid;
 return jsonb_build_object('score',v_score,'correct_count',v_correct,'wrong_count',v_wrong,'unanswered_count',v_empty);
end $$;

-- Admin hanya membaca melalui view admin_results; akses dibatasi role admin.
create or replace view public.admin_results with (security_invoker=true) as
 select p.full_name,p.class_name,p.participant_no,a.score,a.correct_count,a.wrong_count,a.unanswered_count,a.submitted_at
 from public.participants p join public.exam_attempts a on a.participant_id=p.id
 where a.status='submitted';
create policy "admin read all participants" on public.participants for select to authenticated
 using(exists(select 1 from public.profiles pr where pr.id=auth.uid() and pr.role='admin'));
create policy "admin read all attempts" on public.exam_attempts for select to authenticated
 using(exists(select 1 from public.profiles pr where pr.id=auth.uid() and pr.role='admin'));

grant usage on schema public to anon,authenticated;
grant select on public.public_questions to authenticated;
grant select on public.admin_results to authenticated;
grant execute on function public.start_exam_attempt(text,text,text,text) to anon,authenticated;
grant execute on function public.submit_exam_attempt(uuid,jsonb) to authenticated;

-- SEED 50 soal dan kunci: salin data dari src/questions.js ke tabel berikut.
-- Untuk keamanan, lakukan import satu kali dari lingkungan tepercaya/admin.
-- Lihat README untuk skrip seed yang disediakan.
