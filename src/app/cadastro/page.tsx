import Link from "next/link";
import { TelaFormulario } from "@/components/formulario";
import { FormularioCadastro } from "./formulario";

export default function PaginaCadastro() {
  return (
    <TelaFormulario titulo="Criar conta">
      <FormularioCadastro />
      <p className="text-sm">
        Já tem conta?{" "}
        <Link href="/login" className="underline">
          Entrar
        </Link>
      </p>
    </TelaFormulario>
  );
}
