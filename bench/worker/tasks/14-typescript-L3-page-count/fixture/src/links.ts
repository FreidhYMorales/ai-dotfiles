// Page links for the table footer: first, last and a window around the
// current page, with null marking a gap ("…").
import { pageCount } from "./paginate.ts";

export function pageLinks(total: number, perPage: number, current: number, radius = 1): (number | null)[] {
  const count = pageCount(total, perPage);
  const links: (number | null)[] = [];
  for (let p = 1; p <= count; p++) {
    if (p === 1 || p === count || Math.abs(p - current) <= radius) {
      links.push(p);
    } else if (links[links.length - 1] !== null) {
      links.push(null);
    }
  }
  return links;
}
