# Conectar Firebase ao GitHub — Leviticus

Preparado em 07/10/2026. A integração de código está pronta para configuração; a autenticação no Google Cloud e o primeiro deploy ainda precisam ser executados no projeto de homologação.

Comece pelo [roteiro guiado do primeiro deploy](PRIMEIRO-DEPLOY.md). Este documento contém os comandos administrativos detalhados.

## Resultado esperado

`push na main → testes backend/Flutter/E2E → build Web conectado → credencial temporária Google → Functions/regras → Hosting → conferência da versão publicada`.

O workflow é `.github/workflows/deploy-staging.yml`. Inicialmente só é disparado manualmente. Depois do primeiro deploy aprovado, a variável de repositório `AUTO_DEPLOY_STAGING=true` habilita o fluxo automático. O deploy exige testes verdes e só aceita a branch `main`. O ambiente é `staging`; não existe deploy de produção configurado.

A conexão GitHub disponível nesta sessão permite gravar o código, mas não administrar IAM/serviços Google nem as variáveis/environments do GitHub. Esses ajustes devem ser feitos pelo titular nas consoles ou por administrador autorizado. Não envie senha, token pessoal ou chave privada no chat.

## 1. Preparar o projeto Firebase

1. Inspecionar `leviticus-app-c5110`: verificar se há dados/apps/funções existentes e se já é produção. Preferir projeto separado para homologação. O pipeline permite o ID escolhido explicitamente; o nome do environment não transforma um projeto de produção em homologação.
2. Vincular o faturamento necessário (Blaze para deploy de Functions) e configurar alertas.
3. Criar/confirmar Firestore, Auth por e-mail/senha e site padrão do Firebase Hosting. Registrar o app Web e guardar sua configuração pública.
4. Configurar App Check Web (reCAPTCHA v3 usado no código), domínio `ID_DO_PROJETO.web.app` e demais domínios autorizados no Auth/provedor. As Functions exigem App Check fora do emulador.
5. Criar a igreja de teste e os usuários no Auth; confirmar e-mail e provisionar vínculos em `churches/{churchId}/users/{uid}` com `active: true` e papel. Definir `intakePastorUid` no documento da igreja. Não usar o seed local na nuvem.
6. Identificar a conta de execução das Functions e a conta de build; conferir permissões para build, logs e Firestore. A conta de deploy e a conta de execução são identidades diferentes.

Este workflow publica o site padrão do projeto, em `https://ID_DO_PROJETO.web.app`. Projetos com múltiplos sites ou domínio Auth personalizado precisam de configuração adicional antes de usar este fluxo inicial.

## 2. Criar a confiança Google ↔ GitHub uma vez

Use o **Cloud Shell** do projeto escolhido. Os comandos abaixo criam uma conta de deploy e uma federação; não fazem deploy nem criam chaves privadas. Execute após o inventário do projeto. Requer permissão administrativa para IAM/APIs. Se um recurso já existir, confira sua configuração antes de substituir; os comandos `create` não são uma migração de configuração existente.

```bash
export LEVITICUS_PROJECT_ID="PREENCHER_ID_DE_HOMOLOGACAO"
gcloud projects describe "$LEVITICUS_PROJECT_ID" --format='value(projectId,name)'
export LEVITICUS_PROJECT_NUMBER="$(gcloud projects describe "$LEVITICUS_PROJECT_ID" --format='value(projectNumber)')"
export LEVITICUS_DEPLOY_SA="github-deploy@${LEVITICUS_PROJECT_ID}.iam.gserviceaccount.com"

gcloud services enable iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com cloudresourcemanager.googleapis.com cloudfunctions.googleapis.com run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com firestore.googleapis.com firebaserules.googleapis.com firebasehosting.googleapis.com --project="$LEVITICUS_PROJECT_ID"

gcloud iam service-accounts create github-deploy --display-name="Leviticus GitHub deploy" --project="$LEVITICUS_PROJECT_ID"

gcloud iam workload-identity-pools create github-leviticus --location=global --display-name="Leviticus GitHub" --project="$LEVITICUS_PROJECT_ID"

gcloud iam workload-identity-pools providers create-oidc github --location=global --workload-identity-pool=github-leviticus --issuer-uri="https://token.actions.githubusercontent.com" --attribute-mapping="google.subject=assertion.sub,attribute.repository_id=assertion.repository_id,attribute.repository_owner_id=assertion.repository_owner_id,attribute.ref=assertion.ref,attribute.workflow_ref=assertion.workflow_ref" --attribute-condition="assertion.repository_id=='1407781793' && assertion.repository_owner_id=='277139256' && assertion.ref=='refs/heads/main' && assertion.sub=='repo:pedrobritoalves/Leviticus:environment:staging' && assertion.workflow_ref=='pedrobritoalves/Leviticus/.github/workflows/deploy-staging.yml@refs/heads/main'" --project="$LEVITICUS_PROJECT_ID"

gcloud iam service-accounts add-iam-policy-binding "$LEVITICUS_DEPLOY_SA" --role=roles/iam.workloadIdentityUser --member="principalSet://iam.googleapis.com/projects/${LEVITICUS_PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-leviticus/attribute.repository_id/1407781793" --project="$LEVITICUS_PROJECT_ID"
```

