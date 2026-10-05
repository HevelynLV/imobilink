import { exigirTipo } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

const AVISO_POR_STATUS: Record<string, string> = {
  pendente: "Sua assinatura está pendente. Assim que o admin conferir o CRECI e liberar o acesso, o catálogo aparece aqui.",
  bloqueada: "Sua assinatura está bloqueada. Fale com o suporte do Captador.",
  ativa: "Assinatura ativa. O catálogo de imóveis vai aparecer aqui.",
};

export default async function AreaImobiliaria() {
  const perfil = await exigirTipo("imobiliaria");

  // O RLS só deixa o corretor ler a própria imobiliária.
  const supabase = await createClient();
  const { data: imobiliaria } = await supabase
    .from("imobiliarias")
    .select("nome, status_assinatura")
    .eq("id", perfil.imobiliaria_id!)
    .maybeSingle();

  return (
    <main className="mx-auto w-full max-w-md p-6">
      <h1 className="text-2xl font-semibold">Olá, {perfil.nome}</h1>
      {imobiliaria && <p className="mt-1 text-gray-600">{imobiliaria.nome}</p>}
      <p className="mt-4 rounded-md bg-gray-100 p-4 text-gray-800">
        {AVISO_POR_STATUS[imobiliaria?.status_assinatura ?? ""] ??
          "Não foi possível carregar sua assinatura. Tente de novo mais tarde."}
      </p>
    </main>
  );
}
