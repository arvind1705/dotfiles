// Cube Core configuration for the ITSM semantic layer.
//
// Every request must carry a JWT (signed with CUBEJS_API_SECRET) whose payload
// holds the caller's authorized `account_ids`. Queries without account scope
// are rejected.
//
// Tickets authorized only through an in-scope device are resolved in Dgraph by
// the MCP server. Their IDs travel in the query as a filter on
// `<cube>.deviceScopeTicket`, and the token carries `device_scope_digest`: the
// SHA-256 of the sorted, de-duplicated IDs joined by "\n". The IDs are admitted
// only when they match the digest, so the token stays small however many
// tickets the device route yields.

const crypto = require('crypto');
// Cube's own handler error maps to an HTTP status (403 here) instead of 500,
// and its message is returned without a stack trace.
const { CubejsHandlerError } = require('@cubejs-backend/api-gateway/dist/src/cubejs-handler-error');

// Cubes that can be queried directly and the members used to scope them.
// `ticket` is set for ticket cubes so device-route tickets can be admitted.
const TICKET_SCOPE = {
  incidents: { account: 'scopeAccountId', ticket: 'deviceScopeTicket' },
  cases: { account: 'scopeAccountId', ticket: 'deviceScopeTicket' },
  change_requests: { account: 'scopeAccountId', ticket: 'deviceScopeTicket' },
  pet_requests: { account: 'scopeAccountId', ticket: 'deviceScopeTicket' },
  tac_cases: { account: 'scopeAccountId', ticket: 'deviceScopeTicket' },
  tickets: { account: 'scopeAccountId', ticket: 'deviceScopeTicket' },
  org: { account: 'accountId', ticket: null },
};

// Cubes that are only reachable through a scoped cube (joins).
const JOINED_ONLY = new Set([
  'incident_comments', 'sla', 'incident_sla', 'case_sla', 'change_request_sla',
  'pet_request_sla', 'incident_case_links', 'incident_devices',
]);

class ScopeError extends CubejsHandlerError {
  constructor(message) {
    super(403, 'Forbidden', message);
  }
}

function cubesInQuery(query) {
  const members = [
    ...(query.measures || []),
    ...(query.dimensions || []),
    ...(query.segments || []),
    ...(query.timeDimensions || []).map((td) => td.dimension),
    ...collectFilterMembers(query.filters || []),
  ];
  return new Set(members.map((member) => member.split('.')[0]));
}

function collectFilterMembers(filters) {
  const out = [];
  for (const filter of filters) {
    if (filter.member || filter.dimension) out.push(filter.member || filter.dimension);
    if (filter.and) out.push(...collectFilterMembers(filter.and));
    if (filter.or) out.push(...collectFilterMembers(filter.or));
  }
  return out;
}

function isDeviceScopeMember(member) {
  return typeof member === 'string' && member.endsWith('.deviceScopeTicket');
}

function digestOf(ids) {
  const unique = [...new Set(ids.map(String))].sort();
  return crypto.createHash('sha256').update(unique.join('\n')).digest('hex');
}

// Pull top-level device-route filters out of the query, verify them against
// the signed digest, and return the admitted IDs plus the remaining filters.
function extractDeviceScope(filters, digest) {
  const remaining = [];
  let ids = null;
  for (const filter of filters) {
    const member = filter.member || filter.dimension;
    if (isDeviceScopeMember(member)) {
      if (filter.operator !== 'equals' || !Array.isArray(filter.values)) {
        throw new ScopeError('device scope filter must use the equals operator');
      }
      if (ids !== null) throw new ScopeError('only one device scope filter is allowed');
      ids = filter.values;
      continue;
    }
    if (collectFilterMembers([filter]).some(isDeviceScopeMember)) {
      throw new ScopeError('device scope filter must be a top-level filter');
    }
    remaining.push(filter);
  }
  if (ids === null) return { ids: [], remaining };
  if (typeof digest !== 'string' || digestOf(ids) !== digest) {
    throw new ScopeError('device scope tickets do not match the signed digest');
  }
  return { ids, remaining };
}

module.exports = {
  queryRewrite: (query, { securityContext }) => {
    const context = securityContext || {};
    const accountIds = context.account_ids;
    if (!Array.isArray(accountIds) || accountIds.length === 0) {
      throw new ScopeError('account scope required: account_ids missing from security context');
    }

    const cubes = cubesInQuery(query);
    const scoped = [...cubes].filter((cube) => TICKET_SCOPE[cube]);
    for (const cube of cubes) {
      if (!TICKET_SCOPE[cube] && !JOINED_ONLY.has(cube)) {
        throw new ScopeError(`cube "${cube}" is not exposed under account scope`);
      }
    }
    if (scoped.length === 0) {
      throw new ScopeError('query must include a scoped cube');
    }
    for (const member of [...(query.dimensions || []), ...(query.measures || [])]) {
      if (isDeviceScopeMember(member)) {
        throw new ScopeError('deviceScopeTicket is a scope input, not a selectable member');
      }
    }

    const { ids: deviceTickets, remaining } = extractDeviceScope(
      query.filters || [],
      context.device_scope_digest,
    );

    const scopeFilters = scoped.map((cube) => {
      const members = TICKET_SCOPE[cube];
      const byAccount = {
        member: `${cube}.${members.account}`,
        operator: 'equals',
        values: accountIds,
      };
      if (deviceTickets.length === 0 || !members.ticket) return byAccount;
      return {
        or: [
          byAccount,
          { member: `${cube}.${members.ticket}`, operator: 'equals', values: deviceTickets },
        ],
      };
    });

    return { ...query, filters: [...remaining, ...scopeFilters] };
  },
};
