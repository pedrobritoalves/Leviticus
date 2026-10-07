import { writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export function validateDeployConfig(env) {
  const fail = (message) => { throw new Error(message); };
  if (env.STAGING_DEPLOY_ENABLED !== 'true') fail('Ative STAGING_DEPLOY_ENABLED somente após conferir o projeto de homologação.');
  const project = env.FIREBASE_PROJECT_ID;
  if (!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(project ?? '') || project.startsWith('demo-')) fail('FIREBASE_PROJECT_ID inválido para deploy.');
  if (!/^projects\/\d+\/locations\/global\/workloadIdentityPools\/[\w-]+\/providers\/[\w-]+$/.test(env.GCP_WORKLOAD_IDENTITY_PROVIDER ?? '')) fail('Configure GCP_WORKLOAD_IDENTITY_PROVIDER.');
  if (!new RegExp(`^[a-z][a-z0-9-]+@${project}\\.iam\\.gserviceaccount\\.com$`).test(env.GCP_DEPLOY_SERVICE_ACCOUNT ?? '')) fail('A conta de deploy deve pertencer ao projeto configurado.');
  let config;
  try { config = JSON.parse(env.FIREBASE_WEB_CONFIG_JSON); } catch { fail('FIREBASE_WEB_CONFIG_JSON precisa ser JSON válido.'); }
  if (!config || Array.isArray(config) || typeof config !== 'object') fail('Configuração Web inválida.');
  const keys = ['USE_EMULATORS', 'CHURCH_ID', 'FIREBASE_PROJECT_ID', 'FIREBASE_API_KEY', 'FIREBASE_APP_ID', 'FIREBASE_SENDER_ID', 'FIREBASE_AUTH_DOMAIN', 'RECAPTCHA_SITE_KEY'];
  if (Object.keys(config).some(key => !keys.includes(key))) fail('Configuração contém campos desconhecidos; nunca inclua credenciais de serviço.');
  for (const key of keys) {
    if (typeof config[key] !== 'string' || !config[key].trim() || /CONFIGURAR|PREENCHER|PLACEHOLDER/i.test(config[key])) fail(`Preencha ${key}.`);
  }
  if (config.USE_EMULATORS !== 'false') fail('Deploy exige USE_EMULATORS=false.');
  if (config.FIREBASE_PROJECT_ID !== project) fail('Projeto Web difere do destino de deploy.');
  if (!/^[a-zA-Z0-9_-]{1,100}$/.test(config.CHURCH_ID)) fail('CHURCH_ID inválido.');
  if (!/^\d+$/.test(config.FIREBASE_SENDER_ID) || !config.FIREBASE_APP_ID.startsWith(`1:${config.FIREBASE_SENDER_ID}:web:`)) fail('App ID Web e sender ID incompatíveis.');
  if (config.FIREBASE_AUTH_DOMAIN !== `${project}.firebaseapp.com`) fail('Use o domínio Auth padrão do projeto neste fluxo inicial.');
  return config;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const config = validateDeployConfig(process.env);
    writeFileSync('app/config/firebase.local.json', JSON.stringify(config), { mode: 0o600 });
    console.log('Configuração de homologação validada; arquivo de build preparado.');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
