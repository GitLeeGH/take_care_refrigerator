import '../services/ingredient_recognition.dart';
import '../widgets/ingredient_candidate_review.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ingredient_photo.dart';
import '../widgets/ingredient_photo.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:take_care_refrigerator/src/pages/recipes_page.dart';
import '../providers.dart';
import '../models.dart';
import '../theme.dart';

final ingredientImagePickerProvider =
    Provider<Future<XFile?> Function(ImageSource)>(
      (ref) =>
          (source) => ImagePicker().pickImage(
            source: source,
            maxWidth: 1600,
            maxHeight: 1600,
            imageQuality: 80,
          ),
    );

class DashboardPage extends ConsumerWidget {
  const DashboardPage({
    super.key,
    required this.onInventory,
    required this.onRecipes,
    required this.onNotifications,
  });
  final VoidCallback onInventory;
  final VoidCallback onRecipes;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(ingredientsProvider);
    final recommendations = ref.watch(expiringIngredientsRecipesProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        titleSpacing: 18,
        title: const Text(
          '냉장고를 부탁해',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: '알림',
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
        children: [
          const Text(
            '오늘은 뭐 먹지?',
            style: TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          const Text('냉장고 속 재료로 가볍게 한 끼', style: TextStyle(color: mediumGray)),
          const SizedBox(height: 16),
          Material(
            color: softGreen,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showAddEditIngredientSheet(context, ref, null),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: primaryGreen,
                      size: 32,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '재료 추가하기',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '오늘 장 본 재료를 기록해요',
                            style: TextStyle(color: mediumGray, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: primaryGreen),
                  ],
                ),
              ),
            ),
          ),
          if (inventory.asData?.value case final items?) ...[
            const SizedBox(height: 14),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    Text(
                      '보관 중 ${items.length}개',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '3일 이내 ${items.where((item) => _daysLeft(item) >= 0 && _daysLeft(item) <= 3).length}개',
                    ),
                    Text(
                      '기한 지남 ${items.where((item) => _daysLeft(item) < 0).length}개',
                      style: const TextStyle(color: warningInk),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _SectionHeading('먼저 확인해요', onInventory),
          const SizedBox(height: 8),
          inventory.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(ingredientsProvider),
              child: const Text('재료를 불러오지 못했어요 · 다시 시도'),
            ),
            data: (items) {
              final sorted = [...items]
                ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
              if (sorted.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('재료를 추가하면 소비기한을 함께 챙겨드려요.'),
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in sorted.take(3))
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: IngredientPreview(
                          ingredient: item,
                          onTap: onInventory,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          _SectionHeading('레시피 아이디어', onRecipes),
          const SizedBox(height: 8),
          if (recommendations.isNotEmpty)
            RecipeCard(recipe: recommendations.first, compact: true)
          else
            OutlinedButton.icon(
              onPressed: onRecipes,
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('나에게 맞는 레시피 찾아보기'),
            ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title, this.onTap);
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      IconButton(
        tooltip: '$title 더 보기',
        onPressed: onTap,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

int _daysLeft(Ingredient item) {
  final now = DateTime.now();
  return DateTime(
    item.expiryDate.year,
    item.expiryDate.month,
    item.expiryDate.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
}

class IngredientPreview extends StatelessWidget {
  const IngredientPreview({
    super.key,
    required this.ingredient,
    required this.onTap,
    this.detailed = false,
  });
  final Ingredient ingredient;
  final VoidCallback onTap;
  final bool detailed;
  @override
  Widget build(BuildContext context) {
    final days = _daysLeft(ingredient);
    final status = days < 0
        ? '${-days}일 지남'
        : days == 0
        ? '오늘까지'
        : 'D-$days';
    return Material(
      color: const Color(0xFFFCFAF5),
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: ingredient.imagePath != null
                  ? (detailed ? 94 : 78)
                  : (detailed ? 42 : 36),
              width: double.infinity,
              color: softGreen,
              alignment: Alignment.center,
              child: IngredientPhoto(
                path: ingredient.imagePath,
                fallback: Icon(
                  ingredient.storageType == 'frozen'
                      ? Icons.ac_unit
                      : ingredient.storageType == 'ambient'
                      ? Icons.spa_outlined
                      : Icons.kitchen_outlined,
                  size: ingredient.imagePath == null ? 22 : 32,
                  color: primaryGreen,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ingredient.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (detailed)
                        Flexible(
                          child: Text(
                            ingredient.quantity,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 12,
                              color: mediumGray,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detailed
                        ? '${DateFormat('MM.dd').format(ingredient.expiryDate)} · $status'
                        : status,
                    style: TextStyle(
                      fontSize: 12,
                      color: days <= 2 ? warningInk : mediumGray,
                    ),
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

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int selected = 0;
  String query = '';
  bool searching = false;
  static const labels = ['전체', '냉장', '냉동', '실온'];
  static const storage = ['', 'refrigerated', 'frozen', 'ambient'];
  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(ingredientsProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 54,
        titleSpacing: 18,
        title: const Text('나의 냉장고'),
        actions: [
          IconButton(
            tooltip: '재료 검색',
            onPressed: () => setState(() {
              searching = !searching;
              if (!searching) query = '';
            }),
            icon: Icon(searching ? Icons.close : Icons.search),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
          child: FilledButton.icon(
            onPressed: () => _showAddEditIngredientSheet(
              context,
              ref,
              null,
              storageType: selected == 0 ? 'refrigerated' : storage[selected],
            ),
            icon: const Icon(Icons.add),
            label: const Text('재료 추가'),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('신선함을 한눈에', style: TextStyle(color: mediumGray)),
                if (searching) const SizedBox(height: 8),
                if (searching)
                  TextField(
                    onChanged: (value) =>
                        setState(() => query = value.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: '재료 이름으로 검색',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            showCheckmark: false,
                            selectedColor: primaryGreen,
                            backgroundColor: const Color(0xFFEDEAE2),
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                            labelStyle: TextStyle(
                              color: selected == i ? Colors.white : darkGray,
                            ),
                            label: Text(labels[i]),
                            selected: selected == i,
                            onSelected: (_) => setState(() => selected = i),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Expanded(
            child: inventory.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(ingredientsProvider),
                  child: const Text('재료를 불러오지 못했어요. 다시 시도'),
                ),
              ),
              data: (items) {
                final visible =
                    items
                        .where(
                          (item) =>
                              (selected == 0 ||
                                  item.storageType == storage[selected]) &&
                              item.name.toLowerCase().contains(query),
                        )
                        .toList()
                      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
                if (visible.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '표시할 재료가 없어요.\n다른 보관함을 선택하거나 재료를 추가해 주세요.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          MediaQuery.textScalerOf(context).scale(16) > 24
                          ? 1
                          : 2;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final item in visible)
                            SizedBox(
                              width:
                                  (constraints.maxWidth - 12 * (columns - 1)) /
                                  columns,
                              child: IngredientPreview(
                                ingredient: item,
                                detailed: true,
                                onTap: () => showModalBottomSheet(
                                  context: context,
                                  showDragHandle: true,
                                  builder: (context) => SafeArea(
                                    child: SingleChildScrollView(
                                      child: IngredientTile(ingredient: item),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
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
          const _GroupHeader(title: '먼저 확인해 주세요'),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  IngredientTile(ingredient: urgentItems[index]),
              childCount: urgentItems.length,
            ),
          ),
        ],
        if (warningItems.isNotEmpty) ...[
          const _GroupHeader(title: '이번 주에 사용해요'),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  IngredientTile(ingredient: warningItems[index]),
              childCount: warningItems.length,
            ),
          ),
        ],
        if (safeItems.isNotEmpty) ...[
          const _GroupHeader(title: '여유 있게 보관 중'),
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
      color: softGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.restaurant_outlined, color: primaryGreen),
                SizedBox(width: 8),
                Text(
                  '먼저 꺼내 요리해요',
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
      dDayColor = warningInk; // Orange
    } else {
      dDayText = '${-daysLeft}일 지남';
      dDayColor = dangerInk; // Red
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: warmBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: lightGray,
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

  late final String ingredientId;
  IngredientPhotoDraft? _photo;
  IngredientSaveOperation? _operation;
  bool _busy = false;
  bool _picking = false;
  bool get _locked => _busy || _picking || _operation != null;

  Future<void> _pickPhoto(ImageSource source) async {
    if (_locked) return;
    setState(() => _picking = true);
    try {
      final file = await ref.read(ingredientImagePickerProvider)(source);
      if (file == null) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const FormatException('사진은 5MB 이하여야 합니다.');
      }
      final photo = IngredientPhotoDraft(await file.readAsBytes());
      final codec = await ui.instantiateImageCodec(
        photo.bytes,
        targetWidth: 32,
      );
      codec.dispose();
      if (mounted) setState(() => _photo = photo);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message.toString()
                  : '사진을 가져오지 못했어요. 카메라·사진 권한을 확인하고 다시 시도해 주세요.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _recognizePhoto() async {
    final recognizer = ref.read(ingredientRecognizerProvider);
    if (_locked || _photo == null || !recognizer.available) return;
    setState(() => _picking = true);
    try {
      final candidates = await recognizer.recognize(_photo!);
      if (!mounted) return;
      final confirmed = await showDialog<String>(
        context: context,
        builder: (_) => IngredientCandidateReview(candidates: candidates),
      );
      if (confirmed != null && mounted) {
        // Never change quantity, expiry or storage, and never submit a record.
        setState(() => nameController.text = confirmed);
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인식하지 못했어요. 재료명은 직접 입력할 수 있어요.')),
        );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  bool get isEditing => widget.ingredient != null;

  @override
  void initState() {
    super.initState();
    final ingredient = widget.ingredient;
    ingredientId = ingredient?.id ?? newIngredientUuid();
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
    if (_busy || _picking) return;
    final name = nameController.text.trim();
    final quantity = quantityController.text.trim();
    if (name.isEmpty || quantity.isEmpty) return;

    final user = ref.read(supabaseProvider).auth.currentUser;
    if (user == null) return;

    final data = {
      'id': ingredientId,
      'image_path': widget.ingredient?.imagePath,
      'user_id': user.id,
      'name': name,
      'quantity': quantity,
      'expiry_date': DateFormat('yyyy-MM-dd').format(selectedDate),
      'storage_type': storageType,
      if (!isEditing) 'created_at': DateTime.now().toIso8601String(),
    };

    setState(() => _busy = true);
    try {
      _operation ??= IngredientSaveOperation(
        gateway: SupabaseIngredientPhotoGateway(ref.read(supabaseProvider)),
        data: data,
        editing: isEditing,
        photo: _photo,
        oldPath: widget.ingredient?.imagePath,
      );
      final cleaned = await _operation!.save();
      if (!mounted) return;
      if (!cleaned)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('재료는 저장했지만 이전 사진 정리를 완료하지 못했어요.')),
        );
      if (!isEditing) {
        // --- Start of Crowdsourcing Logic ---
        final shelfLifeMap = ref.read(shelfLifeDataProvider).value ?? {};
        if (!shelfLifeMap.containsKey(name)) {
          final days = selectedDate.difference(DateTime.now()).inDays + 1;
          if (days > 0 && mounted) {
            await showDialog(
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
                      if (context.mounted) Navigator.of(context).pop();
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
      ref.invalidate(ingredientsProvider);

      // 즉시 알림 스케줄러 재실행 (신규 재료의 유통기한 확인)
      ref.invalidate(notificationSchedulerProvider);

      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장 결과를 확인하지 못했어요. 입력 내용은 유지됩니다. 다시 눌러 확인해 주세요.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider here to ensure the data is ready and cached.
    final shelfLifeData = ref.watch(shelfLifeDataProvider);

    return PopScope(
      canPop: !_busy && !_picking,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: max(
            MediaQuery.viewInsetsOf(context).bottom,
            MediaQuery.viewPaddingOf(context).bottom,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                isEditing ? '재료 수정' : '재료 추가',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_photo != null || widget.ingredient?.imagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 144,
                    child: _photo != null
                        ? Image.memory(
                            _photo!.bytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Center(child: Text('사진을 표시할 수 없어요.')),
                          )
                        : IngredientPhoto(
                            path: widget.ingredient?.imagePath,
                            fallback: const Icon(Icons.photo_outlined),
                          ),
                  ),
                ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _locked
                        ? null
                        : () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('사진 촬영'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _locked
                        ? null
                        : () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('사진 선택'),
                  ),
                  if (_photo != null)
                    TextButton(
                      onPressed: _locked
                          ? null
                          : () => setState(() => _photo = null),
                      child: const Text('선택 취소'),
                    ),
                ],
              ),
              if (_photo != null) ...[
                OutlinedButton.icon(
                  onPressed:
                      !_locked &&
                          ref.watch(ingredientRecognizerProvider).available
                      ? _recognizePhoto
                      : null,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(
                    ref.watch(ingredientRecognizerProvider).available
                        ? '재료 인식 후 확인'
                        : '자동 인식 · 연결 준비 중',
                  ),
                ),
                if (!ref.watch(ingredientRecognizerProvider).available)
                  const Text(
                    '현재는 사진을 첨부하고 재료명을 직접 입력해 주세요. 인식 서비스에는 사진을 보내지 않습니다.',
                    style: TextStyle(fontSize: 12, color: mediumGray),
                  ),
              ],
              const Text(
                '사진과 입력한 재료 정보를 함께 저장해요.',
                style: TextStyle(fontSize: 12, color: mediumGray),
              ),
              const SizedBox(height: 24),
              TextField(
                enabled: !_locked,
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
                enabled: !_locked,
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: '수량 (예: 1개, 200g)',
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '보관 방식',
                style: TextStyle(fontSize: 12, color: mediumGray),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in const {
                    'refrigerated': '냉장',
                    'frozen': '냉동',
                    'ambient': '실온',
                  }.entries)
                    ChoiceChip(
                      label: Text(option.value),
                      selected: storageType == option.key,
                      onSelected: _locked
                          ? null
                          : (_) => setState(() => storageType = option.key),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                '유통기한',
                style: TextStyle(fontSize: 12, color: mediumGray),
              ),
              InkWell(
                onTap: _locked
                    ? null
                    : () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365 * 3),
                          ),
                        );
                        if (pickedDate != null && pickedDate != selectedDate) {
                          setState(() => selectedDate = pickedDate);
                        }
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: primaryBlue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          DateFormat('yyyy년 MM월 dd일').format(selectedDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _busy || _picking ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _busy
                      ? '저장 확인 중…'
                      : _operation != null
                      ? '저장 다시 확인'
                      : isEditing
                      ? '수정하기'
                      : '추가하기',
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
        ),
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
      child: SingleChildScrollView(
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
