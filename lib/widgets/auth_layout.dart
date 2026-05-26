import 'package:flutter/material.dart';

class AuthLayout extends StatelessWidget {
  final IconData? icon;
  final Widget? brandMark;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final bool showBackButton;

  const AuthLayout({
    super.key,
    this.icon,
    this.brandMark,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.showBackButton = false,
  })  : assert(icon != null || brandMark != null,
            'Either icon or brandMark must be provided.');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 820;
            final content = isWide
                ? Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: _BrandPanel(
                            compact: false,
                            icon: icon,
                            brandMark: brandMark,
                            title: 'MoneyFlow',
                            subtitle: 'Cashflow lebih tertata.',
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: _AuthPanel(
                          title: title,
                          subtitle: subtitle,
                          footer: footer,
                          showBackButton: showBackButton,
                          child: child,
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 44,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _BrandPanel(
                            compact: true,
                            icon: icon,
                            brandMark: brandMark,
                            title: 'MoneyFlow',
                            subtitle: 'Cashflow lebih tertata.',
                          ),
                          const SizedBox(height: 22),
                          _AuthPanel(
                            title: title,
                            subtitle: subtitle,
                            footer: footer,
                            showBackButton: showBackButton,
                            child: child,
                          ),
                        ],
                      ),
                    ),
                  );

            return ColoredBox(color: colors.surface, child: content);
          },
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  final bool compact;
  final IconData? icon;
  final Widget? brandMark;
  final String title;
  final String subtitle;

  const _BrandPanel({
    required this.compact,
    this.icon,
    this.brandMark,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (compact) {
      return Column(
        children: [
          if (brandMark != null)
            _BrandMark(
              foreground: colors.onPrimary,
              size: 84,
              child: brandMark,
            )
          else
            _BrandMark(icon: icon!, foreground: colors.onPrimary, size: 84),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [colors.primary, colors.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (brandMark != null)
              _BrandMark(
                foreground: colors.onPrimary,
                background: colors.onPrimary.withValues(alpha: 0.16),
                child: brandMark,
              )
            else
              _BrandMark(
                icon: icon!,
                foreground: colors.onPrimary,
                background: colors.onPrimary.withValues(alpha: 0.16),
              ),
            const Spacer(),
            Text(
              title,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: colors.onPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.onPrimary.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final Color foreground;
  final Color? background;
  final double size;

  const _BrandMark({
    this.icon,
    this.child,
    required this.foreground,
    this.background,
    this.size = 84,
  }) : assert(icon != null || child != null,
            'Either icon or child must be provided.');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? colors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: child ?? Icon(icon, color: foreground, size: size * 0.4),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final bool showBackButton;

  const _AuthPanel({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
    required this.showBackButton,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showBackButton && Navigator.canPop(context)) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton.filledTonal(
                    tooltip: 'Kembali',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: TextStyle(color: colors.onSurfaceVariant)),
              const SizedBox(height: 24),
              child,
              if (footer != null) ...[const SizedBox(height: 14), footer!],
            ],
          ),
        ),
      ),
    );
  }
}