A condição restringe repositório/dono pelos IDs numéricos, branch, environment e arquivo de workflow. Mudança de nome/ownership do repositório exige revisão dessa confiança. Não autorizar todos os repositórios de uma organização por conveniência.

### Permissões da conta de deploy

Conceder no projeto de homologação as permissões dos componentes publicados. Os papéis abaixo são a base operacional proposta para o fluxo atual; políticas da organização, contas de build e recursos existentes precisam ser conferidos na primeira implantação. Não usar Owner/Editor como solução genérica para erro 403.

```bash
for LEVITICUS_ROLE in roles/firebasehosting.admin roles/firebaserules.admin roles/datastore.indexAdmin roles/cloudfunctions.admin roles/run.admin roles/serviceusage.serviceUsageConsumer roles/firebase.viewer; do
  gcloud projects add-iam-policy-binding "$LEVITICUS_PROJECT_ID" --member="serviceAccount:${LEVITICUS_DEPLOY_SA}" --role="$LEVITICUS_ROLE" --condition=None
done
```

`roles/run.admin` atende à gestão dos serviços/invocação de Functions de segunda geração. A proteção de negócio permanece no Auth, App Check e autorização das callables. Essas permissões permitem alterar código/regras: trate quem pode editar `main` como responsável pelo deploy.

Conceder `Service Account User` **na conta de execução identificada**, não em todas as contas do projeto:

```bash
export LEVITICUS_RUNTIME_SA="PREENCHER_CONTA_DE_EXECUCAO_DAS_FUNCTIONS"
gcloud iam service-accounts describe "$LEVITICUS_RUNTIME_SA" --project="$LEVITICUS_PROJECT_ID"
gcloud iam service-accounts add-iam-policy-binding "$LEVITICUS_RUNTIME_SA" --member="serviceAccount:${LEVITICUS_DEPLOY_SA}" --role=roles/iam.serviceAccountUser --project="$LEVITICUS_PROJECT_ID"
```

Se uma conta de build distinta exigir `actAs`, conceder o mesmo papel somente nessa conta. A conta runtime precisa de acesso ao Firestore usado pela aplicação; a conta build precisa das permissões de build/artefatos/logs exigidas pelo projeto. Essa verificação é parte do bootstrap Google, não é resolvida apenas pelo acesso GitHub.

Obter os dois valores públicos para o GitHub:

```bash
gcloud iam workload-identity-pools providers describe github --location=global --workload-identity-pool=github-leviticus --project="$LEVITICUS_PROJECT_ID" --format='value(name)'
printf '%s\n' "$LEVITICUS_DEPLOY_SA"
```

Não há arquivo JSON de chave de serviço para baixar neste método. A autenticação temporária é usada pela Firebase CLI; o Admin SDK da aplicação usa a identidade runtime do Google Cloud.

## 3. Configurar GitHub

