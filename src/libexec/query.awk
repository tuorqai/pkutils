BEGIN {
    FS = ":"
    total_packages = 0
}

$2 ~ REPO_QUERY &&
$7 ~ SERIES_QUERY &&
$8 ~ NAME_QUERY &&
$9 ~ VERSION_QUERY &&
$10 ~ ARCH_QUERY &&
$12 ~ TAG_QUERY {
    if (INSTAMODE) {
        if ($8 in STASH) {
            next
        }
        STASH[$8] = $9
    }
    print $0
    total_packages++
}

END {
    print total_packages > "/dev/stderr"
}