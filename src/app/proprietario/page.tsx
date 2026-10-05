import { BotaoSair } from "@/components/botao-sair";
import { exigirTipo } from "@/lib/auth";

export default async function AreaProprietario() {
  const perfil = await exigirTipo("proprietario");

  return (
    <main className="mx-auto w-full max-w-md p-6">
      <div className="flex items-start justify-between gap-4">
        <h1 className="text-2xl font-semibold">Olá, {perfil.nome}</h1>
        <BotaoSair />
      </div>
      <p className="mt-2 text-gray-600">Área do proprietário. Seus imóveis vão aparecer aqui.</p>
    </main>
  );
}
