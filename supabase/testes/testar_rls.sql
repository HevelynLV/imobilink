-- Roteiro de teste do RLS · Etapas 2 e 3
-- Como usar: cole o arquivo inteiro no SQL Editor do Supabase e clique em Run.
-- O resultado é uma tabela: toda linha deve mostrar "✅ passou".
-- Usa só IDs fictícios fixos (abaixo) e apaga esses dados no final.
-- Pode rodar quantas vezes quiser.
--
-- Usuários fictícios:
--   ...0001 admin
--   ...0002 proprietário 1 (imóveis: 1 disponível, 2 pendente, 5 reprovado)
--   ...0003 proprietário 2 (imóveis: 3 reservado, 4 vendido)
--   ...0004 corretor da imobiliária ATIVA (tem reserva no imóvel 3)
--   ...0005 corretor da imobiliária BLOQUEADA (tem reserva expirada no imóvel 1)
--   ...0006 corretor da imobiliária ATIVA (colega do ...0004)
--   ...0007 corretor da imobiliária PENDENTE
--
-- Testes de bloqueio conferem o código do erro:
--   42501 = RLS ou falta de permissão · P0001 = trigger · 23514 = regra (check)
--   23505 = valor repetido (unique)
-- Qualquer outro erro aparece como "erro inesperado" e o teste falha.
--
-- Testes que alteram dados desfazem a alteração no final (bloco com
-- "raise ... TR001"), para não mudar o resultado dos outros testes.

-- ---------------------------------------------------------------
-- 0. Preparação: tabela de resultados + limpeza de rodadas anteriores
-- ---------------------------------------------------------------
drop schema if exists teste_rls cascade;
create schema teste_rls;
create table teste_rls.resultado (
  ordem    serial,
  teste    text,
  esperado text,
  obtido   text
);
grant usage on schema teste_rls to authenticated, anon;
grant insert on teste_rls.resultado to authenticated, anon;
grant usage on sequence teste_rls.resultado_ordem_seq to authenticated, anon;

-- Traduz o código do erro no texto que os testes esperam
create function teste_rls.bloqueio(p_estado text, p_msg text)
returns text
language sql
as $$
  select case
    when p_estado in ('42501', 'P0001', '23514', '23505') then 'bloqueado (' || p_estado || ')'
    else 'erro inesperado: ' || p_estado || ' ' || p_msg
  end;
$$;

-- Conta registros de alteracoes_imovel ignorando o RLS (só para o teste)
create function teste_rls.contar_alteracoes(p_imovel_id uuid)
returns int
language sql security definer set search_path = ''
as $$
  select count(*)::int from public.alteracoes_imovel where imovel_id = p_imovel_id;
$$;

grant execute on function teste_rls.bloqueio(text, text) to authenticated, anon;
grant execute on function teste_rls.contar_alteracoes(uuid) to authenticated;

drop table if exists public.teste_rls_privilegios;
drop function if exists public.teste_rls_funcao();

delete from public.propostas where reserva_id in ('dddddddd-0000-4000-a000-000000000001',
                                                  'dddddddd-0000-4000-a000-000000000002');
delete from public.visitas   where reserva_id in ('dddddddd-0000-4000-a000-000000000001',
                                                  'dddddddd-0000-4000-a000-000000000002');
delete from public.reservas  where id in ('dddddddd-0000-4000-a000-000000000001',
                                          'dddddddd-0000-4000-a000-000000000002');
delete from public.imoveis   where proprietario_id in ('00000000-0000-4000-a000-000000000002',
                                                       '00000000-0000-4000-a000-000000000003');
delete from auth.users where id in ('00000000-0000-4000-a000-000000000001',
                                    '00000000-0000-4000-a000-000000000002',
                                    '00000000-0000-4000-a000-000000000003',
                                    '00000000-0000-4000-a000-000000000004',
                                    '00000000-0000-4000-a000-000000000005',
                                    '00000000-0000-4000-a000-000000000006',
                                    '00000000-0000-4000-a000-000000000007');
delete from public.imobiliarias where id in ('bbbbbbbb-0000-4000-a000-000000000001',
                                             'bbbbbbbb-0000-4000-a000-000000000002',
                                             'bbbbbbbb-0000-4000-a000-000000000003');

-- ---------------------------------------------------------------
-- 1. Dados fictícios (inseridos como postgres, que ignora o RLS)
-- ---------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000001', 'authenticated', 'authenticated', 'admin@teste.local'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000002', 'authenticated', 'authenticated', 'prop1@teste.local'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000003', 'authenticated', 'authenticated', 'prop2@teste.local'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000004', 'authenticated', 'authenticated', 'corretor.ativo@teste.local'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000005', 'authenticated', 'authenticated', 'corretor.bloq@teste.local'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000006', 'authenticated', 'authenticated', 'corretor.colega@teste.local'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000007', 'authenticated', 'authenticated', 'corretor.pend@teste.local');

insert into public.imobiliarias (id, nome, creci, status_assinatura) values
  ('bbbbbbbb-0000-4000-a000-000000000001', 'Imob Ativa (teste)',     'TESTE-0001', 'ativa'),
  ('bbbbbbbb-0000-4000-a000-000000000002', 'Imob Bloqueada (teste)', 'TESTE-0002', 'bloqueada'),
  ('bbbbbbbb-0000-4000-a000-000000000003', 'Imob Pendente (teste)',  'TESTE-0003', 'pendente');

