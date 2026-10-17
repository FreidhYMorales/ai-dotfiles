// Slice a list into pages. Pages are 1-based.

export interface Page<T> {
  items: T[];
  page: number;
  pageCount: number;
  total: number;
  hasPrev: boolean;
  hasNext: boolean;
}

/** Number of pages for `total` items; an empty list still has one page. */
export function pageCount(total: number, perPage: number): number {
  return Math.floor(total / perPage) + 1;
}

/**
 * Page `page` of `items`, `perPage` per page. Out-of-range pages are clamped
 * to the first/last page. Throws when perPage is not a positive integer.
 */
export function paginate<T>(items: T[], page: number, perPage: number): Page<T> {
  if (!Number.isInteger(perPage) || perPage < 1) {
    throw new RangeError(`perPage must be a positive integer, got ${perPage}`);
  }
  const count = pageCount(items.length, perPage);
  const current = Math.min(Math.max(1, Math.trunc(page) || 1), count);
  const start = (current - 1) * perPage;
  return {
    items: items.slice(start, start + perPage),
    page: current,
    pageCount: count,
    total: items.length,
    hasPrev: current > 1,
    hasNext: current < count,
  };
}
