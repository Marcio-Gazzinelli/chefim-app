
const MODEL = "@cf/openai/gpt-oss-20b";

function json(data, status = 200) {
    return Response.json(data, {
        status,
        headers: {
            "Cache-Control": "no-store",
        },
    });
}

// Valida a sessão Supabase junto ao servidor Auth (não confia em JWT decodificado).
async function authenticate(request, env) {
    if (!env.SUPABASE_URL || !env.SUPABASE_PUBLISHABLE_KEY) {
        return { error: json({ error: "Autenticação não configurada no servidor." }, 503) };
    }

    const match = /^Bearer\s+(.+)$/i.exec(request.headers.get("authorization") ?? "");
    const token = match?.[1]?.trim();
    if (!token || token.length > 8192) {
        return { error: json({ error: "Entre na sua conta para gerar receitas." }, 401) };
    }

    let authUrl;
    try {
        const base = new URL(env.SUPABASE_URL);
        if (base.protocol !== "https:" || base.username || base.password ||
            base.search || base.hash) throw new Error("URL inválida");
        authUrl = new URL("/auth/v1/user", base.origin);
    } catch (_) {
        return { error: json({ error: "Configuração de autenticação inválida." }, 503) };
    }

    let response;
    try {
        response = await fetch(authUrl, {
            headers: {
                apikey: env.SUPABASE_PUBLISHABLE_KEY,
                Authorization: `Bearer ${token}`,
            },
            signal: AbortSignal.timeout(10000),
        });
    } catch (_) {
        return { error: json({ error: "Serviço de autenticação indisponível." }, 503) };
    }

    if (response.status === 401 || response.status === 403) {
        return { error: json({ error: "Sessão inválida ou expirada. Entre novamente." }, 401) };
    }
    if (!response.ok) {
        return { error: json({ error: "Não foi possível validar sua sessão." }, 503) };
    }

    let user;
    try { user = await response.json(); } catch (_) {
        return { error: json({ error: "Resposta de autenticação inválida." }, 503) };
    }
    if (!validText(user?.id)) {
        return { error: json({ error: "Usuário não autenticado." }, 401) };
    }
    return { userId: user.id };
}

function validText(value) {
    return typeof value === "string" &&
        value.trim().length > 0;
}


function extractText(result) {
    // Formato Chat Completions, retornado pelo
    // @cf/openai/gpt-oss-20b nos nossos testes.
    const choiceContent = result?.choices?.[0]?.message?.content;

    if (typeof choiceContent === "string" &&
        choiceContent.trim().length > 0) {
        return choiceContent;
    }

    // Formato alternativo de algumas APIs.
    if (typeof result?.response === "string") {
        return result.response;
    }

    if (result?.response &&
        typeof result.response === "object") {
        return JSON.stringify(result.response);
    }

    // Formato de respostas com blocos de saída.
    const parts = [];

    for (const item of result?.output ?? []) {
        if (item.type !== "message") continue;

        for (const content of item.content ?? []) {
            if (typeof content.text === "string") {
                parts.push(content.text);
            }
        }
    }

    if (parts.length > 0) {
        return parts.join("\n");
    }

    throw new Error(
        "A IA não retornou conteúdo em um formato reconhecido."
    );
}


