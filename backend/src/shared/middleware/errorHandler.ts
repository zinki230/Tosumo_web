import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { AppError } from '@shared/utils/errors';

export function errorHandler(err: Error, _req: Request, res: Response, _next: NextFunction): void {
  if (err instanceof ZodError) {
    res.status(400).json({
      success: false,
      message: 'Validation failed',
      error: 'Validation failed',
      errors: err.flatten().fieldErrors,
    });
    return;
  }

  if (err instanceof AppError) {
    const body: Record<string, unknown> = {
      success: false,
      message: err.message,
      error: err.message,
    };
    if (err.code) {
      body.code = err.code;
    }
    if (err.errors) {
      body.errors = err.errors;
    }
    res.status(err.statusCode).json(body);
    return;
  }

  console.error('Unhandled error:', err);

  res.status(500).json({
    success: false,
    message: 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error',
  });
}
