const MODEL = "@cf/openai/gpt-oss-20b";

function json(data, status = 200) {
    return Response.json(data, {
        status,
        headers: {
            "Cache-Control": "no-store",
        },
    });
}

// Valida a sessão Supabase junto ao servidor Auth.
async function authenticate(request, env) {
    if (!env.SUPABASE_URL || !env.SUPABASE_PUBLISHABLE_KEY) {
        return {
            error: json(
                { error: "Autenticação não configurada no servidor." },
                503
            ),
        };
    }

    const match = /^Bearer\s+(.+)$/i.exec(
        request.headers.get("authorization") ?? ""
    );

    const token = match?.[1]?.trim();

    if (!token || token.length > 8192) {
        return {
            error: json(
                { error: "Entre na sua conta para gerar receitas." },
                401
            ),
        };
    }

    let authUrl;

    try {
        const base = new URL(env.SUPABASE_URL);

        if (
            base.protocol !== "https:" ||
            base.username ||
            base.password ||
            base.search ||
            base.hash
        ) {
            throw new Error("URL inválida");
        }

        authUrl = new URL("/auth/v1/user", base.origin);
    } catch (_) {
        return {
            error: json(
                { error: "Configuração de autenticação inválida." },
                503
            ),
        };
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
        return {
            error: json(
                { error: "Serviço de autenticação indisponível." },
                503
            ),
        };
    }

    if (response.status === 401 || response.status === 403) {
        return {
            error: json(
                {
                    error:
                        "Sessão inválida ou expirada. Entre novamente.",
                },
                401
            ),
        };
    }

    if (!response.ok) {
        return {
            error: json(
                { error: "Não foi possível validar sua sessão." },
                503
            ),
        };
    }

    let user;

    try {
        user = await response.json();
    } catch (_) {
        return {
            error: json(
                { error: "Resposta de autenticação inválida." },
                503
            ),
        };
    }

    if (!validText(user?.id)) {
        return {
            error: json(
                { error: "Usuário não autenticado." },
                401
            ),
        };
    }

    return { userId: user.id };
}

function validText(value) {
    return typeof value === "string" &&
        value.trim().length > 0;
}

function normalizeForValidation(value) {
    return String(value ?? "")
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .toLowerCase()
        .trim();
}

const englishCulinaryPattern =
    /\b(?:all[- ]purpose flour|baking powder|baking soda|jamaican|fried|dumplings?|servings?|milk|flour|salt|oil|butter|chicken|beef|pork|eggs?|onions?|garlic|tomatoes?|cheese|cream|water|pepper|cups?|tablespoons?|teaspoons?|tbsp|tsp|ounces?|pounds?|oz|lbs?|add|stir|cook|bake|fry|heat|combine|pour|until)\b/i;

const commonCulinaryTranslations = [
    [
        /\bjamaican fried dumplings?\b/gi,
        "Bolinhos Jamaicanos Fritos",
    ],
    [
        /\bjamaican dumplings?\b/gi,
        "Bolinhos Jamaicanos",
    ],
    [
        /\bfried dumplings?\b/gi,
        "Bolinhos Fritos",
    ],
    [/\ball[- ]purpose flour\b/gi, "farinha de trigo"],
    [/\bbaking powder\b/gi, "fermento químico em pó"],
    [/\bbaking soda\b/gi, "bicarbonato de sódio"],
    [/\bheavy cream\b/gi, "creme de leite fresco"],
    [/\bcream cheese\b/gi, "queijo cremoso"],
    [/\bvegetable oil\b/gi, "óleo vegetal"],
    [/\bolive oil\b/gi, "azeite de oliva"],
    [/\bblack pepper\b/gi, "pimenta-do-reino"],
    [/\bmilk\b/gi, "leite"],
    [/\bflour\b/gi, "farinha"],
    [/\bsalt\b/gi, "sal"],
    [/\boil\b/gi, "óleo"],
    [/\bbutter\b/gi, "manteiga"],
    [/\bchicken\b/gi, "frango"],
    [/\bbeef\b/gi, "carne bovina"],
    [/\bpork\b/gi, "carne suína"],
    [/\beggs\b/gi, "ovos"],
    [/\begg\b/gi, "ovo"],
    [/\bonions\b/gi, "cebolas"],
    [/\bonion\b/gi, "cebola"],
    [/\bgarlic\b/gi, "alho"],
    [/\btomatoes\b/gi, "tomates"],
    [/\btomato\b/gi, "tomate"],
    [/\bcheese\b/gi, "queijo"],
    [/\bcream\b/gi, "creme de leite"],
    [/\bwater\b/gi, "água"],
    [/\bpepper\b/gi, "pimenta"],
];

