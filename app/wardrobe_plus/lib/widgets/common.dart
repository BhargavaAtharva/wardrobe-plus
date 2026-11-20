import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/server_settings_screen.dart';
import '../services/catalog.dart';
import '../services/image_store.dart';
import '../theme.dart';

/// "ACLOSET AI" header row used at the top of each tab.
class BrandBar extends StatelessWidget {
  final Widget? trailing;
  const BrandBar({super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text('ACLOSET AI', style: AppText.brand()), if (trailing != null) trailing!],
      ),
    );
  }
}

/// A clothing photo from storage, or a placeholder if the file is missing.
class ItemImage extends StatelessWidget {
  final String? stored;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final double iconSize;

  const ItemImage({
    super.key,
    required this.stored,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.iconSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    final file = ImageStore.resolve(stored);
    return ClipRRect(
      borderRadius: borderRadius,
      child: file != null
          ? Image.file(file, width: width, height: height, fit: BoxFit.cover)
          : Container(
              width: width,
              height: height,
              color: AppColors.sand,
              child: Icon(Icons.checkroom, size: iconSize, color: AppColors.ink),
            ),
    );
  }
}

/// Small round swatch for a colour name ("multicolor" shows a gradient).
class ColorDot extends StatelessWidget {
  final String? color;
  final double size;
  const ColorDot(this.color, {super.key, this.size = 12});

  @override
  Widget build(BuildContext context) {
    final swatch = Catalog.colors[color];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: swatch ?? (color == 'multicolor' ? null : AppColors.outline),
        gradient: color == 'multicolor'
            ? const SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red])
            : null,
        border: Border.all(color: AppColors.outline, width: 0.8),
      ),
    );
  }
}

class TagChip extends StatelessWidget {
  final String label;
  final String? colorDot;
  const TagChip(this.label, {super.key, this.colorDot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (colorDot != null) ...[ColorDot(colorDot), const SizedBox(width: 6)],
          Text(label, style: AppText.body(size: 12, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Selectable pill used for filters, occasions, types and colours.
class SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  const SelectChip({super.key, required this.label, required this.selected, required this.onTap, this.leading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.black : AppColors.sand,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w500, color: selected ? Colors.white : AppColors.ink)),
          ],
        ),
      ),
    );
  }
}

/// Pick a clothing type.
class TypeSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;
  const TypeSelector({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: Catalog.types
          .map((t) => SelectChip(label: Catalog.typeLabel(t), selected: t == selected, onTap: () => onChanged(t)))
          .toList(),
    );
  }
}

/// Pick a colour.
class ColorSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;
  const ColorSelector({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: Catalog.colorNames
          .map((c) => SelectChip(
                label: Catalog.colorLabel(c),
                selected: c == selected,
                onTap: () => onChanged(c),
                leading: ColorDot(c),
              ))
          .toList(),
    );
  }
}

/// Error box with an optional retry and a shortcut to the server settings.
class ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool showServerSettings;
  const ErrorCard({super.key, required this.message, this.onRetry, this.showServerSettings = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: AppText.body(size: 13, color: AppColors.errorText)),
          if (onRetry != null || showServerSettings) const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: Text('Try again', style: AppText.body(size: 13, weight: FontWeight.w600))),
              if (showServerSettings)
                TextButton(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const ServerSettingsScreen())),
                  child: Text('Server address', style: AppText.body(size: 13, weight: FontWeight.w600)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.outline),
          const SizedBox(height: 16),
          Text(title, style: AppText.title(20).copyWith(color: AppColors.inkSoft), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle, style: AppText.body(size: 13, color: AppColors.muted), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Compact card: photo + type + colour. Used for horizontal lists.
class ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String? caption;
  final VoidCallback? onTap;
  const ItemCard({super.key, required this.item, this.caption, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 116,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: cardShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ItemImage(
                stored: item['imagePath'] as String?,
                width: double.infinity,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    ColorDot(item['color'] as String?, size: 9),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(Catalog.typeLabel(item['type'] as String?),
                          style: AppText.body(size: 11, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  if (caption != null)
                    Text(caption!, style: AppText.body(size: 10, color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
