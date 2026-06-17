// Verifies the app's SSE path against the LIVE backend. Run: dart run tool/live_check.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const _url = 'https://your-project-ref.supabase.co/functions/v1/chat';
const _key = 'sb_publishable_REDACTED';

Future<void> main() async {
  final req = http.Request('POST', Uri.parse(_url));
  req.headers.addAll({
    'Authorization': 'Bearer $_key',
    'apikey': _key,
    'Content-Type': 'application/json',
    'Accept': 'text/event-stream',
  });
  req.body = jsonEncode({
    'message': 'What is an isotope?',
    'memory_md': '',
    'history': [],
    'answer_style': 'direct',
  });

  final resp = await http.Client().send(req);
  stderr.writeln('HTTP ${resp.statusCode}');
  var event = '';
  final answer = StringBuffer();
  var citations = 0;
  await for (final line
      in resp.stream.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      final data = line.substring(5).trim();
      if (event == 'token') {
        answer.write((jsonDecode(data)['t'] ?? '').toString());
      } else if (event == 'citations') {
        final list = jsonDecode(data);
        if (list is List) citations = list.length;
      }
    }
  }
  final preview = answer.toString().substring(0, answer.length.clamp(0, 160));
  stdout.writeln('ANSWER (${answer.length} chars): $preview');
  stdout.writeln('CITATIONS: $citations');
}
