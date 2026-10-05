"use client";

import { useActionState } from "react";
import { redefinirSenha, type EstadoFormulario } from "@/app/auth/actions";
import { BotaoEnviar, Campo, Mensagem } from "@/components/formulario";
import { SENHA_MINIMO } from "@/lib/validacao";

export function FormularioRedefinirSenha() {
  const [estado, acao, pendente] = useActionState<EstadoFormulario, FormData>(redefinirSenha, {});

  return (
    <form action={acao} className="flex flex-col gap-4">
      <Mensagem erro={estado.erro} />
      <Campo
        rotulo="Nova senha"
        name="senha"
        type="password"
        autoComplete="new-password"
        required
        minLength={SENHA_MINIMO}
        ajuda={`Pelo menos ${SENHA_MINIMO} caracteres.`}
      />
      <Campo
        rotulo="Repita a nova senha"
        name="confirmacao"
        type="password"
        autoComplete="new-password"
        required
        minLength={SENHA_MINIMO}
      />
      <BotaoEnviar pendente={pendente}>Salvar nova senha</BotaoEnviar>
    </form>
  );
}
