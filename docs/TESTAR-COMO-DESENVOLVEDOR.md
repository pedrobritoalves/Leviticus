# Leviticus — guia de teste como desenvolvedor

Data: 07/10/2026. Use com [TASK-LIST.md](TASK-LIST.md). Este guia distingue comandos executáveis com o código atual de etapas dependentes de implementação.

## 1. O que você pode testar agora

| Modalidade | Situação | O que comprova |
|---|---|---|
| Demo Web local | Disponível | Telas de pessoas, ministérios e oração; dados em memória |
| Testes backend/Flutter | Disponíveis | Regras e interfaces cobertas pelos testes |
| Web com emuladores Firebase | Código e comandos disponíveis; E2E ainda pendente | Login e persistência local quando o conjunto de emuladores estiver funcionando |
| Web hospedado com Firebase | Depende de configuração e deploy | Persistência e autenticação na nuvem |
| Android/iOS nativos | Dependem das tarefas MOBILE/AND/IOS | Execução no sistema operacional correspondente |

Não há URL pública conectada confirmada nem APK/IPA entregue nesta versão. A demo não possui login e não serve para comprovar autorização real. Use somente pessoas e situações fictícias nos testes abaixo.

## 2. Preparar a máquina

Instale Git, Chrome, Flutter **3.47.6** (inclui Dart **3.13.5**), Node **22** e Java **21** para Firebase CLI **15.32.1**, atualmente travada. Se a CLI for atualizada na tarefa BASE-02, ajuste o requisito Java à versão homologada. Não atualize dependências indiscriminadamente para tentar corrigir um erro.

Para Android, acrescente Android Studio/SDK e um emulador. Para iOS, use macOS com Xcode e ferramentas indicadas por `flutter doctor`; Windows pode atender Web e Android, mas o build iOS depende do Mac.

Em um terminal, confirme:

```sh
git --version
node --version
npm --version
java -version
flutter --version
flutter doctor -v
flutter devices
```

Se já tiver o clone, atualize-o preservando alterações locais. Para clone novo:

```sh
git clone https://github.com/pedrobritoalves/Leviticus.git
cd Leviticus
git status
```

## 3. Abrir a demo Web hoje

Na raiz do clone:

```sh
cd app
flutter pub get
flutter analyze
flutter test
flutter run -d chrome -t lib/main.dart
```

O Chrome deve abrir o Leviticus. Se não aparecer, confira se `flutter devices` lista Chrome. Faça T01–T04 abaixo. Ao recarregar a página, alterações se perdem: é o comportamento previsto da demonstração em memória.

Para gerar a demo compilada:

```sh
flutter build web --release -t lib/main.dart
```

O resultado fica em `app/build/web`. Esse build não é o sistema conectado. Para interromper `flutter run`, use `q` no terminal.

## 4. Rodar verificações do backend

Na pasta `backend` do clone:

```sh
npm ci
npm run check
npm test
```

Resultado esperado: saída de sucesso e nenhum teste falhando. Consulte [VALIDACAO.md](VALIDACAO.md) para as versões e execuções já comprovadas. O registro inicial é de 33 testes backend, 3 Firestore e 5 Flutter; números podem crescer com novas entregas.

Para integração Firestore, volte à raiz. Deixe as portas dos emuladores livres; não execute este comando junto com a sessão interativa da seção seguinte. O teste limpa o banco **do emulador**, portanto não deve compartilhar a sessão em que você faz teste manual.

**Windows PowerShell:**

```powershell
.\backend\node_modules\.bin\firebase.cmd emulators:exec --only firestore --project demo-leviticus "node --test backend/integration/firestore.test.js"
```

**macOS/Linux (shell POSIX):**

```sh
./backend/node_modules/.bin/firebase emulators:exec --only firestore --project demo-leviticus 'node --test backend/integration/firestore.test.js'
```

Mensagens `PERMISSION_DENIED` são esperadas nos casos que testam negação. Quem determina aprovação é o resultado dos testes e o código de saída.

## 5. Testar Web com login e persistência local

Este é o próximo teste técnico importante. Foi bloqueado no ambiente de construção por `EPERM` no socket do emulador Functions e ainda exige homologação. Na sua máquina, registre o resultado; não é necessário alterar produção para executá-lo.

### Terminal 1 — raiz do clone

**PowerShell:**

