import { expect, test } from "@playwright/test";
import {
  apagarContasDeTeste,
  buscarUsuarioId,
  cadastrarPelaTela,
  clienteDaSessaoDoNavegador,
  clientePublico,
  conferirQueSoAbreAPropriaArea,
  entrar,
  lerPerfil,
  novoEmail,
  preencherCadastro,
  promoverAAdmin,
  registrarParaApagar,
  sair,
  SENHA_TESTE,
} from "./apoio";

// Etapa 3 · Login e perfis. "Pronto quando: cada tipo de usuário só abre a
// própria área." Pré-requisitos: confirmação de e-mail DESLIGADA no painel do
// Supabase e SUPABASE_SECRET_KEY no .env.local. Os testes que criam conta
// conferem os dois antes de cadastrar e param com uma mensagem clara.

const PRINTS = "tests/e2e/prints";

// Apaga as contas criadas, mesmo se algum teste falhar.
test.afterAll(async () => {
  await apagarContasDeTeste();
});

test.describe("Teste 1: cada tipo só abre a própria área", () => {
  test("deslogado vai para /login", async ({ page }) => {
    for (const area of ["/proprietario", "/imobiliaria", "/admin", "/"]) {
      await page.goto(area);
      await expect(page, `abrindo ${area}`).toHaveURL("/login");
    }
  });

  test("proprietário", async ({ page }) => {
    const email = novoEmail("prop");
    await cadastrarPelaTela(page, { tipo: "proprietario", nome: "Prop Teste", email });
    await expect(page.getByRole("heading", { name: "Olá, Prop Teste" })).toBeVisible();
    await page.screenshot({ path: `${PRINTS}/proprietario.png`, fullPage: true });

    await conferirQueSoAbreAPropriaArea(page, "/proprietario");

    // telefone gravado só com dígitos, sem imobiliária
    const perfil = await lerPerfil(email);
    expect(perfil).toMatchObject({ tipo: "proprietario", telefone: "11987654321", imobiliaria_id: null });

    await sair(page);
    await page.goto("/proprietario");
    await expect(page).toHaveURL("/login");
  });

  test("imobiliária (nasce pendente)", async ({ page }) => {
    const email = novoEmail("imob");
    const creci = `E2E-${Date.now()}`;
    await cadastrarPelaTela(page, {
      tipo: "imobiliaria",
      nome: "Corretor Teste",
      email,
      imobiliariaNome: "Imob Teste E2E",
      creci,
    });
    await expect(page.getByText(/assinatura está pendente/)).toBeVisible();
    await page.screenshot({ path: `${PRINTS}/imobiliaria.png`, fullPage: true });

    await conferirQueSoAbreAPropriaArea(page, "/imobiliaria");

    const perfil = await lerPerfil(email);
    expect(perfil).toMatchObject({
      tipo: "imobiliaria",
      imobiliarias: { nome: "Imob Teste E2E", creci, status_assinatura: "pendente" },
    });

    await sair(page);
  });

  test("admin (promovido como no criar_admin.sql)", async ({ page }) => {
    const email = novoEmail("admin");
    await cadastrarPelaTela(page, { tipo: "proprietario", nome: "Admin Teste", email });
    await sair(page);

    await promoverAAdmin(email);

    await entrar(page, email);
    await expect(page).toHaveURL("/admin");
    await expect(page.getByRole("heading", { name: "Olá, Admin Teste" })).toBeVisible();
    await page.screenshot({ path: `${PRINTS}/admin.png`, fullPage: true });

    await conferirQueSoAbreAPropriaArea(page, "/admin");
    await sair(page);
  });
});

test("Teste 2: mudar o próprio user_metadata para admin não dá acesso a /admin", async ({
  page,
  context,
}) => {
  const email = novoEmail("metadata");
  await cadastrarPelaTela(page, { tipo: "proprietario", nome: "Prop Metadata", email });

  // Mesma sessão do navegador logado (cookies do app)
  const sb = clienteDaSessaoDoNavegador(context);
  const { data: antes } = await sb.auth.getUser();
  expect(antes.user?.email, "o cliente deveria usar a sessão do app").toBe(email);

  // O usuário CONSEGUE mudar o próprio metadata...
  const { error } = await sb.auth.updateUser({ data: { tipo: "admin" } });
  expect(error).toBeNull();
  await sb.auth.refreshSession();
  const { data: claims } = await sb.auth.getClaims();
  expect(claims?.claims.user_metadata?.tipo, "o token novo deveria trazer tipo=admin").toBe("admin");

  // ...mas isso não abre /admin, porque o app lê o tipo da tabela perfis.
  await page.goto("/admin");
  await expect(page).toHaveURL("/proprietario");

  const perfil = await lerPerfil(email);
  expect(perfil?.tipo).toBe("proprietario");
});