Abra [Settings → Environments](https://github.com/pedrobritoalves/Leviticus/settings/environments), crie **`staging`**, restrinja a branch de deploy a `main` e configure estas **Environment variables**:

| Nome | Valor |
|---|---|
| `FIREBASE_PROJECT_ID` | ID efetivo do projeto de homologação |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Saída `projects/NUMERO/locations/global/workloadIdentityPools/github-leviticus/providers/github` |
| `GCP_DEPLOY_SERVICE_ACCOUNT` | `github-deploy@ID_DO_PROJETO.iam.gserviceaccount.com` |
| `FIREBASE_WEB_CONFIG_JSON` | JSON público abaixo, com os valores reais do app Web |
| `STAGING_DEPLOY_ENABLED` | `true`, somente após conferir projeto, IAM, serviços e regras a publicar |

Modelo da configuração (todos os valores são strings):

```json
{
  "USE_EMULATORS": "false",
  "CHURCH_ID": "igreja-homologacao",
  "FIREBASE_PROJECT_ID": "PREENCHER",
  "FIREBASE_API_KEY": "PREENCHER",
  "FIREBASE_APP_ID": "PREENCHER",
  "FIREBASE_SENDER_ID": "PREENCHER",
  "FIREBASE_AUTH_DOMAIN": "ID_DO_PROJETO.firebaseapp.com",
  "RECAPTCHA_SITE_KEY": "PREENCHER"
}
```

Mapeamento da configuração mostrada pelo Firebase: `apiKey` → FIREBASE_API_KEY; `appId` → FIREBASE_APP_ID; `messagingSenderId` → FIREBASE_SENDER_ID; `projectId` → FIREBASE_PROJECT_ID; `authDomain` → FIREBASE_AUTH_DOMAIN. A chave reCAPTCHA é a **site key pública**, não o segredo do provedor.

As opções do app Firebase são públicas e vão para o frontend; não substituem autorização. Não colocar Admin SDK private keys, senhas de testadores nem tokens nessas variáveis.

Em Settings → Actions → General, permitir os workflows e as actions utilizadas. No environment, o responsável pode configurar aprovação de deploy conforme a política da equipe. Isso não exige trocar o workflow para rodar em pull requests não confiáveis.

## 4. Primeiro deploy

1. Abra [Actions → Deploy Firebase staging](https://github.com/pedrobritoalves/Leviticus/actions/workflows/deploy-staging.yml).
2. Clique **Run workflow**, branch **main**.
3. Confira checks: Node 22, Java 21, testes de configuração, backend, integração Firestore, E2E Auth/Functions/Firestore, Flutter e builds Web.
4. O deploy valida variáveis, compila `firebase_main.dart` e obtém credencial temporária somente após o build.
5. Publica Functions da codebase `shepherd`, regras/índices Firestore e depois Hosting. Storage ainda não é publicado por esse fluxo, pois o módulo de anexos não está implementado.
6. Verifica `version.json` no Hosting e mostra URL/commit no resumo do job.
7. Execute os testes T05–T13 de [TESTAR-COMO-DESENVOLVEDOR.md](TESTAR-COMO-DESENVOLVEDOR.md): login, persistência, troca de conta e sigilo. Verificação HTTP de versão não substitui teste da aplicação.

Os testes E2E passaram na execução 37614379172, junto aos jobs backend e Flutter. O deploy Google continua pendente de configuração; teste em emulador não equivale à homologação da nuvem.

## 5. Automatizar os próximos incrementos

Após o primeiro ciclo aprovado, em [Settings → Secrets and variables → Actions → Variables](https://github.com/pedrobritoalves/Leviticus/settings/variables/actions), criar a variável **do repositório**:

```text
AUTO_DEPLOY_STAGING=true
```

Essa variável precisa ser do repositório, porque é avaliada antes de entrar no environment. Cada push em `main` passará pelas verificações e publicará homologação. Pull requests executam CI, sem deploy. Para pausar, defina `AUTO_DEPLOY_STAGING=false`; o botão manual continua disponível, mas `STAGING_DEPLOY_ENABLED=false` impede qualquer publicação.

O fluxo atual prioriza simplicidade: o workflow normal de CI e o workflow de deploy podem repetir verificações no mesmo commit quando o automático estiver ativo. O deploy reutiliza o mesmo arquivo de CI, sem manter duas listas diferentes de testes.

## 6. Erros e recuperação

| Sintoma | Ação |
|---|---|
| Configuração incompleta | Preencher a variável indicada; não é necessário fornecer segredo de serviço |
| OIDC negado | Conferir IDs numéricos, `main`, nome `staging`, arquivo de workflow, provider e binding `workloadIdentityUser` |
| Firebase 403 | Identificar recurso/permissão no erro; revisar conta deploy/runtime/build correspondente |
| API desabilitada | Administrador habilita a API específica; o deploy não recebe permissão genérica para habilitar serviços |
| `functions.config()`/emulador antigo | Executar `npm ci` com o lock atualizado; CLI 15.32.1 e Java 21 |
| Auth funciona mas aplicativo nega | Conferir e-mail confirmado, papel, igreja e `intakePastorUid` |
| App Check nega | Conferir app Web, site key e domínio registrado; não desativar a proteção para publicar |
| Backend publicou, Hosting falhou | O deploy não é uma transação; inspecionar versão backend, corrigir e repetir o commit conhecido |

Para rollback, preferir reverter o commit problemático, obter CI verde e republicar. Rollback de Hosting isolado não reverte Functions nem dados. Não usar `--force` para apagar recursos como resposta automática a falha de deploy.

## 7. O que esta integração não faz

Não cria automaticamente igrejas/usuários reais, não ativa faturamento, não implementa módulos ausentes e não publica Android/iOS nas lojas. Esses apps consumirão o mesmo backend quando a configuração nativa estiver pronta. Produção terá environment e permissões próprios, após homologação.

## Referências

- [Firebase CLI: credenciais para CI](https://firebase.google.com/docs/cli).
- [Google auth action](https://github.com/google-github-actions/auth).
- [Federação com pipelines](https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines).
- [Permissões Firebase](https://firebase.google.com/docs/projects/iam/permissions).
- [Correções e requisitos da CLI](https://firebase.google.com/support/release-notes/cli).
