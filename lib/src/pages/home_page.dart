import '../services/ingredient_ai_gateway.dart';
import '../services/receipt_ai_gateway.dart';
import '../services/receipt_analysis.dart';
import 'ingredient_image_review_page.dart';
import '../widgets/fridge_inventory_visual.dart';
import '../services/ingredient_photos.dart';
import '../widgets/home_curation_section.dart';
import '../widgets/registration_hero.dart';
import '../services/inventory_quantity.dart';
import '../unknown_inventory_provider.dart';
import 'unknown_inventory_page.dart';
import '../services/local_expiry_reminders.dart';
import '../widgets/food_catalog_page.dart';
import '../services/calendar_day.dart';
import '../services/inventory_day.dart';
import '../widgets/app_presentation.dart';
import '../widgets/storage_guidance_dialog.dart';
import '../widgets/ingredient_detail_dialog.dart';
import 'receipt_import_page.dart';
import '../widgets/ingredient_thumbnail.dart';
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

final manualIngredientGatewayProvider = Provider<IngredientPhotoGateway>(
  (ref) => SupabaseIngredientPhotoGateway(ref.watch(supabaseProvider)),
);

final ingredientDeleteProvider =
    Provider<Future<void> Function(String, String)>((ref) {
      final client = ref.watch(supabaseProvider);
      return (id, owner) async {
        if (client.auth.currentUser?.id != owner) {
          throw StateError('Session changed');
        }
        final removed = await guardLocalExpiryInventoryMutation(
          owner,
          () => client
              .from('ingredients')
              .delete()
              .eq('id', id)
              .eq('user_id', owner)
              .select('id'),
        );
        if (removed.length != 1) throw StateError('Delete not confirmed');
      };
    });

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
    this.active = true,
  });
  final VoidCallback onInventory;
  final VoidCallback onRecipes;
  final VoidCallback onNotifications;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(ingredientsProvider);
    void register(ImageSource source) => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptImportPage(initialSource: source),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: pageToolbarHeight(context),
        titleSpacing: pageGutter,
        title: const Row(
          children: [
            Icon(Icons.soup_kitchen_outlined, color: primaryGreen, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '냉장고를 부탁해',
                maxLines: 2,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.8,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '영수증 일괄 등록',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReceiptImportPage()),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: '알림',
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(pageGutter, 12, pageGutter, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: warmBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSectionHeading(
                  '내 냉장고',
                  action: TextButton(
                    onPressed: onInventory,
                    child: const Text('전체 보기'),
                  ),
                ),
                const SizedBox(height: 12),
                inventory.when(
                  skipLoadingOnRefresh: false,
                  skipLoadingOnReload: false,
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('재료를 불러오는 중이에요.'),
                  ),
                  error: (_, _) => TextButton(
                    onPressed: () => ref.invalidate(ingredientsProvider),
                    child: const Text('재료 다시 불러오기'),
                  ),
                  data: (items) {
                    final today = ref.watch(inventoryDayProvider);
                    final useful =
                        items
                            .where(
                              (item) =>
                                  !isExplicitlyEmptyQuantity(item.quantity) &&
                                  _daysLeft(item, today) >= 0,
                            )
                            .toList()
                          ..sort(
                            (a, b) => compareCalendarDates(
                              a.expiryDate,
                              b.expiryDate,
                            ),
                          );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _InventoryOverview(items: items, onTap: onInventory),
                        const SizedBox(height: 20),
                        const Text(
                          '먼저 먹으면 좋아요',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (useful.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              items.isEmpty
                                  ? ref.watch(unknownInventoryEnabledProvider)
                                        ? '날짜가 등록된 재료가 없어요. 기한 미정 재료는 별도 목록에서 확인해 주세요.'
                                        : '아직 등록한 재료가 없어요. 아래에서 첫 재료를 추가해 보세요.'
                                  : items.any(
                                      (item) =>
                                          !isExplicitlyEmptyQuantity(
                                            item.quantity,
                                          ) &&
                                          _daysLeft(item, today) < 0,
                                    )
                                  ? '기한이 지난 재료는 냉장고에서 확인해 주세요.'
                                  : '먼저 쓸 수 있는 재료가 없어요. 냉장고에서 수량과 날짜를 확인해 주세요.',
                              style: const TextStyle(
                                color: mediumGray,
                                height: 1.5,
                              ),
                            ),
                          )
                        else
                          for (var i = 0; i < min(2, useful.length); i++) ...[
                            if (i > 0) const Divider(height: 1),
                            _HomeIngredientRow(
                              ingredient: useful[i],
                              onTap: onInventory,
                            ),
                          ],
                      ],
                    );
                  },
                ),
                const UnknownInventoryEntry(),
              ],
            ),
          ),
          const SizedBox(height: 20),
          RegistrationHero(
            onGallery: () => register(ImageSource.gallery),
            onCamera: () => register(ImageSource.camera),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showAddEditIngredientSheet(context, ref, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('재료 직접 추가하기'),
            ),
          ),
          const SizedBox(height: 12),
          HomeCurationSection(active: active),
          const SizedBox(height: 28),
          const HomeCurationSection.seasonal(),
        ],
      ),
    );
  }
}

