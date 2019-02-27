
function pk_setup_dirs(_dirs, root) {
    _dirs["root"]    = root;
    _dirs["lib"]     = root "/var/lib/pkutils";
    _dirs["cache"]   = root "/var/cache/pkutils";
    _dirs["etc"]     = root "/etc/pkutils";
}

function pk_populate_dirs(dirs) {
    if (system("mkdir -p " dirs["lib"]) != 0)
        return 0;

    if (system("mkdir -p " dirs["cache"]) != 0)
        return 0;

    return 1;
}

function pk_check_dirs(dirs) {
    if (system("ls -1 " dirs["lib"] " 1>/dev/null 2>/dev/null") != 0)
        return 0;
    
    if (system("ls -1 " dirs["cache"] " 1>/dev/null 2>/dev/null") != 0)
        return 0;

    return 1;
}

function pk_parse_options(dirs, _options,    file, line, m) {
    file = dirs["etc"] "/pkutils.conf";

    while ((getline < file) > 0) {
        line++;
        if ($0 ~ /^(#|[[:space:]]*$)/) {
            continue;
        } else if ($0 ~ /^[a-z_]+\s*=\s*'.*'$/) {
            match($0, /^([a-z_]+)\s*=\s*'(.*)'$/, m);
            if (m[1] in _options) {
                continue;
            }
            _options[m[1]] = m[2];
        } else if ($0 ~ /^[a-z_]+\s*=\s*[^=]+$/) {
            match($0, /^([a-z_]+)\s*=\s*([^=]+)$/, m);
            if (m[1] in _options) {
                continue;
            }
            if (m[2] == "yes")     m[2] = 1;
            if (m[2] == "no")      m[2] = 0;
            _options[m[1]] = m[2];
        } else {
            printf "warning: failed to parse %s in line %d: %s\n", file, line, $0;
        }
    }
    close(file);
}

function pk_get_installed_packages(dirs, _installed,    cmd, total, m) {
    cmd = sprintf("find %s/var/log/packages -type f -printf \"%%f\n\"", dirs["root"]);
    while ((cmd | getline) > 0) {
        match($0, /^(.*)-([^-]*)-([^-]*)-([0-9])([^-]*)$/, m);
        total++;
        _installed[total]["name"]     = m[1];
        _installed[total]["version"]  = m[2];
        _installed[total]["arch"]     = m[3];
        _installed[total]["build"]    = m[4];
        _installed[total]["tag"]      = m[5];
    }
    close(cmd);
}

function pk_parse_repos_list(dirs, _repos,    file, total, m) {
    FS = " "; RS = "\n";

    file = dirs["etc"] "/repos.list";

    while ((getline < file) > 0) {
        if ((NF == 3) && ($0 ~ /^(pk|sb)/)) {
            total++;
            _repos[total]["name"] = $2;
            _repos[total]["type"] = $1;

            match($3, /(https?|ftp|rsync|file):\/\/([^\/]*)\/(.*)/, m);
            _repos[total]["url_scheme"] = m[1];
            _repos[total]["url_host"] = m[2];
            _repos[total]["url_path"] = m[3];

            _repos[total]["dir"] = sprintf("%s/repo_%s", dirs["lib"], _repos[total]["name"]);
            _repos[total]["cache"] = sprintf("%s/%s", dirs["cache"], _repos[total]["name"]);

            system("mkdir -p " _repos[total]["dir"]);
            system("mkdir -p " _repos[total]["cache"]);
        }
    }

    close(file);
    return total;
}

function pk_parse_lock_list(dirs, locked,    file, total) {
    FS = " "; RS = "\n";

    file = dirs["etc"] "/lock.list";

    while ((getline < file) > 0) {
        total++;
        locked[total]["name"]      = "^" $1 "$";
        locked[total]["version"]   = "^" $2 "$";
        locked[total]["arch"]      = "^" $3 "$";
        locked[total]["build"]     = "^" $4 "$";
        locked[total]["tag"]       = "^" $5 "$";
    }
    close(file);

    return total;
}

function __pk_check_md5sum(file, md5sum,    cmd) {
    if (!file || !md5sum)
        return 0;
    cmd = sprintf("echo %s %s | /usr/bin/md5sum --check >/dev/null 2>&1", md5sum, file);
    if (system(cmd) == 0)
        return 1;
    return 0;
}

#
# Return 1 on failure, 0 on success
#
function pk_fetch_file(scheme, host, path, output, md5sum, options,    cmd) {
    if (md5sum > 0 && __pk_check_md5sum(output, md5sum)) {
        printf "File %s is downloaded already.\n", output;
        return 0;
    }

    if (scheme ~ /https?|ftp/) {
        if (system("test -L " output) == 0) {
            printf "Found symbolic link %s. Removing... ", output;
            if (system("rm -rf " output) > 0) {
                printf "Failed!\n";
                return 1;
            }
            printf "\n";
        }

        cmd = sprintf("/usr/bin/wget %s -O %s %s://%s/%s", options["wget_args"], output, scheme, host, path);
        if (options["dryrun"]) {
            printf ">> %s\n", cmd;
            return 0;
        }
        if (system(cmd) > 0) {
            printf "Failed to download %s://%s/%s!\n", scheme, host, path > "/dev/stderr";
            return 1;
        }
    } else if (scheme ~ /file|cdrom/) {
        if (host) {
            printf "-- Only local machine for file:// is supported.\n" > "/dev/stderr";
            return 1;
        }

        printf "Linking /%s to %s... ", path, output;
        cmd = sprintf("ln -sf /%s %s", path, output);
        if (options["dryrun"]) {
            printf ">> %s\n", cmd;
            return 0;
        }
        if (system(cmd) > 0) {
            printf "Failed!\n";
            return 1;
        }
        printf "Done!\n";
    } else {
        printf "Internal error: Bad URL scheme \"%s\"!\n", scheme > "/dev/stderr";
        return 1;
    }

    if (md5sum == 0 || __pk_check_md5sum(output, md5sum)) {
        return 0;
    }

    printf "Error: wrong MD5 checksum.\n" >> "/dev/stderr";
    return 1;
}

#
# -> 0: not installed
# -> 1: upgradable
# -> 2: installed
#
function pk_is_installed(pk, installed, _oldpk) {
    for (i in installed) {
        if ((installed[i]["name"]       == pk["name"]) &&
            (installed[i]["version"]    == pk["version"]) &&
            (installed[i]["arch"]       == pk["arch"]) &&
            (installed[i]["build"]      == pk["build"]) &&
            (installed[i]["tag"]        == pk["tag"]))
        {
            return 1;
        } else if (installed[i]["name"] == pk["name"]) {
            _oldpk["version"] = installed[i]["version"];
            _oldpk["arch"] = installed[i]["arch"];
            _oldpk["build"] = installed[i]["build"];
            _oldpk["tag"] = installed[i]["tag"];
            return 2;
        }
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