const commonUnitTranslations = new Map([
    ["cup", "xícara"],
    ["cups", "xícaras"],
    ["tablespoon", "colher de sopa"],
    ["tablespoons", "colheres de sopa"],
    ["tbsp", "colher de sopa"],
    ["teaspoon", "colher de chá"],
    ["teaspoons", "colheres de chá"],
    ["tsp", "colher de chá"],
    ["pinch", "pitada"],
    ["pinches", "pitadas"],
    ["unit", "unidade"],
    ["units", "unidades"],
]);

function translateCommonCulinaryText(value) {
    let translated = String(value ?? "");

    for (
        const [pattern, replacement] of
        commonCulinaryTranslations
    ) {
        translated = translated.replace(
            pattern,
            replacement
        );
    }

    return translated;
}

function translateCommonUnit(value) {
    const original = String(value ?? "").trim();

    const normalized = normalizeForValidation(original)
        .replace(/\.$/, "");

    return commonUnitTranslations.get(normalized) ??
        original;
}

function capitalizeFirst(value) {
    const text = String(value ?? "").trim();

    if (text.length === 0) {
        return text;
    }

    return text[0].toLocaleUpperCase("pt-BR") +
        text.slice(1);
}

function normalizeRecipeLanguage(recipe) {
    const translatedName =
        translateCommonCulinaryText(recipe.nome)
            .replace(
                /\s*\(\s*\d+\s*(?:servings?|por(?:ção|ções|cao|coes))\s*\)\s*$/i,
                ""
            )
            .trim();

    recipe.nome = capitalizeFirst(translatedName);

    recipe.ingredientes = recipe.ingredientes.map(
        (item) => ({
            ...item,
            nome: capitalizeFirst(
                translateCommonCulinaryText(item.nome)
            ),
            unidade: translateCommonUnit(item.unidade),
        })
    );
}

function findEnglishCulinaryTerms(values) {
    const terms = new Set();

    for (const value of values) {
        const pattern = new RegExp(
            englishCulinaryPattern.source,
            "gi"
        );

        for (
            const match of
            String(value ?? "").matchAll(pattern)
        ) {
            terms.add(match[0].toLowerCase());
        }
    }

    return [...terms];
}

function parsePositiveQuantity(value) {
    const text = String(value ?? "")
        .trim()
        .replace(",", ".");

    const mixed =
        /^(\d+)\s+(\d+)\s*\/\s*(\d+)$/.exec(text);

    if (mixed) {
        const denominator = Number(mixed[3]);

        if (denominator > 0) {
            return Number(mixed[1]) +
                Number(mixed[2]) / denominator;
        }
    }

    const fraction =
        /^(\d+)\s*\/\s*(\d+)$/.exec(text);

    if (fraction) {
        const denominator = Number(fraction[2]);

        if (denominator > 0) {
            return Number(fraction[1]) /
                denominator;
        }
    }

    const number = Number(text);

    return Number.isFinite(number) && number > 0
        ? number
        : null;
}

