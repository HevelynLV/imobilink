-- Promove uma conta já cadastrada a ADMIN. NÃO é migration: é um dado,
-- rodado à mão no SQL Editor do Supabase, uma vez por admin.
--
-- Por que funciona: a trava que impede mudar o "tipo" do perfil só vale para
-- chamadas do app (current_user = 'authenticated'). O SQL Editor roda como
-- postgres, então pode. Pelo app, ninguém consegue se promover.
--
-- Como usar:
--   1. Cadastre-se pelo app como PROPRIETÁRIO, com o e-mail do admin
--      (e confirme o e-mail, se a confirmação estiver ligada).
--   2. Troque o e-mail abaixo pelo e-mail dessa conta e rode este arquivo.
--   3. Saia e entre de novo no app: você vai cair em /admin.
--
-- Não salve no repositório este arquivo com um e-mail de verdade.

update public.perfis
set tipo = 'admin'
where id = (select id from auth.users where email = 'TROQUE-PELO-EMAIL@exemplo.com')
  and tipo = 'proprietario'
returning id, tipo, nome;

-- Deve aparecer UMA linha com tipo = admin. Nenhuma linha: o e-mail está
-- errado, a conta não existe ou não é de proprietário.
-- O perfil precisa ser de proprietário porque o de imobiliária está ligado a
-- uma imobiliária (e admin não pode estar).
