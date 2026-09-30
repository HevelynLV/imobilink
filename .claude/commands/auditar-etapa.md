Use a skill requesting-code-review do Superpowers para auditar a etapa $ARGUMENTS do Captador.

Leia o CLAUDE.md e o ROADMAP.md antes de começar. Compare o código desta branch com a main (git diff main).

Verifique:
1. Critério de pronto: a etapa cumpre o "Pronto quando" do ROADMAP.md? Rode ou me diga como testar cada item. Não aceite "deve funcionar"; quero evidência.
2. Regras do negócio:
   - o contato do proprietário nunca chega ao navegador de um corretor
   - só imóveis aprovados aparecem no catálogo
   - só imobiliárias com assinatura ativa veem o catálogo
   - reserva não pode ser duplicada e expira sozinha (se esta etapa mexe nisso)
3. Segurança: regras de RLS, proteção de rotas, validação no servidor, chaves secretas expostas.
4. Casos de erro: dados inválidos, upload que falha, usuário sem permissão, conexão caindo.
5. Organização: código duplicado, arquivos no lugar errado, nomes confusos, algo que vai atrapalhar as próximas etapas.
6. Banco de dados: toda mudança no Supabase está salva como migration no repositório?

Entregue uma tabela com: problema, gravidade (crítico, importante, melhoria), arquivo e como corrigir.

NÃO corrija nada ainda. Espere eu escolher o que corrigir.
