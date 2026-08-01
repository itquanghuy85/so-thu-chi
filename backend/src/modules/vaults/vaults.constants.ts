/**
 * Every workspace gets two internal (type='virtual') vaults on creation,
 * used as the counter-party leg of income/expense double-entry postings.
 * They are looked up by (workspace_id, type='virtual', name) rather than
 * storing their ids on the Workspace row.
 */
export const VIRTUAL_VAULT_NAMES = {
  REVENUE: 'Doanh thu',
  EXPENSE: 'Chi phí',
} as const;
