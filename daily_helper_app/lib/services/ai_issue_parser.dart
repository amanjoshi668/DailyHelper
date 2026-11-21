import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'gcp_backend_service.dart';

class AiIssueParser {
  static AiParseSuggestion? parseDeterministic(String rawInput) {
    final q = rawInput.trim();
    if (q.isEmpty) return null;
    final lower = q.toLowerCase();

    final matchedTrades = <String>[];
    if (RegExp(r'(bijli|switch|spark|mcb|fan|pankha|light|inverter|wiring|wire|socket|regulator|electric|बिजली|स्विच|पंखा|गीज़र|तार)')
        .hasMatch(lower)) {
      matchedTrades.add('electrician');
    }
    if (RegExp(r'(tap|nal|leak|paani|pani|flush|pipe|sink|clog|block|motor|tank|plumb|नल|पानी|लीक|पाइप|फ्लश|सिंक)')
        .hasMatch(lower)) {
      matchedTrades.add('plumber');
    }
    if (RegExp(r'(door|lock|hinge|almari|almirah|cupboard|wood|bed|curtain|drawer|carpent|दरवाजा|अलमारी|लॉक|कब्जा|बेड|लकड़ी)')
        .hasMatch(lower)) {
      matchedTrades.add('carpenter');
    }
    if (RegExp(r'(ac\b|a/c|cooling|fridge|washing|ro\b|purifier|geyser|gas|appliance|एसी|कूलिंग|फ्रिज|वाशिंग)')
        .hasMatch(lower)) {
      matchedTrades.add('appliance');
    }
    if (RegExp(r'(paint|seepage|damp|putty|पेंट|सीलन|पुट्टी)').hasMatch(lower)) {
      matchedTrades.add('painter');
    }

    String? slotHint;
    if (RegExp(r'(morning|subah|9 am|10 am|सुबह)').hasMatch(lower)) {
      slotHint = '09:00 - 11:00 AM';
    } else if (RegExp(r'(noon|11 am|12 pm)').hasMatch(lower)) {
      slotHint = '11:00 - 01:00 PM';
    } else if (RegExp(r'(afternoon|dopahar|2 pm|दोपहर)').hasMatch(lower)) {
      slotHint = '02:00 - 04:00 PM';
    } else if (RegExp(r'(evening|shaam|4 pm|5 pm|शाम)').hasMatch(lower)) {
      slotHint = '04:00 - 06:00 PM';
    }

    if (matchedTrades.isEmpty) return null;

    final tier = matchedTrades.length > 1
        ? 'Tier 2 · Compound Classifier (0 ms)'
        : 'Tier 1 · Deterministic Match (0 ms)';

    return AiParseSuggestion(
      trade: matchedTrades.first,
      preferredSlot: slotHint,
      summaryNote: q,
      tierLabel: tier,
    );
  }

  static Future<AiParseSuggestion?> parseHybrid(String rawInput) async {
    final local = parseDeterministic(rawInput);
    final words = rawInput.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
    if (words < 10) {
      return local;
    }

    try {
      final uri = Uri.parse('${GcpBackendService.baseUrl}/api/v1/dailyhelper/ai-parse');
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': rawInput.trim()}),
          )
          .timeout(const Duration(milliseconds: 2800));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final trade = (data['trade'] ?? local?.trade ?? 'electrician').toString();
        final summary = (data['summaryNote'] ?? rawInput.trim()).toString();
        return AiParseSuggestion(
          trade: trade,
          preferredSlot: local?.preferredSlot,
          summaryNote: summary,
          tierLabel: 'Tier 3 · Gemini Flash-Lite (\$0.00)',
        );
      }
    } catch (_) {}
    return local;
  }
}
