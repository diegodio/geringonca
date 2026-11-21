-- Geringonça: contas, progresso e fases criadas no editor.
-- Rode uma vez no Supabase: SQL Editor → New query → cole este arquivo → Run.
-- Pode rodar de novo sem estragar nada (tudo usa "if not exists"/"or replace").
--
-- Segurança: todas as tabelas têm Row Level Security. Cada pessoa só lê e
-- altera o que é dela; fases marcadas como públicas podem ser lidas por todos
-- (para uma galeria no futuro). A chave "anon" do jogo é pública por natureza:
-- quem protege os dados são estas regras.

-- ---------- perfis ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 40),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "perfil: ler o próprio" on public.profiles;
create policy "perfil: ler o próprio" on public.profiles
  for select to authenticated using (id = auth.uid());

drop policy if exists "perfil: mudar o próprio" on public.profiles;
create policy "perfil: mudar o próprio" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- cria o perfil sozinho quando alguém cria a conta (o nome vem do cadastro)
create or replace function public.criar_perfil()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, left(coalesce(new.raw_user_meta_data ->> 'display_name', ''), 40))
  on conflict (id) do nothing;
  return new;
end;
$$;

-- só o gatilho chama a função (ninguém de fora, pela API)
revoke execute on function public.criar_perfil() from public, anon, authenticated;

drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario
  after insert on auth.users
  for each row execute function public.criar_perfil();

-- ---------- progresso ----------
-- Um registro por pessoa: fases concluídas, medalhas, recordes, melhores
-- soluções, desafios e tentativas, em JSON. O jogo junta o que vem de cada
-- aparelho (fica sempre o melhor de cada um).
create table if not exists public.progress (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  data jsonb not null default '{}'::jsonb check (pg_column_size(data) < 2000000),
  updated_at timestamptz not null default now()
);

alter table public.progress enable row level security;

drop policy if exists "progresso: tudo no próprio" on public.progress;
create policy "progresso: tudo no próprio" on public.progress
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- fases criadas no editor ----------
create table if not exists public.levels (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(name) <= 40),
  data jsonb not null check (pg_column_size(data) < 200000),
  verified boolean not null default false,
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists levels_owner on public.levels (owner);

alter table public.levels enable row level security;

drop policy if exists "fases: ler as próprias e as públicas" on public.levels;
create policy "fases: ler as próprias e as públicas" on public.levels
  for select to anon, authenticated using (owner = auth.uid() or is_public);

drop policy if exists "fases: criar as próprias" on public.levels;
create policy "fases: criar as próprias" on public.levels
  for insert to authenticated with check (owner = auth.uid());

drop policy if exists "fases: mudar as próprias" on public.levels;
create policy "fases: mudar as próprias" on public.levels
  for update to authenticated using (owner = auth.uid()) with check (owner = auth.uid());

drop policy if exists "fases: apagar as próprias" on public.levels;
create policy "fases: apagar as próprias" on public.levels
  for delete to authenticated using (owner = auth.uid());

-- ---------- updated_at sempre atualizado ----------
create or replace function public.tocar_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists progress_updated_at on public.progress;
create trigger progress_updated_at before update on public.progress
  for each row execute function public.tocar_updated_at();

drop trigger if exists levels_updated_at on public.levels;
create trigger levels_updated_at before update on public.levels
  for each row execute function public.tocar_updated_at();