function validateRecipeQuality(recipe) {
    const problems = new Set();

    const textualFields = [
        recipe.nome,
        ...recipe.ingredientes.flatMap(
            (item) => [item.nome, item.unidade]
        ),
        ...recipe.preparo,
        ...recipe.observacoes,
    ];

    const englishTerms =
        findEnglishCulinaryTerms(textualFields);

    if (englishTerms.length > 0) {
        problems.add(
            "Todos os textos da receita devem estar " +
                "em português do Brasil, inclusive nome, " +
                "ingredientes e unidades. Traduza estes " +
                `termos: ${englishTerms.join(", ")}.`
        );
    }

    const normalizedRecipeName =
        normalizeForValidation(recipe.nome);

    if (
        /\b\d+\s*por(?:cao|coes)\b/.test(
            normalizedRecipeName
        )
    ) {
        problems.add(
            "O campo nome não deve incluir a quantidade " +
                "de porções; use apenas o campo porcoes."
        );
    }

    for (const item of recipe.ingredientes) {
        const name =
            normalizeForValidation(item.nome);

        const unit =
            normalizeForValidation(item.unidade)
                .replace(/\./g, "");

        const quantity =
            parsePositiveQuantity(item.quantidade);

        const isLeavening =
            name.includes("fermento") ||
            name.includes("bicarbonato") ||
            name.includes("baking powder") ||
            name.includes("baking soda");

        if (!isLeavening) {
            continue;
        }

        const invalidLargeUnit =
            /(^|\s)(copos?|xicaras?|kg|quilos?|litros?|l|unidades?)(\s|$)/
                .test(unit);

        if (invalidLargeUnit) {
            problems.add(
                "Fermento ou bicarbonato não pode ser " +
                    "medido em copo, xícara, quilo, " +
                    "litro ou unidade."
            );
        }

        if (quantity !== null) {
            const tooMuchInGrams =
                ["g", "grama", "gramas"].includes(
                    unit
                ) && quantity > 20;

            const tooMuchInMilliliters =
                [
                    "ml",
                    "mililitro",
                    "mililitros",
                ].includes(unit) && quantity > 20;

            const tooManyTablespoons =
                unit.includes("colher de sopa") &&
                quantity > 2;

            const tooManyTeaspoons =
                unit.includes("colher de cha") &&
                quantity > 4;

            if (
                tooMuchInGrams ||
                tooMuchInMilliliters ||
                tooManyTablespoons ||
                tooManyTeaspoons
            ) {
                problems.add(
                    "A quantidade de fermento ou " +
                        "bicarbonato está excessiva para " +
                        "2 porções; ajuste a proporção."
                );
            }
        }
    }

    if (problems.size > 0) {
        throw new Error(
            [...problems].join(" ")
        );
    }
}

