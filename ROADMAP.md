# Captador — Roadmap

## Onde paramos

Última atualização: 30/09/2026 · por Hevelyn
Etapa atual: 1. Setup do projeto

O que foi feito nesta sessão:
- Projeto Next.js criado com TypeScript e Tailwind
- Clientes do Supabase criados em `src/lib/supabase/` (navegador e servidor)
- Página de teste da conexão criada em `src/app/teste-supabase/`

Próximo passo exato:
- Abrir `http://localhost:3000/teste-supabase` e confirmar a mensagem "Conectado ao Supabase"
- Fazer o primeiro commit e enviar para o GitHub
- Marcar a Etapa 1 como concluída e seguir para a Etapa 2 (banco de dados)

Pendências e bloqueios:
- Apagar a pasta `src/app/teste-supabase/` antes do deploy (Etapa 10)
- Decisões em aberto listadas no `CLAUDE.md` (prazo da reserva, modelo de receita, preço etc.) precisam ser tomadas antes das Etapas 7 e 8

Atenção (algo que a próxima pessoa precisa saber):
- Cada pessoa precisa criar o próprio `.env.local` na raiz com `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`. As chaves são combinadas por um canal privado, nunca pelo GitHub
- Depois de criar ou mudar o `.env.local`, reinicie o `npm run dev`

## Etapas do MVP

- [ ] 1. Setup do projeto — Pronto quando: a página abre em localhost, a conexão com o Supabase funciona e o código está no GitHub
- [ ] 2. Banco de dados — Pronto quando: imobiliária bloqueada não enxerga nenhum imóvel
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
