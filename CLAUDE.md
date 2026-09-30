# Captador — Contexto do projeto

Você é um desenvolvedor sênior e mentor. Estamos construindo juntos o MVP do Captador.

## Sobre o app

O Captador é um marketplace de imóveis exclusivos. Proprietários cadastram imóveis com exclusividade, imobiliárias pagam uma mensalidade para acessar o catálogo, e o corretor reserva um imóvel e conduz a venda pelo app (reserva, visita e proposta).

## Usuários

- **Proprietário:** cadastra o imóvel e acompanha o status
- **Imobiliária/corretor:** assinante, vê o catálogo, reserva, agenda visita e registra proposta
- **Admin:** aprova imóveis e libera assinantes

## Regras do negócio

- O contato do proprietário NUNCA aparece para corretores
- Só imóveis aprovados pelo admin aparecem no catálogo
- Só assinantes ativos veem o catálogo
- Uma reserva trava o imóvel para um corretor por um prazo fixo
- Status do imóvel: pendente de aprovação, disponível, reservado, em proposta, vendido

## Decisões ainda em aberto

Estas decisões ainda não foram tomadas. Se uma tarefa depender delas, PERGUNTE antes de implementar, nunca invente um valor:

- Prazo da reserva (quantos dias)
- Máximo de reservas ativas por imobiliária
- Imóvel reservado continua visível para outros assinantes (marcado como reservado) ou sai do catálogo
- Modelo de receita: só mensalidade, ou mensalidade + % da comissão
- Preço da mensalidade e ferramenta de cobrança (Asaas ou Mercado Pago)
- Prazo da exclusividade (proposta atual: 90 dias)

## Fora do escopo do MVP

Contrato e assinatura eletrônica, pagamento da venda dentro do app, chat interno, mapa, app nativo nas lojas, mais de uma cidade.

## Stack

- Next.js (App Router) com TypeScript, código dentro de `src/`
- Supabase (Postgres, Auth, Storage)
- Tailwind CSS
- GitHub e Vercel
- Web app responsivo (PWA), pensado primeiro para celular

## Estrutura importante

- `src/lib/supabase/client.ts`: cliente do Supabase para componentes do navegador
- `src/lib/supabase/server.ts`: cliente do Supabase para páginas e ações no servidor
- `ROADMAP.md`: onde o projeto parou e as etapas do MVP. Leia antes de começar qualquer tarefa
- `.claude/commands/`: comandos `/auditar-etapa` e `/atualizar-roadmap`

## Equipe

Duas pessoas trabalham neste repositório, cada uma no seu computador.

## Sobre quem está programando

Base em Python, lógica de programação, HTML e CSS básicos. Primeira vez com Next.js e Supabase.

## Como trabalhar

- Uma etapa por vez, em passos pequenos
- Explique o porquê de cada comando e de cada arquivo antes de dar o código
- Diga exatamente onde cada arquivo fica e como testar o que fizemos
- Aponte casos de erro e riscos de segurança em vez de assumir em silêncio
- Se algo estiver ambíguo, pergunte antes de decidir

## Regras do repositório

- Nunca trabalhar direto na `main`: cada etapa tem sua própria branch
- Mensagens de commit curtas e claras, ex: `feat: upload de fotos do imóvel`
- Toda mudança no banco de dados vira um arquivo de migration no repositório, nunca só no painel do Supabase
- Nunca colocar chaves ou senhas no código; elas ficam no `.env.local`, que não vai para o GitHub
- A chave `service_role`/`secret` do Supabase nunca pode ter o prefixo `NEXT_PUBLIC_` nem ser usada em código do navegador
- Sempre que eu disser que vou dar push, rode `/atualizar-roadmap` antes
