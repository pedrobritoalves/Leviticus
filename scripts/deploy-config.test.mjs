import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateDeployConfig } from './deploy-config.mjs';
const config = { USE_EMULATORS: 'false', CHURCH_ID: 'igreja-teste', FIREBASE_PROJECT_ID: 'leviticus-test', FIREBASE_API_KEY: 'public-test-key', FIREBASE_APP_ID: '1:123:web:test', FIREBASE_SENDER_ID: '123', FIREBASE_AUTH_DOMAIN: 'leviticus-test.firebaseapp.com', RECAPTCHA_SITE_KEY: 'public-test-site-key' };
const env = { STAGING_DEPLOY_ENABLED: 'true', FIREBASE_PROJECT_ID: config.FIREBASE_PROJECT_ID, GCP_WORKLOAD_IDENTITY_PROVIDER: 'projects/123/locations/global/workloadIdentityPools/github/providers/leviticus', GCP_DEPLOY_SERVICE_ACCOUNT: 'github-deploy@leviticus-test.iam.gserviceaccount.com', FIREBASE_WEB_CONFIG_JSON: JSON.stringify(config) };
test('aceita configuração coerente sem alterar os dados', () => assert.deepEqual(validateDeployConfig(env), config));
test('bloqueia deploy desabilitado e projeto de emulação', () => {
  assert.throws(() => validateDeployConfig({ ...env, STAGING_DEPLOY_ENABLED: 'false' }));
  assert.throws(() => validateDeployConfig({ ...env, FIREBASE_PROJECT_ID: 'demo-leviticus' }));
});
test('bloqueia troca acidental de projeto e credencial de outra conta', () => {
  assert.throws(() => validateDeployConfig({ ...env, FIREBASE_WEB_CONFIG_JSON: JSON.stringify({ ...config, FIREBASE_PROJECT_ID: 'outra-igreja' }) }));
  assert.throws(() => validateDeployConfig({ ...env, GCP_DEPLOY_SERVICE_ACCOUNT: 'github-deploy@outro-projeto.iam.gserviceaccount.com' }));
});
test('bloqueia configuração de emulador, placeholders e credenciais privadas', () => {
  for (const delta of [{ USE_EMULATORS: 'true' }, { RECAPTCHA_SITE_KEY: 'CONFIGURAR' }, { private_key: 'não deve ser aceita' }, { FIREBASE_APP_ID: '1:123:android:teste' }]) {
    assert.throws(() => validateDeployConfig({ ...env, FIREBASE_WEB_CONFIG_JSON: JSON.stringify({ ...config, ...delta }) }));
  }
});
test('rejeita JSON inválido e provider ausente sem revelar configuração', () => {
  assert.throws(() => validateDeployConfig({ ...env, FIREBASE_WEB_CONFIG_JSON: '{bad' }), /JSON válido/);
  assert.throws(() => validateDeployConfig({ ...env, GCP_WORKLOAD_IDENTITY_PROVIDER: '' }), /Configure GCP/);
});
