import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/models.dart';
import 'package:take_care_refrigerator/src/providers.dart';

Recipe recipe(String id, List<String> names) => Recipe(
  id: id,
  name: id,
  requiredIngredients: names,
  likeCount: 0,
  createdAt: DateTime(2026),
);

class FixedRecipes extends PaginatedRecipesNotifier {
  @override
  PaginatedRecipesState build() => PaginatedRecipesState(
    recipes: [
      recipe('ready', ['양파', ' 양파 ']),
      recipe('missing', ['양파가루']),
      recipe('unknown', []),
    ],
    hasMore: false,
  );
}

void main() {
  test(
    'can-make filter shares normalized matching and excludes unknown recipes',
    () async {
      final container = ProviderContainer(
        overrides: [
          ingredientsProvider.overrideWith(
            (ref) => Stream.value([
              Ingredient(
                id: '1',
                name: ' 양파 ',
                quantity: '1',
                expiryDate: DateTime.now().add(const Duration(days: 1)),
                storageType: '냉장',
                createdAt: DateTime(2026),
              ),
            ]),
          ),
          paginatedRecipesProvider.overrideWith(FixedRecipes.new),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        filteredPaginatedRecipesProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(ingredientsProvider.future);
      expect(container.read(filteredPaginatedRecipesProvider).length, 3);
      container.read(canMakeFilterProvider.notifier).update(true);
      expect(
        container.read(filteredPaginatedRecipesProvider).map((r) => r.id),
        ['ready'],
      );
    },
  );

  test('expiring recommendations use the same conservative matching', () async {
    final recipes = [
      recipe('match', [' green   onion ']),
      recipe('wrong', ['green pepper']),
    ];
    final container = ProviderContainer(
      overrides: [
        ingredientsProvider.overrideWith(
          (ref) => Stream.value([
            Ingredient(
              id: '1',
              name: 'Green Onion',
              quantity: '1',
              expiryDate: DateTime.now().add(const Duration(days: 1)),
              storageType: '냉장',
              createdAt: DateTime(2026),
            ),
          ]),
        ),
        allRecipesListProvider.overrideWith((ref) async => recipes),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      expiringIngredientsRecipesProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(ingredientsProvider.future);
    await container.read(allRecipesListProvider.future);
    expect(
      container.read(expiringIngredientsRecipesProvider).map((r) => r.id),
      ['match'],
    );
  });
}
