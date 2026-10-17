In `plugins/toolkit/hooks/host-info.sh`, detect Gentoo's package manager
`emerge` like the other package managers, so a Gentoo host reports
`packages: emerge`. Add a test case for it in
`plugins/toolkit/hooks/tests/host-info.test.sh`, following the existing fake-host
cases. Then run `make check` and make sure it ends with "All checks passed".
Change only those two files.
