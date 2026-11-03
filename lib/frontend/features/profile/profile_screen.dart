import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:orderacoffee/frontend/theme/theme.dart';
import 'package:orderacoffee/frontend/widgets/main_shell.dart';
import '../auth/auth_provider.dart';

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
              style: GoogleFonts.figtree(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A3825),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

    final displayName = (profile?.name.isNotEmpty == true) ? profile!.name : 'Coffee Lover';
    final displayEmail = (profile?.email.isNotEmpty == true) ? profile!.email : 'guest@cafego.com';
    final displayPhone = (profile?.phone.isNotEmpty == true) ? profile!.phone : '+63 912 345 6789';

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
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7A4A2F), Color(0xFF3B2317)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B2317).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFF7F1EB),
                    ),
                  ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD49755).withValues(alpha: 0.2),
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
            ],
          ),
        ),

        const SizedBox(height: 16),

        // CafeGO Comfort Club Rewards Card
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD49755),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '320 Pts',
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
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: 0.75,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD49755)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '80 pts to free beverage',
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      color: const Color(0xFFD4C8C2),
                    ),
                  ),
                  Text(
                    '400 pts goal',
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFF7F1EB),
                    ),
                  ),
                ],
              ),
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
                subtitle: 'Custom drinks & pastries',
                onTap: () => context.go('/'),
              ),
              Divider(height: 1, indent: 56, endIndent: 20, color: lineCol),
              _ProfileTile(
                icon: Icons.location_on_outlined,
                title: 'Delivery Addresses',
                subtitle: 'Saved home & office spots',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delivery addresses managed at checkout')),
                  );
                },
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
                onTap: () {},
              ),
              Divider(height: 1, indent: 56, endIndent: 20, color: lineCol),
              _ProfileTile(
                icon: Icons.storefront_outlined,
                title: 'CafeGO Store Locator',
                subtitle: 'Find your nearest branch',
                onTap: () {},
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
            side: BorderSide(color: const Color(0xFFD6336C).withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),

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
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: muteCol, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
