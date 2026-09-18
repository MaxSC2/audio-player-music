/// Rec 5 (pure helpers): отображаемые имена для Коллекции как чистые функции
/// без состояния провайдера — тестируются без платформы.
class DisplayNames {
  /// «Сырые» значения, которые MediaStore часто кладёт в album/artist:
  /// мусор вида `[muzmo…`, `(www.…`, кавычки, `#тег…` и запасной индекс песни.
  static const unknownArtistRaw = '<unknown>';

  /// Человеко-читаемое имя альбома для витрины.
  ///
  /// Правила:
  /// - пусто / `<unknown>` → «Без альбома» (фолбэк на имя файла — в [fileTitle]);
  /// - ведущий файловый/теговый мусор (`[…]`, `(…)`, `"…"`, `'…`, `«…`, `#…`)
  ///   срезается целиком до разделителя (`-`, `–`, `—`); внутри скобок текст
  ///   вида `слово.слово` (сайт без пробелов) тоже игнорируется;
  /// - если после обрезки осталось <3 значимых символов — оставляем оригинал;
  /// - остальное — как есть (нормальных названий не касаемся).
  static String album(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty || s.toLowerCase() == unknownArtistRaw) return 'Без альбома';
    var t = s;
    if (t.startsWith('[') || t.startsWith('(')) {
      final close = t.startsWith('[') ? t.indexOf(']') : t.indexOf(')');
      if (close > 0) {
        // «[muzmo.ru] - GOLDEN HITS» → «GOLDEN HITS»,
        // «(www.LO…com) Best» → «Best», «Сборник (2023)» не трогаем.
        final rest = t.substring(close + 1).trimLeft();
        final dashCut = rest.indexOf(RegExp('^\\s*-{1,2}\\s*'));
        final cleaned = (dashCut == 0
                ? rest.replaceFirst(RegExp('^-{1,2}\\s*'), '')
                : rest)
            .trim();
        if (_significant(cleaned) >= 3) t = cleaned;
      }
    } else if (t.startsWith('"') ||
        t.startsWith("'") ||
        t.startsWith('«') ||
        t.startsWith('#')) {
      // `"GOLDEN OLDIES" vol.2` → `OLDIES" vol.2`,
      // `#райодиннаш TOP 100` → `TOP 100`.
      final cut = t.indexOf(RegExp('[\\s\\-–—]'));
      final rest = (cut > 0 ? t.substring(cut + 1) : '').trim();
      if (_significant(rest) >= 3) t = rest;
    }
    return t.isEmpty ? 'Без альбома' : t;
  }

  /// Значимые символы для порога «мусор/не мусор» (буквы и цифры).
  static int _significant(String s) =>
      s.replaceAll(RegExp('[^0-9A-Za-zА-Яа-яЁё]'), '').length;

  /// Имя исполнителя для витрины: пусто / `<unknown>` → «Неизвестный исполнитель».
  static String artist(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty || s.toLowerCase() == unknownArtistRaw) {
      return 'Неизвестный исполнитель';
    }
    return s;
  }

  /// Заголовок из имени файла: `…/101 Ibiza - Modjo.mp3` → `101 Ibiza - Modjo`.
  /// Возвращает null, если путь непригоден для показа.
  static String? fileTitle(String? path) {
    if (path == null || path.isEmpty) return null;
    var name = path.split('/').last.trim();
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    name = name.replaceAll('_', ' ').replaceAll(RegExp('\\s+'), ' ').trim();
    if (name.length < 3) return null;
    return name;
  }

  /// Русская плюрализация: (1 трек, 3 трека, 7 треков).
  static String plural(int count, String one, String few, String many) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return few;
    }
    return many;
  }

  /// «N треков» для подписей.
  static String tracks(int count) =>
      '$count ${plural(count, 'трек', 'трека', 'треков')}';

  /// «N альбомов» для подписей.
  static String albums(int count) =>
      '$count ${plural(count, 'альбом', 'альбома', 'альбомов')}';
}