insert into public.perfis (id, tipo, nome, telefone, imobiliaria_id) values
  ('00000000-0000-4000-a000-000000000001', 'admin',        'Admin',           null,            null),
  ('00000000-0000-4000-a000-000000000002', 'proprietario', 'Proprietário 1',  '11900000001', null),
  ('00000000-0000-4000-a000-000000000003', 'proprietario', 'Proprietário 2',  '11900000002', null),
  ('00000000-0000-4000-a000-000000000004', 'imobiliaria',  'Corretor Ativo',  '11900000004', 'bbbbbbbb-0000-4000-a000-000000000001'),
  ('00000000-0000-4000-a000-000000000005', 'imobiliaria',  'Corretor Bloq',   '11900000005', 'bbbbbbbb-0000-4000-a000-000000000002'),
  ('00000000-0000-4000-a000-000000000006', 'imobiliaria',  'Corretor Colega', '11900000006', 'bbbbbbbb-0000-4000-a000-000000000001'),
  ('00000000-0000-4000-a000-000000000007', 'imobiliaria',  'Corretor Pend',   '11900000007', 'bbbbbbbb-0000-4000-a000-000000000003');

insert into public.imoveis (id, proprietario_id, titulo, tipo, bairro, preco, status, termo_aceito_em, aprovado_em) values
  ('cccccccc-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000002', 'Imóvel 1', 'apartamento', 'Centro', 500000, 'disponivel',         now(), now()),
  ('cccccccc-0000-4000-a000-000000000002', '00000000-0000-4000-a000-000000000002', 'Imóvel 2', 'casa',        'Centro', 700000, 'pendente_aprovacao', now(), null),
  ('cccccccc-0000-4000-a000-000000000003', '00000000-0000-4000-a000-000000000003', 'Imóvel 3', 'apartamento', 'Jardim', 400000, 'reservado',          now(), now()),
  ('cccccccc-0000-4000-a000-000000000004', '00000000-0000-4000-a000-000000000003', 'Imóvel 4', 'casa',        'Jardim', 900000, 'vendido',            now(), now()),
  ('cccccccc-0000-4000-a000-000000000005', '00000000-0000-4000-a000-000000000002', 'Imóvel 5', 'terreno',     'Centro', 200000, 'reprovado',          now(), null);

insert into public.fotos_imovel (imovel_id, caminho_storage) values
  ('cccccccc-0000-4000-a000-000000000001', 'cccccccc-0000-4000-a000-000000000001/teste.jpg'),
  ('cccccccc-0000-4000-a000-000000000002', 'cccccccc-0000-4000-a000-000000000002/teste.jpg');

insert into public.reservas (id, imovel_id, imobiliaria_id, corretor_id, fim, status) values
  ('dddddddd-0000-4000-a000-000000000001', 'cccccccc-0000-4000-a000-000000000003',
   'bbbbbbbb-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000004', now() + interval '7 days', 'ativa'),
  ('dddddddd-0000-4000-a000-000000000002', 'cccccccc-0000-4000-a000-000000000001',
   'bbbbbbbb-0000-4000-a000-000000000002', '00000000-0000-4000-a000-000000000005', now() + interval '7 days', 'expirada');

insert into public.visitas (reserva_id, data_hora, observacoes) values
  ('dddddddd-0000-4000-a000-000000000001', now() + interval '1 day', 'Texto livre do corretor');

insert into public.propostas (reserva_id, valor, condicoes) values
  ('dddddddd-0000-4000-a000-000000000001', 380000, 'Texto livre do corretor');

-- um registro de edição já existente, para os testes de leitura
insert into public.alteracoes_imovel (imovel_id, editado_por, campo, valor_antigo, valor_novo) values
  ('cccccccc-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000002', 'preco', '480000.00', '500000.00');

-- ---------------------------------------------------------------
-- 2. Testes como PROPRIETÁRIO 1
-- ---------------------------------------------------------------
set role authenticated;
set request.jwt.claims = '{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated"}';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Proprietário vê só os próprios imóveis', '3', count(*)::text
from public.imoveis where id::text like 'cccccccc-%';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Proprietário lê só o próprio perfil (contato)', '1', count(*)::text
from public.perfis where id::text like '00000000-0000-4000-a000-%';

do $$ declare n int; begin
  update public.imoveis set preco = 1 where id = 'cccccccc-0000-4000-a000-000000000003';
  get diagnostics n = row_count;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não edita imóvel de outro', '0 linhas', n || ' linhas');
end $$;

do $$ begin
  update public.imoveis set status = 'disponivel' where id = 'cccccccc-0000-4000-a000-000000000002';
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não aprova o próprio imóvel', 'bloqueado (P0001)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não aprova o próprio imóvel', 'bloqueado (P0001)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

do $$ begin
  insert into public.imoveis (proprietario_id, titulo, tipo, bairro, preco, termo_aceito_em)
  values ('00000000-0000-4000-a000-000000000002', 'Novo', 'casa', 'Centro', 300000, now());
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário cadastra imóvel pendente', 'permitido', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário cadastra imóvel pendente', 'permitido', 'erro inesperado: ' || sqlstate || ' ' || sqlerrm);
end $$;