class _HomeIngredientRow extends ConsumerWidget {
  const _HomeIngredientRow({required this.ingredient, required this.onTap});
  final Ingredient ingredient;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = _daysLeft(ingredient, ref.watch(inventoryDayProvider));
    final status = days == 0 ? '오늘까지' : '$days일 남음';
    final large = MediaQuery.textScalerOf(context).scale(16) > 22;
    final label = Text(
      status,
      style: TextStyle(
        color: days <= 1 ? primaryGreen : mediumGray,
        fontSize: 14,
      ),
    );
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: warmBorder)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 58,
                height: 50,
                child: IngredientPhoto(
                  path: ingredient.imagePath,
                  fallback: ingredientReferencePhotoFor(ingredient.name) == null
                      ? Semantics(
                          label: '${ingredient.name} 사진 없음',
                          child: ColoredBox(
                            color: softGreen,
                            child: Center(
                              child: Text(
                                ingredient.name.isEmpty
                                    ? '?'
                                    : ingredient.name.characters.first,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: mediumGray,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        )
                      : IngredientThumbnail(
                          name: ingredient.name,
                          width: 58,
                          height: 50,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ingredient.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (large) label,
                ],
              ),
            ),
            if (!large) ...[const SizedBox(width: 8), label],
          ],
        ),
      ),
    );
  }
}

class _InventoryOverview extends ConsumerWidget {
  const _InventoryOverview({required this.items, required this.onTap});
  final List<Ingredient> items;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expired = items
        .where(
          (item) =>
              !isExplicitlyEmptyQuantity(item.quantity) &&
              _daysLeft(item, ref.watch(inventoryDayProvider)) < 0,
        )
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FridgeInventoryVisual(items: items, onTap: onTap),
        if (expired > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.info_outline, size: 18),
              label: Text(
                '기한 지난 재료 $expired개 · 상태 확인하기',
                style: const TextStyle(color: warningInk),
              ),
            ),
          ),
      ],
    );
  }
}

int _daysLeft(Ingredient item, [DateTime? today]) =>
    calendarDayDifference(item.expiryDate, today ?? DateTime.now());

