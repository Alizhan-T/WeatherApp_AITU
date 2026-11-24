import Foundation
import Testing
@testable import WeatherApp_Toleukhan

private final class MockWeatherService: WeatherServiceProtocol {
    var citiesToReturn: [City] = []
    var weatherToReturn: WeatherResponse?
    var errorToThrow: Error?

    func searchCity(name: String) async throws -> [City] {
        if let error = errorToThrow { throw error }
        return citiesToReturn
    }

    func fetchWeather(lat: Double, lon: Double) async throws -> WeatherResponse {
        if let error = errorToThrow { throw error }
        if let weather = weatherToReturn { return weather }
        throw WeatherServiceError.invalidResponse
    }
}

private func makeSampleWeather() -> WeatherResponse {
    WeatherResponse(
        current_units: CurrentUnits(
            temperature_2m: "°C",
            relative_humidity_2m: "%",
            wind_speed_10m: "km/h"
        ),
        current: CurrentData(
            time: "2026-02-05T12:00",
            temperature_2m: 12.4,
            relative_humidity_2m: 58,
            weather_code: 80,
            wind_speed_10m: 14.5
        ),
        daily: DailyWeather(
            time: ["2026-02-05", "2026-02-06", "2026-02-07"],
            weather_code: [80, 71, 0],
            temperature_2m_max: [14.0, 2.0, 10.0],
            temperature_2m_min: [4.0, -5.0, 1.0]
        )
    )
}

@MainActor
struct WeatherApp_ToleukhanTests {

    @Test func wmoCodesMapToAccurateSymbolsAndDescriptions() {
        #expect(WeatherCondition.symbol(for: 0) == "sun.max.fill")
        #expect(WeatherCondition.description(for: 0) == "Clear sky")

        #expect(WeatherCondition.symbol(for: 80) == "cloud.heavyrain.fill")
        #expect(WeatherCondition.description(for: 80) == "Rain showers")

        #expect(WeatherCondition.symbol(for: 85) == "cloud.snow.fill")
        #expect(WeatherCondition.description(for: 85) == "Snow showers")

        #expect(WeatherCondition.symbol(for: 95) == "cloud.bolt.rain.fill")
        #expect(WeatherCondition.description(for: 999) == "Cloudy")
    }

    @Test func temperatureAndWindUnitConversions() {
        #expect(TemperatureUnit.celsius.formattedTemperature(0) == "0°C")
        #expect(TemperatureUnit.fahrenheit.formattedTemperature(0) == "32°F")
        #expect(TemperatureUnit.fahrenheit.formattedTemperature(25) == "77°F")

        #expect(TemperatureUnit.celsius.formattedWind(kmh: 10.0) == "10.0 km/h")
        #expect(TemperatureUnit.fahrenheit.formattedWind(kmh: 10.0) == "6.2 mph")
    }

    @Test func dailyForecastHandlesMismatchedArrayLengthsSafely() {
        let daily = DailyWeather(
            time: ["2026-02-05", "2026-02-06", "2026-02-07"],
            weather_code: [61],
            temperature_2m_max: [12.0, 13.0],
            temperature_2m_min: [3.0, 4.0, 5.0]
        )

        let days = daily.forecastDays
        #expect(days.count == 2)
        #expect(days[0].weatherCode == 61)
        #expect(days[1].weatherCode == 3)
        #expect(days[0].formattedDate == "Thu, Feb 5")
    }

    @Test func weatherServiceEncodesQueryParametersSafely() throws {
        let service = WeatherService()
        let geoURL = try service.makeGeocodingURL(name: "St. John's & Bay")
        let geoString = geoURL.absoluteString
        #expect(geoString.contains("geocoding-api.open-meteo.com/v1/search"))
        #expect(!geoString.contains("name=St. John's & Bay"))

        let forecastURL = try service.makeForecastURL(lat: 43.2389, lon: 76.8897)
        #expect(forecastURL.absoluteString.contains("daily=weather_code,temperature_2m_max,temperature_2m_min"))
    }

    @Test func viewModelRejectsWhitespaceSearch() async {
        let mock = MockWeatherService()
        let defaults = UserDefaults(suiteName: "WeatherTests-\(UUID().uuidString)")!
        let vm = WeatherViewModel(service: mock, defaults: defaults)

        vm.searchText = "   "
        await vm.search()

        #expect(vm.cities.isEmpty)
        #expect(vm.errorMessage == "Please enter a city name.")
        #expect(!vm.isLoading)
    }

    @Test func viewModelLoadsWeatherAndSavesSelectedCitySnapshot() async {
        let mock = MockWeatherService()
        let city = City(id: 1, name: "Almaty", latitude: 43.2389, longitude: 76.8897, country: "Kazakhstan")
        let sample = makeSampleWeather()
        mock.weatherToReturn = sample

        let suiteName = "WeatherTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let vm = WeatherViewModel(service: mock, defaults: defaults)
        await vm.loadWeather(for: city)

        #expect(vm.selectedCity == city)
        #expect(vm.weather == sample)
        #expect(!vm.isOffline)
        #expect(vm.errorMessage == nil)
        #expect(vm.lastUpdateString.hasPrefix("Updated:"))
    }

    @Test func viewModelFallsBackToOfflineSnapshotOnNetworkFailure() async {
        let mock = MockWeatherService()
        let city = City(id: 2, name: "Tokyo", latitude: 35.6762, longitude: 139.6503, country: "Japan")
        let sample = makeSampleWeather()
        mock.weatherToReturn = sample

        let suiteName = "WeatherTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let vm = WeatherViewModel(service: mock, defaults: defaults)
        await vm.loadWeather(for: city)

        // Simulate offline failure on subsequent refresh
        mock.errorToThrow = URLError(.notConnectedToInternet)
        await vm.refresh()

        #expect(vm.isOffline)
        #expect(vm.selectedCity == city)
        #expect(vm.weather == sample)
        #expect(vm.errorMessage == nil)
    }

    @Test func viewModelRestoresLastCachedCityOnLaunch() async {
        let mock = MockWeatherService()
        let city = City(id: 3, name: "London", latitude: 51.5072, longitude: -0.1276, country: "United Kingdom")
        let sample = makeSampleWeather()
        mock.weatherToReturn = sample

        let suiteName = "WeatherTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstVM = WeatherViewModel(service: mock, defaults: defaults)
        await firstVM.loadWeather(for: city)

        let relaunchedVM = WeatherViewModel(service: mock, defaults: defaults)
        relaunchedVM.restoreLastCachedIfAvailable()

        #expect(relaunchedVM.selectedCity == city)
        #expect(relaunchedVM.weather == sample)
        #expect(!relaunchedVM.isOffline)
    }
}
