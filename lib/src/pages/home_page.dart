import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:take_care_refrigerator/src/pages/recipes_page.dart';
import '../providers.dart';
import '../models.dart';
import '../theme.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(ingredientsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          '내 냉장고',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: darkGray,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.add_circle, color: primaryGreen, size: 32),
              onPressed: () {
                final storageTypes = ['refrigerated', 'frozen', 'ambient'];
                final currentStorageType = storageTypes[_tabController.index];
                _showAddEditIngredientSheet(
                  context,
                  ref,
                  null,
                  storageType: currentStorageType,
                );
              },
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryBlue,
          unselectedLabelColor: mediumGray,
          indicatorColor: primaryBlue,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: '냉장'),
            Tab(text: '냉동'),
            Tab(text: '실온'),
          ],
        ),
      ),
      body: Column(
        children: [
          const ExpiringRecipesSection(),
          Expanded(
            child: ingredientsAsync.when(
              data: (ingredients) {
                final refrigeratedItems = ingredients
                    .where((i) => i.storageType == 'refrigerated')
                    .toList();
                final frozenItems = ingredients
                    .where((i) => i.storageType == 'frozen')
                    .toList();
                final ambientItems = ingredients
                    .where((i) => i.storageType == 'ambient')
                    .toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildIngredientList(
                      refrigeratedItems,
                      ref,
                      'refrigerated',
                    ),
                    _buildIngredientList(frozenItems, ref, 'frozen'),
                    _buildIngredientList(ambientItems, ref, 'ambient'),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientList(
    List<Ingredient> items,
    WidgetRef ref,
    String storageType,
  ) {
    return GroupedIngredientList(
      items: items,
      onAdd: () => _showAddEditIngredientSheet(
        context,
        ref,
        null,
        storageType: storageType,
      ),
    );
  }
}

class GroupedIngredientList extends StatelessWidget {
  final List<Ingredient> items;
  final VoidCallback onAdd;

  const GroupedIngredientList({
    super.key,
    required this.items,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.kitchen_outlined,
        title: '냉장고가 비어있어요',
        message: '첫 재료를 추가하고\n냉장고 관리를 시작해보세요!',
        buttonText: '재료 추가하기',
        onButtonPressed: onAdd,
      );
    }

    final now = DateTime.now();
    final urgentItems = items
        .where((i) => i.expiryDate.difference(now).inDays < 3)
        .toList();
    final warningItems = items
        .where(
          (i) =>
              i.expiryDate.difference(now).inDays >= 3 &&
              i.expiryDate.difference(now).inDays < 7,
        )
        .toList();
    final safeItems = items
        .where((i) => i.expiryDate.difference(now).inDays >= 7)
        .toList();

    return CustomScrollView(
      slivers: [
        if (urgentItems.isNotEmpty) ...[
          const _GroupHeader(title: '🚨 유통기한 임박'),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  IngredientTile(ingredient: urgentItems[index]),
              childCount: urgentItems.length,
            ),
          ),
        ],
        if (warningItems.isNotEmpty) ...[
          const _GroupHeader(title: '⚠️ 주의'),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  IngredientTile(ingredient: warningItems[index]),
              childCount: warningItems.length,
            ),
          ),
        ],
        if (safeItems.isNotEmpty) ...[
          const _GroupHeader(title: '✅ 넉넉함'),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => IngredientTile(ingredient: safeItems[index]),
              childCount: safeItems.length,
            ),
          ),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: darkGray,
          ),
        ),
      ),
    );
  }
}

class ExpiringRecipesSection extends ConsumerWidget {
  const ExpiringRecipesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendedRecipes = ref.watch(expiringIngredientsRecipesProvider);

