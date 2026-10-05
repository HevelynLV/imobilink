Antes de eu dar git push, atualize o ROADMAP.md para a próxima pessoa.

1. Rode git pull para pegar a versão mais recente do ROADMAP.md.
2. Veja o que mudou nesta sessão com git status, git diff e git log (commits desde o último push).
3. Pergunte meu nome, se não souber, e atualize a seção "Onde paramos":
   - data de hoje e meu nome
   - etapa atual
   - o que foi feito, em linguagem simples (sem jargão)
   - o próximo passo exato, específico o suficiente para alguém começar sem me perguntar nada
   - pendências, bugs conhecidos ou decisões em aberto
   - avisos importantes (ex: nova variável no .env.local, nova migration no banco, pacote novo para instalar)
4. Confira o que a outra pessoa vai precisar fazer no computador dela. Procure no git diff desde o último push:
   `process.env.` novos no código (variável nova no .env.local), mudanças no package.json (pacote ou
   ferramenta nova) e arquivos novos em supabase/migrations/ (migration nova). Para cada item encontrado:
   - coloque no "Atenção" do ROADMAP.md o que fazer, em passos
   - atualize o checklist "Como começar a trabalhar no Captador" do README.md, para quem chegar depois
   - migration nova também entra na lista "Migrations aplicadas no banco" do ROADMAP.md, mas só se já
     foi aplicada no SQL Editor e o testar_rls.sql passou. Se não foi, pare e me avise em vez de listar
   - no "Atenção", deixe só o que é novo e a outra pessoa ainda não fez; o que já virou rotina fica só no README
5. Marque como [x] as etapas que ficaram prontas. Só marque o que está funcionando e passou na auditoria. Se estiver pela metade, deixe [ ] e explique em "Pendências".
6. Adicione uma linha no "Histórico".
7. Me mostre as mudanças no ROADMAP.md e no README.md e espere eu aprovar antes de fazer o commit.
8. Depois de aprovado, faça o commit com a mensagem "docs: atualiza roadmap" e me diga o comando de push.
