export class AppError extends Error {
  public statusCode: number;
  public isOperational: boolean;
  public code?: string;
  public errors?: Record<string, string[]>;

  constructor(message: string, statusCode: number = 500, errors?: Record<string, string[]>) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = true;
    this.code = undefined;
    this.errors = errors;
    Object.setPrototypeOf(this, AppError.prototype);
  }
}

export class BadRequestError extends AppError {
  constructor(message: string = 'Bad request', errors?: Record<string, string[]>) {
    super(message, 400, errors);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message: string = 'Unauthorized') {
    super(message, 401);
  }
}

export class ForbiddenError extends AppError {
  constructor(message: string = 'Forbidden') {
    super(message, 403);
  }
}

export class NotFoundError extends AppError {
  constructor(message: string = 'Resource not found') {
    super(message, 404);
  }
}

export class ConflictError extends AppError {
  constructor(message: string = 'Resource already exists') {
    super(message, 409);
  }
}

export class ValidationError extends AppError {
  constructor(message: string = 'Validation failed', errors?: Record<string, string[]>) {
    super(message, 422, errors);
  }
}

export class TooManyRequestsError extends AppError {
  constructor(message: string = 'Too many requests') {
    super(message, 429);
  }
}

export class QrTokenInvalidError extends AppError {
  constructor(message: string = 'QR code invalide.') {
    super(message, 401);
    this.code = 'QR_INVALID';
  }
}

export class QrTokenExpiredError extends AppError {
  constructor(message: string = 'QR code expiré. Veuillez régénérer le code dans l\'application patient.') {
    super(message, 410);
    this.code = 'QR_EXPIRED';
  }
}

export class QrTokenUsedError extends AppError {
  constructor(message: string = 'Ce QR code a déjà été utilisé.') {
    super(message, 409);
    this.code = 'QR_USED';
  }
}
