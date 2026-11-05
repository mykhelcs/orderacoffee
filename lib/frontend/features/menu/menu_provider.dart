import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:orderacoffee/backend/seed/seed_menu_data.dart';
import 'package:orderacoffee/backend/models/menu_item.dart';
import 'package:orderacoffee/backend/repositories/menu_repository.dart';
import '../auth/auth_provider.dart';

// ─── Production Repository Provider ──────────────────────────────────────────

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository();
});

// ─── Menu Stream (Customer Visible Items) ────────────────────────────────────

final menuStreamProvider = StreamProvider<List<MenuItem>>((ref) {
  final repo = ref.watch(menuRepositoryProvider);
  repo.seedIfEmpty();
  return repo.watchMenu().map((items) {
    if (items.isEmpty) {
      return kDefaultMenuItems;
    }
    return items;
  }).handleError((_) => kDefaultMenuItems);
});

// ─── All Menu Stream (Admin Catalog including Hidden Items) ──────────────────

final allMenuStreamProvider = StreamProvider<List<MenuItem>>((ref) {
  final repo = ref.watch(menuRepositoryProvider);
  return repo.watchAllMenu().map((items) {
    if (items.isEmpty) {
      return kDefaultMenuItems;
    }
    return items;
  }).handleError((_) => kDefaultMenuItems);
});

// ─── Filter State ────────────────────────────────────────────────────────────

class MenuFilterState {
  const MenuFilterState({this.category = 'All', this.query = ''});

  final String category;
  final String query;

  MenuFilterState copyWith({String? category, String? query}) {
    return MenuFilterState(
      category: category ?? this.category,
      query: query ?? this.query,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MenuFilterState &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          query == other.query;

  @override
  int get hashCode => Object.hash(category, query);
}

class MenuFilterNotifier extends StateNotifier<MenuFilterState> {
  MenuFilterNotifier() : super(const MenuFilterState());

  void setCategory(String cat) => state = state.copyWith(category: cat);
  void setQuery(String q) => state = state.copyWith(query: q);
  void reset() => state = const MenuFilterState();
}

final menuFilterProvider =
    StateNotifierProvider<MenuFilterNotifier, MenuFilterState>(
        (ref) => MenuFilterNotifier());

// ─── Filtered List ───────────────────────────────────────────────────────────

final filteredMenuProvider = Provider<List<MenuItem>>((ref) {
  final menuAsync = ref.watch(menuStreamProvider);
  final items = menuAsync.when(
    data: (data) => data.isNotEmpty ? data : kDefaultMenuItems,
    loading: () => kDefaultMenuItems,
    error: (_, __) => kDefaultMenuItems,
  );
  final filter = ref.watch(menuFilterProvider);
  final favorites =
      ref.watch(authProvider).profile?.favorites ?? const <String>[];

  return items.where((item) {
    final bool catOk;
    if (filter.category == 'All') {
      catOk = true;
    } else if (filter.category == 'Favorites') {
      catOk = favorites.contains(item.id);
    } else {
      catOk = item.category == filter.category;
    }

    final q = filter.query.toLowerCase();
    final qOk = q.isEmpty ||
        item.name.toLowerCase().contains(q) ||
        item.category.toLowerCase().contains(q) ||
        item.description.toLowerCase().contains(q);
    return catOk && qOk;
  }).toList();
});
