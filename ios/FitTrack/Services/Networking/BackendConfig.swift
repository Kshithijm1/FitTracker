import Foundation

/// Points at the Phase 2 Fastify API. Defaults to the local dev server
/// (`npm run dev` from `backend/`, see README) — swap `baseURL` for the
/// deployed Fly/Neon URL once shipped (docs/DEPLOYMENT.md).
enum BackendConfig {
#if DEBUG
    static let baseURL = URL(string: "http://localhost:3000")!
#else
    static let baseURL = URL(string: "https://api.fittrack.app")!
#endif
}
