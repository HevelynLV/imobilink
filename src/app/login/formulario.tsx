"use client";

import { useActionState } from "react";
import { entrar, type EstadoFormulario } from "@/app/auth/actions";
import { BotaoEnviar, Campo, Mensagem } from "@/components/formulario";

export function FormularioLogin({ avisoInicial }: { avisoInicial?: string }) {
  const [estado, acao, pendente] = useActionState<EstadoFormulario, FormData>(entrar, {
    erro: avisoInicial,
  });

  return (
    <form action={acao} className="flex flex-col gap-4">
      <Mensagem erro={estado.erro} />
      <Campo
        rotulo="E-mail"
        name="email"
        type="email"
        autoComplete="email"
        required
        defaultValue={estado.valores?.email}
      />
      <Campo rotulo="Senha" name="senha" type="password" autoComplete="current-password" required />
      <BotaoEnviar pendente={pendente}>Entrar</BotaoEnviar>
    </form>
  );
}