    if (recommendedRecipes.isEmpty) {
      return const SizedBox.shrink(); // Show nothing if there are no recommendations
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: const Color(0xFFE9ECEF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.whatshot_outlined, color: Colors.redAccent),
                SizedBox(width: 8),
                Text(
                  '유통기한 임박 재료 활용 레시피 💡',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkGray,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180, // Height for the horizontal list
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: recommendedRecipes.length,
              itemBuilder: (context, index) {
                final recipe = recommendedRecipes[index];
                return SizedBox(
                  width: 150, // Width of each card
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RecipeDetailPage(recipe: recipe),
                        ),
                      );
                    },
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child:
                                (recipe.imageUrl != null &&
                                    recipe.imageUrl!.isNotEmpty)
                                ? CachedNetworkImage(
                                    imageUrl: recipe.imageUrl!,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        Shimmer.fromColors(
                                          baseColor: Colors.grey[300]!,
                                          highlightColor: Colors.grey[100]!,
                                          child: Container(color: Colors.white),
                                        ),
                                    errorWidget: (context, url, error) =>
                                        const Center(
                                          child: Icon(
                                            Icons.ramen_dining_outlined,
                                            color: mediumGray,
                                          ),
                                        ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.ramen_dining_outlined,
                                      color: mediumGray,
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              recipe.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class IngredientTile extends ConsumerWidget {
  final Ingredient ingredient;
  const IngredientTile({super.key, required this.ingredient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(
      ingredient.expiryDate.year,
      ingredient.expiryDate.month,
      ingredient.expiryDate.day,
    );

    final daysLeft = expiryDay.difference(today).inDays;

    final totalDuration = expiryDay.difference(ingredient.createdAt).inDays;
    final progress = totalDuration <= 0
        ? 1.0
        : max(0.0, min(1.0, (daysLeft / max(1, totalDuration))));

    final String dDayText;
    final Color dDayColor;

    if (daysLeft > 0) {
      dDayText = 'D-$daysLeft';
      dDayColor = mediumGray;
    } else if (daysLeft == 0) {
      dDayText = '오늘까지';
      dDayColor = const Color(0xFFFFB74D); // Orange
    } else {
      dDayText = '${-daysLeft}일 지남';
      dDayColor = const Color(0xFFE57373); // Red
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFF1F3F5),
            child: Icon(Icons.food_bank_outlined, color: mediumGray),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ingredient.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ExpiryProgressBar(progress: progress, daysLeft: daysLeft),
                    const SizedBox(width: 8),
                    Text(
                      dDayText,
                      style: TextStyle(
                        color: dDayColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () =>
                _showAddEditIngredientSheet(context, ref, ingredient),
            icon: const Icon(Icons.edit_outlined, color: mediumGray, size: 20),
          ),
          IconButton(
            onPressed: () async {
              await ref
                  .read(supabaseProvider)
                  .from('ingredients')
                  .delete()
                  .match({'id': ingredient.id});
              ref.invalidate(ingredientsProvider);
            },
            icon: const Icon(Icons.delete_outline, color: mediumGray, size: 20),
          ),
        ],
      ),
    );
  }
}

class ExpiryProgressBar extends StatelessWidget {
  final double progress;
  final int daysLeft;
  const ExpiryProgressBar({
    super.key,
    required this.progress,
    required this.daysLeft,
  });

  @override
  Widget build(BuildContext context) {
    final Color barColor;
    if (daysLeft < 3) {
      barColor = const Color(0xFFE57373); // Red
    } else if (daysLeft < 7) {
      barColor = const Color(0xFFFFB74D); // Orange
    } else {
      barColor = const Color(0xFF20C997); // Green
    }

    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          backgroundColor: barColor.withOpacity(0.2),
          color: barColor,
        ),
      ),
    );
  }
}

void _showAddEditIngredientSheet(
  BuildContext context,
  WidgetRef ref,
  Ingredient? ingredient, {
  String? storageType,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _AddEditIngredientSheet(
      ingredient: ingredient,
      ref: ref,
      storageType: storageType,
    ),
  );
}

class _AddEditIngredientSheet extends ConsumerStatefulWidget {
  final Ingredient? ingredient;
  final WidgetRef ref; // Pass ref to the stateful widget
  final String? storageType;

  const _AddEditIngredientSheet({
    this.ingredient,
    required this.ref,
    this.storageType,
  });

  @override
  ConsumerState<_AddEditIngredientSheet> createState() =>
      _AddEditIngredientSheetState();
}

