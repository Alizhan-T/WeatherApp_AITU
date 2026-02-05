import Foundation

struct GeocodingResponse: Codable {
    let results: [City]?
}

struct City: Codable, Identifiable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
}

struct WeatherResponse: Codable {
    let current_units: CurrentUnits?
    let current: CurrentData?
    let daily: DailyWeather
}

struct CurrentUnits: Codable {
    let temperature_2m: String
    let relative_humidity_2m: String
    let wind_speed_10m: String
}

struct CurrentData: Codable {
    let time: String
    let temperature_2m: Double
    let relative_humidity_2m: Int
    let weather_code: Int
    let wind_speed_10m: Double
}

struct DailyWeather: Codable {
    let time: [String]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
}
