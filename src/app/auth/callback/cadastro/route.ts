import type { NextRequest } from "next/server";
import { trocarCodigoPorSessao } from "../trocar-codigo";

// Volta do link do e-mail "Confirm signup" (modelo padrão do Supabase).
// Endereço informado em cadastrar(), em src/app/auth/actions.ts.
// Só é usada com a confirmação de e-mail LIGADA no painel.
export async function GET(request: NextRequest) {
  return trocarCodigoPorSessao(request, {
    // A página inicial manda cada tipo para a sua área.
    sucesso: "/",
    // Quando a troca falha (ex.: aberto no celular, cadastro feito no
    // computador), o e-mail JÁ foi confirmado pelo Supabase; só não deu para
    // criar a sessão aqui. A pessoa entra com a senha.
    falha: "/login?erro=confirmacao",
  });
}
