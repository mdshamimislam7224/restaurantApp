import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'Category.dart';

class CategoryManagerScreen extends StatefulWidget {
  const CategoryManagerScreen({Key? key}) : super(key: key);

  @override
  State<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends State<CategoryManagerScreen> {
  final TextEditingController _nameController = TextEditingController();
  final String scriptUrl = "https://script.google.com/macros/s/AKfycbwF-ApiZXB8j9N_mnTPKHITcXqseEbptEoF4Kob_ejquN2Uesu1_O7HkL4xUMVI5T5NZQ/exec";

  List<Category> categories = [];
  Category? selectedCategory;
  bool _loading = false;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _searchController = TextEditingController();
  String _currentSearchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await fetchCategories();
    setState(() => _loading = false);
  }

  Future<void> fetchCategories() async {
    try {
      final res = await http.get(Uri.parse("$scriptUrl?action=getCategories"));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          categories = data.map((e) => Category.fromJson(e)).toList();
        });
      }
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  Future<void> _refreshData() async {
    await fetchCategories();
  }

  Future<void> addCategory(String name) async {
    if (name.isEmpty) return;

    setState(() => _loading = true);
    try {
      final res = await http.post(Uri.parse("$scriptUrl?action=addCategory&name=$name"));

      if (res.statusCode == 200 || res.statusCode == 302) {
        // Option 1: Add optimistically for immediate UI update
        final newCategory = Category(
          id: DateTime.now().millisecondsSinceEpoch, // Temporary ID
          name: name,
        );
        setState(() {
          categories.insert(0, newCategory);
          _nameController.clear();
        });

        // Option 2: Then refresh from server
        await _refreshData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category added successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding category: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> updateCategory(int id, String name) async {
    if (name.isEmpty) return;

    setState(() => _loading = true);

    try {
      final res = await http.post(Uri.parse("$scriptUrl?action=updateCategory&id=$id&name=$name"));
      print('Status Code updateCategory: ${res.statusCode}');
      if (res.statusCode == 200 || res.statusCode == 302) {
        await _refreshData();
        _nameController.clear();
        setState(() => selectedCategory = null);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category updated successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating category: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> deleteCategory(int id) async {
    setState(() => _loading = true);
    try {
      final res = await http.post(Uri.parse("$scriptUrl?action=deleteCategory&id=$id"));
      print('status Code Delete:${res.statusCode}');
      if (res.statusCode == 200 || res.statusCode == 302) {
        // Option 1: Remove optimistically
        setState(() {
          categories.removeWhere((cat) => cat.id == id);
          if (selectedCategory?.id == id) {
            selectedCategory = null;
            _nameController.clear();
          }
        });

        // Option 2: Then refresh from server
        await _refreshData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category deleted successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting category: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Column(
        children: [
          // Search Bar - Added at the top
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _currentSearchTerm = value;
                });
              },
            ),
          ),
          // Main Content Area
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 400;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildCategoryList(),
          ),
        ),
        Flexible(
          flex: 1,
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildForm(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        Expanded(child: _buildCategoryList()),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildForm(),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryList() {
    if (categories.isEmpty && !_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No Categories Yet",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            const Text("Add your first category to get started"),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 8),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return Dismissible(
            key: ValueKey(cat.id),
            background: Container(
              color: Theme.of(context).colorScheme.errorContainer,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              return await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Confirm Delete"),
                  content: const Text("Are you sure you want to delete this category?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text("Delete"),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (_) => deleteCategory(cat.id),
            child: InkWell(
              onTap: () {
                setState(() {
                  selectedCategory = cat;
                  _nameController.text = cat.name;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: selectedCategory?.id == cat.id
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        cat.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () {
                        setState(() {
                          selectedCategory = cat;
                          _nameController.text = cat.name;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            selectedCategory != null ? "Edit Category" : "New Category",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: "Category Name",
              border: const OutlineInputBorder(),
              filled: true,
              prefixIcon: const Icon(Icons.category),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a category name';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                if (selectedCategory != null) {
                  updateCategory(selectedCategory!.id, _nameController.text);
                } else {
                  addCategory(_nameController.text);
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(selectedCategory != null ? "UPDATE" : "ADD"),
            ),
          ),
          if (selectedCategory != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  selectedCategory = null;
                  _nameController.clear();
                });
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text("CANCEL"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}