do $$ begin
  insert into public.imoveis (proprietario_id, titulo, tipo, bairro, preco, status, termo_aceito_em)
  values ('00000000-0000-4000-a000-000000000002', 'Furão', 'casa', 'Centro', 300000, 'disponivel', now());
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não cadastra imóvel já aprovado', 'bloqueado (42501)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não cadastra imóvel já aprovado', 'bloqueado (42501)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

do $$ declare v timestamptz; begin
  begin
    insert into public.imoveis (proprietario_id, titulo, tipo, bairro, preco, termo_aceito_em)
    values ('00000000-0000-4000-a000-000000000002', 'Data falsa', 'casa', 'Centro', 300000, '2020-01-01')
    returning termo_aceito_em into v;
    raise exception 'desfazer' using errcode = 'TR001';
  exception when sqlstate 'TR001' then null;
  end;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Cadastro ignora termo_aceito_em enviado pelo app', 'data de hoje',
          case when v::date = current_date then 'data de hoje' else v::text end);
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Cadastro ignora termo_aceito_em enviado pelo app', 'data de hoje', 'erro inesperado: ' || sqlstate || ' ' || sqlerrm);
end $$;

do $$ begin
  update public.perfis set tipo = 'admin' where id = '00000000-0000-4000-a000-000000000002';
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não vira admin', 'bloqueado (P0001)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não vira admin', 'bloqueado (P0001)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

do $$ begin
  update public.imoveis set proprietario_id = '00000000-0000-4000-a000-000000000003'
  where id = 'cccccccc-0000-4000-a000-000000000002';
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não passa o imóvel para outro dono', 'bloqueado (42501)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não passa o imóvel para outro dono', 'bloqueado (42501)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

do $$ begin
  update public.imoveis set termo_aceito_em = '2020-01-01' where id = 'cccccccc-0000-4000-a000-000000000002';
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não muda termo_aceito_em', 'bloqueado (P0001)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não muda termo_aceito_em', 'bloqueado (P0001)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

do $$ begin
  update public.imoveis set aprovado_em = now() where id = 'cccccccc-0000-4000-a000-000000000002';
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não muda aprovado_em', 'bloqueado (P0001)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não muda aprovado_em', 'bloqueado (P0001)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

do $$ begin
  update public.imoveis set criado_em = '2020-01-01' where id = 'cccccccc-0000-4000-a000-000000000002';
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não muda criado_em', 'bloqueado (P0001)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não muda criado_em', 'bloqueado (P0001)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

do $$ begin
  insert into public.fotos_imovel (imovel_id, caminho_storage)
  values ('cccccccc-0000-4000-a000-000000000003', 'cccccccc-0000-4000-a000-000000000003/intruso.jpg');
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não põe foto em imóvel de outro', 'bloqueado (42501)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não põe foto em imóvel de outro', 'bloqueado (42501)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

do $$ begin
  insert into public.fotos_imovel (imovel_id, caminho_storage)
  values ('cccccccc-0000-4000-a000-000000000002', 'outro/x.jpg');
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Foto só na pasta do próprio imóvel no Storage', 'bloqueado (23514)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Foto só na pasta do próprio imóvel no Storage', 'bloqueado (23514)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

do $$ declare n int; begin
  delete from public.imoveis where id = 'cccccccc-0000-4000-a000-000000000001';
  get diagnostics n = row_count;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não apaga imóvel aprovado', '0 linhas', n || ' linhas');
end $$;

do $$ declare n int; begin
  begin
    delete from public.imoveis where id = 'cccccccc-0000-4000-a000-000000000002';
    get diagnostics n = row_count;
    raise exception 'desfazer' using errcode = 'TR001';
  exception when sqlstate 'TR001' then null;
  end;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário apaga imóvel pendente com fotos', '1 linhas', n || ' linhas');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário apaga imóvel pendente com fotos', '1 linhas', 'erro inesperado: ' || sqlstate || ' ' || sqlerrm);
end $$;

do $$ declare v_status text; v_aprovado boolean; v_antes int; v_depois int; begin
  begin
    v_antes := teste_rls.contar_alteracoes('cccccccc-0000-4000-a000-000000000001');
    update public.imoveis set preco = 510000 where id = 'cccccccc-0000-4000-a000-000000000001';
    select status, aprovado_em is not null into v_status, v_aprovado
    from public.imoveis where id = 'cccccccc-0000-4000-a000-000000000001';
    v_depois := teste_rls.contar_alteracoes('cccccccc-0000-4000-a000-000000000001');
    raise exception 'desfazer' using errcode = 'TR001';
  exception when sqlstate 'TR001' then null;
  end;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Editar imóvel disponível: mantém status e aprovação, registra 1 alteração',
          'disponivel / aprovado / 1 registro',
          v_status || ' / ' || case when v_aprovado then 'aprovado' else 'sem aprovado_em' end
                   || ' / ' || (v_depois - v_antes) || ' registro');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Editar imóvel disponível: mantém status e aprovação, registra 1 alteração',
          'disponivel / aprovado / 1 registro', 'erro inesperado: ' || sqlstate || ' ' || sqlerrm);
end $$;

