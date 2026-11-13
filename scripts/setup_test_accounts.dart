// Firebase Test Account Setup Script
// Run with: dart scripts/setup_test_accounts.dart
//
// This script sets up test accounts for RBAC testing:
// - Admin: admin@cafego.ph
// - Staff: staff@cafego.ph
// - Driver: driver@cafego.ph
// - Customer: customer@cafego.ph

import 'dart:io';

void main(List<String> arguments) {
  stdout.writeln('========================================');
  stdout.writeln('CafeGO Firebase Test Account Setup');
  stdout.writeln('========================================\n');

  stdout.writeln('To set up test accounts, you need to use the Firebase Console or call Firebase Auth API.');
  stdout.writeln('\nHere are the credentials to create:\n');

  // Test Account Credentials
  final testAccounts = [
    {
      'email': 'admin@cafego.ph',
      'password': 'Admin@123456',
      'role': 'admin',
      'name': 'Admin User',
      'phone': '+63912345601',
    },
    {
      'email': 'staff@cafego.ph',
      'password': 'Staff@123456',
      'role': 'staff',
      'name': 'Staff User',
      'phone': '+63912345602',
    },
    {
      'email': 'driver@cafego.ph',
      'password': 'Driver@123456',
      'role': 'driver',
      'name': 'Driver User',
      'phone': '+63912345603',
      'vehicleType': 'motorcycle',
      'vehicleNumber': 'ABC-1234',
    },
    {
      'email': 'customer@cafego.ph',
      'password': 'Customer@123456',
      'role': 'customer',
      'name': 'Customer User',
      'phone': '+63912345604',
    },
  ];

  for (final account in testAccounts) {
    stdout.writeln('📋 ${account['role'].toString().toUpperCase()} Account');
    stdout.writeln('   Email: ${account['email']}');
    stdout.writeln('   Password: ${account['password']}');
    stdout.writeln('   Name: ${account['name']}');
    stdout.writeln('   Phone: ${account['phone']}');
    if (account['role'] == 'driver') {
      stdout.writeln('   Vehicle Type: ${account['vehicleType']}');
      stdout.writeln('   Vehicle Number: ${account['vehicleNumber']}');
    }
    stdout.writeln('');
  }

  stdout.writeln('========================================');
  stdout.writeln('SETUP INSTRUCTIONS:');
  stdout.writeln('========================================\n');

  stdout.writeln('Option 1: Use Firebase Console');
  stdout.writeln('1. Go to Firebase Console > Authentication');
  stdout.writeln('2. Create each user with the credentials above');
  stdout.writeln('3. Set their role in the users Firestore collection\n');

  stdout.writeln('Option 2: Use Firebase CLI (Recommended)');
  stdout.writeln('1. Export existing users:');
  stdout.writeln('   firebase auth:export --project coughfee-app users.json\n');

  stdout.writeln('2. Import test users:');
  stdout.writeln('   firebase auth:import users.json --project coughfee-app\n');

  stdout.writeln('Option 3: Use App Registration Flow');
  stdout.writeln('1. Open the app at: https://mykhelcs.github.io/orderacoffee/');
  stdout.writeln('2. Click "Sign Up"');
  stdout.writeln('3. Create each account with the credentials above');
  stdout.writeln('4. Manually update role in Firebase Console\n');

  stdout.writeln('========================================');
  stdout.writeln('\nAfter creating accounts, the following Firestore users collection should exist:\n');

  for (final account in testAccounts) {
    stdout.writeln('📁 /users/{uid}');
    stdout.writeln('   name: "${account['name']}"');
    stdout.writeln('   email: "${account['email']}"');
    stdout.writeln('   phone: "${account['phone']}"');
    stdout.writeln('   role: "${account['role']}"');
    stdout.writeln('   isEmailVerified: true');
    if (account['role'] == 'driver') {
      stdout.writeln('   vehicleType: "${account['vehicleType']}"');
      stdout.writeln('   vehicleNumber: "${account['vehicleNumber']}"');
      stdout.writeln('   isAvailable: false');
      stdout.writeln('   totalDeliveries: 0');
    }
    stdout.writeln('   createdAt: timestamp');
    stdout.writeln('');
  }

  stdout.writeln('========================================');
}
