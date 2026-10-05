import { defineConfig, devices } from "@playwright/test";
import { loadEnvConfig } from "@next/env";

// Configuração dos testes de ponta a ponta (e2e): o Playwright abre um
// navegador de verdade, clica e digita como uma pessoa, contra o app rodando
// em localhost:3000 e o banco do Supabase (compartilhado!).

// Carrega o .env.local do mesmo jeito que o Next.js carrega.
loadEnvConfig(process.cwd());

export default defineConfig({
  testDir: "tests/e2e",

  // Um teste por vez: os testes criam contas no banco compartilhado e o
  // Supabase limita cadastros por minuto.
  fullyParallel: false,
  workers: 1,

  // Cada teste tem até 60 s (a primeira abertura de página no `next dev` é lenta).
  timeout: 60_000,

  // Lista no terminal + relatório HTML em playwright-report/ (fora do git).
  reporter: [["list"], ["html", { open: "never" }]],

  use: {
    baseURL: "http://localhost:3000",
    // Guarda um "filme" do teste (telas, cliques, rede) só quando falha.
    // Ver com: npx playwright show-trace <arquivo.zip>
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },

  projects: [
    {
      // O Captador é pensado primeiro para celular.
      name: "celular",
      use: { ...devices["Pixel 7"] },
    },
  ],

  // Usa o `npm run dev` que já estiver aberto; se não houver, abre um.
  webServer: {
    command: "npm run dev",
    url: "http://localhost:3000",
    reuseExistingServer: true,
    timeout: 120_000,
  },
});