do $$ declare v_status text; v_antes int; v_depois int; begin
  begin
    v_antes := teste_rls.contar_alteracoes('cccccccc-0000-4000-a000-000000000001');
    insert into public.fotos_imovel (imovel_id, caminho_storage)
    values ('cccccccc-0000-4000-a000-000000000001', 'cccccccc-0000-4000-a000-000000000001/nova.jpg');
    select status into v_status from public.imoveis where id = 'cccccccc-0000-4000-a000-000000000001';
    v_depois := teste_rls.contar_alteracoes('cccccccc-0000-4000-a000-000000000001');
    raise exception 'desfazer' using errcode = 'TR001';
  exception when sqlstate 'TR001' then null;
  end;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Foto nova em imóvel disponível: mantém status, registra 1 alteração',
          'disponivel / 1 registro', v_status || ' / ' || (v_depois - v_antes) || ' registro');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Foto nova em imóvel disponível: mantém status, registra 1 alteração',
          'disponivel / 1 registro', 'erro inesperado: ' || sqlstate || ' ' || sqlerrm);
end $$;

do $$ declare v_status text; begin
  begin
    update public.imoveis set status = 'pendente_aprovacao' where id = 'cccccccc-0000-4000-a000-000000000005';
    select status into v_status from public.imoveis where id = 'cccccccc-0000-4000-a000-000000000005';
    raise exception 'desfazer' using errcode = 'TR001';
  exception when sqlstate 'TR001' then null;
  end;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário reenvia imóvel reprovado', 'pendente_aprovacao', v_status);
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário reenvia imóvel reprovado', 'pendente_aprovacao', 'erro inesperado: ' || sqlstate || ' ' || sqlerrm);
end $$;

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Proprietário não lê alteracoes_imovel', '0', count(*)::text
from public.alteracoes_imovel;

do $$ begin
  insert into public.alteracoes_imovel (imovel_id, editado_por, campo)
  values ('cccccccc-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000002', 'forjado');
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não escreve em alteracoes_imovel', 'bloqueado (42501)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não escreve em alteracoes_imovel', 'bloqueado (42501)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Proprietário não vê visitas de imóvel alheio', '0', count(*)::text
from public.visitas where reserva_id = 'dddddddd-0000-4000-a000-000000000001';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Proprietário não vê propostas de imóvel alheio (tabela)', '0', count(*)::text
from public.propostas where reserva_id = 'dddddddd-0000-4000-a000-000000000001';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Proprietário não vê propostas de imóvel alheio (função)', '0', count(*)::text
from public.propostas_do_meu_imovel() where imovel_id::text like 'cccccccc-%';

-- ---------------------------------------------------------------
-- 3. Testes como PROPRIETÁRIO 2 (dono do imóvel reservado)
-- ---------------------------------------------------------------
set request.jwt.claims = '{"sub":"00000000-0000-4000-a000-000000000003","role":"authenticated"}';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Proprietário vê visitas do próprio imóvel (função)', '1', count(*)::text
from public.visitas_do_meu_imovel() where imovel_id::text like 'cccccccc-%';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Proprietário vê propostas do próprio imóvel (função)', '1', count(*)::text
from public.propostas_do_meu_imovel() where imovel_id::text like 'cccccccc-%';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Proprietário não lê a tabela visitas (observações do corretor)', '0', count(*)::text
from public.visitas where reserva_id = 'dddddddd-0000-4000-a000-000000000001';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Proprietário não lê a tabela propostas (condições do corretor)', '0', count(*)::text
from public.propostas where reserva_id = 'dddddddd-0000-4000-a000-000000000001';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Proprietário não vê a reserva (dados do corretor)', '0', count(*)::text
from public.reservas where id = 'dddddddd-0000-4000-a000-000000000001';

do $$ begin
  update public.imoveis set titulo = 'Mudei' where id = 'cccccccc-0000-4000-a000-000000000003';
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não edita imóvel reservado', 'bloqueado (P0001)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não edita imóvel reservado', 'bloqueado (P0001)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

do $$ begin
  insert into public.fotos_imovel (imovel_id, caminho_storage)
  values ('cccccccc-0000-4000-a000-000000000003', 'cccccccc-0000-4000-a000-000000000003/nova.jpg');
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não muda fotos de imóvel reservado', 'bloqueado (P0001)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não muda fotos de imóvel reservado', 'bloqueado (P0001)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

-- ---------------------------------------------------------------
-- 4. Testes como CORRETOR da imobiliária ATIVA
-- ---------------------------------------------------------------
set request.jwt.claims = '{"sub":"00000000-0000-4000-a000-000000000004","role":"authenticated"}';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Assinante ativo vê só aprovados (disponível + reservado)', '2', count(*)::text
from public.imoveis where id::text like 'cccccccc-%' or proprietario_id::text like '00000000-0000-4000-a000-%';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Assinante ativo vê fotos só de imóvel aprovado', '1', count(*)::text
from public.fotos_imovel where imovel_id::text like 'cccccccc-%';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Assinante NÃO vê o contato do proprietário', '0', count(*)::text
from public.perfis where id in ('00000000-0000-4000-a000-000000000002', '00000000-0000-4000-a000-000000000003');

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Corretor não vê o perfil do colega', '0', count(*)::text
from public.perfis where id = '00000000-0000-4000-a000-000000000006';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Assinante vê a reserva da própria imobiliária', '1', count(*)::text
from public.reservas where id = 'dddddddd-0000-4000-a000-000000000001';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Assinante não vê a reserva de outra imobiliária', '0', count(*)::text
from public.reservas where id = 'dddddddd-0000-4000-a000-000000000002';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Assinante vê a visita da própria reserva', '1', count(*)::text
from public.visitas where reserva_id = 'dddddddd-0000-4000-a000-000000000001';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Corretor não lê alteracoes_imovel', '0', count(*)::text
from public.alteracoes_imovel;

