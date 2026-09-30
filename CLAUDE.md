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
- Modelo de receita: só mensalidade, ou mensalidade + % da comissão
- Preço da mensalidade e ferramenta de cobrança (Asaas ou Mercado Pago)
- Prazo da exclusividade (proposta atual: 90 dias)

## Decisões tomadas

- Uma imobiliária pode ter vários corretores, cada um com login próprio (perfil tipo `imobiliaria` + `imobiliaria_id`)
- Imóvel reservado ou em proposta continua visível no catálogo, marcado com o status
- O endereço do imóvel fica visível para qualquer assinante ativo (sem tabela privada). Decisão mantida depois da auditoria da Etapa 2 (30/09/2026): a proteção contra desintermediação (imobiliária pegar o endereço e ir direto ao proprietário) será contratual, por uma cláusula no termo de assinatura da imobiliária
- O admin pode reprovar imóvel (status `reprovado`)
- Edição de imóvel aprovado (`disponivel`) vale na hora, sem nova aprovação. Cada campo alterado, inclusive fotos, é registrado na tabela `alteracoes_imovel`, que só o admin lê e marca como revisada. Risco aceito: a edição fica visível no catálogo até a revisão. Edição feita pelo admin não é registrada
- Imóvel reservado, em proposta ou vendido não pode ser editado pelo proprietário (nem as fotos)
- Imóvel reprovado é editado e reenviado pelo proprietário por um passo explícito (`reprovado` → `pendente_aprovacao`); editar não reenvia sozinho
- O proprietário só apaga imóvel pendente de aprovação ou reprovado
- O proprietário vê visitas e propostas do próprio imóvel só pelas funções `visitas_do_meu_imovel()` e `propostas_do_meu_imovel()`, que devolvem data, status e valor, sem os dados do corretor/imobiliária e sem texto livre do corretor (`observacoes`, `condicoes`)
- Migrations são aplicadas à mão pelo SQL Editor do Supabase, em ordem de nome. Por isso o histórico de migrations do Supabase fica vazio: não rodar `supabase db push` sem antes marcar as já aplicadas com `supabase migration repair --status applied <versão>`

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
