import 'package:flutter/material.dart';

import '../api/cartly_api.dart';
import 'add_item_sheet.dart';
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

  Future<void> _showAddItem() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddItemSheet(onAdd: _controller.addItem),
    );
  }
  Future<void> _confirmClearBought() async {
    final count = _controller.boughtCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear bought items?'),
        content: Text(
          'Are you sure you want to remove $count bought item${count == 1 ? '' : 's'} from your list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear items'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _runAction(_controller.clearBought);
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
    } on CartlyApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cartly',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    if (_controller.status != ShoppingListStatus.ready) {
                      return const SizedBox.shrink();
                    }
                    final unbought = _controller.unboughtCount;
                    return Text(
                      unbought == 0
                          ? 'All items in cart!'
                          : '$unbought item${unbought == 1 ? '' : 's'} to buy',
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => IconButton(
              tooltip: 'Refresh list',
              onPressed:
                  _controller.status == ShoppingListStatus.loading ||
                      _controller.isMutating ||
                      _controller.hasPendingDeletes ||
                      _controller.isRefreshing
                  ? null
                  : () => _controller.load(),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Column(
            children: [
              if (_controller.isMutating ||
                  _controller.isRefreshing ||
                  _controller.hasPendingDeletes)
                const LinearProgressIndicator(),
              if (_controller.status == ShoppingListStatus.ready &&
                  _controller.errorMessage != null)
                MaterialBanner(
                  content: Text(_controller.errorMessage!),
                  actions: [
                    TextButton(
                      onPressed:
                          _controller.isRefreshing ||
                              _controller.hasPendingDeletes
                          ? null
                          : () => _controller.load(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => FloatingActionButton.extended(
          onPressed:
              _controller.status == ShoppingListStatus.loading ||
                  _controller.isMutating ||
                  _controller.hasPendingDeletes
              ? null
              : _showAddItem,
          icon: const Icon(Icons.add),
          label: const Text('Add item'),
        ),
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
        final items = _controller.items;
        if (items.isEmpty) {
          return _controller.hasPendingDeletes
              ? const _CenteredMessage(
                  icon: Icons.delete_outline,
                  title: 'Deleting items…',
                  detail: 'Your list will update shortly.',
                )
              : const _CenteredMessage(
                  icon: Icons.shopping_basket_outlined,
                  title: 'Your list is empty',
                  detail: 'Items you add will appear here.',
                );
        }

        final unboughtItems = items.where((i) => !i.isBought).toList();
        final boughtItems = items.where((i) => i.isBought).toList();

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                children: [
                  if (unboughtItems.isNotEmpty) ...[
                    _SectionHeader(
                      title: '🛒 To Buy',
                      count: unboughtItems.length,
                    ),
                    const SizedBox(height: 8),
                    ...unboughtItems.map((item) => _buildItemTile(context, item)),
                    const SizedBox(height: 16),
                  ],
                  if (boughtItems.isNotEmpty) ...[
                    _SectionHeader(
                      title: '✔️ In Your Cart',
                      count: boughtItems.length,
                      trailing: TextButton.icon(
                        onPressed:
                            _controller.isMutating ||
                                _controller.hasPendingDeletes
                            ? null
                            : _confirmClearBought,
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Clear bought'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...boughtItems.map((item) => _buildItemTile(context, item)),
                  ],
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _buildItemTile(BuildContext context, ShoppingItem item) {
    final bought = item.isBought;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bought
            ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: ListTile(
        key: ValueKey(item.id),
        leading: IconButton(
          tooltip: bought
              ? 'Take ${item.name} out of cart'
              : 'Put ${item.name} in cart',
          icon: Icon(
            bought ? Icons.shopping_cart : Icons.add_shopping_cart_outlined,
            color: bought
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onPressed:
              _controller.isMutating || _controller.hasPendingDeletes
              ? null
              : () => _runAction(() => _controller.toggleBought(item)),
        ),
        title: Text(
          item.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: bought
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Theme.of(context).colorScheme.outline,
                )
              : const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Quantity: ${item.quantity} · ${bought ? 'Bought' : 'To buy'}',
        ),
        trailing: IconButton(
          tooltip: 'Delete ${item.name}',
          onPressed: _controller.isMutating
              ? null
              : () => _runAction(() => _controller.deleteItem(item)),
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    this.trailing,
  });

  final String title;
  final int count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing!,
        ],
      ],
    );
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
