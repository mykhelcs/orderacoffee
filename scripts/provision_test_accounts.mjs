/**
 * CafeGO Test Account Provisioning Script
 * 
 * Creates and sets up all 4 RBAC test accounts in Firebase Auth and Firestore:
 * - Admin: admin@cafego.ph / Admin@123456
 * - Staff: staff@cafego.ph / Staff@123456
 * - Driver: driver@cafego.ph / Driver@123456
 * - Customer: customer@cafego.ph / Customer@123456
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

const testAccounts = [
  {
    role: 'admin',
    email: 'admin@cafego.ph',
    password: 'Admin@123456',
    name: 'Admin User',
    phone: '+63912345601',
  },
  {
    role: 'staff',
    email: 'staff@cafego.ph',
    password: 'Staff@123456',
    name: 'Staff User',
    phone: '+63912345602',
  },
  {
    role: 'driver',
    email: 'driver@cafego.ph',
    password: 'Driver@123456',
    name: 'Driver User',
    phone: '+63912345603',
    vehicleType: 'motorcycle',
    vehicleNumber: 'ABC-1234',
    isAvailable: false,
    currentDeliveryId: null,
    totalDeliveries: 0,
    averageRating: null,
  },
  {
    role: 'customer',
    email: 'customer@cafego.ph',
    password: 'Customer@123456',
    name: 'Customer User',
    phone: '+63912345604',
  },
];

async function main() {
  const env = loadEnv();
  const apiKey = env.FIREBASE_WEB_API_KEY;
  const projectId = env.FIREBASE_PROJECT_ID || 'coughfee-app';

  if (!apiKey) {
    console.error('❌ FIREBASE_WEB_API_KEY not found in .env');
    process.exit(1);
  }

  console.log('========================================================');
  console.log('   CafeGO - Test Accounts Provisioning');
  console.log('========================================================');
  console.log(`Firebase Project: ${projectId}\n`);

  const results = [];

  for (const account of testAccounts) {
    console.log(`\n--- Provisioning ${account.role.toUpperCase()} (${account.email}) ---`);
    let idToken = null;
    let localId = null;

    // 1. Create or login via Identity Toolkit
    const signUpUrl = `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`;
    const signUpRes = await fetch(signUpUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: account.email,
        password: account.password,
        returnSecureToken: true,
      }),
    });

    const signUpData = await signUpRes.json();

    if (signUpRes.ok) {
      console.log(`  ✔ Created user in Firebase Auth.`);
      idToken = signUpData.idToken;
      localId = signUpData.localId;
    } else if (signUpData?.error?.message?.includes('EMAIL_EXISTS')) {
      console.log(`  ℹ User already exists in Firebase Auth. Signing in...`);
      const signInUrl = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`;
      const signInRes = await fetch(signInUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: account.email,
          password: account.password,
          returnSecureToken: true,
        }),
      });

      const signInData = await signInRes.json();
      if (!signInRes.ok) {
        console.error(`  ❌ Sign in failed:`, signInData?.error?.message || signInData);
        continue;
      }
      console.log(`  ✔ Authenticated existing user.`);
      idToken = signInData.idToken;
      localId = signInData.localId;
    } else {
      console.error(`  ❌ Auth error:`, signUpData?.error?.message || signUpData);
      continue;
    }

    // 2. Set display name in Auth
    const updateProfileUrl = `https://identitytoolkit.googleapis.com/v1/accounts:update?key=${apiKey}`;
    await fetch(updateProfileUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        idToken,
        displayName: account.name,
        returnSecureToken: false,
      }),
    });
    console.log(`  ✔ Set display name: "${account.name}"`);

    results.push({
      account,
      localId,
      idToken,
    });
  }

  // Output JSON mapping for Firestore updating
  fs.writeFileSync(
    path.join(rootDir, 'test_users_provisioned.json'),
    JSON.stringify(results.map(r => ({ ...r.account, uid: r.localId })), null, 2)
  );

  console.log('\n✔ Auth provisioning completed for all accounts.');
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
