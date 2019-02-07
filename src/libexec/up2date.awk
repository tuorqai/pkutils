# Inputs: pklist.tmp, result.tmp
# Input variables: O_ADD, O_XUP, O_GET
# 

BEGIN {
    FS = ":"
}

NF == 1 {
    match($0, /^(.*)-([^-]*-[^-]*-[^-]*)$/, MATCH)
    INSTALLED[MATCH[1]] = MATCH[2]
    next
}

NF == 14 {
    RP_NAME = $2
    PK_NAME = $8
    PK_TAIL = $9"-"$10"-"$11$12
    PK_BASENAME = PK_NAME"-"PK_TAIL
    PK_FULLNAME = PK_BASENAME"."$13
    RP_PROTOCOL = $3
    PK_URL = $4"/"$5"/"$6"/"PK_FULLNAME
    PK_MD5SUM = $14

    if (PK_NAME in INSTALLED) {
        if (INSTALLED[PK_NAME] == PK_TAIL) {
            #
            # Case A: Same package of exact same version is installed already
            #
            if (FORCE == "yes") {
                print RP_NAME, PK_FULLNAME >> O_XUP
                print RP_NAME, RP_PROTOCOL, PK_URL, PK_FULLNAME, PK_MD5SUM >> O_GET
            } else {
                if (UPGRADE == "no")
                    print PK_BASENAME" is installed already."
            }
        } else {
            #
            # Case B: Same package is installed, but version is different
            #
            if (FORCE == "yes" || UPGRADE == "yes") {
                print RP_NAME, PK_FULLNAME >> O_XUP
                print RP_NAME, RP_PROTOCOL, PK_URL, PK_FULLNAME, PK_MD5SUM >> O_GET
            } else {
                print "Other version of "PK_NAME" ("INSTALLED[PK_NAME]") is installed."
            }
        }
    } else {
        #
        # Case C: Package is not installed
        #
        if (UPGRADE == "no") {
            print RP_NAME, PK_FULLNAME >> O_ADD
            print RP_NAME, RP_PROTOCOL, PK_URL, PK_FULLNAME, PK_MD5SUM >> O_GET
        }
    }
}