```powershell
.\backend\node_modules\.bin\firebase.cmd emulators:start --only auth,firestore,functions --project demo-leviticus
```

**macOS/Linux:**

```sh
./backend/node_modules/.bin/firebase emulators:start --only auth,firestore,functions --project demo-leviticus
```

Espere Auth, Firestore e Functions estarem prontos. As portas configuradas são 9099, 8080 e 5001. Abra a URL da interface de emuladores informada pelo terminal. Não basta a interface abrir: Functions também precisa inicializar.

### Terminal 2 — pasta `backend`

**PowerShell:**

```powershell
$env:FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080"
$env:FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099"
npm run seed:emulator
Remove-Item Env:FIRESTORE_EMULATOR_HOST
Remove-Item Env:FIREBASE_AUTH_EMULATOR_HOST
```

**macOS/Linux:**

```sh
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 npm run seed:emulator
```

O seed cria contas e vínculos fictícios, não uma base completa de pessoas. As listas podem iniciar vazias. Ele só aceita os hosts locais indicados e não deve ser modificado para popular o projeto real.

### Terminal 3 — pasta `app`

O comando é igual nos dois sistemas:

```sh
flutter run -d chrome -t lib/firebase_main.dart --dart-define-from-file=config/emulators.json
```

### Contas locais de teste

Senha fictícia comum: `LeviticusDemo2026!`. Funciona apenas após o seed nos emuladores; não é senha do Firebase real.

| Conta | Papel/vínculo | Resultado esperado no cliente configurado para `igreja-demo` |
|---|---|---|
| `secretaria@example.test` | Secretaria da igreja-demo | Pessoas e ministérios; sem acesso a oração reservada |
| `pastor@example.test` | Pastor de acolhimento da igreja-demo | Cadastros e pedidos atribuídos a ele |
| `membro@example.test` | Membro da igreja-demo | Seus pedidos de oração |
| `consultoria@example.test` | Papel consultoria ainda não habilitado | Acesso negado ao workspace atual |
| `outra@example.test` | Admin de outra igreja | Acesso negado à igreja-demo |

As contas do seed já possuem e-mail confirmado. Os testes de e-mail não confirmado precisam de uma conta adicional criada no Auth Emulator. O seed atual não cria um admin da igreja-demo, um segundo membro ou segundo pastor: sua inclusão está em BASE-07.

Os dados persistem durante a sessão do emulador; não presuma preservação entre reinícios sem configurar exportação/importação. No Web conectado, recarregar a página mantendo os emuladores ligados deve preservar registros.

## 6. Teste automatizado de transporte completo

Pare os emuladores interativos antes de executar. Na raiz:

**PowerShell:**

```powershell
.\backend\node_modules\.bin\firebase.cmd emulators:exec --only auth,firestore,functions --project demo-leviticus "node --test backend/e2e/callable.test.js"
```

**macOS/Linux:**

```sh
./backend/node_modules/.bin/firebase emulators:exec --only auth,firestore,functions --project demo-leviticus 'node --test backend/e2e/callable.test.js'
```

Somente marque BASE-03/QA-01 após sucesso. Se houver falha ao carregar Functions, registre versão de Node/CLI, mensagem e passo. Há um aviso de compatibilidade entre a CLI travada e o SDK Functions que precisa ser resolvido; não desative autorização/App Check de produção para contornar erro de desenvolvimento.

## 7. Testar Firebase de homologação — após CLOUD/WEB

Ainda não há configuração real fornecida no repositório. `app/config/firebase.example.json` contém placeholders e identifica o projeto informado pelo Pedro; não é configuração pronta de homologação.

Depois de criar/validar o ambiente:

1. Preparar arquivo local com os valores do app Firebase correto, igreja de teste e App Check. Usar os nomes/caminhos definidos em BASE-06; não incluir credenciais de serviço.
2. Confirmar que a conta de teste existe no Auth real, está verificada e possui vínculo na igreja. As contas `example.test` do emulador não são copiadas automaticamente.
3. Publicar regras/funções no destino explícito e conferir o efeito sobre recursos existentes.
4. Na pasta `app`, para o esquema atual de configuração:

```sh
flutter run -d chrome -t lib/firebase_main.dart --dart-define-from-file=config/firebase.local.json
flutter build web --release -t lib/firebase_main.dart --dart-define-from-file=config/firebase.local.json
```

