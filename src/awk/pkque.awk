
@include "foundation.awk"
@include "query.awk"

BEGIN {
    for (i = 1; i < ARGC; i++) {
        if (ARGV[i] ~ /^-(s|-strict)$/) {
            query["strict"] = 1;
        } else if (ARGV[i] ~ /^-([^=]+)=([^=]+)$/) {
            match(ARGV[i], /^([^=]+)=([^=]+)$/, m);
            option = m[1];
            value = m[2];

            if (option ~ /^-R$|^--root$/)           root = value;
            else if (option ~ /^-r$|^--repo$/)      query["repo_id"] = query["repo_id"] "|" value;
            else if (option ~ /^-e$|^--series$/)    query["series"]  = query["series"]  "|" value;
            else if (option ~ /^-v$|^--version$/)   query["version"] = query["version"] "|" value;
            else if (option ~ /^-a$|^--arch$/)      query["arch"]    = query["arch"]    "|" value;
            else if (option ~ /^-t$|^--tag$/)       query["tag"]     = query["tag"]     "|" value;
            else {
                printf "Unrecognized option: %s\n", option;
                exit 1;
            }
        } else {
            query["name"] = query["name"] "|" ARGV[i];
        }
    }

    for (j in query) sub(/^\|/, "", query[j]);

    setup_dirs(dirs, root);

    n = do_query(dirs["lib"]"/index.dat", query, results, 1);
    if (!n) {
        printf "No packages found.\n";
        exit 0;
    }

    printf "%d packages found:\n", n;

    for (p = 1; p <= n; p++) {
        printf "%-18s%-32s%s-%s-%s%s\n", results[p]["repo_id"],
            results[p]["name"], results[p]["version"], results[p]["arch"],
            results[p]["build"], results[p]["tag"];
    }

    printf "\n";
}
