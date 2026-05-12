import Foundation

enum GeminiError: LocalizedError {
    case noApiKey
    case networkError(Error)
    case httpError(Int)
    case noContent
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .noApiKey:          return "Gemini API key not set. Add it in Atlas Settings."
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .httpError(let c):  return "Gemini API returned HTTP \(c)"
        case .noContent:         return "Gemini returned an empty response"
        case .parseError(let s): return "Could not parse Gemini response: \(s)"
        }
    }
}

actor GeminiService {
    static let shared = GeminiService()

    private let systemInstruction = """
    You are a scheduling assistant. Your job is to read a single message and determine
    whether it represents a confirmed real-world plan (meeting, meal, call, event, etc.).

    Rules:
    - A confirmed plan requires that the sender has agreed to something specific.
    - Vague social phrases like "we should hang out sometime" are NOT confirmed plans.
    - Phrases like "sounds good, see you at 7" ARE confirmed plans.
    - Resolve any relative date references (tomorrow, Friday, next week) relative to the
      message timestamp provided. Return absolute ISO 8601 dates.
    - If end time is not stated, leave endTime null.
    - Return ONLY valid JSON matching the schema below. No markdown, no explanation text.
    """

    func classify(
        body: String,
        sender: String,
        timestamp: Date
    ) async throws -> GeminiResult {
        guard let apiKey = SharedStorage.shared.geminiApiKey, !apiKey.isEmpty else {
            throw GeminiError.noApiKey
        }

        let iso = ISO8601DateFormatter().string(from: timestamp)
        let prompt = buildPrompt(body: body, sender: sender, timestamp: iso)

        return try await callWithRetry(prompt: prompt, apiKey: apiKey)
    }

    // MARK: - Private

    private func buildPrompt(body: String, sender: String, timestamp: String) -> String {
        """
        Message timestamp: \(timestamp)
        Message sender: \(sender)
        Message recipient: Me
        Message body:
        \"\"\"
        \(body)
        \"\"\"

        Return JSON in exactly this schema:
        {
          "isConfirmedPlan": boolean,
          "confidence": number,
          "eventTitle": string | null,
          "date": string | null,
          "startTime": string | null,
          "endTime": string | null,
          "participants": [string],
          "location": string | null,
          "needsUserConfirmation": boolean,
          "reasoningSummary": string
        }
        """
    }

    private func callWithRetry(prompt: String, apiKey: String, maxRetries: Int = 3) async throws -> GeminiResult {
        var lastError: Error = GeminiError.noContent
        for attempt in 0..<maxRetries {
            do {
                return try await callGemini(prompt: prompt, apiKey: apiKey)
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt)) * 0.5
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        throw lastError
    }

    private func callGemini(prompt: String, apiKey: String) async throws -> GeminiResult {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)") else {
            throw GeminiError.noContent
        }

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": systemInstruction]]],
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["response_mime_type": "application/json"]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GeminiError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else { throw GeminiError.noContent }
        guard http.statusCode == 200 else { throw GeminiError.httpError(http.statusCode) }

        struct APIResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }

        let api = try JSONDecoder().decode(APIResponse.self, from: data)
        guard let raw = api.candidates.first?.content.parts.first?.text else {
            throw GeminiError.noContent
        }

        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw GeminiError.parseError(cleaned)
        }

        do {
            var result = try JSONDecoder().decode(GeminiResult.self, from: jsonData)
            result = coerce(result)
            return result
        } catch {
            throw GeminiError.parseError(error.localizedDescription)
        }
    }

    private func coerce(_ r: GeminiResult) -> GeminiResult {
        var endTime = r.endTime
        if endTime == nil, let s = r.startTime {
            endTime = addOneHour(to: s)
        }
        return GeminiResult(
            isConfirmedPlan: r.isConfirmedPlan,
            confidence: min(1, max(0, r.confidence)),
            eventTitle: r.eventTitle,
            date: r.date,
            startTime: r.startTime,
            endTime: endTime,
            participants: r.participants,
            location: r.location,
            needsUserConfirmation: r.needsUserConfirmation,
            reasoningSummary: r.reasoningSummary
        )
    }

    private func addOneHour(to time: String) -> String {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return time }
        return String(format: "%02d:%02d", (parts[0] + 1) % 24, parts[1])
    }
}
