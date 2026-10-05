# Captador — Roadmap

## Onde paramos

Última atualização: 05/10/2026 · por Hevelyn
Etapa atual: 4. Cadastro do imóvel (a Etapa 3 foi concluída; falta só o Pull Request ser aceito)

O que foi feito nesta sessão (Etapa 3, login e perfis):
- Cadastro com e-mail e senha, escolhendo proprietário ou imobiliária. Telefone com DDD é obrigatório. Imobiliária informa nome e CRECI e entra com assinatura "pendente"
- O perfil é criado pelo próprio banco no momento do cadastro (migration `20261005120000_cadastro_e_perfis.sql`). O banco só aceita "proprietário" ou "imobiliária": ninguém consegue se cadastrar como admin, nem mexendo na requisição
- Login, logout e recuperação de senha. Os links dos e-mails usam o modelo padrão do Supabase (o link só funciona no mesmo navegador em que foi pedido)
- Cada tipo de usuário vai para a sua área (`/proprietario`, `/imobiliaria`, `/admin`) e não consegue abrir a dos outros, nem digitando o endereço. São duas barreiras no app (`src/proxy.ts` e `exigirTipo()` em `src/lib/auth.ts`), além das regras do banco
- O admin é criado à mão: cadastro normal como proprietário e depois o script `supabase/scripts/criar_admin.sql` no SQL Editor
- Auditoria feita (nenhum problema crítico). Corrigidos: links dos e-mails passam a usar o `SITE_URL` do `.env.local`; aviso e botão Sair para quem está logado sem perfil; tela "Algo deu errado" quando o banco não responde; ajustes menores. O resto virou item em "Pendências"
- Testes automáticos com Playwright (`npm run test:e2e`): 15 testes passando, cobrindo os 3 tipos de usuário, a tentativa de virar admin, CRECI repetido e os links de e-mail falsos ou vencidos. `testar_rls.sql` com 93 testes passando
- README com o checklist "Como começar a trabalhar no Captador" para pessoa nova

Próximo passo exato:
- Abrir o Pull Request da branch `etapa-3-login-perfis` para a `main`. A outra pessoa faz o que está em "Atenção" abaixo, roda `npm run test:e2e` (tudo tem que passar) e aceita o PR
- Depois do PR aceito: `git checkout main`, `git pull`, `npm install` e criar a branch `etapa-4-cadastro-do-imovel`
- Começar a Etapa 4 pelas regras do bucket de fotos no Storage (primeiro item da Etapa 4 em "Pendências"), numa migration nova, aplicada no SQL Editor com o `testar_rls.sql` passando. Depois, a tela de cadastro do imóvel em `/proprietario` (toda página e Server Action chama `exigirTipo("proprietario")`) e o botão "Reenviar para aprovação"
- Criar no GitHub a issue do achado 14 da auditoria da Etapa 3, se ainda não foi criada: aceitar telefone digitado com 0 na frente (`0 11 9...`) e reconhecer o erro do cadastro pelo código do Supabase, não pelo texto "Database error" (`src/lib/validacao.ts`, `src/app/auth/actions.ts` e a função `privado.normalizar_telefone`)

Pendências e bloqueios:
- Antes do piloto: configurar SMTP próprio (ex: Resend com domínio do Captador), modelos de e-mail em português apontando para /auth/confirm, e religar a confirmação de e-mail. Sem SMTP próprio o Supabase não deixa editar os modelos; até lá os e-mails usam o modelo padrão, que volta por `/auth/callback/cadastro` e `/auth/callback/recuperacao` (fluxo PKCE: o link só funciona no mesmo navegador do pedido). Depois de religar, testar cadastro e recuperação de senha de ponta a ponta. Junto com isso (achados 9, 10 e 11 da auditoria da Etapa 3):
  - com a confirmação ligada, o perfil e a imobiliária nascem ANTES de o e-mail ser confirmado: planejar a limpeza de contas nunca confirmadas, e testar o que acontece quando alguém repete o cadastro com o mesmo e-mail ainda não confirmado (o Supabase reaproveita o usuário e ignora os dados novos)
  - ligar "Secure password change" no painel (Authentication > Sign In / Providers > Email), para trocar a senha de uma sessão antiga exigir nova autenticação
  - conferir que o cadastro deixa de revelar se um e-mail já tem conta (hoje, com a confirmação desligada, aparece "Já existe uma conta com este e-mail")
