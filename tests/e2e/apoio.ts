import { expect, type BrowserContext, type Page } from "@playwright/test";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { createServerClient } from "@supabase/ssr";

// Funções de apoio dos testes e2e. Reaproveite nas próximas etapas.
//
// ATENÇÃO: o banco do Supabase é compartilhado. Os testes criam contas reais
// com e-mails no padrão teste+<algo>-<timestamp>@exemplo.com e as apagam no
// fim. apagarContasDeTeste() se recusa a apagar qualquer outro e-mail.

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
const PUBLISHABLE_KEY = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "";
// Chave secreta: só nos testes (Node), nunca no app. Ignora o RLS.
const SECRET_KEY = process.env.SUPABASE_SECRET_KEY ?? "";

export const SENHA_TESTE = "SenhaDeTeste123!";
export const TELEFONE_TESTE = "(11) 98765-4321";

const PADRAO_EMAIL_TESTE = /^teste\+[a-z0-9-]+@exemplo\.com$/;

export function novoEmail(algo: string): string {
  const sufixo = `${Date.now()}${Math.floor(Math.random() * 1000)}`;
  return `teste+${algo}-${sufixo}@exemplo.com`;
}

// ---------------------------------------------------------------
// Clientes do Supabase
// ---------------------------------------------------------------

