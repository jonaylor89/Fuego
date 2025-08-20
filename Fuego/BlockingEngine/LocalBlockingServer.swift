import Foundation
import Logging
import Network

/// Local HTTP server that serves stoic quotes for blocked websites
class LocalBlockingServer {
    private let logger = Logger(label: "dev.getfuego.server")
    private var listener: NWListener?
    private let port: UInt16 = 8080

    private let stoicQuotes = [
        "You have power over your mind - not outside events. Realize this, and you will find strength. — Marcus Aurelius",
        "The best revenge is not to be like your enemy. — Marcus Aurelius",
        "Waste no more time arguing what a good person should be. Be one. — Marcus Aurelius",
        "If you want to improve, be content to be thought foolish and stupid with regard to external things. — Epictetus",
        "It's not what happens to you, but how you react to it that matters. — Epictetus",
        "Don't explain your philosophy. Embody it. — Epictetus",
        "The mind that is not baffled is not employed. — Wendell Berry",
        "You are never too old to set another goal or to dream a new dream. — C.S. Lewis",
        "The impediment to action advances action. What stands in the way becomes the way. — Marcus Aurelius",
        "Be like the rocky headland on which the waves constantly break. It stands firm, and round it the seething waters are laid to rest. — Marcus Aurelius",
        "Confine yourself to the present. — Marcus Aurelius",
        "Very little is needed to make a happy life; it is all within yourself, in your way of thinking. — Marcus Aurelius",
    ]

    func start() async throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: .main)
        logger.info("Local blocking server started on port \(port)")
    }

    func stop() {
        listener?.cancel()
        listener = nil
        logger.info("Local blocking server stopped")
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global())

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) {
            [weak self] data, _, isComplete, error in
            guard let self = self, let data = data else {
                connection.cancel()
                return
            }

            // Parse HTTP request (simple parsing)
            _ = String(data: data, encoding: .utf8) ?? ""

            // Generate response with random stoic quote
            let quote = self.stoicQuotes.randomElement() ?? "Focus on what you can control."
            let response = self.generateBlockedPageHTML(quote: quote)

            let httpResponse = """
                HTTP/1.1 200 OK\r
                Content-Type: text/html; charset=utf-8\r
                Content-Length: \(response.utf8.count)\r
                Connection: close\r
                \r
                \(response)
                """

            connection.send(
                content: httpResponse.data(using: .utf8),
                completion: .contentProcessed { error in
                    connection.cancel()
                })
        }
    }

    private func generateBlockedPageHTML(quote: String) -> String {
        return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <title>Focus Time</title>
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                    * { margin: 0; padding: 0; box-sizing: border-box; }
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
                        background: #f8f9fa;
                        min-height: 100vh;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        line-height: 1.6;
                        color: #2c3e50;
                    }
                    .container {
                        text-align: center;
                        max-width: 600px;
                        padding: 40px 20px;
                    }
                    .flame {
                        font-size: 48px;
                        margin-bottom: 20px;
                    }
                    h1 {
                        font-size: 24px;
                        font-weight: 300;
                        margin-bottom: 30px;
                        color: #34495e;
                    }
                    .quote {
                        font-size: 18px;
                        font-style: italic;
                        line-height: 1.8;
                        margin: 40px 0;
                        padding: 30px;
                        background: white;
                        border-radius: 8px;
                        box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                    }
                    .subtitle {
                        font-size: 14px;
                        color: #7f8c8d;
                        margin-top: 30px;
                    }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="flame">🔥</div>
                    <h1>focus time</h1>
                    <div class="quote">\(quote)</div>
                    <div class="subtitle">return to your work when ready</div>
                </div>
            </body>
            </html>
            """
    }
}
