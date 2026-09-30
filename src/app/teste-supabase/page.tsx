import { createClient } from "@/lib/supabase/server";

export default async function TesteSupabase() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  if (!url || !key) {
    return (
      <p className="p-8 text-red-600">
        ❌ Variáveis de ambiente não encontradas. Confira o .env.local e reinicie o npm run dev.
      </p>
    );
  }

  const supabase = await createClient();
  // Ainda não temos tabelas. Consultamos uma que não existe de propósito:
  // se o Supabase responder "tabela não encontrada", é porque URL e chave funcionaram.
  const { error } = await supabase.from("tabela_inexistente").select("*").limit(1);

  const conectado = error?.code === "PGRST205" || error?.code === "42P01";

  return (
    <main className="p-8 space-y-4">
      <h1 className="text-2xl font-bold">Teste de conexão com o Supabase</h1>
      <p className={conectado ? "text-green-600" : "text-red-600"}>
        {conectado ? "✅ Conectado ao Supabase!" : "❌ Falha na conexão"}
      </p>
      <pre className="bg-gray-100 text-gray-900 p-4 rounded text-sm">
        {JSON.stringify(error, null, 2)}
      </pre>
    </main>
  );
}
