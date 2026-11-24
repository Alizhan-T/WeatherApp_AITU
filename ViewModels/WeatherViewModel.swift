import Foundation
import SwiftUI
import Combine

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var cities: [City] = []
    @Published var selectedCity: City?
    @Published var weather: WeatherResponse?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isOffline = false
    @Published var lastUpdateString = ""

    private let service: WeatherServiceProtocol
    private let defaults: UserDefaults
    private let snapshotKey = "cachedWeatherSnapshot"
    private let legacyWeatherKey = "cachedWeather"
    private let legacyDateKey = "cachedDate"

    init(service: WeatherServiceProtocol = WeatherService(), defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
    }

    func search() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter a city name."
            return
        }

        isLoading = true
        defer { isLoading = false }

        weather = nil
        errorMessage = nil
        isOffline = false

        do {
            let results = try await service.searchCity(name: trimmed)
            cities = results
            if results.isEmpty {
                errorMessage = "No matching cities found for \"\(trimmed)\"."
            }
        } catch {
            cities = []
            errorMessage = error.localizedDescription
        }
    }

    func loadWeather(for city: City) async {
        isLoading = true
        defer { isLoading = false }

        selectedCity = city
        cities = []
        errorMessage = nil

        do {
            let data = try await service.fetchWeather(lat: city.latitude, lon: city.longitude)
            weather = data
            isOffline = false

            let now = Date()
            updateTimeString(date: now)
            saveSnapshot(CachedWeatherSnapshot(city: city, weather: data, savedAt: now))
        } catch {
            loadFromCache(fallbackError: error)
        }
    }

    func refresh() async {
        guard let city = selectedCity else { return }
        await loadWeather(for: city)
    }

    func restoreLastCachedIfAvailable() {
        guard weather == nil else { return }
        if let data = defaults.data(forKey: snapshotKey),
           let snapshot = try? JSONDecoder().decode(CachedWeatherSnapshot.self, from: data) {
            selectedCity = snapshot.city
            weather = snapshot.weather
            isOffline = false
            updateTimeString(date: snapshot.savedAt)
        }
    }

    private func updateTimeString(date: Date) {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        lastUpdateString = "Updated: \(formatter.string(from: date))"
    }

    private func saveSnapshot(_ snapshot: CachedWeatherSnapshot) {
        if let encoded = try? JSONEncoder().encode(snapshot) {
            defaults.set(encoded, forKey: snapshotKey)
        }
    }

    private func loadFromCache(fallbackError: Error) {
        if let data = defaults.data(forKey: snapshotKey),
           let snapshot = try? JSONDecoder().decode(CachedWeatherSnapshot.self, from: data) {
            selectedCity = snapshot.city
            weather = snapshot.weather
            isOffline = true
            errorMessage = nil
            updateTimeString(date: snapshot.savedAt)
            return
        }

        if let data = defaults.data(forKey: legacyWeatherKey),
           let decoded = try? JSONDecoder().decode(WeatherResponse.self, from: data) {
            weather = decoded
            isOffline = true
            errorMessage = nil
            if let date = defaults.object(forKey: legacyDateKey) as? Date {
                updateTimeString(date: date)
            } else {
                lastUpdateString = "Unknown update time"
            }
            return
        }

        errorMessage = "Network unavailable and no cached forecast found (\(fallbackError.localizedDescription))."
    }
}
