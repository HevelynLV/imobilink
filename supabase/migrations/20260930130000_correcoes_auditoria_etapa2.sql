-- Etapa 2 · Correções da auditoria (itens 1, 2, 3, 5, 6 e 14)
-- Rodar no SQL Editor do Supabase DEPOIS de 20260930120100_rls.sql.

-- ===============================================================
-- 1. alteracoes_imovel: registro das edições de imóvel aprovado
-- ===============================================================
-- Edição depois da aprovação vale na hora (sem nova aprovação), mas
-- cada campo alterado vira uma linha aqui para o admin revisar.
-- Só o trigger escreve; só o admin lê e marca como revisado.

create table public.alteracoes_imovel (
  id           uuid primary key default gen_random_uuid(),
  imovel_id    uuid not null references public.imoveis (id) on delete cascade,
  editado_por  uuid not null references public.perfis (id),
  campo        text not null,
  valor_antigo text,
  valor_novo   text,
  editado_em   timestamptz not null default now(),
  revisado     boolean not null default false
);

create index alteracoes_imovel_imovel_id_idx on public.alteracoes_imovel (imovel_id);
create index alteracoes_imovel_nao_revisadas_idx
  on public.alteracoes_imovel (editado_em) where not revisado;

-- Permissão por coluna: o usuário logado só pode ler e mudar "revisado".
-- Ninguém pelo app insere, apaga ou altera o conteúdo do registro.
revoke all on public.alteracoes_imovel from anon, authenticated;
grant select, update (revisado) on public.alteracoes_imovel to authenticated;

alter table public.alteracoes_imovel enable row level security;

create policy admin_ler on public.alteracoes_imovel for select to authenticated
  using ((select public.eh_admin()));

create policy admin_marcar_revisado on public.alteracoes_imovel for update to authenticated
  using ((select public.eh_admin())) with check ((select public.eh_admin()));

-- Função que grava o registro. Fica no schema "privado", que NÃO está
-- exposto na API do Supabase: o app não consegue chamá-la para forjar
-- registros. NUNCA adicione "privado" em Settings > Data API > Exposed schemas.
-- É security definer (roda como dono, por isso insere apesar do RLS) e
-- chamada pelos triggers, que rodam como o usuário logado.
create schema privado;
revoke all on schema privado from public, anon;
grant usage on schema privado to authenticated;

create function privado.registrar_alteracao_imovel(
  p_imovel_id uuid, p_campo text, p_valor_antigo text, p_valor_novo text)
returns void
language sql security definer set search_path = ''
as $$
  insert into public.alteracoes_imovel (imovel_id, editado_por, campo, valor_antigo, valor_novo)
  values (p_imovel_id, (select auth.uid()), p_campo, p_valor_antigo, p_valor_novo);
$$;

revoke execute on function privado.registrar_alteracao_imovel(uuid, text, text, text) from public, anon;
grant execute on function privado.registrar_alteracao_imovel(uuid, text, text, text) to authenticated;

-- ===============================================================
-- 2. Trava de edição do imóvel (itens 1, 3 e 6)
-- ===============================================================
-- Substitui a versão da migration de RLS; o trigger imoveis_proteger_campos
-- continua o mesmo e passa a usar esta função. Admin é isento.
--
-- Proprietário, por status atual do imóvel:
--   pendente_aprovacao  edita à vontade
--   reprovado           edita à vontade e reenvia (reprovado -> pendente_aprovacao)
--   disponivel          edição vale na hora e cada campo alterado é registrado
--   reservado, em_proposta, vendido   edição bloqueada

create or replace function public.proteger_campos_imovel()
returns trigger
language plpgsql set search_path = ''
as $$
declare
  campos_conteudo constant text[] := array['titulo', 'descricao', 'tipo', 'endereco', 'bairro',
                                           'preco', 'quartos', 'banheiros', 'vagas', 'area_m2'];
  antigo jsonb := to_jsonb(old);
  novo   jsonb := to_jsonb(new);
  campo  text;
begin
  if current_user = 'authenticated' and not public.eh_admin() then
    if new.aprovado_em is distinct from old.aprovado_em
       or new.termo_aceito_em is distinct from old.termo_aceito_em
       or new.criado_em is distinct from old.criado_em then
      raise exception 'Só o admin pode alterar aprovação, aceite do termo ou data de cadastro';
    end if;

    if old.status in ('reservado', 'em_proposta', 'vendido') then
      raise exception 'Imóvel reservado, em proposta ou vendido não pode ser editado';
    end if;

    if new.status is distinct from old.status
       and not (old.status = 'reprovado' and new.status = 'pendente_aprovacao') then
      raise exception 'Só o admin pode alterar o status (o proprietário só reenvia imóvel reprovado)';
    end if;

    if old.status = 'disponivel' then
      foreach campo in array campos_conteudo loop
        if antigo -> campo is distinct from novo -> campo then
          perform privado.registrar_alteracao_imovel(old.id, campo, antigo ->> campo, novo ->> campo);
        end if;
      end loop;
    end if;
  end if;

  -- data da aprovação (item 6)
  if new.status = 'disponivel' and old.status in ('pendente_aprovacao', 'reprovado') then
    new.aprovado_em := now();
  elsif new.status in ('pendente_aprovacao', 'reprovado') then
    new.aprovado_em := null;
  end if;

  new.atualizado_em := now();
  return new;
end;
$$;

