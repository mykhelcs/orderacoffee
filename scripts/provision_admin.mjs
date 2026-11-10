/**
 * Admin Account Provisioning Script for CafeGo (COUGHFEE)
 *
 * Securely provisions the administrator account in Firebase Authentication
 * and Cloud Firestore using credentials loaded from `.env`.
 *
 * Usage:
 *   node scripts/provision_admin.mjs
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const envPath = path.join(rootDir, '.env');

function loadEnv() {
  if (!fs.existsSync(envPath)) {
    console.error('❌ Error: .env file not found at:', envPath);
    console.error('Please copy .env.example to .env and set your credentials.');
    process.exit(1);
  }

  const content = fs.readFileSync(envPath, 'utf8');
  const env = {};
  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx !== -1) {
      const key = trimmed.slice(0, eqIdx).trim();
      let val = trimmed.slice(eqIdx + 1).trim();
      if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
        val = val.slice(1, -1);
      }
      env[key] = val;
    }
  }
  return env;
}

async function provisionAdmin() {
  const env = loadEnv();

  const apiKey = env.FIREBASE_WEB_API_KEY;
  const projectId = env.FIREBASE_PROJECT_ID || 'coughfee-app';
  const adminEmail = env.ADMIN_EMAIL;
  const adminPassword = env.ADMIN_PASSWORD;
  const adminName = env.ADMIN_NAME || 'Admin Staff';
  const adminPhone = env.ADMIN_PHONE || '+639123456789';

  console.log('========================================================');
  console.log('   CafeGo / COUGHFEE - Admin Provisioning Tool');
  console.log('========================================================');
  console.log(`• Firebase Project : ${projectId}`);
  console.log(`• Admin Email      : ${adminEmail || '(not set)'}`);

  if (!apiKey) {
    console.error('❌ Missing FIREBASE_WEB_API_KEY in .env');
    process.exit(1);
  }

  if (!adminEmail || !adminPassword) {
    console.error('❌ Missing ADMIN_EMAIL or ADMIN_PASSWORD in .env');
    console.error('Please configure ADMIN_EMAIL and ADMIN_PASSWORD in your .env file.');
    process.exit(1);
  }

  let idToken = null;
  let localId = null;

  // 1. Try to create the admin user via Identity Toolkit REST API
  console.log('\n[1/3] Checking admin account in Firebase Authentication...');
  const signUpUrl = `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`;
  const signUpRes = await fetch(signUpUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: adminEmail,
      password: adminPassword,
      returnSecureToken: true,
    }),
  });

  const signUpData = await signUpRes.json();

  if (signUpRes.ok) {
    console.log('  ✔ Created new admin user in Firebase Authentication.');
    idToken = signUpData.idToken;
    localId = signUpData.localId;
  } else if (signUpData?.error?.message?.includes('EMAIL_EXISTS')) {
    console.log('  ℹ Admin user already exists. Authenticating with configured password...');
    const signInUrl = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`;
    const signInRes = await fetch(signInUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: adminEmail,
        password: adminPassword,
        returnSecureToken: true,
      }),
    });

    const signInData = await signInRes.json();
    if (!signInRes.ok) {
      console.error('  ❌ Authentication failed:', signInData?.error?.message || signInData);
      console.error('  If you changed the admin password in .env, verify it matches the existing account.');
      process.exit(1);
    }
    console.log('  ✔ Successfully authenticated existing admin account.');
    idToken = signInData.idToken;
    localId = signInData.localId;
  } else {
    console.error('  ❌ Firebase Auth error:', signUpData?.error?.message || signUpData);
    process.exit(1);
  }

  // 2. Update display name in Firebase Auth
  console.log('\n[2/3] Updating Firebase Auth profile metadata...');
  const updateProfileUrl = `https://identitytoolkit.googleapis.com/v1/accounts:update?key=${apiKey}`;
  await fetch(updateProfileUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      idToken,
      displayName: adminName,
      returnSecureToken: false,
    }),
  });
  console.log(`  ✔ Display name set to: "${adminName}"`);

  // 3. Upsert Firestore document at /users/{localId} with role: 'admin'
  console.log('\n[3/3] Provisioning admin profile in Cloud Firestore...');
  const firestoreUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${localId}`;
  
  const firestorePayload = {
    fields: {
      uid: { stringValue: localId },
      email: { stringValue: adminEmail },
      name: { stringValue: adminName },
      phone: { stringValue: adminPhone },
      role: { stringValue: 'admin' },
      isEmailVerified: { booleanValue: true },
      stamps: { integerValue: '0' },
      favorites: { arrayValue: { values: [] } },
      addresses: { arrayValue: { values: [] } },
      updatedAt: { timestampValue: new Date().toISOString() },
    },
  };

  const fsRes = await fetch(firestoreUrl, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${idToken}`,
    },
    body: JSON.stringify(firestorePayload),
  });

  const fsData = await fsRes.json();
  if (!fsRes.ok) {
    console.error('  ❌ Firestore update failed:', fsData?.error?.message || fsData);
    process.exit(1);
  }

  console.log('  ✔ Firestore document /users/' + localId + ' updated with role: "admin"');

  console.log('\n========================================================');
  console.log('   🎉 Admin Account Provisioned Successfully!');
  console.log('========================================================');
  console.log(`  • UID   : ${localId}`);
  console.log(`  • Email : ${adminEmail}`);
  console.log(`  • Role  : admin`);
  console.log(`  • Path  : /users/${localId}`);
  console.log('========================================================\n');
}

provisionAdmin().catch((err) => {
  console.error('Unexpected error:', err);
  process.exit(1);
});
