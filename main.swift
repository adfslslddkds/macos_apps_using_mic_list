import Foundation
import Darwin

let dateFormatter = ISO8601DateFormatter()

while true {
    print("\n[$dateFormatter.string(from: Date()))] Приложения с активным аудиовводом:")

    do {
        let processes = try appsUsingAudioInput()

        if processes.isEmpty {
            print("  Нет обнаруженных процессов.")
        } else {
            for process in processes {
                let name = process.name ?? "Unkonwn application"
                let bundleID = process.bundleIdentifier ?? "No Bundle ID"
                print(" $name) - PID $process.pid) - $bundleID)")
            }
        }
    } catch {
        print("  Ошибка опроса: $error)")
    }

    fflush(stdout)
    Thread.sleep(forTimeInterval: 1)
}
