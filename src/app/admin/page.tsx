import { exigirTipo } from "@/lib/auth";

export default async function AreaAdmin() {
  const perfil = await exigirTipo("admin");

  return (
    <main className="mx-auto w-full max-w-md p-6">
      <h1 className="text-2xl font-semibold">Olá, {perfil.nome}</h1>
      <p className="mt-2 text-gray-600">Painel do admin. Aprovações de imóveis e imobiliárias vão aparecer aqui.</p>
    </main>
  );
}
