import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { AREA_POR_TIPO, DESTINO_SEM_PERFIL, ehTipoPerfil, type TipoPerfil } from "@/lib/perfis";

// Segunda barreira (a primeira é o src/proxy.ts). Toda página das áreas e
// toda Server Action que mexe com dados do usuário chama uma destas funções.
// Não confie só no proxy nem no layout.tsx: o layout não roda de novo quando
// a pessoa navega entre páginas da mesma área.

export type Perfil = {
  id: string;
  tipo: TipoPerfil;
  nome: string;
  imobiliaria_id: string | null;
};

// "cache" faz cada consulta rodar uma vez só por requisição, mesmo que várias
// partes da página chamem estas funções.

// Id do usuário logado, ou null. getClaims() confere a assinatura do token;
// getSession() não confere nada.
export const obterUsuarioId = cache(async (): Promise<string | null> => {
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  return data?.claims?.sub ?? null;
});

// Perfil do usuário logado. null = sem login ou sem perfil.
// Se o banco não responder, LANÇA um erro (vira a tela de src/app/error.tsx):
// erro de conexão não pode ser confundido com "não tem perfil".
export const obterPerfil = cache(async (): Promise<Perfil | null> => {
  const userId = await obterUsuarioId();
  if (!userId) return null;

  // O RLS só deixa cada usuário ler o próprio perfil.
  const supabase = await createClient();
  const { data: perfil, error } = await supabase
    .from("perfis")
    .select("id, tipo, nome, imobiliaria_id")
    .eq("id", userId)
    .maybeSingle();

  if (error) {
    console.error("Erro ao ler o perfil:", error.code, error.message);
    throw new Error("Não foi possível carregar seu perfil.");
  }
  if (!perfil || !ehTipoPerfil(perfil.tipo)) return null;
  return perfil as Perfil;
});

// Para onde mandar quem não tem perfil: login, ou aviso de "sem perfil".
export async function destinoSemPerfil(): Promise<string> {
  return (await obterUsuarioId()) ? DESTINO_SEM_PERFIL : "/login";
}

// Usa no topo da página ou da Server Action:
//   const perfil = await exigirTipo("admin");
// Sem login: /login. Logado sem perfil: aviso no /login. Outro tipo: a própria área.
export async function exigirTipo(tipo: TipoPerfil): Promise<Perfil> {
  const perfil = await obterPerfil();
  if (!perfil) redirect(await destinoSemPerfil());
  if (perfil.tipo !== tipo) redirect(AREA_POR_TIPO[perfil.tipo]);
  return perfil;
}
