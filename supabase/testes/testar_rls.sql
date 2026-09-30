-- Roteiro de teste do RLS · Etapa 2
-- Como usar: cole o arquivo inteiro no SQL Editor do Supabase e clique em Run.
-- O resultado é uma tabela: toda linha deve mostrar "✅ passou".
-- Usa só IDs fictícios fixos (abaixo) e apaga esses dados no final.
-- Pode rodar quantas vezes quiser.
--
-- Usuários fictícios:
--   ...0001 admin
--   ...0002 proprietário 1 (imóveis: 1 disponível, 2 pendente)
--   ...0003 proprietário 2 (imóveis: 3 reservado, 4 vendido)
--   ...0004 corretor da imobiliária ATIVA (tem reserva no imóvel 3)
--   ...0005 corretor da imobiliária BLOQUEADA

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

delete from public.propostas where reserva_id = 'dddddddd-0000-4000-a000-000000000001';
delete from public.visitas   where reserva_id = 'dddddddd-0000-4000-a000-000000000001';
delete from public.reservas  where id = 'dddddddd-0000-4000-a000-000000000001';
delete from public.imoveis   where proprietario_id in ('00000000-0000-4000-a000-000000000002',
                                                       '00000000-0000-4000-a000-000000000003');
delete from auth.users where id in ('00000000-0000-4000-a000-000000000001',
                                    '00000000-0000-4000-a000-000000000002',
                                    '00000000-0000-4000-a000-000000000003',
                                    '00000000-0000-4000-a000-000000000004',
                                    '00000000-0000-4000-a000-000000000005');
delete from public.imobiliarias where id in ('bbbbbbbb-0000-4000-a000-000000000001',
                                             'bbbbbbbb-0000-4000-a000-000000000002');

-- ---------------------------------------------------------------
-- 1. Dados fictícios (inseridos como postgres, que ignora o RLS)
-- ---------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000001', 'authenticated', 'authenticated', 'admin@teste.local'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000002', 'authenticated', 'authenticated', 'prop1@teste.local'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000003', 'authenticated', 'authenticated', 'prop2@teste.local'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000004', 'authenticated', 'authenticated', 'corretor.ativo@teste.local'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000005', 'authenticated', 'authenticated', 'corretor.bloq@teste.local');

insert into public.imobiliarias (id, nome, creci, status_assinatura) values
  ('bbbbbbbb-0000-4000-a000-000000000001', 'Imob Ativa (teste)',     'TESTE-0001', 'ativa'),
  ('bbbbbbbb-0000-4000-a000-000000000002', 'Imob Bloqueada (teste)', 'TESTE-0002', 'bloqueada');

insert into public.perfis (id, tipo, nome, telefone, imobiliaria_id) values
  ('00000000-0000-4000-a000-000000000001', 'admin',        'Admin',          null,            null),
  ('00000000-0000-4000-a000-000000000002', 'proprietario', 'Proprietário 1', '11 90000-0001', null),
  ('00000000-0000-4000-a000-000000000003', 'proprietario', 'Proprietário 2', '11 90000-0002', null),
  ('00000000-0000-4000-a000-000000000004', 'imobiliaria',  'Corretor Ativo', '11 90000-0004', 'bbbbbbbb-0000-4000-a000-000000000001'),
  ('00000000-0000-4000-a000-000000000005', 'imobiliaria',  'Corretor Bloq',  '11 90000-0005', 'bbbbbbbb-0000-4000-a000-000000000002');

insert into public.imoveis (id, proprietario_id, titulo, tipo, bairro, preco, status, termo_aceito_em) values
  ('cccccccc-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000002', 'Imóvel 1', 'apartamento', 'Centro', 500000, 'disponivel',         now()),
  ('cccccccc-0000-4000-a000-000000000002', '00000000-0000-4000-a000-000000000002', 'Imóvel 2', 'casa',        'Centro', 700000, 'pendente_aprovacao', now()),
  ('cccccccc-0000-4000-a000-000000000003', '00000000-0000-4000-a000-000000000003', 'Imóvel 3', 'apartamento', 'Jardim', 400000, 'reservado',          now()),
  ('cccccccc-0000-4000-a000-000000000004', '00000000-0000-4000-a000-000000000003', 'Imóvel 4', 'casa',        'Jardim', 900000, 'vendido',            now());

