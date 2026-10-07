# Executar o primeiro incremento

## Requisitos

- Flutter 3.47.6 / Dart 3.13.5.
- Node 22 (runtime de Functions) e npm.
- Java 21 para Firebase CLI 15.32.1 (versão travada no projeto).

## Demonstração visual

Na pasta `app`:

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d chrome -t lib/main.dart
```

Este modo oferece Pessoas, Ministérios e Oração com dados fictícios em memória. Reiniciar apaga as alterações. Não solicita credenciais nem acessa o Firebase.

## Testes do servidor

Na pasta `backend`:

```sh
npm ci
npm run check
npm test
```

Na raiz:

```sh
backend/node_modules/.bin/firebase emulators:exec --only firestore --project demo-leviticus 'node --test backend/integration/firestore.test.js'
```

Erros PERMISSION_DENIED no log são esperados nos casos de negação testados. O resultado do comando e os testes determinam sucesso.

## Execução conectada em emuladores

Na raiz, terminal 1:

```sh
backend/node_modules/.bin/firebase emulators:start --only auth,firestore,functions --project demo-leviticus
```

Terminal 2, pasta `backend` (sintaxe de variáveis para shell POSIX):

```sh
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 npm run seed:emulator
```

Terminal 3, pasta `app`:

```sh
flutter run -d chrome -t lib/firebase_main.dart --dart-define-from-file=config/emulators.json
```

Contas apenas para emulador: `secretaria@example.test`, `pastor@example.test`, `membro@example.test`, `consultoria@example.test`, `outra@example.test`. Senha fictícia comum: `LeviticusDemo2026!`. Secretaria e pastor acessam o cadastro de igreja-demo; membro acessa seus pedidos de oração; a consultoria é negada e a conta de outra igreja não acessa igreja-demo. O seed aborta se não receber exatamente os hosts locais dos emuladores e nunca inicializa projeto real.

Teste de transporte completo, na raiz:

```sh
backend/node_modules/.bin/firebase emulators:exec --only auth,firestore,functions --project demo-leviticus 'node --test backend/e2e/callable.test.js'
```

O ambiente precisa permitir os sockets locais usados por Functions. Consulte VALIDACAO.md para saber o que foi efetivamente executado nesta entrega.

## Preparação do Firebase real — pendente

1. Confirmar serviços, região e dados já existentes no projeto `leviticus-app-c5110` antes de qualquer deploy.
2. Registrar ou reutilizar o app Web, ativar Auth e configurar App Check para o domínio autorizado.
3. Copiar `app/config/firebase.example.json` para `firebase.local.json` e preencher a configuração pública Firebase e a chave pública reCAPTCHA. Não incluir credenciais de serviço.
4. Configurar `intakePastorUid` no documento da igreja para o UID do pastor de acolhimento. Provisionar os primeiros vínculos por administração confiável: `churches/{churchId}/users/{uid}` com `active: true` e papel autorizado. Não há autoatribuição de permissões no cliente.
5. Executar build da entrada conectada, testar em ambiente isolado e só então planejar implantação.

```sh
flutter build web --release -t lib/firebase_main.dart --dart-define-from-file=config/firebase.local.json
```

Não execute deploy sobre um banco compartilhado sem avaliar as regras: este incremento nega todo acesso direto e usa funções para ler e gravar. O arquivo `.firebaserc` registra o destino informado, mas não dá credenciais nem autoriza mudanças em recursos existentes.
