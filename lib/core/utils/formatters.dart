/// Formata uma duração em segundos como `MM:SS` ou `H:MM:SS`.
String formatDuration(int seconds) {
  final int safe = seconds < 0 ? 0 : seconds;
  final int hours = safe ~/ 3600;
  final int minutes = (safe % 3600) ~/ 60;
  final int secs = safe % 60;
  final String mm = minutes.toString().padLeft(2, '0');
  final String ss = secs.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

/// Converte uma duração legada no formato `MM:SS` (ou `H:MM:SS`) em segundos.
///
/// Versões antigas do app gravavam a duração como texto; a migração do banco
/// depende disso para não perder o histórico.
int parseDurationToSeconds(String? value) {
  if (value == null || value.trim().isEmpty) return 0;
  final List<String> parts = value.trim().split(':');
  int total = 0;
  for (final String part in parts) {
    final int? piece = int.tryParse(part.trim());
    if (piece == null) return 0;
    total = total * 60 + piece;
  }
  return total;
}

/// Data legível em pt-BR: `dd/MM/yyyy às HH:mm`.
String formatDateTime(DateTime value) {
  final DateTime local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      'às ${two(local.hour)}:${two(local.minute)}';
}

/// Data curta: `dd/MM/yyyy`.
String formatDate(DateTime value) {
  final DateTime local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

/// Iniciais para o avatar do perfil.
String initialsOf(String name) {
  final List<String> parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  String first(String word) => word.substring(0, 1).toUpperCase();
  if (parts.length == 1) return first(parts.first);
  return first(parts.first) + first(parts.last);
}