class _AddEditIngredientSheetState
    extends ConsumerState<_AddEditIngredientSheet> {
  late final TextEditingController nameController;
  late final TextEditingController quantityController;
  late DateTime selectedDate;
  late String storageType;

  bool get isEditing => widget.ingredient != null;

  @override
  void initState() {
    super.initState();
    final ingredient = widget.ingredient;
    nameController = TextEditingController(text: ingredient?.name);
    quantityController = TextEditingController(text: ingredient?.quantity);
    selectedDate = ingredient?.expiryDate ?? DateTime.now();
    // Prioritize ingredient's storage type, then passed type, then default.
    storageType =
        ingredient?.storageType ?? widget.storageType ?? 'refrigerated';
  }

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = nameController.text.trim();
    final quantity = quantityController.text.trim();
    if (name.isEmpty || quantity.isEmpty) return;

    final user = ref.read(supabaseProvider).auth.currentUser;
    if (user == null) return;

    final data = {
      'user_id': user.id,
      'name': name,
      'quantity': quantity,
      'expiry_date': DateFormat('yyyy-MM-dd').format(selectedDate),
      'storage_type': storageType,
      if (!isEditing) 'created_at': DateTime.now().toIso8601String(),
    };

    try {
      if (isEditing) {
        await ref.read(supabaseProvider).from('ingredients').update(data).match(
          {'id': widget.ingredient!.id},
        );
      } else {
        await ref.read(supabaseProvider).from('ingredients').insert(data);

        // --- Start of Crowdsourcing Logic ---
        final shelfLifeMap = ref.read(shelfLifeDataProvider).value ?? {};
        if (!shelfLifeMap.containsKey(name)) {
          final days = selectedDate.difference(DateTime.now()).inDays + 1;
          if (days > 0 && mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('새로운 재료 정보 저장'),
                content: Text(
                  '\'$name\'의 추천 유통기한을 $days일로 저장할까요?\n다른 사용자들이 유용하게 사용할 수 있습니다.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(supabaseProvider)
                          .from('shelf_life_data')
                          .insert({'name': name, 'days': days});
                      ref.invalidate(shelfLifeDataProvider);
                      if (mounted) Navigator.of(context).pop();
                    },
                    child: const Text('저장'),
                  ),
                ],
              ),
            );
          }
        }
        // --- End of Crowdsourcing Logic ---
      }
      
      // 재료 provider 무효화 (즉시 반영)
      print('🔄 재료 정보 갱신 중...');
      ref.invalidate(ingredientsProvider);
      
      // 즉시 알림 스케줄러 재실행 (신규 재료의 유통기한 확인)
      print('🔔 알림 스케줄러 즉시 재실행 중...');
      ref.invalidate(notificationSchedulerProvider);
      
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider here to ensure the data is ready and cached.
    final shelfLifeData = ref.watch(shelfLifeDataProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            isEditing ? '재료 수정' : '재료 추가',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: '재료명'),
            onChanged: (text) {
              // Use the already watched data. This is more efficient.
              if (shelfLifeData.hasValue) {
                final shelfLifeMap = shelfLifeData.value!;
                if (shelfLifeMap.containsKey(text)) {
                  final days = shelfLifeMap[text]!;
                  setState(() {
                    selectedDate = DateTime.now().add(Duration(days: days));
                  });
                }
              }
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: quantityController,
            decoration: const InputDecoration(labelText: '수량 (예: 1개, 200g)'),
          ),
          const SizedBox(height: 20),
          const Text(
            '보관 방식',
            style: TextStyle(fontSize: 12, color: mediumGray),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: primaryBlue.withOpacity(0.2),
              selectedForegroundColor: primaryBlue,
            ),
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(value: 'refrigerated', label: Text('냉장')),
              ButtonSegment<String>(value: 'frozen', label: Text('냉동')),
              ButtonSegment<String>(value: 'ambient', label: Text('실온')),
            ],
            selected: {storageType},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                storageType = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 20),
          const Text('유통기한', style: TextStyle(fontSize: 12, color: mediumGray)),
          InkWell(
            onTap: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              );
              if (pickedDate != null && pickedDate != selectedDate) {
                setState(() => selectedDate = pickedDate);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, color: primaryBlue),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('yyyy년 MM월 dd일').format(selectedDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isEditing ? '수정하기' : '추가하기',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onButtonPressed;
  final String? buttonText;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.onButtonPressed,
    this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: mediumGray.withOpacity(0.5)),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: darkGray,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: mediumGray,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (onButtonPressed != null && buttonText != null)
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: ElevatedButton.icon(
                  onPressed: onButtonPressed,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(
                    buttonText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
