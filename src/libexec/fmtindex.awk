
function read_checksums(file, array) {
    RS = "\n"; FS = " "

    while (1) {
        status = getline < file
        if (status == -1) exit 1
        if (status == 0) break
        if (NF != 2) continue
        match($2, /^.*\/([^\/]*)-[^-]*-[^-]*-[^-]*\.t[bglx]z$/, MATCH)
        if (1 in MATCH) {
            array[MATCH[1]] = $1
        }
    }

    close(file)
}

BEGIN {
    read_checksums(CHECKSUMS, CHECKSUM_ARRAY)
    RS = ""; FS = "\n"
    ORS = "\n"; OFS = ":"
}

/^SLACKBUILD\s+/ {
    for (i = 1; i < NF; i++) {
        if ($i ~ /^SLACKBUILD NAME:\s+/) {
            SB_NAME = $i
            sub(/SLACKBUILD NAME:\s+/, "", SB_NAME)
        } else if ($i ~ /^SLACKBUILD LOCATION:\s+/) {
            SB_LOCATION = $i
            sub(/SLACKBUILD LOCATION:\s+/, "", SB_LOCATION)
        } else if ($i ~ /^SLACKBUILD VERSION:\s+/) {
            SB_VERSION = $i
            sub(/SLACKBUILD VERSION:\s+/, "", SB_VERSION)
        }
    }

    SB_FULLNAME = SB_NAME"-"SB_VERSION"-SlackBuild-0"

    print RP_NAME, SB_LOCATION, "", SB_FULLNAME, SB_FULLNAME, \
        SB_NAME, SB_VERSION, "", "", "", "SlackBuild"
}

/^PACKAGE\s+/ {
    for (i = 1; i < NF; i++) {
        if ($i ~ /^PACKAGE NAME:\s+.*/) {
            PK_FULLNAME = $i
            sub(/PACKAGE NAME:\s+/, "", PK_FULLNAME)
            # gsub(/\+/, "\\+", PK_FULLNAME)
            PK_BASENAME = PK_FULLNAME
            sub(/\.t[bglx]z/, "", PK_BASENAME)
            match(PK_FULLNAME,
                /(.*)-([^-]*)-([^-]*)-([0-9])([^-]*)\.(t[bglx]z)/,
                MATCH)
            PK_NAME = MATCH[1]
            PK_VERSION = MATCH[2]
            PK_ARCH = MATCH[3]
            PK_BUILD = MATCH[4]
            PK_TAG = MATCH[5]
            PK_TYPE = MATCH[6]
        } else if ($i ~ /^PACKAGE LOCATION:\s+.*/) {
            PK_LOCATION = $i
            sub(/PACKAGE LOCATION:\s+(\.\/)?/, "", PK_LOCATION)
            match(PK_LOCATION, /([^\/]*$)/, MATCH)
            PK_SERIES = MATCH[1]
        }
    }

#    print RP_NAME, PK_LOCATION, PK_SERIES, PK_FULLNAME, PK_BASENAME, \
#        PK_NAME, PK_VERSION, PK_ARCH, PK_BUILD, PK_TAG, PK_TYPE

    print RP_DATA, PK_LOCATION, PK_SERIES, \
        PK_NAME, PK_VERSION, PK_ARCH, PK_BUILD, PK_TAG, PK_TYPE, \
        CHECKSUM_ARRAY[PK_NAME]
}
