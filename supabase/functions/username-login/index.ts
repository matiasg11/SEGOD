import { createClient } from 'npm:@supabase/supabase-js@2.112.4'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
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

function safeRedirect(candidate: unknown) {
  const allowed = new Set([
    'https://segod-laboratorio.matiasg11.chatgpt.site',
    'https://matiasg11.github.io',
    'http://localhost:3000',
    'http://127.0.0.1:4173',
  ])
  try {
    const url = new URL(String(candidate ?? ''))
    return allowed.has(url.origin) ? url.href : 'https://segod-laboratorio.matiasg11.chatgpt.site/'
  } catch {
    return 'https://segod-laboratorio.matiasg11.chatgpt.site/'
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return respond({ error: 'Método no permitido.' }, 405)

  try {
    const url = Deno.env.get('SUPABASE_URL') ?? ''
    const serviceKey = envKey('SUPABASE_SECRET_KEYS', 'SUPABASE_SERVICE_ROLE_KEY')
    const publishableKey = envKey('SUPABASE_PUBLISHABLE_KEYS', 'SUPABASE_ANON_KEY')
    if (!url || !serviceKey || !publishableKey) return respond({ error: 'Acceso no disponible.' }, 500)

    const body = await req.json()
    const username = String(body.username ?? '').trim().toLowerCase()
    if (!/^[a-z0-9][a-z0-9._-]{2,63}$/.test(username)) {
      return respond({ error: 'Usuario o contraseña incorrectos.' }, 400)
    }

    const adminClient = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const { data: person, error: personError } = await adminClient
      .from('staff')
      .select('id,email,auth_user_id,status')
      .ilike('username', username)
      .eq('status', 'Activo')
      .maybeSingle()
    if (personError) return respond({ error: 'Acceso no disponible.' }, 500)

    if (body.recover === true) {
      if (person?.email) {
        const publicClient = createClient(url, publishableKey, {
          auth: { persistSession: false, autoRefreshToken: false },
        })
        await publicClient.auth.resetPasswordForEmail(person.email, {
          redirectTo: safeRedirect(body.redirect_to),
        })
      }
      return respond({ ok: true })
    }

    const password = String(body.password ?? '')
    if (!person?.email || !password) return respond({ error: 'Usuario o contraseña incorrectos.' }, 400)

    const publicClient = createClient(url, publishableKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const { data, error } = await publicClient.auth.signInWithPassword({
      email: person.email,
      password,
    })
    if (error && error.code !== 'invalid_credentials') {
      return respond({ error: 'Acceso no disponible.' }, 500)
    }
    if (error || !data.session || !data.user) {
      return respond({ error: 'Usuario o contraseña incorrectos.' }, 400)
    }

    if (!person.auth_user_id) {
      await adminClient.from('staff').update({ auth_user_id: data.user.id }).eq('id', person.id)
    }

    return respond({
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      expires_at: data.session.expires_at,
      expires_in: data.session.expires_in,
      token_type: data.session.token_type,
      user: { id: data.user.id, email: data.user.email },
    })
  } catch {
    return respond({ error: 'Usuario o contraseña incorrectos.' }, 400)
  }
})
