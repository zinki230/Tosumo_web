/**
 * Script pour créer un compte institution_admin directement en base
 * À exécuter avec : node scripts/create-admin.js
 */

const { PrismaClient } = require('@prisma/client')
const bcrypt = require('bcrypt')

const prisma = new PrismaClient({
  datasources: {
    db: {
      url: 'mongodb+srv://russeltsague3_db_user:bPRLbVhxwQpfF7W1@cluster0.5id4izm.mongodb.net/tosumo?appName=Cluster0'
    }
  }
})

async function createInstitutionAdmin() {
  try {
    console.log('🔄 Création du compte institution_admin...')
    
    const phone = '+237691234569'
    const email = 'admin@tosumo-test.cm'
    const password = 'TestAdmin@2024'
    const passwordHash = await bcrypt.hash(password, 12)
    
    // 1. Créer l'utilisateur
    const user = await prisma.user.create({
      data: {
        phone,
        email,
        passwordHash,
        role: 'institution_admin',
        isActive: true,
        isEmailVerified: true,
      }
    })
    
    console.log('✅ Utilisateur créé:', { id: user.id, email: user.email, role: user.role })
    
    // 2. Créer l'institution
    const institution = await prisma.institution.create({
      data: {
        name: 'Centre Test TOSUMO',
        type: 'hospital',
        phone: phone,
        email: email,
        address: 'Douala Centre',
        city: 'Douala',
        region: 'Littoral',
        isVerified: true,
        createdById: user.id
      }
    })
    
    console.log('✅ Institution créée:', { id: institution.id, name: institution.name })
    
    console.log('\n🎉 Compte créé avec succès !')
    console.log('📱 Téléphone:', phone)
    console.log('📧 Email:', email) 
    console.log('🔐 Mot de passe:', password)
    console.log('👤 Rôle: institution_admin')
    
    console.log('\n🌐 Connectez-vous sur: https://tosumo-web-hospital-web.vercel.app/login')
    
  } catch (error) {
    console.error('❌ Erreur:', error.message)
  } finally {
    await prisma.$disconnect()
  }
}

createInstitutionAdmin()