insert into public.fotos_imovel (imovel_id, caminho_storage) values
  ('cccccccc-0000-4000-a000-000000000001', 'teste/imovel1.jpg'),
  ('cccccccc-0000-4000-a000-000000000002', 'teste/imovel2.jpg');

insert into public.reservas (id, imovel_id, imobiliaria_id, corretor_id, fim) values
  ('dddddddd-0000-4000-a000-000000000001', 'cccccccc-0000-4000-a000-000000000003',
   'bbbbbbbb-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000004', now() + interval '7 days');

insert into public.visitas (reserva_id, data_hora) values
  ('dddddddd-0000-4000-a000-000000000001', now() + interval '1 day');

insert into public.propostas (reserva_id, valor) values
  ('dddddddd-0000-4000-a000-000000000001', 380000);

-- ---------------------------------------------------------------
-- 2. Testes como PROPRIETÁRIO 1
-- ---------------------------------------------------------------
set role authenticated;
set request.jwt.claims = '{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated"}';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Proprietário vê só os próprios imóveis', '2', count(*)::text
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
  values ('Proprietário não aprova o próprio imóvel', 'bloqueado', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não aprova o próprio imóvel', 'bloqueado', 'bloqueado');
end $$;

do $$ begin
  insert into public.imoveis (proprietario_id, titulo, tipo, bairro, preco, termo_aceito_em)
  values ('00000000-0000-4000-a000-000000000002', 'Novo', 'casa', 'Centro', 300000, now());
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário cadastra imóvel pendente', 'permitido', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário cadastra imóvel pendente', 'permitido', 'bloqueado: ' || sqlerrm);
end $$;

do $$ begin
  insert into public.imoveis (proprietario_id, titulo, tipo, bairro, preco, status, termo_aceito_em)
  values ('00000000-0000-4000-a000-000000000002', 'Furão', 'casa', 'Centro', 300000, 'disponivel', now());
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não cadastra imóvel já aprovado', 'bloqueado', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não cadastra imóvel já aprovado', 'bloqueado', 'bloqueado');
end $$;

do $$ begin
  update public.perfis set tipo = 'admin' where id = '00000000-0000-4000-a000-000000000002';
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não vira admin', 'bloqueado', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Proprietário não vira admin', 'bloqueado', 'bloqueado');
end $$;

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Proprietário não vê visitas de imóvel alheio', '0', count(*)::text
from public.visitas where reserva_id = 'dddddddd-0000-4000-a000-000000000001';

-- ---------------------------------------------------------------
-- 3. Testes como PROPRIETÁRIO 2 (dono do imóvel reservado)
-- ---------------------------------------------------------------
set request.jwt.claims = '{"sub":"00000000-0000-4000-a000-000000000003","role":"authenticated"}';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Proprietário vê visitas do próprio imóvel', '1', count(*)::text
from public.visitas where reserva_id = 'dddddddd-0000-4000-a000-000000000001';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Proprietário vê propostas do próprio imóvel', '1', count(*)::text
from public.propostas where reserva_id = 'dddddddd-0000-4000-a000-000000000001';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Proprietário não vê a reserva (dados do corretor)', '0', count(*)::text
from public.reservas where id = 'dddddddd-0000-4000-a000-000000000001';

-- ---------------------------------------------------------------
-- 4. Testes como CORRETOR da imobiliária ATIVA
-- ---------------------------------------------------------------
set request.jwt.claims = '{"sub":"00000000-0000-4000-a000-000000000004","role":"authenticated"}';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Assinante ativo vê só aprovados (disponível + reservado)', '2', count(*)::text
from public.imoveis where id::text like 'cccccccc-%' or proprietario_id::text like '00000000-0000-4000-a000-%';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Assinante ativo vê fotos só de imóvel aprovado', '1', count(*)::text
from public.fotos_imovel where caminho_storage like 'teste/%';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Assinante NÃO vê o contato do proprietário', '0', count(*)::text
from public.perfis where id in ('00000000-0000-4000-a000-000000000002', '00000000-0000-4000-a000-000000000003');

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Assinante vê a reserva da própria imobiliária', '1', count(*)::text
from public.reservas where id = 'dddddddd-0000-4000-a000-000000000001';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Assinante vê a visita da própria reserva', '1', count(*)::text
from public.visitas where reserva_id = 'dddddddd-0000-4000-a000-000000000001';

