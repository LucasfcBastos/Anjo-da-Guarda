// Testes das regras do Firestore (rode com: npm test, nesta pasta).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

let env;
const ELDER = 'elder1';
const CARE = 'care1';
const OTHER = 'care2';
const CODE = 'ABC234';

const db = (uid, email = `${uid}@teste.com`) =>
  env.authenticatedContext(uid, { email }).firestore();

const inMinutes = (m) => Timestamp.fromMillis(Date.now() + m * 60_000);

async function seed(fn) {
  await env.withSecurityRulesDisabled((ctx) => fn(ctx.firestore()));
}

async function seedProfiles() {
  await seed(async (f) => {
    await setDoc(doc(f, 'users', ELDER), { name: 'Ana', email: 'elder1@teste.com', role: 'elder' });
    await setDoc(doc(f, 'users', CARE), { name: 'Bruno', email: 'care1@teste.com', role: 'caregiver' });
    await setDoc(doc(f, 'users', OTHER), { name: 'Carla', email: 'care2@teste.com', role: 'caregiver' });
  });
}

const pendingLink = (code = CODE, elderName = 'Ana') => ({
  elderId: ELDER,
  caregiverId: CARE,
  elderName,
  caregiverName: 'Bruno',
  status: 'pending',
  code,
  createdAt: serverTimestamp(),
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-anjo',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seedProfiles();
});

describe('perfil', () => {
  test('cria o próprio perfil com tipo válido', async () => {
    await env.clearFirestore();
    await assertSucceeds(setDoc(doc(db('novo'), 'users', 'novo'), {
      name: 'Novo', email: 'novo@teste.com', role: 'elder', createdAt: serverTimestamp(),
    }));
  });

  test('não aceita tipo de conta inválido', async () => {
    await env.clearFirestore();
    await assertFails(setDoc(doc(db('novo'), 'users', 'novo'), {
      name: 'Novo', email: 'novo@teste.com', role: 'admin', createdAt: serverTimestamp(),
    }));
  });

  test('não lê perfil de outra pessoa', async () => {
    await assertFails(getDoc(doc(db(CARE), 'users', ELDER)));
  });

  test('não troca o tipo de conta', async () => {
    await assertFails(updateDoc(doc(db(CARE), 'users', CARE), { role: 'elder' }));
  });
});

describe('código de vinculação', () => {
  test('idoso gera código', async () => {
    await assertSucceeds(setDoc(doc(db(ELDER), 'linkCodes', CODE), {
      elderId: ELDER, elderName: 'Ana', createdAt: serverTimestamp(), expiresAt: inMinutes(30),
    }));
  });

  test('cuidador não gera código', async () => {
    await assertFails(setDoc(doc(db(CARE), 'linkCodes', CODE), {
      elderId: CARE, elderName: 'Bruno', createdAt: serverTimestamp(), expiresAt: inMinutes(30),
    }));
  });

  test('código não pode valer mais de 30 minutos', async () => {
    await assertFails(setDoc(doc(db(ELDER), 'linkCodes', CODE), {
      elderId: ELDER, elderName: 'Ana', createdAt: serverTimestamp(), expiresAt: inMinutes(600),
    }));
  });

  test('ninguém lista códigos de outro idoso', async () => {
    await assertFails(getDocs(query(collection(db(CARE), 'linkCodes'), where('elderId', '==', ELDER))));
  });
});

describe('pedido e aprovação de vínculo', () => {
  beforeEach(async () => {
    await seed((f) => setDoc(doc(f, 'linkCodes', CODE), {
      elderId: ELDER, elderName: 'Ana', expiresAt: inMinutes(30),
    }));
  });

  test('cuidador com código válido cria pedido pendente', async () => {
    await assertSucceeds(setDoc(doc(db(CARE), 'links', `${ELDER}_${CARE}`), pendingLink()));
  });

  test('código errado é recusado', async () => {
    await assertFails(setDoc(doc(db(CARE), 'links', `${ELDER}_${CARE}`), pendingLink('ZZZ999')));
  });

  test('código expirado é recusado', async () => {
    await seed((f) => setDoc(doc(f, 'linkCodes', CODE), {
      elderId: ELDER, elderName: 'Ana', expiresAt: inMinutes(-1),
    }));
    await assertFails(setDoc(doc(db(CARE), 'links', `${ELDER}_${CARE}`), pendingLink()));
  });

  test('cuidador não cria vínculo já ativo', async () => {
    await assertFails(setDoc(doc(db(CARE), 'links', `${ELDER}_${CARE}`), {
      ...pendingLink(), status: 'active',
    }));
  });

  test('cuidador não cria pedido em nome de outro cuidador', async () => {
    await assertFails(setDoc(doc(db(OTHER), 'links', `${ELDER}_${CARE}`), pendingLink()));
  });

  test('cuidador não aprova o próprio pedido; idoso aprova', async () => {
    await setDoc(doc(db(CARE), 'links', `${ELDER}_${CARE}`), pendingLink());
    const approval = { status: 'active', approvedAt: serverTimestamp() };
    await assertFails(updateDoc(doc(db(CARE), 'links', `${ELDER}_${CARE}`), approval));
    await assertSucceeds(updateDoc(doc(db(ELDER), 'links', `${ELDER}_${CARE}`), approval));
  });

  test('cuidador verifica se o pedido ainda não existe', async () => {
    await assertSucceeds(getDoc(doc(db(CARE), 'links', `${ELDER}_${CARE}`)));
  });

  test('outro cuidador não lê o vínculo', async () => {
    await setDoc(doc(db(CARE), 'links', `${ELDER}_${CARE}`), pendingLink());
    await assertFails(getDoc(doc(db(OTHER), 'links', `${ELDER}_${CARE}`)));
  });
});

