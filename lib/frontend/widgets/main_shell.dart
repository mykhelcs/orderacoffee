import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:orderacoffee/frontend/theme/theme.dart';
import 'package:orderacoffee/frontend/features/auth/auth_provider.dart';
import 'package:orderacoffee/frontend/features/cart/cart_provider.dart';
import 'app_logo.dart';

/// Provider for toggling between Light and Dark mode.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

class MainShell extends ConsumerWidget {
  const MainShell({
    super.key,
    required this.child,
  });

  final Widget child;

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == '/') return 0;
    if (location.startsWith('/cart')) return 1;
    if (location.startsWith('/orders') || location.startsWith('/order')) return 2;
    if (location.startsWith('/profile')) return 3;
    if (location.startsWith('/admin')) return 4;
    return -1;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/cart');
        break;
      case 2:
        context.go('/orders');
        break;
      case 3:
        context.go('/profile');
        break;
      case 4:
        context.go('/admin');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgCol = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;
    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;
    final brandCol = isDark ? AppColors.brandDark : AppColors.brandLight;

    final cartItemCount = ref.watch(cartProvider).itemCount;
    final selectedIndex = _calculateSelectedIndex(context);
    final currentThemeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authProvider);
    final isStaff = authState.isAdmin || authState.profile?.role == 'staff';

    return Scaffold(
      backgroundColor: bgCol,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header: Logo + Theme toggle pill
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppLogo(showSubtitle: false),
                  InkWell(
                    onTap: () {
                      ref.read(themeModeProvider.notifier).state =
                          currentThemeMode == ThemeMode.light
                              ? ThemeMode.dark
                              : ThemeMode.light;
                    },
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: lineCol),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                            size: 15,
                            color: brandCol,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isDark ? 'Light' : 'Espresso',
                            style: GoogleFonts.figtree(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: inkCol,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body Content
            Expanded(child: child),
            // Bottom Navigation
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(top: BorderSide(color: lineCol)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _NavBarItem(
                    label: 'Menu',
                    icon: Icons.coffee_rounded,
                    isSelected: selectedIndex == 0,
                    selectedColor: brandCol,
                    unselectedColor: muteCol,
                    onTap: () => _onItemTapped(0, context),
                  ),
                  _NavBarItem(
                    label: 'Cart',
                    icon: Icons.shopping_bag_outlined,
                    isSelected: selectedIndex == 1,
                    selectedColor: brandCol,
                    unselectedColor: muteCol,
                    badgeCount: cartItemCount,
                    onTap: () => _onItemTapped(1, context),
                  ),
                  _NavBarItem(
                    label: 'Orders',
                    icon: Icons.receipt_long_outlined,
                    isSelected: selectedIndex == 2,
                    selectedColor: brandCol,
                    unselectedColor: muteCol,
                    onTap: () => _onItemTapped(2, context),
                  ),
                  _NavBarItem(
                    label: 'Profile',
                    icon: Icons.person_outline_rounded,
                    isSelected: selectedIndex == 3,
                    selectedColor: brandCol,
                    unselectedColor: muteCol,
                    onTap: () => _onItemTapped(3, context),
                  ),
                  if (isStaff)
                    _NavBarItem(
                      label: 'Staff',
                      icon: Icons.dashboard_outlined,
                      isSelected: selectedIndex == 4,
                      selectedColor: brandCol,
                      unselectedColor: muteCol,
                      onTap: () => _onItemTapped(4, context),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? selectedColor : unselectedColor;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: GoogleFonts.figtree(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: color,
                      ),
                    ),
                  ],
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -2,
                    right: 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bad,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
