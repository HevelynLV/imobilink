import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { AREA_POR_TIPO, ehTipoPerfil, type TipoPerfil } from "@/lib/perfis";

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

// "cache" faz a consulta rodar uma vez só por requisição, mesmo que várias
// partes da página chamem obterPerfil().
export const obterPerfil = cache(async (): Promise<Perfil | null> => {
  const supabase = await createClient();

  // getClaims() confere a assinatura do token; getSession() não confere nada.
  const { data } = await supabase.auth.getClaims();
  const userId = data?.claims?.sub;
  if (!userId) return null;

  // O RLS só deixa cada usuário ler o próprio perfil.
  const { data: perfil } = await supabase
    .from("perfis")
    .select("id, tipo, nome, imobiliaria_id")
    .eq("id", userId)
    .maybeSingle();

  if (!perfil || !ehTipoPerfil(perfil.tipo)) return null;
  return perfil as Perfil;
});

// Usa no topo da página ou da Server Action:
//   const perfil = await exigirTipo("admin");
// Sem login (ou sem perfil): vai para /login. Outro tipo: vai para a própria área.
export async function exigirTipo(tipo: TipoPerfil): Promise<Perfil> {
  const perfil = await obterPerfil();
  if (!perfil) redirect("/login");
  if (perfil.tipo !== tipo) redirect(AREA_POR_TIPO[perfil.tipo]);
  return perfil;
}
