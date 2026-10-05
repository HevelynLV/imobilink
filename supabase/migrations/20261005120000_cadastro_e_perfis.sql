-- Etapa 3 · Cadastro: criação do perfil por trigger (item 4 da auditoria)
-- Rodar no SQL Editor do Supabase DEPOIS de 20260930130000_correcoes_auditoria_etapa2.sql.
--
-- Ninguém cria perfil pelo app: não existe regra de INSERT em perfis nem em
-- imobiliarias para usuários comuns. O único caminho é este trigger, que roda
-- dentro do banco quando o Supabase Auth cria o usuário (auth.users).
--
-- O app manda os dados do formulário em options.data do signUp, e eles chegam
-- aqui em raw_user_meta_data. Esses dados vêm do navegador, então NADA é
-- confiado sem validar. Depois do cadastro, o tipo vale só na tabela perfis;
-- o user_metadata pode ser alterado pelo próprio usuário e nunca serve para
-- decidir permissão.

-- ===============================================================
-- 1. Telefone: formato brasileiro com DDD, só dígitos
-- ===============================================================
-- Celular: DDD + 9 + 8 dígitos (11 no total). Fixo: DDD + [2-5] + 7 dígitos (10).
-- DDD não tem zero (11 a 99). Admin pode ficar sem telefone; os outros não.
-- Vale no cadastro e em qualquer edição futura do perfil.

alter table public.perfis
  add constraint perfis_telefone_formato
  check (telefone is null or telefone ~ '^[1-9]{2}(9[0-9]{8}|[2-5][0-9]{7})$');

alter table public.perfis
  add constraint perfis_telefone_obrigatorio
  check (tipo = 'admin' or telefone is not null);

-- Tira tudo que não é dígito e o +55 do começo, se vier.
-- Devolve null se sobrar texto vazio; o formato é conferido pela regra acima.
create function privado.normalizar_telefone(p_telefone text)
returns text
language sql immutable set search_path = ''
as $$
  select nullif(
    case
      when length(d) in (12, 13) and d like '55%' then substr(d, 3)
      else d
    end, '')
  from (select regexp_replace(coalesce(p_telefone, ''), '[^0-9]', '', 'g') as d) t;
$$;

-- ===============================================================
-- 2. Trigger de cadastro
-- ===============================================================
-- É "security definer": roda como dono da função (postgres) e por isso
-- consegue inserir em perfis e imobiliarias apesar do RLS. Fica no schema
-- "privado", que não está exposto na API (ninguém chama pelo app).
--
-- Regras:
--   - sem "tipo" nos dados: não cria perfil (usuário criado à mão no SQL
--     Editor, como o roteiro de teste). Sem perfil, o usuário não acessa nada
--   - "tipo" diferente de proprietario/imobiliaria (inclusive admin): erro,
--     e o Postgres desfaz o cadastro inteiro, inclusive o usuário em auth.users
--   - imobiliaria: SEMPRE cria uma imobiliária nova com status "pendente".
--     Não aceita imobiliaria_id nem status vindos do navegador, então ninguém
--     entra numa imobiliária que já existe (e talvez já esteja ativa)
--   - CRECI repetido: a regra "unique" da tabela barra e desfaz o cadastro

create function privado.criar_perfil_no_cadastro()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  dados          jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_tipo         text  := dados ->> 'tipo';
  v_nome         text  := nullif(btrim(dados ->> 'nome'), '');
  v_telefone     text  := privado.normalizar_telefone(dados ->> 'telefone');
  v_imob_nome    text  := nullif(btrim(dados ->> 'imobiliaria_nome'), '');
  v_creci        text  := upper(nullif(btrim(dados ->> 'creci'), ''));
  v_imobiliaria  uuid;
begin
  if not (dados ? 'tipo') then
    return new;
  end if;

  if v_tipo is null or v_tipo not in ('proprietario', 'imobiliaria') then
    raise exception 'Tipo de cadastro inválido';
  end if;

  if v_nome is null or char_length(v_nome) > 120 then
    raise exception 'Nome obrigatório (até 120 caracteres)';
  end if;

  if v_telefone is null
     or v_telefone !~ '^[1-9]{2}(9[0-9]{8}|[2-5][0-9]{7})$' then
    raise exception 'Telefone inválido: use DDD + número';
  end if;

  if v_tipo = 'imobiliaria' then
    if v_imob_nome is null or char_length(v_imob_nome) > 120 then
      raise exception 'Nome da imobiliária obrigatório (até 120 caracteres)';
    end if;
    if v_creci is null or char_length(v_creci) > 30 then
      raise exception 'CRECI obrigatório (até 30 caracteres)';
    end if;

    insert into public.imobiliarias (nome, creci, status_assinatura)
    values (v_imob_nome, v_creci, 'pendente')
    returning id into v_imobiliaria;
  end if;

  insert into public.perfis (id, tipo, nome, telefone, imobiliaria_id)
  values (new.id, v_tipo, v_nome, v_telefone, v_imobiliaria);

  return new;
end;
$$;

-- Ninguém chama essas funções diretamente. O trigger funciona mesmo assim:
-- o Postgres só confere a permissão de execute na hora de criar o trigger.
revoke execute on function privado.criar_perfil_no_cadastro() from public, anon, authenticated;
revoke execute on function privado.normalizar_telefone(text) from public, anon, authenticated;

-- O Supabase Auth grava em auth.users com o papel supabase_auth_admin.
grant usage on schema privado to supabase_auth_admin;

create trigger criar_perfil_no_cadastro
  after insert on auth.users
  for each row execute function privado.criar_perfil_no_cadastro();