test("Teste 3: signUp direto pela API com tipo admin é recusado e não cria usuário", async () => {
  const email = novoEmail("hacker");
  await registrarParaApagar(email); // por garantia, se o teste falhar e a conta existir

  const { data, error } = await clientePublico().auth.signUp({
    email,
    password: SENHA_TESTE,
    options: { data: { tipo: "admin", nome: "Hacker", telefone: "11987654321" } },
  });

  expect(error?.message).toContain("Database error");
  expect(data.user).toBeNull();
  expect(await buscarUsuarioId(email), "não pode sobrar usuário em auth.users").toBeNull();
});

test("Teste 4: CRECI repetido mostra a mensagem genérica e não cria usuário", async ({ page }) => {
  const creci = `E2E-${Date.now()}`;
  await cadastrarPelaTela(page, {
    tipo: "imobiliaria",
    nome: "Primeira Imob",
    email: novoEmail("creci1"),
    imobiliariaNome: "Primeira Imob",
    creci,
  });
  await sair(page);

  // Mesmo CRECI, em minúsculas e com espaços: o banco trata como igual.
  const email2 = novoEmail("creci2");
  await registrarParaApagar(email2);
  await preencherCadastro(page, {
    tipo: "imobiliaria",
    nome: "Segunda Imob",
    email: email2,
    imobiliariaNome: "Segunda Imob",
    creci: `  ${creci.toLowerCase()} `,
  });

  // filter: o Next.js também põe na página um elemento invisível com
  // role="alert" (o __next-route-announcer__, para leitores de tela).
  await expect(
    page.getByRole("alert").filter({
      hasText:
        "Não foi possível concluir o cadastro. Confira os dados. Se o CRECI já estiver cadastrado, fale com o suporte do Captador.",
    })
  ).toBeVisible();
  await expect(page).toHaveURL("/cadastro");
  // o formulário não perde o que foi digitado
  await expect(page.getByLabel("E-mail")).toHaveValue(email2);
  expect(await buscarUsuarioId(email2), "não pode sobrar usuário em auth.users").toBeNull();
});

test.describe("Teste 5: recuperação de senha (sem depender do e-mail)", () => {
  test("pedir o link mostra a mensagem certa", async ({ page }) => {
    // E-mail que NÃO tem conta: o Supabase não manda e-mail (não gasta o
    // limite de envios nem gera e-mail devolvido), e a resposta tem que ser
    // igual à de uma conta que existe.
    const email = novoEmail("semconta");
    await page.goto("/esqueci-senha");
    await page.getByLabel("E-mail da sua conta").fill(email);
    await page.getByRole("button", { name: "Enviar link" }).click();
    await expect(page.getByRole("status")).toHaveText(
      `Se existir uma conta para ${email}, enviamos um link para criar uma nova senha. Abra o link neste mesmo navegador.`
    );
  });

  const AVISO_RECUPERACAO = /O link de recuperação venceu, já foi usado ou foi aberto em outro navegador/;
  const AVISO_CONFIRMACAO = /Não conseguimos concluir a confirmação por este link/;
  const AVISO_LINK = /Este link é inválido ou já venceu/;

  const casos: [string, string, RegExp][] = [
    ["/auth/callback/recuperacao?code=falso", "/esqueci-senha?expirado=1", AVISO_RECUPERACAO],
    ["/auth/callback/recuperacao", "/esqueci-senha?expirado=1", AVISO_RECUPERACAO],
    [
      "/auth/callback/recuperacao?error=access_denied&error_code=otp_expired",
      "/esqueci-senha?expirado=1",
      AVISO_RECUPERACAO,
    ],
    ["/auth/callback/cadastro?code=falso", "/login?erro=confirmacao", AVISO_CONFIRMACAO],
    ["/auth/confirm?token_hash=falso&type=recovery", "/login?erro=link", AVISO_LINK],
    ["/auth/confirm?token_hash=falso&type=invite", "/login?erro=link", AVISO_LINK],
    ["/redefinir-senha", "/esqueci-senha?expirado=1", AVISO_RECUPERACAO],
  ];

  for (const [abrir, destino, aviso] of casos) {
    test(`${abrir} → ${destino}`, async ({ page }) => {
      await page.goto(abrir);
      await expect(page).toHaveURL(destino);
      // filter: ver a explicação no Teste 4 (__next-route-announcer__)
      await expect(page.getByRole("alert").filter({ hasText: aviso })).toBeVisible();
    });
  }
});
