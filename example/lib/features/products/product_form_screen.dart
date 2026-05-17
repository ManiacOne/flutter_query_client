import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import '../../shared.dart';
import 'product_controllers.dart';
import 'product_model.dart';
import 'product_service.dart';

// Features demonstrated on this screen:
//  • MutationController lifecycle hooks — onSuccess / onMutationError / onSettled
//  • QueryListener  — navigate/show error on mutation completion
//  • QueryBuilder   — reflect mutation state in the submit button

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _stockCtrl;
  // Typed as base class so Create/Update share the same QueryBuilder type.
  late final MutationController<Product> _mutation;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _titleCtrl = TextEditingController(text: p?.title ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _priceCtrl = TextEditingController(text: p != null ? '${p.price}' : '');
    _categoryCtrl = TextEditingController(text: p?.category ?? '');
    _stockCtrl = TextEditingController(text: p != null ? '${p.stock}' : '0');
    _mutation = _isEditing ? UpdateProductMutation() : CreateProductMutation();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _categoryCtrl.dispose();
    _stockCtrl.dispose();
    _mutation.close();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_isEditing) {
      _mutation.mutate(
        () => productService.updateProduct(widget.product!.id, {
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'price': double.parse(_priceCtrl.text.trim()),
          'category': _categoryCtrl.text.trim(),
          'stock': int.parse(_stockCtrl.text.trim()),
        }),
      );
    } else {
      _mutation.mutate(
        () => productService.createProduct(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          price: double.parse(_priceCtrl.text.trim()),
          category: _categoryCtrl.text.trim(),
          stock: int.parse(_stockCtrl.text.trim()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return QueryListener<MutationController<Product>, Product>(
      bloc: _mutation,
      listenWhen: (prev, curr) => prev.isLoading && !curr.isLoading,
      listener: (ctx, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${state.error}')),
                ],
              ),
              backgroundColor: cs.error,
            ),
          );
        } else if (state.data != null) {
          Navigator.pop(ctx, state.data);
        }
      },
      child: QueryBuilder<MutationController<Product>, Product>(
        bloc: _mutation,
        builder:
            (context, state) => Scaffold(
              appBar: AppBar(
                title: Text(_isEditing ? 'Edit Product' : 'New Product'),
              ),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    // ── Feature banner ────────────────────────────
                    FeatureBanner(
                      features: [
                        FeatureItem(
                          Icons.notifications_outlined,
                          'MutationController hooks',
                          Colors.orange,
                        ),
                        FeatureItem(
                          Icons.hearing,
                          'QueryListener',
                          Colors.purple,
                        ),
                        FeatureItem(
                          Icons.build_outlined,
                          'QueryBuilder',
                          Colors.blue,
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _field(_titleCtrl, 'Title'),
                            const SizedBox(height: 12),
                            _field(_descCtrl, 'Description', maxLines: 3),
                            const SizedBox(height: 12),
                            _field(
                              _priceCtrl,
                              'Price',
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]')),
                              ],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                if (double.tryParse(v.trim()) == null) {
                                  return 'Must be a number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _field(_categoryCtrl, 'Category'),
                            const SizedBox(height: 12),
                            _field(
                              _stockCtrl,
                              'Stock',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                if (int.tryParse(v.trim()) == null) {
                                  return 'Must be an integer';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Submit button
                            FilledButton(
                              onPressed: state.isLoading ? null : _submit,
                              child:
                                  state.isLoading
                                      ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                      : Text(
                                          _isEditing ? 'Update' : 'Create',
                                        ),
                            ),

                            const SizedBox(height: 16),

                            // ── Mutation lifecycle tracker ────────────
                            // Visualises the MutationController state and
                            // shows which lifecycle hooks were called.
                            MutationPhaseBar(
                              isLoading: state.isLoading,
                              isSuccess: state.isSuccess,
                              isError: state.isError,
                            ),

                            if (state.isSuccess) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'QueryListener detected success and called '
                                  'Navigator.pop(result) to return the product '
                                  'to the caller.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
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

  Widget _field(
    TextEditingController ctrl,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1,
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator:
          validator ?? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }
}
