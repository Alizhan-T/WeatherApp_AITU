# Contributing to WeatherApp

Contributions and bug reports are welcome!

## Development Workflow

1. Fork the repository and create a branch:
   ```bash
   git checkout -b feat/your-improvement
   ```
2. Open `WeatherApp_Toleukhan.xcodeproj` in Xcode.
3. Run unit tests (`⌘U` or `xcodebuild test -only-testing:WeatherApp_ToleukhanTests`) and ensure all tests pass.
4. Keep networking behind `WeatherServiceProtocol` so ViewModel behavior remains deterministically testable without live network calls.