do $$ declare n int; begin
  update public.imoveis set status = 'disponivel', preco = 1 where id = 'cccccccc-0000-4000-a000-000000000003';
  get diagnostics n = row_count;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Assinante não altera imóvel do catálogo', '0 linhas', n || ' linhas');
end $$;

do $$ begin
  insert into public.reservas (imovel_id, imobiliaria_id, corretor_id, fim)
  values ('cccccccc-0000-4000-a000-000000000001', 'bbbbbbbb-0000-4000-a000-000000000001',
          '00000000-0000-4000-a000-000000000004', now() + interval '7 days');
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Corretor não cria reserva (até a Etapa 7)', 'bloqueado (42501)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Corretor não cria reserva (até a Etapa 7)', 'bloqueado (42501)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

do $$ begin
  insert into public.visitas (reserva_id, data_hora)
  values ('dddddddd-0000-4000-a000-000000000001', now() + interval '2 days');
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Corretor não cria visita (até a Etapa 7)', 'bloqueado (42501)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Corretor não cria visita (até a Etapa 7)', 'bloqueado (42501)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

do $$ begin
  insert into public.propostas (reserva_id, valor)
  values ('dddddddd-0000-4000-a000-000000000001', 390000);
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Corretor não cria proposta (até a Etapa 7)', 'bloqueado (42501)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Corretor não cria proposta (até a Etapa 7)', 'bloqueado (42501)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

-- ---------------------------------------------------------------
-- 5. Testes como CORRETOR da imobiliária BLOQUEADA
-- ---------------------------------------------------------------
set request.jwt.claims = '{"sub":"00000000-0000-4000-a000-000000000005","role":"authenticated"}';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Imobiliária bloqueada não vê nenhum imóvel', '0', count(*)::text
from public.imoveis where id::text like 'cccccccc-%';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Imobiliária bloqueada não vê fotos', '0', count(*)::text
from public.fotos_imovel where imovel_id::text like 'cccccccc-%';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Imobiliária bloqueada não vê nem a própria reserva', '0', count(*)::text
from public.reservas where id = 'dddddddd-0000-4000-a000-000000000002';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Imobiliária bloqueada vê o próprio cadastro (status)', '1', count(*)::text
from public.imobiliarias where id::text like 'bbbbbbbb-%';

do $$ declare n int; begin
  update public.imobiliarias set status_assinatura = 'ativa' where id = 'bbbbbbbb-0000-4000-a000-000000000002';
  get diagnostics n = row_count;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Imobiliária não se desbloqueia sozinha', '0 linhas', n || ' linhas');
end $$;

do $$ begin
  update public.perfis set imobiliaria_id = 'bbbbbbbb-0000-4000-a000-000000000001'
  where id = '00000000-0000-4000-a000-000000000005';
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Corretor bloqueado não troca para imobiliária ativa', 'bloqueado (P0001)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Corretor bloqueado não troca para imobiliária ativa', 'bloqueado (P0001)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

-- ---------------------------------------------------------------
-- 6. Testes como CORRETOR da imobiliária PENDENTE
-- ---------------------------------------------------------------
set request.jwt.claims = '{"sub":"00000000-0000-4000-a000-000000000007","role":"authenticated"}';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Imobiliária pendente não vê nenhum imóvel', '0', count(*)::text
from public.imoveis where id::text like 'cccccccc-%';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Imobiliária pendente não vê fotos', '0', count(*)::text
from public.fotos_imovel where imovel_id::text like 'cccccccc-%';

-- ---------------------------------------------------------------
-- 7. Testes como ADMIN
-- ---------------------------------------------------------------
set request.jwt.claims = '{"sub":"00000000-0000-4000-a000-000000000001","role":"authenticated"}';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Admin vê todos os imóveis (5 + o novo)', '6', count(*)::text
from public.imoveis where proprietario_id in ('00000000-0000-4000-a000-000000000002', '00000000-0000-4000-a000-000000000003');

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Admin vê o contato dos proprietários', '2', count(telefone)::text
from public.perfis where id in ('00000000-0000-4000-a000-000000000002', '00000000-0000-4000-a000-000000000003');

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Admin lê alteracoes_imovel', 'true', (count(*) >= 1)::text
from public.alteracoes_imovel where imovel_id = 'cccccccc-0000-4000-a000-000000000001';

do $$ declare n int; begin
  update public.alteracoes_imovel set revisado = true
  where imovel_id = 'cccccccc-0000-4000-a000-000000000001' and campo = 'preco';
  get diagnostics n = row_count;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Admin marca alteração como revisada', '1 linhas', n || ' linhas');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Admin marca alteração como revisada', '1 linhas', 'erro inesperado: ' || sqlstate || ' ' || sqlerrm);
end $$;

do $$ begin
  update public.alteracoes_imovel set valor_novo = 'adulterado'
  where imovel_id = 'cccccccc-0000-4000-a000-000000000001';
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Nem o admin adultera o registro de alteração', 'bloqueado (42501)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Nem o admin adultera o registro de alteração', 'bloqueado (42501)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

