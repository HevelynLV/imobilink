import { redirect } from "next/navigation";
import { obterPerfil } from "@/lib/auth";
import { AREA_POR_TIPO } from "@/lib/perfis";

// Página inicial: só distribui. Logado com perfil vai para a própria área;
// sem login (ou sem perfil) vai para o login.
export default async function Inicio() {
  const perfil = await obterPerfil();
  redirect(perfil ? AREA_POR_TIPO[perfil.tipo] : "/login");
}
