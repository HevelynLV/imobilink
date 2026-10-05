// Validações do cadastro. As mesmas regras existem no banco (migration
// 20261005120000_cadastro_e_perfis.sql); aqui servem só para mostrar uma
// mensagem clara antes de enviar. Se mudar uma, mude a outra.

// Celular: DDD + 9 + 8 dígitos. Fixo: DDD + [2-5] + 7 dígitos. DDD sem zero.
const TELEFONE_BR = /^[1-9]{2}(9[0-9]{8}|[2-5][0-9]{7})$/;

export const SENHA_MINIMO = 8;

// "(11) 98765-4321" ou "+55 11 98765-4321" -> "11987654321"
export function normalizarTelefone(valor: string): string {
  const digitos = valor.replace(/\D/g, "");
  if ((digitos.length === 12 || digitos.length === 13) && digitos.startsWith("55")) {
    return digitos.slice(2);
  }
  return digitos;
}

export function telefoneValido(valor: string): boolean {
  return TELEFONE_BR.test(normalizarTelefone(valor));
}

// Lê um campo de texto do formulário, sem espaços nas pontas.
export function texto(formData: FormData, campo: string): string {
  const valor = formData.get(campo);
  return typeof valor === "string" ? valor.trim() : "";
}
