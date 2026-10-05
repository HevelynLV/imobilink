import type { InputHTMLAttributes, ReactNode } from "react";

// Peças de formulário usadas nas telas de login, cadastro e senha.
// text-base (16px) nos campos: abaixo disso o iPhone dá zoom ao tocar.

type CampoProps = InputHTMLAttributes<HTMLInputElement> & {
  rotulo: string;
  name: string;
  ajuda?: string;
};

export function Campo({ rotulo, ajuda, id, name, ...props }: CampoProps) {
  const campoId = id ?? name;
  return (
    <div className="flex flex-col gap-1">
      <label htmlFor={campoId} className="text-sm font-medium">
        {rotulo}
      </label>
      <input
        id={campoId}
        name={name}
        className="rounded-md border border-gray-300 bg-white px-3 py-2 text-base text-gray-900 focus:border-gray-900 focus:outline-none"
        {...props}
      />
      {ajuda && <p className="text-xs text-gray-500">{ajuda}</p>}
    </div>
  );
}

export function BotaoEnviar({ children, pendente }: { children: ReactNode; pendente?: boolean }) {
  return (
    <button
      type="submit"
      disabled={pendente}
      className="rounded-md bg-gray-900 px-4 py-3 text-base font-medium text-white disabled:opacity-60"
    >
      {pendente ? "Aguarde..." : children}
    </button>
  );
}

export function Mensagem({ erro, sucesso }: { erro?: string; sucesso?: string }) {
  if (erro) {
    return (
      <p role="alert" className="rounded-md bg-red-50 p-3 text-sm text-red-800">
        {erro}
      </p>
    );
  }
  if (sucesso) {
    return (
      <p role="status" className="rounded-md bg-green-50 p-3 text-sm text-green-800">
        {sucesso}
      </p>
    );
  }
  return null;
}

export function TelaFormulario({ titulo, children }: { titulo: string; children: ReactNode }) {
  return (
    <main className="mx-auto flex w-full max-w-sm flex-1 flex-col justify-center gap-6 p-6">
      <h1 className="text-2xl font-semibold">{titulo}</h1>
      {children}
    </main>
  );
}
