import { createClient } from 'npm:@supabase/supabase-js@2.112.4'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const respond = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders, 'Content-Type': 'application/json; charset=utf-8' },
})

function envKey(jsonName: string, legacyName: string) {
  try {
    const values = JSON.parse(Deno.env.get(jsonName) ?? '{}')
    if (values.default) return String(values.default)
  } catch {
    // Se usa la variable compatible de respaldo.
  }
  return Deno.env.get(legacyName) ?? ''
}

function escapeHtml(value: unknown) {
  return String(value ?? '').replaceAll('&', '&amp;').replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#039;')
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return respond({ error: 'Método no permitido.' }, 405)

  const url = Deno.env.get('SUPABASE_URL') ?? ''
  const serviceKey = envKey('SUPABASE_SECRET_KEYS', 'SUPABASE_SERVICE_ROLE_KEY')
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '')
  if (!url || !serviceKey) return respond({ error: 'Configuración segura no disponible.' }, 500)
  if (!token) return respond({ error: 'Sesión requerida.' }, 401)

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } })
  const { data: userData, error: userError } = await admin.auth.getUser(token)
  if (userError || !userData.user) return respond({ error: 'Sesión no válida.' }, 401)

  const callerQuery = admin.from('staff').select('id,status,can_run_tests,can_review,can_manage_records')
    .eq('auth_user_id', userData.user.id).limit(1).maybeSingle()
  let { data: caller } = await callerQuery
  if (!caller && userData.user.email) {
    const fallback = await admin.from('staff').select('id,status,can_run_tests,can_review,can_manage_records')
      .ilike('email', userData.user.email).limit(1).maybeSingle()
    caller = fallback.data
  }
  if (!caller || caller.status !== 'Activo' || !(caller.can_run_tests || caller.can_review || caller.can_manage_records)) {
    return respond({ error: 'No tenés permiso para notificar resultados.' }, 403)
  }

  const body = await req.json().catch(() => ({}))
  const testId = String(body.sample_test_id ?? '')
  if (!testId) return respond({ error: 'Falta identificar el ensayo.' }, 400)

  const { data: test, error: testError } = await admin.from('sample_tests')
    .select('id,test_name,final_result,units,classification,compliance,assigned_to,sample_id,samples(sample_name,product,lot,batch)')
    .eq('id', testId).single()
  if (testError || !test) return respond({ error: 'No se encontró el ensayo.' }, 404)
  if (String(test.compliance ?? '').toLowerCase() !== 'no cumple') {
    return respond({ ok: true, email_sent: false, skipped: 'El ensayo no está marcado como No cumple.' })
  }

  const { data: recipientsRows } = await admin.from('staff').select('id,email')
    .eq('status', 'Activo').or(`id.eq.${test.assigned_to},can_manage_records.eq.true`)
  const recipients = [...new Set((recipientsRows ?? []).map(row => row.email?.toLowerCase()).filter(Boolean))] as string[]
  if (!recipients.length) return respond({ error: 'No hay correos válidos para el responsable o el administrador.' }, 422)

  let { data: alert } = await admin.from('lab_alerts').select('id,email_status')
    .eq('related_table', 'sample_tests').eq('related_id', testId)
    .eq('alert_type', 'Ensayo no conforme').maybeSingle()
  if (!alert) {
    const sample = Array.isArray(test.samples) ? test.samples[0] : test.samples
    const inserted = await admin.from('lab_alerts').insert({
      alert_type: 'Ensayo no conforme',
      title: `Ensayo no conforme: ${test.test_name}`,
      detail: `Muestra ${sample?.sample_name ?? test.sample_id} · Resultado ${test.final_result ?? 'sin valor'} ${test.units ?? ''}`.trim(),
      related_table: 'sample_tests', related_id: testId,
      recipient_emails: recipients, email_status: 'Pendiente',
    }).select('id,email_status').single()
    alert = inserted.data
  }
  if (!alert) return respond({ error: 'No se pudo registrar la alerta.' }, 500)
  if (alert.email_status === 'Enviado') return respond({ ok: true, email_sent: true, recipients })

  const resendKey = Deno.env.get('RESEND_API_KEY') ?? ''
  const from = Deno.env.get('ALERT_EMAIL_FROM') ?? ''
  if (!resendKey || !from) {
    await admin.from('lab_alerts').update({
      recipient_emails: recipients, email_status: 'Configuración pendiente',
      email_attempted_at: new Date().toISOString(),
      email_error: 'Faltan RESEND_API_KEY o ALERT_EMAIL_FROM.',
    }).eq('id', alert.id)
    return respond({ ok: true, email_sent: false, warning: 'La alerta quedó registrada; falta configurar el remitente de correo.' })
  }

  const sample = Array.isArray(test.samples) ? test.samples[0] : test.samples
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${resendKey}` },
    body: JSON.stringify({
      from, to: recipients,
      subject: `[SEGOD] Ensayo no conforme · ${test.test_name}`,
      html: `<div style="font-family:Arial,sans-serif;color:#002747;line-height:1.5">
        <h2>Ensayo no conforme</h2>
        <p><strong>Muestra:</strong> ${escapeHtml(sample?.sample_name ?? test.sample_id)}</p>
        <p><strong>Material:</strong> ${escapeHtml(sample?.product ?? '—')}</p>
        <p><strong>Lote / Partida:</strong> ${escapeHtml([sample?.lot, sample?.batch].filter(Boolean).join(' / ') || '—')}</p>
        <p><strong>Ensayo:</strong> ${escapeHtml(test.test_name)}</p>
        <p><strong>Resultado:</strong> ${escapeHtml(test.final_result ?? '—')} ${escapeHtml(test.units ?? '')}</p>
        <p><strong>Nivel:</strong> ${escapeHtml(test.classification ?? '—')}</p>
        <p style="color:#c2410c"><strong>Cumplimiento: No cumple</strong></p>
        <p>Ingresá al Sistema de Gestión del Laboratorio para revisar el registro completo.</p>
      </div>`,
    }),
  })

  const attemptedAt = new Date().toISOString()
  if (!response.ok) {
    const detail = (await response.text()).slice(0, 1000)
    await admin.from('lab_alerts').update({ recipient_emails: recipients, email_status: 'Error',
      email_attempted_at: attemptedAt, email_error: detail }).eq('id', alert.id)
    return respond({ ok: true, email_sent: false, warning: 'La alerta quedó registrada, pero el correo no pudo enviarse.' })
  }

  await admin.from('lab_alerts').update({ recipient_emails: recipients, email_status: 'Enviado',
    email_attempted_at: attemptedAt, email_sent_at: attemptedAt, email_error: null }).eq('id', alert.id)
  return respond({ ok: true, email_sent: true, recipients })
})
