import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../services/error_helper.dart';
import '../widgets/premium_dialogs.dart';

/// Modern Business Menu Management Screen
class BusinessMenuScreen extends StatefulWidget {
  final VoidCallback? onDataChanged;
  final VoidCallback? onBack;

  const BusinessMenuScreen({super.key, this.onDataChanged, this.onBack});

  @override
  State<BusinessMenuScreen> createState() => _BusinessMenuScreenState();
}

class _BusinessMenuScreenState extends State<BusinessMenuScreen> {
  List<dynamic> _menuItems = [];
  bool _loading = true;
  String _selectedFilter = 'All';
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    try {
      final menu = await ApiService.businessGetMenu();
      if (mounted) setState(() { _menuItems = menu; _loading = false; });
      widget.onDataChanged?.call();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _filters {
    final cats = _menuItems.map((e) => (e['category'] ?? 'Other').toString()).toSet().toList();
    return ['All', ...cats];
  }

  List<dynamic> get _filteredItems {
    if (_selectedFilter == 'All') return _menuItems;
    return _menuItems.where((e) => e['category'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Gradient Header
            _buildHeader(),
            // Filter Chips
            if (_menuItems.isNotEmpty) _buildFilterChips(),
            // Menu List
            Expanded(child: _buildMenuList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, statusBarHeight + 8, 16, 18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            // This screen is a tab inside BusinessHomeScreen, not a pushed
            // route — so switch back to the Home tab instead of popping
            // the navigator (which would exit to the role selection screen).
            onTap: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.of(context).maybePop();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Manage Menu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          GestureDetector(
            onTap: () => _showAddItemDialog(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: const Icon(Icons.add_rounded, color: AppColors.orange, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        itemBuilder: (ctx, i) {
          final isSelected = _selectedFilter == _filters[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8, top: 10),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = _filters[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppColors.primaryGradient : null,
                  color: isSelected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Text(
                  _filters[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.orange));
    }
    if (_filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.orangePale,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.restaurant_menu_rounded, size: 36, color: AppColors.orange.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 16),
            const Text('No menu items yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF999999))),
            const SizedBox(height: 6),
            Text('Tap + to add your first item', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMenu,
      color: AppColors.orange,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _filteredItems.length,
        itemBuilder: (ctx, i) => _buildMenuCard(_filteredItems[i]),
      ),
    );
  }

  Widget _buildMenuCard(dynamic item) {
    final isAvailable = item['isAvailable'] ?? true;
    final hasImage = item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.orange.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Top section with gradient and image
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isAvailable
                    ? [AppColors.orange.withValues(alpha: 0.05), AppColors.deepOrange.withValues(alpha: 0.03)]
                    : [Colors.grey.shade50, Colors.grey.shade100],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item Image - Larger and better styled
                Container(
                  width: hasImage ? 80 : 52,
                  height: hasImage ? 80 : 52,
                  decoration: BoxDecoration(
                    gradient: !hasImage && isAvailable ? AppColors.primaryGradient : null,
                    color: !hasImage && !isAvailable ? Colors.grey.shade300 : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: hasImage || isAvailable
                        ? [BoxShadow(color: AppColors.orange.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: hasImage
                        ? Image.network(
                            item['imageUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(gradient: AppColors.primaryGradient),
                              child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 32),
                            ),
                            loadingBuilder: (_, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: AppColors.orangePale,
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : const Icon(Icons.restaurant_rounded, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item name
                      Text(
                        item['name'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isAvailable ? Colors.black : Colors.grey,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Description if available
                      if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
                        Text(
                          item['description'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isAvailable ? Colors.grey[600] : Colors.grey[400],
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      // Price and category row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: isAvailable ? AppColors.primaryGradient : null,
                              color: !isAvailable ? Colors.grey.shade300 : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Rs.${item['price']}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isAvailable ? Colors.white : Colors.grey[600],
                              ),
                            ),
                          ),
                          if (item['category'] != null) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isAvailable ? AppColors.orange.withValues(alpha: 0.1) : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isAvailable ? AppColors.orange.withValues(alpha: 0.3) : Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.category_rounded,
                                      size: 12,
                                      color: isAvailable ? AppColors.orange : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        item['category'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isAvailable ? AppColors.orange : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Prep time if available
                      if (item['preparationTime'] != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              '${item['preparationTime']} min',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bottom section with actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isAvailable ? Colors.white : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(
              children: [
                // Availability Toggle
                Transform.scale(
                  scale: 0.9,
                  child: Switch(
                    value: isAvailable,
                    activeColor: AppColors.orange,
                    onChanged: (val) async {
                      try {
                        await ApiService.businessToggleAvailability(item['id']);
                        _loadMenu();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(val ? '✅ Item is now available' : '⏸️ Item is now unavailable'),
                              backgroundColor: val ? Colors.green : Colors.orange,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ErrorHelper.getMessage(e)), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAvailable ? 'Available' : 'Unavailable',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isAvailable ? Colors.green : Colors.grey[600],
                      ),
                    ),
                    Text(
                      isAvailable ? 'Customers can order' : 'Hidden from menu',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const Spacer(),
                // Edit Button
                GestureDetector(
                  onTap: () => _showAddItemDialog(existingItem: item),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.orangePale,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.edit_rounded, color: AppColors.orange, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                // Delete Button
                GestureDetector(
                  onTap: () => _confirmDelete(item),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEF5350).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.delete_rounded, color: Color(0xFFE53935), size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog({dynamic existingItem}) {
    final nameController = TextEditingController(text: existingItem?['name'] ?? '');
    final priceController = TextEditingController(text: existingItem?['price']?.toString() ?? '');
    final descController = TextEditingController(text: existingItem?['description'] ?? '');
    final prepController = TextEditingController(text: existingItem?['preparationTime']?.toString() ?? '15');
    final imageUrlController = TextEditingController(text: existingItem?['imageUrl'] ?? '');
    String category = existingItem?['category'] ?? 'Main Course';
    String? inlineError; // shown inside the sheet — snackbars hide behind modal sheets
    bool saving = false;
    final categories = ['Burgers', 'Pizza', 'Chicken', 'Biryani', 'Chinese', 'Fast Food', 'BBQ', 'Desserts', 'Drinks', 'Appetizers', 'Main Course'];
    // Guard against any category value (old data, typos, etc.) that isn't
    // in the dropdown's list — that mismatch throws a DropdownButton
    // assertion error and shows the red error screen.
    if (!categories.contains(category)) category = categories.first;

    // NEW items never save without an image: if the owner skipped the
    // photo, seed the field with a small category-appropriate stock photo
    // so the customer menu always shows a real image (not a grey card).
    const defaultImages = {
      'Burgers': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&h=300&fit=crop&auto=format&q=70',
      'Pizza': 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&h=300&fit=crop&auto=format&q=70',
      'Chicken': 'https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?w=400&h=300&fit=crop&auto=format&q=70',
      'Biryani': 'https://images.unsplash.com/photo-1633945274405-b6c8069047b0?w=400&h=300&fit=crop&auto=format&q=70',
      'Chinese': 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=400&h=300&fit=crop&auto=format&q=70',
      'Fast Food': 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=400&h=300&fit=crop&auto=format&q=70',
      'BBQ': 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=400&h=300&fit=crop&auto=format&q=70',
      'Desserts': 'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=400&h=300&fit=crop&auto=format&q=70',
      'Drinks': 'https://images.unsplash.com/photo-1541519227354-08fa5d50c44d?w=400&h=300&fit=crop&auto=format&q=70',
      'Appetizers': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&h=300&fit=crop&auto=format&q=70',
      'Main Course': 'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=400&h=300&fit=crop&auto=format&q=70',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(existingItem != null ? Icons.edit_rounded : Icons.add_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(existingItem != null ? 'Edit Item' : 'Add New Item',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('Fill in the details below', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Image Preview Section
                if (imageUrlController.text.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.orange.withValues(alpha: 0.2), width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            imageUrlController.text,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.orangePale,
                              child: const Center(child: Icon(Icons.broken_image, size: 48, color: AppColors.orange)),
                            ),
                            loadingBuilder: (_, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: AppColors.orangePale,
                                child: const Center(child: CircularProgressIndicator(color: AppColors.orange)),
                              );
                            },
                          ),
                          Positioned(
                            top: 8, right: 8,
                            child: GestureDetector(
                              onTap: () => setSheetState(() => imageUrlController.clear()),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Item Name
                const Text('Item Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkGray)),
                const SizedBox(height: 8),
                _buildDialogField(nameController, 'e.g., Zinger Burger', TextInputType.text),
                
                const SizedBox(height: 16),
                
                // Price
                const Text('Price (Rs.) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkGray)),
                const SizedBox(height: 8),
                _buildDialogField(priceController, 'e.g., 599', TextInputType.number, prefix: 'Rs. '),
                
                const SizedBox(height: 16),
                
                // Category
                const Text('Category *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkGray)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.orange.withValues(alpha: 0.1)),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: category,
                    decoration: InputDecoration(
                      hintText: 'Select category',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      prefixIcon: const Icon(Icons.category_rounded, color: AppColors.orange, size: 20),
                    ),
                    dropdownColor: Colors.white,
                    items: categories.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c, style: const TextStyle(fontSize: 15)),
                    )).toList(),
                    onChanged: (v) => setSheetState(() => category = v ?? category),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Description
                const Text('Description (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkGray)),
                const SizedBox(height: 8),
                _buildDialogField(descController, 'Tell customers about this item', TextInputType.multiline, maxLines: 3),
                
                const SizedBox(height: 16),
                
                // Image URL
                const Text('Food Image (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkGray)),
                const SizedBox(height: 8),
                _buildDialogField(
                  imageUrlController,
                  'Paste image URL — or pick from gallery below',
                  TextInputType.url,
                  onChanged: (value) => setSheetState(() {}),
                  suffix: imageUrlController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.visibility, color: AppColors.orange, size: 20),
                          onPressed: () => setSheetState(() {}),
                        )
                      : null,
                ),
                
                const SizedBox(height: 12),
                
                // Gallery / Camera pickers
                Row(
                  children: [
                    Expanded(
                      child: _buildImagePickButton(
                        icon: Icons.photo_library_rounded,
                        label: 'Choose from Gallery',
                        onTap: () => _pickImageFromGallery(ctx, setSheetState, imageUrlController),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildImagePickButton(
                        icon: Icons.photo_camera_rounded,
                        label: 'Take Photo',
                        onTap: () => _pickImageFromCamera(ctx, setSheetState, imageUrlController),
                      ),
                    ),
                  ],
                ),
                
                if (_uploadingImage)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.orange)),
                        SizedBox(width: 8),
                        Text('Uploading image...', style: TextStyle(fontSize: 12, color: AppColors.orange)),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 12),
                
                // Image URL Helper
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.orangePale.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.orange.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.orange, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tip: Search your food on Unsplash.com, right-click image, and copy image address',
                          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Prep Time
                const Text('Preparation Time (Minutes)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkGray)),
                const SizedBox(height: 8),
                _buildDialogField(prepController, 'e.g., 15', TextInputType.number, prefix: '⏱️ '),
                
                if (inlineError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(inlineError!, style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Action Button
                SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                      final name = nameController.text.trim();
                      final priceText = priceController.text.trim();
                      if (name.isEmpty) {
                        setSheetState(() => inlineError = 'Please enter item name');
                        return;
                      }
                      if (priceText.isEmpty) {
                        setSheetState(() => inlineError = 'Please enter price');
                        return;
                      }
                      final price = double.tryParse(priceText);
                      if (price == null || price <= 0) {
                        setSheetState(() => inlineError = 'Price must be a number, e.g. 250');
                        return;
                      }

                      setSheetState(() { saving = true; inlineError = null; });
                      try {
                        final imageUrl = imageUrlController.text.trim().isNotEmpty
                            ? imageUrlController.text.trim()
                            : (existingItem == null ? (defaultImages[category] ?? defaultImages['Main Course']) : null);
                        
                        if (existingItem != null) {
                          await ApiService.businessUpdateMenuItem(existingItem['id'], {
                            'name': nameController.text.trim(),
                            'price': price,
                            'description': descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                            'category': category,
                            'preparationTime': int.tryParse(prepController.text.trim()) ?? 15,
                            if (imageUrl != null) 'imageUrl': imageUrl,
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✅ Item updated successfully!'), backgroundColor: Colors.green),
                            );
                          }
                        } else {
                          await ApiService.businessAddMenuItem(
                            name: nameController.text.trim(),
                            price: price,
                            description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                            category: category,
                            preparationTime: int.tryParse(prepController.text.trim()) ?? 15,
                            imageUrl: imageUrl,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✅ Item added successfully!'), backgroundColor: Colors.green),
                            );
                          }
                        }
                        Navigator.of(ctx).pop();
                        _loadMenu();
                      } catch (e) {
                        setSheetState(() {
                          saving = false;
                          inlineError = ErrorHelper.getMessage(e);
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                      shadowColor: AppColors.orange.withValues(alpha: 0.3),
                    ),
                    child: saving
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                              SizedBox(width: 12),
                              Text('Saving...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(existingItem != null ? Icons.check_circle_outline : Icons.add_circle_outline, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                existingItem != null ? 'Update Item' : 'Add to Menu',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                              ),
                            ],
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

  /// Opens the gallery, uploads the picked image to the backend and puts
  /// the returned URL into [imageUrlController] so it is saved with the item.
  Future<void> _pickImageFromGallery(
    BuildContext sheetCtx,
    StateSetter setSheetState,
    TextEditingController imageUrlController,
  ) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 80,
      );
      if (picked == null) return;
      await _uploadPickedImage(picked.path, sheetCtx, setSheetState, imageUrlController);
    } catch (e) {
      if (sheetCtx.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open gallery: ${ErrorHelper.getMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromCamera(
    BuildContext sheetCtx,
    StateSetter setSheetState,
    TextEditingController imageUrlController,
  ) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        imageQuality: 80,
      );
      if (picked == null) return;
      await _uploadPickedImage(picked.path, sheetCtx, setSheetState, imageUrlController);
    } catch (e) {
      if (sheetCtx.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open camera: ${ErrorHelper.getMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadPickedImage(
    String path,
    BuildContext sheetCtx,
    StateSetter setSheetState,
    TextEditingController imageUrlController,
  ) async {
    setSheetState(() => _uploadingImage = true);
    try {
      final url = await ApiService.uploadImage(path, type: 'menu');
      imageUrlController.text = url;
      setSheetState(() {}); // refresh preview
    } catch (e) {
      if (sheetCtx.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image upload failed: ${ErrorHelper.getMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setSheetState(() => _uploadingImage = false);
    }
  }

  Widget _buildImagePickButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _uploadingImage ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.orangePale.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.orange, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogField(
    TextEditingController controller,
    String hint,
    TextInputType keyboard, {
    int maxLines = 1,
    String? prefix,
    Widget? suffix,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.darkGray.withValues(alpha: 0.5), fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixText: prefix,
          prefixStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.orange),
          suffixIcon: suffix,
        ),
      ),
    );
  }

  void _confirmDelete(dynamic item) {
    PremiumDialogs.showConfirm(
      context,
      title: 'Delete Item',
      message: 'Delete "${item['name']}" from your menu?',
      confirmText: 'Delete',
      icon: Icons.delete_outline_rounded,
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          await ApiService.businessDeleteMenuItem(item['id']);
          _loadMenu();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ErrorHelper.getMessage(e)), backgroundColor: Colors.red),
            );
          }
        }
      }
    });
  }
}