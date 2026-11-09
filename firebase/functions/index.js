// Backend do Anjo da Guarda (Cloud Functions, exige o plano Blaze).
//
// 1. alertPush: quando um alerta do idoso muda de status, envia push (FCM)
//    para os cuidadores com vínculo ativo, mesmo com o app deles fechado.
// 2. unansweredFalls: a cada minuto, marca como emergência as quedas cujo
//    prazo de 30 s acabou sem resposta do celular do idoso (ex.: celular
//    sem internet, desligado ou com o app pausado pelo sistema).
//
// As credenciais administrativas ficam só no servidor (conta de serviço do
// Firebase); o app nunca tem acesso a elas.

const { setGlobalOptions } = require('firebase-functions/v2');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { logger } = require('firebase-functions');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();

// Mesma região do banco Firestore (São Paulo). Se o banco for criado em
// outra região, troque aqui antes do deploy.
const REGION = 'southamerica-east1';
setGlobalOptions({ region: REGION, maxInstances: 5 });

// Mesmo canal criado pelo app (NotificationService.caregiverChannelId).
const ANDROID_CHANNEL = 'cuidador_alertas';
// Tolerância de rede antes de considerar a queda sem resposta.
const GRACE_MS = 10_000;

function messageFor(status, alert) {
  const name = alert.elderName || 'O idoso';
  const isFall = alert.type === 'fall';
  switch (status) {
    case 'awaiting':
      return {
        title: `Possível queda: ${name}`,
        body: `O celular de ${name} detectou uma possível queda. Aguardando resposta por até 30 segundos.`,
        urgent: false,
      };
    case 'emergency':
      return {
        title: isFall ? `EMERGÊNCIA: ${name} não respondeu` : `EMERGÊNCIA: ${name} pediu ajuda`,
        body: alert.emergencySource === 'server'
          ? `${name} não confirmou que está bem e o celular dele não respondeu. Abra o app para ver a última localização.`
          : `Abra o app para ver a localização de ${name}.`,
        urgent: true,
      };
    case 'safe':
      return {
        title: `${name} está bem`,
        body: `${name} respondeu que está bem após a possível queda.`,
        urgent: false,
      };
    default:
      return null;
  }
}

/** Tokens FCM de todos os cuidadores com vínculo ativo. */
async function caregiverTokens(elderId) {
  const links = await db.collection('links')
    .where('elderId', '==', elderId)
    .where('status', '==', 'active')
    .get();
  const devices = await Promise.all(links.docs.map((l) =>
    db.collection('users').doc(l.get('caregiverId')).collection('devices').get()));
  return devices.flatMap((snap) => snap.docs.map((d) => d.ref));
}

exports.alertPush = onDocumentWritten('elders/{elderId}/alerts/{alertId}', async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!after || before?.status === after.status) return;

  const msg = messageFor(after.status, after);
  if (!msg) return;

  const { elderId, alertId } = event.params;
  const deviceRefs = await caregiverTokens(elderId);
  if (deviceRefs.length === 0) return;

  // Mesma "tag" usada pelas notificações locais do app: no Android,
  // a notificação do mesmo alerta é substituída em vez de duplicada.
  const tag = `${alertId}-${after.status}`;
  const response = await getMessaging().sendEachForMulticast({
    tokens: deviceRefs.map((r) => r.id),
    notification: { title: msg.title, body: msg.body },
    data: { elderId, alertId, status: after.status },
    android: {
      priority: 'high',
      notification: {
        channelId: ANDROID_CHANNEL,
        tag,
        sound: 'default',
        priority: msg.urgent ? 'max' : 'high',
      },
    },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: { aps: { sound: 'default', 'thread-id': elderId } },
    },
  });

  // Remove tokens de aparelhos que desinstalaram o app ou saíram da conta.
  const stale = [];
  response.responses.forEach((r, i) => {
    const code = r.error?.code;
    if (code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token') {
      stale.push(deviceRefs[i].delete());
    }
  });
  await Promise.all(stale);
  logger.info('push enviado', {
    elderId, alertId, status: after.status,
    sent: response.successCount, failed: response.failureCount,
  });
});

exports.unansweredFalls = onSchedule({ schedule: 'every 1 minutes', timeZone: 'America/Sao_Paulo' }, async () => {
  const limit = Timestamp.fromMillis(Date.now() - GRACE_MS);
  const overdue = await db.collectionGroup('alerts')
    .where('status', '==', 'awaiting')
    .where('deadline', '<=', limit)
    .limit(50)
    .get();

  await Promise.all(overdue.docs.map((doc) => db.runTransaction(async (tx) => {
    const fresh = await tx.get(doc.ref);
    // O idoso pode ter respondido enquanto isso.
    if (fresh.get('status') !== 'awaiting') return;
    tx.update(doc.ref, {
      status: 'emergency',
      emergencySource: 'server',
      emergencyAt: Timestamp.now(),
    });
  })));
  if (!overdue.empty) logger.info('quedas sem resposta', { count: overdue.size });
});
