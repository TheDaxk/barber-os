import 'package:flutter/material.dart';

/// Widget de cabeçalho padrão para todas as telas (exceto Home).
/// Exibe o título em dourado com negrito, subtítulo opcional em cinza.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  static const Color _gold = Color(0xFFD4AF37);

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _gold,
              letterSpacing: -0.5,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