-- Cadastro pelo app: o banco decide as datas, não o navegador (item 3).
create function public.preencher_datas_imovel()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if current_user = 'authenticated' then
    new.termo_aceito_em := now();
    new.criado_em := now();
    new.atualizado_em := now();
  end if;
  return new;
end;
$$;

create trigger imoveis_preencher_datas
  before insert on public.imoveis
  for each row execute function public.preencher_datas_imovel();

-- ===============================================================
-- 3. Trava das fotos (itens 1 e 5)
-- ===============================================================
-- Mesmas regras do imóvel: foto de imóvel reservado/em proposta/vendido
-- não muda; foto de imóvel disponível muda e é registrada. Admin é isento.
-- Quando o imóvel é apagado, as fotos saem junto (cascade): nesse momento
-- o imóvel já não é encontrado e o trigger não bloqueia nem registra.

create function public.proteger_fotos_imovel()
returns trigger
language plpgsql set search_path = ''
as $$
declare
  v_imovel_id uuid := coalesce(new.imovel_id, old.imovel_id);
  v_status    text;
begin
  if current_user = 'authenticated' and not public.eh_admin() then
    if tg_op = 'UPDATE' and new.imovel_id is distinct from old.imovel_id then
      raise exception 'Não é possível mover a foto para outro imóvel';
    end if;

    select status into v_status from public.imoveis where id = v_imovel_id;

    if v_status in ('reservado', 'em_proposta', 'vendido') then
      raise exception 'Fotos de imóvel reservado, em proposta ou vendido não podem ser alteradas';
    end if;

    if v_status = 'disponivel' then
      if tg_op = 'INSERT' then
        perform privado.registrar_alteracao_imovel(v_imovel_id, 'foto', null, new.caminho_storage);
      elsif tg_op = 'DELETE' then
        perform privado.registrar_alteracao_imovel(v_imovel_id, 'foto', old.caminho_storage, null);
      else
        if new.caminho_storage is distinct from old.caminho_storage then
          perform privado.registrar_alteracao_imovel(v_imovel_id, 'foto.caminho_storage',
                                                     old.caminho_storage, new.caminho_storage);
        end if;
        if new.ordem is distinct from old.ordem then
          perform privado.registrar_alteracao_imovel(v_imovel_id, 'foto.ordem',
                                                     old.ordem::text, new.ordem::text);
        end if;
      end if;
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger fotos_imovel_proteger
  before insert or update or delete on public.fotos_imovel
  for each row execute function public.proteger_fotos_imovel();

-- O arquivo da foto tem que ficar na pasta do próprio imóvel no Storage:
-- "<imovel_id>/qualquer-nome.jpg" (item 5).
alter table public.fotos_imovel
  add constraint fotos_imovel_caminho_do_imovel
  check (caminho_storage like imovel_id::text || '/%');

-- ===============================================================
-- 4. Visitas e propostas para o proprietário (item 2)
-- ===============================================================
-- O proprietário deixa de ler as tabelas direto (lá estão observacoes e
-- condicoes, textos livres do corretor). Ele passa a usar as funções
-- abaixo, que devolvem só colunas seguras. No app: supabase.rpc('...').

drop policy visita_ver on public.visitas;
create policy visita_ver on public.visitas for select to authenticated
  using (exists (select 1 from public.reservas r where r.id = reserva_id));

drop policy proposta_ver on public.propostas;
create policy proposta_ver on public.propostas for select to authenticated
  using (exists (select 1 from public.reservas r where r.id = reserva_id));

drop function public.reserva_do_meu_imovel(uuid);

create function public.visitas_do_meu_imovel()
returns table (id uuid, imovel_id uuid, data_hora timestamptz, status text, criado_em timestamptz)
language sql stable security definer set search_path = ''
as $$
  select v.id, r.imovel_id, v.data_hora, v.status, v.criado_em
  from public.visitas v
  join public.reservas r on r.id = v.reserva_id
  join public.imoveis im on im.id = r.imovel_id
  where im.proprietario_id = (select auth.uid())
  order by v.data_hora;
$$;

create function public.propostas_do_meu_imovel()
returns table (id uuid, imovel_id uuid, valor numeric, status text, criado_em timestamptz)
language sql stable security definer set search_path = ''
as $$
  select p.id, r.imovel_id, p.valor, p.status, p.criado_em
  from public.propostas p
  join public.reservas r on r.id = p.reserva_id
  join public.imoveis im on im.id = r.imovel_id
  where im.proprietario_id = (select auth.uid())
  order by p.criado_em desc;
$$;

revoke execute on function public.visitas_do_meu_imovel() from public, anon;
revoke execute on function public.propostas_do_meu_imovel() from public, anon;
grant execute on function public.visitas_do_meu_imovel() to authenticated;
grant execute on function public.propostas_do_meu_imovel() to authenticated;

-- ===============================================================
-- 5. Objetos criados no futuro nascem fechados para o anon (item 14)
-- ===============================================================
-- Vale para tabelas, sequências e funções criadas pelo usuário postgres
-- (SQL Editor e migrations). O authenticated continua recebendo acesso
-- pelo padrão do Supabase; o RLS de cada tabela nova continua obrigatório.
-- O "execute para public" das funções é um padrão global do Postgres, por
-- isso é revogado sem "in schema".

alter default privileges for role postgres in schema public
  revoke all on tables from anon;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon;
alter default privileges for role postgres in schema public
  revoke all on functions from anon;
alter default privileges for role postgres
  revoke execute on functions from public;
