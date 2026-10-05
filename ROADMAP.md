# Captador — Roadmap

## Onde paramos

Última atualização: 30/09/2026 · por Gabriel
Etapa atual: 3. Login e perfis (a Etapa 2 foi concluída)

O que foi feito nesta sessão:
- Banco de dados criado no Supabase: tabelas de imobiliárias, perfis, imóveis, fotos, reservas, visitas e propostas
- Regras de segurança (RLS): cada tipo de usuário só enxerga e altera o que é dele; imobiliária bloqueada ou pendente não vê nenhum imóvel; o contato do proprietário nunca chega ao corretor
- Auditoria da etapa feita, e os problemas escolhidos foram corrigidos numa migration nova:
  - o proprietário pode editar imóvel já aprovado, mas cada mudança fica registrada para o admin revisar (tabela `alteracoes_imovel`)
  - imóvel reservado, em proposta ou vendido não pode ser editado
  - o proprietário vê visitas e propostas por funções que escondem os dados e os textos do corretor
  - datas de cadastro e de aceite do termo passam a ser preenchidas pelo banco
  - foto só pode apontar para a pasta do próprio imóvel no Storage
- Roteiro de teste `supabase/testes/testar_rls.sql` com 71 testes, todos passando no SQL Editor do Supabase
- Reauditoria depois das correções: nenhum problema crítico

Próximo passo exato:
- Criar a branch `etapa-3-login-e-perfis` a partir da `main` atualizada (depois que o Pull Request da Etapa 2 for aceito)
- Começar a Etapa 3 (login e perfis) resolvendo primeiro o item 4 da auditoria: travar também a criação de perfil (INSERT) e criar perfil só por uma função controlada no banco. No cadastro, o tipo é sempre `proprietario`; corretor só entra por convite ou pelo admin; ninguém se cria como `admin`
- Essa trava entra numa migration nova, com testes novos no `testar_rls.sql`

Pendências e bloqueios:
- Etapa 3: trava de perfil no INSERT e criação de perfil só por função controlada (item 4 da auditoria). Decisão de 05/10/2026: o perfil é criado só pelo trigger `criar_perfil_no_cadastro` (migration `20261005120000_cadastro_e_perfis.sql`). O cadastro aceita `proprietario` ou `imobiliaria`, nunca `admin`. Quem se cadastra como imobiliária sempre cria uma imobiliária NOVA com assinatura `pendente` e vira o primeiro corretor dela; não dá para entrar numa imobiliária existente pelo cadastro. Corretores adicionais da mesma imobiliária: por convite, numa etapa futura
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

- [ ] 1. Setup do projeto — Pronto quando: a página abre em localhost, a conexão com o Supabase funciona e o código está no GitHub
- [x] 2. Banco de dados — Pronto quando: imobiliária bloqueada não enxerga nenhum imóvel
- [ ] 3. Login e perfis — Pronto quando: cada tipo de usuário só abre a própria área
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
