import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const respond = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return respond({ error: 'Method not allowed' }, 405);

  const authorization = request.headers.get('Authorization');
  const token = authorization?.replace(/^Bearer\s+/i, '');
  if (!token) return respond({ error: 'Sesi admin tidak ditemukan.' }, 401);

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anonKey || !serviceKey) {
    return respond({ error: 'Konfigurasi fungsi belum lengkap.' }, 500);
  }

  // Verify the caller's JWT with Auth, then use a server-only key for admin operations.
  const authClient = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser(token);
  if (authError || !authData.user) return respond({ error: 'Sesi tidak valid.' }, 401);

  const adminClient = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: caller, error: callerError } = await adminClient
    .from('profiles')
    .select('role')
    .eq('id', authData.user.id)
    .maybeSingle();
  if (callerError || caller?.role !== 'admin') {
    return respond({ error: 'Hanya admin yang dapat menghapus akun warga.' }, 403);
  }

  let userId: unknown;
  try {
    userId = (await request.json()).user_id;
  } catch {
    return respond({ error: 'Permintaan tidak valid.' }, 400);
  }
  if (typeof userId !== 'string' || !/^[0-9a-f-]{36}$/i.test(userId)) {
    return respond({ error: 'ID akun tidak valid.' }, 400);
  }

  const { data: target, error: targetError } = await adminClient
    .from('profiles')
    .select('role')
    .eq('id', userId)
    .maybeSingle();
  if (targetError) return respond({ error: 'Gagal memeriksa akun tujuan.' }, 500);
  if (!target || target.role !== 'warga') {
    return respond({ error: 'Akun tujuan bukan akun warga atau sudah dihapus.' }, 404);
  }

  const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);
  if (deleteError) return respond({ error: 'Penghapusan akun gagal.' }, 500);
  return respond({ success: true });
});
