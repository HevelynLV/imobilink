"use client";

// Tela mostrada quando uma página falha sem querer (ex.: o Supabase não
// respondeu ao ler o perfil). Precisa ser componente do navegador ("use client").
// Não mostre error.message: em produção o Next.js esconde o texto real e pode
// conter detalhes internos.

export default function Erro({ retry }: { error: Error & { digest?: string }; retry: () => void }) {
  return (
    <main className="mx-auto flex w-full max-w-sm flex-1 flex-col justify-center gap-4 p-6">
      <h1 className="text-2xl font-semibold">Algo deu errado</h1>
      <p className="text-gray-600">
        Não conseguimos carregar esta página. Confira sua internet e tente de novo.
      </p>
      <button
        type="button"
        onClick={() => retry()}
        className="rounded-md bg-gray-900 px-4 py-3 text-base font-medium text-white"
      >
        Tentar de novo
      </button>
    </main>
  );
}
