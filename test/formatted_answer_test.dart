import 'package:flutter_test/flutter_test.dart';
import 'package:tellmemore/ui/formatted_answer.dart';

void main() {
  group('FormattedAnswerView parsing tests', () {
    test('Parses plain text with code fences into code blocks and text blocks', () {
      const input = '''
Here is the solution to your algorithm:
```python
def two_sum(nums, target):
    seen = {}
    for i, n in enumerate(nums):
        if target - n in seen:
            return [seen[target - n], i]
        seen[n] = i
```
Time complexity is O(n).
''';

      final blocks = FormattedAnswerView.parseBlocksForTesting(input);
      expect(blocks.length, equals(3));

      expect(blocks[0].isCode, isFalse);
      expect(blocks[0].content, contains('Here is the solution'));

      expect(blocks[1].isCode, isTrue);
      expect(blocks[1].language, equals('PYTHON'));
      expect(blocks[1].content, contains('def two_sum'));

      expect(blocks[2].isCode, isFalse);
      expect(blocks[2].content, contains('Time complexity is O(n)'));
    });

    test('Parses multiple consecutive code blocks with different languages', () {
      const input = '''
```sql
SELECT * FROM users WHERE active = 1;
```
```dart
void main() => print("Hello");
```
''';

      final blocks = FormattedAnswerView.parseBlocksForTesting(input);
      expect(blocks.length, equals(2));
      expect(blocks[0].language, equals('SQL'));
      expect(blocks[1].language, equals('DART'));
    });
  });
}
