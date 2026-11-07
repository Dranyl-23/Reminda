/* eslint-disable @typescript-eslint/no-require-imports */
const fs = require('fs');
const path = require('path');

const content = fs.readFileSync(path.join(__dirname, '../.env.local'), 'utf8');
const match = content.match(/FIREBASE_SERVICE_ACCOUNT_KEY='([\s\S]*?)'/);
if (!match) {
  console.error('Service account key not found in .env.local');
  process.exit(1);
}
const serviceAccount = JSON.parse(match[1]);
const mongoMatch = content.match(/MONGODB_URI=(.*)/);
const mongoUri = mongoMatch ? mongoMatch[1].trim() : null;

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { MongoClient } = require('mongodb');

const app = initializeApp({
  credential: cert(serviceAccount),
  projectId: 'schedly-b4b8d'
});

const db = getFirestore(app, 'default');
const auth = getAuth(app);

const BASE_LOGO_URL = 'https://raw.githubusercontent.com/Dranyl-23/Reminda/main/assets/logos/';

// Optional local overrides (loaded from untracked local JSON if present; never hardcode PII in git)
const LOCAL_OVERRIDES_PATH = path.join(__dirname, 'user_overrides.local.json');
const localOverrides = fs.existsSync(LOCAL_OVERRIDES_PATH)
  ? JSON.parse(fs.readFileSync(LOCAL_OVERRIDES_PATH, 'utf8'))
  : {};
const WINDOWS_USER_MAP = localOverrides.windowsUserMap || {};
const ANDROID_VERSION_MAP = localOverrides.androidVersionMap || {};

async function migrateOrphanedAndRestoreSubcollections() {
  console.log('\n--- 1. CHECKING SUBCOLLECTIONS & MIGRATIONS ---');
  const migrationConfig = localOverrides.migration;
  if (!migrationConfig || !migrationConfig.orphanUid || !migrationConfig.targetUid) {
    console.log('  * No local orphan UID migration configured; skipping.');
    return;
  }

  const { orphanUid, targetUid } = migrationConfig;
  const orphanRef = db.collection('users').doc(orphanUid);
  const targetRef = db.collection('users').doc(targetUid);

  const orphanSchedSnap = await orphanRef.collection('schedules').get();
  if (orphanSchedSnap.size > 0) {
    const batch = db.batch();
    orphanSchedSnap.forEach((docSnap) => {
      batch.set(targetRef.collection('schedules').doc(docSnap.id), docSnap.data(), { merge: true });
      batch.delete(docSnap.ref);
    });
    const orphanProfSnap = await orphanRef.collection('profiles').get();
    orphanProfSnap.forEach((docSnap) => {
      batch.set(targetRef.collection('profiles').doc(docSnap.id), docSnap.data(), { merge: true });
      batch.delete(docSnap.ref);
    });
    batch.delete(orphanRef);
    await batch.commit();
    console.log(`  + Migrated ${orphanSchedSnap.size} schedules from ${orphanUid} to ${targetUid}.`);
  }
}

async function syncAuthUsers() {
  console.log('\n--- 2. SYNCING FIREBASE AUTH USERS & PLATFORM METADATA TO FIRESTORE (default) ---');
  const authUsersResult = await auth.listUsers();
  const authUsers = authUsersResult.users;
  console.log(`Found ${authUsers.length} total users in Firebase Auth.`);

  let windowsCount = 0;
  let androidCount = 0;

  for (const u of authUsers) {
    const userRef = db.collection('users').doc(u.uid);
    const docSnap = await userRef.get();
    const existing = docSnap.exists ? docSnap.data() : {};

    const email = u.email || existing.email || '';
    const winMeta = WINDOWS_USER_MAP[u.uid];

    const displayName =
      (winMeta && winMeta.displayName) ||
      u.displayName ||
      (existing.displayName && existing.displayName !== 'User' ? existing.displayName : null) ||
      (email ? email.split('@')[0] : 'Reminda User');

    // Update Firebase Auth displayName if missing on DesktopGoogleAuthService accounts
    if (!u.displayName && displayName && displayName !== 'Reminda User') {
      try {
        await auth.updateUser(u.uid, { displayName });
        console.log(`  * Updated Firebase Auth displayName for ${email} -> "${displayName}"`);
      } catch (e) {
        console.warn(`  ! Could not update Auth displayName for ${u.uid}: ${e.message}`);
      }
    }

    const createdAt = u.metadata.creationTime ? new Date(u.metadata.creationTime) : new Date();
    const lastSignIn = u.metadata.lastSignInTime ? new Date(u.metadata.lastSignInTime) : createdAt;

    const platform = winMeta ? winMeta.platform : 'Mobile (Android)';
    const appVersion = winMeta
      ? winMeta.appVersion
      : (ANDROID_VERSION_MAP[u.uid] || existing.appVersion || 'v1.0.0+15');

    if (platform.includes('Windows')) windowsCount++;
    else androidCount++;

    // Count subcollections
    const [profSnap, schedSnap] = await Promise.all([
      userRef.collection('profiles').get(),
      userRef.collection('schedules').get(),
    ]);

    const payload = {
      id: u.uid,
      displayName,
      email,
      photoUrl: u.photoURL || existing.photoUrl || null,
      createdAt: Timestamp.fromDate(createdAt),
      lastSyncAt: Timestamp.fromDate(lastSignIn),
      lastActive: Timestamp.fromDate(lastSignIn),
      updatedAt: lastSignIn.toISOString(),
      platform,
      appVersion,
      profilesCount: profSnap.size,
      schedulesCount: schedSnap.size,
      status: existing.status || 'active',
    };

    await userRef.set(payload, { merge: true });
    console.log(
      `  ~ [${platform.padEnd(17)}] ${displayName.padEnd(26)} (${email.padEnd(34)}) | ${appVersion} | profiles: ${profSnap.size}, schedules: ${schedSnap.size}`
    );
  }

  console.log(
    `User sync complete: ${authUsers.length} total (${windowsCount} Desktop Windows, ${androidCount} Mobile Android).`
  );
}

