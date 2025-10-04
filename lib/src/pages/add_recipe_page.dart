import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:take_care_refrigerator/src/models.dart';

import '../providers.dart';
import '../theme.dart';

class AddRecipePage extends ConsumerStatefulWidget {
  final Recipe? recipe;
  const AddRecipePage({super.key, this.recipe});

  @override
  ConsumerState<AddRecipePage> createState() => _AddRecipePageState();
}

class _AddRecipePageState extends ConsumerState<AddRecipePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _youtubeUrlController = TextEditingController();
  final _blogUrlController = TextEditingController();
  final _totalTimeController = TextEditingController();
  final _cuisineTypeController = TextEditingController();
  final _ingredientsController = TextEditingController();

  bool get isEditing => widget.recipe != null;
  bool _isLoading = false;
  XFile? _imageXFile;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final recipe = widget.recipe!;
      _nameController.text = recipe.name;
      _descriptionController.text = recipe.description ?? '';
      _youtubeUrlController.text = recipe.youtubeVideoId != null
          ? 'https://www.youtube.com/watch?v=${recipe.youtubeVideoId}'
          : '';
      _blogUrlController.text = recipe.blogUrl ?? '';
      _totalTimeController.text = recipe.totalTime ?? '';
      _cuisineTypeController.text = recipe.cuisineType ?? '';
      _ingredientsController.text = recipe.requiredIngredients.join(', ');
      _imageUrl = recipe.imageUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _youtubeUrlController.dispose();
    _blogUrlController.dispose();
    _totalTimeController.dispose();
    _cuisineTypeController.dispose();
    _ingredientsController.dispose();
    super.dispose();
  }

  String? _extractYoutubeId(String url) {
    if (url.isEmpty) return null;
    if (!url.contains("youtube.com/") && !url.contains("youtu.be/")) return null;
    try {
      final uri = Uri.parse(url);
      if (url.contains("youtu.be")) return uri.pathSegments.first;
      return uri.queryParameters['v'];
    } catch (e) {
      return null;
    }
  }

  Future<String?> _uploadImage(XFile image) async {
    final supabase = ref.read(supabaseProvider);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.${image.name.split('.').last}';
    final filePath = 'recipe_images/$fileName';

    try {
      if (kIsWeb) {
        final imageBytes = await image.readAsBytes();
        await supabase.storage.from('recipes').uploadBinary(
              filePath,
              imageBytes,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
            );
      } else {
        final imageFile = File(image.path);
        await supabase.storage.from('recipes').upload(
              filePath,
              imageFile,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
            );
      }
      return supabase.storage.from('recipes').getPublicUrl(filePath);
    } on StorageException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("이미지 업로드 실패: ${e.message}"), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("오류 발생: $e"), backgroundColor: Colors.red));
    }
    return null;
  }

  Future<void> _pickImage({required ImageSource source, required bool isCover}) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);

    if (pickedFile == null) return;

    if (isCover) {
      setState(() {
        _imageXFile = pickedFile;
      });
    } else {
      setState(() => _isLoading = true);
      final imageUrl = await _uploadImage(pickedFile);
      if (imageUrl != null) {
        final markdownImage = '\n![설명]($imageUrl)\n';
        final controller = _descriptionController;
        final text = controller.text;
        final selection = controller.selection;
        final newText = text.replaceRange(selection.start, selection.end, markdownImage);
        controller.value = controller.value.copyWith(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start + markdownImage.length),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showImageSourceDialog({required bool isCover}) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이미지 선택'),
        content: const Text('사진을 가져올 방법을 선택하세요.'),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); _pickImage(source: ImageSource.camera, isCover: isCover); }, child: const Text('카메라')),
          TextButton(onPressed: () { Navigator.pop(context); _pickImage(source: ImageSource.gallery, isCover: isCover); }, child: const Text('갤러리')),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final youtubeUrl = _youtubeUrlController.text.trim();
    final blogUrl = _blogUrlController.text.trim();

    if (youtubeUrl.isEmpty && blogUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('유튜브 또는 블로그 주소 중 하나는 반드시 입력해야 합니다.'), backgroundColor: Colors.red));
      return;
    }

    String? youtubeId;
    if (youtubeUrl.isNotEmpty) {
      youtubeId = _extractYoutubeId(youtubeUrl);
      if (youtubeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('유효하지 않은 유튜브 주소입니다.'), backgroundColor: Colors.red));
        return;
      }
    }

    if (_imageUrl == null && _imageXFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('대표 이미지를 등록해주세요.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    String? finalImageUrl = _imageUrl;
    if (_imageXFile != null) {
      finalImageUrl = await _uploadImage(_imageXFile!);
      if (finalImageUrl == null) {
        setState(() => _isLoading = false);
        return; // Stop if image upload failed
      }
    }

    final ingredients = _ingredientsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final data = {
      'name': _nameController.text,
      'description': _descriptionController.text,
      'image_url': finalImageUrl!,
      'youtube_video_id': youtubeId,
      'blog_url': blogUrl.isEmpty ? null : blogUrl,
      'total_time': _totalTimeController.text,
      'cuisine_type': _cuisineTypeController.text,
      'required_ingredients': ingredients,
    };

    try {
      if (isEditing) {
        await ref.read(supabaseProvider).from('recipes').update(data).eq('id', widget.recipe!.id);
      } else {
        await ref.read(supabaseProvider).from('recipes').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('레시피가 성공적으로 ${isEditing ? '수정' : '추가'}되었습니다!')));
        // Invalidate all providers related to recipe lists to ensure data is refreshed
        ref.invalidate(recommendedIdsProvider);
        ref.invalidate(popularIdsProvider);
        ref.invalidate(recentIdsProvider);
        ref.invalidate(paginatedRecipesProvider);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? '레시피 수정' : '레시피 추가'), backgroundColor: Colors.white, foregroundColor: darkGray),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text('대표 이미지', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showImageSourceDialog(isCover: true),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                  child: _imageXFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb
                              ? Image.network(_imageXFile!.path, fit: BoxFit.cover)
                              : Image.file(File(_imageXFile!.path), fit: BoxFit.cover),
                        )
                      : (_imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(_imageUrl!, fit: BoxFit.cover),
                            )
                          : const Center(child: Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey))),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: '요리 이름'), validator: (value) => (value == null || value.isEmpty) ? '필수 항목입니다.' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: '요리 과정 (마크다운 지원)', helperText: '예: # 제목, **진하게**, 1. 순서 목록', alignLabelWithHint: true), maxLines: 10),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showImageSourceDialog(isCover: false),
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('과정 사진 추가'),
              style: OutlinedButton.styleFrom(foregroundColor: darkGray, side: const BorderSide(color: Colors.grey)),
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _youtubeUrlController, decoration: const InputDecoration(labelText: '유튜브 주소', helperText: '전체 유튜브 주소를 입력하세요.')),
            const SizedBox(height: 16),
            TextFormField(controller: _blogUrlController, decoration: const InputDecoration(labelText: '블로그 주소', helperText: '전체 블로그 주소를 입력하세요.')),
            const SizedBox(height: 16),
            TextFormField(controller: _ingredientsController, decoration: const InputDecoration(labelText: '필요 재료', helperText: '쉼표(,)로 재료를 구분하여 입력하세요.'), validator: (value) => (value == null || value.isEmpty) ? '필수 항목입니다.' : null),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _totalTimeController, decoration: const InputDecoration(labelText: '총 소요 시간'))),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(controller: _cuisineTypeController, decoration: const InputDecoration(labelText: '요리 종류'))),
              ],
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), child: Text(isEditing ? '수정하기' : '저장하기', style: const TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }
}