describe('acesso aos dados do idoso', () => {
  const linkRef = (f) => doc(f, 'links', `${ELDER}_${CARE}`);

  beforeEach(async () => {
    await seed(async (f) => {
      await setDoc(linkRef(f), { ...pendingLink(), createdAt: Timestamp.now() });
      await setDoc(doc(f, 'elders', ELDER), { name: 'Ana', monitoring: true });
      await setDoc(doc(f, 'elders', ELDER, 'alerts', 'a1'), {
        type: 'fall', status: 'emergency', createdAt: Timestamp.now(),
      });
    });
  });

  test('pedido pendente ainda não dá acesso', async () => {
    await assertFails(getDoc(doc(db(CARE), 'elders', ELDER)));
  });

  test('vínculo ativo dá acesso ao status e aos alertas', async () => {
    await seed((f) => updateDoc(linkRef(f), { status: 'active' }));
    await assertSucceeds(getDoc(doc(db(CARE), 'elders', ELDER)));
    await assertSucceeds(getDocs(collection(db(CARE), 'elders', ELDER, 'alerts')));
  });

  test('cuidador sem vínculo não tem acesso', async () => {
    await assertFails(getDoc(doc(db(OTHER), 'elders', ELDER)));
    await assertFails(getDocs(collection(db(OTHER), 'elders', ELDER, 'alerts')));
  });

  test('cuidador não altera a localização do idoso', async () => {
    await seed((f) => updateDoc(linkRef(f), { status: 'active' }));
    await assertFails(updateDoc(doc(db(CARE), 'elders', ELDER), { monitoring: false }));
  });

  test('cuidador marca alerta como atendido, mas não muda outros campos', async () => {
    await seed((f) => updateDoc(linkRef(f), { status: 'active' }));
    const ref = doc(db(CARE), 'elders', ELDER, 'alerts', 'a1');
    await assertFails(updateDoc(ref, { status: 'safe' }));
    await assertFails(updateDoc(ref, {
      status: 'resolved', resolvedBy: CARE, resolvedAt: serverTimestamp(), type: 'manual',
    }));
    await assertSucceeds(updateDoc(ref, {
      status: 'resolved', resolvedBy: CARE, resolvedByName: 'Bruno', resolvedAt: serverTimestamp(),
    }));
  });

  test('idoso remove o cuidador e o acesso acaba', async () => {
    await seed((f) => updateDoc(linkRef(f), { status: 'active' }));
    await assertSucceeds(deleteDoc(doc(db(ELDER), 'links', `${ELDER}_${CARE}`)));
    await assertFails(getDoc(doc(db(CARE), 'elders', ELDER)));
  });

  test('idoso grava a própria localização e alertas', async () => {
    await assertSucceeds(setDoc(doc(db(ELDER), 'elders', ELDER), {
      location: { lat: -23.5, lng: -46.6 }, lastSeen: serverTimestamp(),
    }, { merge: true }));
    await assertSucceeds(setDoc(doc(db(ELDER), 'elders', ELDER, 'alerts', 'a2'), {
      type: 'fall', status: 'awaiting', createdAt: serverTimestamp(),
    }));
  });

  test('ninguém grava alerta em nome do idoso', async () => {
    await seed((f) => updateDoc(linkRef(f), { status: 'active' }));
    await assertFails(setDoc(doc(db(CARE), 'elders', ELDER, 'alerts', 'a3'), {
      type: 'fall', status: 'emergency',
    }));
  });
});
