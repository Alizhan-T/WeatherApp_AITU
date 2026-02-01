import Foundation
import SwiftUI
import Combine

@MainActor
class WeatherViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var cities: [City] = []
    @Published var weather: WeatherResponse?
    @Published var errorMessage: String?
    @Published var isOffline = false
    
    private let service = WeatherService()
    
        func search() async {
            guard !searchText.isEmpty else { return }
            
            self.weather = nil
            self.errorMessage = nil
            
            do {
                let results = try await service.searchCity(name: searchText)
                self.cities = results
                
                if results.isEmpty {
                    self.errorMessage = "City not found"
                }
            } catch {
                self.errorMessage = "Error: \(error.localizedDescription)"
            }
        }
    
    func loadWeather(for city: City) async {
        do {
            let data = try await service.fetchWeather(lat: city.latitude, lon: city.longitude)
            self.weather = data
            self.isOffline = false
            self.errorMessage = nil
            saveToCache(data)
        } catch {
            print("Network failed, checking cache...")
            loadFromCache()
        }
    }
    
    private func saveToCache(_ data: WeatherResponse) {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "cachedWeather")
        }
    }
    
    private func loadFromCache() {
        if let data = UserDefaults.standard.data(forKey: "cachedWeather"),
           let decoded = try? JSONDecoder().decode(WeatherResponse.self, from: data) {
            self.weather = decoded
            self.isOffline = true
        } else {
            self.errorMessage = "No internet & no cache found."
        }
    }
}
