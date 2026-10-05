import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";

// Retorno dos links de e-mail no modelo PADRÃO do Supabase (fluxo PKCE).
// O link do e-mail abre o servidor do Supabase, que confere o token e volta
// para a nossa rota com ?code=... no endereço. Aqui trocamos esse código
// pela sessão (exchangeCodeForSession).
//
// A troca só funciona no MESMO navegador em que o cadastro ou a recuperação
// foi pedida: ela precisa do "code_verifier", um segredo que ficou guardado
// num cookie desse navegador na hora do pedido.
//
// Cada rota de retorno (cadastro, recuperacao) passa destinos FIXOS. Nada do
// endereço decide para onde a pessoa vai (evita open redirect).
//
// Este arquivo não é uma rota: só arquivos chamados route.ts ou page.tsx viram
// endereço no Next.js.

export async function trocarCodigoPorSessao(
  request: NextRequest,
  destinos: { sucesso: string; falha: string }
) {
  const codigo = request.nextUrl.searchParams.get("code");

  const url = request.nextUrl.clone();
  url.search = "";

  if (codigo) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(codigo);
    if (!error) {
      url.pathname = destinos.sucesso;
      return NextResponse.redirect(url);
    }
    console.error("Falha ao trocar código por sessão:", error.code, error.message);
  }

  // Sem código (link vencido: o Supabase volta com ?error=...), código já
  // usado, ou aberto em outro navegador (sem o code_verifier).
  const [caminho, busca] = destinos.falha.split("?");
  url.pathname = caminho;
  url.search = busca ? `?${busca}` : "";
  return NextResponse.redirect(url);
}
