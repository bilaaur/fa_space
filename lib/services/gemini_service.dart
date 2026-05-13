import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  Future<Map<String, dynamic>> getResolution(String problem) async {
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system('''
        You are an expert in relationship conflict resolution.
        Analyze the problem and provide a JSON response with the following keys exactly:
        - root_cause: Analysis of why this happened.
        - perspectives: Analysis of the feelings from both sides.
        - suggestion: What is the best and calmest way to say or resolve this.
        - avoid: What NOT to do or say.
        Return ONLY valid JSON format without any markdown blocks.
      '''),
    );

    final prompt = 'Problem: $problem';

    try {
      final response = await model.generateContent([Content.text(prompt)]);

      String rawText = response.text ?? '{}';
      rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();

      return jsonDecode(rawText);
    } catch (e) {
      print('Error calling Gemini: $e');
      throw Exception('Gagal mendapatkan solusi dari AI: $e');
    }
  }

  Future<Map<String, dynamic>> analyzeConflict({
    required String description,
    required String mood,
    required int daysTogether,
    required String userPov,
    required String partnerPov,
  }) async {
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system('''
You are a relationship conflict resolution expert for a couple app called FA Space.

The person currently speaking is $userPov. Their partner is $partnerPov.
Always analyze perspectives from these two sides: $userPov (the one telling the story) and $partnerPov (their partner).

Your job is to analyze relationship conflicts and give structured, empathetic advice.

IMPORTANT RULES:
- Always be warm, non-judgmental, and balanced
- Never take one side
- Use simple Indonesian language (lo/gue style, casual)
- Keep each section concise (2-4 sentences max)
- suggested_message must be a ready-to-send Indonesian message written from $userPov's point of view (no quotes inside)
- perspective_user = $userPov's feelings/perspective
- perspective_partner = $partnerPov's feelings/perspective

CLASSIFY the conflict into one of these labels:
ghosting | communication | jealousy | trust | distance | habit | other

OUTPUT FORMAT (strict JSON only, absolutely no markdown, no extra text):
{
  "label": "...",
  "label_emoji": "...",
  "root_cause": "...",
  "perspective_user": "...",
  "perspective_partner": "...",
  "suggested_message": "...",
  "what_to_avoid": "...",
  "next_step": "..."
}
'''),
    );

    final userPrompt = '''
conflict_description: "$description"

Analyze this conflict and respond ONLY with the JSON format above. No markdown, no backticks.
''';

    try {
      final response = await model.generateContent([Content.text(userPrompt)]);

      String rawText = response.text ?? '{}';
      rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();

      return jsonDecode(rawText);
    } catch (e) {
      print('Error calling Gemini: $e');
      throw Exception('Gagal menganalisis konflik: $e');
    }
  }
}