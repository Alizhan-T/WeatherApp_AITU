import Foundation

protocol WeatherServiceProtocol {
    func searchCity(name: String) async throws -> [City]
    func fetchWeather(lat: Double, lon: Double) async throws -> WeatherResponse
}

enum WeatherServiceError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Failed to construct API request URL."
        case .invalidResponse:
            return "Received an invalid response from the weather server."
        case .httpStatus(let code):
            return "Weather server returned HTTP \(code)."
        }
    }
}

final class WeatherService: WeatherServiceProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func makeGeocodingURL(name: String) throws -> URL {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "count", value: "5"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components?.url else { throw WeatherServiceError.invalidURL }
        return url
    }

    func makeForecastURL(lat: Double, lon: Double) throws -> URL {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        guard let url = components?.url else { throw WeatherServiceError.invalidURL }
        return url
    }

    func searchCity(name: String) async throws -> [City] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let url = try makeGeocodingURL(name: trimmed)
        let data = try await fetchValidatedData(from: url)
        return try JSONDecoder().decode(GeocodingResponse.self, from: data).results ?? []
    }

    func fetchWeather(lat: Double, lon: Double) async throws -> WeatherResponse {
        let url = try makeForecastURL(lat: lat, lon: lon)
        let data = try await fetchValidatedData(from: url)
        return try JSONDecoder().decode(WeatherResponse.self, from: data)
    }

    private func fetchValidatedData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw WeatherServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw WeatherServiceError.httpStatus(http.statusCode)
        }
        return data
    }
}
