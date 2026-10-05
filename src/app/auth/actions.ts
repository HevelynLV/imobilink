"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { SENHA_MINIMO, normalizarTelefone, telefoneValido, texto } from "@/lib/validacao";

// Server Actions de login. Ver a regra do CLAUDE.md sobre exigirTipo():
// entrar, cadastrar e pedirRecuperacao são para quem ainda não está logado;
// sair e redefinirSenha valem para qualquer tipo de usuário.
//
// Toda action devolve um EstadoFormulario (mensagem de erro ou de sucesso)
// ou redireciona. "valores" devolve o que a pessoa digitou (nunca a senha),
// para o formulário não ficar vazio depois de um erro.

export type EstadoFormulario = {
  erro?: string;
  sucesso?: string;
  valores?: Record<string, string>;
};

// Endereço do nosso site (ex.: http://localhost:3000), para montar o link de
// volta dos e-mails. Vem do cabeçalho Origin: o Next.js já recusa Server
// Actions cujo Origin não bate com o site, e o Supabase só aceita endereços
// cadastrados em Redirect URLs no painel.
async function enderecoDoSite() {
  const h = await headers();
  return h.get("origin") ?? `https://${h.get("host")}`;
}

// ---------------------------------------------------------------
// Cadastro
// ---------------------------------------------------------------
export async function cadastrar(
  _estado: EstadoFormulario,
  formData: FormData
): Promise<EstadoFormulario> {
  const tipo = texto(formData, "tipo");
  const nome = texto(formData, "nome");
  const telefone = texto(formData, "telefone");
  const email = texto(formData, "email");
  const senha = String(formData.get("senha") ?? "");
  const imobiliariaNome = texto(formData, "imobiliaria_nome");
  const creci = texto(formData, "creci");

  const valores = { tipo, nome, telefone, email, imobiliaria_nome: imobiliariaNome, creci };
  const falhar = (erro: string) => ({ erro, valores });

  // O banco confere tudo de novo (o navegador pode ser manipulado).
  // Aqui é só para dar uma mensagem clara.
  if (tipo !== "proprietario" && tipo !== "imobiliaria") {
    return falhar("Escolha se você é proprietário ou imobiliária.");
  }
  if (!nome || nome.length > 120) return falhar("Informe seu nome (até 120 caracteres).");
  if (!telefoneValido(telefone)) {
    return falhar("Telefone inválido. Use DDD + número, ex.: (11) 98765-4321.");
  }
  if (!email) return falhar("Informe seu e-mail.");
  if (senha.length < SENHA_MINIMO) {
    return falhar(`A senha precisa ter pelo menos ${SENHA_MINIMO} caracteres.`);
  }
  if (tipo === "imobiliaria") {
    if (!imobiliariaNome || imobiliariaNome.length > 120) {
      return falhar("Informe o nome da imobiliária (até 120 caracteres).");
    }
    if (!creci || creci.length > 30) return falhar("Informe o CRECI da imobiliária.");
  }

  // Estes dados chegam ao trigger criar_perfil_no_cadastro no banco.
  // Só os campos do tipo escolhido são enviados.
  const dados: Record<string, string> = {
    tipo,
    nome,
    telefone: normalizarTelefone(telefone),
  };
  if (tipo === "imobiliaria") {
    dados.imobiliaria_nome = imobiliariaNome;
    dados.creci = creci;
  }

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signUp({
    email,
    password: senha,
    options: {
      data: dados,
      // Com a confirmação de e-mail ligada, o link do e-mail volta para cá.
      emailRedirectTo: `${await enderecoDoSite()}/auth/callback/cadastro`,
    },
  });

  if (error) {
    if (error.code === "user_already_exists") {
      return falhar("Já existe uma conta com este e-mail. Tente entrar ou recuperar a senha.");
    }
    if (error.code === "weak_password") {
      return falhar("Senha fraca. Use uma senha mais longa e difícil de adivinhar.");
    }
    if (error.code === "over_email_send_rate_limit") {
      return falhar("Muitos cadastros em pouco tempo. Espere alguns minutos e tente de novo.");
    }
    if (error.message.includes("Database error")) {
      // O trigger recusou. Com o formulário validado acima, o motivo mais
      // provável é CRECI repetido. Não confirmamos isso, para não revelar
      // quais CRECIs estão cadastrados.
      return falhar(
        "Não foi possível concluir o cadastro. Confira os dados. Se o CRECI já estiver cadastrado, fale com o suporte do Captador."
      );
    }
    console.error("Erro no cadastro:", error.code, error.message);
    return falhar("Não foi possível concluir o cadastro. Tente de novo em alguns minutos.");
  }

  // Confirmação de e-mail DESLIGADA: o Supabase já devolve a sessão.
  // Confirmação LIGADA: não há sessão até a pessoa clicar no link do e-mail.
  if (!data.session) {
    return {
      sucesso: `Enviamos um link de confirmação para ${email}. Abra o e-mail e clique no link para ativar sua conta, de preferência neste mesmo navegador.`,
    };
  }

  redirect("/");
}