do $$ declare n int; begin
  update public.imoveis set status = 'disponivel', preco = 1 where id = 'cccccccc-0000-4000-a000-000000000003';
  get diagnostics n = row_count;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Assinante não altera imóvel do catálogo', '0 linhas', n || ' linhas');
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
from public.fotos_imovel where caminho_storage like 'teste/%';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Imobiliária bloqueada vê o próprio cadastro (status)', '1', count(*)::text
from public.imobiliarias where id::text like 'bbbbbbbb-%';

do $$ declare n int; begin
  update public.imobiliarias set status_assinatura = 'ativa' where id = 'bbbbbbbb-0000-4000-a000-000000000002';
  get diagnostics n = row_count;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Imobiliária não se desbloqueia sozinha', '0 linhas', n || ' linhas');
end $$;

-- ---------------------------------------------------------------
-- 6. Testes como ADMIN
-- ---------------------------------------------------------------
set request.jwt.claims = '{"sub":"00000000-0000-4000-a000-000000000001","role":"authenticated"}';

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Admin vê todos os imóveis (4 + o novo)', '5', count(*)::text
from public.imoveis where proprietario_id in ('00000000-0000-4000-a000-000000000002', '00000000-0000-4000-a000-000000000003');

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Admin vê o contato dos proprietários', '2', count(telefone)::text
from public.perfis where id in ('00000000-0000-4000-a000-000000000002', '00000000-0000-4000-a000-000000000003');

do $$ declare n int; begin
  update public.imoveis set status = 'disponivel' where id = 'cccccccc-0000-4000-a000-000000000002';
  get diagnostics n = row_count;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Admin aprova imóvel', '1 linhas', n || ' linhas');
end $$;

insert into teste_rls.resultado (teste, esperado, obtido)
select 'Aprovação grava a data em aprovado_em', 'true', (aprovado_em is not null)::text
from public.imoveis where id = 'cccccccc-0000-4000-a000-000000000002';

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
-- 7. Teste como VISITANTE SEM LOGIN (anon)
-- ---------------------------------------------------------------
reset role;
set role anon;
set request.jwt.claims = '{"role":"anon"}';

do $$ begin
  perform 1 from public.imoveis limit 1;
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Visitante sem login não lê imóveis', 'bloqueado', 'permitido');
exception when others then
  insert into teste_rls.resultado (teste, esperado, obtido)
  values ('Visitante sem login não lê imóveis', 'bloqueado', 'bloqueado');
end $$;

-- ---------------------------------------------------------------
-- 8. Limpeza e resultado
-- ---------------------------------------------------------------
reset role;
reset request.jwt.claims;

delete from public.propostas where reserva_id = 'dddddddd-0000-4000-a000-000000000001';
delete from public.visitas   where reserva_id = 'dddddddd-0000-4000-a000-000000000001';
delete from public.reservas  where id = 'dddddddd-0000-4000-a000-000000000001';
delete from public.imoveis   where proprietario_id in ('00000000-0000-4000-a000-000000000002',
                                                       '00000000-0000-4000-a000-000000000003');
delete from auth.users where id in ('00000000-0000-4000-a000-000000000001',
                                    '00000000-0000-4000-a000-000000000002',
                                    '00000000-0000-4000-a000-000000000003',
                                    '00000000-0000-4000-a000-000000000004',
                                    '00000000-0000-4000-a000-000000000005');
delete from public.imobiliarias where id in ('bbbbbbbb-0000-4000-a000-000000000001',
                                             'bbbbbbbb-0000-4000-a000-000000000002');

select ordem, teste, esperado, obtido,
       case when esperado = obtido then '✅ passou' else '❌ FALHOU' end as resultado
from teste_rls.resultado
order by ordem;
