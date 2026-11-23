
const MODEL = "@cf/openai/gpt-oss-20b";

function json(data, status = 200) {
    return Response.json(data, {
        status,
        headers: {
            "Cache-Control": "no-store",
        },
    });
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

    // Remove cercas Markdown, caso o modelo as produza.
    const cleaned = text
        .replace(/^```(?:json)?\s*/i, "")
        .replace(/\s*```$/, "");

    const recipe = JSON.parse(cleaned);

    console.log("===== VALIDAÇÃO DA RECEITA =====");

    console.log("Nome:", recipe?.nome);
    console.log("Porções:", recipe?.porcoes);

    console.log(
        "Ingredientes:",
        Array.isArray(recipe?.ingredientes)
            ? recipe.ingredientes.length
            : "Formato inválido"
    );

    console.log(
        "Etapas:",
        Array.isArray(recipe?.preparo)
            ? recipe.preparo.length
            : "Formato inválido"
    );

    console.log(
        "Estrutura dos ingredientes:",
        Array.isArray(recipe?.ingredientes)
            ? recipe.ingredientes.map((item) => ({
                nome: item?.nome,
                tipoQuantidade: typeof item?.quantidade,
                unidade: item?.unidade,
                origem: item?.origem,
            }))
            : []
    );



    console.log("Chefim: estrutura retornada pela IA", {
        campos: Object.keys(recipe ?? {}),
        nome: typeof recipe?.nome,
        porcoes: recipe?.porcoes,
        ingredientes: Array.isArray(recipe?.ingredientes)
            ? recipe.ingredientes.length
            : "inválido",
        preparo: Array.isArray(recipe?.preparo)
            ? recipe.preparo.length
            : "inválido",
    });

    if (Array.isArray(recipe?.ingredientes)) {
        console.log(
            "Chefim: formatos dos ingredientes",
            recipe.ingredientes.map((item) => ({
                nome: typeof item?.nome,
                quantidade: typeof item?.quantidade,
                unidade: typeof item?.unidade,
                origem: item?.origem,
            }))
        );
    }

    if (
        !recipe ||
        typeof recipe !== "object" ||
        !validText(recipe.nome) ||
        !Number.isInteger(recipe.porcoes) ||
        recipe.porcoes < 1 ||
        recipe.porcoes > 10 ||
        !Array.isArray(recipe.ingredientes) ||
        recipe.ingredientes.length === 0 ||
        !Array.isArray(recipe.preparo) ||
        recipe.preparo.length < 3 ||
        recipe.preparo.some((step) => !validText(step)) ||
        recipe.ingredientes.some(
            (item) =>
                !item ||
                !validText(item.nome) ||
                !validText(item.quantidade) ||
                !validText(item.unidade)
        )
    ) {
        throw new Error("Estrutura da receita inválida.");
    }

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

        // Esta primeira versão deve ser testada localmente.
        // Antes de publicar, implementar autenticação,
        // rate limit e proteção contra abuso.
        if (url.hostname !== "localhost" &&
            url.hostname !== "127.0.0.1") {
            return json(
                { error: "Endpoint indisponível nesta versão de testes." },
                403
            );
        }

        const contentLength = Number(
            request.headers.get("content-length") ?? 0
        );

        if (contentLength > 20000) {
            return json({ error: "Requisição muito grande." }, 413);
        }

        let body;

        try {
            body = await request.json();
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
            !Array.isArray(reference.preparo)
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
            const result = await env.AI.run(MODEL, {
                messages: [
                    {
                        role: "system",
                        content: instructions,
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

            console.log(
                "Chefim: IA respondeu em",
                Date.now() - startTime,
                "ms"
            );

            console.log(
                "Motivo de término:",
                result?.choices?.[0]?.finish_reason
            );

            console.log(
                "Tamanho da resposta:",
                result?.choices?.[0]?.message?.content?.length ?? 0
            );

            const finishReason = result?.choices?.[0]?.finish_reason;

            if (finishReason === "length") {
                throw new Error(
                    "A IA atingiu o limite de tokens antes de concluir a receita."
                );
            }

            const recipe = parseRecipe(result);

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