class IngredientPreview extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final days = _daysLeft(ingredient, ref.watch(inventoryDayProvider));
    final status = days < 0
        ? '${-days}일 지남'
        : days == 0
        ? '오늘까지'
        : 'D-$days';
    final storageLabel =
        const {
          'refrigerated': '냉장',
          'frozen': '냉동',
          'ambient': '실온',
        }[ingredient.storageType] ??
        ingredient.storageType;
    if (!detailed) {
      return Semantics(
        button: true,
        label: '${ingredient.name} \uc7ac\ub8cc \uc0c1\uc138 \uc5f4\uae30',
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: IngredientPhoto(
                        path: ingredient.imagePath,
                        fallback: IngredientThumbnail(
                          name: ingredient.name,
                          width: 76,
                          height: 76,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ingredient.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${ingredient.quantity} \u00b7 $storageLabel',
                          style: const TextStyle(
                            color: mediumGray,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          status,
                          style: TextStyle(
                            color: days <= 2 ? warningInk : primaryGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: mediumGray,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: '${ingredient.name} 재료 상세 열기',
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: warmBorder),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: detailed ? 120 : 96,
                alignment: Alignment.center,
                color: const Color(0xFFF5F5F5),
                child: IngredientPhoto(
                  path: ingredient.imagePath,
                  fallback: IngredientThumbnail(
                    name: ingredient.name,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height:
                          MediaQuery.textScalerOf(context).scale(16) * 1.4 * 2,
                      child: Tooltip(
                        message: ingredient.name,
                        child: Text(
                          ingredient.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          ingredient.quantity,
                          style: const TextStyle(
                            fontSize: 12,
                            color: mediumGray,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: softGreen,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            storageLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 4,
                      runSpacing: 3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: mediumGray,
                        ),
                        if (detailed)
                          Text(
                            DateFormat('MM.dd').format(ingredient.expiryDate),
                            style: const TextStyle(
                              fontSize: 11,
                              color: mediumGray,
                            ),
                          ),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            color: days <= 2 ? warningInk : mediumGray,
                            fontWeight: days <= 2
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  static const labels = ['전체', '냉장', '냉동', '실온'];
  static const storage = ['', 'refrigerated', 'frozen', 'ambient'];
  @override
  Widget build(BuildContext context) {
    ref.watch(inventoryDayProvider);
    final inventory = ref.watch(ingredientsProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: pageToolbarHeight(context),
        titleSpacing: pageGutter,
        title: const Text('냉장고'),
        actions: [
          if (ref.watch(unknownInventoryEnabledProvider))
            IconButton(
              tooltip: '기한 미정 재료',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const UnknownInventoryPage(),
                ),
              ),
              icon: const Icon(Icons.event_busy_outlined),
            ),
          IconButton(
            tooltip: '영수증 일괄 등록',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReceiptImportPage()),
            ),
            icon: const Icon(Icons.receipt_long),
          ),
          IconButton(
            tooltip: searching ? '재료 검색 닫기' : '재료 검색',
            onPressed: () => setState(() {
              searching = !searching;
              if (searching) {
                _searchFocus.requestFocus();
              } else {
                query = '';
                _searchController.clear();
                _searchFocus.unfocus();
              }
            }),
            icon: Icon(searching ? Icons.close : Icons.search),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: pageGutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (MediaQuery.textScalerOf(context).scale(16) <= 24 &&
                    MediaQuery.viewInsetsOf(context).bottom == 0)
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '우리 집 재료',
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                color: darkGray,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              '우리 집 재료를 차곡차곡',
                              style: TextStyle(fontSize: 12, color: mediumGray),
                            ),
                          ],
                        ),
                      ),
                      if (MediaQuery.textScalerOf(context).scale(16) <= 24)
                        Container(
                          width: 60,
                          height: 64,
                          decoration: BoxDecoration(
                            color: softGreen,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.kitchen_outlined,
                            size: 42,
                            color: primaryGreen,
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: (value) =>
                      setState(() => query = value.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: '재료 이름으로 검색',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 16),
                if (MediaQuery.viewInsetsOf(context).bottom == 0)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < labels.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              shape: const StadiumBorder(),
                              label: Text(labels[i]),
                              selected: selected == i,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => selected = i),
                              selectedColor: primaryGreen,
                              backgroundColor: Colors.white,
                              side: BorderSide.none,
                              labelStyle: TextStyle(
                                color: selected == i
                                    ? Colors.white
                                    : mediumGray,
                                fontWeight: FontWeight.w600,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
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
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const Center(
                child: CircularProgressIndicator(semanticsLabel: '재료 불러오는 중'),
              ),
              error: (_, _) => Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: () => ref.invalidate(ingredientsProvider),
                    child: const Text('재료를 불러오지 못했어요. 다시 시도'),
                  ),
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
                      ..sort(
                        (a, b) =>
                            compareCalendarDates(a.expiryDate, b.expiryDate),
                      );
                if (visible.isEmpty) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      pageGutter,
                      8,
                      pageGutter,
                      24,
                    ),
                    child: Column(
                      children: [
                        AppEmptyState(
                          icon: Icons.kitchen_outlined,
                          title: items.isEmpty
                              ? ref.watch(unknownInventoryEnabledProvider)
                                    ? '날짜가 등록된 재료가 없어요.'
                                    : '냉장고가 비어있어요.'
                              : '조건에 맞는 재료가 없어요.',
                          message: items.isEmpty
                              ? ref.watch(unknownInventoryEnabledProvider)
                                    ? '기한 미정 재료는 상단의 기한 미정 목록에서 확인해 주세요.'
                                    : '아래 재료 추가 버튼으로 첫 재료를 등록해 주세요.'
                              : '검색어나 보관함을 바꾸면 다른 재료를 볼 수 있어요.',
                        ),
                        if (items.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() {
                              selected = 0;
                              query = '';
                              _searchController.clear();
                              _searchFocus.unfocus();
                              searching = false;
                            }),
                            child: const Text('필터 초기화'),
                          ),
                      ],
                    ),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    pageGutter,
                    0,
                    pageGutter,
                    24,
                  ),
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
                                onTap: () =>
                                    _showIngredientDetails(context, ref, item),
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

class GroupedIngredientList extends ConsumerWidget {
  final List<Ingredient> items;
  final VoidCallback onAdd;

  const GroupedIngredientList({
    super.key,
    required this.items,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.kitchen_outlined,
        title: '냉장고가 비어있어요',
        message: '첫 재료를 추가하고\n냉장고 관리를 시작해보세요!',
        buttonText: '재료 추가하기',
        onButtonPressed: onAdd,
      );
    }

    final now = ref.watch(inventoryDayProvider);
    final urgentItems = items
        .where((i) => calendarDayDifference(i.expiryDate, now) < 3)
        .toList();
    final warningItems = items
        .where(
          (i) =>
              calendarDayDifference(i.expiryDate, now) >= 3 &&
              calendarDayDifference(i.expiryDate, now) < 7,
        )
        .toList();
    final safeItems = items
        .where((i) => calendarDayDifference(i.expiryDate, now) >= 7)
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
    final now = ref.watch(inventoryDayProvider);
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(
      ingredient.expiryDate.year,
      ingredient.expiryDate.month,
      ingredient.expiryDate.day,
    );

    final daysLeft = calendarDayDifference(expiryDay, today);

    final totalDuration = calendarDayDifference(
      expiryDay,
      ingredient.createdAt.toLocal(),
    );
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
          SizedBox(
            width: 58,
            height: 42,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: IngredientPhoto(
                path: ingredient.imagePath,
                fallback: IngredientThumbnail(name: ingredient.name),
              ),
            ),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ExpiryProgressBar(
                          progress: progress,
                          daysLeft: daysLeft,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
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
            tooltip: '${ingredient.name} 수정',
            onPressed: () =>
                _showAddEditIngredientSheet(context, ref, ingredient),
            icon: const Icon(Icons.edit_outlined, color: mediumGray, size: 20),
          ),
          IconButton(
            tooltip: '${ingredient.name} 삭제',
            onPressed: () => _confirmDeleteIngredient(context, ref, ingredient),
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

Future<void> _showIngredientDetails(
  BuildContext context,
  WidgetRef ref,
  Ingredient ingredient,
) async {
  final action = await showDialog<IngredientDetailAction>(
    context: context,
    builder: (_) => IngredientDetailDialog(ingredient: ingredient),
  );
  if (!context.mounted) return;
  if (action == IngredientDetailAction.edit) {
    _showAddEditIngredientSheet(context, ref, ingredient);
  } else if (action == IngredientDetailAction.delete) {
    await _confirmDeleteIngredient(context, ref, ingredient);
  }
}

Future<void> _confirmDeleteIngredient(
  BuildContext context,
  WidgetRef ref,
  Ingredient ingredient,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: const Text('재료를 삭제할까요?'),
      content: Text(ingredient.name),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final currentUser = ref.read(currentSessionUserProvider);
  final owner = currentUser()?.id;
  try {
    if (owner == null) throw StateError('Authentication required');
    await ref.read(ingredientDeleteProvider)(ingredient.id, owner);
    if (!context.mounted || currentUser()?.id != owner) return;
    ref.invalidate(ingredientsProvider);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('삭제 결과를 확인하지 못했어요. 목록을 새로고침해 확인해 주세요.'),
          action: SnackBarAction(
            label: '새로고침',
            onPressed: () => ref.invalidate(ingredientsProvider),
          ),
        ),
      );
    }
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
  DateTime? selectedDate;
  String? _dateError;
  String? _nameError;
  String? _recognitionError;
  String? _quantityError;
  String? _validationSummary;
  final _validationKey = GlobalKey();
  final _nameFocus = FocusNode();
  final _quantityFocus = FocusNode();
  late String storageType;

  late final String ingredientId;
  IngredientPhotoDraft? _photo;
  IngredientSaveOperation? _operation;
  bool _busy = false;
  bool _picking = false;
  bool get _locked => _busy || _picking || _operation != null;
  bool _confirmingExit = false;
  bool _exitApproved = false;
  bool get _hasChanges =>
      nameController.text != (widget.ingredient?.name ?? '') ||
      quantityController.text != (widget.ingredient?.quantity ?? '') ||
      selectedDate != widget.ingredient?.expiryDate ||
      storageType !=
          (widget.ingredient?.storageType ??
              widget.storageType ??
              'refrigerated') ||
      _photo != null ||
      _operation != null;

  Future<void> _confirmExit() async {
    if (_busy || _picking || _confirmingExit) return;
    _confirmingExit = true;
    FocusScope.of(context).unfocus();
    try {
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('입력을 종료할까요?'),
          content: Text(
            _operation == null
                ? '아직 저장하지 않은 입력 내용이 사라집니다.'
                : '저장 결과가 아직 확인되지 않았습니다. 이미 저장됐을 수도 있어요. 나가면 이 입력 화면은 사라지므로, 재등록 전에 재고를 확인해 주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('계속 입력'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('나가기'),
            ),
          ],
        ),
      );
      if (leave == true && mounted) {
        setState(() => _exitApproved = true);
        Navigator.of(context).pop();
      }
    } finally {
      _confirmingExit = false;
    }
  }

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
      if (mounted)
        setState(() {
          _photo = photo;
          _recognitionError = null;
        });
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
    setState(() {
      _picking = true;
      _recognitionError = null;
    });
    try {
      final photo = _photo!;
      List<IngredientCandidate> candidates;
      ReceiptAiReviewContext? request;
      ReceiptAiSessionGuard? session;
      bool current() =>
          mounted &&
          identical(_photo, photo) &&
          (request == null || request.matches(session!.current(request)));
      if (recognizer is SupabaseIngredientRecognizer) {
        session = ref.read(receiptAiSessionProvider);
        request = session!.capture(
          inputRevision: 'pending',
          requestId: newIngredientUuid(),
        );
        await recognizer.checkReady();
        if (!mounted || !current()) return;
        final reviewed = await Navigator.of(context)
            .push<ReviewedIngredientImage>(
              MaterialPageRoute(
                builder: (_) => IngredientImageReviewPage(
                  originalBytes: photo.bytes,
                  isSessionCurrent: current,
                  sessionChanges: session,
                ),
              ),
            );
        if (reviewed == null || !current()) return;
        request = session.capture(
          inputRevision: reviewed.sha256Hex,
          requestId: request.requestId,
        );
        candidates = await recognizer.recognizeReviewed(
          image: reviewed,
          context: request,
          currentContext: () => current() ? session!.current(request!) : null,
        );
      } else {
        candidates = await recognizer.recognize(photo);
      }
      if (!current()) return;
      if (!mounted) return;
      final confirmed = await showDialog<String>(
        context: context,
        builder: (_) => IngredientCandidateReview(candidates: candidates),
      );
      if (confirmed != null && current()) {
        // Never change quantity, expiry or storage, and never submit a record.
        setState(() {
          nameController.text = confirmed;
          _nameError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        final code = error is ReceiptAiFailure ? error.code : '';
        final message = switch (code) {
          'not_ready' => '재료 사진 AI가 아직 준비되지 않았어요. 이름을 직접 입력할 수 있어요.',
          'unauthenticated' ||
          'owner_not_allowed' => '재료 사진 AI를 사용할 수 있는 계정으로 로그인해 주세요.',
          'budget_exhausted' ||
          'rate_limited' => 'AI 사용 한도에 도달했어요. 이름을 직접 입력해 주세요.',
          'consent_expired' => '보낼 사진과 전송 동의를 다시 확인해 주세요.',
          'duplicate_request' => '중복 요청을 막았어요. 사진을 다시 보내지 않았습니다.',
          'timeout' || 'provider_unavailable' || 'invalid_response' =>
            '분석을 완료하지 못했어요. 비용이나 예약액이 남을 수 있어 자동 재시도하지 않았어요. 이름을 직접 입력할 수 있어요.',
          _ => '분석이 중단됐어요. 이름을 직접 입력할 수 있어요.',
        };
        setState(() => _recognitionError = message);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  bool get isEditing => widget.ingredient != null;

  Future<void> _pickExpiryDate() async {
    if (_locked) return;
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final initial = selectedDate ?? now;
    final first = DateTime(now.year, now.month, now.day - 365);
    final last = DateTime(now.year, now.month, now.day + 365 * 3);
    final picked = await showDatePicker(
      context: context,
      helpText: '포장지 날짜 확인 · 참고 보관일은 실제 소비기한이 아닙니다',
      initialDate: initial,
      firstDate: initial.isBefore(first) ? initial : first,
      lastDate: initial.isAfter(last) ? initial : last,
    );
    if (!mounted || _locked || picked == null) return;
    setState(() {
      selectedDate = picked;
      _dateError = null;
      _validationSummary = null;
    });
  }

  @override
  void initState() {
    super.initState();
    final ingredient = widget.ingredient;
    ingredientId = ingredient?.id ?? newIngredientUuid();
    nameController = TextEditingController(text: ingredient?.name);
    quantityController = TextEditingController(text: ingredient?.quantity);
    selectedDate = ingredient?.expiryDate;
    // Prioritize ingredient's storage type, then passed type, then default.
    storageType =
        ingredient?.storageType ?? widget.storageType ?? 'refrigerated';
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _quantityFocus.dispose();
    nameController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _picking) return;
    final name = nameController.text.trim();
    final quantity = quantityController.text.trim();
    final expiry = selectedDate;
    final missing = <String>[
      if (name.isEmpty) '재료명',
      if (quantity.isEmpty) '수량',
      if (expiry == null) '소비기한',
    ];
    setState(() {
      _nameError = name.isEmpty ? '재료명을 입력해 주세요.' : null;
      _quantityError = quantity.isEmpty ? '수량을 입력해 주세요.' : null;
      _dateError = expiry == null
          ? '포장지에 표시된 날짜를 직접 선택해 주세요. 기한을 모르면 아직 등록할 수 없어요.'
          : null;
      _validationSummary = missing.isEmpty
          ? null
          : missing.join(' · ') + ' 확인이 필요해요. 필수 항목을 입력해 주세요.';
    });
    if (missing.isNotEmpty) {
      FocusScope.of(context).unfocus();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('저장 전 입력을 확인해 주세요'),
          content: Text(
            '필수 항목을 입력해 주세요. 입력한 내용은 그대로 유지됩니다.\n\n${missing.join(' · ')} 입력 필요',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('입력 계속하기'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _validationKey.currentContext;
        if (mounted && target != null) {
          Scrollable.ensureVisible(
            target,
            alignment: 0.5,
            duration: const Duration(milliseconds: 180),
          );
        }
      });
      return;
    }

    final currentUser = ref.read(currentSessionUserProvider);
    final user = currentUser();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 상태를 확인할 수 없어요. 입력 내용은 유지됩니다. 로그인 후 다시 시도해 주세요.'),
        ),
      );
      return;
    }

    final data = {
      'id': ingredientId,
      'image_path': widget.ingredient?.imagePath,
      'user_id': user.id,
      'name': name,
      'quantity': quantity,
      'expiry_date': DateFormat('yyyy-MM-dd').format(expiry!),
      'storage_type': storageType,
      if (!isEditing) 'created_at': DateTime.now().toIso8601String(),
    };

    setState(() => _busy = true);
    try {
      _operation ??= IngredientSaveOperation(
        gateway: ref.read(manualIngredientGatewayProvider),
        data: data,
        editing: isEditing,
        photo: _photo,
        oldPath: widget.ingredient?.imagePath,
        stillValid: () => mounted && currentUser()?.id == user.id,
      );
      final cleaned = await _operation!.save();
      if (!mounted || currentUser()?.id != user.id) return;
      if (!cleaned)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('재료는 저장했지만 이전 사진 정리를 완료하지 못했어요.')),
        );
      if (!isEditing) {}

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

    return PopScope(
      canPop: !_busy && !_picking && (!_hasChanges || _exitApproved),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
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
                if (_recognitionError != null)
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      key: const ValueKey('ingredient-recognition-error'),
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8, bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _recognitionError!,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                focusNode: _nameFocus,
                decoration: InputDecoration(
                  labelText: '재료명',
                  errorText: _nameError,
                  errorMaxLines: 3,
                ),
                onChanged: (_) => setState(() {
                  _nameError = null;
                  _validationSummary = null;
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                enabled: !_locked,
                controller: quantityController,
                focusNode: _quantityFocus,
                decoration: InputDecoration(
                  labelText: '수량 (예: 1개, 200g)',
                  errorText: _quantityError,
                  errorMaxLines: 3,
                ),
                onChanged: (_) => setState(() {
                  _quantityError = null;
                  _validationSummary = null;
                }),
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
              if (!_locked)
                FoodCatalogButton(
                  name: nameController.text,
                  onSelected: (name) async {
                    if (_locked) return;
                    FocusScope.of(context).unfocus();
                    setState(() {
                      nameController.text = name;
                      _nameError = null;
                    });
                    if (selectedDate == null) await _pickExpiryDate();
                  },
                ),
              StorageGuidanceButton(
                name: nameController.text,
                storageType: storageType,
              ),
              if (!isEditing &&
                  ref.watch(unknownInventoryWritesEnabledProvider)) ...[
                TextButton.icon(
                  onPressed: _locked || _photo != null
                      ? null
                      : () async {
                          final saved = await showUnknownIngredientEditor(
                            context,
                            ref,
                            initialName: nameController.text,
                            initialQuantity: quantityController.text,
                            initialStorage: storageType,
                          );
                          if (saved && mounted) {
                            setState(() => _exitApproved = true);
                            if (context.mounted) Navigator.of(context).pop();
                          }
                        },
                  icon: const Icon(Icons.event_busy_outlined),
                  label: const Text('날짜를 모르면 기한 미정으로 등록'),
                ),
                Text(
                  _photo == null
                      ? '기한 미정 재료는 별도 목록에 저장되며 소비기한 알림에서 제외돼요.'
                      : '기한 미정 등록은 사진을 지원하지 않아요. 선택한 사진을 취소한 뒤 이용해 주세요.',
                ),
              ] else
                const Text(
                  '포장지 날짜를 직접 선택해 주세요. 소비기한을 모르는 재료의 등록은 아직 지원하지 않아요. 임의 날짜를 입력하지 마세요.',
                ),
              const SizedBox(height: 8),
              const Text(
                '포장지 소비기한',
                style: TextStyle(fontSize: 12, color: mediumGray),
              ),
              InkWell(
                onTap: _locked ? null : _pickExpiryDate,
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
                          selectedDate == null
                              ? '날짜 선택 (필수)'
                              : DateFormat(
                                  'yyyy년 MM월 dd일',
                                ).format(selectedDate!),
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
              if (_dateError != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _dateError!,
                    style: const TextStyle(color: dangerInk),
                  ),
                ),
              const SizedBox(height: 24),
              if (_validationSummary != null) ...[
                Semantics(
                  key: _validationKey,
                  liveRegion: true,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _validationSummary!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
              TextButton(
                onPressed: _busy || _picking
                    ? null
                    : () => Navigator.of(context).maybePop(),
                child: const Text('취소'),
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
