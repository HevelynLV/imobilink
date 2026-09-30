-- Etapa 2 · Segurança: Row Level Security (RLS) e travas de campos
-- Rodar no SQL Editor do Supabase DEPOIS de 20260930120000_tabelas_iniciais.sql.

-- ===============================================================
-- 1. Funções auxiliares
-- ===============================================================
-- São "security definer": rodam com permissão do dono da função e
-- por isso conseguem consultar perfis/reservas sem passar pelo RLS.
-- Sem isso, uma regra de perfis que consulta perfis entraria em loop.
-- Cada uma só responde sobre o PRÓPRIO usuário logado (auth.uid()).

create or replace function public.eh_admin()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.perfis
    where id = (select auth.uid()) and tipo = 'admin'
  );
$$;

create or replace function public.minha_imobiliaria_id()
returns uuid
language sql stable security definer set search_path = ''
as $$
  select imobiliaria_id from public.perfis
  where id = (select auth.uid()) and tipo = 'imobiliaria';
$$;

create or replace function public.assinante_ativo()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.perfis p
    join public.imobiliarias i on i.id = p.imobiliaria_id
    where p.id = (select auth.uid())
      and p.tipo = 'imobiliaria'
      and i.status_assinatura = 'ativa'
  );
$$;

create or replace function public.reserva_do_meu_imovel(p_reserva_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.reservas r
    join public.imoveis im on im.id = r.imovel_id
    where r.id = p_reserva_id
      and im.proprietario_id = (select auth.uid())
  );
$$;

-- Só usuários logados podem chamar essas funções
revoke execute on function public.eh_admin() from public, anon;
revoke execute on function public.minha_imobiliaria_id() from public, anon;
revoke execute on function public.assinante_ativo() from public, anon;
revoke execute on function public.reserva_do_meu_imovel(uuid) from public, anon;
grant execute on function public.eh_admin() to authenticated;
grant execute on function public.minha_imobiliaria_id() to authenticated;
grant execute on function public.assinante_ativo() to authenticated;
grant execute on function public.reserva_do_meu_imovel(uuid) to authenticated;

-- ===============================================================
-- 2. Permissões de tabela
-- ===============================================================
-- Visitante não logado (anon) não acessa nada. Usuário logado
-- (authenticated) pode tentar, e o RLS decide linha por linha.

revoke all on public.perfis, public.imobiliarias, public.imoveis, public.fotos_imovel,
              public.reservas, public.visitas, public.propostas
  from anon;

grant select, insert, update, delete
  on public.perfis, public.imobiliarias, public.imoveis, public.fotos_imovel,
     public.reservas, public.visitas, public.propostas
  to authenticated;

alter table public.perfis       enable row level security;
alter table public.imobiliarias enable row level security;
alter table public.imoveis      enable row level security;
alter table public.fotos_imovel enable row level security;
alter table public.reservas     enable row level security;
alter table public.visitas      enable row level security;
alter table public.propostas    enable row level security;

-- ===============================================================
-- 3. Admin: acesso total em todas as tabelas
-- ===============================================================
create policy admin_tudo on public.perfis       for all to authenticated
  using ((select public.eh_admin())) with check ((select public.eh_admin()));
create policy admin_tudo on public.imobiliarias for all to authenticated
  using ((select public.eh_admin())) with check ((select public.eh_admin()));
create policy admin_tudo on public.imoveis      for all to authenticated
  using ((select public.eh_admin())) with check ((select public.eh_admin()));
create policy admin_tudo on public.fotos_imovel for all to authenticated
  using ((select public.eh_admin())) with check ((select public.eh_admin()));
create policy admin_tudo on public.reservas     for all to authenticated
  using ((select public.eh_admin())) with check ((select public.eh_admin()));
create policy admin_tudo on public.visitas      for all to authenticated
  using ((select public.eh_admin())) with check ((select public.eh_admin()));
create policy admin_tudo on public.propostas    for all to authenticated
  using ((select public.eh_admin())) with check ((select public.eh_admin()));

-- ===============================================================
-- 4. perfis: cada um vê e edita só o próprio (contato protegido)
-- ===============================================================
create policy perfil_ver_o_proprio on public.perfis for select to authenticated
  using (id = (select auth.uid()));

create policy perfil_editar_o_proprio on public.perfis for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));
-- Sem regra de insert: a criação do perfil no cadastro entra na Etapa 3.

-- ===============================================================
-- 5. imobiliarias: corretor vê só a própria (para saber o status)
-- ===============================================================
create policy imobiliaria_ver_a_propria on public.imobiliarias for select to authenticated
  using (id = (select public.minha_imobiliaria_id()));
