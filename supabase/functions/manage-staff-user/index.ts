import { createClient } from 'npm:@supabase/supabase-js@2.112.4'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

class RequestError extends Error {
  status: number
  constructor(message: string, status = 400) {
    super(message)
    this.status = status
  }
}

const respond = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json; charset=utf-8' },
  })

function envKey(jsonName: string, legacyName: string) {
  try {
    const values = JSON.parse(Deno.env.get(jsonName) ?? '{}')
    if (values.default) {
      const selected = String(values.default)
      return Deno.env.get(selected) ?? selected
    }
  } catch {
    // Se usa la variable compatible de respaldo.
  }
  return Deno.env.get(legacyName) ?? ''
}

const staffFields = [
  'full_name',
  'email',
  'username',
  'role',
  'status',
  'activated_at',
  'inactivated_at',
  'can_run_tests',
  'can_review',
  'can_approve_reports',
  'can_manage_records',
  'authorized_tests',
  'notes',
] as const

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return respond({ error: 'Método no permitido.' }, 405)

  try {
    const url = Deno.env.get('SUPABASE_URL') ?? ''
    const serviceKey = envKey('SUPABASE_SECRET_KEYS', 'SUPABASE_SERVICE_ROLE_KEY')
    if (!url || !serviceKey) throw new RequestError('Configuración segura no disponible.', 500)

    const authorization = req.headers.get('Authorization') ?? ''
    const token = authorization.replace(/^Bearer\s+/i, '')
    if (!token) throw new RequestError('Sesión requerida.', 401)

    const adminClient = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const { data: callerData, error: callerError } = await adminClient.auth.getUser(token)
    if (callerError || !callerData.user) throw new RequestError('Sesión no válida.', 401)

    let { data: caller } = await adminClient
      .from('staff')
      .select('id,email,status,can_manage_records')
      .eq('auth_user_id', callerData.user.id)
      .maybeSingle()

    if (!caller && callerData.user.email) {
      const result = await adminClient
        .from('staff')
        .select('id,email,status,can_manage_records')
        .ilike('email', callerData.user.email)
        .maybeSingle()
      caller = result.data
    }

    if (!caller?.can_manage_records || caller.status !== 'Activo') {
      throw new RequestError('Solo un administrador activo puede gestionar accesos.', 403)
    }

    const body = await req.json()
    const action = String(body.action ?? 'upsert')
    const staffId = body.staff_id ? String(body.staff_id) : null

    if (action === 'status') {
      if (!staffId || !['Activo', 'Inactivo'].includes(body.status)) {
        throw new RequestError('Estado de personal no válido.')
      }
      const { data: target, error: targetError } = await adminClient
        .from('staff')
        .select('*')
        .eq('id', staffId)
        .single()
      if (targetError || !target) throw new RequestError('No se encontró la persona.', 404)

      if (target.auth_user_id) {
        const { data: authData } = await adminClient.auth.admin.getUserById(target.auth_user_id)
        const { error: authError } = await adminClient.auth.admin.updateUserById(target.auth_user_id, {
          ban_duration: body.status === 'Inactivo' ? '876000h' : 'none',
          app_metadata: {
            ...(authData.user?.app_metadata ?? {}),
            active: body.status === 'Activo',
          },
        })
        if (authError) throw new RequestError('No se pudo actualizar el acceso: ' + authError.message)
      }

      const today = new Date().toISOString().slice(0, 10)
      const statusPatch = body.status === 'Inactivo'
        ? { status: 'Inactivo', inactivated_at: today }
        : { status: 'Activo', activated_at: target.activated_at ?? today, inactivated_at: null }
      const { error: statusError } = await adminClient.from('staff').update(statusPatch).eq('id', staffId)
      if (statusError) throw new RequestError(statusError.message)
      return respond({ ok: true })
    }

    if (action !== 'upsert') throw new RequestError('Acción no válida.')

    const input = body.profile ?? {}
    const profile: Record<string, unknown> = {}
    for (const key of staffFields) {
      if (Object.prototype.hasOwnProperty.call(input, key)) profile[key] = input[key]
    }

    const username = String(profile.username ?? '').trim().toLowerCase()
    const email = String(profile.email ?? '').trim().toLowerCase()
    const fullName = String(profile.full_name ?? '').trim()
    const password = String(body.password ?? '')
    if (!/^[a-z0-9][a-z0-9._-]{2,63}$/.test(username)) {
      throw new RequestError('El usuario debe tener entre 3 y 64 caracteres: letras minúsculas, números, punto, guion o guion bajo.')
    }
    if (!/^\S+@\S+\.\S+$/.test(email)) throw new RequestError('Ingresá un correo válido.')
    if (!fullName) throw new RequestError('Ingresá el nombre completo.')
    if (password && password.length < 6) throw new RequestError('La contraseña debe tener al menos 6 caracteres.')

    profile.username = username
    profile.email = email
    profile.full_name = fullName
    profile.status = profile.status === 'Inactivo' ? 'Inactivo' : 'Activo'

    let existing: Record<string, any> | null = null
    if (staffId) {
      const result = await adminClient.from('staff').select('*').eq('id', staffId).single()
      if (result.error || !result.data) throw new RequestError('No se encontró la persona.', 404)
      existing = result.data
    }

    let usernameQuery = adminClient.from('staff').select('id').ilike('username', username)
    if (staffId) usernameQuery = usernameQuery.neq('id', staffId)
    const { data: usernameOwner } = await usernameQuery.maybeSingle()
    if (usernameOwner) throw new RequestError('Ese nombre de usuario ya está asignado.')

    let emailQuery = adminClient.from('staff').select('id').ilike('email', email)
    if (staffId) emailQuery = emailQuery.neq('id', staffId)
    const { data: emailOwner } = await emailQuery.maybeSingle()
    if (emailOwner) throw new RequestError('Ese correo ya está asignado a otra persona.')

    let authUserId = existing?.auth_user_id as string | undefined
    if (!authUserId) {
      const { data: usersPage } = await adminClient.auth.admin.listUsers({ page: 1, perPage: 1000 })
      authUserId = usersPage.users.find((user) => user.email?.toLowerCase() === email)?.id
    }

    let createdAuthUser = false
    if (!authUserId) {
      if (!password) throw new RequestError('Ingresá una contraseña provisoria para habilitar el acceso.')
      const { data: created, error: createError } = await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: fullName, username },
        app_metadata: {
          role: profile.role ?? 'Consulta',
          active: profile.status === 'Activo',
        },
      })
      if (createError || !created.user) throw new RequestError(createError?.message ?? 'No se pudo crear el acceso.')
      authUserId = created.user.id
      createdAuthUser = true
    } else {
      const { data: authData } = await adminClient.auth.admin.getUserById(authUserId)
      const attributes: Record<string, unknown> = {
        email,
        email_confirm: true,
        ban_duration: profile.status === 'Inactivo' ? '876000h' : 'none',
        user_metadata: {
          ...(authData.user?.user_metadata ?? {}),
          full_name: fullName,
          username,
        },
        app_metadata: {
          ...(authData.user?.app_metadata ?? {}),
          role: profile.role ?? 'Consulta',
          active: profile.status === 'Activo',
        },
      }
      if (password) attributes.password = password
      const { error: updateAuthError } = await adminClient.auth.admin.updateUserById(authUserId, attributes)
      if (updateAuthError) throw new RequestError('No se pudo actualizar el acceso: ' + updateAuthError.message)
    }

    profile.auth_user_id = authUserId
    const today = new Date().toISOString().slice(0, 10)
    if (profile.status === 'Activo') {
      profile.activated_at = profile.activated_at || existing?.activated_at || today
      profile.inactivated_at = null
    } else {
      profile.inactivated_at = profile.inactivated_at || today
    }

    const staffResult = existing
      ? await adminClient.from('staff').update(profile).eq('id', existing.id).select('*').single()
      : await adminClient.from('staff').insert(profile).select('*').single()

    if (staffResult.error) {
      if (createdAuthUser && authUserId) await adminClient.auth.admin.deleteUser(authUserId)
      throw new RequestError(staffResult.error.message)
    }

    if (createdAuthUser && profile.status === 'Inactivo' && authUserId) {
      await adminClient.auth.admin.updateUserById(authUserId, { ban_duration: '876000h' })
    }

    return respond({
      ok: true,
      staff: staffResult.data,
      access_configured: true,
      password_updated: Boolean(password),
    })
  } catch (error) {
    const status = error instanceof RequestError ? error.status : 500
    const message = error instanceof Error ? error.message : 'Error inesperado.'
    return respond({ error: message }, status)
  }
})
