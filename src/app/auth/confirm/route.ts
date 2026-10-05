import type { EmailOtpType } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";

// RESERVADA PARA O FUTURO: hoje os e-mails usam o modelo padrão do Supabase,
// que volta pelas rotas de /auth/callback (fluxo PKCE, com ?code=).
// Esta rota passa a ser usada quando tivermos SMTP próprio e modelos de
// e-mail apontando para /auth/confirm?token_hash=...&type=... (ver ROADMAP).
// Vantagem desse formato: o link funciona em qualquer navegador.
//
// Recebe o clique no link dos e-mails do Supabase (confirmação de cadastro e
// recuperação de senha).
//
// verifyOtp() confere o código no servidor do Supabase e, se for válido,
// cria a sessão (grava os cookies de login).
//
// O destino é decidido AQUI pelo tipo do link, nunca por um parâmetro do
// endereço: assim ninguém monta um link nosso que leva para outro site.

const TIPOS_ACEITOS: EmailOtpType[] = ["signup", "email", "recovery"];

export async function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl;
  const tokenHash = searchParams.get("token_hash");
  const tipo = searchParams.get("type") as EmailOtpType | null;

  const url = request.nextUrl.clone();
  url.search = "";

  if (tokenHash && tipo && TIPOS_ACEITOS.includes(tipo)) {
    const supabase = await createClient();
    const { error } = await supabase.auth.verifyOtp({ type: tipo, token_hash: tokenHash });

    if (!error) {
      // Recuperação: vai criar a senha nova. Cadastro: a página inicial
      // manda cada tipo para a sua área.
      url.pathname = tipo === "recovery" ? "/redefinir-senha" : "/";
      return NextResponse.redirect(url);
    }
  }

  // Link inválido, já usado ou vencido
  url.pathname = "/login";
  url.searchParams.set("erro", "link");
  return NextResponse.redirect(url);
}
