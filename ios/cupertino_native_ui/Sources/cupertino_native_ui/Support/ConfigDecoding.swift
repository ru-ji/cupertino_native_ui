import Foundation

/// Decodes a Flutter platform-view creation/update argument map into a `Decodable` config struct.
func decodeConfig<T: Decodable>(_ type: T.Type, from map: [String: Any]) -> T? {
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: map, options: [])
        return try JSONDecoder().decode(T.self, from: jsonData)
    } catch {
        print("Error decoding \(T.self): \(error)")
        return nil
    }
}
