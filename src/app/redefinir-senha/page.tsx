import { redirect } from "next/navigation";
import { TelaFormulario } from "@/components/formulario";
import { createClient } from "@/lib/supabase/server";
import { FormularioRedefinirSenha } from "./formulario";

// Chega-se aqui pelo link do e-mail de recuperação, que passa por
// /auth/confirm e cria a sessão. Sem sessão, não há senha para trocar.
// Vale para qualquer tipo de usuário, por isso não usa exigirTipo().
export default async function PaginaRedefinirSenha() {
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  if (!data?.claims?.sub) redirect("/esqueci-senha?expirado=1");

  return (
    <TelaFormulario titulo="Criar nova senha">
      <FormularioRedefinirSenha />
    </TelaFormulario>
  );
}
