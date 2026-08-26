import 'package:flutter_test/flutter_test.dart';
import 'package:matchmaster/core/utils/formatters.dart';

void main() {
  group('formatDuration', () {
    test('formata minutos e segundos', () {
      expect(formatDuration(0), '00:00');
      expect(formatDuration(9), '00:09');
      expect(formatDuration(65), '01:05');
      expect(formatDuration(599), '09:59');
    });

    test('inclui horas quando necessário', () {
      expect(formatDuration(3600), '1:00:00');
      expect(formatDuration(3725), '1:02:05');
    });

    test('valores negativos viram zero', () {
      expect(formatDuration(-10), '00:00');
    });
  });

  group('parseDurationToSeconds', () {
    test('lê o formato legado MM:SS', () {
      expect(parseDurationToSeconds('01:05'), 65);
      expect(parseDurationToSeconds('00:00'), 0);
      expect(parseDurationToSeconds('12:30'), 750);
    });

    test('lê H:MM:SS', () {
      expect(parseDurationToSeconds('1:02:05'), 3725);
    });

    test('entradas inválidas viram zero', () {
      expect(parseDurationToSeconds(null), 0);
      expect(parseDurationToSeconds(''), 0);
      expect(parseDurationToSeconds('abc'), 0);
    });

    test('ida e volta preserva o valor', () {
      for (final int seconds in <int>[0, 7, 61, 599, 3725]) {
        expect(parseDurationToSeconds(formatDuration(seconds)), seconds);
      }
    });
  });

  group('initialsOf', () {
    test('usa primeiro e último nome', () {
      expect(initialsOf('André Rigo'), 'AR');
      expect(initialsOf('André Luiz Rigo'), 'AR');
      expect(initialsOf('André'), 'A');
      expect(initialsOf('  '), '?');
    });
  });

  test('formatDate usa o padrão brasileiro', () {
    expect(formatDate(DateTime(2024, 3, 7)), '07/03/2024');
  });
}
