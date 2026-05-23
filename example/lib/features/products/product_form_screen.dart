import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import '../../shared.dart';
import 'product_controllers.dart';
import 'product_model.dart';

// Features demonstrated on this screen:
//  • MutationController<T, P> with typed params — mutationFn override
//  • context.query<T>().mutate(params) — consistent with QueryController
//  • QueryListener  — navigate/show error on mutation completion
//  • QueryBuilder   — reflect mutation state in the submit button

class ProductFormScreen extends StatelessWidget {
  const ProductFormScreen({super.key, this.product});
  final Product? product;
  @override
  Widget build(BuildContext context) {
    return MultiQueryProvider(
      providers: [
        QueryProvider(create: (_) => UpdateProductMutation()),
        QueryProvider(create: (_) => CreateProductMutation()),
      ],
      child: _ProductFormScreenBody(product: product),
    );
  }
}

class _ProductFormScreenBody extends StatefulWidget {
  final Product? product;
  const _ProductFormScreenBody({this.product});

  @override
  State<_ProductFormScreenBody> createState() => _ProductFormScreenBodyState();
}

class _ProductFormScreenBodyState extends State<_ProductFormScreenBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _stockCtrl;

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
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _categoryCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    if (_isEditing) {
      context.query<UpdateProductMutation>().mutate((
        id: widget.product!.id,
        fields: {
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'price': double.parse(_priceCtrl.text.trim()),
          'category': _categoryCtrl.text.trim(),
          'stock': int.parse(_stockCtrl.text.trim()),
        },
      ));
    } else {
      context.query<CreateProductMutation>().mutate((
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: double.parse(_priceCtrl.text.trim()),
        category: _categoryCtrl.text.trim(),
        stock: int.parse(_stockCtrl.text.trim()),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MultiQueryListener(
      listeners: [
        QueryListener<UpdateProductMutation, Product>(
          listener: (ctx, state) {
            if (state.error != null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${state.error}')),
                    ],
                  ),
                  backgroundColor: cs.error,
                ),
              );
            } else if (state.data != null) {
              QueryClient.instance.updateInfiniteQuery<Product>('products', (
                pages,
              ) {
                if (pages.isEmpty) {
                  return [
                    [state.data!],
                  ];
                }
                return [
                  [state.data!, ...pages[0]],
                  ...pages.sublist(1),
                ];
              });

              Navigator.pop(ctx, state.data);
            }
          },
        ),
        QueryListener<CreateProductMutation, Product>(
          listener: (ctx, state) {
            if (state.error != null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${state.error}')),
                    ],
                  ),
                  backgroundColor: cs.error,
                ),
              );
            } else if (state.data != null) {
              QueryClient.instance.updateInfiniteQuery<Product>('products', (
                pages,
              ) {
                if (pages.isEmpty) {
                  return [
                    [state.data!],
                  ];
                }
                return [
                  [state.data!, ...pages[0]],
                  ...pages.sublist(1),
                ];
              });

              Navigator.pop(ctx, state.data);
            }
          },
        ),
      ],
      child: Scaffold(
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
                    'MutationController<T, P>',
                    Colors.orange,
                  ),
                  FeatureItem(Icons.hearing, 'QueryListener', Colors.purple),
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
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
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
                        onPressed:
                            context
                                        .queryWatch<CreateProductMutation>()
                                        .state
                                        .isLoading ||
                                    context
                                        .queryWatch<UpdateProductMutation>()
                                        .state
                                        .isLoading
                                ? null
                                : () => _submit(context),
                        child:
                            context
                                        .queryWatch<CreateProductMutation>()
                                        .state
                                        .isLoading ||
                                    context
                                        .queryWatch<UpdateProductMutation>()
                                        .state
                                        .isLoading
                                ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Text(_isEditing ? 'Update' : 'Create'),
                      ),

                      const SizedBox(height: 16),

                      // ── Mutation lifecycle tracker ────────────
                      MutationPhaseBar(
                        isLoading:
                            context
                                .queryWatch<CreateProductMutation>()
                                .state
                                .isLoading ||
                            context
                                .queryWatch<UpdateProductMutation>()
                                .state
                                .isLoading,
                        isSuccess:
                            context
                                .queryWatch<CreateProductMutation>()
                                .state
                                .isSuccess ||
                            context
                                .queryWatch<UpdateProductMutation>()
                                .state
                                .isSuccess,
                        isError:
                            context
                                .queryWatch<CreateProductMutation>()
                                .state
                                .isError ||
                            context
                                .queryWatch<UpdateProductMutation>()
                                .state
                                .isError,
                      ),

                      if (context
                              .queryWatch<CreateProductMutation>()
                              .state
                              .isSuccess ||
                          context
                              .queryWatch<UpdateProductMutation>()
                              .state
                              .isSuccess) ...[
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
                            style: TextStyle(fontSize: 11, color: Colors.green),
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
          validator ??
          (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }
}