do $$ declare v_antes int; v_depois int; begin
  begin
    v_antes := teste_rls.contar_alteracoes('cccccccc-0000-4000-a000-000000000001');
    update public.imoveis set preco = 520000 where id = 'cccccccc-0000-4000-a000-000000000001';
    insert into public.fotos_imovel (imovel_id, caminho_storage)
    values ('cccccccc-0000-4000-a000-000000000001', 'cccccccc-0000-4000-a000-000000000001/admin.jpg');
    v_depois := teste_rls.contar_alteracoes('cccccccc-0000-4000-a000-000000000001');
    raise exception 'desfazer' using errcode = 'TR001';
  exception when sqlstate 'TR001' then null;
  end;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Edição do admin (imóvel e foto) não gera registro', '0 registro', (v_depois - v_antes) || ' registro');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Edição do admin (imóvel e foto) não gera registro', '0 registro', 'erro inesperado: ' || sqlstate || ' ' || sqlerrm);
end $$;

do $$ declare n int; begin
  update public.imoveis set status = 'disponivel' where id = 'cccccccc-0000-4000-a000-000000000002';
  get diagnostics n = row_count;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Admin aprova imóvel', '1 linhas', n || ' linhas');
end $$;

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Aprovação grava a data em aprovado_em', 'true', (aprovado_em is not null)::text
from public.imoveis where id = 'cccccccc-0000-4000-a000-000000000002';

do $$ declare v boolean; begin
  begin
    update public.imoveis set status = 'disponivel' where id = 'cccccccc-0000-4000-a000-000000000005';
    select aprovado_em is not null into v from public.imoveis where id = 'cccccccc-0000-4000-a000-000000000005';
    raise exception 'desfazer' using errcode = 'TR001';
  exception when sqlstate 'TR001' then null;
  end;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Aprovar imóvel reprovado grava aprovado_em', 'true', v::text);
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Aprovar imóvel reprovado grava aprovado_em', 'true', 'erro inesperado: ' || sqlstate || ' ' || sqlerrm);
end $$;

do $$ declare v boolean; begin
  begin
    update public.imoveis set status = 'reprovado' where id = 'cccccccc-0000-4000-a000-000000000001';
    select aprovado_em is null into v from public.imoveis where id = 'cccccccc-0000-4000-a000-000000000001';
    raise exception 'desfazer' using errcode = 'TR001';
  exception when sqlstate 'TR001' then null;
  end;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Reprovar imóvel apaga aprovado_em', 'true', v::text);
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Reprovar imóvel apaga aprovado_em', 'true', 'erro inesperado: ' || sqlstate || ' ' || sqlerrm);
end $$;

do $$ declare n int; begin
  update public.imobiliarias set status_assinatura = 'ativa' where id = 'bbbbbbbb-0000-4000-a000-000000000002';
  get diagnostics n = row_count;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Admin ativa imobiliária', '1 linhas', n || ' linhas');
end $$;

-- A imobiliária que acabou de ser ativada agora enxerga o catálogo
set request.jwt.claims = '{"sub":"00000000-0000-4000-a000-000000000005","role":"authenticated"}';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Imobiliária ativada passa a ver o catálogo', '3', count(*)::text
from public.imoveis where id::text like 'cccccccc-%';

-- ---------------------------------------------------------------
-- 8. Testes como VISITANTE SEM LOGIN (anon)
-- ---------------------------------------------------------------
reset role;
set role anon;
set request.jwt.claims = '{"role":"anon"}';

do $$ begin
  perform 1 from public.imoveis limit 1;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Visitante sem login não lê imóveis', 'bloqueado (42501)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Visitante sem login não lê imóveis', 'bloqueado (42501)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

do $$ begin
  perform 1 from public.alteracoes_imovel limit 1;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Visitante sem login não lê alteracoes_imovel', 'bloqueado (42501)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Visitante sem login não lê alteracoes_imovel', 'bloqueado (42501)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

-- ---------------------------------------------------------------
-- 9. Permissões (como postgres, conferindo o que cada papel pode)
-- ---------------------------------------------------------------
reset role;
reset request.jwt.claims;

-- Objetos novos em public nascem fechados para o anon.
-- Tudo num bloco só: cria, confere e apaga. Assim cada comando só é
-- analisado na hora de rodar, quando a tabela e a função já existem.
do $teste$ begin
  create table public.teste_rls_privilegios (id int);
  create function public.teste_rls_funcao() returns int language sql as $f$ select 1 $f$;

  insert into teste_rls.resultado (teste, esperado, obtido) values
    ('Tabela nova nasce sem acesso para anon', 'false',
     has_table_privilege('anon', 'public.teste_rls_privilegios', 'select')::text),
    ('Função nova nasce sem execute para anon', 'false',
     has_function_privilege('anon', 'public.teste_rls_funcao()', 'execute')::text),
    ('Função nova continua liberada para authenticated', 'true',
     has_function_privilege('authenticated', 'public.teste_rls_funcao()', 'execute')::text);

  drop table public.teste_rls_privilegios;
  drop function public.teste_rls_funcao();
end $teste$;

-- Função que grava alterações: search_path fixo, executável pelo usuário
-- logado (é o trigger que a chama), fechada para o anon
insert into teste_rls.resultado (teste, esperado, obtido)
select 'registrar_alteracao_imovel tem search_path fixo', 'true',
       coalesce('search_path=""' = any (proconfig), false)::text
from pg_proc
where oid = 'privado.registrar_alteracao_imovel(uuid, text, text, text)'::regprocedure;

