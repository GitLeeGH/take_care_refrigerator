# Recognition integration — not enabled

The production recognizer is explicitly unavailable. No image provider, network transport, paid API, secret or server function has been configured. Test suggestions exist only in tests. Existing photo attachment/manual entry continues unchanged.

Proposed request flow after separate approval:
1. User selects/captures a photo and explicitly requests recognition after seeing who receives the image.
2. An authenticated server endpoint validates the JWT, image JPEG/PNG signature and 5 MiB limit, strips unnecessary metadata, limits requests per user and invokes the approved vision provider. API keys remain server-side, never in Flutter.
3. Return bounded structured candidates containing name and optional food category. Treat image text as untrusted content, not instructions. Do not return inferred quantity, expiry, edibility or storage guarantees. Low certainty/no result yields manual entry.
4. User selects one candidate, edits its name, and confirms. This populates only the name field. Quantity, storage and expiry remain user-controlled. The existing Save button is still required; recognition never writes ingredients or changes the database.
5. Timeout, denied consent, cancellation, no result or service error preserves the photo and manual form. Avoid logging images, signed URLs, access tokens or model prompt contents. Define retention/deletion and budget before implementation.

Decisions required: vision provider/model and pricing/budget cap; disclosure and consent for external photo processing; allowed server endpoint deployment and secret provisioning; retention and rate limits. Provider-specific API details must be verified against official current documentation before connecting. The local adapter/review UI is ready for this later integration, but no automatic recognition capability is claimed yet.
