
function pk_query(results, query, db, strict, action,    i, total, stash) {
    FS = ":"; RS = "\n";

    if (strict) {
        for (i in query) {
            query[i] = "^" query[i] "$";
        }
    }

    while ((getline < db) > 0) {
        if (($1 ~ query["repo_id"]) && ($3 ~ query["series"])  &&
            ($4 ~ query["name"])    && ($5 ~ query["version"]) &&
            ($6 ~ query["arch"])    && ($8 ~ query["tag"]) &&
            ($11 ~ query["desc"]))
        {
            if (action) {
                # `action' means that we have to return only one
                # version of a package
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
        }
    }

    close(db);
    return total;
}
