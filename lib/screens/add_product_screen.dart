import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../services/shop_state.dart';
import '../models/shop_models.dart';

class AddProductScreen extends StatefulWidget {
  final ProductModel? product; // null = yangi, not null = tahrirlash

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  
  int _descriptionLength = 0;
  

  String _selectedCategory = 'fertilizer';
  List<File> _newImages = [];
  List<String> _existingImageUrls = [];
  List<_CustomField> _customFields = [];
  bool _isLoading = false;

  final Map<String, String> _categories = {
    'fertilizer': 'O\'g\'itlar',
    'tool': 'Asboblar',
    'pot': 'Gorshoklar',
    'seed': 'Urug\'lar',
    'soil': 'Tuproq',
    'accessory': 'Aksessuarlar',
  };

  bool get isEditing => widget.product != null;

@override
void initState() {
  super.initState();

  if (isEditing && widget.product != null) {
    // Name
    _nameController.text = widget.product!.name;

    // Description
    _descriptionController.text = widget.product!.description ?? '';
    _descriptionLength = _descriptionController.text.length;

    // Price
    _priceController.text =
        widget.product!.price.toStringAsFixed(0);

    // Stock
    _stockController.text =
        widget.product!.stock_quantity.toString();

    // Category
    _selectedCategory =
        widget.product!.category ?? 'fertilizer';

    // Existing images
    _existingImageUrls =
        List<String>.from(widget.product!.imageUrls);

    // Custom fields
    if (widget.product!.customFields != null) {
      widget.product!.customFields!.forEach((key, value) {
        _customFields.add(
          _CustomField(
            key: key,
            value: value.toString(),
          ),
        );
      });
    }
  }
}


  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    
    if (images.isNotEmpty) {
      setState(() {
        _newImages.addAll(images.map((x) => File(x.path)));
      });
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    
    if (photo != null) {
      setState(() {
        _newImages.add(File(photo.path));
      });
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  void _addCustomField() {
    setState(() {
      _customFields.add(_CustomField());
    });
  }

  void _removeCustomField(int index) {
    setState(() {
      _customFields.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_newImages.isEmpty && _existingImageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamida bitta rasm qo\'shing'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    final shopState = context.read<ShopState>();
    
    // Custom fields to map
    Map<String, dynamic>? customFieldsMap;
    if (_customFields.isNotEmpty) {
      customFieldsMap = {};
      for (final field in _customFields) {
        if (field.keyController.text.isNotEmpty && field.valueController.text.isNotEmpty) {
          customFieldsMap[field.keyController.text] = field.valueController.text;
        }
      }
    }
    
    try {
      if (isEditing) {
        print('🔄 Starting update process...');
        
        // 1. Avval mavjud rasmlarni olish
        List<String> allImageUrls = List<String>.from(_existingImageUrls);
        print('📷 Existing images: $allImageUrls');
        
        // 2. Yangi rasmlarni upload qilish
        if (_newImages.isNotEmpty) {
          print('📤 Uploading ${_newImages.length} new images...');
          final uploadResult = await shopState.uploadImages(_newImages);
          
          if (uploadResult.success && uploadResult.data != null) {
            allImageUrls.addAll(uploadResult.data!);
            print('✅ New images uploaded: ${uploadResult.data}');
          } else {
            print('❌ Upload failed: ${uploadResult.error}');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(uploadResult.error ?? 'Rasmlarni yuklashda xatolik'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
            setState(() => _isLoading = false);
            return;
          }
        }
        
        print('📦 Final image URLs: $allImageUrls');
        
        // 3. Mahsulotni yangilash (rasmlar bilan birga)
        final result = await shopState.updateProduct(
          productId: widget.product!.id,
          name: _nameController.text,
          description: _descriptionController.text,
          price: double.parse(_priceController.text),
          stock: int.parse(_stockController.text),
          category: _selectedCategory,
          imageUrls: allImageUrls, // ✅ MUHIM: Bo'sh bo'lmasligi kerak
          customFields: customFieldsMap,
        );
        
        if (mounted) {
          if (result.success) {
            print('✅ Product updated successfully!');
            Navigator.pop(context, true); // ✅ true qaytarish - yangilanganini bildirish
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mahsulot muvaffaqiyatli yangilandi'),
                backgroundColor: AppColors.success,
              ),
            );
        } else {
          print('❌ Update failed: ${result.error}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Yangilashda xatolik'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } else {
        final result = await shopState.createProduct(
          name: _nameController.text,
          description: _descriptionController.text,
          price: double.parse(_priceController.text),
          stock: int.parse(_stockController.text),
          category: _selectedCategory,
          images: _newImages,
          customFields: customFieldsMap,
        );
        
        if (mounted) {
          if (result.success) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mahsulot qo\'shildi'),
                backgroundColor: AppColors.success,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.error ?? 'Xatolik'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Mahsulotni tahrirlash' : 'Yangi mahsulot',
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Images section
              _buildImagesSection().animate().fadeIn(delay: 100.ms),
              
              const SizedBox(height: 24),
              
              // Required fields
              const Text(
                '📋 Asosiy ma\'lumotlar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Majburiy maydonlar',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMedium,
                ),
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _nameController,
                label: 'Mahsulot nomi *',
                hint: 'Masalan: Organik o\'g\'it',
                icon: Icons.inventory_2_outlined,
                validator: (v) => v == null || v.isEmpty ? 'Nomini kiriting' : null,
              ).animate().fadeIn(delay: 150.ms),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _priceController,
                      label: 'Narxi (so\'m) *',
                      hint: '50000',
                      icon: Icons.monetization_on_outlined,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Narxni kiriting';
                        if (double.tryParse(v) == null) return 'Noto\'g\'ri format';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _stockController,
                      label: 'Soni *',
                      hint: '10',
                      icon: Icons.numbers,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Sonini kiriting';
                        if (int.tryParse(v) == null) return 'Noto\'g\'ri format';
                        return null;
                      },
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                maxLength: 500, 
                onChanged: (value) {
                  setState(() {
                    _descriptionLength = value.length;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Tavsif *',
                  hintText: 'Mahsulot haqida batafsil...',
                  prefixIcon: const Icon(Icons.description_outlined),
                  helperText: '$_descriptionLength / 500',
                  helperStyle: TextStyle(
                    color: _descriptionLength >= 500
                        ? AppColors.error
                        : AppColors.textMedium,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Tavsif yozish majburiy';
                  }
                  if (value.length > 500) {
                    return 'Tavsif 500 belgidan oshmasligi kerak';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 250.ms),

              
              const SizedBox(height: 16),
              
              // Category
              const Text(
                'Kategoriya',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.entries.map((entry) {
                  final isSelected = _selectedCategory == entry.key;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = entry.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppColors.primaryGradient : null,
                        color: isSelected ? null : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppColors.cardShadow,
                        border: Border.all(
                          color: isSelected ? Colors.transparent : AppColors.textLight.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textMedium,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ).animate().fadeIn(delay: 300.ms),
              
              const SizedBox(height: 32),
              
              // Custom fields
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '➕ Qo\'shimcha maydonlar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Ixtiyoriy (og\'irlik, rang, va h.k.)',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _addCustomField,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: AppColors.primaryGreen,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 350.ms),
              
              const SizedBox(height: 16),
              
              // Custom fields list
              ..._customFields.asMap().entries.map((entry) {
                final index = entry.key;
                final field = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: field.keyController,
                          decoration: InputDecoration(
                            hintText: 'Maydon nomi',
                            hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.6)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: AppColors.textLight.withOpacity(0.2),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: field.valueController,
                          decoration: InputDecoration(
                            hintText: 'Qiymati',
                            hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.6)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _removeCustomField(index),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close, color: AppColors.error, size: 18),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              
              const SizedBox(height: 32),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEditing ? 'Saqlash' : 'Mahsulot qo\'shish',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ).animate().fadeIn(delay: 400.ms),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagesSection() {
    final totalImages = _existingImageUrls.length + _newImages.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📷 Mahsulot rasmlari',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Kamida 1 ta rasm qo\'shing',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$totalImages ta',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Image picker buttons
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _pickImages,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.cardShadow,
                    border: Border.all(
                      color: AppColors.primaryGreen.withOpacity(0.3),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.photo_library_outlined, color: AppColors.primaryGreen, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Galereyadan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _takePhoto,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.cardShadow,
                    border: Border.all(
                      color: AppColors.accentBlue.withOpacity(0.3),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.camera_alt_outlined, color: AppColors.accentBlue, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Kameradan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        
        // Existing images
        if (_existingImageUrls.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _existingImageUrls.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _existingImageUrls[index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.softGreen,
                            child: const Icon(Icons.image, color: AppColors.textLight),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 14,
                      child: GestureDetector(
                        onTap: () => _removeExistingImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                    if (index == 0)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Asosiy',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
        
        // New images
        if (_newImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _newImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_newImages[index], fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 14,
                      child: GestureDetector(
                        onTap: () => _removeNewImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Yangi',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.6)),
            prefixIcon: Icon(icon, color: AppColors.primaryGreen),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.textLight.withOpacity(0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomField {
  final TextEditingController keyController;
  final TextEditingController valueController;
  
  _CustomField({String key = '', String value = ''})
      : keyController = TextEditingController(text: key),
        valueController = TextEditingController(text: value);
}
