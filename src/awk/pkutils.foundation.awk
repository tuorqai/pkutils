#
# Copyright (c) 2019 Valery Timiriliyev timiriliyev@gmail.com
# 
# This software is provided 'as-is', without any express or implied
# warranty. In no event will the authors be held liable for any damages
# arising from the use of this software.
# 
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
# 
# 1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software
#    in a product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
# 3. This notice may not be removed or altered from any source distribution.
#

function pk_setup_dirs(root) {
    if (!root && ENVIRON["ROOT"]) {
        root = ENVIRON["ROOT"];
    }

    DIRS["root"]    = root;
    DIRS["lib"]     = root "/var/lib/pkutils";
    DIRS["cache"]   = root "/var/cache/pkutils";
    DIRS["etc"]     = root "/etc/pkutils";
    DIRS["libexec"] = root "/usr/libexec/pkutils";

    # for debugging purposes only
    if (ENVIRON["PKUTILS_LIBEXEC"]) {
        DIRS["libexec"] = ENVIRON["PKUTILS_LIBEXEC"];
    }
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
    if (OPTIONS["verbose"] >= 2) {
        printf ("set_option(): %s -> %s\n", key, value);
    }
    OPTIONS[key] = value;
}

function pk_parse_options(    file, line, m) {
    FS = " "; RS = "\n";
    file = DIRS["etc"] "/pkutils.conf";

    while ((getline < file) > 0) {
        line++;
        if ($0 ~ /^#|^\s*$/) {
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

function pk_parse_repos_list(    file, total) {
    FS = " "; RS = "\n";
    file = DIRS["etc"] "/repos.list";

    while ((getline < file) > 0) {
        if ((NF == 3) && ($0 ~ /^(pk|sb)/)) {
            total++;
            REPOS[total]["uri"] = $3;
            REPOS[total]["name"] = $2;
            REPOS[total]["type"] = $1;

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

# --------------------------------
# -- check_md5sum
# --------------------------------
function check_md5sum(file, md5sum,    cmd) {
    if (!file || !md5sum)
        return 0;
    cmd = sprintf("echo %s %s | /usr/bin/md5sum --check >/dev/null 2>&1", md5sum, file);
    if (system(cmd) == 0)
        return 1;
    return 0;
}

# --------------------------------
# -- fetch_file
# Downloads a file from a remote source.
# Uses the shell script in /usr/libexec in order
# to properly handle Ctrl-C interrupt from the user.
# --------------------------------
function fetch_file(output, remote, md5sum,    cmd, status) {
    if (md5sum > 0 && check_md5sum(output, md5sum)) {
        printf "File %s is downloaded already.\n", output;
        return 1;
    }

    if (!OPTIONS["downloader"]) {
        OPTIONS["downloader"] = "/usr/bin/wget";
    }

    if (!OPTIONS["wget_args"]) {
        OPTIONS["wget_args"] = "-O";
    }

    cmd = sprintf("EXEC=\"%s\" ARGS=\"%s\" %s/fetch.sh %s %s",
        OPTIONS["downloader"],
        sprintf("%s %s", OPTIONS["wget_args"], output),
        DIRS["libexec"], remote, output);
    if (OPTIONS["dryrun"]) {
        system("DRYRUN=yes " cmd);
        return 1;
    }

    status = system(cmd);
    if (status == 200) {
        printf "Got interrupted by user. Stopping... :(\n";
        exit 200;
    }

    if (status >= 1) {
        printf "Failed to download %s.\n", remote >> "/dev/stderr";
        return 0;
    }

    if (md5sum == 0 || check_md5sum(output, md5sum)) {
        return 1;
    }

    printf "Error: wrong MD5 checksum.\n" >> "/dev/stderr";
    return 0;
}

# --------------------------------
# -- make_symlink
# --------------------------------
function make_symlink(dest, src, md5sum,    cmd) {
    cmd = sprintf("/bin/ln -sf %s %s >/dev/null 2>/dev/null",
        src, dest);
    if (OPTIONS["dryrun"]) {
        printf ">> %s\n", cmd;
        return 1;
    }

    printf "Linking %s to %s... ", src, dest;
    if (system(cmd) > 0) {
        printf "Failed!\n";
        return 0;
    }

    if (md5sum == 0 || check_md5sum(dest, md5sum)) {
        printf "Done.\n";
        return 1;
    }

    printf "Wrong MD5 checksum.\n" >> "/dev/stderr";
    return 0;
}

# --------------------------------
# -- get_file
# --------------------------------
function get_file(output, uri,    scheme, host, path, m) {
    match(uri, /^([a-z]+):\/\/([^\/]*)\/(.*)/, m);
    scheme = m[1];
    host = m[2];
    path = m[3];
    if (scheme ~ /ftp|https?/) {
        if (!fetch_file(output, uri)) {
            return 0;
        }
    } else if (scheme ~ /file|cdrom/) {
        if (host) {
            printf "Warning: only local host is supported for file://\n";
        }
        if (!make_symlink(output, path)) {
            return 0;
        }
    } else {
        printf "Error: bad URL scheme \"%s\".\n", scheme;
        return 0;
    }
    return 1;
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
