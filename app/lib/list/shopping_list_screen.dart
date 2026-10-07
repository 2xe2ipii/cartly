import 'package:flutter/material.dart';

import '../api/cartly_api.dart';
import 'shopping_list_controller.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key, required this.api});

  final CartlyApi api;

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  late final ShoppingListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ShoppingListController(widget.api);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.load();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('My list'),
          actions: [
            IconButton(
              tooltip: 'Refresh list',
              onPressed: _controller.status == ShoppingListStatus.loading
                  ? null
                  : () => _controller.load(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_controller.status) {
      case ShoppingListStatus.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your list…'),
            ],
          ),
        );
      case ShoppingListStatus.error:
        return _CenteredMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Couldn’t load your list',
          detail: _controller.errorMessage ?? 'Please try again.',
          action: FilledButton(
            onPressed: () => _controller.load(),
            child: const Text('Try again'),
          ),
        );
      case ShoppingListStatus.ready:
        if (_controller.items.isEmpty) {
          return const _CenteredMessage(
            icon: Icons.shopping_basket_outlined,
            title: 'Your list is empty',
            detail: 'Items you add will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _controller.items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = _controller.items[index];
            final bought = item.isBought;
            return ListTile(
              leading: Icon(
                bought ? Icons.check_circle : Icons.radio_button_unchecked,
                semanticLabel: bought ? 'Bought' : 'Not bought',
                color: bought ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: bought
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null,
              ),
              subtitle: Text(
                'Quantity: ${item.quantity} · ${bought ? 'Bought' : 'To buy'}',
              ),
            );
          },
        );
    }
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(detail, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
