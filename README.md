# Leviticus

Sistema de administração e cuidado eclesiástico orientado pelo Blueprint O.S. Shepherd. Marco de apresentação: **13/10/2026**.

## Primeira implementação

- **Pessoas:** cadastro e edição com nome, nome preferido, contatos, nascimento, congregação, admissão, batismo e endereço; busca e filtro por vínculo.
- **Ministérios:** cadastro, edição, situação, participantes e responsável, usando as pessoas da mesma igreja.
- **Oração e acompanhamento:** pedido reservado ao autor e ao pastor de acolhimento; situação, próximo contato e proteção por vínculo, sem acesso administrativo automático.
- **Autenticação:** integração Firebase Auth, confirmação de e-mail, recuperação de acesso e encerramento de sessão.
- **Backend:** funções autenticadas, autorização por igreja, versionamento, idempotência e auditoria transacional.
- **Segurança:** acesso direto ao Firestore/Storage negado; consultoria e papéis não implementados não recebem acesso aos cadastros.
- **Demonstração:** entrada Flutter com dados fictícios em memória. A entrada Firebase é separada e persistente após configuração.

Este incremento NÃO é o sistema completo. Família, fotografia, anexos, gestão de usuários por interface, aconselhamento detalhado, EBD, agenda, secretaria e assinaturas ainda serão implementados. A lista de dados pessoais cresce somente conforme finalidade e necessidade.

## Construção e testes

- [Task list completa: Web, Android, iOS e produto](docs/TASK-LIST.md)
- [Guia para testar como desenvolvedor](docs/TESTAR-COMO-DESENVOLVEDOR.md)

## Executar

Ver [docs/EXECUTAR.md](docs/EXECUTAR.md). Ver resultados e limitações em [docs/VALIDACAO.md](docs/VALIDACAO.md).

```sh
cd backend
npm ci
npm test
```

```sh
cd app
flutter pub get
flutter run -d chrome
```

`lib/main.dart` usa memória e dados fictícios. `lib/firebase_main.dart` exige configuração Firebase ou emuladores. Não confundir o modo demonstrativo com persistência de produção.

## Estrutura

- `app/`: Flutter Web, contratos de repositório, formulários e testes de interface.
- `backend/src/`: domínio, autorização e adaptador Firestore.
- `backend/test/`: testes de regras de aplicação.
- `backend/integration/`: transações e regras Firestore no emulador.
- `backend/e2e/`: teste de Auth + Functions + Firestore, dependente do ambiente de emulação.
- `infra/`: regras e índices.
- `.github/workflows/ci.yml`: verificação automática preparada para o GitHub.

Projeto Firebase informado: `leviticus-app-c5110`. Não houve deploy nem acesso aos seus dados. O projeto padrão local é `demo-leviticus`, para prevenir uso acidental do ambiente real.
