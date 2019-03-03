
function pk_setup_dirs(root) {
    DIRS["root"]    = root;
    DIRS["lib"]     = root "/var/lib/pkutils";
    DIRS["cache"]   = root "/var/cache/pkutils";
    DIRS["etc"]     = root "/etc/pkutils";
}

function pk_populate_dirs() {
    if (system("mkdir -p " DIRS["lib"]) != 0)
        return 0;

    if (system("mkdir -p " DIRS["cache"]) != 0)
        return 0;

    return 1;
}

function pk_check_dirs() {
    if (system("ls -1 " DIRS["lib"] " 1>/dev/null 2>/dev/null") != 0)
        return 0;
    
    if (system("ls -1 " DIRS["cache"] " 1>/dev/null 2>/dev/null") != 0)
        return 0;

    return 1;
}

function set_option(key, value) {
    # printf ("set_option(): %s -> %s\n", key, value);
    OPTIONS[key] = value;
}

function pk_parse_options(    file, line, m) {
    file = DIRS["etc"] "/pkutils.conf";

    while ((getline < file) > 0) {
        line++;
        if ($0 ~ /^(#|[[:space:]]*$)/) {
            continue;
        } else if ($0 ~ /^[a-z_]+\s*=\s*'.*'$/) {
            match($0, /^([a-z_]+)\s*=\s*'(.*)'$/, m);
            if (m[1] in OPTIONS) {
                continue;
            }
            set_option(m[1], m[2]);
        } else if ($0 ~ /^[a-z_]+\s*=\s*[^=]+$/) {
            match($0, /^([a-z_]+)\s*=\s*([^=]+)$/, m);
            if (m[1] in OPTIONS) {
                continue;
            }
            if (m[2] == "yes")     m[2] = 1;
            if (m[2] == "no")      m[2] = 0;
            set_option(m[1], m[2]);
        } else {
            printf "warning: failed to parse %s in line %d: %s\n", file, line, $0;
        }
    }
    close(file);
}

function pk_parse_repos_list(    file, total, m) {
    FS = " "; RS = "\n";

    file = DIRS["etc"] "/repos.list";

    while ((getline < file) > 0) {
        if ((NF == 3) && ($0 ~ /^(pk|sb)/)) {
            total++;
            REPOS[total]["name"] = $2;
            REPOS[total]["type"] = $1;

            match($3, /(https?|ftp|rsync|file):\/\/([^\/]*)\/(.*)/, m);
            REPOS[total]["url_scheme"] = m[1];
            REPOS[total]["url_host"] = m[2];
            REPOS[total]["url_path"] = m[3];

            REPOS[total]["dir"] = sprintf("%s/repo_%s", DIRS["lib"], REPOS[total]["name"]);
            REPOS[total]["cache"] = sprintf("%s/%s", DIRS["cache"], REPOS[total]["name"]);

            system("mkdir -p " REPOS[total]["dir"]);
            system("mkdir -p " REPOS[total]["cache"]);
        }
    }

    close(file);
    REPOS["length"] = total;
    return total;
}

function parse_lock_list(    file) {
    FS = " "; RS = "\n";

    file = DIRS["etc"] "/lock.list";

    while ((getline < file) > 0) {
        if ($0 ~ "^#|^\\s*$") {
            continue;
        }
        LOCK[++LOCK["length"]] = $0;
    }
    close(file);
}

function __pk_check_md5sum(file, md5sum,    cmd) {
    if (!file || !md5sum)
        return 0;
    cmd = sprintf("echo %s %s | /usr/bin/md5sum --check >/dev/null 2>&1", md5sum, file);
    if (system(cmd) == 0)
        return 1;
    return 0;
}

function pk_make_symlink(dest, src, md5sum,    cmd) {
    cmd = sprintf("ln -sf %s %s", src, dest);
    if (OPTIONS["dryrun"]) {
        printf ">> %s\n", cmd;
        return 0;
    }
    if (system(cmd) > 0) {
        printf "Failed!\n";
        return 1;
    }

    if (md5sum == 0 || __pk_check_md5sum(dest, md5sum)) {
        printf "Done.\n";
        return 0;
    }

    printf "wrong MD5 checksum.\n" >> "/dev/stderr";
    return 1;
}

function pk_fetch_remote(output, remote, md5sum,    cmd) {
    if (md5sum > 0 && __pk_check_md5sum(output, md5sum)) {
        printf "File %s is downloaded already.\n", output;
        return 0;
    }

    if (system("test -L " output) == 0) {
        printf "Found symbolic link %s. Removing... ", output;
        if (system("rm -rf " output) > 0) {
            printf "Failed!\n";
            return 1;
        }
        printf "Done.\n";
    }

    cmd = sprintf("/usr/bin/wget %s -O %s %s", OPTIONS["wget_args"], output, remote);
    if (OPTIONS["dryrun"]) {
        printf ">> %s\n", cmd;
        return 0;
    }

    if (system(cmd) > 0) {
        printf "Failed to download %s!\n", remote > "/dev/stderr";
        return 1;
    }

    if (md5sum == 0 || __pk_check_md5sum(output, md5sum)) {
        return 0;
    }

    printf "Error: wrong MD5 checksum.\n" >> "/dev/stderr";
    return 1;
}

function pk_fetch_file(scheme, host, path, output, md5sum,    failed) {
    if (scheme ~ /https?|ftp/) {
        failed = pk_fetch_remote(output, sprintf("%s://%s/%s", scheme, host, path), md5sum);
        if (failed) {
            return 1;
        }
    } else if (scheme ~ /file|cdrom/) {
        if (host) {
            printf "-- Only local machine for file:// is supported.\n" > "/dev/stderr";
            return 1;
        }

        failed = pk_make_symlink("/" output, path, md5sum);
        if (failed) {
            return 1;
        }
    } else {
        printf "Internal error: Bad URL scheme \"%s\"!\n", scheme > "/dev/stderr";
        return 1;
    }

    return 0;
}

function pk_is_locked(pk, locked) {
    for (i in locked) {
        if ((pk["name"]    ~ locked[i]["name"]) &&
            (pk["version"] ~ locked[i]["version"]) &&
            (pk["arch"]    ~ locked[i]["arch"]) &&
            (pk["build"]   ~ locked[i]["build"]) &&
            (pk["tag"]     ~ locked[i]["tag"]))
        {
            return 1;
        }
    }

    return 0;
}

#
# -> 0: user replied N
# -> 1: user replied Y
#
function pk_answer(prompt, default_reply,    reply) {
    if (default_reply == "y") {
        printf "%s [Y/n] ", prompt;
    } else {
        printf "%s [y/N] ", prompt;
    }

    if (OPTIONS["always_reply"]) {
        reply = OPTIONS["always_reply"] - 1000;
        if (reply) {
            printf "Y\n";
        } else {
            printf "N\n";
        }
        return reply;
    }

    getline reply < "/dev/stdin";
    reply = tolower(reply);

    if (default_reply == "y") {
        if (reply == "n") {
            return 0;
        }
        return 1;
    } else {
        if (reply == "y") {
            return 1;
        }
        return 0;
    }
}

function pk_get_full_version(pk) {
    if (pk["type"] == "SlackBuild") {
        return pk["version"];
    }
    return sprintf("%s-%s-%d%s",
        pk["version"], pk["arch"], pk["build"], pk["tag"]);
}
