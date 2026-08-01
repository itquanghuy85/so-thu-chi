import { ValueTransformer } from 'typeorm';

/**
 * Postgres `bigint` columns come back from `pg` as strings (since they may
 * exceed JS's safe integer range). We store all money amounts (đồng) as
 * whole-number bigint columns to avoid float rounding issues, and use this
 * transformer to get plain `number`s back on the entity side. Amounts in
 * this app are well within Number.MAX_SAFE_INTEGER.
 */
export const bigintTransformer: ValueTransformer = {
  to: (value?: number) => value,
  from: (value?: string) => (value === null || value === undefined ? value : parseInt(value, 10)),
};
