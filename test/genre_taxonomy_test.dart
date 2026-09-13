import 'package:flutter_test/flutter_test.dart';
import 'package:audio_player/models/genre_taxonomy.dart';

void main() {
  group('GenreTaxonomy.normalizeOnline', () {
    test('маппит известные онлайн-жанры в таксономию', () {
      expect(GenreTaxonomy.normalizeOnline('Rock'), 'Rock');
      expect(GenreTaxonomy.normalizeOnline('hip-hop/rap'), 'Hip-Hop');
      expect(GenreTaxonomy.normalizeOnline('Hard Rock'), 'Rock');
      expect(GenreTaxonomy.normalizeOnline('Drum & Bass'), 'Drum & Bass');
      expect(GenreTaxonomy.normalizeOnline('chanson'), 'Chanson');
      expect(GenreTaxonomy.normalizeOnline('шансон'), 'Chanson');
      expect(GenreTaxonomy.normalizeOnline('SynthPop'), 'Synthwave');
    });

    test('null для неизвестных жанров (не кэшируем как жанр)', () {
      expect(GenreTaxonomy.normalizeOnline('unknown-weird-genre'), isNull);
      expect(GenreTaxonomy.normalizeOnline(''), isNull);
    });

    test('жанр из таксономии распознаётся подстрокой', () {
      expect(GenreTaxonomy.normalizeOnline('jazz fusion'), 'Jazz');
    });
  });

  group('GenreTaxonomy.guessFromText', () {
    test('угадывает жанр по исполнителю', () {
      expect(GenreTaxonomy.guessFromText('Rammstein - Sonne'), 'Metal');
      expect(GenreTaxonomy.guessFromText('queen bohemian'), 'Rock');
      expect(GenreTaxonomy.guessFromText('james brown live'), 'Funk');
    });

    test('более длинное совпадение приоритетнее короткого', () {
      // 'death' (Metal) vs 'death metal' — должен выиграть Metal,
      // но и 'black metal' тоже Metal — берём самое длинное совпадение.
      final r = GenreTaxonomy.guessFromText('black metal band');
      expect(r, 'Metal');
    });

    test('возвращает «Прочее» для нераспознаваемого текста', () {
      expect(GenreTaxonomy.guessFromText('xyz'), 'Прочее');
    });
  });
}