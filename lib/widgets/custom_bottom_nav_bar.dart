import 'package:flutter/material.dart';
import '../theme_provider.dart';
import '../language_provider.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);

    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: theme.cardColor,
      elevation: 10,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            // --- العناصر على اليسار ---
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                    icon: Icons.receipt_long_outlined,
                    selectedIcon: Icons.receipt_long,
                    label: context.translate('Bookings'),
                    index: 2,
                    isDark: isDark,
                  ),
                  _buildNavItem(
                    icon: Icons.favorite_border_outlined,
                    selectedIcon: Icons.favorite,
                    label: context.translate('Saved'),
                    index: 1,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            // مساحة فارغة للزر العائم في المنتصف
            const SizedBox(width: 60),
            //  --- العناصر على اليمين ---
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                    icon: Icons.account_balance_wallet_outlined,
                    selectedIcon: Icons.account_balance_wallet,
                    label: context.translate('Wallet'),
                    index: 3,
                    isDark: isDark,
                  ),
                  _buildNavItem(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: context.translate('Account'),
                    index: 4,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required bool isDark,
  }) {
    final isSelected = currentIndex == index;
    final color = isSelected
        ? const Color(0xFF1E88E5)
        : (isDark ? Colors.grey[400] : Colors.grey[600]);

    return InkWell(
      onTap: () => onTap(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isSelected ? selectedIcon : icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class CustomFabLocation extends FloatingActionButtonLocation {
  final FloatingActionButtonLocation location;
  final double offsetY;

  const CustomFabLocation(this.location, {this.offsetY = 0});

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    Offset originalOffset = location.getOffset(scaffoldGeometry);
    return Offset(originalOffset.dx, originalOffset.dy + offsetY);
  }
}
