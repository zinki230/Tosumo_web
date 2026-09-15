const swaggerDefinition = {
  openapi: '3.0.0',
  info: {
    title: 'TOSUMO Healthcare Platform API',
    version: '1.0.0',
    description: 'Backend API for TOSUMO patient and doctor mobile applications',
    contact: {
      name: 'TOSUMO Team',
      email: 'support@tosumo.cm',
    },
  },
  servers: [
    { url: 'http://localhost:3000', description: 'Development server' },
    { url: 'https://api.tosumo.cm', description: 'Production server' },
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
      },
    },
    schemas: {
      User: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          email: { type: 'string' },
          phone: { type: 'string' },
          role: { type: 'string', enum: ['patient', 'doctor', 'admin', 'superadmin'] },
          isActive: { type: 'boolean' },
          isEmailVerified: { type: 'boolean' },
          isPhoneVerified: { type: 'boolean' },
          createdAt: { type: 'string', format: 'date-time' },
        },
      },
      Patient: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          userId: { type: 'string' },
          nin: { type: 'string' },
          dateOfBirth: { type: 'string', format: 'date-time' },
          gender: { type: 'string' },
          bloodType: { type: 'string' },
          allergies: { type: 'array', items: { type: 'string' } },
          chronicDiseases: { type: 'array', items: { type: 'string' } },
          emergencyContactName: { type: 'string' },
          emergencyContactPhone: { type: 'string' },
          isOnboarded: { type: 'boolean' },
          createdAt: { type: 'string', format: 'date-time' },
        },
      },
      Doctor: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          userId: { type: 'string' },
          firstName: { type: 'string' },
          lastName: { type: 'string' },
          specialty: { type: 'string' },
          licenseNumber: { type: 'string' },
          consultationFee: { type: 'number' },
          isVerified: { type: 'boolean' },
          isAvailable: { type: 'boolean' },
          averageRating: { type: 'number' },
          createdAt: { type: 'string', format: 'date-time' },
        },
      },
      Appointment: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          patientId: { type: 'string' },
          doctorId: { type: 'string' },
          appointmentDate: { type: 'string', format: 'date-time' },
          startTime: { type: 'string' },
          endTime: { type: 'string' },
          type: { type: 'string' },
          status: { type: 'string', enum: ['pending', 'approved', 'confirmed', 'rescheduled', 'cancelled', 'completed', 'no_show'] },
          reason: { type: 'string' },
          createdAt: { type: 'string', format: 'date-time' },
        },
      },
      Consultation: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          patientId: { type: 'string' },
          doctorId: { type: 'string' },
          chiefComplaint: { type: 'string' },
          diagnosis: { type: 'string' },
          symptoms: { type: 'array', items: { type: 'string' } },
          consultationDate: { type: 'string', format: 'date-time' },
        },
      },
      LabResult: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          patientId: { type: 'string' },
          doctorId: { type: 'string' },
          testName: { type: 'string' },
          testCategory: { type: 'string' },
          status: { type: 'string' },
          isAbnormal: { type: 'boolean' },
          orderedDate: { type: 'string', format: 'date-time' },
        },
      },
      Prescription: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          medicationName: { type: 'string' },
          dosage: { type: 'string' },
          frequency: { type: 'string' },
          duration: { type: 'string' },
          isActive: { type: 'boolean' },
          prescribedDate: { type: 'string', format: 'date-time' },
        },
      },
      ChatMessage: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          chatId: { type: 'string' },
          senderId: { type: 'string' },
          content: { type: 'string' },
          messageType: { type: 'string' },
          isRead: { type: 'boolean' },
          createdAt: { type: 'string', format: 'date-time' },
        },
      },
      Notification: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          title: { type: 'string' },
          body: { type: 'string' },
          type: { type: 'string' },
          isRead: { type: 'boolean' },
          createdAt: { type: 'string', format: 'date-time' },
        },
      },
      ApiResponse: {
        type: 'object',
        properties: {
          success: { type: 'boolean' },
          message: { type: 'string' },
          data: { type: 'object' },
          error: { type: 'string' },
        },
      },
    },
  },
  security: [{ bearerAuth: [] }],
  paths: {
    '/api/v1/health': {
      get: {
        tags: ['Health'],
        summary: 'Health check',
        responses: { '200': { description: 'API is running' } },
      },
    },
    '/api/v1/auth/register': {
      post: {
        tags: ['Auth'],
        summary: 'Register a new user',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['email', 'phone', 'password', 'role'],
                properties: {
                  email: { type: 'string' },
                  phone: { type: 'string' },
                  password: { type: 'string', minLength: 8 },
                  role: { type: 'string', enum: ['patient', 'doctor'] },
                },
              },
            },
          },
        },
        responses: { '201': { description: 'Registration successful' }, '409': { description: 'Conflict' } },
      },
    },
    '/api/v1/auth/login': {
      post: {
        tags: ['Auth'],
        summary: 'Login',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  email: { type: 'string' },
                  phone: { type: 'string' },
                  password: { type: 'string' },
                },
              },
            },
          },
        },
        responses: { '200': { description: 'Login successful' }, '401': { description: 'Invalid credentials' } },
      },
    },
  },
};

module.exports = swaggerDefinition;