insert into teste_rls.resultado (teste, esperado, obtido) values
  ('authenticated executa registrar_alteracao_imovel', 'true',
   has_function_privilege('authenticated', 'privado.registrar_alteracao_imovel(uuid, text, text, text)', 'execute')::text),
  ('anon não executa registrar_alteracao_imovel', 'false',
   has_function_privilege('anon', 'privado.registrar_alteracao_imovel(uuid, text, text, text)', 'execute')::text);

-- ---------------------------------------------------------------
-- 10. Cadastro e perfis (Etapa 3)
-- ---------------------------------------------------------------
-- Simula o Supabase Auth criando um usuário com os dados do formulário
-- (raw_user_meta_data), o que dispara o trigger criar_perfil_no_cadastro.
-- Todo cadastro é desfeito no final (TR001); nada fica no banco.

-- Tenta cadastrar e devolve "permitido" ou "bloqueado (código)"
create function teste_rls.tentar_cadastro(p_dados jsonb)
returns text
language plpgsql
as $$
begin
  begin
    insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data)
    values ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-0000000000c1',
            'authenticated', 'authenticated', 'cadastro@teste.local', p_dados);
    raise exception 'desfazer' using errcode = 'TR001';
  exception when sqlstate 'TR001' then
    return 'permitido';
  end;
exception when others then
  return teste_rls.bloqueio(sqlstate, sqlerrm);
end;
$$;

-- Cadastra e descreve o perfil criado: "tipo | telefone | imobiliária"
create function teste_rls.perfil_criado(p_dados jsonb)
returns text
language plpgsql
as $$
declare
  v text;
begin
  begin
    insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data)
    values ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-0000000000c1',
            'authenticated', 'authenticated', 'cadastro@teste.local', p_dados);

    select p.tipo || ' | ' || coalesce(p.telefone, 'sem telefone') || ' | ' ||
           case
             when i.id is null then 'sem imobiliária'
             when i.id::text like 'bbbbbbbb-%' then 'imobiliária JÁ EXISTENTE'
             else 'imobiliária nova ' || i.status_assinatura || ' ' || i.creci
           end
    into v
    from public.perfis p
    left join public.imobiliarias i on i.id = p.imobiliaria_id
    where p.id = '00000000-0000-4000-a000-0000000000c1';

    raise exception 'desfazer' using errcode = 'TR001';
  exception when sqlstate 'TR001' then
    return coalesce(v, 'sem perfil');
  end;
exception when others then
  return 'erro inesperado: ' || sqlstate || ' ' || sqlerrm;
end;
$$;

insert into teste_rls.resultado (teste, esperado, obtido) values
  ('Cadastro como admin é recusado', 'bloqueado (P0001)',
   teste_rls.tentar_cadastro('{"tipo":"admin","nome":"Hacker","telefone":"11987654321"}')),
  ('Cadastro com tipo inventado é recusado', 'bloqueado (P0001)',
   teste_rls.tentar_cadastro('{"tipo":"corretor","nome":"X","telefone":"11987654321"}')),
  ('Cadastro com tipo vazio é recusado', 'bloqueado (P0001)',
   teste_rls.tentar_cadastro('{"tipo":null,"nome":"X","telefone":"11987654321"}')),
  ('Cadastro sem nome é recusado', 'bloqueado (P0001)',
   teste_rls.tentar_cadastro('{"tipo":"proprietario","nome":"  ","telefone":"11987654321"}')),
  ('Cadastro sem telefone é recusado', 'bloqueado (P0001)',
   teste_rls.tentar_cadastro('{"tipo":"proprietario","nome":"X"}')),
  ('Cadastro com telefone sem DDD é recusado', 'bloqueado (P0001)',
   teste_rls.tentar_cadastro('{"tipo":"proprietario","nome":"X","telefone":"98765-4321"}')),
  ('Cadastro com DDD inválido (01) é recusado', 'bloqueado (P0001)',
   teste_rls.tentar_cadastro('{"tipo":"proprietario","nome":"X","telefone":"01987654321"}')),
  ('Cadastro de imobiliária sem CRECI é recusado', 'bloqueado (P0001)',
   teste_rls.tentar_cadastro('{"tipo":"imobiliaria","nome":"X","telefone":"11987654321","imobiliaria_nome":"Imob"}')),
  ('Cadastro de imobiliária sem nome da imobiliária é recusado', 'bloqueado (P0001)',
   teste_rls.tentar_cadastro('{"tipo":"imobiliaria","nome":"X","telefone":"11987654321","creci":"TESTE-CAD-1"}')),
  ('Cadastro com CRECI já usado é recusado (maiúscula/minúscula não importa)', 'bloqueado (23505)',
   teste_rls.tentar_cadastro('{"tipo":"imobiliaria","nome":"X","telefone":"11987654321","imobiliaria_nome":"Imob","creci":" teste-0001 "}'));

