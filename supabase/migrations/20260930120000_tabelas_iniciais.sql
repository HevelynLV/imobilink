-- Etapa 2 · Tabelas iniciais do Captador
-- Rodar no SQL Editor do Supabase ANTES do arquivo de RLS.

-- ---------------------------------------------------------------
-- imobiliarias: empresas assinantes
-- ---------------------------------------------------------------
create table public.imobiliarias (
  id                uuid primary key default gen_random_uuid(),
  nome              text not null,
  creci             text not null unique,
  status_assinatura text not null default 'pendente'
                    check (status_assinatura in ('pendente', 'ativa', 'bloqueada')),
  criado_em         timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- perfis: um por usuário do Supabase Auth
-- ---------------------------------------------------------------
create table public.perfis (
  id             uuid primary key references auth.users (id) on delete cascade,
  tipo           text not null check (tipo in ('proprietario', 'imobiliaria', 'admin')),
  nome           text not null,
  telefone       text,  -- contato: só o próprio usuário e o admin leem (ver RLS)
  imobiliaria_id uuid references public.imobiliarias (id),
  criado_em      timestamptz not null default now(),

  -- corretor (tipo imobiliaria) precisa estar ligado a uma imobiliária;
  -- os outros tipos não podem estar
  constraint perfis_imobiliaria_so_para_corretor check (
    (tipo = 'imobiliaria' and imobiliaria_id is not null)
    or (tipo <> 'imobiliaria' and imobiliaria_id is null)
  )
);

create index perfis_imobiliaria_id_idx on public.perfis (imobiliaria_id);

-- ---------------------------------------------------------------
-- imoveis
-- ---------------------------------------------------------------
create table public.imoveis (
  id              uuid primary key default gen_random_uuid(),
  proprietario_id uuid not null references public.perfis (id),
  titulo          text not null,
  descricao       text,
  tipo            text not null check (tipo in ('apartamento', 'casa', 'terreno', 'comercial')),
  endereco        text,
  bairro          text not null,
  preco           numeric(12, 2) not null check (preco > 0),
  quartos         integer check (quartos >= 0),
  banheiros       integer check (banheiros >= 0),
  vagas           integer check (vagas >= 0),
  area_m2         numeric(8, 2) check (area_m2 > 0),
  status          text not null default 'pendente_aprovacao'
                  check (status in ('pendente_aprovacao', 'reprovado', 'disponivel',
                                    'reservado', 'em_proposta', 'vendido')),
  termo_aceito_em timestamptz not null,
  aprovado_em     timestamptz,
  criado_em       timestamptz not null default now(),
  atualizado_em   timestamptz not null default now()
);

create index imoveis_proprietario_id_idx on public.imoveis (proprietario_id);
create index imoveis_status_idx on public.imoveis (status);

-- ---------------------------------------------------------------
-- fotos_imovel
-- ---------------------------------------------------------------
create table public.fotos_imovel (
  id              uuid primary key default gen_random_uuid(),
  imovel_id       uuid not null references public.imoveis (id) on delete cascade,
  caminho_storage text not null unique,
  ordem           integer not null default 0,
  criado_em       timestamptz not null default now()
);

create index fotos_imovel_imovel_id_idx on public.fotos_imovel (imovel_id);

-- ---------------------------------------------------------------
-- reservas
-- ---------------------------------------------------------------
create table public.reservas (
  id             uuid primary key default gen_random_uuid(),
  imovel_id      uuid not null references public.imoveis (id),
  imobiliaria_id uuid not null references public.imobiliarias (id),
  corretor_id    uuid not null references public.perfis (id),
  inicio         timestamptz not null default now(),
  fim            timestamptz not null,  -- prazo da reserva ainda em aberto (Etapa 7)
  status         text not null default 'ativa'
                 check (status in ('ativa', 'expirada', 'cancelada', 'convertida')),
  criado_em      timestamptz not null default now(),
  constraint reservas_fim_depois_do_inicio check (fim > inicio)
);

-- no máximo UMA reserva ativa por imóvel, garantido pelo banco
create unique index reservas_uma_ativa_por_imovel
  on public.reservas (imovel_id) where status = 'ativa';

create index reservas_imobiliaria_id_idx on public.reservas (imobiliaria_id);
create index reservas_corretor_id_idx on public.reservas (corretor_id);

-- ---------------------------------------------------------------
-- visitas
-- ---------------------------------------------------------------
create table public.visitas (
  id          uuid primary key default gen_random_uuid(),
  reserva_id  uuid not null references public.reservas (id),
  data_hora   timestamptz not null,
  status      text not null default 'agendada'
              check (status in ('agendada', 'realizada', 'cancelada')),
  observacoes text,
  criado_em   timestamptz not null default now()
);

create index visitas_reserva_id_idx on public.visitas (reserva_id);

-- ---------------------------------------------------------------
-- propostas
-- ---------------------------------------------------------------
create table public.propostas (
  id         uuid primary key default gen_random_uuid(),
  reserva_id uuid not null references public.reservas (id),
  valor      numeric(12, 2) not null check (valor > 0),
  condicoes  text,
  status     text not null default 'enviada'
             check (status in ('enviada', 'aceita', 'recusada')),
  criado_em  timestamptz not null default now()
);

create index propostas_reserva_id_idx on public.propostas (reserva_id);
