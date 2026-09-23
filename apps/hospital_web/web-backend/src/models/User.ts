import mongoose, { Schema, Document, Types } from 'mongoose'

export interface IUser extends Document {
  _id: Types.ObjectId
  phone: string
  email?: string
  passwordHash: string
  role: 'patient' | 'doctor' | 'institution_admin' | 'admin' | 'superadmin'
  
  // Personal info
  firstName?: string
  lastName?: string
  dateOfBirth?: Date
  gender?: 'male' | 'female' | 'other'
  
  // Doctor specific
  specialty?: string
  licenseNumber?: string
  
  // Status
  isActive: boolean
  isEmailVerified: boolean
  isPhoneVerified: boolean
  
  // Timestamps
  lastLoginAt?: Date
  createdAt: Date
  updatedAt: Date
  
  // Relationships
  createdBy?: Types.ObjectId
  createdInstitutions?: Types.ObjectId[]
}

const UserSchema = new Schema<IUser>({
  phone: {
    type: String,
    required: true,
    unique: true,
    trim: true
  },
  email: {
    type: String,
    unique: true,
    sparse: true,
    lowercase: true,
    trim: true
  },
  passwordHash: {
    type: String,
    required: true
  },
  role: {
    type: String,
    enum: ['patient', 'doctor', 'institution_admin', 'admin', 'superadmin'],
    required: true,
    default: 'patient'
  },
  
  // Personal info
  firstName: {
    type: String,
    trim: true
  },
  lastName: {
    type: String,
    trim: true
  },
  dateOfBirth: {
    type: Date
  },
  gender: {
    type: String,
    enum: ['male', 'female', 'other']
  },
  
  // Doctor specific
  specialty: {
    type: String,
    trim: true
  },
  licenseNumber: {
    type: String,
    trim: true
  },
  
  // Status
  isActive: {
    type: Boolean,
    default: true
  },
  isEmailVerified: {
    type: Boolean,
    default: false
  },
  isPhoneVerified: {
    type: Boolean,
    default: false
  },
  
  // Timestamps
  lastLoginAt: {
    type: Date
  },
  
  // Relationships
  createdBy: {
    type: Schema.Types.ObjectId,
    ref: 'User'
  },
  createdInstitutions: [{
    type: Schema.Types.ObjectId,
    ref: 'Institution'
  }]
}, {
  timestamps: true,
  collection: 'users'
})

// Indexes for better performance
UserSchema.index({ phone: 1 })
UserSchema.index({ email: 1 })
UserSchema.index({ role: 1, isActive: 1 })
UserSchema.index({ createdBy: 1 })

// Virtual for full name
UserSchema.virtual('fullName').get(function() {
  return `${this.firstName || ''} ${this.lastName || ''}`.trim()
})

// Transform output
UserSchema.set('toJSON', {
  virtuals: true,
  transform: function(doc, ret) {
    delete (ret as any).__v
    delete (ret as any).passwordHash
    return ret
  }
})

export const User = mongoose.model<IUser>('User', UserSchema)