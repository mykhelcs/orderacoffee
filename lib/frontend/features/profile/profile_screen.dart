import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import 'package:orderacoffee/backend/models/user_profile.dart';
import 'package:orderacoffee/backend/services/location_service.dart';
import 'package:orderacoffee/frontend/theme/theme.dart';
import 'package:orderacoffee/frontend/widgets/brand_button.dart';
import 'package:orderacoffee/frontend/widgets/live_order_map.dart';
import 'package:orderacoffee/frontend/widgets/main_shell.dart';
import '../auth/auth_provider.dart';
import '../menu/menu_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of CafeGO?',
          style: GoogleFonts.figtree(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.figtree(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A3825),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: Text(
              'Sign Out',
              style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Account',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.bad,
          ),
        ),
        content: Text(
          'This will permanently delete your CafeGO profile, saved addresses, and loyalty stamps. Continue?',
          style: GoogleFonts.figtree(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bad,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).deleteAccount();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  void _showImagePickerSheet(BuildContext context, WidgetRef ref) {
    final picker = ImagePicker();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: Text(
                    'Take Photo',
                    style: GoogleFonts.figtree(fontWeight: FontWeight.w600),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final photo = await picker.pickImage(
                        source: ImageSource.camera,
                        maxWidth: 800,
                        maxHeight: 800,
                        imageQuality: 85,
                      );
                      if (photo != null) {
                        await ref
                            .read(authProvider.notifier)
                            .uploadProfilePhoto(photo);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile photo updated!'),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update photo: $e')),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(
                    'Choose from Gallery',
                    style: GoogleFonts.figtree(fontWeight: FontWeight.w600),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final photo = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 800,
                        maxHeight: 800,
                        imageQuality: 85,
                      );
                      if (photo != null) {
                        await ref
                            .read(authProvider.notifier)
                            .uploadProfilePhoto(photo);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile photo updated!'),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update photo: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditProfileSheet(
    BuildContext context,
    WidgetRef ref,
    String initialName,
    String initialPhone,
  ) {
    final nameCtrl = TextEditingController(text: initialName);
    final phoneCtrl = TextEditingController(text: initialPhone);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Profile',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 20),
              BrandButton(
                label: 'Save Changes',
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final phone = phoneCtrl.text.trim();
                  if (name.isEmpty) return;
                  await ref
                      .read(authProvider.notifier)
                      .updateProfileDetails(name: name, phone: phone);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile updated!')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddressesSheet(BuildContext context, WidgetRef ref) {
    final labelCtrl = TextEditingController(text: 'Home');
    final addrCtrl = TextEditingController();
    LatLng pinnedCoords = LocationService.defaultCustomerCoordinates;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Consumer(
              builder: (ctx, modalRef, _) {
                final addresses =
                    modalRef.watch(authProvider).profile?.addresses ?? [];
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    MediaQuery.of(ctx).viewInsets.bottom + 24,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Addresses',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (addresses.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No saved addresses yet. Add your home or office below.',
                              style: GoogleFonts.figtree(fontSize: 13),
                            ),
                          )
                        else
                          ...addresses.map(
                            (addr) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.location_on_rounded),
                              title: Text(
                                addr.label,
                                style: GoogleFonts.figtree(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(addr.addressLine),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.bad,
                                ),
                                onPressed: () {
                                  modalRef
                                      .read(authProvider.notifier)
                                      .removeDeliveryAddress(addr);
                                },
                              ),
                            ),
                          ),
                        const Divider(height: 24),
                        Text(
                          'Add New Address',
                          style: GoogleFonts.figtree(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: labelCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Label (Home/Office)',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 4,
                              child: TextField(
                                controller: addrCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Street / Building / Unit',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LiveOrderMap(
                          height: 170,
                          branchLocation:
                              LocationService.defaultBranch.coordinates,
                          branchName: LocationService.defaultBranch.name,
                          customerLocation: pinnedCoords,
                          onLocationPicked: (latLng) {
                            setModalState(() => pinnedCoords = latLng);
                          },
                          onUseMyLocation: () async {
                            final gps = await const LocationService()
                                .getCurrentLocation();
                            setModalState(() => pinnedCoords = gps);
                          },
                        ),
                        const SizedBox(height: 14),
                        BrandButton(
                          label: 'Save Address',
                          onPressed: () async {
                            final line = addrCtrl.text.trim();
                            if (line.isEmpty) return;
                            final newAddr = UserAddress(
                              id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
                              label: labelCtrl.text.trim().isEmpty
                                  ? 'Home'
                                  : labelCtrl.text.trim(),
                              line1: line,
                              city: 'Metro Manila',
                              lat: pinnedCoords.latitude,
                              lng: pinnedCoords.longitude,
                            );
                            await modalRef
                                .read(authProvider.notifier)
                                .addDeliveryAddress(newAddr);
                            addrCtrl.clear();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showStoreLocatorSheet(BuildContext context) {
    CafeBranch selected = kCafeBranches.first;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CafeGO Store Locator',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LiveOrderMap(
                    height: 200,
                    branchLocation: selected.coordinates,
                    branchName: selected.name,
                  ),
                  const SizedBox(height: 12),
                  ...kCafeBranches.map(
                    (branch) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.storefront_rounded,
                        color: branch.id == selected.id
                            ? AppColors.crema
                            : null,
                      ),
                      title: Text(
                        branch.name,
                        style: GoogleFonts.figtree(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text('${branch.address} • ${branch.hours}'),
                      onTap: () => setModalState(() => selected = branch),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showHelpFaqSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Help & FAQ',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('How do CafeGO Comfort Club stamps work?'),
                subtitle: Text(
                  'Earn 1 stamp per order. Collect 8 stamps to redeem a Free Handcrafted Drink (up to ₱ 140 off) at checkout!',
                ),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('What payment methods are supported?'),
                subtitle: Text(
                  'We support GCash, Maya, and Credit/Debit Cards via PayMongo, plus Cash on Delivery and Pay at Counter.',
                ),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('How much is delivery?'),
                subtitle: Text(
                  'Standard delivery is ₱ 45 and automatically FREE on orders ₱ 500 and above.',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final profile = authState.profile;

    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;
    final brandCol = isDark ? AppColors.brandDark : AppColors.brandLight;
    final currentThemeMode = ref.watch(themeModeProvider);

    final displayName =
        (profile?.name.isNotEmpty == true) ? profile!.name : 'Coffee Lover';
    final displayEmail = (profile?.email.isNotEmpty == true)
        ? profile!.email
        : 'guest@cafego.com';
    final displayPhone = (profile?.phone.isNotEmpty == true)
        ? profile!.phone
        : '+63 912 345 6789';

    final stamps = profile?.stamps ?? 0;
    final stampProgress = (stamps / 8).clamp(0.0, 1.0);
    final stampsRemaining = (8 - stamps).clamp(0, 8);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        // User Profile Header Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: lineCol),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with Photo / Initials & Picker Trigger
              GestureDetector(
                onTap: () => _showImagePickerSheet(context, ref),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7A4A2F), Color(0xFF3B2317)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B2317)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: (profile?.photoUrl != null &&
                              profile!.photoUrl!.isNotEmpty)
                          ? Image.network(
                              profile.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : 'C',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFF7F1EB),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'C',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFF7F1EB),
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD49755),
                          shape: BoxShape.circle,
                          border: Border.all(color: cardBg, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 13,
                          color: Color(0xFF1B110B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // User Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: inkCol,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFD49755).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'Gold Member',
                            style: GoogleFonts.figtree(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFD49755),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayEmail,
                      style: GoogleFonts.figtree(
                        fontSize: 13,
                        color: muteCol,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayPhone,
                      style: GoogleFonts.figtree(
                        fontSize: 12,
                        color: muteCol,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit Profile',
                onPressed: () => _showEditProfileSheet(
                  context,
                  ref,
                  displayName,
                  displayPhone,
                ),
                icon: Icon(Icons.edit_outlined, color: muteCol, size: 20),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // CafeGO Comfort Club Rewards Card (Connected to LoyaltyRepository)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF382319), Color(0xFF231610)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF231610).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CafeGO Comfort Club',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF7F1EB),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your Daily Rewards Tier',
                        style: GoogleFonts.figtree(
                          fontSize: 12,
                          color: const Color(0xFFD4C8C2),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD49755),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$stamps / 8 Stamps',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1B110B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Animated progress bar
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: stampProgress),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 7,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Color(0xFFD49755)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    stampsRemaining == 0
                        ? 'Free drink reward unlocked!'
                        : '$stampsRemaining more stamps to free beverage',
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      color: const Color(0xFFD4C8C2),
                    ),
                  ),
                  Text(
                    '8 stamps goal',
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFF7F1EB),
                    ),
                  ),
                ],
              ),
              if (stamps == 4) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD49755).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFD49755).withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.military_tech_rounded,
                        color: Color(0xFFD49755),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Milestone Reached! 4 stamps down, 4 to go for a free drink! 🎉',
                          style: GoogleFonts.figtree(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFF7F1EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (authState.activeRewardCode != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Active Reward Code: ${authState.activeRewardCode}',
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD49755),
                    ),
                  ),
                ),
              ] else if (stamps >= 8) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD49755),
                      foregroundColor: const Color(0xFF1B110B),
                    ),
                    onPressed: () async {
                      final code =
                          await ref.read(authProvider.notifier).redeemStamps();
                      if (code.isNotEmpty && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Reward unlocked! Code: $code'),
                          ),
                        );
                      }
                    },
                    child: const Text('Redeem Free Drink (8 Stamps)'),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Settings & Options Section
        Text(
          'Account & Preferences',
          style: GoogleFonts.playfairDisplay(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: inkCol,
          ),
        ),
        const SizedBox(height: 12),

        Material(
          color: cardBg,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: lineCol),
          ),
          child: Column(
            children: [
              _ProfileTile(
                icon: Icons.coffee_outlined,
                title: 'Order History',
                subtitle: 'View recent brews & reorder',
                onTap: () => context.go('/orders'),
              ),
              Divider(height: 1, indent: 56, endIndent: 20, color: lineCol),
              _ProfileTile(
                icon: Icons.favorite_border_rounded,
                title: 'My Favorites',
                subtitle: 'Custom drinks & pastries (${profile?.favorites.length ?? 0})',
                onTap: () {
                  ref.read(menuFilterProvider.notifier).setCategory('Favorites');
                  context.go('/');
                },
              ),
              Divider(height: 1, indent: 56, endIndent: 20, color: lineCol),
              _ProfileTile(
                icon: Icons.location_on_outlined,
                title: 'Delivery Addresses',
                subtitle: 'Saved home & office spots',
                onTap: () => _showAddressesSheet(context, ref),
              ),
              Divider(height: 1, indent: 56, endIndent: 20, color: lineCol),
              _ProfileTile(
                icon: Icons.brightness_6_outlined,
                title: 'Appearance',
                subtitle: isDark ? 'Espresso Dark Mode' : 'Creamy Light Mode',
                trailing: Switch(
                  value: isDark,
                  activeThumbColor: brandCol,
                  onChanged: (val) {
                    ref.read(themeModeProvider.notifier).state =
                        val ? ThemeMode.dark : ThemeMode.light;
                  },
                ),
                onTap: () {
                  ref.read(themeModeProvider.notifier).state =
                      currentThemeMode == ThemeMode.light
                          ? ThemeMode.dark
                          : ThemeMode.light;
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Support & About
        Text(
          'More',
          style: GoogleFonts.playfairDisplay(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: inkCol,
          ),
        ),
        const SizedBox(height: 12),

        Material(
          color: cardBg,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: lineCol),
          ),
          child: Column(
            children: [
              _ProfileTile(
                icon: Icons.help_outline_rounded,
                title: 'Help & FAQ',
                subtitle: 'Questions about ordering and rewards',
                onTap: () => _showHelpFaqSheet(context),
              ),
              Divider(height: 1, indent: 56, endIndent: 20, color: lineCol),
              _ProfileTile(
                icon: Icons.storefront_outlined,
                title: 'CafeGO Store Locator',
                subtitle: 'Find your nearest branch',
                onTap: () => _showStoreLocatorSheet(context),
              ),
              if (profile?.isAdmin == true || profile?.role == 'staff') ...[
                Divider(height: 1, indent: 56, endIndent: 20, color: lineCol),
                _ProfileTile(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Staff Management',
                  subtitle: 'Orders queue & menu administration',
                  onTap: () => context.go('/admin'),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Sign Out Button
        OutlinedButton.icon(
          onPressed: () => _showSignOutDialog(context, ref),
          icon: const Icon(Icons.logout_rounded, color: Color(0xFFD6336C)),
          label: Text(
            'Sign Out',
            style: GoogleFonts.playfairDisplay(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFD6336C),
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: const Color(0xFFD6336C).withValues(alpha: 0.4),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),

        if (profile != null) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _showDeleteAccountDialog(context, ref),
              child: Text(
                'Delete Account',
                style: GoogleFonts.figtree(
                  fontSize: 12.5,
                  color: muteCol,
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 36),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;

    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFFD4A373) : const Color(0xFF5A3825))
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDark ? const Color(0xFFD4A373) : const Color(0xFF5A3825),
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.figtree(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: inkCol,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.figtree(
          fontSize: 12,
          color: muteCol,
        ),
      ),
      trailing:
          trailing ?? Icon(Icons.chevron_right_rounded, color: muteCol, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
