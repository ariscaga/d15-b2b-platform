/**
 * D15 B2B Platform — RLS Isolation Test Suite
 *
 * Tests that Row Level Security policies correctly isolate data
 * between enterprise accounts and expose everything to admins.
 *
 * Run with: npm run test:rls
 *
 * Requires the following env vars in .env.test.local:
 *   VITE_SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY   (never expose in frontend — test only)
 *   TEST_ENTERPRISE_A_EMAIL
 *   TEST_ENTERPRISE_A_PASSWORD
 *   TEST_ENTERPRISE_B_EMAIL
 *   TEST_ENTERPRISE_B_PASSWORD
 *   TEST_ADMIN_EMAIL
 *   TEST_ADMIN_PASSWORD
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js'

// ============================================================
// Setup — clients for each persona
// ============================================================

const supabaseUrl = process.env.VITE_SUPABASE_URL!
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY!

// Service role client — bypasses RLS, used only for test setup/teardown
const adminClient = createClient(supabaseUrl, serviceRoleKey)

// Anon clients — subject to RLS, used for the actual tests
const clientA = createClient(supabaseUrl, process.env.VITE_SUPABASE_ANON_KEY!)
const clientB = createClient(supabaseUrl, process.env.VITE_SUPABASE_ANON_KEY!)
const adminUserClient = createClient(supabaseUrl, process.env.VITE_SUPABASE_ANON_KEY!)

// Test data IDs — populated during setup
let enterpriseAId: string
let enterpriseBId: string
let taskAId: string
let taskBId: string
let submissionAId: string
let submissionBId: string
let deliverableAId: string
let deliverableBId: string
let userAId: string
let userBId: string
let adminUserId: string

// ============================================================
// Helpers
// ============================================================

function assert(condition: boolean, message: string) {
  if (!condition) {
    throw new Error(`FAIL: ${message}`)
  }
  console.log(`  ✅ ${message}`)
}

function assertFail(message: string) {
  throw new Error(`FAIL: ${message}`)
}

async function signIn(client: SupabaseClient, email: string, password: string) {
  const { data, error } = await client.auth.signInWithPassword({ email, password })
  if (error) throw new Error(`Sign in failed for ${email}: ${error.message}`)
  return data
}

async function signOut(client: SupabaseClient) {
  await client.auth.signOut()
}

// ============================================================
// Test setup — create test users and seed data via service role
// ============================================================

async function setup() {
  console.log('\n🔧 Setting up test data...\n')

  // Create Enterprise A user
  const { data: userA, error: errA } = await adminClient.auth.admin.createUser({
    email: process.env.TEST_ENTERPRISE_A_EMAIL!,
    password: process.env.TEST_ENTERPRISE_A_PASSWORD!,
    email_confirm: true,
    user_metadata: { role: 'enterprise' },
  })
  if (errA) throw new Error(`Failed to create Enterprise A user: ${errA.message}`)
  userAId = userA.user!.id

  // Create Enterprise B user
  const { data: userB, error: errB } = await adminClient.auth.admin.createUser({
    email: process.env.TEST_ENTERPRISE_B_EMAIL!,
    password: process.env.TEST_ENTERPRISE_B_PASSWORD!,
    email_confirm: true,
    user_metadata: { role: 'enterprise' },
  })
  if (errB) throw new Error(`Failed to create Enterprise B user: ${errB.message}`)
  userBId = userB.user!.id

  // Create Admin user
  const { data: adminUser, error: errAdmin } = await adminClient.auth.admin.createUser({
    email: process.env.TEST_ADMIN_EMAIL!,
    password: process.env.TEST_ADMIN_PASSWORD!,
    email_confirm: true,
    user_metadata: { role: 'admin' },
  })
  if (errAdmin) throw new Error(`Failed to create Admin user: ${errAdmin.message}`)
  adminUserId = adminUser.user!.id

  // Update admin role in public.users (trigger creates it as enterprise by default)
  await adminClient
    .from('users')
    .update({ role: 'admin' })
    .eq('id', adminUserId)

  // Create Enterprise A profile
  const { data: profA, error: errProfA } = await adminClient
    .from('enterprise_profiles')
    .insert({
      user_id: userAId,
      name: 'Test Enterprise A',
      email: process.env.TEST_ENTERPRISE_A_EMAIL!,
      tier: 'validate_basic',
      subscription_status: 'active',
      has_acknowledged_disclaimer: true,
    })
    .select()
    .single()
  if (errProfA) throw new Error(`Failed to create Enterprise A profile: ${errProfA.message}`)
  enterpriseAId = profA.id

  // Create Enterprise B profile
  const { data: profB, error: errProfB } = await adminClient
    .from('enterprise_profiles')
    .insert({
      user_id: userBId,
      name: 'Test Enterprise B',
      email: process.env.TEST_ENTERPRISE_B_EMAIL!,
      tier: 'validate_basic',
      subscription_status: 'active',
      has_acknowledged_disclaimer: true,
    })
    .select()
    .single()
  if (errProfB) throw new Error(`Failed to create Enterprise B profile: ${errProfB.message}`)
  enterpriseBId = profB.id

  // Create Task for Enterprise A
  const { data: tA, error: errTA } = await adminClient
    .from('tasks')
    .insert({
      enterprise_id: enterpriseAId,
      task_type: 'text_rating',
      title: 'Enterprise A Task',
      description: 'Test task for Enterprise A',
      instructions: 'Rate these text samples',
      compensation_per_task: 15.00,
      volume: 10,
      tier_at_creation: 'validate_basic',
    })
    .select()
    .single()
  if (errTA) throw new Error(`Failed to create Task A: ${errTA.message}`)
  taskAId = tA.id

  // Create Task for Enterprise B
  const { data: tB, error: errTB } = await adminClient
    .from('tasks')
    .insert({
      enterprise_id: enterpriseBId,
      task_type: 'text_rating',
      title: 'Enterprise B Task',
      description: 'Test task for Enterprise B',
      instructions: 'Rate these text samples',
      compensation_per_task: 15.00,
      volume: 10,
      tier_at_creation: 'validate_basic',
    })
    .select()
    .single()
  if (errTB) throw new Error(`Failed to create Task B: ${errTB.message}`)
  taskBId = tB.id

  // Create Submission for Task A
  const { data: sA, error: errSA } = await adminClient
    .from('task_submissions')
    .insert({
      task_id: taskAId,
      content: { text: 'Enterprise A submission content' },
      submission_status: 'mock',
    })
    .select()
    .single()
  if (errSA) throw new Error(`Failed to create Submission A: ${errSA.message}`)
  submissionAId = sA.id

  // Create Submission for Task B
  const { data: sB, error: errSB } = await adminClient
    .from('task_submissions')
    .insert({
      task_id: taskBId,
      content: { text: 'Enterprise B submission content' },
      submission_status: 'mock',
    })
    .select()
    .single()
  if (errSB) throw new Error(`Failed to create Submission B: ${errSB.message}`)
  submissionBId = sB.id

  // Create Deliverable for Task A
  const { data: dA, error: errDA } = await adminClient
    .from('processed_deliverables')
    .insert({
      task_id: taskAId,
      enterprise_id: enterpriseAId,
      deliverable_status: 'ready',
    })
    .select()
    .single()
  if (errDA) throw new Error(`Failed to create Deliverable A: ${errDA.message}`)
  deliverableAId = dA.id

  // Create Deliverable for Task B
  const { data: dB, error: errDB } = await adminClient
    .from('processed_deliverables')
    .insert({
      task_id: taskBId,
      enterprise_id: enterpriseBId,
      deliverable_status: 'ready',
    })
    .select()
    .single()
  if (errDB) throw new Error(`Failed to create Deliverable B: ${errDB.message}`)
  deliverableBId = dB.id

  console.log('  ✅ Test data seeded successfully\n')
}

// ============================================================
// Test teardown — remove all test data
// ============================================================

async function teardown() {
  console.log('\n🧹 Cleaning up test data...\n')

  // Delete in reverse dependency order
  await adminClient.from('processed_deliverables').delete().in('id', [deliverableAId, deliverableBId])
  await adminClient.from('task_submissions').delete().in('id', [submissionAId, submissionBId])
  await adminClient.from('tasks').delete().in('id', [taskAId, taskBId])
  await adminClient.from('enterprise_profiles').delete().in('id', [enterpriseAId, enterpriseBId])
  await adminClient.auth.admin.deleteUser(userAId)
  await adminClient.auth.admin.deleteUser(userBId)
  await adminClient.auth.admin.deleteUser(adminUserId)

  console.log('  ✅ Cleanup complete\n')
}

// ============================================================
// Tests — Enterprise A isolation
// ============================================================

async function testEnterpriseAIsolation() {
  console.log('📋 Enterprise A isolation tests\n')

  await signIn(clientA, process.env.TEST_ENTERPRISE_A_EMAIL!, process.env.TEST_ENTERPRISE_A_PASSWORD!)

  // enterprise_profiles
  const { data: ownProfile } = await clientA.from('enterprise_profiles').select().eq('id', enterpriseAId)
  assert(ownProfile?.length === 1, 'Enterprise A can read own profile')

  const { data: otherProfile } = await clientA.from('enterprise_profiles').select().eq('id', enterpriseBId)
  assert(otherProfile?.length === 0, 'Enterprise A cannot read Enterprise B profile')

  // tasks
  const { data: ownTasks } = await clientA.from('tasks').select().eq('id', taskAId)
  assert(ownTasks?.length === 1, 'Enterprise A can read own task')

  const { data: otherTasks } = await clientA.from('tasks').select().eq('id', taskBId)
  assert(otherTasks?.length === 0, 'Enterprise A cannot read Enterprise B task')

  // task_submissions
  const { data: ownSubmissions } = await clientA.from('task_submissions').select().eq('id', submissionAId)
  assert(ownSubmissions?.length === 1, 'Enterprise A can read submissions on own task')

  const { data: otherSubmissions } = await clientA.from('task_submissions').select().eq('id', submissionBId)
  assert(otherSubmissions?.length === 0, 'Enterprise A cannot read submissions on Enterprise B task')

  // processed_deliverables
  const { data: ownDeliverables } = await clientA.from('processed_deliverables').select().eq('id', deliverableAId)
  assert(ownDeliverables?.length === 1, 'Enterprise A can read own deliverable')

  const { data: otherDeliverables } = await clientA.from('processed_deliverables').select().eq('id', deliverableBId)
  assert(otherDeliverables?.length === 0, 'Enterprise A cannot read Enterprise B deliverable')

  // direct insert blocked
  const { error: insertError } = await clientA.from('enterprise_profiles').insert({
    user_id: userAId,
    name: 'Injected profile',
    email: 'injected@test.com',
    tier: 'validate_basic',
    subscription_status: 'active',
  })
  assert(insertError !== null, 'Enterprise A cannot directly insert enterprise_profiles (Edge Function only)')

  // direct transaction insert blocked
  const { error: txError } = await clientA.from('transactions').insert({
    transaction_type: 'subscription_payment',
    amount: 999,
  })
  assert(txError !== null, 'Enterprise A cannot directly insert transactions (Edge Function only)')

  await signOut(clientA)
  console.log('')
}

// ============================================================
// Tests — Enterprise B isolation
// ============================================================

async function testEnterpriseBIsolation() {
  console.log('📋 Enterprise B isolation tests\n')

  await signIn(clientB, process.env.TEST_ENTERPRISE_B_EMAIL!, process.env.TEST_ENTERPRISE_B_PASSWORD!)

  // enterprise_profiles
  const { data: ownProfile } = await clientB.from('enterprise_profiles').select().eq('id', enterpriseBId)
  assert(ownProfile?.length === 1, 'Enterprise B can read own profile')

  const { data: otherProfile } = await clientB.from('enterprise_profiles').select().eq('id', enterpriseAId)
  assert(otherProfile?.length === 0, 'Enterprise B cannot read Enterprise A profile')

  // tasks
  const { data: ownTasks } = await clientB.from('tasks').select().eq('id', taskBId)
  assert(ownTasks?.length === 1, 'Enterprise B can read own task')

  const { data: otherTasks } = await clientB.from('tasks').select().eq('id', taskAId)
  assert(otherTasks?.length === 0, 'Enterprise B cannot read Enterprise A task')

  // task_submissions
  const { data: ownSubmissions } = await clientB.from('task_submissions').select().eq('id', submissionBId)
  assert(ownSubmissions?.length === 1, 'Enterprise B can read submissions on own task')

  const { data: otherSubmissions } = await clientB.from('task_submissions').select().eq('id', submissionAId)
  assert(otherSubmissions?.length === 0, 'Enterprise B cannot read submissions on Enterprise A task')

  // processed_deliverables
  const { data: ownDeliverables } = await clientB.from('processed_deliverables').select().eq('id', deliverableBId)
  assert(ownDeliverables?.length === 1, 'Enterprise B can read own deliverable')

  const { data: otherDeliverables } = await clientB.from('processed_deliverables').select().eq('id', deliverableAId)
  assert(otherDeliverables?.length === 0, 'Enterprise B cannot read Enterprise A deliverable')

  await signOut(clientB)
  console.log('')
}

// ============================================================
// Tests — Admin sees everything
// ============================================================

async function testAdminAccess() {
  console.log('📋 Admin access tests\n')

  await signIn(adminUserClient, process.env.TEST_ADMIN_EMAIL!, process.env.TEST_ADMIN_PASSWORD!)

  // Admin sees both enterprise profiles
  const { data: profiles } = await adminUserClient.from('enterprise_profiles').select().in('id', [enterpriseAId, enterpriseBId])
  assert(profiles?.length === 2, 'Admin can read all enterprise profiles')

  // Admin sees both tasks
  const { data: tasks } = await adminUserClient.from('tasks').select().in('id', [taskAId, taskBId])
  assert(tasks?.length === 2, 'Admin can read all tasks')

  // Admin sees both submissions
  const { data: submissions } = await adminUserClient.from('task_submissions').select().in('id', [submissionAId, submissionBId])
  assert(submissions?.length === 2, 'Admin can read all task submissions')

  // Admin sees both deliverables
  const { data: deliverables } = await adminUserClient.from('processed_deliverables').select().in('id', [deliverableAId, deliverableBId])
  assert(deliverables?.length === 2, 'Admin can read all processed deliverables')

  await signOut(adminUserClient)
  console.log('')
}

// ============================================================
// Tests — Unauthenticated access blocked
// ============================================================

async function testUnauthenticatedBlocked() {
  console.log('📋 Unauthenticated access tests\n')

  const anonClient = createClient(supabaseUrl, process.env.VITE_SUPABASE_ANON_KEY!)

  const { data: profiles } = await anonClient.from('enterprise_profiles').select()
  assert(!profiles || profiles.length === 0, 'Unauthenticated cannot read enterprise_profiles')

  const { data: tasks } = await anonClient.from('tasks').select()
  assert(!tasks || tasks.length === 0, 'Unauthenticated cannot read tasks')

  const { data: submissions } = await anonClient.from('task_submissions').select()
  assert(!submissions || submissions.length === 0, 'Unauthenticated cannot read task_submissions')

  const { data: deliverables } = await anonClient.from('processed_deliverables').select()
  assert(!deliverables || deliverables.length === 0, 'Unauthenticated cannot read processed_deliverables')

  const { data: transactions } = await anonClient.from('transactions').select()
  assert(!transactions || transactions.length === 0, 'Unauthenticated cannot read transactions')

  console.log('')
}

// ============================================================
// Main runner
// ============================================================

async function run() {
  console.log('🔐 D15 RLS Isolation Test Suite\n')
  console.log('='.repeat(50))

  let passed = 0
  let failed = 0

  try {
    await setup()
    await testEnterpriseAIsolation()
    await testEnterpriseBIsolation()
    await testAdminAccess()
    await testUnauthenticatedBlocked()
    console.log('='.repeat(50))
    console.log('\n✅ All RLS isolation tests passed\n')
  } catch (error) {
    console.log('='.repeat(50))
    console.error(`\n❌ ${(error as Error).message}\n`)
    process.exit(1)
  } finally {
    await teardown()
  }
}

run()
