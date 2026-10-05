import { sair } from "@/app/auth/actions";

// Formulário com um botão só: funciona mesmo antes do JavaScript carregar.
export function BotaoSair() {
  return (
    <form action={sair}>
      <button type="submit" className="text-sm underline">
        Sair
      </button>
    </form>
  );
}
