
function pk_make_database(_db, dirs,    m, cmd, index_dat, total) {
    index_dat = dirs["lib"] "/index.dat";
    FS = ":"; RS = "\n";
    while ((getline < index_dat) > 0) {
        total++;
        _db[total]["repo_id"]     = $1;
        _db[total]["location"]    = $2;
        _db[total]["series"]      = $3;
        _db[total]["name"]        = $4;
        _db[total]["version"]     = $5;
        _db[total]["arch"]        = $6;
        _db[total]["build"]       = $7;
        _db[total]["tag"]         = $8;
        _db[total]["type"]        = $9;
        _db[total]["checksum"]    = $10;
        _db[total]["description"] = $11;
        _db[total]["required"]    = $12;
        _db[total]["conflicts"]   = $13;
        _db[total]["suggests"]    = $14;
    }
    close(index_dat);

    cmd = sprintf("find %s/var/log/packages -type f -printf \"%%f\n\"", dirs["root"]);
    while ((cmd | getline) > 0) {
        match($0, /^(.*)-([^-]*)-([^-]*)-([0-9])([^-]*)$/, m);
        total++;
        _db[total]["repo_id"]     = "local";
        _db[total]["series"]      = "unknown";
        _db[total]["name"]        = m[1];
        _db[total]["version"]     = m[2];
        _db[total]["arch"]        = m[3];
        _db[total]["build"]       = m[4];
        _db[total]["tag"]         = m[5];
        _db[total]["description"] = "(description not available)";
    }
    close(cmd);

    _db["length"] = total;
}

function pk_query2(_results, query, db, strict, action,    i, stash, total) {
    for (i in query) {
        if (strict) {
            query[i] = "^" query[i] "$";
        }
        sub(/\+/, "\\+", query[i]);
    }

    for (i = 1; i <= db["length"]; i++) {
        if ((db[i]["repo_id"] ~ query["repo_id"]) &&
            (db[i]["series"] ~ query["series"]) &&
            (db[i]["name"] ~ query["name"]) &&
            (db[i]["version"] ~ query["version"]) &&
            (db[i]["arch"] ~ query["arch"]) &&
            (db[i]["tag"] ~ query["tag"]) &&
            (db[i]["description"] ~ query["desc"]))
        {
            if (action) {
                # `action' means that we have to return only one
                # version (one that have highest priority) of a package
                if (db[i]["name"] in stash) {
                    continue;
                }
                stash[db[i]["name"]] = 1;
            }

            total++;
            _results[total]["repo_id"]     = db[i]["repo_id"];
            _results[total]["location"]    = db[i]["location"];
            _results[total]["series"]      = db[i]["series"];
            _results[total]["name"]        = db[i]["name"];
            _results[total]["version"]     = db[i]["version"];
            _results[total]["arch"]        = db[i]["arch"];
            _results[total]["build"]       = db[i]["build"];
            _results[total]["tag"]         = db[i]["tag"];
            _results[total]["type"]        = db[i]["type"];
            _results[total]["checksum"]    = db[i]["checksum"];
            _results[total]["description"] = db[i]["description"];
            _results[total]["required"]    = db[i]["required"];
            _results[total]["conflicts"]   = db[i]["conflicts"];
            _results[total]["suggests"]    = db[i]["suggests"];
        }
    }

    _results["length"] = total;
}

function pk_query(results, query, db, strict, action,    i, total, stash) {
    FS = ":"; RS = "\n";

    for (i in query) {
        if (strict) {
            query[i] = "^" query[i] "$";
        }
        sub(/\+/, "\\+", query[i]);
    }

    while ((getline < db) > 0) {
        if (($1 ~ query["repo_id"]) && ($3 ~ query["series"])  &&
            ($4 ~ query["name"])    && ($5 ~ query["version"]) &&
            ($6 ~ query["arch"])    && ($8 ~ query["tag"]) &&
            ($11 ~ query["desc"]))
        {
            if (action) {
                # `action' means that we have to return only one
                # version (one that have highest priority) of a package
                if ($4 in stash) {
                    continue;
                }

                stash[$4] = 1;
            }
    
            total++;
            results[total]["repo_id"]     = $1;
            results[total]["location"]    = $2;
            results[total]["series"]      = $3;
            results[total]["name"]        = $4;
            results[total]["version"]     = $5;
            results[total]["arch"]        = $6;
            results[total]["build"]       = $7;
            results[total]["tag"]         = $8;
            results[total]["type"]        = $9;
            results[total]["checksum"]    = $10;
            results[total]["description"] = $11;
            results[total]["required"]    = $12;
            results[total]["conflicts"]   = $13;
            results[total]["suggests"]    = $14;
        }
    }

    close(db);
    return total;
}
