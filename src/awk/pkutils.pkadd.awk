
@include "pkutils.foundation.awk"
@include "pkutils.query.awk"
@include "pkutils.deps.awk"

function parse_arguments(queries,    i, m) {
    for (i = 1; i < ARGC; i++) {
        if (ARGV[i] ~ /^-[^=]+$/) {
            if (ARGV[i] ~ /^(-u|--upgrade)$/) {
                OPTIONS["upgrade"] = 1;
            } else if (ARGV[i] ~ /^(-f|--reinstall)$/) {
                OPTIONS["force"] = 1;
            } else if (ARGV[i] ~ /^(-d|--dry-run)$/) {
                OPTIONS["dryrun"] = 1;
            } else if (ARGV[i] ~ /^(--enable-deps)$/) {
                OPTIONS["use_deps"] = 1;
            } else if (ARGV[i] ~ /^(--disable-deps)$/) {
                OPTIONS["use_deps"] = 0;
            } else if (ARGV[i] ~ /^(-F|--fetch)$/) {
                OPTIONS["fetch_only"] = 1;
            } else {
                printf "Unrecognized option: %s\n", ARGV[i] >> "/dev/stderr";
                return 0;
            }
        } else if (ARGV[i] ~ /^-([^=]+)=([^=]+)$/) {
            match(ARGV[i], /^([^=]+)=([^=]+)$/, m);

            if (m[1] ~ /^-R$|^--root$/) {
                OPTIONS["root"]  = m[2];
            } else {
                printf "Unrecognized option: %s\n", m[1] >> "/dev/stderr";
                return 0;
            }
        } else {
            queries[++queries["length"]] = ARGV[i];
        }
    }

    return 1;
}

function elist_add_package(self, p, op,    k) {
    for (k = 1; k <= self["length"]; k++) {
        if (self[k] == p) {
            return;
        }
    }

    k = ++self["length"];
    self[k] = p;
    self[k, "tar"] = db_get_tar_name(DB[p]);
    if (op) {
        self[k, "hint"] = db_get_signature(DB[op]) " -> " db_get_signature(DB[p]);
    } else {
        self[k, "hint"] = db_get_signature(DB[p]);
    }
}

function elist_prompt(self,    i, p) {
    if (self["length"] == 0) {
        return;
    }

    printf "\n%d package(s) will be %s:\n", self["length"], self["action"];
    for (i = 1; i <= self["length"]; i++) {
        p = self[i];
        printf "-- %s (%s)\n", DB[p]["name"], self[i, "hint"];
    }
}

function fetch_sources(pk, tar,    i, failed, total, sources, checksums, m) {
    printf ">> TODO: FETCH %s SOURCES!\n", pk["name"];
    return 0;
}

function fetch_package(pk, tar, output,    i, r, pk_url_path) {
    for (i = 1; i <= REPOS["length"]; i++) {
        if (REPOS[i]["name"] == pk["repo_id"]) {
            r = i;
            break;
        }
    }

    if (!r) {
        printf "Error: no repo %s\n", pk["repo_id"] > "/dev/stderr";
        return 1;
    }

    if (pk["type"] == "SlackBuild") {
        return fetch_sources(pk, tar);
    }

    pk_url_path = sprintf("%s/%s/%s", REPOS[r]["url_path"], pk["location"], tar);
    __fetch_package_output = sprintf("%s/%s", REPOS[r]["cache"], tar);

    return pk_fetch_file(REPOS[r]["url_scheme"], REPOS[r]["url_host"],
        pk_url_path, __fetch_package_output, pk["checksum"]);
}

function elist_fetch(self,    i, p, output, failed) {
    for (i = 1; i <= self["length"]; i++) {
        p = self[i];
        failed += fetch_package(DB[p], self[i, "tar"]);
        self[i, "cache"] = __fetch_package_output;
    }
    return failed;
}

function elist_process(self,    i, p) {
    if (self["length"] == 0) {
        return;
    }

    if (OPTIONS["root"]) {
        self["command"] = sprintf("%s --root %s", self["command"], OPTIONS["root"]);
    }

    for (i = 1; i <= self["length"]; i++) {
        p = self[i];
        if (DB[p]["type"] == "SlackBuild") {
            printf ">> TODO: BUILD %s!\n", DB[p]["name"];
            continue;
        }

        if (OPTIONS["dryrun"]) {
            printf ">> %s %s\n", self["command"], self[i, "cache"];
            continue;
        }

        system(self["command"] " " self[i, "cache"]);
    }
}

function insert_package(p, er, eu, ei,    status) {
    status = db_is_installed(p);
    if (status == 1) {
        if (OPTIONS["force"]) {
            elist_add_package(er, p);
        } else {
            printf "Package %s (%s) installed already.\n", DB[p]["name"], DB[p]["version"];
        }
    } else if (status > 65535) {
        elist_add_package(eu, p, status - 65535);
    } else {
        if (!OPTIONS["upgrade"]) {
            elist_add_package(ei, p);
        }
    }
}

function upgrade_system(results,    i, status) {
    for (i = DB["first_local"]; i <= DB["length"]; i++) {
        status = db_is_upgradable(i);
        if (status == 0) {
            continue;
        }
        results[++results["length"]] = status;
    }
}

function pkadd_main(    i, p, queries, results, er, eu, ei) {
    if (!parse_arguments(queries)) {
        return 255;
    }

    pk_setup_dirs(OPTIONS["root"]);
    if (!pk_check_dirs()) {
        printf "Run `pkupd' first!\n";
        return 255;
    }
    pk_parse_options();

    printf "Reading packages index...";
    db_rebuild();
    printf " Done.\n";

    pk_parse_repos_list();

    if (OPTIONS["upgrade"] && !isarray(queries)) {
        upgrade_system(results);
    } else {
        db_query(results, queries);
        if (results["length"] <= 0) {
            printf "No packages found.\n";
            return 0;
        }
    }

    er["action"] = "REINSTALLED";
    er["command"] = "upgradepkg --reinstall";
    eu["action"] = "UPGRADED";
    eu["command"] = "upgradepkg";
    ei["action"] = "INSTALLED";
    ei["command"] = "installpkg";

    for (i = 1; i <= results["length"]; i++) {
        p = results[i];
        if (!DB[p]["required"] || !OPTIONS["use_deps"]) {
            insert_package(p, er, eu, ei);
            continue;
        }

        printf "Calculating dependencies for %s...\n", db_get_full_name(DB[p]);
        delete dlist;
        make_dependency_list(p, dlist);
        printf "Done!\n";

        for (j = 1; j <= dlist["length"]; j++) {
            insert_package(dlist[j], er, eu, ei);
        }
    }

    if (er["length"] == 0 && eu["length"] == 0 && ei["length"] == 0) {
        printf "Nothing to do.\n";
        return 0;
    }

    elist_prompt(er);
    elist_prompt(eu);
    elist_prompt(ei);

    if (pk_answer("\nContinue?", "y") == 0) {
        printf "Exiting...\n";
        return 255;
    }

    failed += elist_fetch(er);
    failed += elist_fetch(eu);
    failed += elist_fetch(ei);

    if (failed > 0) {
        printf "Exiting...\n";
        return 255;
    }

    if (OPTIONS["fetch_only"]) {
        return 0;
    }

    elist_process(er);
    elist_process(eu);
    elist_process(ei);

    return 0;
}

BEGIN {
    rc = pkadd_main();
    exit rc;
}