5. Publicar o build conectado no Hosting do ambiente escolhido e repetir T05–T13 na URL HTTPS efetiva.

O arquivo local deve apontar para o ambiente de teste real e permanecer fora do Git, conforme a política do repositório. Quando MOBILE-03 introduzir configuração por plataforma, atualizar estes comandos para a convenção implementada. Não há comando de deploy universal nesta etapa: o alvo deve resultar do inventário CLOUD-01/02.

## 8. Android e iOS — comandos futuros, após preparação nativa

Os comandos desta seção **ainda não tornam o projeto atual executável no celular**, pois as pastas nativas/configurações não existem. Primeiro conclua MOBILE-01–06 e AND/IOS correspondentes.

Com os projetos criados e a configuração de plataforma homologada:

```sh
flutter devices
flutter run -d ID_DO_DISPOSITIVO -t lib/firebase_main.dart --dart-define-from-file=config/firebase.local.json
```

Substitua `ID_DO_DISPOSITIVO` pelo valor retornado e use a configuração local correspondente à plataforma/ambiente. Ela não pode reutilizar o App ID Web como se fosse Android/iOS.

Para Android de desenvolvimento, após AND-01–04:

```sh
flutter build apk --debug -t lib/firebase_main.dart --dart-define-from-file=config/firebase.local.json
```

Instale `app/build/app/outputs/flutter-apk/app-debug.apk` no aparelho de teste. O App Check de homologação precisa estar preparado para esse build. Distribuição release usa assinatura própria, não a chave debug.

Para iOS, execute `flutter run` no Mac com simulador ou iPhone identificado. Instalação no iPhone depende de assinatura/provisionamento configurados. IPA/TestFlight pertencem à etapa IOS-06. Rodar Safari no iPhone testa a versão Web; não substitui o teste nativo.

Quando usar emuladores Firebase com Android, o código precisará de MOBILE-05 (`10.0.2.2` no emulador Android); `localhost` atual aponta para o próprio aparelho. Em telefone físico, usar homologação HTTPS é o caminho mais simples; acesso ao emulador local exige rede/configuração de desenvolvimento apropriadas.

## 9. Matriz de testes manuais

Registre ambiente, plataforma, commit/build, resultado e evidência. **D** = demo; **E** = emuladores; **H** = homologação; **F** = depende de funcionalidade futura. Os casos conectados devem ser repetidos no Web, Android e iOS quando disponíveis.

| ID | Ambiente | Passos | Resultado esperado |
|---|---|---|---|
| T01 | D/E/H | Cadastrar pessoa fictícia com contato/endereço; editar e buscar pelo nome | Cadastro e edição corretos; filtros respeitam vínculo |
| T02 | D/E/H | Enviar nome vazio, contato/data inválidos; cancelar formulário | Validação impede dado inválido; cancelar não grava |
| T03 | D/E/H | Criar ministério, selecionar pessoa e responsável; editar equipe | Relações consistentes; responsável pertence aos participantes |
| T04 | D | Criar registro e recarregar a página | Registro novo desaparece: demo em memória |
| T05 | E/H | Entrar como secretaria; cadastrar pessoa; recarregar sem parar backend | Registro permanece; criação deixa auditoria |
| T06 | E/H | Entrar como membro; enviar pedido fictício; sair; entrar como pastor | Autor e pastor designado encontram pedido; pastor atualiza acompanhamento |
| T07 | E/H | Entrar como secretaria, consultoria e conta de outra igreja; tentar recurso restrito | Sem acesso indevido; backend também nega, mesmo chamada direta |
| T08 | E/H | Abrir diálogo/pedido; sair e entrar com outro usuário | Nenhum dado ou rota da identidade anterior permanece acessível |
| T09 | E/H | Com mesma pessoa aberta em dois navegadores, salvar mudanças concorrentes | Conflito é informado; edição recente não é sobrescrita silenciosamente |
| T10 | E/H | Perder rede durante gravação; retomar e repetir envio | Erro compreensível e possibilidade de nova tentativa; não duplicar a mesma operação reenviada |
| T11 | E/H | Administrador de teste desativa vínculo; usuário tenta nova operação com sessão aberta | Servidor nega; cliente trata revogação sem expor novos dados |
| T12 | E/H | Conta não confirmada tenta entrar; testar confirmação/recuperação | Workspace protegido; no H, e-mail chega e link funciona; no E, usar links do emulador |
| T13 | H | Criar no Web e consultar após login no Android/iOS; fechar/reabrir aplicativo | Mesma igreja/dados; sessão e persistência consistentes |
| T14 | F | Criar agenda, reservar sala, provocar conflito e cancelar | Conflito tratado; cancelamento atualiza participantes sem duplicidade |
| T15 | F | Matricular em EBD, registrar presença e entrar como outro professor | Frequência correta; acesso limitado às turmas autorizadas |
| T16 | F | Solicitar declaração como membro; emitir pela secretaria | Protocolo, aprovação e documento acessível só aos autorizados |
| T17 | F | Enviar termo no sandbox, assinar, repetir callback e tentar callback inválido | Evidências corretas; duplicado não duplica efeito; inválido rejeitado |
| T18 | F | Registrar visita/aconselhamento e tentar acesso por admin sem vínculo pastoral | Atendimento acessível apenas aos autorizados |
| T19 | F | Criar discipulado, registrar encontro e conferir dashboard | Progresso e métricas conferem com registros de origem |
| T20 | F/H | Restaurar backup em ambiente isolado e verificar registros/vínculos | Dados recuperados dentro das metas de operação; produção intacta |

