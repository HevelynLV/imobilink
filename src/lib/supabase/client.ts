import { createBrowserClient } from "@supabase/ssr";

// Cliente do Supabase para código que roda no NAVEGADOR
// (componentes com "use client": botões, formulários interativos).
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!
  );
}
