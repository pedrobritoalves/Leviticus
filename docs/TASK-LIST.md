# Leviticus — task list de construção e liberação

Atualização: 07/10/2026. Marco: apresentação em 13/10/2026. Base inspecionada: commit `dcc483e11304cce5962258c10c793e1246fcacaf`.

Este documento acompanha o código e o Blueprint O.S. Shepherd v1.0, especialmente os capítulos 4–13. Inclui o escopo adicional solicitado: secretaria, EBD, voluntariado, assinatura de documentos e oferta em parceria com consultoria. É um backlog de execução; caixas abertas não significam funcionalidades disponíveis.

## 1. Onde estamos

| Área | Evidência atual | O que ainda impede considerá-la pronta |
|---|---|---|
| Repositório | Código na `main`, escrita confirmada | Consolidar CI, fluxo de revisão e releases |
| Web demonstrativo | Compilação release e testes de interface | Dados são fictícios, apenas em memória |
| Web conectado | Entrada Firebase compila com configuração de emuladores | Fluxo Auth → Functions → Firestore não homologado; sem implantação |
| Pessoas e ministérios | Cadastro/edição básicos, busca, participantes e responsável | Completar cadastro, usuários, histórico, escala e validação integrada |
| Oração | Autor e pastor designado; acompanhamento básico | Homologação conectada; demais rotinas pastorais |
| Permissões | Verificação no backend por igreja, papel e vínculo ativo | Administração de usuários, escopos granulares e testes completos |
| Android | Código Dart compartilhável | `app/android` ainda não existe; configuração e build nativo pendentes |
| iOS | Código Dart compartilhável | `app/ios` ainda não existe; macOS/Xcode, configuração e assinatura pendentes |
| Firebase real | ID conhecido: `leviticus-app-c5110` | Serviços, dados, IAM, faturamento e configurações ainda não inspecionados |
| Qualidade | 41 casos locais; jobs backend e Flutter do CI aprovados em 07/10 | E2E Auth/Functions, dispositivos reais e nuvem ainda não comprovados |
| Demais módulos | Planejados no blueprint | Agenda, secretaria, EBD, assinaturas, discipulado, indicadores e IA ainda não implementados |

A compilação Web não comprova execução Android/iOS. A configuração atual em `firebase_main.dart` usa opções recebidas por variáveis, exige chave reCAPTCHA fora de emuladores e fixa `localhost` para emulação. Esses pontos precisam de adaptação por plataforma. `CHURCH_ID` também é fixado na compilação; a seleção de igreja ainda não existe. As listas carregam todas as páginas; não há sincronização offline nem tempo real implementados.

## 2. Como acompanhar

- `[x]`: concluído com evidência para o escopo exato descrito.
- `[ ]`: pendente, incluindo implementação parcial sem homologação.
- **P0**: necessário para testar o núcleo conectado nas três plataformas.
- **P1**: completa o piloto funcional solicitado e o MVP pastoral do blueprint.
- **P2**: evolução do produto completo e distribuição comercial ampla.
- Responsáveis: **ENG** = engenharia; **PEDRO** = contas, decisões e aceite; **JUR** = consultoria jurídica; **PASTOR** = validação ministerial. São responsabilidades propostas, não atribuições já aceitas por terceiros.
- Cada tarefa deve registrar commit, ambiente, resultado e evidência de teste. Não marcar um módulo pronto só porque sua tela existe.
- Os itens de segurança, privacidade e operação indicados como pré-requisito para dados reais são obrigatórios para produção, mesmo quando não bloqueiam uma demonstração fictícia.

## 3. Marcos de aceite

| Marco | Critério verificável | Dependências |
|---|---|---|
| M0 — experimentar hoje | Abrir demo Web e testar pessoas, ministérios e oração fictícios | DEV-01–04 |
| M1 — Web persistente de homologação | Login, gravação, recarga, isolamento entre igrejas e sigilo aprovados em URL HTTPS | BASE, CLOUD, AUTH básicos, WEB, QA |
| M2 — Android de desenvolvimento | APK instalado; mesmos fluxos e backend de homologação; sessão e rede testadas | M1 + MOBILE + AND |
| M3 — iOS de desenvolvimento | App em simulador e iPhone; mesmos fluxos e backend; assinatura de desenvolvimento válida | M1 + MOBILE + IOS |
| M4 — piloto funcional | Módulos P1 e jornadas pastorais/documentais aprovados pelos usuários responsáveis | M1–M3 + FUNC + DOC + DATA |
| M5 — produto comercial | Operação, contratos, suporte, cobrança, recuperação e distribuição aprovados | M4 + OPS + SAAS + STORE |

