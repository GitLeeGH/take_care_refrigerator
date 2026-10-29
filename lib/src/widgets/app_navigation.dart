import 'package:flutter/material.dart';

class AppNavigation extends StatelessWidget {
  const AppNavigation({
    super.key,
    required this.index,
    required this.onSelected,
  });
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: index,
    onDestinationSelected: onSelected,
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: '홈',
      ),
      NavigationDestination(
        icon: Icon(Icons.kitchen_outlined),
        selectedIcon: Icon(Icons.kitchen),
        label: '냉장고',
      ),
      NavigationDestination(
        icon: Icon(Icons.restaurant_menu_outlined),
        selectedIcon: Icon(Icons.restaurant_menu),
        label: '레시피',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: '마이',
      ),
    ],
  );
}
