import Link from "next/link";
import { TelaFormulario } from "@/components/formulario";
import { FormularioLogin } from "./formulario";

// Mensagens que outras telas mandam pelo endereço (/login?erro=...).
// Só textos fixos daqui: o que vem no endereço nunca vira texto na tela.
const AVISOS: Record<string, string> = {
  link: "Este link é inválido ou já venceu. Entre com sua senha ou peça um novo link.",
  confirmacao:
    "Não conseguimos concluir a confirmação por este link. Se você já clicou nele, seu e-mail pode estar confirmado: tente entrar com sua senha.",
};

export default async function PaginaLogin({ searchParams }: PageProps<"/login">) {
  const { erro } = await searchParams;
  const aviso = typeof erro === "string" ? AVISOS[erro] : undefined;

  return (
    <TelaFormulario titulo="Entrar no Captador">
      <FormularioLogin avisoInicial={aviso} />
      <div className="flex flex-col gap-2 text-sm">
        <Link href="/esqueci-senha" className="underline">
          Esqueci minha senha
        </Link>
        <p>
          Ainda não tem conta?{" "}
          <Link href="/cadastro" className="underline">
            Cadastre-se
          </Link>
        </p>
      </div>
    </TelaFormulario>
  );
}
