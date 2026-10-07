# Primeiro deploy — o que Pedro precisa fazer

Atualizado em 07/10/2026. O código e o pipeline estão no GitHub. A execução [37614379172](https://github.com/pedrobritoalves/Leviticus/actions/runs/37614379172) passou nos jobs backend e Flutter, incluindo o teste Auth → Functions → Firestore. Ainda não houve deploy no Firebase real.

Siga a sequência. Os passos Google exigem a conta que administra o projeto; os passos GitHub exigem administração do repositório. Não é necessário enviar senhas nem chaves privadas no chat. A preparação pode continuar com o sistema em modo de demonstração enquanto essas configurações são feitas.

## Passo 1 — confirmar o destino

Abra o projeto `leviticus-app-c5110` no Firebase Console. Verifique se é um projeto novo destinado ao Leviticus ou se já atende algum sistema.

- Se já possui sistema/dados reais: prepare um projeto Firebase separado para homologação e use seu ID em todos os passos seguintes.
- Se é um projeto novo sem dependências: pode ser usado como ambiente inicial de teste após essa conferência; a separação de produção continua necessária antes da entrada de igrejas reais.

Em Project settings/Configurações do projeto → General/Geral, anote **Project ID** e **Project number**. Não confunda ID com nome de exibição. A partir daqui, `ID_DO_PROJETO` significa esse destino confirmado.

Opcionalmente abra o Cloud Shell pelo console Google Cloud e execute a inspeção somente leitura:

```bash
git clone https://github.com/pedrobritoalves/Leviticus.git
cd Leviticus
bash scripts/firebase-preflight.sh ID_DO_PROJETO
```

Se já tem esse clone no Cloud Shell, atualize-o em vez de clonar novamente. Substitua `ID_DO_PROJETO` pelo valor confirmado. O script lista configurações e recursos; não lê documentos de membros, não altera permissões e não habilita serviços. Ele também não prova sozinho que o projeto está vazio.

## Passo 2 — faturamento e serviços

1. Em Usage and billing/Uso e faturamento, confira ou configure **Blaze**. A ativação de faturamento e aceitação de termos devem ser feitas pelo titular.
2. Configure um alerta de orçamento e seu responsável. O alerta não desliga automaticamente os serviços quando um valor é atingido.
3. Em Firestore Database, crie o banco `(default)` se ainda não existir. Use modo de produção; as regras restritivas serão publicadas pelo pipeline. Selecione a região conscientemente; o código de Functions usa `southamerica-east1`. Se o banco já existe, não o recrie.
4. Em Authentication → Sign-in method, habilite **Email/Password**. O fluxo atual usa senha, não exige link mágico.
5. Em Hosting, confirme/crie o site padrão do projeto. Não execute um assistente que sobrescreva `firebase.json` ou gere outro workflow sobre os arquivos já preparados.

Resultado desta etapa: projeto com faturamento, banco, Auth e Hosting disponíveis. Ainda não é um app funcional publicado.

## Passo 3 — registrar o app Web

Em Configurações do projeto → Geral → Seus apps:

1. Se não houver app Web apropriado, use o ícone `</>` e o nome `Leviticus Web Homologação`.
2. Abra a configuração do SDK do app registrado. Copie os valores públicos de `apiKey`, `appId`, `messagingSenderId`, `projectId` e `authDomain`.
3. Em Authentication → Settings → Authorized domains, confira `ID_DO_PROJETO.web.app` e `ID_DO_PROJETO.firebaseapp.com`.

A configuração Web é pública, mas não inclui conta de serviço, segredo reCAPTCHA ou senha. Não copie um arquivo Admin SDK para o frontend.

## Passo 4 — App Check

O código atual usa **reCAPTCHA v3 no Web**. No App Check do Firebase, registre esse app com o provedor correspondente. Se precisar criar as chaves reCAPTCHA, siga o link oferecido pelo console e configure os domínios da homologação.

- A **site key pública** entra no JSON de build do GitHub.
- A **secret key** do provedor deve ser configurada somente no serviço Google correspondente, nunca no repositório ou na configuração pública.
- O domínio publicado precisa estar autorizado no provedor.
- As callables já exigem App Check fora do emulador. Não desative essa exigência para resolver configuração incompleta.

Resultado: app registrado no App Check e chave pública disponível. O comportamento será validado após publicar.

## Passo 5 — autorizar GitHub no Google Cloud

Abra o Cloud Shell com o projeto correto selecionado e siga a **seção 2** de [CONECTAR-FIREBASE-GITHUB.md](CONECTAR-FIREBASE-GITHUB.md). Ela contém os comandos completos para:

1. Habilitar APIs necessárias.
2. Criar a conta `github-deploy`.
3. Criar a federação OIDC limitada ao Leviticus, à `main`, ao environment `staging` e ao workflow de deploy.
4. Conceder os papéis dos recursos publicados.
5. Conceder `Service Account User` na conta runtime efetiva.
6. Obter o caminho do provider e o e-mail da conta de deploy.

A conta runtime é a identidade que executará as Functions, e não a conta de deploy. Confirme sua existência/configuração no Google Cloud. Não preencha esse campo com um e-mail adivinhado; em projetos novos a preparação das contas runtime/build pode exigir uma etapa administrativa adicional. Se algum comando falhar, pare naquele comando e registre a mensagem sem tokens/chaves; não conceda Owner para contornar o erro.

Esses comandos concedem acesso de publicação do GitHub ao projeto. Devem ser executados conscientemente pelo administrador. Não existe chave privada para baixar nessa configuração.

## Passo 6 — preencher GitHub

No repositório Leviticus, abra Settings → Environments → New environment. Crie **`staging`** e limite deployment branches a **`main`**.

Em Environment variables, crie:

| Nome | O que colocar |
|---|---|
| `FIREBASE_PROJECT_ID` | ID confirmado no passo 1 |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Caminho completo retornado pelo passo 5 |
| `GCP_DEPLOY_SERVICE_ACCOUNT` | `github-deploy@ID_DO_PROJETO.iam.gserviceaccount.com` |
| `FIREBASE_WEB_CONFIG_JSON` | JSON abaixo, preenchido com os valores do passo 3/4 |
| `STAGING_DEPLOY_ENABLED` | `true` após concluir/conferir os passos anteriores |

```json
{
  "USE_EMULATORS": "false",
  "CHURCH_ID": "igreja-homologacao",
  "FIREBASE_PROJECT_ID": "ID_DO_PROJETO",
  "FIREBASE_API_KEY": "VALOR_apiKey",
  "FIREBASE_APP_ID": "VALOR_appId",
  "FIREBASE_SENDER_ID": "VALOR_messagingSenderId",
  "FIREBASE_AUTH_DOMAIN": "ID_DO_PROJETO.firebaseapp.com",
  "RECAPTCHA_SITE_KEY": "CHAVE_PUBLICA_DO_PASSO_4"
}
```

Substitua todos os valores indicativos. Mantenha `USE_EMULATORS` como string `"false"`. `CHURCH_ID` pode permanecer `igreja-homologacao` para a igreja fictícia do primeiro teste.

## Passo 7 — publicar

Em Actions → **Deploy Firebase staging** → Run workflow, escolha **main**.

O workflow executa os testes, compila a entrada conectada, publica backend/regras e depois o Web. Ao concluir, o resumo mostra a URL e o commit publicado. A URL esperada do site padrão é `https://ID_DO_PROJETO.web.app`; ela só está confirmada depois da execução bem-sucedida.

Se falhar, use o nome da etapa e a mensagem para identificar o ajuste. O backend e Hosting são etapas distintas, então uma falha pode deixar publicação parcial. Não use `--force` ou apague recursos para tentar resolver.

## Passo 8 — criar os primeiros acessos de teste

No Authentication → Users, crie contas de teste usando endereços de e-mail que você controla. Escolha senhas próprias, guarde-as com segurança e não as coloque em arquivos do repositório. A app atual não oferece autocadastro.

Para validar bem os papéis, prepare ao menos secretaria, pastor e membro, cada um com seu próprio UID. Copie o **UID do Authentication** para os vínculos; não use o e-mail como ID do documento.

No Firestore → Data:

1. Crie a coleção `churches` e o documento `igreja-homologacao`.
2. No documento da igreja, adicione `name` (string) = `Igreja de homologação` e `intakePastorUid` (string) = UID da conta do pastor.
3. Dentro desse documento, crie a subcoleção `users`.
4. Crie um documento para cada conta usando seu UID como ID; adicione os campos abaixo.

| Documento | `active` (boolean) | `role` (string) |
|---|---|---|
| `churches/igreja-homologacao/users/UID_SECRETARIA` | `true` | `secretary` |
| `churches/igreja-homologacao/users/UID_PASTOR` | `true` | `pastor` |
| `churches/igreja-homologacao/users/UID_MEMBRO` | `true` | `member` |

`active` deve ser booleano, não o texto `"true"`. Os UIDs da tabela são marcadores, não valores reais. O nome `igreja-homologacao` deve corresponder exatamente ao JSON do GitHub. Não há usuário administrativo da igreja criado automaticamente.

Abra o site, faça login e, se o e-mail ainda não estiver confirmado, use **Reenviar confirmação**, confirme na caixa de entrada e saia/entre novamente conforme orientado pela tela. Não simule confirmação de endereços que você não controla.

Resultado esperado:

- Secretaria cadastra pessoas/ministérios e não lê oração reservada.
- Membro envia pedido fictício e vê os próprios pedidos.
- Pastor de acolhimento recebe e acompanha o pedido atribuído a ele.

Esse provisionamento pelo console é inicial e administrativo. A interface de gestão de usuários continua no backlog.

## Passo 9 — validar e automatizar

1. Como secretaria, cadastre uma pessoa fictícia e recarregue a página: o registro precisa permanecer.
2. Como membro, envie um pedido fictício; entre como pastor e confira o acompanhamento.
3. Entre como secretaria novamente: o pedido reservado não pode ser acessível.
4. Execute os demais casos T05–T13 de [TESTAR-COMO-DESENVOLVEDOR.md](TESTAR-COMO-DESENVOLVEDOR.md), conforme plataformas disponíveis.
5. Somente após o ciclo aprovado, crie a variável **do repositório** `AUTO_DEPLOY_STAGING=true` em Settings → Secrets and variables → Actions → Variables.

A partir daí, cada push em `main` passa pelos testes e publica homologação. Android/iOS ainda dependem de seus projetos/configurações nativas; esta conexão prepara o backend compartilhado e o Web.

## Como pedir ajuda durante a configuração

Informe o número do passo, o projeto selecionado e a mensagem de erro sem senhas, tokens ou chaves privadas. Pode compartilhar Project ID, Project number, nome do provider, e-mail técnico da conta de serviço e configuração pública do app. Para eu agir diretamente na console, a sessão precisa ter autenticação autorizada; acesso ao GitHub por integração não autentica automaticamente o Google.
