const { supabase } = require('../lib/supabase');

async function requireOrganizationMember(req, res, next) {
  const organizationId = req.header('x-organization-id');
  if (!organizationId) return res.status(400).json({ error: { code: 'ORG_REQUIRED', message: 'x-organization-id is required' } });

  const { data, error } = await supabase
    .from('organization_members')
    .select('id, role, status')
    .eq('organization_id', organizationId)
    .eq('user_id', req.user.id)
    .eq('status', 'active')
    .maybeSingle();

  if (error) return next(error);
  if (!data) return res.status(403).json({ error: { code: 'ORG_FORBIDDEN', message: 'User is not an active organization member' } });

  req.organization = { id: organizationId, role: data.role };
  next();
}

async function requireOutlet(req, res, next) {
  const outletId = req.header('x-outlet-id');
  if (!outletId) return res.status(400).json({ error: { code: 'OUTLET_REQUIRED', message: 'x-outlet-id is required' } });

  const { data, error } = await supabase
    .from('outlets')
    .select('id, name, code, status')
    .eq('id', outletId)
    .eq('organization_id', req.organization.id)
    .eq('status', 'active')
    .maybeSingle();

  if (error) return next(error);
  if (!data) return res.status(403).json({ error: { code: 'OUTLET_FORBIDDEN', message: 'Outlet is not available in the selected organization' } });

  req.outlet = data;
  next();
}

module.exports = { requireOrganizationMember, requireOutlet };
