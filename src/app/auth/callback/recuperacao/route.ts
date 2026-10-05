import type { NextRequest } from "next/server";
import { trocarCodigoPorSessao } from "../trocar-codigo";

// Volta do link do e-mail "Reset password" (modelo padrão do Supabase).
// Endereço informado em pedirRecuperacao(), em src/app/auth/actions.ts.
export async function GET(request: NextRequest) {
  return trocarCodigoPorSessao(request, {
    sucesso: "/redefinir-senha",
    falha: "/esqueci-senha?expirado=1",
  });
}
