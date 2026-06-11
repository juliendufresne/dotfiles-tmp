#!/usr/bin/env awk

# usage: awk -f filter.awk <file>

mode == 1 { header=header $0 "\n" }

/^# ┌/ { mode=1; header=$0 "\n" }
/^# └/ { mode=0; header=header "\n" }
/^# ---/ { group=$0 "\n\n" }

/^$/ {
    if (keep) {
        print header group buf
        header = ""
        group = ""
    }
    buf = ""
    keep = 0
}

/^[^#]/ { keep=1; }

! /^[[:blank:]]*$/ {
    buf=buf $0 "\n"
}

