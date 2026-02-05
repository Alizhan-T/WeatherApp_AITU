import Foundation

class WeatherService {
    func searchCity(name: String) async throws -> [City] {
        guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encodedName)&count=5&language=en&format=json") else {
            return []
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(GeocodingResponse.self, from: data).results ?? []
    }
    
    func fetchWeather(lat: Double, lon: Double) async throws -> WeatherResponse {
            let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min&timezone=auto"
            
            guard let url = URL(string: urlString) else { throw URLError(.badURL) }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(WeatherResponse.self, from: data)
        }
}