async function restoreAndSyncFeedbacks() {
  console.log('\n--- 3. SYNCING USER FEEDBACKS TO MONGODB WAREHOUSE ---');

  const feedbackSeed = Array.isArray(localOverrides.feedbackDocs) ? localOverrides.feedbackDocs : [];
  if (feedbackSeed.length > 0) {
    const batch = db.batch();
    for (const fb of feedbackSeed) {
      if (!fb.id) continue;
      const ref = db.collection('user_feedback').doc(fb.id);
      batch.set(ref, {
        ...fb,
        timestamp: fb.createdAtIso ? Timestamp.fromDate(new Date(fb.createdAtIso)) : Timestamp.now(),
      }, { merge: true });
    }
    await batch.commit();
  }

  // Mirror all feedbacks to MongoDB Atlas reminda_warehouse.customer_feedbacks
  if (mongoUri) {
    const allFbSnap = await db.collection('user_feedback').get();
    const allFbDocs = [];
    allFbSnap.forEach((d) => {
      allFbDocs.push({ id: d.id, ...d.data() });
    });

    const client = new MongoClient(mongoUri);
    try {
      await client.connect();
      const mdb = client.db('reminda_warehouse');
      const col = mdb.collection('customer_feedbacks');
      const bulkOps = allFbDocs.map((docItem) => ({
        updateOne: {
          filter: { firestoreId: docItem.id },
          update: {
            $set: {
              ...docItem,
              firestoreId: docItem.id,
              syncedAt: new Date(),
            },
          },
          upsert: true,
        },
      }));
      if (bulkOps.length > 0) {
        const res = await col.bulkWrite(bulkOps);
        console.log(
          `  + Mirrored ${allFbDocs.length} feedback documents to MongoDB Atlas reminda_warehouse.customer_feedbacks (upserted: ${res.upsertedCount}, modified: ${res.modifiedCount}).`
        );
      }
    } finally {
      await client.close();
    }
  }
}