function parseRecipe(result) {
    const text = extractText(result).trim();
    const cleaned = text
        .replace(/^```(?:json)?\s*/i, "")
        .replace(/\s*```$/, "");

    // Respostas válidas às vezes contêm texto antes/depois do objeto.
    // Usamos somente o bloco JSON caso o texto completo não seja JSON.
    let recipe;
    try {
        recipe = JSON.parse(cleaned);
    } catch (_) {
        const start = cleaned.indexOf("{");
        const end = cleaned.lastIndexOf("}");
        if (start < 0 || end <= start) {
            throw new Error("JSON ausente ou incompleto.");
        }
        recipe = JSON.parse(cleaned.slice(start, end + 1));
    }

    if (!recipe || typeof recipe !== "object" || Array.isArray(recipe)) {
        throw new Error("Resposta não é um objeto de receita.");
    }

    // O modelo pode gerar quantidade como número; o Flutter espera String.
    if (Array.isArray(recipe.ingredientes)) {
        recipe.ingredientes = recipe.ingredientes.map((item) => {
            if (!item || typeof item !== "object" || Array.isArray(item)) {
                return item;
            }
            const normalized = { ...item };
            if (typeof normalized.quantidade === "number" &&
                Number.isFinite(normalized.quantidade) &&
                normalized.quantidade > 0) {
                normalized.quantidade = String(normalized.quantidade);
            }
            return normalized;
        });
    }

    // Validacao explicita: facilita diagnosticar o campo que o modelo errou,
    // sem registrar o conteudo da receita nem dados do usuario.
    if (!validText(recipe.nome)) {
        throw new Error("Campo nome ausente ou vazio.");
    }
    if (!Number.isInteger(recipe.porcoes) ||
        recipe.porcoes < 1 || recipe.porcoes > 10) {
        throw new Error("Campo porcoes invalido (esperado inteiro entre 1 e 10).");
    }
    if (!Array.isArray(recipe.ingredientes) ||
        recipe.ingredientes.length === 0) {
        throw new Error("Campo ingredientes ausente ou vazio.");
    }
    if (!Array.isArray(recipe.preparo) || recipe.preparo.length < 3) {
        throw new Error("Campo preparo com menos de 3 etapas.");
    }
    for (const [index, step] of recipe.preparo.entries()) {
        if (!validText(step)) {
            throw new Error(`Etapa ${index + 1} do preparo invalida.`);
        }
    }
    for (const [index, item] of recipe.ingredientes.entries()) {
        if (!item || typeof item !== "object" || Array.isArray(item)) {
            throw new Error(`Ingrediente ${index + 1}: objeto invalido.`);
        }
        if (!validText(item.nome)) {
            throw new Error(`Ingrediente ${index + 1}: nome invalido.`);
        }
        if (!validText(item.quantidade)) {
            throw new Error(`Ingrediente ${index + 1}: quantidade invalida.`);
        }


        if (!validText(item.unidade)) {
            const quantidade = String(item.quantidade ?? '')
                .trim()
                .toLowerCase();

            const quantidadeSemMedida = [
                'a gosto',
                'à gosto',
                'quanto baste',
                'q.b.',
                'qb',
            ].includes(quantidade);

            if (quantidadeSemMedida) {

                item.unidade = '';
            } else {
                console.warn('Chefim: unidade inválida detectada', {
                    ingredienteNumero: index + 1,
                    nome: item.nome,
                    quantidade: item.quantidade,
                    unidade: item.unidade,
                    tipoUnidade: typeof item.unidade,
                });

                throw new Error(
                    `Ingrediente ${index + 1}: unidade invalida.`
                );
            }
        }


        if (!["selecionado", "adicional"].includes(item.origem)) {
            throw new Error(`Ingrediente ${index + 1}: origem invalida.`);
        }
    }

    // Observações são opcionais. Ignora entradas vazias.
    recipe.observacoes = Array.isArray(recipe.observacoes)
        ? recipe.observacoes.filter(validText)
        : [];

    return recipe;
}

