# Validação — atualização em 07/10/2026

## Resultados confirmados

- 33 testes de domínio, validação e autorização aprovados no Node 24.19.0. O primeiro conjunto de 24 testes também foi executado no Node 22.23.3; o conjunto atual também passou no job backend do CI com Node 22 em 07/10/2026.
- 3 testes de integração no emulador Firestore aprovados: transação/idempotência/conflito/vínculo; regras de acesso direto; consulta sigilosa por autor/pastor designado.
- Sintaxe JavaScript verificada.
- `flutter analyze`: sem problemas.
- 5 testes Flutter de interface aprovados: busca, cadastro, ministério, oração/acompanhamento e ocultação do acesso pastoral para a área administrativa.
- Código Dart formatado pelo Dart 3.13.5.

## Limitações do ambiente

- O teste de transporte completo Auth → Functions → Firestore foi iniciado, mas o emulador Functions não conseguiu usar seu socket Unix local (`EPERM`). Não foi concluído; não confundir com os testes Firestore aprovados. O teste possui timeout e permanece no código para execução em ambiente compatível.
- A primeira tentativa de gravação no GitHub retornou `403 Resource not accessible by integration`. Após ajuste de acesso, a escrita foi confirmada em 07/10/2026 pelo commit inicial `cae26c97989342b5340ea45f597bc310e2dbf742`.
- Nenhum deploy ou acesso aos dados do Firebase `leviticus-app-c5110` foi realizado.
- O workflow GitHub executou remotamente: [execução 37611939852](https://github.com/pedrobritoalves/Leviticus/actions/runs/37611939852), commit `dcc483e11304cce5962258c10c793e1246fcacaf`. Jobs backend e Flutter concluídos com sucesso em 07/10/2026: testes Node 22, integração Firestore, análise/testes Flutter e compilações Web. O teste E2E Auth → Functions → Firestore ainda não integra esse workflow.

A versão de Functions usada no projeto deve ser homologada junto à versão da CLI antes de deploy; a CLI de emulação emitiu também um aviso de API de configuração removida no SDK v7. O projeto não utiliza `functions.config()`.

Um resultado de compilação não substitui a validação do login e do App Check no projeto real. A troca de identidade recria o navegador interno da aplicação para descartar páginas e diálogos da sessão anterior.

## Compilações concluídas

- Flutter 3.47.6 / Dart 3.13.5.
- Build Web release de `lib/main.dart`: aprovado; demonstração com dados fictícios em memória.
- Build Web release de `lib/firebase_main.dart` com configuração de emuladores: aprovado. Isso valida a compilação, não o transporte completo de autenticação/Functions nem a configuração do projeto real.
- A demonstração final foi compilada com recursos Web locais (`--no-web-resources-cdn`).
- Total: 33 testes de núcleo + 3 de integração Firestore + 5 de interface = 41 casos aprovados. Os testes de transporte completo em `backend/e2e` não integram essa contagem.
