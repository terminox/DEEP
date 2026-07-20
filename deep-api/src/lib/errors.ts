// A small typed HTTP error so route handlers can `throw new ApiError(...)`
// and the global handler turns it into a clean JSON response.
export class ApiError extends Error {
  constructor(
    public statusCode: number,
    public code: string,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }

  static badRequest(message: string, code = "bad_request") {
    return new ApiError(400, code, message);
  }
  static unauthorized(message = "Not authenticated", code = "unauthorized") {
    return new ApiError(401, code, message);
  }
  static forbidden(message = "Not allowed", code = "forbidden") {
    return new ApiError(403, code, message);
  }
  static notFound(message = "Not found", code = "not_found") {
    return new ApiError(404, code, message);
  }
  static conflict(message: string, code = "conflict") {
    return new ApiError(409, code, message);
  }
}
