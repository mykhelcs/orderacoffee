/// Firebase Test Account Setup Script
/// Run with: dart scripts/setup_test_accounts.dart
/// 
/// This script sets up test accounts for RBAC testing:
/// - Admin: admin@cafego.ph
/// - Staff: staff@cafego.ph  
/// - Driver: driver@cafego.ph
/// - Customer: customer@cafego.ph

import 'dart:io';

void main(List<String> arguments) {
  print('========================================');
  print('CafeGO Firebase Test Account Setup');
  print('========================================\n');

  print('To set up test accounts, you need to use the Firebase Console or call Firebase Auth API.');
  print('\nHere are the credentials to create:\n');

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
    print('📋 ${account['role'].toString().toUpperCase()} Account');
    print('   Email: ${account['email']}');
    print('   Password: ${account['password']}');
    print('   Name: ${account['name']}');
    print('   Phone: ${account['phone']}');
    if (account['role'] == 'driver') {
      print('   Vehicle Type: ${account['vehicleType']}');
      print('   Vehicle Number: ${account['vehicleNumber']}');
    }
    print('');
  }

  print('========================================');
  print('SETUP INSTRUCTIONS:');
  print('========================================\n');

  print('Option 1: Use Firebase Console');
  print('1. Go to Firebase Console > Authentication');
  print('2. Create each user with the credentials above');
  print('3. Set their role in the users Firestore collection\n');

  print('Option 2: Use Firebase CLI (Recommended)');
  print('1. Export existing users:');
  print('   firebase auth:export --project coughfee-app users.json\n');

  print('2. Import test users:');
  print('   firebase auth:import users.json --project coughfee-app\n');

  print('Option 3: Use App Registration Flow');
  print('1. Open the app at: https://mykhelcs.github.io/orderacoffee/');
  print('2. Click "Sign Up"');
  print('3. Create each account with the credentials above');
  print('4. Manually update role in Firebase Console\n');

  print('========================================');
  print('\nAfter creating accounts, the following Firestore users collection should exist:\n');

  for (final account in testAccounts) {
    print('📁 /users/{uid}');
    print('   name: "${account['name']}"');
    print('   email: "${account['email']}"');
    print('   phone: "${account['phone']}"');
    print('   role: "${account['role']}"');
    print('   isEmailVerified: true');
    if (account['role'] == 'driver') {
      print('   vehicleType: "${account['vehicleType']}"');
      print('   vehicleNumber: "${account['vehicleNumber']}"');
      print('   isAvailable: false');
      print('   totalDeliveries: 0');
    }
    print('   createdAt: timestamp');
    print('');
  }

  print('========================================');
}
