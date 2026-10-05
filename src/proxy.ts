import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { AREA_POR_TIPO, DESTINO_SEM_PERFIL, ehTipoPerfil } from "@/lib/perfis";

// Proxy (antigo "middleware" até o Next.js 15): roda no servidor antes de
// cada página. Faz duas coisas:
//   1. Renova a sessão do Supabase e grava os cookies novos na resposta.
//   2. Barra quem tenta abrir a área de outro tipo de usuário.
//
// É a PRIMEIRA barreira, não a única: as páginas conferem o perfil de novo
// (src/lib/auth.ts) e o RLS do banco protege os dados de qualquer jeito.

const AREAS = Object.values(AREA_POR_TIPO);
const PAGINAS_DE_ENTRADA = ["/login", "/cadastro"];

function estaEm(caminho: string, base: string) {
  return caminho === base || caminho.startsWith(base + "/");
}

export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request });
  // Cabeçalhos anti-cache que o Supabase pede quando renova a sessão
  let cabecalhosDaSessao: Record<string, string> = {};

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet, headers) {
          // Grava os cookies renovados no pedido (para as páginas lerem
          // nesta mesma requisição) e na resposta (para o navegador guardar).
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          );
          // Impede que um CDN guarde a resposta com o token de outra pessoa
          cabecalhosDaSessao = { ...cabecalhosDaSessao, ...headers };
          Object.entries(cabecalhosDaSessao).forEach(([chave, valor]) =>
            response.headers.set(chave, valor)
          );
        },
      },
    }
  );

  // getClaims() confere a assinatura do token. NUNCA use getSession() aqui:
  // ela devolve o que está no cookie sem verificar, e o cookie vem do navegador.
  // Não coloque código entre createServerClient e getClaims().
  const { data } = await supabase.auth.getClaims();
  const userId = data?.claims?.sub;

  const caminho = request.nextUrl.pathname;
  const areaPedida = AREAS.find((area) => estaEm(caminho, area));
  const paginaDeEntrada = PAGINAS_DE_ENTRADA.some((p) => estaEm(caminho, p));

  // Fora das áreas e das páginas de entrada, só renova a sessão.
  if (!areaPedida && !paginaDeEntrada) {
    return response;
  }

  // Redireciona sem perder os cookies renovados acima.
  // "destino" é sempre um endereço fixo deste arquivo, nunca vindo da requisição.
  function redirecionar(destino: string) {
    const url = new URL(destino, request.url);
    const redirect = NextResponse.redirect(url);
    response.cookies.getAll().forEach((cookie) => redirect.cookies.set(cookie));
    Object.entries(cabecalhosDaSessao).forEach(([chave, valor]) =>
      redirect.headers.set(chave, valor)
    );
    return redirect;
  }

  if (!userId) {
    return areaPedida ? redirecionar("/login") : response;
  }

  // O tipo vem da tabela perfis (o RLS deixa cada um ler só o próprio perfil).
  // NUNCA do user_metadata: o usuário consegue alterar o próprio metadata.
  const { data: perfil, error } = await supabase
    .from("perfis")
    .select("tipo")
    .eq("id", userId)
    .maybeSingle();

  if (error) {
    // Banco não respondeu: não dá para decidir aqui. Deixa seguir para a
    // página, que confere de novo (exigirTipo) e, se o erro continuar, mostra
    // a tela de erro sem mostrar conteúdo nenhum.
    console.error("Proxy: erro ao ler o perfil:", error.code, error.message);
    return response;
  }

  const tipo = perfil?.tipo;

  if (!ehTipoPerfil(tipo)) {
    // Logado mas sem perfil: não entra em área nenhuma. No /login vê o aviso.
    return areaPedida ? redirecionar(DESTINO_SEM_PERFIL) : response;
  }

  const minhaArea = AREA_POR_TIPO[tipo];

  if (paginaDeEntrada || areaPedida !== minhaArea) {
    return redirecionar(minhaArea);
  }

  return response;
}

export const config = {
  // Roda em tudo, menos arquivos estáticos e imagens.
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
