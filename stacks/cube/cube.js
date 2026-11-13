// Cube Core configuration for the ITSM semantic layer.
//
// Every request must carry a JWT (signed with CUBEJS_API_SECRET) whose payload
// holds the caller's authorized `account_ids`. Queries without account scope
// are rejected.
//
// A caller may see a ticket raised by one of their accounts or sub-accounts,
// located at one of their sites or sub-sites, or affecting one of their
// devices. Each ticket cube computes `scopeAccounts`, every account that may
// see the ticket as ",hex(A),hex(B),", from the org directory and the device
// inventory (see globals.py), and every query is narrowed to tickets whose
// list holds one of the caller's accounts.

// Cube's own handler error maps to an HTTP status (403 here) instead of 500,
// and its message is returned without a stack trace.
const { CubejsHandlerError } = require('@cubejs-backend/api-gateway/dist/src/cubejs-handler-error');

// Cubes that can be queried directly and how each is scoped: `accounts` is a
// ",hex(A),hex(B)," list matched per caller account, `account` a single
// account column.
const TICKET_SCOPE = {
  incidents: { accounts: 'scopeAccounts' },
  cases: { accounts: 'scopeAccounts' },
  change_requests: { accounts: 'scopeAccounts' },
  pet_requests: { accounts: 'scopeAccounts' },
  tac_cases: { accounts: 'scopeAccounts' },
  tickets: { accounts: 'scopeAccounts' },
  org: { account: 'accountId' },
  bug_details: { account: 'accountId' },
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

// The account lists name other accounts, so they are a scope input only.
function isScopeListMember(member) {
  return typeof member === 'string' && member.endsWith('.scopeAccounts');
}

// `order` is an object or a list of [member, direction] pairs.
function orderMembers(order) {
  if (!order) return [];
  return Array.isArray(order) ? order.map((pair) => pair[0]) : Object.keys(order);
}

module.exports = {
  queryRewrite: (query, { securityContext }) => {
    const context = securityContext || {};
    const accountIds = context.account_ids;
    if (!Array.isArray(accountIds) || accountIds.length === 0) {
      throw new ScopeError('account scope required: account_ids missing from security context');
    }
    for (const id of accountIds) {
      // The list match is ",id,", so an ID must not contain the delimiter.
      if (typeof id !== 'string' || id === '' || id.includes(',')) {
        throw new ScopeError('account_ids must be non-empty strings without commas');
      }
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
    const selected = [
      ...(query.dimensions || []),
      ...(query.measures || []),
      ...(query.timeDimensions || []).map((td) => td.dimension),
      ...orderMembers(query.order),
      ...collectFilterMembers(query.filters || []),
    ];
    if (selected.some(isScopeListMember)) {
      throw new ScopeError('scopeAccounts is a scope input, not a queryable member');
    }

    const scopeFilters = scoped.map((cube) => {
      const members = TICKET_SCOPE[cube];
      if (members.account) {
        return { member: `${cube}.${members.account}`, operator: 'equals', values: accountIds };
      }
      // Cube compiles `contains` to ILIKE (wildcards escaped), one alternative
      // per value. The lists hold lower-case hex of each ID, so the
      // case-insensitive match is exact.
      return {
        member: `${cube}.${members.accounts}`,
        operator: 'contains',
        values: accountIds.map((id) => `,${Buffer.from(id, 'utf8').toString('hex')},`),
      };
    });

    return { ...query, filters: [...(query.filters || []), ...scopeFilters] };
  },
};
