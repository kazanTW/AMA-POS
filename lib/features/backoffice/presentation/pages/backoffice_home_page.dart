import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BackofficeHomePage extends StatelessWidget {
  const BackofficeHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('商家後台'),
        leading: BackButton(onPressed: () => context.go('/cashier')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: GridView.count(
            padding: const EdgeInsets.all(24),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2,
            children: [
              _NavCard(
                title: '商品分類',
                icon: Icons.category,
                onTap: () => context.push('/backoffice/categories'),
              ),
              _NavCard(
                title: '商品管理',
                icon: Icons.inventory,
                onTap: () => context.push('/backoffice/products'),
              ),
              _NavCard(
                title: '班次管理',
                icon: Icons.work_history,
                onTap: () => context.push('/backoffice/shifts'),
              ),
              _NavCard(
                title: '每日報表',
                icon: Icons.bar_chart,
                onTap: () => context.push('/backoffice/reports'),
              ),
              _NavCard(
                title: '匯入/匯出',
                icon: Icons.import_export,
                onTap: () => context.push('/backoffice/import-export'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