- Etapa 4: regras do bucket de fotos no Storage (caminho `<imovel_id>/arquivo`, só o dono do imóvel envia); botão "Reenviar para aprovação" no imóvel reprovado (o banco já permite `reprovado → pendente_aprovacao` pelo proprietário)
- Etapa 5 (achado 2 da auditoria da Etapa 3): o CRECI é único e fica com quem cadastra primeiro, então alguém pode registrar o CRECI de uma imobiliária real e travar o cadastro dela. O admin precisa conseguir excluir uma imobiliária pendente junto com o usuário dela e liberar o CRECI. Avaliar o `on delete` de `perfis.imobiliaria_id` (hoje sem `on delete`, o que impede apagar a imobiliária enquanto houver perfil ligado). Pensar também em CRECI por UF e em corretor autônomo (CRECI-F)
- Etapa 5: tela "Edições para revisar" no painel do admin, que lê `alteracoes_imovel` e marca cada linha como revisada
- Etapa 5: aprovar imóvel por uma função que só aprova se o imóvel não mudou desde que o admin abriu a tela (comparando `atualizado_em`). Hoje, uma edição feita enquanto o imóvel está pendente, entre o admin revisar e clicar em aprovar, vai ao ar sem registro em `alteracoes_imovel` (achado da reauditoria)
- Etapa 7: rotina automática (cron) que expira reservas vencidas, mais um índice em `reservas(status, fim)`. Hoje a reserva vencida continua `ativa` e segura o imóvel
- Etapa 7: a função de reservar trava a linha do imóvel (select ... for update), confere que o status é disponivel e só então cria a reserva e muda o status, tudo na mesma transação. Evita reserva dupla e edição do proprietário no mesmo instante da reserva
- Issues abertas no GitHub (itens 10, 11 e 13 da auditoria): schema `teste_rls` que fica no banco depois do roteiro de teste; testes que dependem uns dos outros; exclusão e anonimização de usuários e imóveis (LGPD). Acrescentar nessa issue (achado 8 da auditoria da Etapa 3): nome, telefone e CRECI do cadastro ficam copiados também em `raw_user_meta_data` do Supabase Auth, uma cópia que o usuário pode editar, que fica desatualizada e vai dentro do token de login; avaliar apagar essas chaves depois que o trigger copia os dados para `perfis`
- Apagar a pasta `src/app/teste-supabase/` antes do deploy (Etapa 10)
- Etapa 10: no painel do Supabase, trocar o Site URL (Authentication > URL Configuration) pelo endereço da Vercel e adicionar `https://<endereço>/auth/callback/**` e `https://<endereço>/auth/confirm` em Redirect URLs. Os links dos e-mails de confirmação e de recuperação usam o Site URL
- Decisões em aberto listadas no `CLAUDE.md` (prazo da reserva, modelo de receita, preço etc.) precisam ser tomadas antes das Etapas 7 e 8

Atenção (algo que a próxima pessoa precisa saber):
- Primeira vez no projeto? Veja o README.md.
- Novidades da Etapa 3 para fazer no seu computador:
  - Rodar `npm install` depois do `git pull` (pacotes novos: `@playwright/test` e `server-only`)
  - Rodar `npx playwright install chromium` uma vez (navegador dos testes automáticos)
  - Acrescentar no `.env.local`: `SITE_URL=http://localhost:3000` (sem barra no fim, sem `NEXT_PUBLIC_`). Sem ela, cadastro e recuperação de senha dão erro
  - Criar a SUA `SUPABASE_SECRET_KEY` (Project Settings > API Keys > Secret keys > "Add new secret key", nome `testes-e2e-<seu nome>`) e acrescentar no `.env.local`. É pessoal, sem `NEXT_PUBLIC_`, nunca vai para o GitHub (README, passo 4)
  - Reiniciar o `npm run dev` e rodar `npm run test:e2e`: tudo tem que passar
- Migration nova: `20261005120000_cadastro_e_perfis.sql` (trigger que cria o perfil no cadastro e regras do telefone). JÁ ESTÁ APLICADA no banco compartilhado: não rode de novo

## Migrations aplicadas no banco

O banco do Supabase é compartilhado (projeto `gaxvhygqwcvfgpudywmi`). Estas migrations já rodaram, nesta ordem: não rode de novo. Toda migration nova entra aqui assim que for aplicada no SQL Editor e o `testar_rls.sql` passar.

1. `20260930120000_tabelas_iniciais.sql` (Etapa 2)
2. `20260930120100_rls.sql` (Etapa 2)
3. `20260930130000_correcoes_auditoria_etapa2.sql` (Etapa 2)
4. `20261005120000_cadastro_e_perfis.sql` (Etapa 3, 05/10/2026)

## Etapas do MVP

- [x] 1. Setup do projeto — Pronto quando: a página abre em localhost, a conexão com o Supabase funciona e o código está no GitHub
- [x] 2. Banco de dados — Pronto quando: imobiliária bloqueada não enxerga nenhum imóvel
- [x] 3. Login e perfis — Pronto quando: cada tipo de usuário só abre a própria área
- [ ] 4. Cadastro do imóvel — Pronto quando: imóvel cadastrado com fotos aparece como "pendente"
- [ ] 5. Painel do admin — Pronto quando: admin aprova imóvel e ativa imobiliária
- [ ] 6. Catálogo — Pronto quando: imobiliária ativa filtra no celular e bloqueada não vê nada
- [ ] 7. Reserva, visita e proposta — Pronto quando: só um corretor consegue reservar o mesmo imóvel e reserva vencida libera o imóvel
- [ ] 8. Cobrança — Pronto quando: imobiliária com "pago até" vencido perde o acesso sozinha
- [ ] 9. PWA e testes — Pronto quando: o roteiro de teste passa inteiro
- [ ] 10. Deploy — Pronto quando: o app abre pelo endereço público no celular de outra pessoa

## Histórico

- 30/09/2026 · Hevelyn · Setup inicial do Next.js e conexão com o Supabase
- 30/09/2026 · Gabriel · Etapa 2: banco de dados, RLS, auditoria e correções (71 testes passando)
- 05/10/2026 · Hevelyn · Etapa 3: cadastro, login e perfis, auditoria e correções, testes e2e com Playwright (15 passando), README de início
