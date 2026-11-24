import Foundation

struct GeocodingResponse: Codable {
    let results: [City]?
}

struct City: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?

    init(
        id: Int,
        name: String,
        latitude: Double,
        longitude: Double,
        country: String? = nil,
        admin1: String? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.country = country
        self.admin1 = admin1
    }

    var displaySubtitle: String {
        let parts = [admin1, country]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "Unknown region" : parts.joined(separator: ", ")
    }
}

struct WeatherResponse: Codable, Equatable {
    let current_units: CurrentUnits?
    let current: CurrentData?
    let daily: DailyWeather
}

struct CurrentUnits: Codable, Equatable {
    let temperature_2m: String
    let relative_humidity_2m: String
    let wind_speed_10m: String
}

struct CurrentData: Codable, Equatable {
    let time: String
    let temperature_2m: Double
    let relative_humidity_2m: Int
    let weather_code: Int
    let wind_speed_10m: Double
}

struct DailyWeather: Codable, Equatable {
    let time: [String]
    let weather_code: [Int]?
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]

    init(
        time: [String],
        weather_code: [Int]? = nil,
        temperature_2m_max: [Double],
        temperature_2m_min: [Double]
    ) {
        self.time = time
        self.weather_code = weather_code
        self.temperature_2m_max = temperature_2m_max
        self.temperature_2m_min = temperature_2m_min
    }

    var forecastDays: [DailyForecastDay] {
        let count = min(time.count, temperature_2m_max.count, temperature_2m_min.count)
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            let code = (weather_code != nil && index < weather_code!.count) ? weather_code![index] : 3
            return DailyForecastDay(
                dateString: time[index],
                maxCelsius: temperature_2m_max[index],
                minCelsius: temperature_2m_min[index],
                weatherCode: code
            )
        }
    }
}

struct DailyForecastDay: Identifiable, Equatable {
    var id: String { dateString }
    let dateString: String
    let maxCelsius: Double
    let minCelsius: Double
    let weatherCode: Int

    var formattedDate: String {
        Self.inputFormatter.date(from: dateString).map { Self.outputFormatter.string(from: $0) } ?? dateString
    }

    private static let inputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let outputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEE, MMM d"
        return f
    }()
}

struct CachedWeatherSnapshot: Codable, Equatable {
    let city: City
    let weather: WeatherResponse
    let savedAt: Date
}

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius = "°C"
    case fahrenheit = "°F"

    var id: String { rawValue }

    func convertTemperature(_ celsius: Double) -> Double {
        switch self {
        case .celsius: return celsius
        case .fahrenheit: return (celsius * 9.0 / 5.0) + 32.0
        }
    }

    func formattedTemperature(_ celsius: Double) -> String {
        "\(Int(round(convertTemperature(celsius))))\(rawValue)"
    }

    func formattedWind(kmh: Double) -> String {
        switch self {
        case .celsius:
            return String(format: "%.1f km/h", kmh)
        case .fahrenheit:
            return String(format: "%.1f mph", kmh * 0.621371)
        }
    }
}

enum WeatherCondition {
    static func symbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67: return "cloud.rain.fill"
        case 71...77: return "snowflake"
        case 80...82: return "cloud.heavyrain.fill"
        case 85...86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func description(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1, 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51...57: return "Drizzle"
        case 61...67: return "Rain"
        case 71...77: return "Snowfall"
        case 80...82: return "Rain showers"
        case 85...86: return "Snow showers"
        case 95...99: return "Thunderstorm"
        default: return "Cloudy"
        }
    }
}
