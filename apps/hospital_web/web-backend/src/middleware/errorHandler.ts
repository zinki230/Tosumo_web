import { Request, Response, NextFunction } from 'express'

export interface APIError extends Error {
  statusCode?: number
  code?: string
}

export function errorHandler(err: APIError, req: Request, res: Response, next: NextFunction) {
  let error = { ...err }
  error.message = err.message

  // Log error
  if (process.env.NODE_ENV !== 'production') {
    console.error('❌ Error:', err)
  }

  // Mongoose bad ObjectId
  if (err.name === 'CastError') {
    error.message = 'Invalid ID format'
    error.statusCode = 400
  }

  // Mongoose duplicate key
  if (err.code === '11000') {
    error.message = 'Duplicate field value'
    error.statusCode = 400
  }

  // Mongoose validation error
  if (err.name === 'ValidationError') {
    error.message = 'Validation Error'
    error.statusCode = 400
  }

  // JWT errors
  if (err.name === 'JsonWebTokenError') {
    error.message = 'Invalid token'
    error.statusCode = 401
  }

  if (err.name === 'TokenExpiredError') {
    error.message = 'Token expired'
    error.statusCode = 401
  }

  res.status(error.statusCode || 500).json({
    success: false,
    message: error.message || 'Internal Server Error',
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack })
  })
}