-- Sem regra de update para corretor: só o admin muda status_assinatura.

-- ===============================================================
-- 6. imoveis
-- ===============================================================
create policy imovel_proprietario_ver on public.imoveis for select to authenticated
  using (proprietario_id = (select auth.uid()));

create policy imovel_proprietario_cadastrar on public.imoveis for insert to authenticated
  with check (
    proprietario_id = (select auth.uid())
    and status = 'pendente_aprovacao'
    and aprovado_em is null
    and exists (select 1 from public.perfis
                where id = (select auth.uid()) and tipo = 'proprietario')
  );

create policy imovel_proprietario_editar on public.imoveis for update to authenticated
  using (proprietario_id = (select auth.uid()))
  with check (proprietario_id = (select auth.uid()));

create policy imovel_proprietario_excluir on public.imoveis for delete to authenticated
  using (proprietario_id = (select auth.uid())
         and status in ('pendente_aprovacao', 'reprovado'));

-- Catálogo: só assinante ativo, só imóveis aprovados.
-- Reservado e em proposta continuam visíveis (decisão da Etapa 2).
create policy imovel_catalogo_assinante on public.imoveis for select to authenticated
  using (
    (select public.assinante_ativo())
    and status in ('disponivel', 'reservado', 'em_proposta')
  );

-- ===============================================================
-- 7. fotos_imovel: segue a visibilidade do imóvel
-- ===============================================================
-- A subconsulta em imoveis também passa pelo RLS de imoveis:
-- se você não enxerga o imóvel, não enxerga as fotos dele.
create policy foto_ver on public.fotos_imovel for select to authenticated
  using (exists (select 1 from public.imoveis i where i.id = imovel_id));

create policy foto_proprietario_gerenciar on public.fotos_imovel for all to authenticated
  using (exists (select 1 from public.imoveis i
                 where i.id = imovel_id and i.proprietario_id = (select auth.uid())))
  with check (exists (select 1 from public.imoveis i
                      where i.id = imovel_id and i.proprietario_id = (select auth.uid())));

-- ===============================================================
-- 8. reservas, visitas, propostas: por enquanto só LEITURA
-- ===============================================================
-- Criar/alterar reserva, visita e proposta entra na Etapa 7, junto com
-- o prazo da reserva e o limite por imobiliária (decisões em aberto).

create policy reserva_ver_da_minha_imobiliaria on public.reservas for select to authenticated
  using (
    imobiliaria_id = (select public.minha_imobiliaria_id())
    and (select public.assinante_ativo())
  );
-- Proprietário NÃO lê reservas (lá estão corretor e imobiliária).

-- Imobiliária: a subconsulta em reservas passa pelo RLS de reservas.
-- Proprietário: vê visitas/propostas do próprio imóvel, sem dados do corretor.
create policy visita_ver on public.visitas for select to authenticated
  using (
    exists (select 1 from public.reservas r where r.id = reserva_id)
    or public.reserva_do_meu_imovel(reserva_id)
  );

create policy proposta_ver on public.propostas for select to authenticated
  using (
    exists (select 1 from public.reservas r where r.id = reserva_id)
    or public.reserva_do_meu_imovel(reserva_id)
  );

-- ===============================================================
-- 9. Travas de campos (o RLS filtra linhas, não colunas)
-- ===============================================================
-- Valem só para chamadas do app (current_user = 'authenticated').
-- O SQL Editor e as funções internas do banco não são afetados.

create or replace function public.proteger_campos_perfil()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if current_user = 'authenticated' and not public.eh_admin() then
    if new.tipo is distinct from old.tipo
       or new.imobiliaria_id is distinct from old.imobiliaria_id then
      raise exception 'Você não pode alterar o tipo do perfil nem a imobiliária';
    end if;
  end if;
  return new;
end;
$$;

create trigger perfis_proteger_campos
  before update on public.perfis
  for each row execute function public.proteger_campos_perfil();

create or replace function public.proteger_campos_imovel()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if current_user = 'authenticated' and not public.eh_admin() then
    if new.status is distinct from old.status
       or new.aprovado_em is distinct from old.aprovado_em
       or new.termo_aceito_em is distinct from old.termo_aceito_em then
      raise exception 'Só o admin pode alterar status, aprovação ou aceite do termo';
    end if;
  end if;

  -- registra a data da aprovação automaticamente
  if old.status = 'pendente_aprovacao' and new.status = 'disponivel' then
    new.aprovado_em := now();
  end if;

  new.atualizado_em := now();
  return new;
end;
$$;

create trigger imoveis_proteger_campos
  before update on public.imoveis
  for each row execute function public.proteger_campos_imovel();
