// Tipos de perfil e a área de cada um. Arquivo sem dependências de servidor
// ou navegador, para poder ser usado no proxy, nas páginas e nos formulários.

export type TipoPerfil = "proprietario" | "imobiliaria" | "admin";

export const AREA_POR_TIPO: Record<TipoPerfil, string> = {
  proprietario: "/proprietario",
  imobiliaria: "/imobiliaria",
  admin: "/admin",
};

export function ehTipoPerfil(valor: unknown): valor is TipoPerfil {
  return typeof valor === "string" && valor in AREA_POR_TIPO;
}