// ---------------------------------------------------------------
// Login e logout
// ---------------------------------------------------------------
export async function entrar(
  _estado: EstadoFormulario,
  formData: FormData
): Promise<EstadoFormulario> {
  const email = texto(formData, "email");
  const senha = String(formData.get("senha") ?? "");
  const valores = { email };

  if (!email || !senha) return { erro: "Informe e-mail e senha.", valores };

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password: senha });

  if (error) {
    if (error.code === "email_not_confirmed") {
      return { erro: "Confirme seu e-mail antes de entrar. Procure o link na sua caixa de entrada.", valores };
    }
    // Mesma mensagem para e-mail inexistente e senha errada: não revelamos
    // quais e-mails têm conta.
    return { erro: "E-mail ou senha incorretos.", valores };
  }

  // A página inicial manda cada tipo para a sua área.
  redirect("/");
}

export async function sair() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}

// ---------------------------------------------------------------
// Recuperação de senha
// ---------------------------------------------------------------
export async function pedirRecuperacao(
  _estado: EstadoFormulario,
  formData: FormData
): Promise<EstadoFormulario> {
  const email = texto(formData, "email");
  if (!email) return { erro: "Informe seu e-mail." };

  const supabase = await createClient();
  // O link do e-mail volta para esta rota, que cria a sessão e manda para
  // /redefinir-senha. O link só funciona neste mesmo navegador (fluxo PKCE).
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${await enderecoDoSite()}/auth/callback/recuperacao`,
  });

  if (error?.code === "over_email_send_rate_limit") {
    return { erro: "Muitos pedidos em pouco tempo. Espere alguns minutos e tente de novo.", valores: { email } };
  }
  if (error) console.error("Erro ao pedir recuperação:", error.code, error.message);

  // Mesma resposta exista ou não a conta: não revelamos quais e-mails têm conta.
  return {
    sucesso: `Se existir uma conta para ${email}, enviamos um link para criar uma nova senha. Abra o link neste mesmo navegador.`,
  };
}

export async function redefinirSenha(
  _estado: EstadoFormulario,
  formData: FormData
): Promise<EstadoFormulario> {
  const senha = String(formData.get("senha") ?? "");
  const confirmacao = String(formData.get("confirmacao") ?? "");

  if (senha.length < SENHA_MINIMO) {
    return { erro: `A senha precisa ter pelo menos ${SENHA_MINIMO} caracteres.` };
  }
  if (senha !== confirmacao) return { erro: "As duas senhas não são iguais." };

  const supabase = await createClient();

  // Só troca a senha de quem está logado. O link do e-mail de recuperação
  // (via /auth/confirm) é o que cria essa sessão.
  const { data } = await supabase.auth.getClaims();
  if (!data?.claims?.sub) redirect("/esqueci-senha?expirado=1");

  const { error } = await supabase.auth.updateUser({ password: senha });

  if (error) {
    if (error.code === "same_password") return { erro: "A nova senha precisa ser diferente da antiga." };
    if (error.code === "weak_password") return { erro: "Senha fraca. Use uma senha mais longa e difícil de adivinhar." };
    console.error("Erro ao redefinir senha:", error.code, error.message);
    return { erro: "Não foi possível trocar a senha. Peça um novo link e tente de novo." };
  }

  redirect("/");
}
