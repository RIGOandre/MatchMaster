import 'package:flutter/material.dart';

/// Paleta do MatchMaster.
///
/// A identidade antiga era um amarelo só: título, borda, botão, ícone e texto
/// usavam a mesma cor, então nada tinha peso maior que o resto. A paleta nova
/// parte da ideia do próprio app — dois lados disputando — e dá uma cor para
/// cada lado: **clay** (o saibro) contra **teal** (a quadra rápida). O amarelo
/// vira o destaque de conquista, não mais o plano de fundo de tudo.
abstract final class AppColors {
  // ---------------------------------------------------------------- base ---
  /// Fundo do tema escuro.
  static const Color ink900 = Color(0xFF0C1015);

  /// Superfície (cartões) no tema escuro.
  static const Color ink800 = Color(0xFF141A21);

  /// Superfície elevada / seleção no tema escuro.
  static const Color ink700 = Color(0xFF1E262F);

  /// Texto e ícones sobre as cores de marca.
  static const Color ink = Color(0xFF0C1015);

  /// Fundo do tema claro — papel levemente quente, não branco puro.
  static const Color paper = Color(0xFFFAF7F3);
  static const Color paperSurface = Color(0xFFFFFFFF);

  // --------------------------------------------------------------- marca ---
  /// Primária no escuro: laranja de saibro.
  static const Color clay = Color(0xFFFF6B35);

  /// Primária no claro — escurecida para manter contraste sobre papel.
  static const Color clayDeep = Color(0xFFC2410C);

  /// Secundária no escuro: verde-água de quadra rápida.
  static const Color teal = Color(0xFF14C8A6);

  /// Secundária no claro.
  static const Color tealDeep = Color(0xFF0F766E);

  /// Destaque de conquista — herança do amarelo original.
  static const Color amber = Color(0xFFFFC53D);
  static const Color amberDeep = Color(0xFFB45309);

  // ------------------------------------------------------------ semântico ---
  static const Color danger = Color(0xFFF2545B);
  static const Color dangerDeep = Color(0xFFB91C1C);

  /// Cor do time 1 (esquerda do placar).
  static Color team1(Brightness brightness) =>
      brightness == Brightness.dark ? clay : clayDeep;

  /// Cor do time 2 (direita do placar).
  static Color team2(Brightness brightness) =>
      brightness == Brightness.dark ? teal : tealDeep;

  /// Cor de conquista (vencedor, líder, troféu).
  static Color highlight(Brightness brightness) =>
      brightness == Brightness.dark ? amber : amberDeep;
}

/// Par de cores que troca conforme o tema.
@immutable
class ThemedColor {
  const ThemedColor(this.dark, this.light);

  final Color dark;
  final Color light;

  Color of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  Color ofContext(BuildContext context) => of(Theme.of(context).brightness);
}