async function restoreSchoolLogos() {
  console.log('\n--- 4. RESTORING & LINKING SCHOOL LOGOS IN FIRESTORE ---');
  const logosDir = path.join(__dirname, '../../assets/logos');
  const logoFiles = fs.readdirSync(logosDir);
  console.log(`Found ${logoFiles.length} logo files in assets/logos.`);

  const instSnap = await db.collection('institutions').get();
  console.log(`Found ${instSnap.size} institutions in Firestore (default).`);

  const docsList = [];
  instSnap.forEach(d => {
    docsList.push({ id: d.id, ...d.data(), docRef: d.ref });
  });

  function cleanStr(s) {
    return (s || '').toLowerCase().replace(/[^a-z0-9]/g, ' ').replace(/\s+/g, ' ').trim();
  }

  const manualFileMap = {
    'addu.png': ['ateneo de davao'],
    'ADMU.avif': ['ateneo de manila'],
    'ADNU.avif': ['ateneo de naga'],
    'cjc.png': ['cor jesu'],
    'dlsu.png': ['de la salle'],
    'ust.png': ['university of santo tomas'],
    'up.png': ['university of the philippines'],
    'usep.png': ['university of southeastern philippines'],
    'dssc.png': ['davao del sur state college'],
    'DOrSU-Logo.png': ['davao oriental state university'],
    'DNSC-Panabo.png': ['davao del norte state college'],
    'FEU-IT.png': ['feu institute of technology', 'feu it'],
    'FEU-ALABANG.png': ['feu alabang'],
    'FEU-CAVITE.jpg': ['feu cavite'],
    'FEU-DILIMAN.png': ['feu diliman'],
    'FEU-PAMPANGA.png': ['feu pampanga'],
    'FEU-ROOSEVELT.jpg': ['feu roosevelt'],
    'feu.png': ['far eastern university'],
    'hcdc.jpg': ['holy cross of davao'],
    'MSU_-_Gensan_logo.png': ['mindanao state university general santos', 'msu gensan'],
    'NDDUseal.png': ['notre dame of dadiangas'],
    'rmmc-gensan.png': ['ramon magsaysay memorial colleges general santos', 'rmmc gensan'],
    'rmmc-koronadal.png': ['ramon magsaysay memorial colleges koronadal', 'rmmc koronadal'],
    'USM-Kabacan.png': ['university of southern mindanao'],
    'wvsu.png': ['west visayas state university'],
    'spmc.png': ['southern philippines medical center'],
    'deped.png': ['department of education'],
    'jollibee.png': ['jollibee'],
    'mcdo.png': ['mcdonald'],
    'Abreeza.png': ['abreeza'],
    'Gmalldigos.webp': ['g mall digos', 'gmall digos'],
    'SC-Padada.png': ['southeastern college of padada'],
    'GoldenState-Gensan.jpg': ['goldenstate', 'golden state college'],
    'GSDMSFI-Gensan.jpg': ['general santos doctors'],
    'spac.png': ['south philippine adventist college'],
    'um.png': ['university of mindanao']
  };

  let updatedCount = 0;
  const batch = db.batch();

  for (const doc of docsList) {
    if (doc.logoUrl && (String(doc.logoUrl).startsWith('data:image/') || String(doc.logoUrl).includes('ibb.co'))) {
      continue;
    }
    const docClean = cleanStr(doc.name + ' ' + (doc.shortName || ''));
    let matchedLogo = null;

    for (const [file, keywords] of Object.entries(manualFileMap)) {
      for (const kw of keywords) {
        if (docClean.includes(kw)) {
          matchedLogo = file;
          break;
        }
      }
      if (matchedLogo) break;
    }

    if (!matchedLogo) {
      for (const file of logoFiles) {
        const fileBase = cleanStr(file.replace(/\.[^/.]+$/, ''));
        if (fileBase.length >= 5 && docClean.includes(fileBase)) {
          matchedLogo = file;
          break;
        }
      }
    }

    if (matchedLogo) {
      const fullUrl = BASE_LOGO_URL + encodeURIComponent(matchedLogo);
      if (doc.logoUrl !== fullUrl) {
        batch.set(doc.docRef, { logoUrl: fullUrl }, { merge: true });
        updatedCount++;
        console.log(`  + Linked logo for [${doc.shortName || doc.name}]: ${matchedLogo}`);
      }
    }
  }

  if (updatedCount > 0) {
    await batch.commit();
  }
  console.log(`Logo linking complete: ${updatedCount} institutions updated with verified logos.`);

  const jsonPath = path.join(__dirname, '../src/lib/codebase_institutions.json');
  if (fs.existsSync(jsonPath)) {
    const list = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
    const freshInst = await db.collection('institutions').get();
    const map = {};
    freshInst.forEach(d => {
      const data = d.data();
      if (data.logoUrl) map[d.id] = data.logoUrl;
    });
    let jsonUpdated = 0;
    for (const item of list) {
      if (map[item.id] && item.logoUrl !== map[item.id]) {
        item.logoUrl = map[item.id];
        jsonUpdated++;
      }
    }
    fs.writeFileSync(jsonPath, JSON.stringify(list, null, 2), 'utf8');
    console.log(`Updated ${jsonUpdated} institutions in codebase_institutions.json.`);
  }
}

async function main() {
  try {
    await migrateOrphanedAndRestoreSubcollections();
    await syncAuthUsers();
    await restoreAndSyncFeedbacks();
    await restoreSchoolLogos();
    console.log('\nAll backend fixes & validations completed successfully!');
    process.exit(0);
  } catch (err) {
    console.error('\nError running backend fix:', err);
    process.exit(1);
  }
}

main();
