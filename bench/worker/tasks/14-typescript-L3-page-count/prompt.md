Bug report for the `pager` package (see README.md):

Our users table has exactly 20 users and shows 10 per page. The footer offers
pages 1, 2 and 3, and page 3 is empty; on page 2 the "next" button is still
enabled. The same happens for every list whose length is an exact multiple of
the page size (30 items with 10 per page shows 4 pages, and so on).

Find the cause and fix it, without changing the documented behavior. Add a
test that reproduces the problem to `test/paginate.test.ts`, then run
`node --test` and make sure every test passes. Change only files under `src/`
and `test/paginate.test.ts`.
