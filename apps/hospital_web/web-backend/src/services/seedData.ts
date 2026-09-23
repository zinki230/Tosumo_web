import bcrypt from 'bcrypt'
import { User } from '../models/User'
import { Institution } from '../models/Institution'

/**
 * Create demo data for development and testing
 */
export async function seedDemoData() {
  try {
    console.log('🌱 Seeding demo data...')

    // Check if demo admin already exists
    const existingAdmin = await User.findOne({ 
      phone: process.env.DEMO_ADMIN_PHONE 
    })

    if (existingAdmin) {
      console.log('✅ Demo admin already exists')
      return
    }

    // Create demo admin user
    const passwordHash = await bcrypt.hash(
      process.env.DEMO_ADMIN_PASSWORD || 'WebAdmin@2024', 
      parseInt(process.env.BCRYPT_ROUNDS || '12')
    )

    const adminUser = new User({
      phone: process.env.DEMO_ADMIN_PHONE || '+237691234570',
      email: process.env.DEMO_ADMIN_EMAIL || 'admin@hospital-web.tosumo.cm',
      passwordHash,
      role: 'institution_admin',
      firstName: 'Admin',
      lastName: 'TOSUMO',
      isActive: true,
      isEmailVerified: true,
      isPhoneVerified: true
    })

    await adminUser.save()

    // Create demo institution
    const institution = new Institution({
      name: 'Centre Hospitalier TOSUMO Web',
      type: 'hospital',
      phone: adminUser.phone,
      email: adminUser.email,
      city: 'Douala',
      region: 'Littoral',
      address: 'Akwa, Boulevard de la Liberté',
      isVerified: true,
      isActive: true,
      createdBy: adminUser._id
    })

    await institution.save()

    // Link institution to user
    adminUser.createdInstitutions = [institution._id]
    await adminUser.save()

    console.log('✅ Demo data seeded successfully')
    console.log('📱 Demo Login:')
    console.log(`   Phone: ${adminUser.phone}`)
    console.log(`   Password: ${process.env.DEMO_ADMIN_PASSWORD}`)
    console.log(`   Role: ${adminUser.role}`)
    console.log(`   Institution: ${institution.name}`)

  } catch (error) {
    console.error('❌ Error seeding demo data:', error)
  }
}

/**
 * Create some demo doctors for testing
 */
export async function seedDemoDoctors() {
  try {
    const adminUser = await User.findOne({ 
      phone: process.env.DEMO_ADMIN_PHONE 
    })

    if (!adminUser) {
      console.log('⚠️ Admin user not found, skipping doctor seeding')
      return
    }

    const existingDoctors = await User.countDocuments({ 
      role: 'doctor', 
      createdBy: adminUser._id 
    })

    if (existingDoctors > 0) {
      console.log('✅ Demo doctors already exist')
      return
    }

    const doctorsData = [
      {
        phone: '+237691234571',
        email: 'dr.mballa@tosumo.cm',
        firstName: 'Jean',
        lastName: 'Mballa',
        specialty: 'Cardiologie'
      },
      {
        phone: '+237691234572',
        email: 'dr.nguemo@tosumo.cm',
        firstName: 'Marie',
        lastName: 'Nguemo',
        specialty: 'Pédiatrie'
      },
      {
        phone: '+237691234573',
        firstName: 'Paul',
        lastName: 'Fouda',
        specialty: 'Chirurgie Générale'
      }
    ]

    const passwordHash = await bcrypt.hash('Doctor@123', 12)

    for (const docData of doctorsData) {
      const doctor = new User({
        ...docData,
        passwordHash,
        role: 'doctor',
        licenseNumber: `LIC-${Math.random().toString(36).substr(2, 6).toUpperCase()}`,
        isActive: true,
        createdBy: adminUser._id
      })

      await doctor.save()
    }

    console.log(`✅ Created ${doctorsData.length} demo doctors`)

  } catch (error) {
    console.error('❌ Error seeding demo doctors:', error)
  }
}