"use client";

import { useActionState, useState } from "react";
import { cadastrar, type EstadoFormulario } from "@/app/auth/actions";
import { BotaoEnviar, Campo, Mensagem } from "@/components/formulario";
import { SENHA_MINIMO } from "@/lib/validacao";

type Tipo = "proprietario" | "imobiliaria";

export function FormularioCadastro() {
  const [estado, acao, pendente] = useActionState<EstadoFormulario, FormData>(cadastrar, {});
  // O tipo escolhido decide se os campos da imobiliária aparecem.
  const [tipo, setTipo] = useState<Tipo>("proprietario");

  // Cadastro feito, esperando a pessoa confirmar o e-mail
  if (estado.sucesso) return <Mensagem sucesso={estado.sucesso} />;

  const v = estado.valores ?? {};

  return (
    <form action={acao} className="flex flex-col gap-4">
      <Mensagem erro={estado.erro} />

      <fieldset className="flex flex-col gap-2">
        <legend className="mb-1 text-sm font-medium">Você é</legend>
        {(
          [
            ["proprietario", "Proprietário: quero anunciar meu imóvel"],
            ["imobiliaria", "Imobiliária ou corretor: quero acessar o catálogo"],
          ] as const
        ).map(([valor, texto]) => (
          <label
            key={valor}
            className="flex items-center gap-3 rounded-md border border-gray-300 p-3 text-base"
          >
            <input
              type="radio"
              name="tipo"
              value={valor}
              checked={tipo === valor}
              onChange={() => setTipo(valor)}
            />
            {texto}
          </label>
        ))}
      </fieldset>

      <Campo rotulo="Seu nome" name="nome" autoComplete="name" required maxLength={120} defaultValue={v.nome} />
      <Campo
        rotulo="Telefone com DDD"
        name="telefone"
        type="tel"
        autoComplete="tel"
        inputMode="tel"
        placeholder="(11) 98765-4321"
        required
        defaultValue={v.telefone}
        ajuda="Só você e a equipe do Captador veem seu telefone."
      />

      {tipo === "imobiliaria" && (
        <>
          <Campo
            rotulo="Nome da imobiliária"
            name="imobiliaria_nome"
            autoComplete="organization"
            required
            maxLength={120}
            defaultValue={v.imobiliaria_nome}
          />
          <Campo
            rotulo="CRECI da imobiliária"
            name="creci"
            required
            maxLength={30}
            defaultValue={v.creci}
            ajuda="Vamos conferir o CRECI antes de liberar o acesso ao catálogo."
          />
        </>
      )}

      <Campo rotulo="E-mail" name="email" type="email" autoComplete="email" required defaultValue={v.email} />
      <Campo
        rotulo="Senha"
        name="senha"
        type="password"
        autoComplete="new-password"
        required
        minLength={SENHA_MINIMO}
        ajuda={`Pelo menos ${SENHA_MINIMO} caracteres.`}
      />

      <BotaoEnviar pendente={pendente}>Criar conta</BotaoEnviar>
    </form>
  );
}
