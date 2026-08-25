const ROLE_PERMISSIONS = Object.freeze({
  owner: new Set(['product:read', 'product:write', 'sale:create', 'sale:void', 'inventory:read', 'inventory:write', 'customer:read', 'customer:write', 'report:read', 'audit:read', 'settings:write']),
  admin: new Set(['product:read', 'product:write', 'sale:create', 'sale:void', 'inventory:read', 'inventory:write', 'customer:read', 'customer:write', 'report:read', 'audit:read', 'settings:write']),
  manager: new Set(['product:read', 'product:write', 'sale:create', 'sale:void', 'inventory:read', 'inventory:write', 'customer:read', 'customer:write', 'report:read', 'audit:read']),
  cashier: new Set(['product:read', 'sale:create', 'inventory:read', 'customer:read', 'customer:write']),
  inventory_operator: new Set(['product:read', 'inventory:read', 'inventory:write', 'report:read']),
  viewer: new Set(['product:read', 'inventory:read', 'customer:read', 'report:read']),
  auditor: new Set(['product:read', 'inventory:read', 'customer:read', 'report:read', 'audit:read']),
});

function requirePermission(permission) {
  return (req, res, next) => {
    const role = req.organization?.role;
    const permissions = ROLE_PERMISSIONS[role];

    if (!permissions || !permissions.has(permission)) {
      return res.status(403).json({
        error: {
          code: 'PERMISSION_DENIED',
          message: `Permission denied: ${permission}`,
        },
      });
    }

    req.permission = permission;
    next();
  };
}

module.exports = { ROLE_PERMISSIONS, requirePermission };
