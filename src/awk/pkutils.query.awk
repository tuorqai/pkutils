
# --------------------------------
# -- pk_get_package_id_by_name
# Get package index in DB by it's name
# Polucith index packeta po ego nazvanyu
# --------------------------------
function db_get_by_name(name,    i, j, k, cases) {
    k = split(name, cases, /\|/);
    for (i = 1; i <= DB["length"]; i++) {
        for (j = 1; j <= k; j++) {
            if (DB[i]["name"] == cases[j]) {
                return i;
            }
        }
    }
    return 0;
}

# --------------------------------
# -- db_get_signature
# Vozvrasceaet signaturu packeta,
# to esth strocu vida `1.0.0-i586-1_slack14.2'
# --------------------------------
function db_get_signature(pk) {
    if (pk["type"] == "SlackBuild") {
        return pk["version"];
    }
    return sprintf("%s-%s-%d%s",
        pk["version"],
        pk["arch"],
        pk["build"],
        pk["tag"]);
}

# --------------------------------
# -- db_get_signature
# Vozvrasceaet polnoe imea packeta,
# to esth `imea-signatura'.
# --------------------------------
function db_get_full_name(pk) {
    return sprintf("%s-%s", pk["name"], db_get_signature(pk));
}

# --------------------------------
# -- db_get_tar_name
# Vozvrasceaet nazvanie sobstvenno faila
# dlea packeta s t?z-rasxireniem.
# --------------------------------
function db_get_tar_name(pk) {
    if (pk["type"] == "SlackBuild") {
        return sprintf("%s.tar.gz", pk["name"]);
    }
    return sprintf("%s.%s", db_get_full_name(pk), pk["type"]);
}

# --------------------------------
# -- db_rebuild
# --------------------------------
function db_rebuild(    m, cmd, index_dat, total) {
    index_dat = DIRS["lib"] "/index.dat";
    FS = ":"; RS = "\n";
    while ((getline < index_dat) > 0) {
        total++;
        DB[total]["repo_id"]     = $1;
        DB[total]["location"]    = $2;
        DB[total]["series"]      = $3;
        DB[total]["name"]        = $4;
        DB[total]["version"]     = $5;
        DB[total]["arch"]        = $6;
        DB[total]["build"]       = $7;
        DB[total]["tag"]         = $8;
        DB[total]["type"]        = $9;
        DB[total]["checksum"]    = $10;
        DB[total]["description"] = $11;
        DB[total]["required"]    = $12;
        DB[total]["conflicts"]   = $13;
        DB[total]["suggests"]    = $14;
        DB[total]["src_download"] = $15;
        DB[total]["src_download_x86_64"] = $16;
        DB[total]["src_checksum"] = $17;
        DB[total]["src_checksum_x86_64"] = $18;
    }
    close(index_dat);

    DB["last_remote"] = total;
    DB["first_local"] = total + 1;

    cmd = sprintf("find %s/var/log/packages -type f -printf \"%%f\n\" 2> /dev/null", DIRS["root"]);
    while ((cmd | getline) > 0) {
        match($0, /^(.*)-([^-]*)-([^-]*)-([0-9])([^-]*)$/, m);
        total++;
        DB[total]["repo_id"]     = "local";
        DB[total]["series"]      = "unknown";
        DB[total]["name"]        = m[1];
        DB[total]["version"]     = m[2];
        DB[total]["arch"]        = m[3];
        DB[total]["build"]       = m[4];
        DB[total]["tag"]         = m[5];
        DB[total]["description"] = "(description not available)";
    }
    close(cmd);

    DB["length"] = total;
}
# --------------------------------
# -- perform_query
# --------------------------------
function perform_query(results, query, strong,    i, j, p, f, m) {
    match(query,
        /^([^\~=@\/]*)\~?([^\~=@\/]*)=?([^\~=@\/]*)@?([^\~=@\/]*)\/?([^\~=@\/]*)/, m);

    for (i = 1; i <= 5; i++) {
        if (m[i] == "") {
            m[i] = ".*";
        }
        if (strong || i > 1) {
            m[i] = "^" m[i] "$";
        }
    }

    for (i = 1; i <= DB["length"]; i++) {
        if ((DB[i]["name"] ~ m[1]) && (DB[i]["arch"] ~ m[2]) &&
            (DB[i]["version"] ~ m[3]) && (DB[i]["repo_id"] ~ m[4]) &&
            (DB[i]["series"] ~ m[5]))
        {
            if (strong) {
                for (j = 1; j <= results["length"]; j++) {
                    p = results[j];
                    if (DB[p]["name"] == DB[i]["name"]) {
                        # ispolhzuem flag, t.c. net vozmoghnosti
                        # normalhno vhyti iz vlogennogo cycla
                        f = 65535;
                    }
                }
                if (f == 65535) {
                    break;
                }
            }
            results[++results["length"]] = i;
        }
    }
}

# --------------------------------
# -- db_query
# --------------------------------
function db_query(results, queries,    i) {
    for (i = 1; i <= queries["length"]; i++) {
        perform_query(results, queries[i], 1);
    }
}

# --------------------------------
# -- db_weak_query
# --------------------------------
function db_weak_query(results, queries,    i) {
    for (i = 1; i <= queries["length"]; i++) {
        perform_query(results, queries[i]);
    }
}

# --------------------------------
# -- db_is_installed
# Etot bratixhca provereaet, ustanovlen li
# tot ili inoi packet. Na vxod DB i index packeta,
# a na vhixod 1, esli packet ustanovlen localhno,
# libo 65535 + index obnovleaemogo packeta, esli
# ustanovlena drugaya versia, libo 0, esli nicego net.
# --------------------------------
# Pocemu 65535? Potomu chto mogu.
# --------------------------------
function db_is_installed(p,    i) {
    for (i = DB["first_local"]; i <= DB["length"]; i++) {
        if (DB[i]["name"] == DB[p]["name"]) {
            if ((DB[i]["version"] == DB[p]["version"]) && (DB[i]["arch"] == DB[p]["arch"]) &&
                (DB[i]["build"] == DB[p]["build"]) && (DB[i]["tag"] == DB[p]["tag"]))
            {
                return 1;
            }
            return 65535 + i;
        }
    }

    return 0;
}

function db_is_upgradable(p,    i) {
    for (i = 1; i <= DB["last_remote"]; i++) {
        if (DB[i]["name"] == DB[p]["name"]) {
            if ((DB[i]["version"] != DB[p]["version"]) ||
                (DB[i]["arch"] != DB[p]["arch"]) ||
                (DB[i]["build"] != DB[p]["build"]) ||
                (DB[i]["tag"] != DB[p]["tag"]))
            {
                return i;
            }
        }
    }
    return 0;
}

# --------------------------------
# -- db_dump
# --------------------------------
function db_dump(    i, j) {
    printf "DB size: %d packages\n", DB["length"];
    for (i = 1; i <= DB["length"]; i++) {
        printf "== PACKAGE #%d ==\n", i;
        for (j in DB[i]) {
            printf "  %s: %s\n", j, DB[i][j];
        }
    }
}