-- "Cadastro recusado não deixa usuário em auth.users" não é testável aqui
-- (as funções acima sempre desfazem o cadastro). Esse caso é conferido no
-- teste manual pelo app: cadastro como admin pelo console do navegador.
insert into teste_rls.resultado (teste, esperado, obtido) values
  ('Usuário criado sem tipo (SQL Editor) fica sem perfil', 'sem perfil',
   teste_rls.perfil_criado('{}')),
  ('Proprietário: telefone normalizado e sem imobiliária, mesmo se enviar dados de imobiliária',
   'proprietario | 11987654321 | sem imobiliária',
   teste_rls.perfil_criado('{"tipo":"proprietario","nome":"Prop","telefone":"(11) 98765-4321",
                             "imobiliaria_id":"bbbbbbbb-0000-4000-a000-000000000001",
                             "imobiliaria_nome":"Imob","creci":"TESTE-CAD-1"}')),
  ('Telefone fixo com +55 é aceito e normalizado',
   'proprietario | 2133334444 | sem imobiliária',
   teste_rls.perfil_criado('{"tipo":"proprietario","nome":"Prop","telefone":"+55 (21) 3333-4444"}')),
  ('Imobiliária nasce nova e pendente, ignorando status e imobiliaria_id enviados',
   'imobiliaria | 11987654321 | imobiliária nova pendente TESTE-CAD-2',
   teste_rls.perfil_criado('{"tipo":"imobiliaria","nome":"Corretor","telefone":"11987654321",
                             "imobiliaria_nome":"Imob Nova","creci":"teste-cad-2",
                             "status_assinatura":"ativa",
                             "imobiliaria_id":"bbbbbbbb-0000-4000-a000-000000000001"}'));

-- Usuário logado tentando criar perfil ou imobiliária direto pelo app
set role authenticated;
set request.jwt.claims = '{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated"}';

do $$ begin
  insert into public.perfis (id, tipo, nome, telefone)
  values ('00000000-0000-4000-a000-000000000002', 'admin', 'Furão', null);
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Usuário logado não cria perfil pelo app', 'bloqueado (42501)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Usuário logado não cria perfil pelo app', 'bloqueado (42501)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

do $$ begin
  insert into public.imobiliarias (nome, creci, status_assinatura)
  values ('Furona', 'TESTE-CAD-3', 'ativa');
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Usuário logado não cria imobiliária pelo app', 'bloqueado (42501)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Usuário logado não cria imobiliária pelo app', 'bloqueado (42501)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

do $$ begin
  update public.perfis set telefone = null where id = '00000000-0000-4000-a000-000000000002';
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não apaga o próprio telefone', 'bloqueado (23514)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não apaga o próprio telefone', 'bloqueado (23514)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

do $$ begin
  update public.perfis set telefone = '1234' where id = '00000000-0000-4000-a000-000000000002';
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não grava telefone em formato inválido', 'bloqueado (23514)', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não grava telefone em formato inválido', 'bloqueado (23514)', teste_rls.bloqueio(sqlstate, sqlerrm));
end $$;

do $$ declare n int; begin
  begin
    update public.perfis set telefone = '21987654321' where id = '00000000-0000-4000-a000-000000000002';
    get diagnostics n = row_count;
    raise exception 'desfazer' using errcode = 'TR001';
  exception when sqlstate 'TR001' then null;
  end;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário troca o próprio telefone por um válido', '1 linhas', n || ' linhas');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário troca o próprio telefone por um válido', '1 linhas', 'erro inesperado: ' || sqlstate || ' ' || sqlerrm);
end $$;

reset role;
reset request.jwt.claims;

-- A função do trigger: search_path fixo, roda como dono, ninguém chama pelo app
insert into teste_rls.resultado (teste, esperado, obtido)
select 'criar_perfil_no_cadastro tem search_path fixo e é security definer', 'true',
       (coalesce('search_path=""' = any (proconfig), false) and prosecdef)::text
from pg_proc
where oid = 'privado.criar_perfil_no_cadastro()'::regprocedure;

insert into teste_rls.resultado (teste, esperado, obtido) values
  ('authenticated não executa criar_perfil_no_cadastro', 'false',
   has_function_privilege('authenticated', 'privado.criar_perfil_no_cadastro()', 'execute')::text),
  ('anon não executa criar_perfil_no_cadastro', 'false',
   has_function_privilege('anon', 'privado.criar_perfil_no_cadastro()', 'execute')::text);

-- ---------------------------------------------------------------
-- 11. Limpeza e resultado
-- ---------------------------------------------------------------
delete from public.propostas where reserva_id in ('dddddddd-0000-4000-a000-000000000001',
                                                  'dddddddd-0000-4000-a000-000000000002');
delete from public.visitas   where reserva_id in ('dddddddd-0000-4000-a000-000000000001',
                                                  'dddddddd-0000-4000-a000-000000000002');
delete from public.reservas  where id in ('dddddddd-0000-4000-a000-000000000001',
                                          'dddddddd-0000-4000-a000-000000000002');
delete from public.imoveis   where proprietario_id in ('00000000-0000-4000-a000-000000000002',
                                                       '00000000-0000-4000-a000-000000000003');
delete from auth.users where id in ('00000000-0000-4000-a000-000000000001',
                                    '00000000-0000-4000-a000-000000000002',
                                    '00000000-0000-4000-a000-000000000003',
                                    '00000000-0000-4000-a000-000000000004',
                                    '00000000-0000-4000-a000-000000000005',
                                    '00000000-0000-4000-a000-000000000006',
                                    '00000000-0000-4000-a000-000000000007');
delete from public.imobiliarias where id in ('bbbbbbbb-0000-4000-a000-000000000001',
                                             'bbbbbbbb-0000-4000-a000-000000000002',
                                             'bbbbbbbb-0000-4000-a000-000000000003');

select ordem, teste, esperado, obtido,
       case when esperado = obtido then '✅ passou' else '❌ FALHOU' end as resultado
from teste_rls.resultado
order by ordem;