// Cliente "admin" (chave secreta): apaga contas e promove a admin.
let admin: SupabaseClient | null = null;
export function clienteAdmin(): SupabaseClient {
  if (!SUPABASE_URL || !SECRET_KEY) {
    throw new Error(
      "Falta NEXT_PUBLIC_SUPABASE_URL ou SUPABASE_SECRET_KEY no .env.local (ver ROADMAP, seção Atenção)."
    );
  }
  admin ??= createClient(SUPABASE_URL, SECRET_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return admin;
}

// Cliente igual ao de um visitante qualquer (chave publishable), fora do app.
export function clientePublico(): SupabaseClient {
  return createClient(SUPABASE_URL, PUBLISHABLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

// Cliente que usa a MESMA sessão do navegador do teste (lê e grava os cookies
// de login do app). É o equivalente a rodar código no console da página logada.
export function clienteDaSessaoDoNavegador(context: BrowserContext): SupabaseClient {
  return createServerClient(SUPABASE_URL, PUBLISHABLE_KEY, {
    cookies: {
      async getAll() {
        const cookies = await context.cookies("http://localhost:3000");
        return cookies.map(({ name, value }) => ({ name, value }));
      },
      async setAll(cookiesToSet) {
        for (const { name, value, options } of cookiesToSet) {
          if (!value || options?.maxAge === 0) {
            await context.clearCookies({ name });
            continue;
          }
          await context.addCookies([
            {
              name,
              value,
              domain: "localhost",
              path: options?.path ?? "/",
              sameSite: "Lax",
              expires: options?.maxAge ? Math.floor(Date.now() / 1000) + options.maxAge : -1,
            },
          ]);
        }
      },
    },
  });
}

// ---------------------------------------------------------------
// Contas de teste: busca, promoção e limpeza
// ---------------------------------------------------------------

const contasCriadas = new Set<string>();

// Os e-mails de teste (@exemplo.com) não existem. Se a confirmação de e-mail
// estiver LIGADA no Supabase, cada cadastro tentaria mandar e-mail para lá:
// gasta o limite de envios e os e-mails devolvidos prejudicam o projeto.
// /auth/v1/settings é público e não manda e-mail: mailer_autoconfirm = true
// quer dizer confirmação DESLIGADA.
let checagemConfirmacao: Promise<void> | null = null;
function garantirConfirmacaoDesligada(): Promise<void> {
  checagemConfirmacao ??= (async () => {
    const resposta = await fetch(`${SUPABASE_URL}/auth/v1/settings`, {
      headers: { apikey: PUBLISHABLE_KEY },
    });
    if (!resposta.ok) {
      throw new Error(`Não consegui ler as configurações do Supabase Auth (HTTP ${resposta.status}).`);
    }
    const config = (await resposta.json()) as { mailer_autoconfirm?: boolean };
    if (config.mailer_autoconfirm !== true) {
      throw new Error(
        "PARADO: a confirmação de e-mail está LIGADA no Supabase. Os testes criam contas " +
          "@exemplo.com e cada cadastro tentaria mandar e-mail para um endereço que não existe. " +
          "Desligue em Authentication > Sign In / Providers > Email > Confirm email, ou rode " +
          'só os testes que não criam conta: npx playwright test -g "deslogado|Teste 5"'
      );
    }
  })();
  return checagemConfirmacao;
}

// Chame ANTES de criar qualquer conta. Para o teste (sem criar nada) se faltar
// a chave secreta (a conta não daria para apagar depois) ou se a confirmação
// de e-mail estiver ligada. Depois anota o e-mail para ser apagado no fim.
export async function registrarParaApagar(email: string) {
  clienteAdmin();
  await garantirConfirmacaoDesligada();
  contasCriadas.add(email);
}

export async function buscarUsuarioId(email: string): Promise<string | null> {
  const porPagina = 1000;
  for (let pagina = 1; ; pagina++) {
    const { data, error } = await clienteAdmin().auth.admin.listUsers({ page: pagina, perPage: porPagina });
    if (error) throw error;
    const achado = data.users.find((u) => u.email?.toLowerCase() === email.toLowerCase());
    if (achado) return achado.id;
    if (data.users.length < porPagina) return null;
  }
}

export async function lerPerfil(email: string) {
  const id = await buscarUsuarioId(email);
  if (!id) return null;
  const { data, error } = await clienteAdmin()
    .from("perfis")
    .select("tipo, nome, telefone, imobiliaria_id, imobiliarias(nome, creci, status_assinatura)")
    .eq("id", id)
    .maybeSingle();
  if (error) throw error;
  return data;
}

// Mesmo comando do supabase/scripts/criar_admin.sql: só promove quem é
// proprietário. Roda como service_role (chave secreta), que, como o postgres
// do SQL Editor, não é barrado pela trava de "tipo" (ela só vale para
// usuários logados pelo app).
export async function promoverAAdmin(email: string) {
  const id = await buscarUsuarioId(email);
  expect(id, `conta ${email} não encontrada`).not.toBeNull();
  const { data, error } = await clienteAdmin()
    .from("perfis")
    .update({ tipo: "admin" })
    .eq("id", id!)
    .eq("tipo", "proprietario")
    .select("id, tipo");
  if (error) throw error;
  expect(data, "a promoção deveria alterar exatamente 1 perfil").toHaveLength(1);
}

export async function apagarContasDeTeste() {
  for (const email of contasCriadas) {
    if (!PADRAO_EMAIL_TESTE.test(email)) {
      throw new Error(`Recusado: ${email} não é um e-mail de teste`);
    }
    const id = await buscarUsuarioId(email);
    if (!id) {
      contasCriadas.delete(email);
      continue;
    }
    const perfil = await lerPerfil(email);

    // Apagar o usuário apaga o perfil junto (on delete cascade)...
    const { error } = await clienteAdmin().auth.admin.deleteUser(id);
    if (error) throw error;

    // ...mas não a imobiliária criada no cadastro: apaga à mão.
    if (perfil?.imobiliaria_id) {
      const { error: erroImob } = await clienteAdmin()
        .from("imobiliarias")
        .delete()
        .eq("id", perfil.imobiliaria_id);
      if (erroImob) throw erroImob;
    }
    contasCriadas.delete(email);
  }
}

// ---------------------------------------------------------------
// Ações pela tela do app
// ---------------------------------------------------------------

type DadosCadastro = {
  tipo: "proprietario" | "imobiliaria";
  nome: string;
  email: string;
  imobiliariaNome?: string;
  creci?: string;
};

export async function preencherCadastro(page: Page, dados: DadosCadastro) {
  await page.goto("/cadastro");
  await page
    .getByLabel(dados.tipo === "proprietario" ? /^Proprietário:/ : /^Imobiliária ou corretor:/)
    .check();
  await page.getByLabel("Seu nome").fill(dados.nome);
  await page.getByLabel("Telefone com DDD").fill(TELEFONE_TESTE);
  if (dados.tipo === "imobiliaria") {
    await page.getByLabel("Nome da imobiliária").fill(dados.imobiliariaNome ?? "");
    await page.getByLabel("CRECI da imobiliária").fill(dados.creci ?? "");
  }
  await page.getByLabel("E-mail").fill(dados.email);
  await page.getByLabel("Senha").fill(SENHA_TESTE);
  await page.getByRole("button", { name: "Criar conta" }).click();
}

// Cadastra pela tela e confere que caiu na área do tipo.
export async function cadastrarPelaTela(page: Page, dados: DadosCadastro) {
  await registrarParaApagar(dados.email);
  await preencherCadastro(page, dados);
  await expect(page).toHaveURL(`/${dados.tipo}`);
}

export async function entrar(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-mail").fill(email);
  await page.getByLabel("Senha").fill(SENHA_TESTE);
  await page.getByRole("button", { name: "Entrar" }).click();
}

export async function sair(page: Page) {
  await page.getByRole("button", { name: "Sair" }).click();
  await expect(page).toHaveURL("/login");
}

// Tenta abrir cada endereço e confere que volta para a própria área.
export async function conferirQueSoAbreAPropriaArea(page: Page, propriaArea: string) {
  for (const destino of ["/proprietario", "/imobiliaria", "/admin", "/login", "/cadastro", "/"]) {
    await page.goto(destino);
    await expect(page, `abrindo ${destino}`).toHaveURL(propriaArea);
  }
}
