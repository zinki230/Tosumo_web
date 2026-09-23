import mongoose, { Schema, Document, Types } from 'mongoose'

export interface IInstitution extends Document {
  _id: Types.ObjectId
  name: string
  type: 'hospital' | 'clinic' | 'health_center' | 'polyclinic'
  
  // Contact info
  phone: string
  email?: string
  address?: string
  city: string
  region: string
  
  // Status
  isVerified: boolean
  isActive: boolean
  
  // Metadata
  logoUrl?: string
  description?: string
  
  // Timestamps
  createdAt: Date
  updatedAt: Date
  
  // Relationships
  createdBy: Types.ObjectId
}

const InstitutionSchema = new Schema<IInstitution>({
  name: {
    type: String,
    required: true,
    trim: true,
    minlength: 2,
    maxlength: 200
  },
  type: {
    type: String,
    enum: ['hospital', 'clinic', 'health_center', 'polyclinic'],
    required: true
  },
  
  // Contact info
  phone: {
    type: String,
    required: true,
    trim: true
  },
  email: {
    type: String,
    lowercase: true,
    trim: true
  },
  address: {
    type: String,
    trim: true
  },
  city: {
    type: String,
    required: true,
    trim: true
  },
  region: {
    type: String,
    required: true,
    trim: true
  },
  
  // Status
  isVerified: {
    type: Boolean,
    default: false
  },
  isActive: {
    type: Boolean,
    default: true
  },
  
  // Metadata
  logoUrl: {
    type: String,
    trim: true
  },
  description: {
    type: String,
    trim: true,
    maxlength: 1000
  },
  
  // Relationships
  createdBy: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true
  }
}, {
  timestamps: true,
  collection: 'institutions'
})

// Indexes
InstitutionSchema.index({ name: 1 })
InstitutionSchema.index({ type: 1, isVerified: 1, isActive: 1 })
InstitutionSchema.index({ city: 1, region: 1 })
InstitutionSchema.index({ createdBy: 1 })

// Virtual for type display name
InstitutionSchema.virtual('typeDisplayName').get(function() {
  const typeMap = {
    hospital: 'Hôpital',
    clinic: 'Clinique',
    health_center: 'Centre de Santé',
    polyclinic: 'Polyclinique'
  }
  return typeMap[this.type] || this.type
})

InstitutionSchema.set('toJSON', { virtuals: true })

export const Institution = mongoose.model<IInstitution>('Institution', InstitutionSchema)