export default {
    async fetch(request, env) {
        const url = new URL(request.url);

        if (url.pathname === "/health" &&
            request.method === "GET") {
            return json({ status: "ok", app: "Chefim" });
        }

        if (url.pathname !== "/recipes/adapt") {
            return json({ error: "Rota não encontrada." }, 404);
        }

        if (request.method !== "POST") {
            return json({ error: "Método não permitido." }, 405);
        }

        // Somente usuários autenticados podem consumir Workers AI.
        const auth = await authenticate(request, env);
        if (auth.error) return auth.error;

        // Limitação aproximada: 5 receitas/minuto por usuário, por região Cloudflare.
        // Se a configuração não existir, falha sem chamar o modelo.
        if (!env.RECIPE_RATE_LIMITER) {
            return json({ error: "Limite de requisições não configurado." }, 503);
        }
        try {
            const { success } = await env.RECIPE_RATE_LIMITER.limit({
                key: auth.userId,
            });
            if (!success) {
                return json({ error: "Muitas receitas seguidas. Tente novamente em instantes." }, 429);
            }
        } catch (_) {
            return json({ error: "Não foi possível validar o limite de uso." }, 503);
        }

        // Proteção contra corpos grandes, inclusive quando Content-Length está ausente.
        const contentLength = Number(request.headers.get("content-length") ?? 0);
        if (contentLength > 20000) {
            return json({ error: "Requisição muito grande." }, 413);
        }

        const reader = request.body?.getReader();
        if (!reader) return json({ error: "Corpo da requisição ausente." }, 400);
        const chunks = [];
        let size = 0;
        try {
            while (true) {
                const { done, value } = await reader.read();
                if (done) break;
                size += value.byteLength;
                if (size > 20000) {
                    await reader.cancel();
                    return json({ error: "Requisição muito grande." }, 413);
                }
                chunks.push(value);
            }
        } catch (_) {
            return json({ error: "Falha ao ler a requisição." }, 400);
        }
        const bytes = new Uint8Array(size);
        let offset = 0;
        for (const chunk of chunks) {
            bytes.set(chunk, offset);
            offset += chunk.byteLength;
        }
        const rawBody = new TextDecoder().decode(bytes);

        let body;

        try {
            body = JSON.parse(rawBody);
        } catch (_) {
            return json({ error: "JSON inválido." }, 400);
        }

        const products = body?.produtos;
        const reference = body?.referencia;

        if (
            !Array.isArray(products) ||
            products.length < 1 ||
            products.length > 3 ||
            products.some((p) => !validText(p.nome)) ||
            !reference ||
            !validText(reference.nome) ||
            !Array.isArray(reference.ingredientes) ||
            !Array.isArray(reference.preparo) ||
            reference.nome.length > 200 ||
            reference.ingredientes.length > 60 ||
            reference.preparo.length > 60 ||
            products.some((p) => p.nome.length > 200) ||
            reference.ingredientes.some((name) => !validText(name) || name.length > 200) ||
            reference.preparo.some((step) => !validText(step) || step.length > 1500)
        ) {
            return json({ error: "Dados inválidos." }, 400);
        }

        const instructions = `
Você é o motor de adaptação culinária do Chefim.


OBJETIVO:
Gerar uma receita culinária completa, saborosa e coerente
a partir de uma referência da TheMealDB, priorizando os
ingredientes selecionados pelo usuário.

REGRAS:

1. Os ingredientes selecionados representam os alimentos
que o usuário deseja priorizar. Eles NÃO representam
todos os alimentos que o usuário possui em casa.

2. A receita pode utilizar ingredientes que não foram
selecionados, incluindo ingredientes essenciais da
receita original e complementos culinários adequados.

3. Preserve, sempre que possível, a identidade e as
características principais da receita de referência.
Não simplifique uma Carbonara para apenas macarrão
com molho por não haver ovos ou queijo selecionados.

4. Utilize os ingredientes selecionados sempre que
forem culinariamente compatíveis com a receita.
Não force ingredientes que descaracterizem o prato.

5. Se a receita original utilizar uma variedade diferente
da disponível, adapte a variedade quando a substituição
for adequada. Exemplo: penne por espaguete.

6. Ingredientes selecionados e efetivamente utilizados
devem receber origem "selecionado".

7. Ingredientes que não foram selecionados devem
receber origem "adicional", mesmo que o usuário
possa possuí-los em casa.

8. "Adicional" significa apenas que o ingrediente
não foi confirmado entre os produtos selecionados.
NÃO significa que o usuário precisa comprá-lo.

9. Inclua TODOS os ingredientes necessários para
executar a receita gerada, com quantidades e unidades.
Não omita ovos, queijos, temperos ou outros ingredientes
apenas porque não foram selecionados.

10. Respeite as quantidades informadas dos produtos
selecionados e não utilize obrigatoriamente todo o estoque.

11. Ajuste as quantidades para 2 porções, mantendo
proporções culinárias coerentes.

12. Gere de 3 a 6 etapas claras e suficientemente
detalhadas para o preparo seguro da receita.

13. Não invente que o usuário possui ingredientes
que não foram selecionados.

14. Não afirme que ingredientes adicionais estão
faltando ou precisam ser comprados. Essa decisão
será tomada posteriormente pelo usuário.

15. Retorne exclusivamente o JSON no formato solicitado,
com nome, porcoes, ingredientes, preparo e observacoes.

16. Não retorne ingredientes ou preparo vazios como
forma de indicar falta de ingredientes selecionados.

Estrutura obrigatória:
{
  "nome": "Nome da receita",
  "porcoes": 2,
  "ingredientes": [
    {
      "nome": "Nome do ingrediente",
      "quantidade": "200",
      "unidade": "g",
      "origem": "selecionado"
    }
  ],
  "preparo": [
    "Primeira etapa",
    "Segunda etapa",
    "Terceira etapa"
  ],
  "observacoes": [
    "Informações importantes ou adaptações"
  ]
}

Valores permitidos para origem:
"selecionado" e "adicional".

A receita de referência pode conter muitas etapas.
Use-a como orientação culinária, sem reproduzir cada etapa.

Gere entre 3 e 6 etapas de preparo, suficientemente
detalhadas para executar a receita com segurança.

Evite explicações longas e repetitivas.
Limite as observações às informações realmente necessárias.
`;

        const startTime = Date.now();
        try {
            console.log("Chefim: iniciando geração com IA");
            console.log("Referência:", reference.nome);
            console.log(
                "Ingredientes de referência:",
                reference.ingredientes.length
            );

            console.log(
                "Etapas de referência:",
                reference.preparo.length
            );

            console.log(
                "Tamanho dos dados enviados:",
                JSON.stringify({
                    produtos: products,
                    referencia: reference,
                }).length
            );
            let recipe;
            let lastValidationError = null;
            for (let attempt = 1; attempt <= 2; attempt++) {
                const result = await env.AI.run(MODEL, {
                    messages: [
                        {
                            role: "system",
                            content: lastValidationError
                                ? `${instructions}\n\nATENCAO: na tentativa anterior, a resposta falhou na validacao: ${lastValidationError}. Corrija esse problema e siga rigorosamente a estrutura JSON.`
                                : instructions,
                        },
                        {
                            role: "user",
                            content: JSON.stringify({
                                produtos: products,
                                referencia: reference,
                            }),
                        },
                    ],
                    temperature: 0.2,
                    max_tokens: 3500,
                    reasoning_effort: "low",
                });

                const finishReason = result?.choices?.[0]?.finish_reason;
                try {
                    if (finishReason === "length") {
                        throw new Error("Resposta truncada por limite de tokens.");
                    }
                    recipe = parseRecipe(result);
                    console.log("Chefim: receita validada", {
                        tentativa: attempt,
                        duracaoMs: Date.now() - startTime,
                    });
                    break;
                } catch (error) {
                    // Não registre o texto completo da resposta: pode conter
                    // nomes de produtos e informações do usuário.
                    console.warn("Chefim: resposta de IA inválida", {
                        tentativa: attempt,
                        motivo: String(error?.message ?? error),
                        finishReason: finishReason ?? "desconhecido",
                        tamanhoResposta: result?.choices?.[0]?.message?.content?.length ?? 0,
                    });
                    lastValidationError = String(error?.message ?? error);
                    if (attempt === 2) throw error;
                }
            }

            console.log(
                "Chefim: receita validada em",
                Date.now() - startTime,
                "ms"
            );

            return json({
                receita: recipe,
                modelo: MODEL,
            });
        } catch (error) {
            console.error("Chefim: falha na geração:", error);
            console.error(
                "Tempo até a falha:",
                Date.now() - startTime,
                "ms"
            );

            return json(
                {
                    error: "Não foi possível gerar uma receita válida.",
                },
                502
            );
        }
    },
};
