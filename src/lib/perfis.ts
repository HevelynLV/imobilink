// Tipos de perfil e a área de cada um. Arquivo sem dependências de servidor
// ou navegador, para poder ser usado no proxy, nas páginas e nos formulários.

export type TipoPerfil = "proprietario" | "imobiliaria" | "admin";

export const AREA_POR_TIPO: Record<TipoPerfil, string> = {
  proprietario: "/proprietario",
  imobiliaria: "/imobiliaria",
  admin: "/admin",
};

// Para onde vai quem está logado mas não tem perfil (conta criada sem tipo).
export const DESTINO_SEM_PERFIL = "/login?erro=sem-perfil";

export function ehTipoPerfil(valor: unknown): valor is TipoPerfil {
  // hasOwn, e não "in": "in" aceitaria "toString", "constructor" etc.
  return typeof valor === "string" && Object.hasOwn(AREA_POR_TIPO, valor);
}