T07, T09, T10 e T11 incluem verificação técnica pelo desenvolvedor; menu oculto não comprova segurança. Segundo membro/pastor e admin de teste precisam de BASE-07 para completar toda a matriz.

## 10. Diagnóstico rápido

| Sintoma | Conferir primeiro |
|---|---|
| Demo abriu, mas não existe login | Você iniciou `main.dart`; entrada conectada é `firebase_main.dart` |
| “Ambiente ainda não foi configurado” | Arquivo de defines, `CHURCH_ID`, opções Firebase e App Check; mensagem é genérica e não identifica sozinha a causa |
| Login funciona, workspace nega acesso | E-mail verificado, vínculo ativo, papel aceito e igreja configurada |
| Dados somem ao atualizar | Demo em memória ou reinício do emulador sem exportação; identificar a entrada usada |
| Function indisponível/timeout | Emulador Functions iniciou? Porta 5001, região e compatibilidade CLI/SDK corretas? |
| Android não encontra emulador Firebase | MOBILE-05 pendente; host `localhost` não aponta para o computador |
| Local funciona, nuvem nega chamada | App Check, Auth, domínio, região, IAM e versão implantada; não presumir problema nas regras Firestore |
| `EPERM` no emulador Functions | Permissão do ambiente para sockets locais; registrar o erro e testar ambiente compatível |
| Porta já em uso | Encerrar a sessão de emuladores anterior; não misturar sessão manual e automação |

## 11. Registrar um defeito

Crie uma issue com este modelo; use dados fictícios nas evidências:

```text
Título: [Web/Android/iOS] descrição objetiva
Task/Teste: ex. CLOUD-12 / T05
Commit/build:
Ambiente: demo / emulador / homologação
Sistema operacional e dispositivo/navegador:
Papel do usuário e igreja fictícia:
Passos para reproduzir:
Resultado esperado:
Resultado observado:
Frequência: sempre / intermitente
Evidência: captura e trecho de log sem dados pessoais ou tokens
Severidade: bloqueio / alta / média / baixa
```

Considere bloqueio de release: acesso entre igrejas, exposição pastoral indevida, perda/corrupção de dados, falso estado de assinatura ou impossibilidade de login nos clientes suportados. Depois da correção, repita o caso afetado e a jornada principal, registrando o novo commit.

## 12. Minha rodada de aceite

- [ ] Preparei o ambiente e anotei versões.
- [ ] Executei a demo e distingui memória de persistência.
- [ ] Executei análise e testes locais.
- [ ] Subi os emuladores e criei contas fictícias.
- [ ] Completei os testes conectados disponíveis; anotei os que falharam ou estão bloqueados.
- [ ] Repeti a jornada na URL de homologação quando disponibilizada.
- [ ] Repeti no Android e no iPhone quando as entregas nativas estiverem disponíveis.
- [ ] Abri issues para problemas e vinculei evidências.
- [ ] Confirmei a versão candidata e as limitações antes da apresentação.

Referências técnicas e dependências estão no final da [TASK-LIST.md](TASK-LIST.md). Os comandos foram conferidos contra os arquivos do repositório; nesta tarefa documental eles não representam novas execuções nem novos testes aprovados.