function extractText(result) {
    // Formato Chat Completions retornado pelo modelo.
    const choiceContent =
        result?.choices?.[0]?.message?.content;

    if (
        typeof choiceContent === "string" &&
        choiceContent.trim().length > 0
    ) {
        return choiceContent;
    }

    // Formato alternativo de algumas APIs.
    if (typeof result?.response === "string") {
        return result.response;
    }

    if (
        result?.response &&
        typeof result.response === "object"
    ) {
        return JSON.stringify(result.response);
    }

    // Formato de respostas com blocos de saída.
    const parts = [];

    for (const item of result?.output ?? []) {
        if (item.type !== "message") {
            continue;
        }

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

    // Usa somente o objeto JSON caso haja texto antes ou depois.
    let recipe;

    try {
        recipe = JSON.parse(cleaned);
    } catch (_) {
        const start = cleaned.indexOf("{");
        const end = cleaned.lastIndexOf("}");

        if (start < 0 || end <= start) {
            throw new Error("JSON ausente ou incompleto.");
        }

        recipe = JSON.parse(
            cleaned.slice(start, end + 1)
        );
    }

    if (
        !recipe ||
        typeof recipe !== "object" ||
        Array.isArray(recipe)
    ) {
        throw new Error(
            "Resposta não é um objeto de receita."
        );
    }

    // O modelo pode gerar quantidade como número,
    // mas o Flutter espera String.
    if (Array.isArray(recipe.ingredientes)) {
        recipe.ingredientes =
            recipe.ingredientes.map((item) => {
                if (
                    !item ||
                    typeof item !== "object" ||
                    Array.isArray(item)
                ) {
                    return item;
                }

                const normalized = { ...item };

                if (
                    typeof normalized.quantidade ===
                        "number" &&
                    Number.isFinite(
                        normalized.quantidade
                    ) &&
                    normalized.quantidade > 0
                ) {
                    normalized.quantidade = String(
                        normalized.quantidade
                    );
                }

                return normalized;
            });
    }

    if (!validText(recipe.nome)) {
        throw new Error(
            "Campo nome ausente ou vazio."
        );
    }

    if (
        !Number.isInteger(recipe.porcoes) ||
        recipe.porcoes < 1 ||
        recipe.porcoes > 10
    ) {
        throw new Error(
            "Campo porcoes invalido " +
                "(esperado inteiro entre 1 e 10)."
        );
    }

    const rawEstimatedCalories =
        recipe.calorias_totais_estimadas;

    const estimatedCalories =
        typeof rawEstimatedCalories === "number"
            ? rawEstimatedCalories
            : Number(
                  String(
                      rawEstimatedCalories ?? ""
                  ).replace(",", ".")
              );

    if (
        !Number.isFinite(estimatedCalories) ||
        estimatedCalories <= 0 ||
        estimatedCalories > 30000
    ) {
        throw new Error(
            "Campo calorias_totais_estimadas invalido."
        );
    }

    recipe.calorias_totais_estimadas =
        Math.round(estimatedCalories);

    recipe.calorias_por_porcao = Math.round(
        estimatedCalories / recipe.porcoes
    );

    if (
        !Array.isArray(recipe.ingredientes) ||
        recipe.ingredientes.length === 0
    ) {
        throw new Error(
            "Campo ingredientes ausente ou vazio."
        );
    }

    if (
        !Array.isArray(recipe.preparo) ||
        recipe.preparo.length < 3
    ) {
        throw new Error(
            "Campo preparo com menos de 3 etapas."
        );
    }

    for (
        const [index, step] of
        recipe.preparo.entries()
    ) {
        if (!validText(step)) {
            throw new Error(
                `Etapa ${index + 1} do preparo invalida.`
            );
        }
    }

    for (
        const [index, item] of
        recipe.ingredientes.entries()
    ) {
        if (
            !item ||
            typeof item !== "object" ||
            Array.isArray(item)
        ) {
            throw new Error(
                `Ingrediente ${index + 1}: objeto invalido.`
            );
        }

        if (!validText(item.nome)) {
            throw new Error(
                `Ingrediente ${index + 1}: nome invalido.`
            );
        }

        if (!validText(item.quantidade)) {
            throw new Error(
                `Ingrediente ${index + 1}: quantidade invalida.`
            );
        }

        if (!validText(item.unidade)) {
            const quantidade = String(
                item.quantidade ?? ""
            )
                .trim()
                .toLowerCase();

            const quantidadeSemMedida = [
                "a gosto",
                "à gosto",
                "quanto baste",
                "q.b.",
                "qb",
            ].includes(quantidade);

            if (quantidadeSemMedida) {
                item.unidade = "";
            } else {
                console.warn(
                    "Chefim: unidade inválida detectada",
                    {
                        ingredienteNumero: index + 1,
                        nome: item.nome,
                        quantidade: item.quantidade,
                        unidade: item.unidade,
                        tipoUnidade:
                            typeof item.unidade,
                    }
                );

                throw new Error(
                    `Ingrediente ${index + 1}: ` +
                        "unidade invalida."
                );
            }
        }

        if (
            ![
                "selecionado",
                "adicional",
            ].includes(item.origem)
        ) {
            throw new Error(
                `Ingrediente ${index + 1}: origem invalida.`
            );
        }
    }

    // Observações são opcionais.
    recipe.observacoes =
        Array.isArray(recipe.observacoes)
            ? recipe.observacoes.filter(validText)
            : [];

    normalizeRecipeLanguage(recipe);
    validateRecipeQuality(recipe);

    return recipe;
}

export default {
    async fetch(request, env) {
        const url = new URL(request.url);

        if (
            url.pathname === "/health" &&
            request.method === "GET"
        ) {
            return json({
                status: "ok",
                app: "Chefim",
            });
        }

        if (url.pathname !== "/recipes/adapt") {
            return json(
                { error: "Rota não encontrada." },
                404
            );
        }

        if (request.method !== "POST") {
            return json(
                { error: "Método não permitido." },
                405
            );
        }

        // Somente usuários autenticados podem
        // consumir o Workers AI.
        const auth = await authenticate(
            request,
            env
        );

        if (auth.error) {
            return auth.error;
        }

        // Limite aproximado de cinco receitas
        // por minuto para cada usuário.
        if (!env.RECIPE_RATE_LIMITER) {
            return json(
                {
                    error:
                        "Limite de requisições não configurado.",
                },
                503
            );
        }

        try {
            const { success } =
                await env.RECIPE_RATE_LIMITER.limit({
                    key: auth.userId,
                });

            if (!success) {
                return json(
                    {
                        error:
                            "Muitas receitas seguidas. " +
                            "Tente novamente em instantes.",
                    },
                    429
                );
            }
        } catch (_) {
            return json(
                {
                    error:
                        "Não foi possível validar o limite de uso.",
                },
                503
            );
        }

        // Proteção contra corpos de requisição grandes.
        const contentLength = Number(
            request.headers.get(
                "content-length"
            ) ?? 0
        );

        if (contentLength > 20000) {
            return json(
                { error: "Requisição muito grande." },
                413
            );
        }

        const reader =
            request.body?.getReader();

        if (!reader) {
            return json(
                {
                    error:
                        "Corpo da requisição ausente.",
                },
                400
            );
        }

        const chunks = [];
        let size = 0;

        try {
            while (true) {
                const { done, value } =
                    await reader.read();

                if (done) {
                    break;
                }

                size += value.byteLength;

                if (size > 20000) {
                    await reader.cancel();

                    return json(
                        {
                            error:
                                "Requisição muito grande.",
                        },
                        413
                    );
                }

                chunks.push(value);
            }
        } catch (_) {
            return json(
                {
                    error:
                        "Falha ao ler a requisição.",
                },
                400
            );
        }

        const bytes = new Uint8Array(size);
        let offset = 0;

        for (const chunk of chunks) {
            bytes.set(chunk, offset);
            offset += chunk.byteLength;
        }

        const rawBody =
            new TextDecoder().decode(bytes);

        let body;

        try {
            body = JSON.parse(rawBody);
        } catch (_) {
            return json(
                { error: "JSON inválido." },
                400
            );
        }

        const products = body?.produtos;
        const reference = body?.referencia;

        if (
            !Array.isArray(products) ||
            products.length < 1 ||
            products.length > 3 ||
            products.some(
                (product) =>
                    !validText(product.nome)
            ) ||
            !reference ||
            !validText(reference.nome) ||
            !Array.isArray(
                reference.ingredientes
            ) ||
            !Array.isArray(reference.preparo) ||
            reference.nome.length > 200 ||
            reference.ingredientes.length > 60 ||
            reference.preparo.length > 60 ||
            products.some(
                (product) =>
                    product.nome.length > 200
            ) ||
            reference.ingredientes.some(
                (name) =>
                    !validText(name) ||
                    name.length > 200
            ) ||
            reference.preparo.some(
                (step) =>
                    !validText(step) ||
                    step.length > 1500
            )
        ) {
            return json(
                { error: "Dados inválidos." },
                400
            );
        }

        const instructions = `
Você é o motor de adaptação culinária do Chefim.

OBJETIVO:
Gerar uma receita culinária completa, saborosa e coerente
a partir de uma referência da TheMealDB, priorizando os
ingredientes selecionados pelo usuário.

IDIOMA OBRIGATÓRIO:
A referência da TheMealDB pode estar escrita em inglês.
Traduza para português do Brasil o nome da receita, todos
os ingredientes, todas as unidades, o modo de preparo e as
observações antes de montar o JSON. A resposta não pode
conter termos culinários em inglês.

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

15. Calcule uma estimativa coerente das calorias totais
da receita a partir das quantidades de todos os ingredientes.
Retorne um número inteiro em calorias (kcal). Não use texto,
faixa de valores ou unidade nesse campo.

16. Retorne exclusivamente o JSON no formato solicitado,
com nome, porcoes, calorias_totais_estimadas, ingredientes,
preparo e observacoes.

17. Não retorne ingredientes ou preparo vazios como
forma de indicar falta de ingredientes selecionados.

18. Escreva TODO o conteúdo textual em português do Brasil,
incluindo nome da receita, ingredientes, unidades, etapas
de preparo e observações.

19. Traduza os termos genéricos presentes na receita de
referência. Exemplos: "Jamaican Fried Dumplings" deve ser
traduzido; "Milk" deve ser "Leite"; "All purpose flour"
deve ser "Farinha de trigo"; e "Baking Powder" deve ser
"Fermento químico em pó". Nomes culinários consagrados,
como Carbonara, Ratatouille e Fettuccine Alfredo, podem ser
mantidos, mas seus termos descritivos devem estar em português.

20. O campo "nome" deve conter somente o nome da receita.
Não inclua "(2 porções)" nem qualquer quantidade de porções
no nome, pois essa informação já existe no campo "porcoes".

21. Mantenha quantidade e unidade em campos separados.
Exemplo correto: "quantidade": "1" e
"unidade": "colher de chá".

22. Use unidades em português e adequadas ao ingrediente,
como g, kg, ml, l, unidade, pitada, colher de chá,
colher de sopa e xícara. Não use cup, tbsp, tsp, oz ou lb.

23. Nunca meça fermento ou bicarbonato em copo, xícara,
quilo, litro ou unidade. Para 2 porções, utilize quantidade
culinariamente coerente, normalmente entre meia e duas
colheres de chá, conforme a quantidade de farinha.

24. Antes de responder, revise as proporções de todos os
ingredientes e confirme que são coerentes para 2 porções.
Calcule as calorias somente depois dessa revisão, usando as
quantidades finais presentes no JSON.

Estrutura obrigatória:
{
  "nome": "Nome da receita",
  "porcoes": 2,
  "calorias_totais_estimadas": 900,
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
            console.log(
                "Chefim: iniciando geração com IA"
            );

            console.log(
                "Referência:",
                reference.nome
            );

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

            for (
                let attempt = 1;
                attempt <= 2;
                attempt++
            ) {
                const result = await env.AI.run(
                    MODEL,
                    {
                        messages: [
                            {
                                role: "system",
                                content:
                                    lastValidationError
                                        ? `${instructions}

ATENCAO: na tentativa anterior, a resposta falhou na validacao: ${lastValidationError}. Corrija esse problema e siga rigorosamente a estrutura JSON.`
                                        : instructions,
                            },
                            {
                                role: "user",
                                content:
                                    JSON.stringify({
                                        idioma_saida:
                                            "pt-BR",
                                        traducao_obrigatoria:
                                            true,
                                        produtos:
                                            products,
                                        referencia:
                                            reference,
                                    }),
                            },
                        ],
                        temperature: 0.2,
                        max_tokens: 3500,
                        reasoning_effort: "low",
                    }
                );

                const finishReason =
                    result?.choices?.[0]
                        ?.finish_reason;

                try {
                    if (
                        finishReason === "length"
                    ) {
                        throw new Error(
                            "Resposta truncada por limite de tokens."
                        );
                    }

                    recipe = parseRecipe(result);

                    console.log(
                        "Chefim: receita validada",
                        {
                            tentativa: attempt,
                            duracaoMs:
                                Date.now() -
                                startTime,
                        }
                    );

                    break;
                } catch (error) {
                    // Não registra a resposta completa porque
                    // ela pode conter dados do usuário.
                    console.warn(
                        "Chefim: resposta de IA inválida",
                        {
                            tentativa: attempt,
                            motivo: String(
                                error?.message ??
                                    error
                            ),
                            finishReason:
                                finishReason ??
                                "desconhecido",
                            tamanhoResposta:
                                result
                                    ?.choices?.[0]
                                    ?.message
                                    ?.content
                                    ?.length ?? 0,
                        }
                    );

                    lastValidationError = String(
                        error?.message ?? error
                    );

                    if (attempt === 2) {
                        throw error;
                    }
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
            console.error(
                "Chefim: falha na geração:",
                error
            );

            console.error(
                "Tempo até a falha:",
                Date.now() - startTime,
                "ms"
            );

            return json(
                {
                    error:
                        "Não foi possível gerar uma receita válida.",
                },
                502
            );
        }
    },
};