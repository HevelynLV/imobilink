"use client";

import { useActionState } from "react";
import { pedirRecuperacao, type EstadoFormulario } from "@/app/auth/actions";
import { BotaoEnviar, Campo, Mensagem } from "@/components/formulario";

export function FormularioEsqueciSenha({ avisoInicial }: { avisoInicial?: string }) {
  const [estado, acao, pendente] = useActionState<EstadoFormulario, FormData>(pedirRecuperacao, {
    erro: avisoInicial,
  });

  if (estado.sucesso) return <Mensagem sucesso={estado.sucesso} />;

  return (
    <form action={acao} className="flex flex-col gap-4">
      <Mensagem erro={estado.erro} />
      <Campo
        rotulo="E-mail da sua conta"
        name="email"
        type="email"
        autoComplete="email"
        required
        defaultValue={estado.valores?.email}
      />
      <BotaoEnviar pendente={pendente}>Enviar link</BotaoEnviar>
    </form>
  );
}
