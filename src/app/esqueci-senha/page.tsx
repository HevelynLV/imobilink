import Link from "next/link";
import { TelaFormulario } from "@/components/formulario";
import { FormularioEsqueciSenha } from "./formulario";

export default async function PaginaEsqueciSenha({ searchParams }: PageProps<"/esqueci-senha">) {
  const { expirado } = await searchParams;
  const aviso = expirado
    ? "O link de recuperação venceu, já foi usado ou foi aberto em outro navegador. Peça um novo abaixo e abra o link neste mesmo navegador."
    : undefined;

  return (
    <TelaFormulario titulo="Recuperar senha">
      <p className="text-sm text-gray-600">
        Informe o e-mail da sua conta. Vamos mandar um link para você criar uma senha nova.
      </p>
      <FormularioEsqueciSenha avisoInicial={aviso} />
      <Link href="/login" className="text-sm underline">
        Voltar para o login
      </Link>
    </TelaFormulario>
  );
}
