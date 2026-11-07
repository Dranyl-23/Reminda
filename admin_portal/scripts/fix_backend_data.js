const fs = require('fs');
const path = require('path');

const content = fs.readFileSync(path.join(__dirname, '../.env.local'), 'utf8');
const match = content.match(/FIREBASE_SERVICE_ACCOUNT_KEY='(.*)'/s);
if (!match) {
  console.error('Service account key not found in .env.local');
  process.exit(1);
}
const serviceAccount = JSON.parse(match[1]);

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

const app = initializeApp({
  credential: cert(serviceAccount),
  projectId: 'schedly-b4b8d'
});

const db = getFirestore(app, 'default');
const auth = getAuth(app);

const BASE_LOGO_URL = 'https://raw.githubusercontent.com/Dranyl-23/Reminda/main/assets/logos/';

async function syncAuthUsers() {
  console.log('\n--- 1. SYNCING FIREBASE AUTH USERS TO FIRESTORE (default) ---');
  const authUsersResult = await auth.listUsers();
  const authUsers = authUsersResult.users;
  console.log(`Found ${authUsers.length} total users in Firebase Auth.`);

  let createdCount = 0;
  let updatedCount = 0;

  for (const u of authUsers) {
    const userRef = db.collection('users').doc(u.uid);
    const docSnap = await userRef.get();

    const email = u.email || '';
    const displayName = u.displayName || (email ? email.split('@')[0] : 'Reminda User');
    const createdAt = u.metadata.creationTime ? new Date(u.metadata.creationTime) : new Date();
    const lastSyncAt = u.metadata.lastSignInTime ? new Date(u.metadata.lastSignInTime) : createdAt;

    const payload = {
      id: u.uid,
      displayName,
      email,
      photoUrl: u.photoURL || null,
      createdAt,
      lastSyncAt,
      lastActive: lastSyncAt,
      platform: 'Mobile (Android)',
      status: 'active'
    };

    if (!docSnap.exists) {
      await userRef.set(payload);
      createdCount++;
      console.log(`  + Created user: ${displayName} (${email}) [Registered: ${createdAt.toISOString().slice(0, 10)}]`);
    } else {
      // Merge in lastActive/createdAt if missing
      await userRef.set(payload, { merge: true });
      updatedCount++;
      console.log(`  ~ Updated user: ${displayName} (${email})`);
    }
  }

  console.log(`User sync complete: ${createdCount} created, ${updatedCount} verified/updated. Total users now in Firestore: ${authUsers.length}`);
}

async function restoreSchoolLogos() {
  console.log('\n--- 2. RESTORING & LINKING SCHOOL LOGOS IN FIRESTORE ---');
  const logosDir = path.join(__dirname, '../../assets/logos');
  const logoFiles = fs.readdirSync(logosDir);
  console.log(`Found ${logoFiles.length} logo files in assets/logos.`);

  const instSnap = await db.collection('institutions').get();
  console.log(`Found ${instSnap.size} institutions in Firestore (default).`);

  // Build lookup index: normalize string -> doc
  const docsList = [];
  instSnap.forEach(d => {
    docsList.push({ id: d.id, ...d.data(), docRef: d.ref });
  });

  function cleanStr(s) {
    return (s || '').toLowerCase().replace(/[^a-z0-9]/g, ' ').replace(/\s+/g, ' ').trim();
  }

  // Pre-mapped logo rules for common abbreviations and specific files
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
    const docClean = cleanStr(doc.name + ' ' + (doc.shortName || ''));
    let matchedLogo = null;

    // 1. Check manual rules
    for (const [file, keywords] of Object.entries(manualFileMap)) {
      for (const kw of keywords) {
        if (docClean.includes(kw)) {
          matchedLogo = file;
          break;
        }
      }
      if (matchedLogo) break;
    }

    // 2. Check direct file name match if not matched
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

  // Also sync codebase_institutions.json locally
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
    await syncAuthUsers();
    await restoreSchoolLogos();
    console.log('\nAll backend fixes completed successfully!');
    process.exit(0);
  } catch (err) {
    console.error('\nError running backend fix:', err);
    process.exit(1);
  }
}

main();