M2/M3 não exigem publicação pública nas lojas. Um sistema Web responsivo pode ser testado no navegador do telefone antes dos aplicativos nativos, mas isso não comprova o funcionamento do app iOS/Android.

## 4. P0 — ambiente de desenvolvimento

Responsáveis: ENG + PEDRO. Saída: clone limpo reproduz a demonstração e as verificações. Guia detalhado: [TESTAR-COMO-DESENVOLVEDOR.md](TESTAR-COMO-DESENVOLVEDOR.md).

- [x] BASE-00 — Versionar a entrega inicial no GitHub e conferir igualdade do conteúdo local/remoto.
- [x] BASE-01 — Compilar as entradas Web demonstrativa e Firebase; registrar limitações em `VALIDACAO.md`.
- [ ] DEV-01 — Instalar Git, Flutter 3.47.6/Dart 3.13.5, Chrome, Node 22 e Java 21 compatível com a CLI travada; registrar `flutter doctor -v` e versões.
- [ ] DEV-02 — Clonar o repositório na máquina de Pedro; executar `npm ci` e `flutter pub get` a partir dos lockfiles.
- [ ] DEV-03 — Instalar editor e extensões Flutter/Dart; preparar emulador Android e, no Mac, simulador iOS.
- [ ] DEV-04 — Rodar a demo Web e completar os casos manuais T01–T04 do guia.
- [ ] BASE-02 — Homologar Firebase CLI, SDK Functions e Node 22 em conjunto; resolver o aviso de compatibilidade da CLI antes do deploy.
- [ ] BASE-03 — Executar os testes E2E Auth → Functions → Firestore em ambiente que permita sockets; incluir o comando no CI após estabilização.
- [x] BASE-04 — CI verde: backend Node 22, integração Firestore, análise/testes Flutter e dois builds Web. Evidência: [execução 37611939852](https://github.com/pedrobritoalves/Leviticus/actions/runs/37611939852), jobs backend e Flutter concluídos com sucesso em 07/10/2026. E2E Auth/Functions ainda não integra esse workflow.
- [ ] BASE-05 — Acrescentar jobs Android e iOS/macOS após criar os projetos nativos; separar compilação sem assinatura de distribuição assinada.
- [ ] BASE-06 — Criar configuração explícita de desenvolvimento, homologação e produção; identificar ambiente na tela e impedir release com placeholders ou emuladores.
- [ ] BASE-07 — Criar dados fictícios reproduzíveis de duas igrejas e contas para cada papel; ampliar o seed com admin, segundo membro, segundo pastor e usuário inativo.
- [ ] BASE-08 — Registrar versões de API/dados e política de migração; definir branches, revisão, changelog e tag de cada entrega homologada.

## 5. P0 — Firebase e backend conectado

Responsáveis: ENG; PEDRO para acesso administrativo e faturamento. Depende de BASE-02/03. Saída: chamadas autenticadas persistem somente no ambiente correto.

- [ ] CLOUD-01 — Inventariar o projeto `leviticus-app-c5110`: apps registrados, serviços, região do banco, dados existentes, regras, funções, IAM e faturamento. Não presumir que o projeto está vazio.
- [ ] CLOUD-02 — Separar homologação e produção em projetos Firebase; documentar o papel do projeto existente e os aliases. Manter `demo-leviticus` como destino local de emuladores.
- [ ] CLOUD-03 — Configurar acesso de menor privilégio para desenvolvimento e deploy. Preferir identidade federada no CI; não versionar chaves de serviço, tokens, certificados privados ou senhas reais.
- [ ] CLOUD-04 — Habilitar faturamento necessário para Functions (Blaze), alertas de orçamento e limites operacionais. Registrar responsável por custos; alertas não substituem controle de consumo.
- [ ] CLOUD-05 — Configurar Firestore e conferir região em relação às Functions (`southamerica-east1` no código); registrar decisão antes de criar recursos permanentes.
- [ ] CLOUD-06 — Habilitar Auth por e-mail/senha; configurar domínios autorizados, remetente e links de confirmação/recuperação; testar e-mail real em homologação.
- [ ] CLOUD-07 — Registrar apps Web, Android e iOS no ambiente correspondente; gerar configuração por plataforma com FlutterFire e revisar alterações nos arquivos existentes.
- [ ] CLOUD-08 — Configurar App Check por app/domínio e builds de teste. O backend já exige App Check fora do emulador; validar cliente legítimo e requisição sem atestado antes de liberar acesso.
- [ ] CLOUD-09 — Provisionar igreja, primeiro administrador, pastor de acolhimento e vínculos ativos por operação administrativa confiável. O seed atual serve somente a emuladores.
- [ ] CLOUD-10 — Publicar as oito funções atuais em homologação; conferir região, autenticação, App Check, permissões de serviço, logs e tratamento de erros.
- [ ] CLOUD-11 — Aplicar regras e índices após avaliar o impacto nos recursos existentes; manter acesso direto negado enquanto as operações passarem por Functions. Criar índices conforme as consultas reais exigirem.
- [ ] CLOUD-12 — Testar persistência após recarga, reinício e login em outro dispositivo; confirmar auditoria e negação entre igrejas. Produzir evidência do fluxo completo.
- [ ] CLOUD-13 — Preparar implantação seletiva, verificação após deploy e rollback de aplicação/backend compatível com os dados; registrar versão em execução.

## 6. P0/P1 — identidade, usuários e igrejas

Responsáveis: ENG + PEDRO. Depende de CLOUD-06/09. Saída: cada pessoa recebe somente o acesso necessário, revogável e auditado.

- [ ] AUTH-01 — Homologar login, senha incorreta, recuperação, e-mail não confirmado, expiração e logout no Web/Android/iOS. **P0**.
- [ ] AUTH-02 — Testar revogação de vínculo e troca de conta com páginas abertas; remover dados e rotas da sessão anterior. **P0**.
- [ ] AUTH-03 — Documentar matriz atual e futura: administrador, secretaria, pastor, líder, professor EBD, discipulador, membro, visitante e consultoria. Validar servidor e interface para cada operação. **P0** para os papéis existentes; **P1** para os novos.
- [ ] AUTH-04 — Implementar convites, ativação, suspensão e alteração de papel por interface; impedir autoelevação de privilégio e perda acidental do último administrador. **P1**.
- [ ] AUTH-05 — Relacionar usuário autenticado ao cadastro de pessoa, sem presumir que todo membro tem login e sem unir identidades apenas por nome. **P1**.
- [ ] AUTH-06 — Substituir igreja fixa na compilação por seleção entre vínculos autorizados; limpar estado ao trocar igreja. Testar usuário em duas igrejas. **P1**.
- [ ] AUTH-07 — Implementar escopos por ministério, turma, congregação e vínculo pastoral; consultoria acessa apenas processos explicitamente concedidos. **P1**.
- [ ] AUTH-08 — Implementar autenticação reforçada para acessos privilegiados conforme serviços adotados e política de sessão/recuperação. Pré-requisito de operação com dados sensíveis reais.
- [ ] AUTH-09 — Entregar portal do membro para seus dados, solicitações, agenda e documentos, com aprovação quando a atualização afetar registro institucional. **P1**.

## 7. P0 — Web

Responsável: ENG. Depende de CLOUD e AUTH básicos. Saída: URL de homologação utilizável por Pedro.

- [ ] WEB-01 — Compilar e publicar **`lib/firebase_main.dart`**, com configuração de homologação, no Firebase Hosting. Impedir publicação acidental de `lib/main.dart` como sistema persistente.
- [ ] WEB-02 — Validar HTTPS, domínio autorizado, App Check e navegação/recarga em URL publicada; registrar a URL efetivamente criada.
- [ ] WEB-03 — Testar Chrome, Edge e Safari; desktop, tablet e telefone; teclado, foco, leitor de tela, zoom, contraste e formulários com teclado virtual.
- [ ] WEB-04 — Tratar carregamento, vazio, erro, timeout, sessão expirada e rede indisponível com tentativa segura; preservar rascunho onde apropriado.
- [ ] WEB-05 — Validar atualização de versão/cache para não manter frontend incompatível após deploy; completar ícones, título e metadados.
- [ ] WEB-06 — Substituir carregamento de todas as páginas por paginação incremental/busca no servidor para bases grandes; medir com dados sintéticos. Necessário antes de grandes igrejas.
- [ ] WEB-07 — Definir se haverá instalação PWA; implementar e testar separadamente se adotada. Navegador móvel, PWA e app nativo são entregas distintas. **P2**, não bloqueia o Web conectado.

## 8. P0 — base móvel compartilhada

Responsável: ENG. Depende de CLOUD-07/08. Saída: a mesma base Dart inicializa corretamente em Android e iOS.

- [ ] MOBILE-01 — Definir identificador Android e Bundle ID iOS estáveis, nome e ícones; evitar IDs de exemplo antes de registrar apps e assinatura.
- [ ] MOBILE-02 — Gerar `app/android` e `app/ios` em branch de trabalho, revisando o diff para preservar código, configuração Web e testes existentes.
- [ ] MOBILE-03 — Refatorar inicialização para opções Firebase próprias de cada plataforma/ambiente; validar pacote/Bundle ID e App ID correspondentes.
- [ ] MOBILE-04 — Separar App Check Web, Android e Apple; usar provedores adequados (reCAPTCHA, Play Integrity, App Attest/DeviceCheck conforme suporte). Não exigir reCAPTCHA Web em toda inicialização nativa.
- [ ] MOBILE-05 — Implementar configuração de host de emulador: Web local e simulador iOS normalmente `127.0.0.1`; emulador Android `10.0.2.2`; aparelho físico exige rota própria de desenvolvimento. Não usar `localhost` fixo em todos os dispositivos.
- [ ] MOBILE-06 — Restringir HTTP local/exceções de rede aos builds de desenvolvimento; testar release usando somente endpoints previstos e sem tokens de debug.
- [ ] MOBILE-07 — Testar retorno do segundo plano, retomada de sessão, rotação, teclado, botão Voltar e links de autenticação em dispositivo físico.
- [ ] MOBILE-08 — Definir política de dados offline e limpeza no logout. Implementar fila/reconciliação e proteção do cache se houver offline; declarar claramente operações indisponíveis enquanto não implementado. **P1**, exigência do blueprint para evolução.

## 9. P0 — Android para desenvolvimento; P2 — distribuição

Responsáveis: ENG + PEDRO para aparelho/contas. Depende de MOBILE.

- [ ] AND-01 — Instalar Android Studio/SDK, aceitar licenças, criar emulador e obter `flutter doctor` sem bloqueio Android.
- [ ] AND-02 — Ajustar Gradle/JDK/SDK mínimo e alvo compatíveis com Flutter e plugins travados; conferir permissão de internet e configurações Firebase necessárias.
- [ ] AND-03 — Configurar certificados/fingerprints exigidos pelos serviços habilitados e App Check de teste; separar debug e release.
- [ ] AND-04 — Executar a entrada conectada no emulador e Android físico; cumprir os casos T05–T13 do guia.
- [ ] AND-05 — Gerar APK de teste, instalar fora do IDE e repetir login, persistência e atualização do app sem perda de dados. **M2** somente após esse aceite.
- [ ] AND-06 — Criar e guardar chave de assinatura de release com backup e acesso restrito; gerar AAB assinado e configurar distribuição interna. **P2**.
- [ ] AND-07 — Preparar Play Console, ficha, classificação, política de privacidade, declarações de dados, canal de suporte e requisitos vigentes de teste/publicação. **P2**.

## 10. P0 — iOS para desenvolvimento; P2 — TestFlight/App Store

Responsáveis: ENG + PEDRO para Mac/conta/aparelho. Depende de MOBILE. O build iOS exige macOS e Xcode; Windows sozinho não produz esse build.

- [ ] IOS-01 — Disponibilizar Mac local ou runner macOS, Xcode e ferramentas requeridas pelos plugins; validar `flutter doctor` e simulador.
- [ ] IOS-02 — Configurar Bundle ID, equipe Apple, versão mínima compatível, dependências nativas, ícones e descrições das permissões realmente usadas.
- [ ] IOS-03 — Configurar Firebase e App Check Apple por ambiente; usar configuração de desenvolvimento adequada ao simulador e conferir atestado no aparelho.
- [ ] IOS-04 — Executar no simulador; verificar layout, teclado, autenticação, chamadas e persistência.
- [ ] IOS-05 — Configurar assinatura/provisionamento de desenvolvimento e instalar em iPhone físico; completar T05–T13. **M3** exige execução real, não somente compilação sem assinatura.
- [ ] IOS-06 — Configurar Apple Developer Program/App Store Connect e assinatura de distribuição para TestFlight; gerar IPA e distribuir a testadores autorizados. **P2** ou antecipar para piloto externo.
- [ ] IOS-07 — Preparar privacidade, suporte, capturas, credenciais de revisão e requisitos aplicáveis da App Store; validar eventual exclusão de conta e SDKs utilizados. **P2**.
- [ ] IOS-08 — Registrar resultado da revisão/distribuição. Não vincular a demonstração de 13/10 à aprovação da loja, cujo prazo não controlamos.

## 11. P1 — módulos necessários ao piloto completo

Responsável técnico: ENG. Aceite ministerial: PEDRO/PASTOR. Todos os módulos dependem de identidade, isolamento por igreja, validação de servidor e auditoria. Cada grupo só fecha após sua jornada funcionar nos clientes alvo.

### Pessoas e integração

- [ ] PEO-01 — Completar famílias/responsáveis, relações, fotografia e anexos protegidos, com finalidade definida para cada campo e tratamento específico de menores.
- [ ] PEO-02 — Implementar origem/primeira visita, responsável pelo acolhimento, próximo contato e jornada visitante → integração → membro.
- [ ] PEO-03 — Registrar conversão, batismo, recepção, transferência, desligamento e histórico de alterações sem apagar eventos anteriores.
- [ ] PEO-04 — Implementar importação CSV com prévia, validação, duplicidades e relatório de falhas; exportação autorizada e auditada.
- [ ] PEO-05 — Criar arquivamento/restauração e correção/união de duplicidades preservando vínculos e histórico.

Aceite: cadastrar/importar família, acompanhar visitante, alterar situação e verificar histórico e restrições.

### Ministérios, liderança e voluntários

- [ ] MIN-01 — Completar escopos de liderança, histórico de participação, disponibilidade, escalas, confirmação e substituição de voluntário.
- [ ] MIN-02 — Detectar conflitos de escala e sobrecarga; associar tarefas, treinamentos e requisitos de participação.
- [ ] MIN-03 — Relacionar voluntário ao termo vigente e sua situação documental; manter revisão humana para exceções.
- [ ] MIN-04 — Implementar mentoria, formação, sucessor e grupo de pastoreio do próprio pastor previstos no blueprint.

Aceite: montar equipe/escala, confirmar participação, tratar conflito e consultar termo sem expor dados reservados.

### Oração, pastorado e publicações pastorais

- [ ] PAS-01 — Completar oração com respostas, histórico, próximo contato e reatribuição autorizada; manter privado por padrão. Compartilhamento com intercessores precisa de regra explícita.
- [ ] PAS-02 — Implementar visitas, hospital, plantão, responsáveis e acompanhamento; ligar ação pastoral à pessoa/pedido sem duplicar narrativa confidencial na agenda pública.
- [ ] PAS-03 — Implementar aconselhamento com autorização por vínculo, notas reservadas, histórico e auditoria de leitura; administrador não recebe acesso automático.
- [ ] PAS-04 — Criar painel de prioridades e tarefas vencidas; testar acolhimento por usuário sem treinamento técnico.
- [ ] PAS-05 — Implementar publicações pastorais/mensagens, rascunho, revisão, destinatários e publicação; incluir sermões, séries e biblioteca no aprofundamento do módulo.
- [ ] PAS-06 — Definir fluxo humano para solicitações urgentes e responsabilidades de atendimento; o aplicativo não deve prometer monitoramento contínuo que a igreja não oferece.

Aceite: pedido → atribuição → visita/atendimento → retorno → encerramento, com tentativas de acesso indevido negadas.

### Agenda e eventos

- [ ] AGE-01 — Implementar agendas institucional, pastoral e ministerial; evento, responsável, local, início/fim, fuso e visibilidade.
- [ ] AGE-02 — Implementar recorrência, exceções, cancelamento, reservas de salas/recursos e conflito de horários.
- [ ] AGE-03 — Implementar inscrição, capacidade, presença/check-in e lembretes com preferências; integrar escala e EBD.
- [ ] AGE-04 — Testar lembretes idempotentes, alteração de horário e privacidade do título/descrição em calendário compartilhado.

Aceite: criar evento, reservar sala, inscrever participante, registrar presença e cancelar sem notificação duplicada.

### Secretaria

- [ ] SEC-01 — Implementar solicitações com protocolo, categoria, responsável, prazo, status e histórico.
- [ ] SEC-02 — Criar modelos versionados de carta, declaração, certificado, ata e demais documentos aprovados pela igreja/consultoria.
- [ ] SEC-03 — Gerar PDF com dados aprovados, número/versão, conferência e acesso por destinatário; corrigir por nova versão.
- [ ] SEC-04 — Implementar arquivo institucional, controle de vencimento e processos compartilhados com consultoria por concessão específica.

Aceite: membro solicita documento → secretaria confere → responsável aprova → documento é emitido e disponibilizado ao destinatário.

### EBD e formação

- [ ] EBD-01 — Cadastrar turmas, períodos, professores, salas, currículo e aulas.
- [ ] EBD-02 — Matricular pessoas sem duplicidade; registrar presença/ausência por aula e correções auditadas.
- [ ] EBD-03 — Restringir professor às turmas autorizadas; proteger informações de crianças/responsáveis.
- [ ] EBD-04 — Emitir relatórios de frequência/conclusão e encaminhamento pastoral autorizado de ausências; integrar calendário.
- [ ] DIS-01 — Implementar vínculo discipulador-discípulo, trilhas, encontros e progresso básico, com escopo próprio de acesso.
- [ ] DIS-02 — Implementar pequenos grupos, líderes, participantes, encontros, frequência e multiplicação.

Aceite: matrícula → aula → presença → relatório; discipulado → encontro → avanço → conclusão, mantendo restrições de acesso.

## 12. P1 — documentos, voluntariado e assinatura

Responsáveis: ENG + JUR + PEDRO. Depende de AUTH, SEC, MIN e armazenamento protegido. Revisão jurídica define o tipo de assinatura e exigências por documento; esta lista não declara validade jurídica de um mecanismo ainda não escolhido.

- [ ] DOC-01 — Aprovar modelos, campos obrigatórios, signatários, representação, ordem de assinatura e regras para menores/responsáveis quando aplicáveis.
- [ ] DOC-02 — Implementar armazenamento privado, autorização de upload/download, limites de tamanho/tipo, inspeção de arquivos e retenção. As regras atuais de Storage negam tudo; nenhum fluxo de anexos foi entregue.
- [ ] DOC-03 — Congelar conteúdo/versão do documento antes do envio; registrar hash e vínculo com igreja, pessoa e finalidade.
- [ ] DOC-04 — Selecionar provedor após avaliação técnica/jurídica/comercial; configurar sandbox e segredos apenas no backend.
- [ ] DOC-05 — Implementar emissão de envelope, link individual e estados rascunho/enviado/pendente/assinado/recusado/expirado/cancelado.
- [ ] DOC-06 — Validar autenticidade de webhooks, proteger contra replay, processar idempotentemente e conferir estado com o provedor quando necessário.
- [ ] DOC-07 — Arquivar documento concluído e pacote de evidências; permitir download ao signatário e aos responsáveis autorizados.
- [ ] DOC-08 — Implementar nova versão, renovação, cancelamento e reenvio sem alterar documento já assinado.
- [ ] DOC-09 — Testar dois signatários, recusa, expiração, callback duplicado, callback falso, falha de rede e indisponibilidade do provedor.
- [ ] DOC-10 — Concluir uma assinatura ponta a ponta em sandbox e homologar com a consultoria. Só depois liberar documentos reais.

Aceite: termo aprovado → membro identificado → assinatura no provedor → retorno verificado → PDF/evidências disponíveis. Clicar em “aceito” ou desenhar uma rubrica isoladamente não fecha esta entrega.

## 13. P1/P2 — comunicação, inteligência e blueprint restante

Responsável: ENG; aceite: PEDRO/PASTOR. Os módulos seguintes permanecem no escopo, com implementação incremental.

- [ ] COM-01 — Criar mural/avisos, preferências, grupos autorizados e histórico de entrega. **P1**.
- [ ] COM-02 — Integrar e-mail e push com tokens por dispositivo, limpeza no logout, APNs/Android/Web conforme plataforma e prevenção de duplicidades. Não colocar narrativas confidenciais na notificação. **P1**.
- [ ] COM-03 — Criar portal leve do visitante e fluxo de solicitação de contato/integração. **P1**.
- [ ] COM-04 — Integrar WhatsApp Business, SMS, Google/Microsoft Calendar, Gmail e YouTube quando aprovados; credenciais por igreja, limites, consentimentos e reconciliação. **P2**.
- [ ] INS-01 — Entregar dashboard básico de visitas, frequência, conversões, batismos, discipulado e pendências, com origem e período de cada número. **P1; MVP do blueprint**.
- [ ] INS-02 — Implementar eventos de domínio, outbox/reprocessamento idempotente e atualização de indicadores; escolher transporte de atualização em tempo real sem abrir dados confidenciais. **P1**.
- [ ] INS-03 — Criar históricos e Índice SHALOM com fórmulas/limites documentados, cobertura de dados e validação ministerial. Não apresentar ausência de dado como falha espiritual. **P2**.
- [ ] AI-01 — Implementar IA inicial limitada para resumos e sugestões fundamentadas, com revisão humana e permissão equivalente à do usuário. **P1; MVP do blueprint**.
- [ ] AI-02 — Validar isolamento de contexto, dados autorizados, tentativa de instrução maliciosa em documentos, rastreabilidade, orçamento, retenção e funcionamento quando a IA falha. **P1 antes de ativar IA**.
- [ ] AI-03 — Evoluir Executive AI, PastorCare, Disciple, Leader, Prayer, Sermon, Finance, Church Health, Communication, Events/Planner, Administration, Analytics e Knowledge por casos de uso testados. **P2**.
- [ ] AI-04 — Construir Church Graph completo e recomendações explicáveis sem exposição de relações restritas. **P2**.
- [ ] ADM-01 — Implementar receitas/despesas, contribuições, centros de custo, orçamento, campanhas, missões, aprovações, conciliação e prestação de contas. Separar acesso financeiro individual de relatórios agregados. **P2**.
- [ ] ADM-02 — Implementar patrimônio, inventário, manutenção, reservas e responsáveis por bens. **P2**.
- [ ] ADM-03 — Implementar gestão de missões, evangelismo, projetos sociais e resultados associados às pessoas, com relatórios autorizados. **P2**.

A IA inicial e o discipulado fazem parte do MVP do blueprint. Se não estiverem homologados em 13/10, a apresentação deve ser identificada como incremento/piloto, sem anunciar o MVP completo. Escopo postergado precisa permanecer registrado.

## 14. Proteção de dados e operação com pessoas reais

Responsáveis: ENG + JUR + PEDRO. Estes itens são critérios para uso real conforme risco e serviço habilitado; tarefas documentais precisam de validação jurídica específica.

- [ ] DATA-01 — Mapear dados, finalidades, responsáveis, bases aplicáveis, compartilhamentos e retenção; revisar particularmente religião, aconselhamento, menores e finanças.
- [ ] DATA-02 — Aprovar política de privacidade, termos de uso, contratos com igrejas/consultoria e tratamento por fornecedores; disponibilizar versões aceitas.
- [ ] DATA-03 — Implementar solicitações de acesso, correção, exportação, eliminação/anonimização e revogação quando aplicáveis; verificar identidade e registrar decisão/execução.
- [ ] DATA-04 — Aplicar minimização em logs, métricas, suporte, exportações e mensagens; testar ausência de texto pastoral, tokens e senhas nos registros técnicos.
- [ ] DATA-05 — Definir retenção e proteção da auditoria; controlar acesso administrativo ao banco. Auditoria transacional atual não significa imutabilidade contra administradores de infraestrutura.
- [ ] DATA-06 — Revisar segredos, dependências, permissões IAM e repositório público; criar processo de rotação e resposta a vazamento.
- [ ] OPS-01 — Configurar backups e testar restauração isolada; definir perda máxima tolerável de dados e tempo de recuperação com a igreja.
- [ ] OPS-02 — Implementar monitoramento de erros, disponibilidade, latência, quotas e custo; alertas com responsável e procedimento de atendimento.
- [ ] OPS-03 — Executar teste de carga com volume sintético acordado e verificar limites de consulta, Functions e notificações; registrar meta e resultado.
- [ ] OPS-04 — Criar manual de incidentes, rollback, indisponibilidade, recuperação de acesso e suporte; ensaiar uma falha de cada tipo crítico.
- [ ] OPS-05 — Homologar migrações e compatibilidade com aplicativos antigos; definir política de atualização mínima.
- [ ] OPS-06 — Treinar secretaria, pastor, líder e membro; obter aceite das jornadas reais sem assistência do desenvolvedor.

## 15. P2 — produto oferecido com a consultoria

Responsáveis: PEDRO + JUR + ENG. Pré-requisito: M4 e operação validada.

- [ ] SAAS-01 — Definir titularidade do produto, marca, modelo comercial, planos, limites, responsabilidades e contrato da parceria.
- [ ] SAAS-02 — Criar onboarding de igreja, congregações, importação, personalização e checklist de implantação.
- [ ] SAAS-03 — Implementar assinatura comercial/cobrança e direitos de uso dos módulos; separar inadimplência de retenção/exportação de dados segundo contrato aprovado.
- [ ] SAAS-04 — Criar área de consultoria por igreja/processo concedido, prazo de acesso, revogação e auditoria; impedir acesso transversal indevido.
- [ ] SAAS-05 — Definir suporte, atendimento, treinamento, encerramento contratual, portabilidade e descarte autorizado.
- [ ] STORE-01 — Homologar canal interno Android e TestFlight; executar plano de revisão das lojas e manter metadados alinhados ao que o produto realmente entrega.
- [ ] STORE-02 — Publicar somente builds assinados e rastreáveis; documentar dono das contas, chaves, certificados e renovações.

## 16. Qualidade e teste de aceite

Responsáveis: ENG executa automação; PEDRO valida experiência; PASTOR/JUR validam suas jornadas. Depende da entrega de cada módulo.

- [ ] QA-01 — Executar todos os testes existentes em ambiente reproduzível; registrar separadamente núcleo, Firestore, widgets e E2E.
- [ ] QA-02 — Testar matriz de papéis e duas igrejas em toda operação; tentar chamada direta ao backend, não apenas verificar menu oculto.
- [ ] QA-03 — Testar concorrência, reenvio, conflito de versão, dados inválidos, timeout e revogação com sessão aberta.
- [ ] QA-04 — Criar testes de jornada Web/Android/iOS de login → gravação → recarga → logout; executar em aparelho físico Android/iPhone.
- [ ] QA-05 — Testar navegação, acessibilidade, fuso, formatos brasileiros e telas pequenas; verificar recuperação de formulários após erro.
- [ ] QA-06 — Testar as jornadas integradas de EBD, secretaria, voluntariado e assinatura conforme os módulos forem entregues.
- [ ] QA-07 — Registrar bugs com passos, resultado esperado/observado, versão e evidência sem dados reais. Bloquear release com falha de isolamento, perda de dados, login ou assinatura indevida.
- [ ] QA-08 — Executar ensaio integral com dados fictícios, contas preparadas, internet alternativa e demonstração local de contingência.
- [ ] QA-09 — Gerar release candidato e ata de aceite: o que funciona, em quais plataformas, limitações e próximos passos.

## 17. Ordem de execução até 13/10

Há seis dias de calendário entre 07/10 e 13/10. A sequência abaixo é uma meta condicionada à capacidade e aos acessos; não é promessa de finalizar todo o blueprint em seis dias.

| Data | Foco proposto | Evidência desejada |
|---|---|---|
| 07/10 | DEV, BASE, inventário Firebase e preparação de contas | Demo na máquina de Pedro, diagnóstico do E2E e ambiente de homologação definido |
| 08/10 | CLOUD, AUTH básico, WEB | URL conectada com pessoas, ministérios e oração persistentes |
| 09/10 | MOBILE, Android e preparação iOS; início agenda | Núcleo no Android; compilação/execução inicial iOS se Mac e conta disponíveis |
| 10/10 | Jornadas prioritárias de agenda, secretaria/EBD e pastorado | Incrementos completos por fluxo, com critérios de aceite |
| 11/10 | Discipulado/indicadores prioritários, documentos e sandbox de assinatura conforme dependências | Somente integrações efetivamente verificadas entram no roteiro |
| 12/10 | Congelamento, correções e ensaio | Release candidato; repetir testes críticos; sem novo escopo |
| 13/10 | Apresentação | Demonstrar versão verificada e informar claramente o que permanece no backlog |

Se a capacidade não comportar a sequência, preservar M1 e os testes de sigilo antes de acrescentar módulos. M2/M3 dependem também de equipamentos e assinatura; aprovação de lojas não é condição para a apresentação. O backlog P1/P2 continua válido após o marco.

## 18. O que Pedro precisa disponibilizar

- [ ] PEDRO-01 — Confirmar a máquina de desenvolvimento e acesso a Android físico; disponibilizar Mac/runner macOS e iPhone para aceite iOS.
- [ ] PEDRO-02 — Garantir acesso administrativo ao Firebase para inventário e configurar faturamento quando necessário; conceder permissões pelo serviço, sem enviar chaves privadas pelo chat.
- [ ] PEDRO-03 — Definir igreja fictícia de homologação, primeiro administrador, pastor de acolhimento e e-mails dos testadores.
- [ ] PEDRO-04 — Definir nome público, identificadores dos apps e titular das contas Google/Apple.
- [ ] PEDRO-05 — Fornecer modelos de documentos/termos revisados e contato responsável pelo aceite jurídico; selecionar provedor após proposta concreta.
- [ ] PEDRO-06 — Aprovar prioridades do piloto e executar o guia de testes a cada incremento; registrar defeitos pelos IDs T01–T20.

## 19. Fontes e rastreabilidade

- Código-base inspecionado: [commit dcc483e](https://github.com/pedrobritoalves/Leviticus/commit/dcc483e11304cce5962258c10c793e1246fcacaf), especialmente `firebase_main.dart`, `firebase.json`, regras, testes e workflow.
- Blueprint O.S. Shepherd(1).pdf v1.0: módulos pp. 17–27; permissões/dados pp. 28–35 e 57–63; arquitetura pp. 63–71; MVP e evolução pp. 71–78; adoção/governança pp. 78–89.
- [Configurar Firebase para Flutter](https://firebase.google.com/docs/flutter/setup).
- [App Check por plataforma](https://firebase.google.com/docs/app-check/flutter/default-providers).
- [Functions: desenvolvimento e implantação](https://firebase.google.com/docs/functions/get-started).
- [Conectar Auth ao emulador](https://firebase.google.com/docs/emulator-suite/connect_auth).
- [Preparar iOS](https://docs.flutter.dev/platform-integration/ios/setup) e [distribuir iOS](https://docs.flutter.dev/deployment/ios).
- [Distribuir Android](https://docs.flutter.dev/deployment/android).

As fontes técnicas foram consultadas em 07/10/2026. Revalidar requisitos de lojas e ferramentas no momento da publicação. Este documento não comprova configuração de serviços que ainda não foram inspecionados.
